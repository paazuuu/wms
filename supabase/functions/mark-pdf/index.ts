// mark-pdf: the PDF as it came, with a red frame around each row that could
// not be read (no JAN, no quantity), so a person sees in the original what
// was left out. A PDF that carries its text is marked where the row's words
// stand; a scan is marked where the AI finds the row (approximate, dashed).
// Nothing is kept but the AI call's record (ai_calls).
//
// POST multipart { file: PDF, marks: JSON [{ i, texts: string[] }] }
//   → the marked PDF (application/pdf); X-Marked / X-Missing: how many rows
//     were framed and how many could not be found.

import { getDocumentProxy } from "npm:unpdf@1.1.0";
import { PDFDocument, rgb, StandardFonts } from "npm:pdf-lib@1.17.1";

const DEFAULT_MODEL = "gemini-3.1-flash-lite";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Expose-Headers": "x-marked, x-missing",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

const url = Deno.env.get("SUPABASE_URL") ?? "";
const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

type Mark = { i: number; texts: string[] };
type Box = { page: number; x: number; y: number; w: number; h: number; guess: boolean };
type Item = { str: string; x0: number; x1: number; y: number; h: number };

/** Text compared without width, case or spaces: ＡＢ-１ and ab-1 alike. */
export function norm(s: string): string {
  return s.normalize("NFKC").toLowerCase().replace(/\s+/g, "");
}

/** Lines of words on each page, top to bottom, with where they stand. */
async function pageLines(bytes: Uint8Array): Promise<Item[][][] | null> {
  let pdf;
  try {
    pdf = await getDocumentProxy(new Uint8Array(bytes));
  } catch (_) {
    return null;
  }
  const pages: Item[][][] = [];
  let count = 0;
  for (let n = 1; n <= pdf.numPages; n++) {
    const page = await pdf.getPage(n);
    const content = await page.getTextContent();
    const items: Item[] = [];
    for (const it of content.items as { str?: string; transform?: number[]; width?: number; height?: number }[]) {
      const text = (it.str ?? "").trim();
      if (!text || !it.transform) continue;
      const h = Math.abs(it.height ?? it.transform[3] ?? 8) || 8;
      items.push({ str: text, x0: it.transform[4], x1: it.transform[4] + (it.width ?? 0), y: it.transform[5], h });
    }
    count += items.length;
    items.sort((a, b) => b.y - a.y || a.x0 - b.x0);
    const lines: Item[][] = [];
    let line: Item[] = [];
    let y = Number.POSITIVE_INFINITY;
    for (const it of items) {
      if (Math.abs(it.y - y) > 3 && line.length) {
        lines.push(line);
        line = [];
      }
      if (!line.length) y = it.y;
      line.push(it);
    }
    if (line.length) lines.push(line);
    pages.push(lines);
  }
  return count >= 5 ? pages : null;
}

/** Where each row stands, found by its words: a strong word (a 品番, a JAN,
 * a name — three characters or more; a bare number only as long as a JAN) must
 * be on the line; a weak one (a quantity) only adds to it. Each line is used
 * once, so two rows alike land on two lines. */
export function locate(pages: Item[][][], marks: Mark[]): Map<number, Box> {
  const out = new Map<number, Box>();
  const used = new Set<string>();
  for (const m of marks) {
    const words = m.texts.map(norm).filter((t) => t.length > 0);
    const strong = words.filter((t) => t.length >= 3 && (!/^[\d.,]+$/.test(t) || t.length >= 8));
    if (!strong.length) continue;
    let best: { score: number; page: number; line: number } | null = null;
    pages.forEach((lines, p) => {
      lines.forEach((line, l) => {
        if (used.has(`${p}:${l}`)) return;
        const text = norm(line.map((it) => it.str).join(""));
        let score = 0;
        for (const s of strong) if (text.includes(s)) score += 2;
        if (score === 0) return;
        for (const w of words) if (!strong.includes(w) && line.some((it) => norm(it.str) === w)) score += 1;
        if (!best || score > best.score) best = { score, page: p, line: l };
      });
    });
    if (!best) continue;
    const { page, line } = best as { score: number; page: number; line: number };
    used.add(`${page}:${line}`);
    const its = pages[page][line];
    const h = Math.max(...its.map((it) => it.h));
    const x0 = Math.min(...its.map((it) => it.x0)) - 3;
    const x1 = Math.max(...its.map((it) => it.x1)) + 3;
    const y0 = Math.min(...its.map((it) => it.y)) - h * 0.35;
    out.set(m.i, { page, x: x0, y: y0, w: x1 - x0, h: h * 1.5, guess: false });
  }
  return out;
}

