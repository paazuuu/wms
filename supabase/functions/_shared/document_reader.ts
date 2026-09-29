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

export type Field =
  | "jan" | "maker" | "product_name" | "product_code" | "name_code"
  | "quantity" | "case_quantity" | "cases" | "unit_price" | "amount"
  | "spec" | "tax_rate" | "order_date" | "ignore" | "attr";

export const FIELDS: Field[] = [
  "jan", "maker", "product_name", "product_code", "name_code", "quantity",
  "case_quantity", "cases", "unit_price", "amount", "spec", "tax_rate",
  "order_date", "ignore", "attr",
];

/** A column heading we know. For field 'attr', [attribute] says which of our
 * product attributes (0110: color, size, capacity, …) the column holds. */
export type AliasRow = { header_key: string; field: Field; partner: boolean; attribute?: string | null };

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
};

export type ReadLine = {
  row: number;
  jan_code: string;          // normalized, "" when none
  raw_jan_code: string | null;
  maker: string | null;
  product_name: string | null;
  product_code: string | null;
  raw_name_code: string | null;
  split_by: "rule" | "ai" | "both" | null;
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
};

export type Header = {
  supplier_name: string | null;
  registration_number: string | null;
  customer_code: string | null;
  doc_number: string | null;
  doc_date: string | null;
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
  if (v === null || v === undefined || String(v).trim() === "") return null;
  const n = Number(String(v).normalize("NFKC").replace(/[^\d.-]/g, ""));
  return Number.isFinite(n) ? Math.round(n) : null;
}
export function toNum(v: unknown): number | null {
  if (v === null || v === undefined || String(v).trim() === "") return null;
  const n = Number(String(v).normalize("NFKC").replace(/[^\d.-]/g, ""));
  return Number.isFinite(n) ? n : null;
}
function dateStr(v: unknown): string | null {
  if (v === null || v === undefined || v === "") return null;
  if (v instanceof Date) return v.toISOString().slice(0, 10);
  return String(v).trim();
}

// ---------------------------------------------------------------------------
// The AI (Gemini), with retries on overload
// ---------------------------------------------------------------------------

export async function gemini(
  parts: unknown[],
  schema: unknown,
): Promise<Record<string, unknown>> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) throw new Error("GEMINI_API_KEY is not set on the server.");
  const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.8-flash";
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
  for (let attempt = 0; attempt < 4; attempt++) {
    res = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
      body: JSON.stringify(payload),
    });
    if (res.status !== 503 && res.status !== 429) break;
    if (attempt < 3) await new Promise((r) => setTimeout(r, 700 * (attempt + 1)));
  }
  if (!res || !res.ok) {
    throw new Error(`Gemini error ${res ? res.status : "?"}: ${res ? await res.text() : ""}`);
  }
  const body = await res.json();
  const text = body?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
  try {
    return JSON.parse(text);
  } catch (_) {
    return {};
  }
}

const FIELD_HELP =
  "jan=JANコード/バーコード, maker=メーカー/ブランド, product_name=品名/商品名, " +
  "product_code=品番/型番/項目/商品コード, name_code=品名と品番が1つの欄に入っている, " +
  "quantity=数量(総数), case_quantity=入数, cases=ケース数/箱数, unit_price=単価, " +
  "amount=金額, spec=規格/仕様, tax_rate=税率, order_date=日付, " +
  "attr=色・サイズ・容量・材質・重量など商品の属性(どの属性かを attribute に), ignore=その他";

/** "attr:color" as an override or wire value → field and attribute. */
export function splitAttr(v: string): { field: Field; attribute: string | null } | null {
  if (v.startsWith("attr:")) return v.length > 5 ? { field: "attr", attribute: v.slice(5) } : null;
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
      });
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

export function aliasFor(
  header: string,
  aliases: AliasRow[],
): { field: Field; source: Column["source"]; attribute: string | null } | null {
  const key = normalizeText(header);
  if (!key) return null;
  const exact = aliases.filter((a) => a.header_key === key);
  const partner = exact.find((a) => a.partner);
  if (partner) return { field: partner.field, source: "partner", attribute: partner.attribute ?? null };
  if (exact.length) return { field: exact[0].field, source: "global", attribute: exact[0].attribute ?? null };
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
              field: { type: "string", enum: attributes.length ? FIELDS : FIELDS.filter((f) => f !== "attr") },
              ...(attributes.length ? { attribute: { type: "string", enum: attributes.map((a) => a.key) } } : {}),
            },
            required: ["index", "field"],
          },
        },
      },
      required: ["columns"],
    });
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

