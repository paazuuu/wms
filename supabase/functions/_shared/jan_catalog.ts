// Reading a maker's catalog (a mediapress iCata viewer) for its JAN codes.
//
// The viewer serves each page's text as one <text> element per character,
// with where it sits (x, y, w, h). Characters on one line share a y; a wide
// gap between two of them is a column break. A catalog's price table prints
// a 品番 (or its end: MAB-F, B-EF) in one column and the JAN in another,
// often as 49-02505-625923. So: lines from the characters, columns from the
// gaps, and each JAN kept with the column just before it.

export type CatalogRef = {
  host: string;
  volumeId: string;
  catalogId: string;
  designId: string;
};

/** The catalog a viewer URL opens, or null for a URL that is not one. Only
 * mediapress hosts: the function fetches from what this returns. */
export function parseCatalogUrl(raw: string): CatalogRef | null {
  let u: URL;
  try {
    u = new URL(raw.trim());
  } catch {
    return null;
  }
  if (u.protocol !== "https:") return null;
  if (!/^[a-z0-9-]+\.mediapress-net\.com$/.test(u.hostname)) return null;
  const p = (k: string) => {
    for (const [key, v] of u.searchParams) if (key.toLowerCase() === k.toLowerCase()) return v.trim();
    return "";
  };
  const volumeId = p("volumeID"), catalogId = p("catalogId"), designId = p("designID");
  if (!/^[A-Za-z0-9_]+$/.test(volumeId) || !/^[0-9]+$/.test(catalogId)) return null;
  if (designId && !/^[A-Za-z0-9_]+$/.test(designId)) return null;
  return { host: u.hostname, volumeId, catalogId, designId };
}

export type PageRef = { id: string; group: string; number: string };

/** A meclib e-book (Kobe Ecole's catalog library and others): its host and
 * book id, from a URL such as https://ecole-rg.meclib.jp/zebra2026/book/. */
export type MeclibRef = { host: string; book: string };

export function parseMeclibUrl(raw: string): MeclibRef | null {
  let u: URL;
  try {
    u = new URL(raw.trim());
  } catch {
    return null;
  }
  if (u.protocol !== "https:" || !/^[a-z0-9-]+\.meclib\.jp$/.test(u.hostname)) return null;
  const m = /^\/(?:library\/books\/)?([A-Za-z0-9_-]+)\/book(?:\/|$)/.exec(u.pathname);
  if (!m) return null;
  return { host: u.hostname, book: m[1] };
}

/** The book's folder on its host (where book.txt, txtsearch.txt, pdf/ are). */
export function meclibBase(r: MeclibRef): string {
  return `https://${r.host}/${r.book}/book/`;
}

/** What a meclib book.txt says: its title, and what a PC browser may have
 * of it (the first of each five-way setting): a page's PDF, text search. */
export function meclibInfo(json: unknown): { title: string | null; pdfAllowed: boolean; textAllowed: boolean } {
  // deno-lint-ignore no-explicit-any
  const j = json as any;
  const first = (k: string) => (Array.isArray(j?.[k]) ? String(j[k][0]) : "0");
  return {
    title: typeof j?.title === "string" && j.title.trim() ? j.title.trim() : null,
    pdfAllowed: first("pdf") === "1",
    // Its text search, which is what is read.
    textAllowed: first("txtsearch") === "1",
  };
}

/** A book that prints only a JAN's end, saying what goes before it: 「下6ケ
 * タを表記…前に4904085をつけて」, 「上7ケタ(4902580)は省略」, 「メーカーコードは
 * 4971760」, 「JAN(共通457116336)下4桁」. Its lists then run the ends together
 * (388126388133388140…). A run is taken as JANs only when it splits evenly
 * into ends and every one makes a JAN with a good check digit — at least
 * three of them, or two just after the word JAN. */
function abbreviatedJans(lines: string[]): { jan: string; page: number; at: number; alone: boolean; line: string }[] {
  const all = lines.join("\n");
  const prefixes = new Set<string>();
  const declared =
    /(?:上\s*[7７]\s*(?:桁|ケタ)|メーカーコード|共通|省略|前に)[^0-9\n]{0,20}?(4[59][0-9]{5}(?:[0-9]{2})?)(?![0-9])|(?<![0-9])(4[59][0-9]{5}(?:[0-9]{2})?)(?![0-9])[^0-9\n]{0,6}(?:を(?:つけ|付け)|は(?:共通|省略))/g;
  for (const m of all.matchAll(declared)) prefixes.add(m[1] ?? m[2]);
  const out: { jan: string; page: number; at: number; alone: boolean; line: string }[] = [];
  for (const prefix of prefixes) {
    const len = 13 - prefix.length;
    lines.forEach((line, i) => {
      for (const m of line.matchAll(/[0-9]+/g)) {
        const run = m[0];
        if (run.length % len !== 0 || run.length / len < 2) continue;
        const jans: string[] = [];
        for (let k = 0; k < run.length; k += len) jans.push(prefix + run.slice(k, k + len));
        if (!jans.every(validJan)) continue;
        const at = m.index ?? 0;
        if (jans.length < 3 && !/JAN/.test(line.slice(Math.max(0, at - 80), at))) continue;
        for (const jan of jans) out.push({ jan, page: i + 1, at, alone: true, line });
      }
    });
  }
  return out;
}

