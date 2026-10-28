// 参照資料 (0160): what a saved copy needs — whether a URL may be fetched,
// a page's title and text, a content hash, and where its files go.

/** A URL a person may have saved: http(s), and not this machine or a
 * private network (the function fetches it). */
export function safeReferenceUrl(raw: string): URL | null {
  let u: URL;
  try {
    u = new URL(raw.trim());
  } catch {
    return null;
  }
  if (u.protocol !== "https:" && u.protocol !== "http:") return null;
  const h = u.hostname.toLowerCase().replace(/^\[|\]$/g, "");
  if (!h.includes(".") || /(^|\.)(localhost|local|internal|lan|home|corp)$/.test(h)) return null;
  // An address, not a name: none of the private, loopback or link-local ones.
  if (/^[0-9.]+$/.test(h)) {
    const [a, b] = h.split(".").map(Number);
    if (a === 10 || a === 127 || a === 0 || (a === 169 && b === 254) || (a === 172 && b >= 16 && b <= 31) ||
      (a === 192 && b === 168) || (a === 100 && b >= 64 && b <= 127)) return null;
  }
  if (h.includes(":")) return null; // an IPv6 literal
  return u;
}

const ENTITIES: Record<string, string> = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " " };

function decode(s: string): string {
  return s.replace(/&(#x[0-9a-f]+|#[0-9]+|[a-z]+);/gi, (m, e: string) => {
    if (e[0] === "#") {
      const n = e[1] === "x" || e[1] === "X" ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
      return Number.isFinite(n) ? String.fromCodePoint(n) : m;
    }
    return ENTITIES[e.toLowerCase()] ?? m;
  });
}

/** A page's <title>. */
export function htmlTitle(html: string): string | null {
  const m = /<title[^>]*>([\s\S]*?)<\/title>/i.exec(html);
  const t = m ? decode(m[1]).replace(/\s+/g, " ").trim() : "";
  return t ? t.slice(0, 300) : null;
}

/** A page's text as a person would read it: no scripts or styles, a line
 * a block, entities decoded. */
export function htmlText(html: string): string {
  return decode(
    html
      .replace(/<(script|style|noscript|template)[^>]*>[\s\S]*?<\/\1>/gi, " ")
      .replace(/<!--[\s\S]*?-->/g, " ")
      .replace(/<(br|\/p|\/div|\/li|\/tr|\/h[1-6]|\/section|\/article)[^>]*>/gi, "\n")
      .replace(/<[^>]+>/g, " "),
  )
    .split("\n")
    .map((l) => l.replace(/[ \t ]+/g, " ").trim())
    .filter((l) => l.length > 0)
    .join("\n");
}

export async function sha256Hex(data: Uint8Array | string): Promise<string> {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  const d = new Uint8Array(await crypto.subtle.digest("SHA-256", new Uint8Array(bytes)));
  return [...d].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** The folder a copy's files go in: source-12/20261028-153000. */
export function snapshotFolder(sourceId: number, at: Date): string {
  const p = (n: number) => String(n).padStart(2, "0");
  // Japan time, as the copy is looked at.
  const t = new Date(at.getTime() + 9 * 3600 * 1000);
  return `source-${sourceId}/${t.getUTCFullYear()}${p(t.getUTCMonth() + 1)}${p(t.getUTCDate())}-` +
    `${p(t.getUTCHours())}${p(t.getUTCMinutes())}${p(t.getUTCSeconds())}`;
}

/** 年度 (April to March, Japan time) of a moment, as the database has it. */
export function fiscalYear(at: Date): number {
  const t = new Date(at.getTime() + 9 * 3600 * 1000);
  return t.getUTCMonth() < 3 ? t.getUTCFullYear() - 1 : t.getUTCFullYear();
}
