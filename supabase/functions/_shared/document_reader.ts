// Reading a trading company's document the way the company wrote it (0105).
//
// Every company heads its columns differently (品名 / 商品名 / Product Name /
// ｼｮｳﾋﾝﾒｲ), writes the JAN with its own separators, and some put the name and
// the 品番 in one cell. This module turns an Excel/CSV sheet, a PDF or a photo
// into lines of {jan, maker, name, code, quantity, …} in the company's own
// words, with every step checked twice:
//
//   * Columns: the company's learned headings, then everyone's, then a
//     "contains" match — and the AI is asked about whatever is left or looks
//     wrong. Where the two disagree the column is flagged for review.
//   * Values: a column whose values are valid JANs is the JAN column whatever
//     its heading says.
//   * Name + 品番 in one cell: split by rule AND by the AI; agreement is
//     accepted, disagreement flagged with both readings.
//   * PDF / photo: read by the AI once, then read again by a second,
//     independent verification pass that sees the first reading; every field
//     the two disagree on is flagged, with the other reading kept.
//   * Deterministic checks on top: JAN check digit, quantity present,
//     amount = quantity × unit price.
//
// Nothing here resolves to our products or writes anything: the caller does
// that through `resolve_notation_lines` once the lines are read.
import * as XLSX from "npm:xlsx@0.18.5";
import { encodeBase64 } from "jsr:@std/encoding/base64";
import { getDocumentProxy } from "npm:unpdf@1.1.0";

export type Field =
  | "jan" | "maker" | "product_name" | "product_code" | "name_code"
  | "quantity" | "case_quantity" | "cases" | "unit_price" | "amount"
  | "spec" | "tax_rate" | "order_date" | "ignore" | "attr"
  | "list_price" | "discount_rate" | "unit" | "supplier_code"
  | "upstream_code" | "customer_code" | "multi";

export const FIELDS: Field[] = [
  "jan", "maker", "product_name", "product_code", "name_code", "quantity",
  "case_quantity", "cases", "unit_price", "amount", "spec", "tax_rate",
  "order_date", "ignore", "attr", "list_price", "discount_rate", "unit", "supplier_code",
  "upstream_code", "customer_code", "multi",
];

/** What a cell holding several fields (0114, field 'multi') can be split into. */
export const PART_FIELDS: Field[] = [
  "maker", "product_name", "product_code", "jan", "spec", "supplier_code", "upstream_code", "unit", "ignore",
];

/** A column heading we know. For field 'attr', [attribute] says which of our
 * product attributes (0110: color, size, capacity, …) the column holds. */
export type AliasRow = {
  header_key: string;
  field: Field;
  partner: boolean;
  attribute?: string | null;
  /** The heading as written, and for field 'multi' its parts in order and
   * separator (0114). */
  header?: string | null;
  parts?: string[] | null;
  separator?: string | null;
};

/** One of our product attributes, as the AI is told about it. */
export type AttributeDef = { key: string; name: string };

/** An attribute as the company wrote it on one line: which of ours, the
 * company's own heading for it, and its value as written. */
export type ReadAttribute = { key: string; name: string; value: string };

export type Column = {
  index: number;
  header: string;
  field: Field | null;
  source: "partner" | "global" | "contains" | "values" | "ai" | "override" | null;
  ai_field?: Field | null;
  conflict?: boolean;
  /** For field 'attr': which of our attributes. */
  attribute?: string | null;
  /** For field 'multi': the fields in the cell, in order, and what separates
   * them (null = ／ or / when present, else spaces). */
  parts?: Field[] | null;
  separator?: string | null;
};

export type ReadLine = {
  row: number;
  jan_code: string;          // normalized, "" when none
  raw_jan_code: string | null;
  maker: string | null;
  product_name: string | null;
  product_code: string | null;
  raw_name_code: string | null;
  split_by: "rule" | "ai" | "both" | "layout" | null;
  spec: string | null;
  planned_quantity: number;
  case_quantity: number | null;
  cases: number | null;
  unit_price: number | null;
  amount: number | null;
  tax_rate: number | null;
  order_date: string | null;
  flags: string[];
  alternatives: Record<string, string | number | null>;
  attributes: ReadAttribute[];
  /** 定価 (list price), 掛率 as a fraction, 単位 as written (0111). */
  list_price: number | null;
  discount_rate: number | null;
  unit: string | null;
  /** The trading company's own code for the item, beside the maker's 品番. */
  supplier_code: string | null;
  /** The trading company's code for ITS supplier (仕入先コード — the maker
   * or vendor upstream of it), and its code for us (得意先コード) when a
   * sheet repeats it on every line (0112). */
  upstream_code: string | null;
  customer_code: string | null;
};

export type Header = {
  supplier_name: string | null;
  registration_number: string | null;
  customer_code: string | null;
  doc_number: string | null;
  doc_date: string | null;
  /** The company the document is addressed to (〇〇御中) — us (0132). */
  addressee?: string | null;
  /** Every other company it names, likeliest issuer first (0132). */
  supplier_candidates?: string[];
};

// ---------------------------------------------------------------------------
// Normalizing — the same rules as the database's (0105)
// ---------------------------------------------------------------------------

const KATA = "ァアィイゥウェエォオカガキギクグケゲコゴサザシジスズセゼソゾタダチヂッツヅテデトドナニヌネノハバパヒビピフブプヘベペホボポマミムメモャヤュユョヨラリルレロヮワヰヱヲンヴヵヶ";

export function normalizeText(v: unknown): string {
  if (v === null || v === undefined) return "";
  let s = String(v).normalize("NFKC").toLowerCase();
  let out = "";
  for (const ch of s) {
    const i = KATA.indexOf(ch);
    out += i >= 0 ? String.fromCharCode(ch.charCodeAt(0) - 0x60) : ch;
  }
  s = out.replace(/[\s・･\-‐‑‒–—―−_/\\,、，;:：；()\[\]{}「」【】『』〔〕<>#＃*]/g, "");
  return s.replace(/(?<![0-9])\.|\.(?![0-9])/g, "");
}

export function normalizeJan(v: unknown): string {
  if (v === null || v === undefined) return "";
  let s = String(v).normalize("NFKC").trim();
  if (/^[0-9]{8,14}\.0+$/.test(s)) s = s.split(".")[0];
  if (typeof v === "number" && Number.isFinite(v)) s = Math.round(v).toString();
  let d = s.replace(/[^0-9]/g, "");
  if (d.length === 12) d = "0" + d;
  if (d.length === 14) {
    if (d.startsWith("0")) return d.slice(1);
    const body = d.slice(1, 13);
    let sum = 0;
    for (let i = 0; i < 12; i++) sum += Number(body[i]) * ((i + 1) % 2 === 0 ? 3 : 1);
    return body + ((10 - (sum % 10)) % 10).toString();
  }
  return d;
}

export function janCheckOk(v: unknown): boolean {
  const d = normalizeJan(v);
  if (d.length !== 13 && d.length !== 8) return false;
  let s = 0;
  const n = d.length;
  for (let i = 0; i < n - 1; i++) s += Number(d[i]) * ((n - 1 - i) % 2 === 1 ? 3 : 1);
  return (10 - (s % 10)) % 10 === Number(d[n - 1]);
}

const isJanLength = (d: string) => d.length === 13 || d.length === 8;

export function str(v: unknown): string | null {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  return s === "" ? null : s;
}
export function toInt(v: unknown): number | null {
  const n = toNum(v);
  return n === null ? null : Math.round(n);
}
export function toNum(v: unknown): number | null {
  if (v === null || v === undefined || String(v).trim() === "") return null;
  // Text with no digit in it ("税抜金額") is no number, not zero.
  const t = String(v).normalize("NFKC").replace(/[^\d.-]/g, "");
  if (!/\d/.test(t)) return null;
  const n = Number(t);
  return Number.isFinite(n) ? n : null;
}
/** 掛率 as a fraction: 0.52, 52 and "52%" all read as 0.52. */
export function toRate(v: unknown): number | null {
  const n = toNum(v);
  if (n === null || n <= 0) return null;
  return n > 1 ? n / 100 : n;
}

function dateStr(v: unknown): string | null {
  if (v === null || v === undefined || v === "") return null;
  if (v instanceof Date) return v.toISOString().slice(0, 10);
  return String(v).trim();
}

// ---------------------------------------------------------------------------
// The AI (Gemini), with retries on overload
// ---------------------------------------------------------------------------

/** What kind of failure an AI call was (0133), for 稼働状況. */
export type AiErrorKind = "no_key" | "auth" | "quota" | "overload" | "bad_request" | "network" | "parse" | "other";

export class AiError extends Error {
  constructor(message: string, readonly kind: AiErrorKind, readonly status: number | null = null) {
    super(message);
  }
}

export function aiErrorKind(status: number | null, body = ""): AiErrorKind {
  if (status === null) return "network";
  if (status === 401 || status === 403 || /API_KEY_INVALID|API key not valid|PERMISSION_DENIED/i.test(body)) return "auth";
  // 402: the project's prepaid credits are spent; 429: too many requests.
  if (status === 402 || status === 429 || /RESOURCE_EXHAUSTED|quota|credits/i.test(body)) return "quota";
  if (status >= 500) return "overload";
  if (status >= 400) return "bad_request";
  return "other";
}

let aiFunction = "unknown";
/** Which edge function the calls are made from, for the record. */
export function setAiFunction(name: string) {
  aiFunction = name;
}

/** Every AI call is recorded in `ai_calls` (0133). Best effort: a record that
 * cannot be written never fails the reading. */
async function logAiCall(row: Record<string, unknown>) {
  const url = Deno.env.get("SUPABASE_URL"), key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return;
  try {
    await fetch(`${url}/rest/v1/ai_calls`, {
      method: "POST",
      headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json", Prefer: "return=minimal" },
      body: JSON.stringify({ function_name: aiFunction, ...row }),
    });
  } catch (_) { /* the record is not worth failing for */ }
}

export function aiModel(): string {
  return Deno.env.get("GEMINI_MODEL") ?? "gemini-3.8-flash";
}

/** One call to the AI (Gemini), retried on overload, and recorded with its
 * outcome, time and tokens (0133). [task] says what it was for. */
export async function gemini(
  parts: unknown[],
  schema: unknown,
  task = "other",
): Promise<Record<string, unknown>> {
  const model = aiModel();
  const started = Date.now();
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    await logAiCall({ task, model, ok: false, error_kind: "no_key", error: "GEMINI_API_KEY is not set", attempts: 0 });
    throw new AiError("GEMINI_API_KEY is not set on the server.", "no_key");
  }
  const endpoint =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
  const payload = {
    contents: [{ role: "user", parts }],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: schema,
      temperature: 0,
    },
  };
  let res: Response | null = null;
  let attempts = 0;
  for (let attempt = 0; attempt < 4; attempt++) {
    attempts++;
    try {
      res = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
        body: JSON.stringify(payload),
      });
    } catch (e) {
      await logAiCall({ task, model, ok: false, error_kind: "network", error: String(e).slice(0, 500), attempts,
        latency_ms: Date.now() - started });
      throw new AiError(`Gemini unreachable: ${e}`, "network");
    }
    if (res.status !== 503 && res.status !== 429) break;
    if (attempt < 3) await new Promise((r) => setTimeout(r, 700 * (attempt + 1)));
  }
  if (!res || !res.ok) {
    const status = res ? res.status : null;
    const body = res ? await res.text() : "";
    const kind = aiErrorKind(status, body);
    await logAiCall({ task, model, ok: false, http_status: status, error_kind: kind, error: body.slice(0, 500), attempts,
      latency_ms: Date.now() - started });
    throw new AiError(`Gemini error ${status ?? "?"}: ${body}`, kind, status);
  }
  const body = await res.json();
  const usage = body?.usageMetadata ?? {};
  const text = body?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
  let parsed: Record<string, unknown> | null = null;
  try {
    parsed = JSON.parse(text);
  } catch (_) {
    parsed = null;
  }
  await logAiCall({
    task, model, ok: parsed !== null, http_status: res.status, attempts, latency_ms: Date.now() - started,
    input_tokens: usage.promptTokenCount ?? null, output_tokens: usage.candidatesTokenCount ?? null,
    ...(parsed === null ? { error_kind: "parse", error: String(text).slice(0, 500) } : {}),
  });
  return parsed ?? {};
}