/** The JANs in a meclib book's search text (txtsearch.txt, a line a page),
 * with the page and the text around each. That text runs digits together
 * (4901681773138商品コード:8642314901681773145…), so a JAN is taken:
 *   * standing alone (no digit either side) with a good check digit, or
 *   * inside a run of digits only when its first 7 digits (the maker's GS1
 *     prefix) are a prefix the book shows standing alone at least twice —
 *     13 digits inside a run with a known prefix and a good check digit do
 *     not happen by chance.
 * No weight: without where things sit, a weight cannot be put to its JAN. */
export function meclibTextEntries(txtsearch: string): CatalogEntry[] {
  const lines = txtsearch.split("\n");
  const clean = new Map<string, number>();
  const found: { jan: string; page: number; at: number; alone: boolean; line: string }[] = [];
  lines.forEach((line, i) => {
    for (const m of line.matchAll(/(?=(4[59][0-9]{11}))/g)) {
      const at = m.index ?? 0;
      const jan = m[1];
      if (!validJan(jan)) continue;
      const alone = !/[0-9]/.test(line[at - 1] ?? "") && !/[0-9]/.test(line[at + 13] ?? "");
      if (alone) clean.set(jan.slice(0, 7), (clean.get(jan.slice(0, 7)) ?? 0) + 1);
      found.push({ jan, page: i + 1, at, alone, line });
    }
    for (const m of line.matchAll(JAN_RE)) {
      const jan = m[1].replace(/[^0-9]/g, "");
      if (/^[0-9]{13}$/.test(m[1]) || !validJan(jan)) continue;
      clean.set(jan.slice(0, 7), (clean.get(jan.slice(0, 7)) ?? 0) + 1);
      found.push({ jan, page: i + 1, at: m.index ?? 0, alone: true, line });
    }
  });
  found.push(...abbreviatedJans(lines));
  const known = new Set([...clean].filter(([, n]) => n >= 2).map(([p]) => p));
  const out: CatalogEntry[] = [];
  for (const f of found) {
    if (!f.alone && !known.has(f.jan.slice(0, 7))) continue;
    out.push({
      jan: f.jan,
      code_hint: null,
      line_text: f.line.slice(Math.max(0, f.at - 80), f.at + 40).replace(/\s+/g, " ").trim(),
      page_number: String(f.page),
      page_group: String(f.page),
      weight_g: null,
      weight_text: null,
      weight_basis: null,
    });
  }
  return uniqueEntries(out);
}

/** The pages (from 1) whose search text has a JAN's digits in it: one line a
 * page in txtsearch.txt. Digits run on there (4901681773138商品コード:864231…),
 * so this only says where to look; the page's PDF says what is there. */
export function meclibJanPages(txtsearch: string): number[] {
  const out: number[] = [];
  txtsearch.split("\n").forEach((line, i) => {
    if (/4[59][0-9]{11}|4[59][-‐－ ][0-9]{5}[-‐－ ][0-9]{6}|4[59][0-9]{5}[-‐－ ][0-9]{6}/.test(line)) out.push(i + 1);
  });
  return out;
}

/** The pages a search result names (each <page> with its id, group, number). */
export function pagesFromSearch(xml: string): { total: number; pages: PageRef[] } {
  const total = Number(/<response[^>]*\btotal="(\d+)"/.exec(xml)?.[1] ?? 0);
  const pages: PageRef[] = [];
  for (const m of xml.matchAll(/<page>([\s\S]*?)<\/page>/g)) {
    const body = m[1];
    const id = /^\s*<id>(\d+)<\/id>/.exec(body)?.[1];
    if (!id) continue;
    pages.push({
      id,
      group: /<groupid>([^<]*)<\/groupid>/.exec(body)?.[1] ?? "",
      number: /<number>([^<]*)<\/number>/.exec(body)?.[1] ?? "",
    });
  }
  return { total, pages };
}

