// JANs found on the web for a maker's 品番 (0223), for invoices that print
// only a maker and a 品番 (エコーマインド and others). The AI searches the
// maker's site, catalogs and large shops; an answer is kept only when it is
// a real JAN (its check digit adds up) and starts with one of the maker's own
// company prefixes as the JANs we already hold say (三菱鉛筆 4902778 …).
// Nothing is decided here: the app shows the JAN marked "AI検索" for a person
// to check against the invoice.
import { AiError, type ChosenKey, geminiSearch, resolveAiKey, type SpecDeps } from "./document_reader.ts";
import { validJan } from "./jan_catalog.ts";

export type JanAsk = {
  index: number;
  code: string;
  maker?: string | null;
  name?: string | null;
  /** The maker's company prefixes (first 7 digits) we know; empty: none known. */
  prefixes?: string[];
};

export type JanAnswer = {
  index: number;
  code: string;
  maker: string | null;
  jan: string | null;
  product_name: string | null;
  source_url: string | null;
  confidence: number | null;
  note: string | null;
  /** Why there is no JAN when the lookup itself failed (quota, no key …). */
  error_kind: string | null;
};

export function janLookupPrompt(item: JanAsk): string {
  return [
    "次のメーカーの品番の商品のJANコード(13桁)を、メーカー公式サイト・メーカーのカタログ・大手通販サイト(アスクル・モノタロウ・ヨドバシ・ビックカメラ・Amazon など)でGoogle検索して調べてください。",
    "",
    item.maker ? `メーカー: ${item.maker}` : null,
    `品番・型番: ${item.code}`,
    item.name && item.name !== item.code ? `仕入先の書き方(品名): ${item.name}` : null,
    "",
    "ルール:",
    "- 品番が完全に一致する商品(色番号・ボール径・サイズ・入数まで同じ)のJANだけを答える。品番の「.」の後ろの数字は色番号のことが多い。",
    "- 同じシリーズの別の色・別のサイズのJANを答えない。確かめられないときは jan を null にする。推測しない。",
    "- jan は数字13桁だけ(ハイフンや空白は入れない)。",
    "",
    "次のJSONだけを返す(説明文は不要):",
    '{"jan": "13桁"またはnull, "product_name": "通販サイト等での商品名"またはnull, "source_url": "根拠のページのURL"またはnull, ' +
      '"confidence": 0から1, "note": "根拠を一言で(日本語)"}',
  ].filter((l) => l !== null).join("\n");
}

/** The AI's answer kept to what can be trusted: a JAN with a good check
 * digit and, when the maker's prefixes are known, one of them. */
export function parseJanAnswer(text: string, item: JanAsk): Omit<JanAnswer, "error_kind"> | null {
  const start = text.indexOf("{"), end = text.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  let j: Record<string, unknown>;
  try {
    j = JSON.parse(text.slice(start, end + 1));
  } catch (_) {
    return null;
  }
  const t = (v: unknown, max: number) =>
    typeof v === "string" && v.trim() && !/^(null|不明|なし)$/i.test(v.trim()) ? v.trim().slice(0, max) : null;
  const url = typeof j.source_url === "string" && /^https?:\/\//.test(j.source_url) ? j.source_url : null;
  let conf = typeof j.confidence === "number" && j.confidence >= 0 && j.confidence <= 1 ? j.confidence : null;
  let note = t(j.note, 300);
  let jan: string | null = String(j.jan ?? "").normalize("NFKC").replace(/[^0-9]/g, "");
  if (jan.length !== 13 || !validJan(jan)) {
    if (jan) note = `JANの桁またはチェックデジットが合わない(${jan})`;
    jan = null;
  } else if ((item.prefixes ?? []).length > 0 && !item.prefixes!.some((p) => jan!.startsWith(p))) {
    note = `メーカーのJANの番号(${item.prefixes!.join("・")})と合わない(${jan})`;
    jan = null;
  }
  if (!jan) conf = 0;
  return {
    index: item.index, code: item.code, maker: item.maker ?? null, jan,
    product_name: t(j.product_name, 120), source_url: jan ? url : null, confidence: conf, note,
  };
}

/** Each item looked up on the web, at most ten at a time; nothing is kept
 * here (code_jan_save keeps it). Keys as for names: the lookup key, then the
 * reading key; a key out of search quota is not asked again. */
export async function lookupJansByCode(items: JanAsk[], deps?: Partial<SpecDeps>): Promise<{
  search_unavailable: boolean;
  results: JanAnswer[];
}> {
  const d: SpecDeps = { resolve: resolveAiKey, search: geminiSearch, plain: async () => ({}), ...deps } as SpecDeps;
  const keys: ChosenKey[] = [await d.resolve(null, "spec_lookup")];
  const general = await d.resolve(null, "general");
  if (general.key && general.id !== keys[0].id) keys.push(general);
  const outOfSearch = new Set<number>();
  const results: JanAnswer[] = [];
  let stop: string | null = null;
  for (const item of items.slice(0, 10)) {
    const empty = (kind: string | null): JanAnswer => ({
      index: item.index, code: item.code, maker: item.maker ?? null, jan: null, product_name: null,
      source_url: null, confidence: null, note: null, error_kind: kind,
    });
    if (stop) {
      results.push(empty(stop));
      continue;
    }
    let done = false;
    for (let k = 0; k < keys.length && !done; k++) {
      if (outOfSearch.has(k) || !keys[k].key) continue;
      try {
        const { text } = await d.search(janLookupPrompt(item), "jan_lookup", keys[k]);
        const found = parseJanAnswer(text, item);
        results.push(found ? { ...found, error_kind: null } : empty("parse"));
        done = true;
      } catch (e) {
        const kind = e instanceof AiError ? e.kind : "other";
        if (kind === "quota") {
          outOfSearch.add(k);
          continue;
        }
        results.push(empty(kind));
        if (kind === "auth" || kind === "no_key" || kind === "limit") stop = kind;
        done = true;
      }
    }
    if (!done) {
      stop = keys.some((k) => k.key) ? "search_unavailable" : "no_key";
      results.push(empty(stop));
    }
  }
  return { search_unavailable: stop === "search_unavailable", results };
}