const TOTAL_ROW = /^(合計|小計|総合計|計|total|subtotal|grand ?total)$/i;

/** Reads the first sheet of an Excel or CSV file. [overrides] maps a column
 * index to a field when the operator corrected the reading. */
export async function readSpreadsheet(
  bytes: Uint8Array,
  aliases: AliasRow[],
  overrides: Record<number, string> = {},
  useAi = true,
  attributes: AttributeDef[] = [],
): Promise<{ columns: Column[]; lines: ReadLine[]; header_row: number }> {
  const wb = XLSX.read(bytes, { type: "array", cellDates: true });
  const ws = wb.Sheets[wb.SheetNames[0]];
  const rows = XLSX.utils.sheet_to_json(ws, { header: 1, raw: true, defval: null }) as unknown[][];
  const ncol = rows.reduce((m, r) => Math.max(m, r.length), 0);

  // The heading row: the one most of whose cells are headings we know.
  let headerRow = -1, bestScore = 0;
  for (let ri = 0; ri < Math.min(rows.length, 40); ri++) {
    const score = (rows[ri] ?? []).filter((c) =>
      typeof c === "string" && aliasFor(c, aliases) !== null
    ).length;
    if (score > bestScore) { bestScore = score; headerRow = ri; }
  }
  if (bestScore < 2) headerRow = -1;
  const headerCells = headerRow >= 0 ? rows[headerRow] : [];
  const body = rows.slice(headerRow + 1);

  const columns: Column[] = [];
  for (let c = 0; c < ncol; c++) {
    const header = str(headerCells[c]) ?? "";
    const hit = header ? aliasFor(header, aliases) : null;
    columns.push({
      index: c, header, field: hit?.field ?? null, source: hit?.source ?? null,
      attribute: hit?.field === "attr" ? hit.attribute : null,
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
      } else if (col.field && a && (a.field !== col.field || a.attribute !== (col.attribute ?? null)) &&
                 col.source !== "partner") {
        col.conflict = true;
      }
    }
  }
  for (const [k, v] of Object.entries(overrides)) {
    const i = Number(k);
    const o = splitAttr(v);
    if (columns[i] && o) {
      columns[i] = { ...columns[i], field: o.field, attribute: o.attribute, source: "override", conflict: false };
    }
  }

  const colOf = (f: Field) => columns.find((c) => c.field === f)?.index ?? -1;
  const cell = (r: unknown[], c: number) => (c >= 0 && c < r.length ? r[c] : null);
  const cJan = colOf("jan"), cMaker = colOf("maker"), cName = colOf("product_name");
  const cCode = colOf("product_code"), cNameCode = colOf("name_code"), cQty = colOf("quantity");
  const cCaseQty = colOf("case_quantity"), cCases = colOf("cases"), cUnit = colOf("unit_price");
  const cAmount = colOf("amount"), cSpec = colOf("spec"), cTax = colOf("tax_rate");
  const cDate = colOf("order_date");
  // Every attribute column, however many (色 and サイズ side by side).
  const attrCols = columns.filter((c) => c.field === "attr" && c.attribute);

  const lines: ReadLine[] = [];
  body.forEach((r, i) => {
    if (!r.some((c) => c !== null && String(c).trim() !== "")) return;
    const first = str(r.find((c) => str(c) !== null));
    if (first && TOTAL_ROW.test(first.normalize("NFKC").replace(/\s/g, ""))) return;
    const rawJan = str(cell(r, cJan));
    const jan = normalizeJan(cell(r, cJan));
    const name = str(cell(r, cName));
    const code = str(cell(r, cCode));
    const nameCode = str(cell(r, cNameCode));
    if (!rawJan && !name && !code && !nameCode) return;
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
    lines.push({
      row: headerRow + 2 + i,
      jan_code: isJanLength(jan) ? jan : "",
      raw_jan_code: rawJan,
      maker: str(cell(r, cMaker)),
      product_name: name,
      product_code: code,
      raw_name_code: nameCode,
      split_by: null,
      spec: str(cell(r, cSpec)) ?? specFrom(attrs),
      planned_quantity: qty ?? 0,
      case_quantity: caseQty,
      cases,
      unit_price: toInt(cell(r, cUnit)),
      amount: toInt(cell(r, cAmount)),
      tax_rate: toNum(cell(r, cTax)),
      order_date: dateStr(cell(r, cDate)),
      flags,
      alternatives: {},
      attributes: attrs,
    });
  });

  await applySplits(lines, useAi);
  checkLines(lines);
  return { columns, lines, header_row: headerRow + 1 };
}