/** A run of text on a page: one character (the iCata viewer) or a few (a
 * PDF's text item), where it starts, how wide, and its line's y — growing
 * down the page. */
export type TextItem = { x: number; y: number; w: number; t: string };

/** A column's text on one line, with where it spans. */
export type Segment = { x0: number; x1: number; y: number; text: string };

/** The viewer's <text> elements as items. */
export function itemsFromXml(xml: string): TextItem[] {
  const out: TextItem[] = [];
  for (const m of xml.matchAll(/<text\s([^>]*)><!\[CDATA\[([\s\S]*?)\]\]><\/text>/g)) {
    const a: Record<string, number> = {};
    for (const [, k, v] of m[1].matchAll(/(\w+)="([^"]*)"/g)) a[k] = Number(v);
    if (!Number.isFinite(a.x) || !Number.isFinite(a.y)) continue;
    out.push({ x: a.x, y: a.y, w: Number.isFinite(a.w) ? a.w : 0, t: m[2] });
  }
  return out;
}

/** Items into lines, top to bottom, each line into its columns: a gap wider
 * than 12pt is a column, a smaller one a space. */
export function segmentRows(items: TextItem[]): Segment[][] {
  // A run of spaces (a PDF's spacer) would join two columns: left out.
  const sorted = items.filter((i) => i.t.trim().length > 0).sort((a, b) => a.y - b.y || a.x - b.x);
  const rows: TextItem[][] = [];
  for (const c of sorted) {
    const row = rows[rows.length - 1];
    if (row && Math.abs(c.y - row[0].y) <= 1.5) row.push(c);
    else rows.push([c]);
  }
  return rows
    .map((row) => {
      row.sort((a, b) => a.x - b.x);
      const segs: Segment[] = [];
      let cur: Segment | null = null;
      for (const c of row) {
        const gap = cur ? c.x - cur.x1 : 0;
        if (cur && gap > 12) {
          segs.push(cur);
          cur = null;
        }
        if (!cur) {
          cur = { x0: c.x, x1: c.x + c.w, y: row[0].y, text: c.t };
        } else {
          cur.text += (gap > 2 ? " " : "") + c.t;
          cur.x1 = Math.max(cur.x1, c.x + c.w);
        }
      }
      if (cur) segs.push(cur);
      return segs
        .map((g) => ({ ...g, text: g.text.replace(/\s+/g, " ").trim() }))
        .filter((g) => g.text.length > 0);
    })
    .filter((r) => r.length > 0);
}

/** A page's text as lines, top to bottom, each split into its columns. */
export function pageLines(xml: string): string[][] {
  return segmentRows(itemsFromXml(xml)).map((r) => r.map((g) => g.text));
}

/** A JAN (EAN-13) whose check digit adds up. */
export function validJan(jan: string): boolean {
  if (!/^\d{13}$/.test(jan)) return false;
  let sum = 0;
  for (let i = 0; i < 12; i++) sum += Number(jan[i]) * (i % 2 === 0 ? 1 : 3);
  return (10 - (sum % 10)) % 10 === Number(jan[12]);
}

// A Japanese (45/49) JAN as catalogs print it, and only so: 13 digits
// together (4902505625923), 2-5-6 (49-02505-625923, Pilot), 7-6 (4901991
// 901115, Tombow), or the barcode's 1-6-6 (4 901991 901115). A looser
// pattern took runs of short codes (498-33 498-34 …) for JANs whenever
// their digits happened to add up.
const SEP = "[-‐－ ]";
const JAN_RE = new RegExp(
  `(?<![0-9]|[0-9][-‐－])(4[59][0-9]{11}|4[59]${SEP}[0-9]{5}${SEP}[0-9]{6}|4[59][0-9]{5}${SEP}[0-9]{6}|4 [59][0-9]{5} [0-9]{6})(?![0-9]|[-‐－][0-9])`,
  "g",
);

/** What is left of [text] after the last JAN in it. */
function afterLastJan(text: string): string {
  let end = 0;
  for (const m of text.matchAll(JAN_RE)) end = (m.index ?? 0) + m[0].length;
  return text.slice(end).trim();
}

export type WeightBasis = "product" | "package" | "pack";

export type CatalogEntry = {
  jan: string;
  code_hint: string | null;
  line_text: string;
  page_number: string;
  page_group: string;
  weight_g?: number | null;
  weight_text?: string | null;
  weight_basis?: WeightBasis | null;
};

/** A weight printed on a page, and where. */
export type PageWeight = { x0: number; x1: number; y: number; g: number; text: string; basis: WeightBasis };