/** 接続テスト (0133): one tiny call, to tell at once whether the key works. */
export async function aiPing(): Promise<
  { ok: boolean; model: string; latency_ms: number; error_kind: AiErrorKind | null; message: string | null }
> {
  const started = Date.now();
  try {
    const r = await gemini([{ text: "接続確認です。reply に OK とだけ入れて返してください。" }],
      { type: "object", properties: { reply: { type: "string" } }, required: ["reply"] }, "ping");
    const ok = typeof r.reply === "string";
    return { ok, model: aiModel(), latency_ms: Date.now() - started, error_kind: ok ? null : "parse", message: null };
  } catch (e) {
    return {
      ok: false, model: aiModel(), latency_ms: Date.now() - started,
      error_kind: e instanceof AiError ? e.kind : "other", message: String(e).slice(0, 300),
    };
  }
}

/** How a reading went (0133), kept on its file's record: how many lines,
 * how many the AI's two readings disagreed on, or the check added or
 * dropped, and whether the lines add up to the document's total. */
export function readingQuality(
  lines: Pick<ReadLine, "flags">[], source: string, verified: boolean, totals: Pick<Totals, "ok"> | null,
): Record<string, unknown> {
  const count = (f: string) => lines.filter((l) => l.flags.some((x) => x === f || x.startsWith(`${f}:`))).length;
  const disagree = count("ai_disagree"), added = count("added_by_check"), dropped = count("dropped_by_check");
  const n = lines.length;
  return {
    source, verified, lines: n, disagree, added, dropped,
    no_quantity: count("no_quantity"), jan_check: count("jan_check"), qty_from_amount: count("qty_from_amount"),
    totals_ok: totals?.ok ?? null,
    agreement: n ? Math.round((1 - (disagree + added + dropped) / n) * 1000) / 1000 : null,
  };
}

const FIELD_HELP =
  "jan=JANコード/バーコード, maker=メーカー/ブランド, product_name=品名/商品名, " +
  "product_code=品番/型番/項目/商品コード, name_code=品名と品番が1つの欄に入っている, " +
  "quantity=数量(総数), case_quantity=入数, cases=ケース数/箱数, unit_price=単価, " +
  "amount=金額, spec=規格/仕様, tax_rate=税率, order_date=日付, " +
  "list_price=定価/上代/希望小売価格, discount_rate=掛率, unit=単位(本・冊・個・P など), " +
  "supplier_code=取引先独自の商品コード(品番とは別の欄がある場合), " +
  "upstream_code=仕入先コード(取引先がさらに仕入れている先=メーカー等のコード), " +
  "customer_code=得意先コード/お客様コード(取引先から見た当社のコード), " +
  "multi=メーカー・品名・品番など複数の項目が1つの欄にまとまっている, " +
  "attr=色・サイズ・容量・材質・重量など商品の属性(どの属性かを attribute に), ignore=その他";

/** "attr:color" as an override or wire value → field and attribute. */
export function splitAttr(
  v: string,
): { field: Field; attribute: string | null; parts?: Field[]; separator?: string | null } | null {
  if (v.startsWith("attr:")) return v.length > 5 ? { field: "attr", attribute: v.slice(5) } : null;
  // "multi:maker,product_name,product_code" with "|／" for its separator.
  if (v.startsWith("multi:")) {
    const [list, sep] = v.slice(6).split("|");
    const parts = list.split(",").filter((p) => PART_FIELDS.includes(p as Field)) as Field[];
    return parts.length >= 2 ? { field: "multi", attribute: null, parts, separator: sep || null } : null;
  }
  return FIELDS.includes(v as Field) && v !== "attr" ? { field: v as Field, attribute: null } : null;
}

// ---------------------------------------------------------------------------
// Name and 品番 in one cell
// ---------------------------------------------------------------------------