/** A combined 品名・品番 cell, or a name column with the 品番 inside it when the
 * sheet has no 品番 column, is split twice and compared. */
async function applySplits(lines: ReadLine[], useAi: boolean) {
  const targets: { line: ReadLine; text: string }[] = [];
  for (const l of lines) {
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
export function checkLines(lines: ReadLine[]) {
  for (const l of lines) {
    if (l.raw_jan_code && !janCheckOk(l.raw_jan_code)) l.flags.push("jan_check");
    if (!l.raw_jan_code) l.flags.push("no_jan");
    if (!l.planned_quantity) l.flags.push("no_quantity");
    if (!l.maker) l.flags.push("no_maker");
    if (l.amount !== null && l.unit_price !== null && l.planned_quantity &&
        Math.abs(l.amount - l.unit_price * l.planned_quantity) > Math.max(1, l.amount * 0.01)) {
      l.flags.push("amount_mismatch");
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
  "1) header: {supplier_name: 発行元の会社名, registration_number: インボイス登録番号(T+13桁), " +
  "customer_code: お客様コード, doc_number: 伝票番号, doc_date: 日付(YYYY-MM-DD)}。\n" +
  "2) columns: 表の見出しを左から順に {header: 見出しの文字どおり, field: 意味} で。field は " + FIELD_HELP + "。\n" +
  "3) lines: 明細の各行。jan_code は印字どおり(ハイフン・点・空白もそのまま、無ければ空)。maker はメーカー名を印字どおり。" +
  "品名と品番が1つの欄にまとめて書かれている場合は、その欄の文字をそのまま name_code に入れ、" +
  "さらに品名を product_name、品番を product_code に分けて入れる。別の欄ならそれぞれに。" +
  "quantity は総数(入数×ケース数の表記なら掛けた数)。case_quantity は入数、cases はケース数。" +
  "色・サイズ・容量・材質・重量など商品の属性が別の欄(または品名の後ろ)に書かれていれば、attributes に " +
  "{name: 見出しの文字どおり(カラー・Size など), value: 書かれた値} で入れる。" +
  "住所・電話・登録番号・合計行は明細にしない。読めない項目は省略。";

const EXTRACT_SCHEMA = {
  type: "object",
  properties: {
    header: {
      type: "object",
      properties: {
        supplier_name: { type: "string" },
        registration_number: { type: "string" },
        customer_code: { type: "string" },
        doc_number: { type: "string" },
        doc_date: { type: "string" },
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
    unit_price: toInt(l.unit_price),
    amount: toInt(l.amount),
    tax_rate: toNum(l.tax_rate),
    order_date: null,
    flags: [],
    alternatives: {},
    attributes: attrs,
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
export async function readDocument(
  bytes: Uint8Array,
  mime: string,
  aliases: AliasRow[] = [],
): Promise<{ header: Header; columns: Column[]; lines: ReadLine[]; verified: boolean }> {
  const doc = { inline_data: { mime_type: mime, data: encodeBase64(bytes) } };
  const a = await gemini([{ text: EXTRACT_PROMPT }, doc], EXTRACT_SCHEMA);
  const aLines = (Array.isArray(a.lines) ? a.lines : []) as RawLine[];

  let bLines: RawLine[] | null = null;
  try {
    const b = await gemini(
      [{ text: VERIFY_PROMPT + JSON.stringify(aLines.map((l, i) => ({ index: i, ...l }))) }, doc],
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
  for (const l of lines) {
    if (!l.raw_name_code) continue;
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
  checkLines(lines);

  const h = (a.header ?? {}) as Record<string, unknown>;
  const cols = (Array.isArray(a.columns) ? a.columns : []) as { header?: string; field?: Field; attribute?: string }[];
  return {
    header: {
      supplier_name: str(h.supplier_name),
      registration_number: str(h.registration_number),
      customer_code: str(h.customer_code),
      doc_number: str(h.doc_number),
      doc_date: str(h.doc_date),
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
  };
}