async function rpc(name: string, args: unknown, token: string): Promise<unknown> {
  const r = await fetch(`${url}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: { apikey: token === service ? service : anon, Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(args ?? {}),
  });
  if (!r.ok) throw new Error(`${name}: ${r.status} ${await r.text()}`);
  return await r.json();
}

async function log(row: Record<string, unknown>) {
  try {
    await fetch(`${url}/rest/v1/ai_calls`, {
      method: "POST",
      headers: { apikey: service, Authorization: `Bearer ${service}`, "Content-Type": "application/json", Prefer: "return=minimal" },
      body: JSON.stringify({ function_name: "mark-pdf", task: "mark_pdf", ...row }),
    });
  } catch (_) { /* the record is not worth failing for */ }
}

function b64(bytes: Uint8Array): string {
  let s = "";
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
}

/** A scan: the AI says on which page each row is and where (0–1000 of the
 * page, top-left origin). Rows it cannot find are left out. */
async function askAi(bytes: Uint8Array, marks: Mark[]): Promise<Map<number, { page: number; box: number[] }>> {
  const out = new Map<number, { page: number; box: number[] }>();
  let key: string | null = Deno.env.get("GEMINI_API_KEY") ?? null;
  let keyId: number | null = null;
  let model = Deno.env.get("GEMINI_MODEL") ?? DEFAULT_MODEL;
  try {
    const k = await rpc("ai_active_key", { p_id: null }, service) as { key_id?: number; key?: string; model?: string | null } | null;
    if (k?.key) {
      key = k.key;
      keyId = k.key_id ?? null;
      if (k.model) model = k.model;
    }
  } catch (_) { /* the server's own key is used */ }
  if (!key) {
    await log({ ok: false, model, error_kind: "no_key", error: "no API key is chosen or set", attempts: 0 });
    return out;
  }
  const prompt =
    "この納品書・請求書のPDFで、次の各行（i と、その行に書かれている文字）が書かれている位置を探してください。" +
    "page は1から数えたページ番号、box_2d は [ymin, xmin, ymax, xmax]（ページを0〜1000に正規化、左上が原点）で、その行全体（表の端から端まで）を囲む範囲です。" +
    "見つからない行は含めないでください。\n" + JSON.stringify(marks.map((m) => ({ i: m.i, texts: m.texts })));
  const started = Date.now();
  let res: Response | null = null;
  let attempts = 0;
  for (let a = 0; a < 3; a++) {
    attempts++;
    res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": key },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ inlineData: { mimeType: "application/pdf", data: b64(bytes) } }, { text: prompt }] }],
        generationConfig: {
          responseMimeType: "application/json",
          temperature: 0,
          responseSchema: {
            type: "object",
            properties: {
              rows: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    i: { type: "integer" },
                    page: { type: "integer" },
                    box_2d: { type: "array", items: { type: "number" } },
                  },
                  required: ["i", "page", "box_2d"],
                },
              },
            },
            required: ["rows"],
          },
        },
      }),
    });
    if (res.status !== 503 && res.status !== 429) break;
    await new Promise((r) => setTimeout(r, 700 * (a + 1)));
  }
  if (!res || !res.ok) {
    await log({ key_id: keyId, ok: false, model, http_status: res?.status ?? null, error_kind: "http",
      error: res ? (await res.text()).slice(0, 500) : "", attempts, latency_ms: Date.now() - started });
    return out;
  }
  const body = await res.json();
  const usage = body?.usageMetadata ?? {};
  try {
    const parsed = JSON.parse(body?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}");
    for (const r of Array.isArray(parsed.rows) ? parsed.rows : []) {
      const box = Array.isArray(r.box_2d) ? r.box_2d.map(Number) : [];
      if (Number.isInteger(r.i) && Number.isInteger(r.page) && box.length === 4 && box.every(Number.isFinite)) {
        out.set(r.i, { page: r.page - 1, box });
      }
    }
  } catch (_) { /* nothing found */ }
  await log({ key_id: keyId, ok: true, model, http_status: res.status, attempts, latency_ms: Date.now() - started,
    input_tokens: usage.promptTokenCount ?? null, output_tokens: usage.candidatesTokenCount ?? null });
  return out;
}

/** The PDF with a red frame (dashed where the AI placed it) and its row
 * number beside each row of [marks] found. */
export async function markPdf(
  bytes: Uint8Array,
  marks: Mark[],
  ai: (bytes: Uint8Array, marks: Mark[]) => Promise<Map<number, { page: number; box: number[] }>> = askAi,
): Promise<{ out: Uint8Array; marked: number }> {
  const doc = await PDFDocument.load(bytes, { ignoreEncryption: true });
  const pages = doc.getPages();
  const boxes = new Map<number, Box>();
  const lines = await pageLines(bytes);
  if (lines) for (const [i, b] of locate(lines, marks)) boxes.set(i, b);
  const rest = marks.filter((m) => !boxes.has(m.i));
  if (rest.length) {
    for (const [i, g] of await ai(bytes, rest)) {
      const page = pages[g.page];
      if (!page) continue;
      const { width, height } = page.getSize();
      const [ymin, xmin, ymax, xmax] = g.box;
      boxes.set(i, {
        page: g.page, x: xmin / 1000 * width, y: height - ymax / 1000 * height,
        w: (xmax - xmin) / 1000 * width, h: (ymax - ymin) / 1000 * height, guess: true,
      });
    }
  }
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const red = rgb(0.88, 0, 0);
  let marked = 0;
  for (const [i, b] of boxes) {
    const page = pages[b.page];
    if (!page || b.w <= 0 || b.h <= 0) continue;
    page.drawRectangle({
      x: b.x, y: b.y, width: b.w, height: b.h,
      borderColor: red, borderWidth: 1.6, color: rgb(1, 0, 0), opacity: 0.08, borderOpacity: 1,
      ...(b.guess ? { borderDashArray: [4, 3] } : {}),
    });
    page.drawText(`#${i}`, { x: Math.max(1, b.x - 22), y: b.y + b.h / 2 - 3, size: 7, font, color: red });
    marked++;
  }
  return { out: await doc.save(), marked };
}