const LABELLED = /(?:重\s*量|質\s*量|重\s*さ)\s*[：:]?\s*約?\s*([0-9]+(?:\.[0-9]+)?)\s*(kg|ｋｇ|g|ｇ)(?![a-zA-Zａ-ｚ])/;
// 55×15×191mm/20g, under a heading that says it is a weight.
const AFTER_SIZE = /(?:mm|㎜)\s*[\/／]\s*約?\s*([0-9]+(?:\.[0-9]+)?)\s*(kg|ｋｇ|g|ｇ)(?![a-zA-Zａ-ｚ])/;
const NOT_THE_ITEM = /物流|ケース|カートン|梱包単位|外箱/;
// A weight of several together (a box, a dozen, 10本入): not one item's,
// and the count is not always there to divide by — left out.
const SEVERAL = /箱|ダース|ケース|カートン|入数|[0-9０-９]+\s*(?:本|個|枚|冊|コ|ヶ|袋|パック)\s*入/;

function overlap(a: { x0: number; x1: number }, b: { x0: number; x1: number }): number {
  return Math.min(a.x1, b.x1) - Math.max(a.x0, b.x0);
}

/** The weights a page prints: 「●重量：11.5g／パック」, or a value under a
 * 「…/重量」 heading. A carton's (物流…) is not the item's, and left out. */
export function pageWeights(rows: Segment[][]): PageWeight[] {
  const out: PageWeight[] = [];
  for (let r = 0; r < rows.length; r++) {
    for (const s of rows[r]) {
      if (NOT_THE_ITEM.test(s.text)) continue;
      let m = LABELLED.exec(s.text);
      let header = "";
      if (!m) {
        m = AFTER_SIZE.exec(s.text);
        if (!m) continue;
        // The heading: the line just above, over the same place.
        const above = r > 0 ? rows[r - 1] : [];
        const h = above.find((a) => s.y - a.y <= 16 && overlap(a, s) > 0);
        if (!h || !/重\s*量|質\s*量/.test(h.text) || NOT_THE_ITEM.test(h.text)) continue;
        header = h.text;
      }
      const v = Number(m[1]);
      if (!(v > 0)) continue;
      if (SEVERAL.test(s.text) || SEVERAL.test(header)) continue;
      const g = /k/i.test(m[2]) || /ｋ/.test(m[2]) ? v * 1000 : v;
      const both = s.text + " " + header;
      out.push({
        x0: s.x0,
        x1: s.x1,
        y: s.y,
        g: Math.round(g * 1000) / 1000,
        text: s.text.slice(0, 80),
        basis: /パック|袋/.test(both) ? "pack" : /包装|パッケージ/.test(both) ? "package" : "product",
      });
    }
  }
  return out;
}

type Mark = { x0: number; x1: number; y: number; entry: CatalogEntry };
type Group = { x0: number; x1: number; top: number; bottom: number; marks: Mark[] };

/** JANs one under another in the same place: one product's colours or sizes. */
function groupsOf(marks: Mark[]): Group[] {
  const groups: Group[] = [];
  for (const m of [...marks].sort((a, b) => a.y - b.y || a.x0 - b.x0)) {
    const g = groups.find((g) => overlap(g, m) >= 0.5 * Math.min(g.x1 - g.x0, m.x1 - m.x0) && m.y - g.bottom <= 14);
    if (g) {
      g.marks.push(m);
      g.bottom = m.y;
      g.x0 = Math.min(g.x0, m.x0);
      g.x1 = Math.max(g.x1, m.x1);
    } else {
      groups.push({ x0: m.x0, x1: m.x1, top: m.y, bottom: m.y, marks: [m] });
    }
  }
  return groups;
}

/** Each group's weight, the weights printed above their JANs (dir -1) or
 * below them (+1): the nearest in the same place, before the next group. A
 * weight two groups would take is no one's. */
function placeWeights(groups: Group[], weights: PageWeight[], dir: -1 | 1): Map<Group, PageWeight> {
  const got = new Map<Group, PageWeight>();
  const claims = new Map<PageWeight, number>();
  for (const g of groups) {
    const near = (w: { x0: number; x1: number }) => overlap(g, w) >= 12;
    const others = groups.filter((o) => o !== g && near(o));
    let best: PageWeight | null = null;
    for (const w of weights) {
      if (!near(w)) continue;
      if (dir < 0) {
        if (w.y > g.top + 1 || g.top - w.y > 260) continue;
        // Not past a group above.
        if (others.some((o) => o.bottom < g.top && o.bottom > w.y)) continue;
        if (!best || w.y > best.y) best = w;
      } else {
        if (w.y < g.bottom - 1 || w.y - g.bottom > 260) continue;
        if (others.some((o) => o.top > g.bottom && o.top < w.y)) continue;
        if (!best || w.y < best.y) best = w;
      }
    }
    if (best) {
      got.set(g, best);
      claims.set(best, (claims.get(best) ?? 0) + 1);
    }
  }
  for (const [g, w] of got) if ((claims.get(w) ?? 0) > 1) got.delete(g);
  return got;
}