const CODE = "[A-Za-z0-9][A-Za-z0-9\\-_./#]{1,}";
const looksLikeCode = (s: string) =>
  /[0-9]/.test(s) && /^[A-Za-z0-9][A-Za-z0-9\-_./#]{1,}$/.test(s) && s.length <= 30;

export function splitByRule(raw: string): { name: string; code: string } | null {
  const s = raw.normalize("NFKC").trim();
  // 名前 (CODE) / 名前【CODE】 / 名前[CODE]
  let m = s.match(/^(.+?)\s*[(\[【〔]\s*([^()\[\]【】〔〕]+?)\s*[)\]】〕]$/);
  if (m && looksLikeCode(m[2].trim())) return { name: m[1].trim(), code: m[2].trim() };
  // CODE 名前 / CODE / 名前 / CODE:名前
  m = s.match(new RegExp(`^(${CODE})\\s*[\\s/:|]\\s*(.+)$`));
  if (m && looksLikeCode(m[1]) && /[^\x00-\x7f]|[a-z]{3,}/i.test(m[2])) {
    return { name: m[2].trim(), code: m[1] };
  }
  // 名前 CODE / 名前 / CODE
  m = s.match(new RegExp(`^(.+?)\\s*[\\s/|]\\s*(${CODE})$`));
  if (m && looksLikeCode(m[2])) return { name: m[1].trim(), code: m[2] };
  return null;
}

/** Splits every combined cell by rule and by the AI; returns one reading per
 * input with how it was reached. */
export type SplitResult = {
  name: string | null;
  code: string | null;
  by: "rule" | "ai" | "both" | null;
  alt?: { name: string | null; code: string | null };
};

export async function splitNameCodes(values: string[]): Promise<SplitResult[]> {
  const rules = values.map((v) => splitByRule(v));
  let ai: { index?: number; product_name?: string; product_code?: string }[] = [];
  if (values.length > 0) {
    try {
      const r = await gemini([{
        text:
          "次のそれぞれの文字列は、商品名(品名)と品番(型番・項目)が1つの欄にまとめて書かれたものです。" +
          "品名と品番に分けてください。品番が無いものは product_code を空文字に。" +
          "メーカー名が含まれていても品名に残してください。index はそのまま返すこと。\n" +
          JSON.stringify(values.map((v, i) => ({ index: i, text: v }))),
      }], {
        type: "object",
        properties: {
          items: {
            type: "array",
            items: {
              type: "object",
              properties: {
                index: { type: "integer" },
                product_name: { type: "string" },
                product_code: { type: "string" },
              },
              required: ["index"],
            },
          },
        },
        required: ["items"],
      }, "split");
      ai = Array.isArray(r.items) ? r.items as typeof ai : [];
    } catch (_) {
      ai = [];
    }
  }
  return values.map((v, i) => {
    const rule = rules[i];
    const a = ai.find((x) => x.index === i);
    const aName = str(a?.product_name);
    const aCode = str(a?.product_code);
    if (rule && (aName || aCode)) {
      const same = normalizeText(rule.code) === normalizeText(aCode) &&
        normalizeText(rule.name) === normalizeText(aName);
      if (same) return { name: rule.name, code: rule.code, by: "both" as const };
      return { name: aName, code: aCode, by: "ai" as const, alt: { name: rule.name, code: rule.code } };
    }
    if (rule) return { name: rule.name, code: rule.code, by: "rule" as const };
    if (aName || aCode) return { name: aName ?? v, code: aCode, by: "ai" as const };
    return { name: v, code: null, by: null };
  });
}

// ---------------------------------------------------------------------------
// Spreadsheets
// ---------------------------------------------------------------------------

/** The fields a heading names, in order, when it names several of them and
 * more than a name and a 品番 (those are name_code): "メーカー/品名/品番" →
 * maker, product_name, product_code. Null otherwise. */
export function headingParts(header: string, aliases: AliasRow[]): Field[] | null {
  const segs = header.normalize("NFKC").split(/[/／・,、|｜]/).map((x) => x.trim()).filter(Boolean);
  if (segs.length < 2) return null;
  const parts: Field[] = [];
  for (const seg of segs) {
    const key = normalizeText(seg);
    const hit = aliases.find((a) => a.header_key === key && !a.partner);
    if (!hit || !PART_FIELDS.includes(hit.field) || parts.includes(hit.field)) return null;
    parts.push(hit.field);
  }
  if (parts.length === 2 && parts.includes("product_name") && parts.includes("product_code")) return null;
  return parts;
}

/** A cell holding several fields, split in order (0114). The separator is
 * the one given, else ／ or / when the cell has one, else spaces. The last
 * field takes what is left ("UMN105EW 33" stays one 品番); a cell shorter
 * than its parts fills them from the end, since the 品番 comes last. */
export function splitMulti(raw: string, parts: Field[], separator?: string | null): Partial<Record<Field, string>> {
  const text = raw.trim();
  let tokens: string[];
  let glue: string;
  if (separator && separator !== "space") {
    tokens = text.split(separator);
    glue = separator;
  } else if (!separator && /[／/]/.test(text)) {
    tokens = text.split(/[／/]/);
    glue = text.includes("／") ? "／" : "/";
  } else {
    tokens = text.split(/[\s\u3000]+/);
    glue = " ";
  }
  tokens = tokens.map((t) => t.trim()).filter(Boolean);
  const out: Partial<Record<Field, string>> = {};
  if (tokens.length === 0) return out;
  if (tokens.length >= parts.length) {
    parts.forEach((p, i) => {
      const v = i === parts.length - 1 ? tokens.slice(i).join(glue) : tokens[i];
      if (p !== "ignore" && v) out[p] = v;
    });
  } else {
    const from = parts.length - tokens.length;
    tokens.forEach((t, i) => {
      const p = parts[from + i];
      if (p !== "ignore") out[p] = t;
    });
  }
  return out;
}

export function aliasFor(
  header: string,
  aliases: AliasRow[],
): {
  field: Field;
  source: Column["source"];
  attribute: string | null;
  parts?: Field[] | null;
  separator?: string | null;
} | null {
  const key = normalizeText(header);
  if (!key) return null;
  const exact = aliases.filter((a) => a.header_key === key);
  const layout = (a: AliasRow) => ({
    parts: a.field === "multi" ? (a.parts ?? []).filter((p) => PART_FIELDS.includes(p as Field)) as Field[] : null,
    separator: a.field === "multi" ? a.separator ?? null : null,
  });
  const partner = exact.find((a) => a.partner);
  if (partner) return { field: partner.field, source: "partner", attribute: partner.attribute ?? null, ...layout(partner) };
  if (exact.length) return { field: exact[0].field, source: "global", attribute: exact[0].attribute ?? null, ...layout(exact[0]) };
  // A heading naming several fields ("メーカー/品名/品番") says how its cells split (0114).
  const parts = headingParts(header, aliases);
  if (parts) return { field: "multi", source: "global", attribute: null, parts, separator: null };
  // The longest known heading contained in this one (JANコード(13桁), 商品名称/カナ).
  let best: AliasRow | null = null;
  for (const a of aliases) {
    if (a.header_key.length >= 2 && key.includes(a.header_key) &&
        (!best || a.header_key.length > best.header_key.length)) best = a;
  }
  return best ? { field: best.field, source: "contains", attribute: best.attribute ?? null } : null;
}

async function aiColumns(
  headers: string[],
  samples: unknown[][],
  attributes: AttributeDef[] = [],
): Promise<({ field: Field; attribute: string | null } | null)[]> {
  const attrHelp = attributes.length
    ? "attr の場合の attribute は次のどれか: " + attributes.map((a) => `${a.key}=${a.name}`).join(", ") + "。"
    : "";
  try {
    const r = await gemini([{
      text:
        "これは取引先(商社)から届いた表の見出し行とデータ例です。見出しは日本語(漢字・カナ)や英語など" +
        "商社ごとに違います。各列が何を表すか、次のどれかで答えてください: " + FIELD_HELP + "。" +
        "見出しだけでなく値も見て判断すること(13桁の数字ならjan、品名と品番が混ざっていればname_code)。" +
        attrHelp + "\n" +
        JSON.stringify({ headers, samples: samples.map((r) => r.map((c) => (c === null ? "" : String(c)))) }),
    }], {
      type: "object",
      properties: {
        columns: {
          type: "array",
          items: {
            type: "object",
            properties: {
              index: { type: "integer" },
              field: {
                type: "string",
                enum: FIELDS.filter((f) => f !== "multi" && (attributes.length > 0 || f !== "attr")),
              },
              ...(attributes.length ? { attribute: { type: "string", enum: attributes.map((a) => a.key) } } : {}),
            },
            required: ["index", "field"],
          },
        },
      },
      required: ["columns"],
    }, "columns");
    const cols = Array.isArray(r.columns) ? r.columns as { index: number; field: Field; attribute?: string }[] : [];
    return headers.map((_, i) => {
      const c = cols.find((c) => c.index === i);
      if (!c || !FIELDS.includes(c.field)) return null;
      if (c.field === "attr") {
        return attributes.some((a) => a.key === c.attribute) ? { field: "attr", attribute: c.attribute! } : null;
      }
      return { field: c.field, attribute: null };
    });
  } catch (_) {
    return headers.map(() => null);
  }
}

/** The attributes as one 規格 text, for documents that print a single spec
 * column (the slip, the plan line) when the file had none of its own. */
export function specFrom(attrs: ReadAttribute[]): string | null {
  return attrs.length ? attrs.map((a) => `${a.name}:${a.value}`).join(" ") : null;
}

const MAKER_CODE_HEADING = /品番|型番|型式|項目|めーかー|model|partno|partnumber|styleno/;
const LIST_PRICE_HEADING = /定価|上代|希望小売|小売価格|listprice|retail|msrp/;

/** Two columns read as the same thing, as in a wholesaler's sheet with its
 * own 商品コード beside the maker's 品番, or 定価 beside 見積単価: the
 * maker's code stays the 品番 and the other is the company's own code; a
 * 定価-like heading is the list price and the other is the price paid. */
export function settleDuplicates(columns: Column[]) {
  const codes = columns.filter((c) => c.field === "product_code");
  if (codes.length > 1) {
    const maker = codes.find((c) => MAKER_CODE_HEADING.test(normalizeText(c.header))) ?? codes[0];
    for (const c of codes) if (c !== maker) c.field = "supplier_code";
  }
  const prices = columns.filter((c) => c.field === "unit_price");
  if (prices.length > 1) {
    for (const c of prices) {
      if (LIST_PRICE_HEADING.test(normalizeText(c.header)) && !columns.some((x) => x.field === "list_price")) {
        c.field = "list_price";
      }
    }
  }
}

const TOTAL_ROW = /^(合計|小計|総合計|計|total|subtotal|grand ?total)$/i;
const SUMMARY_WORDS = /合計|小計|消費税|税抜|税込|対象額?|総額|値引|送料|繰越|前回|今回|請求|入金|残高|買上|差引|振込|手数料|total|tax/i;

/** What the lines add up to, against what the document says it totals
 * (0114). A misread quantity or price shows here. */
export type Totals = {
  lines_sum: number | null;
  doc_subtotal: number | null;
  doc_tax: number | null;
  doc_total: number | null;
  /** subtotal / total_minus_tax / total / found (a figure elsewhere on the
   * document), or null. */
  matched: string | null;
  /** null when there is nothing to compare. */
  ok: boolean | null;
};

export function checkTotals(
  lines: Pick<ReadLine, "amount">[],
  doc: { subtotal?: number | null; tax?: number | null; total?: number | null; numbers?: number[] } = {},
): Totals {
  const amounts = lines.map((l) => l.amount).filter((a): a is number => a !== null && Number.isFinite(a));
  const sum = amounts.length ? Math.round(amounts.reduce((x, y) => x + y, 0) * 100) / 100 : null;
  const subtotal = doc.subtotal ?? null, tax = doc.tax ?? null, total = doc.total ?? null;
  const out: Totals = { lines_sum: sum, doc_subtotal: subtotal, doc_tax: tax, doc_total: total, matched: null, ok: null };
  if (sum === null) return out;
  const near = (x: number | null) => x !== null && Math.abs(x - sum) <= 1;
  if (near(subtotal)) return { ...out, matched: "subtotal", ok: true };
  if (total !== null && tax !== null && near(total - tax)) return { ...out, matched: "total_minus_tax", ok: true };
  if (near(total)) return { ...out, matched: "total", ok: true };
  if ((doc.numbers ?? []).some((n) => near(n))) return { ...out, matched: "found", ok: true };
  const anything = subtotal !== null || total !== null || (doc.numbers ?? []).length > 0;
  return { ...out, ok: anything ? false : null };
}

/** A cell that is a plain amount ("¥614,820", "328,600", 12480). */
function amountOf(v: unknown): number | null {
  if (typeof v === "number") return Number.isFinite(v) ? v : null;
  const t = String(v ?? "").normalize("NFKC").replace(/[¥\s円]/g, "");
  return /^-?[0-9][0-9,]*(\.[0-9]+)?$/.test(t) ? Number(t.replace(/,/g, "")) : null;
}

/** Reads the first sheet of an Excel or CSV file. [overrides] maps a column
 * index to a field when the operator corrected the reading. */
export async function readSpreadsheet(
  bytes: Uint8Array,
  aliases: AliasRow[],
  overrides: Record<number, string> = {},
  useAi = true,
  attributes: AttributeDef[] = [],
  own: OwnCompany | null = null,
): Promise<{ columns: Column[]; lines: ReadLine[]; header_row: number; totals: Totals; header: Header }> {
  const wb = XLSX.read(bytes, { type: "array", cellDates: true, cellNF: true });
  const ws = wb.Sheets[wb.SheetNames[0]];
  const rows = XLSX.utils.sheet_to_json(ws, { header: 1, raw: true, defval: null, blankrows: true }) as unknown[][];
  // Row/column 0 of [rows] is the sheet's first used cell.
  const origin = ws["!ref"] ? XLSX.utils.decode_range(ws["!ref"]).s : { r: 0, c: 0 };
  const formatAt = (r: number, c: number): string | null => {
    const cellObj = ws[XLSX.utils.encode_cell({ r: origin.r + r, c: origin.c + c })] as { z?: unknown } | undefined;
    return typeof cellObj?.z === "string" ? cellObj.z : null;
  };
  const read = await readRows(rows, aliases, overrides, useAi, attributes, formatAt);
  // What the sheet says above its table: who sent it, its number and date.
  const top = rows.slice(0, Math.max(read.header_row - 1, 0))
    .map((r) => r.filter((c) => c !== null && String(c).trim() !== "").map((c) => String(c)).join(" "))
    .join("\n");
  return { ...read, header: pdfHeaderFrom(top, own) };
}

/** Reads a table given as rows of cells — a sheet, or a PDF's text laid out
 * by position (0114). */
export async function readRows(
  rows: unknown[][],
  aliases: AliasRow[],
  overrides: Record<number, string> = {},
  useAi = true,
  attributes: AttributeDef[] = [],
  formatAt: (r: number, c: number) => string | null = () => null,
): Promise<{ columns: Column[]; lines: ReadLine[]; header_row: number; totals: Totals }> {
  const ncol = rows.reduce((m, r) => Math.max(m, r.length), 0);

  // The heading row: the one most of whose cells are headings we know.
  let headerRow = -1, bestScore = 0;
  for (let ri = 0; ri < Math.min(rows.length, 60); ri++) {
    const score = (rows[ri] ?? []).filter((c) =>
      typeof c === "string" && aliasFor(c, aliases) !== null
    ).length;
    if (score > bestScore) { bestScore = score; headerRow = ri; }
  }
  if (bestScore < 2) headerRow = -1;
  const headerCells = headerRow >= 0 ? rows[headerRow] : [];
  const headerKey = headerCells.map((c) => normalizeText(c)).join("|");
  const body = rows.slice(headerRow + 1);

  const columns: Column[] = [];
  for (let c = 0; c < ncol; c++) {
    const header = str(headerCells[c]) ?? "";
    const hit = header ? aliasFor(header, aliases) : null;
    columns.push({
      index: c, header, field: hit?.field ?? null, source: hit?.source ?? null,
      attribute: hit?.field === "attr" ? hit.attribute : null,
      ...(hit?.field === "multi" ? { parts: hit.parts ?? null, separator: hit.separator ?? null } : {}),
    });
  }

  // Values say more than headings: a column of valid JANs is the JAN column.
  const janScore = (c: number) => {
    let ok = 0, filled = 0;
    for (const r of body) {
      const v = r[c];
      if (v === null || v === undefined || String(v).trim() === "") continue;
      filled++;
      if (janCheckOk(v)) ok++;
    }
    return filled === 0 ? 0 : ok / filled;
  };
  if (!columns.some((c) => c.field === "jan")) {
    let best = -1, score = 0;
    for (let c = 0; c < ncol; c++) {
      const s = janScore(c);
      if (s > score) { score = s; best = c; }
    }
    if (best >= 0 && score >= 0.6) {
      columns[best] = { ...columns[best], field: "jan", source: "values" };
    }
  }

  // Ask the AI about every column, and compare.
  if (useAi && ncol > 0) {
    const samples = body.filter((r) => r.some((c) => c !== null && String(c).trim() !== "")).slice(0, 6);
    const ai = await aiColumns(columns.map((c) => c.header), samples, attributes);
    for (const col of columns) {
      const a = ai[col.index];
      col.ai_field = a?.field ?? null;
      if (col.field === null && a && a.field !== "ignore") {
        col.field = a.field;
        col.attribute = a.attribute;
        col.source = "ai";
      } else if (col.field && col.field !== "multi" && a &&
                 (a.field !== col.field || a.attribute !== (col.attribute ?? null)) &&
                 col.source !== "partner") {
        col.conflict = true;
      }
    }
  }
  for (const [k, v] of Object.entries(overrides)) {
    const i = Number(k);
    const o = splitAttr(v);
    if (columns[i] && o) {
      columns[i] = {
        ...columns[i], field: o.field, attribute: o.attribute, source: "override", conflict: false,
        parts: o.parts ?? null, separator: o.separator ?? null,
      };
    }
  }

  settleDuplicates(columns);

  const colOf = (f: Field) => columns.find((c) => c.field === f)?.index ?? -1;
  const cell = (r: unknown[], c: number) => (c >= 0 && c < r.length ? r[c] : null);
  const cJan = colOf("jan"), cMaker = colOf("maker"), cName = colOf("product_name");
  const cCode = colOf("product_code"), cNameCode = colOf("name_code"), cQty = colOf("quantity");
  const cCaseQty = colOf("case_quantity"), cCases = colOf("cases"), cUnit = colOf("unit_price");
  const cAmount = colOf("amount"), cSpec = colOf("spec"), cTax = colOf("tax_rate");
  const cDate = colOf("order_date");
  const cList = colOf("list_price"), cRate = colOf("discount_rate"), cUnitName = colOf("unit");
  const cSupCode = colOf("supplier_code");
  const cUpstream = colOf("upstream_code"), cCustomer = colOf("customer_code");
  // Every attribute column, however many (色 and サイズ side by side).
  const attrCols = columns.filter((c) => c.field === "attr" && c.attribute);
  // Cells holding several fields, split by their layout (0114).
  const multiCols = columns.filter((c) => c.field === "multi" && (c.parts ?? []).length >= 2);

  // Figures outside the lines — totals rows, the summary above the table —
  // to check the lines against.
  const numbers: number[] = [];
  const keepNumbers = (r: unknown[]) => {
    for (const c of r) {
      const n = amountOf(c);
      if (n !== null && Math.abs(n) >= 1) numbers.push(n);
    }
  };
  rows.slice(0, Math.max(headerRow, 0)).forEach(keepNumbers);

  const lines: ReadLine[] = [];
  body.forEach((r, i) => {
    if (!r.some((c) => c !== null && String(c).trim() !== "")) return;
    // The heading again (a second page) is not a line.
    if (headerRow >= 0 && r.map((c) => normalizeText(c)).join("|") === headerKey) return;
    const first = str(r.find((c) => str(c) !== null));
    if (first && TOTAL_ROW.test(first.normalize("NFKC").replace(/\s/g, ""))) {
      keepNumbers(r);
      return;
    }
    const split: Partial<Record<Field, string>> = {};
    let multiRaw: string | null = null;
    for (const c of multiCols) {
      const v = str(cell(r, c.index));
      if (!v) continue;
      multiRaw ??= v;
      for (const [k, val] of Object.entries(splitMulti(v, c.parts!, c.separator))) {
        split[k as Field] ??= val;
      }
    }
    const rawJan = str(cell(r, cJan)) ?? split.jan ?? null;
    const jan = normalizeJan(cell(r, cJan) ?? split.jan ?? null);
    const name = str(cell(r, cName)) ?? split.product_name ?? null;
    const code = str(cell(r, cCode)) ?? split.product_code ?? null;
    const nameCode = str(cell(r, cNameCode));
    if (!rawJan && !name && !code && !nameCode) {
      keepNumbers(r);
      return;
    }
    // A summary row below the lines (消費税10%対象 / 税抜金額 …): its figures
    // are for checking, it is not a line.
    if (!janCheckOk(rawJan) && toInt(cell(r, cQty)) === null &&
        r.some((c) => SUMMARY_WORDS.test(String(c ?? "").normalize("NFKC")))) {
      keepNumbers(r);
      return;
    }
    const listPrice = toNum(cell(r, cList));
    const rate = toRate(cell(r, cRate));
    const cases = toInt(cell(r, cCases));
    const caseQty = toInt(cell(r, cCaseQty));
    let qty = toInt(cell(r, cQty));
    const flags: string[] = [];
    const attrs: ReadAttribute[] = [];
    for (const c of attrCols) {
      const v = str(cell(r, c.index));
      if (v) attrs.push({ key: c.attribute!, name: c.header, value: v });
    }
    if (qty === null && cases !== null && caseQty !== null) {
      qty = cases * caseQty;
      flags.push("qty_from_cases");
    }
    // A JAN kept whole as a number but SHOWN in exponent form (4.90148E+12):
    // read right, but warned about, since the file loses it once saved as CSV.
    if (cJan >= 0 && janShownAsExponent(cell(r, cJan), formatAt(headerRow + 1 + i, cJan))) {
      flags.push("jan_display_exponent");
    }
    lines.push({
      row: headerRow + 2 + i,
      jan_code: isJanLength(jan) ? jan : "",
      raw_jan_code: rawJan,
      maker: str(cell(r, cMaker)) ?? split.maker ?? null,
      product_name: name,
      product_code: code,
      raw_name_code: nameCode ?? multiRaw,
      split_by: !nameCode && multiRaw ? "layout" : null,
      spec: str(cell(r, cSpec)) ?? split.spec ?? specFrom(attrs),
      planned_quantity: qty ?? 0,
      case_quantity: caseQty,
      cases,
      unit_price: toNum(cell(r, cUnit)) ??
        (listPrice !== null && rate !== null ? Math.round(listPrice * rate * 100) / 100 : null),
      amount: toInt(cell(r, cAmount)),
      tax_rate: toNum(cell(r, cTax)),
      order_date: dateStr(cell(r, cDate)),
      flags,
      alternatives: {},
      attributes: attrs,
      list_price: listPrice,
      discount_rate: rate,
      unit: str(cell(r, cUnitName)) ?? split.unit ?? null,
      supplier_code: str(cell(r, cSupCode)) ?? split.supplier_code ?? null,
      upstream_code: str(cell(r, cUpstream)) ?? split.upstream_code ?? null,
      customer_code: str(cell(r, cCustomer)),
    });
  });

  // A totals row that slipped in as a line (請求金額 under the name column, a
  // tax figure in the quantity column …) is told by its sum: no JAN, no
  // quantity, no unit price, and an amount that is what the other lines add
  // up to — with or without tax, or the tax alone (0134).
  for (const l of dropTotalsLines(lines)) numbers.push(l.amount!);

  await applySplits(lines, useAi);
  checkLines(lines);
  return { columns, lines, header_row: headerRow + 1, totals: checkTotals(lines, { numbers }) };
}

// ---------------------------------------------------------------------------
// PDFs that carry their text: read it where it stands (0114)
// ---------------------------------------------------------------------------

/** Takes out of [lines] those that are the document's totals, not goods: no
 * JAN, no quantity, no unit price, and an amount equal to what the goods
 * lines add up to — as is, with 8% or 10% tax, or the tax alone. Returns
 * what it took out. */
export function dropTotalsLines(lines: ReadLine[]): ReadLine[] {
  const loose = (l: ReadLine) =>
    !l.raw_jan_code && !l.planned_quantity && l.unit_price === null && l.amount !== null && l.amount !== 0;
  const taken: ReadLine[] = [];
  for (let pass = 0; pass < 4; pass++) {
    const goods = lines.filter((l) => !loose(l));
    const base = goods.reduce((s, l) => s + (l.amount ?? 0), 0);
    if (base <= 0) break;
    const looks = [base, base * 1.1, base * 1.08, base * 0.1, base * 0.08];
    const at = lines.findIndex((l) => loose(l) && looks.some((v) => Math.abs(l.amount! - v) <= Math.max(1, v * 0.001)));
    if (at < 0) break;
    taken.push(...lines.splice(at, 1));
  }
  return taken;
}

type TextItem = { str: string; x0: number; x1: number; y: number };

/** A PDF's words with their positions, page after page, as lines of words
 * from the top. Null for a scan (no text to read). */
export async function pdfTextLines(bytes: Uint8Array): Promise<TextItem[][] | null> {
  let pdf;
  try {
    pdf = await getDocumentProxy(new Uint8Array(bytes));
  } catch (_) {
    return null;
  }
  const out: TextItem[][] = [];
  let count = 0;
  for (let n = 1; n <= pdf.numPages; n++) {
    const page = await pdf.getPage(n);
    const content = await page.getTextContent();
    const items: TextItem[] = [];
    for (const it of content.items as { str?: string; transform?: number[]; width?: number }[]) {
      const text = (it.str ?? "").trim();
      if (!text || !it.transform) continue;
      items.push({ str: text, x0: it.transform[4], x1: it.transform[4] + (it.width ?? 0), y: it.transform[5] });
    }
    count += items.length;
    items.sort((a, b) => b.y - a.y || a.x0 - b.x0);
    let line: TextItem[] = [];
    let y = Number.POSITIVE_INFINITY;
    for (const it of items) {
      if (Math.abs(it.y - y) > 3 && line.length) {
        out.push(line.sort((a, b) => a.x0 - b.x0));
        line = [];
      }
      if (!line.length) y = it.y;
      line.push(it);
    }
    if (line.length) out.push(line.sort((a, b) => a.x0 - b.x0));
  }
  return count >= 5 ? out : null;
}

/** The PDF's text as a table: the heading line we know best sets the
 * columns (each heading's middle, split halfway to the next), and every
 * word goes to the column its middle falls in. Null when no heading line is
 * found — the PDF is then read as a picture. */
export function pdfTable(lines: TextItem[][], aliases: AliasRow[]): { rows: unknown[][]; text: string } | null {
  let header: TextItem[] | null = null, best = 0;
  for (const l of lines) {
    const score = l.filter((it) => aliasFor(it.str, aliases) !== null).length;
    if (score > best) { best = score; header = l; }
  }
  if (!header || best < 3) return null;
  const centers = header.map((it) => (it.x0 + it.x1) / 2);
  // Between two headings, the line to split on is where the fewest words
  // below the heading cross it — in the widest empty gap. Text sits left in
  // a wide column and numbers sit right, so halfway is often wrong.
  const below = lines.slice(lines.indexOf(header) + 1).filter((l) => l.length >= 3).flat();
  const bounds = centers.slice(1).map((right, i) => {
    const left = centers[i];
    const edges = [left, right];
    for (const it of below) {
      if (it.x0 > left && it.x0 < right) edges.push(it.x0);
      if (it.x1 > left && it.x1 < right) edges.push(it.x1);
    }
    edges.sort((a, b) => a - b);
    let pick = (left + right) / 2, bestCross = Number.POSITIVE_INFINITY, bestGap = -1;
    for (let k = 0; k + 1 < edges.length; k++) {
      const gap = edges[k + 1] - edges[k];
      if (gap <= 0) continue;
      const mid = (edges[k] + edges[k + 1]) / 2;
      const cross = below.filter((it) => it.x0 < mid && it.x1 > mid).length;
      if (cross < bestCross || (cross === bestCross && gap > bestGap)) {
        bestCross = cross;
        bestGap = gap;
        pick = mid;
      }
    }
    return pick;
  });
  const columnOf = (it: TextItem) => {
    const mid = (it.x0 + it.x1) / 2;
    let i = 0;
    while (i < bounds.length && mid > bounds[i]) i++;
    return i;
  };
  const rows = lines.map((l) => {
    if (l === header) return header.map((it) => it.str);
    const cells: (string | null)[] = header!.map(() => null);
    for (const it of l) {
      const i = columnOf(it);
      cells[i] = cells[i] === null ? it.str : `${cells[i]} ${it.str}`;
    }
    return cells;
  });
  const fields = header.map((it) => aliasFor(it.str, aliases)?.field ?? null);
  return {
    rows: mergeCellFragments(rows, lines.indexOf(header), lines.map((l) => l[0]?.y ?? 0), fields),
    text: lines.map((l) => l.map((it) => it.str).join(" ")).join("\n"),
  };
}

const TEXT_FIELDS = new Set<Field>(["product_name", "maker", "spec", "name_code", "multi", "attr", "unit"]);

/** A sheet printed to PDF draws a merged cell (縦結合) once, at the middle
 * of the rows it spans: its quantity, price or amount lands on a line of its
 * own between the item's lines, and an item written on two lines (maker and
 * JAN above, name below) comes out as two. Lines that only complete the
 * item above — they fill none of the same columns, sit close, and are no
 * totals — are folded into it; so is a name wrapped onto a line of its own
 * under an item with a JAN or 品番. Lines above the heading stay as they
 * are. */
export function mergeCellFragments(
  rows: (string | null)[][],
  headerIndex: number,
  ys: number[],
  fields: (Field | null)[],
): (string | null)[][] {
  const body = rows.slice(headerIndex + 1);
  const bodyYs = ys.slice(headerIndex + 1);
  const gaps: number[] = [];
  for (let i = 1; i < bodyYs.length; i++) {
    const g = Math.abs(bodyYs[i] - bodyYs[i - 1]);
    if (g > 0) gaps.push(g);
  }
  gaps.sort((a, b) => a - b);
  const limit = gaps.length ? gaps[Math.floor(gaps.length / 2)] * 2.5 : Number.POSITIVE_INFINITY;
  const filled = (r: (string | null)[]) => new Set(r.flatMap((c, i) => (c !== null && c.trim() !== "" ? [i] : [])));
  const onlyText = (cols: Set<number>) =>
    [...cols].every((i) => fields[i] !== null && TEXT_FIELDS.has(fields[i]!) && fields[i] !== "multi" && fields[i] !== "name_code");
  const isTotal = (r: (string | null)[]) =>
    r.some((c) => c !== null && (TOTAL_ROW.test(c.normalize("NFKC").replace(/\s/g, "")) || SUMMARY_WORDS.test(c.normalize("NFKC"))));
  const out: (string | null)[][] = [];
  let last: { row: (string | null)[]; y: number; total: boolean } | null = null;
  body.forEach((r, i) => {
    const mine = filled(r);
    const total = isTotal(r);
    if (mine.size === 0) return;
    if (last && !last.total && !total && Math.abs(bodyYs[i] - last.y) <= limit) {
      const theirs = filled(last.row);
      const disjoint = [...mine].every((c) => !theirs.has(c));
      // A wrapped name: text only, under a line that has its JAN or 品番.
      const wrapped = !disjoint && onlyText(mine) &&
        [...theirs].some((c) => fields[c] === "jan" || fields[c] === "product_code");
      if (disjoint || wrapped) {
        r.forEach((c, k) => {
          if (c === null || c.trim() === "") return;
          last!.row[k] = last!.row[k] === null ? c : `${last!.row[k]} ${c}`;
        });
        last.y = bodyYs[i];
        return;
      }
    }
    const copy = [...r];
    out.push(copy);
    last = { row: copy, y: bodyYs[i], total };
  });
  return [...rows.slice(0, headerIndex + 1), ...out];
}

/** Our own company (0131): its names and 登録番号, so a document's other
 * company — the one that issued it — is taken as the supplier. */
export type OwnCompany = { names: string[]; registration_number: string | null };

const COMPANY_FORMS = /株式会社|有限会社|合同会社|合資会社|合名会社|\(株\)|\(有\)|㈱|㈲/g;

/** A company name reduced to what tells it apart: no 株式会社 or (株), no
 * 御中 or 様, no spaces or punctuation. */
export function companyKey(v: unknown): string {
  const t = String(v ?? "").normalize("NFKC").replace(COMPANY_FORMS, "").replace(/御中|様|殿/g, "");
  return normalizeText(t);
}

/** Whether [name] is ours, by any of our names. */
export function isOwnCompany(name: unknown, own: OwnCompany | null | undefined): boolean {
  const k = companyKey(name);
  if (!own || k.length < 2) return false;
  return own.names.some((n) => {
    const o = companyKey(n);
    return o.length >= 2 && (k === o || k.includes(o) || o.includes(k));
  });
}

const REG_NO = /T\s?-?\s?(\d{4})\s?-?\s?(\d{4})\s?-?\s?(\d{5})|T\s?(\d{13})/g;
const FORMS = "株式会社|有限会社|合同会社|合資会社|合名会社|\\(株\\)|\\(有\\)|㈱|㈲";
const NAME_CHARS = "[^\\s\\d〒:：,、()（）「」【】]";
const COMPANY_NAMES = new RegExp(
  `(?:${FORMS})\\s?${NAME_CHARS}{1,30}|${NAME_CHARS}{1,30}\\s?(?:${FORMS})`, "g",
);
/** Words that mark the one a document is addressed to (us). */
const ADDRESSEE = /^\s*(?:御中|様|殿|さま|宛)/;
/** Words near the company that issued it: its 登録番号, address, phone, seal. */
const ISSUER_CUES = /TEL|FAX|電話|〒|住所|担当|発行元?|販売元|出荷元|納入者|代表|印/i;
/** Lines that carry no company of their own. */
const NOT_A_NAME = /^(?:納品書|請求書|見積書|御見積書|注文書|発注書|出荷案内|明細書|控|合計|小計)$/;

/** The companies a document names, best guess for the issuer first (0132):
 * the one written 〇〇御中 / 様 is the addressee (us), ours by name or
 * 登録番号 is never the issuer, and the issuer is the one beside a 登録番号,
 * an address or a phone number. Works without our own name known. */
export function companiesIn(
  text: string, own: OwnCompany | null = null,
): { candidates: string[]; addressee: string | null } {
  const t = text.normalize("NFKC");
  const lines = t.split(/\n/);
  const ownReg = own?.registration_number?.replace(/[^0-9]/g, "") ?? "";
  const regAt = new Set<number>();
  const cueAt = new Set<number>();
  lines.forEach((l, i) => {
    for (const m of l.matchAll(REG_NO)) {
      const r = m[4] ?? `${m[1]}${m[2]}${m[3]}`;
      if (r !== ownReg) regAt.add(i);
    }
    if (ISSUER_CUES.test(l)) cueAt.add(i);
  });
  // Closer is likelier; a 登録番号 or address is usually printed under the
  // name it belongs to.
  const closeness = (set: Set<number>, i: number, below: number[], above: number[]) => {
    let best = 0;
    below.forEach((w, d) => { if (set.has(i + d)) best = Math.max(best, w); });
    above.forEach((w, d) => { if (set.has(i - d - 1)) best = Math.max(best, w); });
    return best;
  };
  const scored: { name: string; score: number; order: number }[] = [];
  let addressee: string | null = null;
  let order = 0;
  // 様 / 御中 printed on a line of its own, under the name it belongs to.
  const honorificBelow = (i: number) =>
    [1, 2].some((d) => /^\s*(?:御中|様|殿|さま)\s*$/.test(lines[i + d] ?? ""));
  lines.forEach((l, i) => {
    const found = [...l.matchAll(COMPANY_NAMES)];
    found.forEach((m, at) => {
      const name = m[0].trim();
      if (NOT_A_NAME.test(name) || companyKey(name).length < 2) return;
      const after = l.slice((m.index ?? 0) + m[0].length);
      const lastOnLine = at === found.length - 1 && after.trim() === "";
      if (ADDRESSEE.test(after) || /御中|様|殿/.test(name) || (lastOnLine && honorificBelow(i))) {
        addressee ??= name.replace(/\s*(?:御中|様|殿)\s*$/, "");
        return;
      }
      if (isOwnCompany(name, own)) return;
      let score = 0;
      score += closeness(regAt, i, [6, 5, 4, 2], [2, 1]);
      score += closeness(cueAt, i, [3, 3, 2, 1], [1]);
      if (/発行元?|販売元|出荷元|納入者/.test(l)) score += 2;
      scored.push({ name, score, order: order++ });
    });
  });
  // Our name on the document, wherever it stands, is the addressee.
  if (addressee) {
    for (let k = scored.length - 1; k >= 0; k--) {
      if (isOwnCompany(scored[k].name, { names: [addressee], registration_number: null })) scored.splice(k, 1);
    }
  }
  scored.sort((a, b) => b.score - a.score || a.order - b.order);
  const candidates: string[] = [];
  for (const s of scored) if (!candidates.some((c) => companyKey(c) === companyKey(s.name))) candidates.push(s.name);
  return { candidates, addressee };
}

/** What a text PDF (or the top of a sheet) says of itself, found by its
 * words. Our 登録番号 and our name are left out, the company written
 * 〇〇御中 is taken as the addressee, and the issuer — the one beside a
 * 登録番号, an address or a phone — as the supplier (0131, 0132). */
export function pdfHeaderFrom(text: string, own: OwnCompany | null = null): Header {
  const t = text.normalize("NFKC");
  const regs = [...t.matchAll(REG_NO)].map((m) => `T${m[4] ?? `${m[1]}${m[2]}${m[3]}`}`);
  const ownReg = own?.registration_number?.replace(/[^0-9]/g, "") ?? "";
  const reg = regs.find((r) => r.slice(1) !== ownReg) ?? null;
  const { candidates, addressee } = companiesIn(t, own);
  const date = t.match(/(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日/);
  const customer = t.match(/得意先\s*(?:No|NO|№|コード|CD|番号)?[\s.:：]*([0-9A-Za-z-]{3,})/);
  const doc = t.match(/(?:伝票|請求|納品|依頼)\s*(?:No|NO|№|番号)[\s.:：]*([0-9A-Za-z-]{3,})/);
  return {
    supplier_name: candidates[0] ?? null,
    registration_number: reg,
    customer_code: customer?.[1] ?? null,
    doc_number: doc?.[1] ?? null,
    doc_date: date ? `${date[1]}-${date[2].padStart(2, "0")}-${date[3].padStart(2, "0")}` : null,
    addressee,
    supplier_candidates: candidates,
  };
}

/** The companies a file's name gives ("20260819_株式会社アケボノクラウン_請求書.pdf"),
 * ours left out (0132). Many companies' files carry the issuer's name. */
export function companiesInFileName(fileName: string, own: OwnCompany | null = null): string[] {
  const base = fileName.normalize("NFKC").replace(/\.[A-Za-z0-9]{1,8}$/, "");
  const parts = base.split(/[_\-‐₋−–—,，\s　()\[\]【】]+/);
  const out: string[] = [];
  for (const p of parts) {
    for (const m of p.matchAll(COMPANY_NAMES)) {
      const name = m[0].trim();
      if (companyKey(name).length < 2 || isOwnCompany(name, own)) continue;
      if (!out.some((o) => companyKey(o) === companyKey(name))) out.push(name);
    }
  }
  return out;
}

/** Who issued a PDF or picture, read by the AI from the page itself — for a
 * document whose issuer is printed as a logo, so its text names only us
 * (0132). Null when nothing could be read. */
export async function readIssuer(
  bytes: Uint8Array, mime: string, own: OwnCompany | null = null,
): Promise<{ supplier_name: string | null; registration_number: string | null; addressee: string | null } | null> {
  try {
    const r = await gemini([{
      text:
        "この書類(納品書・請求書・入金依頼書・見積書など)を発行した会社の名前を読んでください。" +
        "会社名はロゴや画像で書かれていることがあります。ロゴ・社印・URL・メールアドレスのドメインも手がかりにしてください。" +
        "「〇〇御中」「〇〇様」と宛名になっている会社は受け取る側なので発行元ではありません。" +
        "issuer_name は発行元の正式な会社名(株式会社などを含めて)、registration_number は発行元の登録番号(T+13桁)、" +
        "addressee_name は宛名の会社名。分からない項目は空にすること。" + ownText(own),
    }, { inline_data: { mime_type: mime, data: encodeBase64(bytes) } }], {
      type: "object",
      properties: {
        issuer_name: { type: "string" },
        registration_number: { type: "string" },
        addressee_name: { type: "string" },
      },
    }, "issuer");
    const addressee = str(r.addressee_name)?.replace(/\s*(?:御中|様|殿)\s*$/, "") ?? null;
    const toUs = addressee ? { names: [addressee], registration_number: null } : null;
    let name = str(r.issuer_name);
    if (name && (isOwnCompany(name, own) || isOwnCompany(name, toUs))) name = null;
    return { supplier_name: name, registration_number: str(r.registration_number), addressee };
  } catch (_) {
    return null;
  }
}

/** Reads a PDF by its own text when it has some and a table we know
 * (exact, no AI reading needed); null when it must be read as a picture. */
export async function readPdfText(
  bytes: Uint8Array,
  aliases: AliasRow[],
  overrides: Record<number, string> = {},
  useAi = true,
  attributes: AttributeDef[] = [],
  own: OwnCompany | null = null,
): Promise<{ columns: Column[]; lines: ReadLine[]; header: Header; totals: Totals } | null> {
  const textLines = await pdfTextLines(bytes);
  if (!textLines) return null;
  const table = pdfTable(textLines, aliases);
  if (!table) return null;
  const read = await readRows(table.rows, aliases, overrides, useAi, attributes);
  const good = read.lines.filter((l) => janCheckOk(l.raw_jan_code) || l.product_code).length;
  if (read.header_row === 0 || read.lines.length === 0 || good * 2 < read.lines.length) return null;
  return { columns: read.columns, lines: read.lines, header: pdfHeaderFrom(table.text, own), totals: read.totals };
}

/** A combined 品名・品番 cell, or a name column with the 品番 inside it when the
 * sheet has no 品番 column, is split twice and compared. */
async function applySplits(lines: ReadLine[], useAi: boolean) {
  const targets: { line: ReadLine; text: string }[] = [];
  for (const l of lines) {
    if (l.split_by === "layout") continue;
    if (l.raw_name_code) targets.push({ line: l, text: l.raw_name_code });
    else if (!l.product_code && l.product_name && splitByRule(l.product_name)) {
      targets.push({ line: l, text: l.product_name });
    }
  }
  if (targets.length === 0) return;
  const parts: SplitResult[] = useAi
    ? await splitNameCodes(targets.map((t) => t.text))
    : targets.map((t): SplitResult => {
      const r = splitByRule(t.text);
      return r ? { name: r.name, code: r.code, by: "rule" } : { name: t.text, code: null, by: null };
    });
  targets.forEach((t, i) => {
    const p = parts[i];
    t.line.raw_name_code = t.text;
    t.line.product_name = p.name ?? t.line.product_name;
    t.line.product_code = t.line.product_code ?? p.code;
    t.line.split_by = p.by;
    if (p.alt) {
      t.line.flags.push("split_disagree");
      t.line.alternatives.product_name = p.alt.name;
      t.line.alternatives.product_code = p.alt.code;
    } else if (p.by === "rule" || p.by === "ai") {
      t.line.flags.push("split_single");
    } else if (p.by === null) {
      t.line.flags.push("split_failed");
    }
  });
}

/** The checks no AI is needed for. */
/** A JAN that went through a spreadsheet as a number shown in exponent form
 * ("4.90148E+12", or 4901480000000 after it was saved that way): its last
 * digits are gone, and no reading can bring them back. */
/** Excel shows a number of 12 digits or more in exponent form under the
 * "General" format (and under any format with E+ in it). */
export function janShownAsExponent(value: unknown, format: string | null): boolean {
  if (typeof value !== "number" || !Number.isFinite(value) || Math.abs(value) < 1e11) return false;
  // No format at all (a CSV) has no display to speak of.
  return format !== null && (/^general$/i.test(format) || /e\+/i.test(format));
}

/** The leading digits a JAN that lost its tail still has: "4.90148E+12" and
 * 4901480000000 both keep 490148. Null when nothing trustworthy is left. */
export function janSurvivingDigits(raw: unknown): string | null {
  const s = String(raw ?? "").normalize("NFKC").trim();
  const m = s.match(/^([0-9])(?:\.([0-9]+))?e\+?([0-9]+)$/i);
  const digits = m ? (m[1] + (m[2] ?? "")) : (/^[0-9]{13}$/.test(s) ? s : "");
  const kept = digits.replace(/0+$/, "");
  return kept.length >= 5 ? kept : null;
}

export function janLostDigits(raw: unknown): boolean {
  const s = String(raw ?? "").normalize("NFKC").trim();
  if (/^[0-9](\.[0-9]+)?e\+?[0-9]+$/i.test(s)) return true;
  return /^[0-9]{7,8}0{5,}$/.test(s) && s.length === 13 && !janCheckOk(s);
}

/** A match made on the 品番 alone, trusted enough to check a JAN against. */
export const CODE_MATCHES = new Set(["dialect_code", "sku"]);

/** The JAN checked against the 品番 on the same line (0113):
 *   * digits lost (jan_exponent) — the product the 品番 names is taken only
 *     when its JAN starts with the digits that survived (jan_restored, for a
 *     person to confirm); otherwise nothing is guessed (jan_restore_mismatch);
 *   * a JAN and a 品番 naming two different products — jan_code_mismatch. */
export function checkJan(
  l: Pick<ReadLine, "flags" | "raw_jan_code" | "jan_code">,
  product: Record<string, unknown> | null,
  matchedBy: string | null,
  codeProduct: Record<string, unknown> | null,
): { flag?: string; alternative?: string; restored?: Record<string, unknown>; drop?: boolean } {
  const describe = (p: Record<string, unknown>) => `${p.name ?? ""} (${p.jan_code ?? ""})`;
  if (l.flags.includes("jan_exponent")) {
    const prefix = janSurvivingDigits(l.raw_jan_code);
    const candidate = codeProduct ?? product;
    if (!candidate) return {};
    const jan = String(candidate.jan_code ?? "");
    if (prefix && jan.startsWith(prefix)) return { flag: "jan_restored", restored: candidate };
    return { flag: "jan_restore_mismatch", alternative: describe(candidate), drop: true };
  }
  if (product && codeProduct && (matchedBy === "jan" || matchedBy === "dialect_jan") &&
      codeProduct.id !== product.id) {
    return { flag: "jan_code_mismatch", alternative: describe(codeProduct) };
  }
  if (!product && codeProduct && l.raw_jan_code && !janCheckOk(l.raw_jan_code)) {
    // A JAN that fails its check digit, with a 品番 we know: say which.
    return { alternative: describe(codeProduct) };
  }
  return {};
}

export function checkLines(lines: ReadLine[]) {
  for (const l of lines) {
    if (l.raw_jan_code && janLostDigits(l.raw_jan_code)) {
      l.flags.push("jan_exponent");
      l.jan_code = "";
    } else if (l.raw_jan_code && !janCheckOk(l.raw_jan_code)) l.flags.push("jan_check");
    if (!l.raw_jan_code) l.flags.push("no_jan");
    // No quantity read, but an amount and a unit price that divide evenly:
    // the quantity is what they say, flagged for a person to see.
    if (!l.planned_quantity && l.amount && l.unit_price && l.unit_price > 0) {
      const q = l.amount / l.unit_price;
      if (Math.round(q) > 0 && Math.abs(q - Math.round(q)) < 0.01) {
        l.planned_quantity = Math.round(q);
        l.flags.push("qty_from_amount");
      }
    }
    if (!l.planned_quantity) l.flags.push("no_quantity");
    if (!l.maker) l.flags.push("no_maker");
    if (l.amount !== null && l.unit_price !== null && l.planned_quantity &&
        Math.abs(l.amount - l.unit_price * l.planned_quantity) > Math.max(1, l.amount * 0.01)) {
      l.flags.push("amount_mismatch");
      // What the amount says the quantity is, when it divides evenly.
      const q = l.unit_price > 0 ? l.amount / l.unit_price : 0;
      if (Math.round(q) > 0 && Math.abs(q - Math.round(q)) < 0.01) l.alternatives.planned_quantity = Math.round(q);
    }
  }
}

// ---------------------------------------------------------------------------
// PDF and photos: read, then read again to check
// ---------------------------------------------------------------------------

const LINE_PROPS = {
  jan_code: { type: "string" },
  maker: { type: "string" },
  product_name: { type: "string" },
  product_code: { type: "string" },
  name_code: { type: "string" },
  spec: { type: "string" },
  quantity: { type: "integer" },
  case_quantity: { type: "integer" },
  cases: { type: "integer" },
  unit_price: { type: "number" },
  amount: { type: "number" },
  tax_rate: { type: "number" },
  list_price: { type: "number" },
  discount_rate: { type: "number" },
  unit: { type: "string" },
  supplier_code: { type: "string" },
  upstream_code: { type: "string" },
  attributes: {
    type: "array",
    items: {
      type: "object",
      properties: { name: { type: "string" }, value: { type: "string" } },
      required: ["name", "value"],
    },
  },
};

const EXTRACT_PROMPT =
  "この画像/PDFは日本の取引先(商社)の納品書・出荷案内・注文明細です。商社ごとに書式も見出しの言葉" +
  "(日本語の漢字・カナ、英語)も違います。見出しの意味を理解して、次を返してください。\n" +
  "1) header: {supplier_name: 発行元の会社名(この書類を出した側。登録番号・住所・電話・社印の近くに書かれた会社。" +
  "「〇〇御中」「〇〇様」と宛名になっている会社は受け取る側なので入れない), addressee_name: 宛名の会社名(御中・様の付く側), " +
  "registration_number: 発行元のインボイス登録番号(T+13桁), " +
  "customer_code: お客様コード, doc_number: 伝票番号, doc_date: 日付(YYYY-MM-DD), " +
  "subtotal: 明細の税抜合計(今回お買上額・10%対象と8%対象の合計など), tax: 消費税額, total: 税込の合計(請求額)}。\n" +
  "2) columns: 表の見出しを左から順に {header: 見出しの文字どおり, field: 意味} で。field は " + FIELD_HELP + "。\n" +
  "3) lines: 明細の各行。jan_code は印字どおり(ハイフン・点・空白もそのまま、無ければ空)。maker はメーカー名を印字どおり。" +
  "品名と品番が1つの欄にまとめて書かれている場合は、その欄の文字をそのまま name_code に入れ、" +
  "さらに品名を product_name、品番を product_code に分けて入れる。別の欄ならそれぞれに。" +
  "quantity は総数(入数×ケース数の表記なら掛けた数)。case_quantity は入数、cases はケース数。" +
  "unit_price は実際の単価(見積単価・納品単価)、list_price は定価(上代)、discount_rate は掛率、unit は単位(本・冊・P など書かれたとおり)。" +
  "品番(メーカー品番・項目)とは別に取引先独自の商品コードの欄があれば supplier_code に。" +
  "仕入先コード(取引先の仕入先=メーカー等のコード)の欄があれば upstream_code に。" +
  "色・サイズ・容量・材質・重量など商品の属性が別の欄(または品名の後ろ)に書かれていれば、attributes に " +
  "{name: 見出しの文字どおり(カラー・Size など), value: 書かれた値} で入れる。" +
  "表に縦に結合されたセル(複数の行にまたがるセル)があるときは、その値は結合された範囲の商品のもの。" +
  "数量・単価・金額が行と行の間の高さに印字されていても、上下の別の商品ではなく、その結合範囲の商品の行に入れる。" +
  "1つの商品が2段(上段にメーカー・JAN、下段に品名など)に分かれて書かれていれば1行にまとめる。" +
  "数量は 金額÷単価 と合うか確かめ、合わなければ印字をもう一度読む。" +
  "住所・電話・登録番号・合計行は明細にしない。読めない項目は省略。";

const EXTRACT_SCHEMA = {
  type: "object",
  properties: {
    header: {
      type: "object",
      properties: {
        supplier_name: { type: "string" },
        addressee_name: { type: "string" },
        registration_number: { type: "string" },
        customer_code: { type: "string" },
        doc_number: { type: "string" },
        doc_date: { type: "string" },
        subtotal: { type: "number" },
        tax: { type: "number" },
        total: { type: "number" },
      },
    },
    columns: {
      type: "array",
      items: {
        type: "object",
        properties: {
          header: { type: "string" }, field: { type: "string", enum: FIELDS }, attribute: { type: "string" },
        },
        required: ["header", "field"],
      },
    },
    lines: { type: "array", items: { type: "object", properties: LINE_PROPS } },
  },
  required: ["lines"],
};

const VERIFY_PROMPT =
  "あなたは検品担当のダブルチェック役です。同じ画像/PDFを、別の担当者が読み取った結果(JSON)と見比べて、" +
  "1行ずつ確認してください。数字(JAN・数量・金額)は1桁ずつ、メーカー名・品名・品番は1文字ずつ確かめ、" +
  "間違いがあれば正しい値にしてください。読み漏れた行は追加し、存在しない行は削除してください。" +
  "品名と品番がまとめて書かれた欄は name_code にそのまま、分けた値を product_name/product_code に。" +
  "縦に結合されたセルの数量・単価・金額は、その結合範囲の商品の行のもの。数量が 金額÷単価 と合うかも確かめる。" +
  "各行に確認済みの印として index(元の行番号、追加した行は -1) を付けてください。\n読み取り結果:\n";

type RawLine = Record<string, unknown> & { index?: number };

/** The document's own attribute headings mapped to ours through the known
 * headings; what maps to none of ours stays in the 規格 text. */
function attributesOf(l: RawLine, aliases: AliasRow[]): { attrs: ReadAttribute[]; rest: string | null } {
  const attrs: ReadAttribute[] = [];
  const rest: string[] = [];
  for (const a of (Array.isArray(l.attributes) ? l.attributes : []) as { name?: unknown; value?: unknown }[]) {
    const name = str(a?.name), value = str(a?.value);
    if (!name || !value) continue;
    const hit = aliasFor(name, aliases);
    if (hit?.field === "attr" && hit.attribute) attrs.push({ key: hit.attribute, name, value });
    else rest.push(`${name}:${value}`);
  }
  return { attrs, rest: rest.length ? rest.join(" ") : null };
}

function rawToLine(l: RawLine, row: number, aliases: AliasRow[] = []): ReadLine {
  const { attrs, rest } = attributesOf(l, aliases);
  const rawJan = str(l.jan_code);
  const jan = normalizeJan(l.jan_code);
  return {
    row,
    jan_code: isJanLength(jan) ? jan : "",
    raw_jan_code: rawJan,
    maker: str(l.maker),
    product_name: str(l.product_name),
    product_code: str(l.product_code),
    raw_name_code: str(l.name_code),
    split_by: str(l.name_code) ? "ai" : null,
    spec: str(l.spec) ?? rest ?? specFrom(attrs),
    planned_quantity: toInt(l.quantity) ??
      ((toInt(l.cases) ?? 0) * (toInt(l.case_quantity) ?? 0) || 0),
    case_quantity: toInt(l.case_quantity),
    cases: toInt(l.cases),
    unit_price: toNum(l.unit_price),
    amount: toInt(l.amount),
    tax_rate: toNum(l.tax_rate),
    order_date: null,
    flags: [],
    alternatives: {},
    attributes: attrs,
    list_price: toNum(l.list_price),
    discount_rate: toRate(l.discount_rate),
    unit: str(l.unit),
    supplier_code: str(l.supplier_code),
    upstream_code: str(l.upstream_code),
    customer_code: null,
  };
}

const COMPARED: (keyof ReadLine)[] = [
  "raw_jan_code", "maker", "product_name", "product_code", "planned_quantity", "unit_price", "amount",
];

function same(a: unknown, b: unknown, k: keyof ReadLine): boolean {
  if (k === "raw_jan_code") return normalizeJan(a) === normalizeJan(b);
  if (typeof a === "number" || typeof b === "number") return (a ?? null) === (b ?? null);
  return normalizeText(a) === normalizeText(b);
}

/** Reads a PDF or photo twice — once to extract, once to check — and returns
 * lines flagged wherever the two readings differ. */
/** What is known of one company's documents (0114): what its headings mean
 * (learned, or corrected on this reading), how its combined cells split,
 * and its 書式メモ in plain words. */
export type ReadingHints = {
  columns?: { header: string; field: Field; parts?: Field[] | null; separator?: string | null }[];
  notes?: string | null;
};

const PART_WORDS: Partial<Record<Field, string>> = {
  jan: "JANコード", maker: "メーカー", product_name: "品名", product_code: "品番", spec: "規格",
  supplier_code: "取引先独自の商品コード", upstream_code: "仕入先コード", unit: "単位", ignore: "読まない記号",
  quantity: "数量", unit_price: "単価", amount: "金額", list_price: "定価", customer_code: "得意先コード",
};

/** The hints as words for the AI. */
export function hintText(h: ReadingHints): string {
  const out: string[] = [];
  for (const c of h.columns ?? []) {
    if (c.field === "multi" && (c.parts ?? []).length >= 2) {
      const sep = c.separator === "space" ? "空白" : (c.separator ? `「${c.separator}」` : "区切り記号か空白");
      out.push(`見出し『${c.header}』の欄は${sep}で区切って ${(c.parts ?? []).map((p) => PART_WORDS[p] ?? p).join("・")} の順に入っている。` +
        "欄の文字はそのまま name_code に入れること。");
    } else if (c.field === "ignore") {
      out.push(`見出し『${c.header}』の列は読まない。`);
    } else {
      out.push(`見出し『${c.header}』の列には ${PART_WORDS[c.field] ?? c.field}(${c.field}) が入っている。`);
    }
  }
  if (h.notes) out.push(`書式メモ: ${h.notes}`);
  return out.length ? "\nこの取引先の書類について、これまでの確認で分かっていること:\n- " + out.join("\n- ") + "\n" : "";
}

/** Our company for the AI: who receives the document, so the other company
 * named on it is the supplier (0131). */
export function ownText(own: OwnCompany | null): string {
  if (!own || own.names.length === 0) return "";
  return "\n当社(この書類を受け取る側・宛先・〇〇御中と書かれる側)は「" + own.names.join("」「") + "」" +
    (own.registration_number ? `(登録番号 ${own.registration_number})` : "") +
    "。header.supplier_name には当社ではない会社(書類を発行した側)の名前を、registration_number にはその会社の登録番号を入れる。" +
    "当社の名前や登録番号は入れない。\n";
}

export async function readDocument(
  bytes: Uint8Array,
  mime: string,
  aliases: AliasRow[] = [],
  hints: ReadingHints = {},
  own: OwnCompany | null = null,
): Promise<{ header: Header; columns: Column[]; lines: ReadLine[]; verified: boolean; totals: Totals }> {
  const doc = { inline_data: { mime_type: mime, data: encodeBase64(bytes) } };
  const known = hintText(hints);
  const a = await gemini([{ text: EXTRACT_PROMPT + ownText(own) + known }, doc], EXTRACT_SCHEMA, "extract");
  const aLines = (Array.isArray(a.lines) ? a.lines : []) as RawLine[];

  let bLines: RawLine[] | null = null;
  try {
    const b = await gemini(
      [{ text: known + VERIFY_PROMPT + JSON.stringify(aLines.map((l, i) => ({ index: i, ...l }))) }, doc],
      {
        type: "object",
        properties: {
          lines: {
            type: "array",
            items: { type: "object", properties: { index: { type: "integer" }, ...LINE_PROPS } },
          },
        },
        required: ["lines"],
      },
      "verify",
    );
    bLines = (Array.isArray(b.lines) ? b.lines : []) as RawLine[];
  } catch (_) {
    bLines = null;
  }

  const lines: ReadLine[] = [];
  if (bLines === null) {
    aLines.forEach((l, i) => {
      const line = rawToLine(l, i + 1, aliases);
      line.flags.push("not_verified");
      lines.push(line);
    });
  } else {
    const seen = new Set<number>();
    bLines.forEach((bl, i) => {
      const line = rawToLine(bl, i + 1, aliases);
      const idx = typeof bl.index === "number" ? bl.index : -1;
      const al = idx >= 0 ? aLines[idx] : undefined;
      if (!al) {
        line.flags.push("added_by_check");
      } else {
        seen.add(idx);
        const first = rawToLine(al, i + 1, aliases);
        for (const k of COMPARED) {
          if (!same(first[k], line[k], k)) {
            line.flags.push(`ai_disagree:${k}`);
            line.alternatives[k] = first[k] as string | number | null;
          }
        }
      }
      lines.push(line);
    });
    aLines.forEach((al, i) => {
      if (seen.has(i)) return;
      const line = rawToLine(al, lines.length + 1, aliases);
      line.flags.push("dropped_by_check");
      lines.push(line);
    });
  }

  // A combined cell the AI did not split gets the rule's try, and a split
  // the rule reads differently is flagged.
  // A combined cell whose layout we know is split by rule, not by guess:
  // what this company's heading was taught, else what the heading names.
  const cols = (Array.isArray(a.columns) ? a.columns : []) as { header?: string; field?: Field; attribute?: string }[];
  const layout = (hints.columns ?? []).find((c) => c.field === "multi" && (c.parts ?? []).length >= 2) ??
    cols.map((c) => ({ parts: headingParts(str(c.header) ?? "", aliases), separator: null as string | null }))
      .find((c) => c.parts !== null);
  if (layout?.parts) {
    for (const l of lines) {
      if (!l.raw_name_code) continue;
      const part = splitMulti(l.raw_name_code, layout.parts, layout.separator);
      if (!part.product_code && !part.maker && !part.product_name) continue;
      if (part.product_code && l.product_code && normalizeText(part.product_code) !== normalizeText(l.product_code)) {
        l.alternatives.product_code = l.product_code;
        if (!l.flags.includes("split_disagree")) l.flags.push("split_disagree");
      }
      l.maker = part.maker ?? l.maker;
      l.product_name = part.product_name ?? (layout.parts.includes("product_name") ? null : l.product_name);
      l.product_code = part.product_code ?? l.product_code;
      if (!l.raw_jan_code && part.jan) {
        l.raw_jan_code = part.jan;
        const jan = normalizeJan(part.jan);
        l.jan_code = isJanLength(jan) ? jan : "";
      }
      l.split_by = "layout";
    }
  }
  for (const l of lines) {
    if (!l.raw_name_code || l.split_by === "layout") continue;
    const r = splitByRule(l.raw_name_code);
    if (!l.product_name && !l.product_code && r) {
      l.product_name = r.name;
      l.product_code = r.code;
      l.split_by = "rule";
      l.flags.push("split_single");
    } else if (r && (normalizeText(r.code) !== normalizeText(l.product_code) ||
                     normalizeText(r.name) !== normalizeText(l.product_name))) {
      l.flags.push("split_disagree");
      l.alternatives.product_name = r.name;
      l.alternatives.product_code = r.code;
    } else if (r) {
      l.split_by = "both";
    }
  }
  // A totals row the reading took for goods is set aside as a figure (0134).
  const totalsRows = dropTotalsLines(lines).map((l) => l.amount!);
  checkLines(lines);

  const h = (a.header ?? {}) as Record<string, unknown>;
  const totals = checkTotals(lines, {
    subtotal: toNum(h.subtotal), tax: toNum(h.tax), total: toNum(h.total), numbers: totalsRows,
  });
  // Ours is never the supplier, whatever the reading put there; nor is the
  // company the document is addressed to (0132).
  const addressee = str(h.addressee_name)?.replace(/\s*(?:御中|様|殿)\s*$/, "") ?? null;
  const toUs = addressee ? { names: [addressee], registration_number: null } : null;
  const supplierName = isOwnCompany(h.supplier_name, own) || isOwnCompany(h.supplier_name, toUs) ||
      /御中|様$|殿$/.test(str(h.supplier_name) ?? "")
    ? null
    : str(h.supplier_name);
  const ownReg = own?.registration_number?.replace(/[^0-9]/g, "") ?? "";
  const regNo = str(h.registration_number);
  return {
    header: {
      supplier_name: supplierName,
      registration_number: regNo && ownReg && regNo.replace(/[^0-9]/g, "") === ownReg ? null : regNo,
      customer_code: str(h.customer_code),
      doc_number: str(h.doc_number),
      doc_date: str(h.doc_date),
      addressee,
      supplier_candidates: supplierName ? [supplierName] : [],
    },
    columns: cols.map((c, i) => {
      // An attribute heading is placed through our known headings, not the AI's guess.
      const hit = c.field === "attr" ? aliasFor(str(c.header) ?? "", aliases) : null;
      const attribute = hit?.field === "attr" ? hit.attribute : null;
      const field = FIELDS.includes(c.field as Field) && (c.field !== "attr" || attribute) ? c.field! : null;
      return { index: i, header: str(c.header) ?? "", field, attribute, source: "ai" as const };
    }),
    lines,
    verified: bLines !== null,
    totals,
  };
}