if (import.meta.main) {
  Deno.serve(async (req) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
    if (req.method !== "POST") return json({ message: "POST only" }, 405);
    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    if (!token) return json({ message: "sign in required" }, 401);
    const who = await fetch(`${url}/auth/v1/user`, { headers: { apikey: anon, Authorization: `Bearer ${token}` } });
    if (!who.ok) return json({ message: "sign in required" }, 401);

    let form: FormData;
    try {
      form = await req.formData();
    } catch (_) {
      return json({ message: "a multipart body is required" }, 400);
    }
    const file = form.get("file");
    if (!(file instanceof File)) return json({ message: "file is required" }, 400);
    let marks: Mark[] = [];
    try {
      marks = (JSON.parse(String(form.get("marks") ?? "[]")) as Mark[])
        .filter((m) => Number.isInteger(m.i) && Array.isArray(m.texts))
        .slice(0, 500)
        .map((m) => ({ i: m.i, texts: m.texts.map((t) => String(t ?? "").slice(0, 80)).filter((t) => t.trim()) }));
    } catch (_) {
      return json({ message: "marks must be JSON" }, 400);
    }
    const bytes = new Uint8Array(await file.arrayBuffer());
    let r: { out: Uint8Array; marked: number };
    try {
      r = await markPdf(bytes, marks);
    } catch (_) {
      return json({ message: "not a PDF" }, 400);
    }
    return new Response(new Blob([r.out as BlobPart]), {
      headers: {
        ...cors,
        "Content-Type": "application/pdf",
        "X-Marked": String(r.marked),
        "X-Missing": String(marks.length - r.marked),
      },
    });
  });
}