/** Every JAN on a page (as its lines of columns), each with the column
 * printed before it, and the weight printed for it when the page's layout
 * says which one that is. */
export function entriesFromRows(rows: Segment[][], page: PageRef): CatalogEntry[] {
  const out: CatalogEntry[] = [];
  const marks: Mark[] = [];
  for (const segs of rows) {
    const cols = segs.map((g) => g.text);
    for (let i = 0; i < segs.length; i++) {
      for (const m of cols[i].matchAll(JAN_RE)) {
        const jan = m[1].replace(/[^0-9]/g, "");
        if (!validJan(jan)) continue;
        // Before the JAN in its own column (after any JAN before it), else
        // what the column before ends with after its own JAN.
        const before = afterLastJan(cols[i].slice(0, m.index));
        const hint = before || (i > 0 ? afterLastJan(cols[i - 1]) : "");
        const entry: CatalogEntry = {
          jan,
          code_hint: hint ? hint.slice(0, 120) : null,
          line_text: cols.join(" | ").slice(0, 400),
          page_number: page.number,
          page_group: page.group,
          weight_g: null,
          weight_text: null,
          weight_basis: null,
        };
        out.push(entry);
        marks.push({ x0: segs[i].x0, x1: segs[i].x1, y: segs[i].y, entry });
      }
    }
  }
  const weights = pageWeights(rows);
  if (weights.length > 0 && marks.length > 0) {
    const groups = groupsOf(marks);
    const above = placeWeights(groups, weights, -1);
    const below = placeWeights(groups, weights, 1);
    // The way this page is laid out: whichever places more; a tie that
    // disagrees says nothing.
    let chosen: Map<Group, PageWeight> | null = above.size > below.size ? above : below.size > above.size ? below : null;
    if (!chosen && above.size > 0 && [...above].every(([g, w]) => below.get(g) === w)) chosen = above;
    for (const [g, w] of chosen ?? []) {
      for (const m of g.marks) {
        m.entry.weight_g = w.g;
        m.entry.weight_text = w.text;
        m.entry.weight_basis = w.basis;
      }
    }
  }
  return out;
}

/** Every JAN on a viewer page (its text XML). */
export function entriesFromPage(xml: string, page: PageRef): CatalogEntry[] {
  return entriesFromRows(segmentRows(itemsFromXml(xml)), page);
}

/** Every JAN on a PDF page, from its text items (y down the page). */
export function entriesFromItems(items: TextItem[], page: PageRef): CatalogEntry[] {
  return entriesFromRows(segmentRows(items), page);
}

/** One entry per JAN, the first page it was seen on (with a weight from a
 * later page when the first had none). */
export function uniqueEntries(entries: CatalogEntry[]): CatalogEntry[] {
  const seen = new Map<string, CatalogEntry>();
  for (const e of entries) {
    const first = seen.get(e.jan);
    if (!first) seen.set(e.jan, { ...e });
    // A weight found for it on a later page, when the first had none.
    else if (first.weight_g == null && e.weight_g != null) {
      first.weight_g = e.weight_g;
      first.weight_text = e.weight_text;
      first.weight_basis = e.weight_basis;
    }
  }
  return [...seen.values()];
}

/** The catalog's name, published date and page count (getCatalog.json). */
export function catalogInfo(json: unknown): { name: string | null; published: string | null; pageCount: number | null } {
  // deno-lint-ignore no-explicit-any
  const specs = (json as any)?.result?.article?.listDisplaySpecs ?? {};
  const pages = String(specs["総ページ数"] ?? "").replace(/[^0-9]/g, "");
  return {
    name: specs["カタログ名"] ? String(specs["カタログ名"]).replace(/\s+/g, " ").trim() : null,
    published: specs["発行年月"] ? String(specs["発行年月"]) : null,
    pageCount: pages ? Number(pages) : null,
  };
}

/** The maker a search result names (its メーカー名 spec). */
export function makerFromSearch(xml: string): string | null {
  const m = /<name>メーカー名<\/name>[\s\S]*?<value>([^<]*)<\/value>/.exec(xml);
  return m ? m[1].trim() || null : null;
}
