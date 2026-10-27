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

type Char = { x: number; y: number; w: number; h: number; t: string };

function charsOf(xml: string): Char[] {
  const out: Char[] = [];
  for (const m of xml.matchAll(/<text\s([^>]*)><!\[CDATA\[([\s\S]*?)\]\]><\/text>/g)) {
    const a: Record<string, number> = {};
    for (const [, k, v] of m[1].matchAll(/(\w+)="([^"]*)"/g)) a[k] = Number(v);
    if (!Number.isFinite(a.x) || !Number.isFinite(a.y)) continue;
    out.push({ x: a.x, y: a.y, w: Number.isFinite(a.w) ? a.w : 0, h: Number.isFinite(a.h) ? a.h : 0, t: m[2] });
  }
  return out;
}

/** A page's text as lines, top to bottom, each split into its columns. */
export function pageLines(xml: string): string[][] {
  const chars = charsOf(xml).sort((a, b) => a.y - b.y || a.x - b.x);
  const rows: Char[][] = [];
  for (const c of chars) {
    const row = rows[rows.length - 1];
    if (row && Math.abs(c.y - row[0].y) <= 1.5) row.push(c);
    else rows.push([c]);
  }
  return rows.map((row) => {
    row.sort((a, b) => a.x - b.x);
    const cols: string[] = [];
    let cur = "";
    let end = -Infinity;
    for (const c of row) {
      const gap = c.x - end;
      if (cur && gap > 12) {
        cols.push(cur.trim());
        cur = "";
      } else if (cur && gap > 2) {
        cur += " ";
      }
      cur += c.t;
      end = Math.max(end, c.x + c.w);
    }
    if (cur.trim()) cols.push(cur.trim());
    return cols.filter((s) => s.length > 0);
  });
}

/** A JAN (EAN-13) whose check digit adds up. */
export function validJan(jan: string): boolean {
  if (!/^\d{13}$/.test(jan)) return false;
  let sum = 0;
  for (let i = 0; i < 12; i++) sum += Number(jan[i]) * (i % 2 === 0 ? 1 : 3);
  return (10 - (sum % 10)) % 10 === Number(jan[12]);
}

// 49-02505-625923, 4902505625923, 49 02505 625923 — a Japanese (45/49) JAN.
const JAN_RE = /(?<![0-9])(4[59](?:[-‐－ ]?[0-9]){11})(?![0-9])/g;

export type CatalogEntry = {
  jan: string;
  code_hint: string | null;
  line_text: string;
  page_number: string;
  page_group: string;
};

/** Every JAN on a page, each with the column printed before it. */
export function entriesFromPage(xml: string, page: PageRef): CatalogEntry[] {
  const out: CatalogEntry[] = [];
  for (const cols of pageLines(xml)) {
    for (let i = 0; i < cols.length; i++) {
      for (const m of cols[i].matchAll(JAN_RE)) {
        const jan = m[1].replace(/[^0-9]/g, "");
        if (!validJan(jan)) continue;
        // Before the JAN in its own column, else the column before.
        const before = cols[i].slice(0, m.index).trim();
        const hint = before || (i > 0 ? cols[i - 1] : "");
        out.push({
          jan,
          code_hint: hint ? hint.slice(0, 120) : null,
          line_text: cols.join(" | ").slice(0, 400),
          page_number: page.number,
          page_group: page.group,
        });
      }
    }
  }
  return out;
}

/** One entry per JAN, the first page it was seen on. */
export function uniqueEntries(entries: CatalogEntry[]): CatalogEntry[] {
  const seen = new Map<string, CatalogEntry>();
  for (const e of entries) if (!seen.has(e.jan)) seen.set(e.jan, e);
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
