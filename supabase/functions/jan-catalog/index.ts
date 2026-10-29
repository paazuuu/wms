// JAN catalogs (0153): a maker's catalog read for its JAN codes.
//   GET    /jan-catalog            the catalogs registered, with their counts
//   POST   /jan-catalog/sync {url} register a viewer URL (a mediapress iCata
//                                  page, or a meclib e-book such as Kobe
//                                  Ecole's library) and set it to be read
//                                  from page one
//   POST   /jan-catalog/step {catalog_id?} read its next 40 pages (the app
//                                  loops; the database's job steps every
//                                  catalog waiting, one call at a time)
//   DELETE /jan-catalog/:id        forget a catalog and its JANs
//
// Reading: every page a search for 49 / 45 (a Japanese JAN's start) finds,
// its text, each JAN with what is printed before it (see
// ../_shared/jan_catalog.ts). Only a mediapress host is fetched from.
//   POST   /jan-catalog/refresh     every viewer catalog set to be read again
//   POST   /jan-catalog/pdf/start   a PDF catalog (0155): its name, its hash;
//                                  what it had before is cleared
//   POST   /jan-catalog/pdf/pages   its pages' text, as the browser read it
//   POST   /jan-catalog/pdf/finish  counted, and products' weights filled
//   POST   /jan-catalog/photos      products' pictures from the web page their
//                                  name was found on (0166)
// After every read, products' weights are filled from the catalogs (and the
// AI's where there is none) by apply_jan_weights (0155).
// Writing needs product.manage (or the scheduler's secret) and goes through
// the service role; reading the table is open to product.view.
import { adminClient, callerClient, clientPermitted, notPermittedMessage } from "../_shared/require_permission.ts";
import { purgeAllowed } from "../_shared/purge.ts";
import { htmlText, htmlTitle, pageImageUrl, safeReferenceUrl, sha256Hex, snapshotFolder } from "../_shared/reference.ts";
import {
  type CatalogEntry,
  catalogInfo,
  type CatalogRef,
  entriesFromItems,
  entriesFromPage,
  makerFromSearch,
  meclibBase,
  meclibInfo,
  meclibTextEntries,
  type MeclibRef,
  parseMeclibUrl,
  type PageRef,
  type TextItem,
  pagesFromSearch,
  parseCatalogUrl,
  uniqueEntries,
} from "../_shared/jan_catalog.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
};
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const PAGE_SIZE = 100;
const PARALLEL = 6;
// Pages read in one call: a whole catalog (300–900 pages) is more than one
// function run may compute.
const CHUNK = 40;

async function fetchText(url: string): Promise<string> {
  for (let attempt = 0; ; attempt++) {
    try {
      const r = await fetch(url, { headers: { "User-Agent": "wms-jan-catalog/1.0" } });
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      return await r.text();
    } catch (e) {
      if (attempt >= 2) throw e;
      await new Promise((ok) => setTimeout(ok, 500 * (attempt + 1)));
    }
  }
}

function api(c: CatalogRef, params: Record<string, string>): string {
  const q = new URLSearchParams({ volumeid: c.volumeId, catalogid: c.catalogId, designID: c.designId, ...params });
  return `https://${c.host}/iportal/webapi.do?${q}`;
}

/** Every page a search for [kw] finds, page by page of results. */
async function searchPages(c: CatalogRef, kw: string): Promise<{ pages: PageRef[]; maker: string | null }> {
  const pages: PageRef[] = [];
  let maker: string | null = null;
  for (let ofs = 0; ofs < 2000; ofs += PAGE_SIZE) {
    const xml = await fetchText(api(c, { api: "getCatalogpageByFreeword", kw, ofs: `${ofs}`, rs: `${PAGE_SIZE}`, hrs: "1" }));
    maker ??= makerFromSearch(xml);
    const r = pagesFromSearch(xml);
    pages.push(...r.pages);
    if (r.pages.length === 0 || ofs + PAGE_SIZE >= r.total) break;
  }
  return { pages, maker };
}

/** The catalog's name and the pages that carry a JAN, in page order. */
async function listPages(c: CatalogRef) {
  const info = catalogInfo(
    JSON.parse(
      await fetchText(
        `https://${c.host}/iportal/getCatalog.json?${new URLSearchParams({ t: "mb", vid: c.volumeId, clid: c.catalogId, did: c.designId })}`,
      ),
    ),
  );
  const found = new Map<string, PageRef>();
  let maker: string | null = null;
  for (const kw of ["49", "45"]) {
    const r = await searchPages(c, kw);
    maker ??= r.maker;
    for (const p of r.pages) if (!found.has(p.id)) found.set(p.id, p);
  }
  const pages = [...found.values()].sort((a, b) => Number(a.number) - Number(b.number) || a.id.localeCompare(b.id));
  return { info, maker, pages };
}

/** These pages read, in their order: a JAN keeps the first page it is on. */
async function readPages(c: CatalogRef, pages: PageRef[]): Promise<CatalogEntry[]> {
  const byPage: CatalogEntry[][] = pages.map(() => []);
  let next = 0;
  await Promise.all(
    Array.from({ length: PARALLEL }, async () => {
      for (let i = next++; i < pages.length; i = next++) {
        const xml = await fetchText(api(c, { api: "getCatalogviewTextposition", pageid: pages[i].id, keyword: "" }));
        byPage[i] = entriesFromPage(xml, pages[i]);
      }
    }),
  );
  return uniqueEntries(byPage.flat());
}

type Admin = ReturnType<typeof adminClient>;

/** Entries into a catalog: new JANs added, a weight given to one that had
 * none; what an earlier page gave is kept. How many were new. */
async function mergeEntries(admin: Admin, id: number, entries: CatalogEntry[]): Promise<number> {
  const unique = uniqueEntries(entries);
  if (unique.length === 0) return 0;
  // Asked 150 at a time: a few hundred JANs make too long a URL.
  const known = new Map<string, number | null>();
  for (let k = 0; k < unique.length; k += 150) {
    const { data: had, error: hadErr } = await admin
      .from("jan_catalog_entries")
      .select("jan, weight_g")
      .eq("catalog_id", id)
      .in("jan", unique.slice(k, k + 150).map((e) => e.jan));
    if (hadErr) throw new Error(hadErr.message);
    for (const h of had ?? []) known.set(h.jan as string, h.weight_g as number | null);
  }
  const fresh = unique.filter((e) => !known.has(e.jan));
  for (let k = 0; k < fresh.length; k += 500) {
    // Two steps of one catalog at once (the app's and the job's) may both
    // add a JAN: the second is let go.
    const { error } = await admin.from("jan_catalog_entries")
      .upsert(fresh.slice(k, k + 500).map((e) => ({ catalog_id: id, ...e })), {
        onConflict: "catalog_id,jan",
        ignoreDuplicates: true,
      });
    if (error) throw new Error(error.message);
  }
  for (const e of unique) {
    if (known.has(e.jan) && known.get(e.jan) == null && e.weight_g != null) {
      await admin.from("jan_catalog_entries")
        .update({ weight_g: e.weight_g, weight_text: e.weight_text, weight_basis: e.weight_basis })
        .eq("catalog_id", id).eq("jan", e.jan);
    }
  }
  return fresh.length;
}

/** A catalog read to its end: counted, and products' weights filled. */
async function finishCatalog(admin: Admin, id: number, pagesRead: number, event: string) {
  const { count } = await admin.from("jan_catalog_entries").select("jan", { count: "exact", head: true }).eq("catalog_id", id);
  const { data: done, error } = await admin
    .from("jan_catalogs")
    .update({
      entry_count: count ?? 0,
      pages_read: pagesRead,
      next_page: null,
      synced_at: new Date().toISOString(),
      sync_error: (count ?? 0) === 0 ? "no JAN found" : null,
    })
    .eq("id", id)
    .select("*")
    .single();
  if (error) throw new Error(error.message);
  await admin.rpc("apply_jan_weights", { p_jans: null });
  // A copy for 参照資料 (0160); a failure here does not undo the read.
  await snapshotCatalog(admin, id).catch((e) => console.error("snapshot", id, `${e}`));
  await admin.rpc("log_audit", {
    p_event_type: event,
    p_entity_type: "jan_catalog",
    p_entity_id: String(id),
    p_warehouse_id: null,
    p_details: { entries: count ?? 0, pages: pagesRead },
  }).then(() => {}, () => {});
  return done;
}

// ------------------------------------------------------------ 参照資料 (0160)

const ARCHIVE = "reference-archive";
const SITE_MAX_BYTES = 25 * 1024 * 1024;

type CopyFile = { kind: string; name: string; body: Uint8Array | string; type: string };

/** A copy kept for [sourceId] unless the last one had the same content:
 * its files in the archive, and a row saying what it was. */
async function keepCopy(
  admin: Admin,
  sourceId: number,
  copy: { hash: string; title: string | null; edition?: string | null; pageCount?: number | null; entryCount?: number | null;
    weightCount?: number | null; files: CopyFile[]; note?: string | null },
): Promise<{ kept: boolean; snapshot?: unknown }> {
  const now = new Date();
  const { data: last } = await admin.from("reference_snapshots").select("content_hash").eq("source_id", sourceId)
    .order("taken_at", { ascending: false }).limit(1);
  await admin.from("reference_sources").update({ last_checked_at: now.toISOString() }).eq("id", sourceId);
  if (last?.[0]?.content_hash === copy.hash) return { kept: false };
  const folder = snapshotFolder(sourceId, now);
  const files = [];
  for (const f of copy.files) {
    const body = typeof f.body === "string" ? new TextEncoder().encode(f.body) : f.body;
    const path = `${folder}/${f.name}`;
    const { error } = await admin.storage.from(ARCHIVE).upload(path, body, { contentType: f.type, upsert: true });
    if (error) throw new Error(`archive: ${error.message}`);
    files.push({ kind: f.kind, path, bytes: body.length, type: f.type });
  }
  const { data, error } = await admin.from("reference_snapshots").insert({
    source_id: sourceId,
    taken_at: now.toISOString(),
    fiscal_year: 0, // set by the table's trigger
    title: copy.title,
    edition: copy.edition ?? null,
    page_count: copy.pageCount ?? null,
    entry_count: copy.entryCount ?? null,
    weight_count: copy.weightCount ?? null,
    content_hash: copy.hash,
    files,
    note: copy.note ?? null,
  }).select("*").single();
  if (error) throw new Error(error.message);
  return { kept: true, snapshot: data };
}

/** A catalog's 参照資料 entry, made or brought up to date. */
async function catalogSource(admin: Admin, cat: Record<string, unknown>): Promise<number> {
  const row = { kind: "catalog", jan_catalog_id: cat.id, url: cat.url || "", title: cat.name ?? null, maker: cat.maker ?? null };
  const { data, error } = await admin.from("reference_sources").upsert(row, { onConflict: "jan_catalog_id" }).select("id").single();
  if (error || !data) throw new Error(error?.message ?? "source");
  return data.id as number;
}

/** A copy of what a catalog gave: every JAN with what was printed beside it,
 * its weight and page; and a meclib book's own text. */
async function snapshotCatalog(admin: Admin, id: number): Promise<{ kept: boolean }> {
  const { data: cat, error } = await admin.from("jan_catalogs").select("*").eq("id", id).single();
  if (error || !cat) throw new Error(error?.message ?? "catalog");
  const rows: unknown[][] = [];
  for (let from = 0; ; from += 1000) {
    const { data, error: e } = await admin.from("jan_catalog_entries")
      .select("jan, code_hint, weight_g, weight_text, weight_basis, page_number, line_text")
      .eq("catalog_id", id).order("jan").range(from, from + 999);
    if (e) throw new Error(e.message);
    for (const r of data ?? []) {
      rows.push([r.jan, r.code_hint, r.weight_g, r.weight_text, r.weight_basis, r.page_number, r.line_text]);
    }
    if ((data ?? []).length < 1000) break;
  }
  const entries = JSON.stringify({
    catalog: { name: cat.name, maker: cat.maker, url: cat.url, kind: cat.kind, published: cat.published, file_name: cat.file_name },
    columns: ["jan", "code_hint", "weight_g", "weight_text", "weight_basis", "page_number", "line_text"],
    rows,
  });
  const files: CopyFile[] = [{ kind: "entries", name: "entries.json", body: entries, type: "application/json" }];
  let text = "";
  if (cat.kind === "meclib") {
    text = await fetchText(meclibBase({ host: cat.host, book: cat.catalog_id }) + "data/txtsearch.txt").catch(() => "");
    if (text) files.push({ kind: "text", name: "text.txt", body: text, type: "text/plain; charset=utf-8" });
  }
  const sourceId = await catalogSource(admin, cat);
  return await keepCopy(admin, sourceId, {
    hash: await sha256Hex(JSON.stringify(rows) + "\n" + text),
    title: cat.name,
    edition: cat.published ?? null,
    pageCount: cat.page_count ?? null,
    entryCount: rows.length,
    weightCount: rows.filter((r) => r[2] != null).length,
    files,
  });
}

function charsetOf(type: string, head: string): string {
  const m = /charset=["']?([A-Za-z0-9_-]+)/i.exec(type) ?? /<meta[^>]+charset=["']?([A-Za-z0-9_-]+)/i.exec(head);
  return (m?.[1] ?? "utf-8").toLowerCase();
}

/** A site as it is now: a PDF kept as it is; a page kept with its text. */
async function snapshotSite(admin: Admin, source: Record<string, unknown>): Promise<[number, unknown]> {
  const url = safeReferenceUrl(String(source.url ?? ""));
  if (!url) return [400, { message: "reference_bad_url" }];
  let res: Response;
  try {
    res = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0 (wms-reference/1.0)" }, signal: AbortSignal.timeout(30000) });
  } catch (e) {
    return [502, { message: `reference_unreachable: ${e}` }];
  }
  if (!res.ok) return [502, { message: `reference_unreachable: HTTP ${res.status}` }];
  if (Number(res.headers.get("content-length") ?? 0) > SITE_MAX_BYTES) return [413, { message: "reference_too_large" }];
  const bytes = new Uint8Array(await res.arrayBuffer());
  if (bytes.length > SITE_MAX_BYTES) return [413, { message: "reference_too_large" }];
  const type = res.headers.get("content-type") ?? "application/octet-stream";
  const files: CopyFile[] = [];
  let title = (source.title as string | null) ?? null;
  if (/pdf/i.test(type) || /\.pdf$/i.test(url.pathname)) {
    files.push({ kind: "pdf", name: "page.pdf", body: bytes, type: "application/pdf" });
  } else if (/html|text/i.test(type)) {
    const head = new TextDecoder("latin1").decode(bytes.slice(0, 4096));
    let html: string;
    try {
      html = new TextDecoder(charsetOf(type, head)).decode(bytes);
    } catch {
      html = new TextDecoder().decode(bytes);
    }
    title ??= htmlTitle(html);
    // Kept as UTF-8, with a base so its pictures and styles still load.
    const kept = html.replace(/<meta[^>]+charset=[^>]*>/gi, "")
      .replace(/<head([^>]*)>/i, `<head$1><meta charset="utf-8"><base href="${url.href.replace(/"/g, "&quot;")}">`);
    files.push({ kind: "html", name: "page.html", body: kept, type: "text/html; charset=utf-8" });
    files.push({ kind: "text", name: "text.txt", body: htmlText(html), type: "text/plain; charset=utf-8" });
  } else {
    files.push({ kind: "file", name: "file", body: bytes, type });
  }
  const r = await keepCopy(admin, source.id as number, { hash: await sha256Hex(bytes), title, files });
  if (title && !source.title) await admin.from("reference_sources").update({ title }).eq("id", source.id);
  return [200, { data: r }];
}

// --- 0166: a product's picture from the web --------------------------------

const PHOTO_PAGE_MAX = 3_000_000;
const PHOTO_MAX = 6_000_000;
const PHOTO_TYPES: Record<string, string> = { "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp", "image/gif": "gif" };
const BROWSER_UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36";

type PhotoResult = { product_id: number; ok: boolean; reason?: string; page_url?: string | null; image_url?: string };

/** The picture of one product: the page its name was found on (or [pageUrl]),
 * that page's own picture (og:image …), kept in product-images and added as
 * the person who asked (add_product_web_image: product.manage). */
// deno-lint-ignore no-explicit-any
async function photoFor(admin: Admin, caller: any, p: { id: number; jan_code: string }, pageUrl: string | null): Promise<PhotoResult> {
  let page = pageUrl;
  if (!page) {
    const { data } = await admin.from("jan_name_lookups").select("source_url").eq("jan", p.jan_code).maybeSingle();
    page = (data?.source_url as string | null) ?? null;
  }
  const url = page ? safeReferenceUrl(page) : null;
  if (!url) return { product_id: p.id, ok: false, reason: "no_page", page_url: page };
  let html: string;
  try {
    const res = await fetch(url, { headers: { "User-Agent": BROWSER_UA, "Accept": "text/html" }, signal: AbortSignal.timeout(15000) });
    if (!res.ok) return { product_id: p.id, ok: false, reason: `page_http_${res.status}`, page_url: url.href };
    const bytes = new Uint8Array(await res.arrayBuffer());
    if (bytes.length > PHOTO_PAGE_MAX) return { product_id: p.id, ok: false, reason: "page_too_large", page_url: url.href };
    const type = res.headers.get("content-type") ?? "";
    const head = new TextDecoder("latin1").decode(bytes.slice(0, 4096));
    try {
      html = new TextDecoder(charsetOf(type, head)).decode(bytes);
    } catch {
      html = new TextDecoder().decode(bytes);
    }
  } catch (e) {
    return { product_id: p.id, ok: false, reason: `page_unreachable: ${e}`.slice(0, 200), page_url: url.href };
  }
  const img = pageImageUrl(html, url);
  const safe = img ? safeReferenceUrl(img.href) : null;
  if (!safe) return { product_id: p.id, ok: false, reason: "no_image", page_url: url.href };
  let body: Uint8Array, ctype: string;
  try {
    const res = await fetch(safe, { headers: { "User-Agent": BROWSER_UA, "Referer": url.href }, signal: AbortSignal.timeout(15000) });
    if (!res.ok) return { product_id: p.id, ok: false, reason: `image_http_${res.status}`, page_url: url.href };
    ctype = (res.headers.get("content-type") ?? "").split(";")[0].trim().toLowerCase();
    body = new Uint8Array(await res.arrayBuffer());
  } catch (e) {
    return { product_id: p.id, ok: false, reason: `image_unreachable: ${e}`.slice(0, 200), page_url: url.href };
  }
  if (!PHOTO_TYPES[ctype]) {
    // Some shops say octet-stream: the bytes tell.
    ctype = body[0] === 0xff && body[1] === 0xd8 ? "image/jpeg"
      : body[0] === 0x89 && body[1] === 0x50 ? "image/png"
      : body[8] === 0x57 && body[9] === 0x45 ? "image/webp" : ctype;
  }
  if (!PHOTO_TYPES[ctype]) return { product_id: p.id, ok: false, reason: "not_an_image", page_url: url.href };
  if (body.length < 1000 || body.length > PHOTO_MAX) return { product_id: p.id, ok: false, reason: "image_size", page_url: url.href };
  const path = `${p.id}/${Date.now()}_web.${PHOTO_TYPES[ctype]}`;
  const up = await admin.storage.from("product-images").upload(path, body, { contentType: ctype, upsert: false });
  if (up.error) return { product_id: p.id, ok: false, reason: `upload: ${up.error.message}`, page_url: url.href };
  const { error } = await caller.rpc("add_product_web_image", {
    p_product_id: p.id, p_storage_path: path, p_content_type: ctype, p_byte_size: body.length, p_source_url: url.href,
  });
  if (error) {
    await admin.storage.from("product-images").remove([path]);
    return { product_id: p.id, ok: false, reason: error.message, page_url: url.href };
  }
  return { product_id: p.id, ok: true, page_url: url.href, image_url: safe.href };
}

/** POST /photos {product_ids? | jans?, page_url?, again?}: up to ten
 * products' pictures from the web — only those with none yet, unless
 * [again] (a person asking for another) or a page is given. */
// deno-lint-ignore no-explicit-any
async function photosRoute(admin: Admin, caller: any, body: any): Promise<[number, unknown]> {
  const ids = (Array.isArray(body?.product_ids) ? body.product_ids : []).map(Number).filter((n: number) => Number.isFinite(n) && n > 0);
  const jans = (Array.isArray(body?.jans) ? body.jans : []).map(String).filter((j: string) => /^[0-9]{8,14}$/.test(j));
  if (ids.length === 0 && jans.length === 0) return [400, { message: "product_ids or jans are required" }];
  let q = admin.from("products").select("id, jan_code");
  q = ids.length ? q.in("id", ids.slice(0, 50)) : q.in("jan_code", jans.slice(0, 50));
  const { data: products, error } = await q;
  if (error) return [400, { message: error.message }];
  const pageUrl = typeof body?.page_url === "string" && body.page_url.trim() ? body.page_url.trim() : null;
  const again = body?.again === true || pageUrl !== null;
  const { data: imgs } = await admin.from("product_images").select("product_id")
    .in("product_id", (products ?? []).map((p) => p.id)).is("withdrawn_at", null);
  const has = new Set((imgs ?? []).map((i) => i.product_id as number));
  const results: PhotoResult[] = [];
  for (const p of (products ?? []).slice(0, 10)) {
    if (!again && has.has(p.id as number)) {
      results.push({ product_id: p.id as number, ok: false, reason: "has_images" });
      continue;
    }
    results.push(await photoFor(admin, caller, p as { id: number; jan_code: string }, pageUrl));
  }
  return [200, { data: { results, added: results.filter((r) => r.ok).length } }];
}

/** A site and every copy of it, gone. */
async function deleteSource(admin: Admin, id: number): Promise<[number, unknown]> {
  const { data: folders } = await admin.storage.from(ARCHIVE).list(`source-${id}`, { limit: 1000 });
  for (const f of folders ?? []) {
    const { data: inner } = await admin.storage.from(ARCHIVE).list(`source-${id}/${f.name}`, { limit: 100 });
    const paths = (inner ?? []).map((x) => `source-${id}/${f.name}/${x.name}`);
    if (paths.length > 0) await admin.storage.from(ARCHIVE).remove(paths);
  }
  const { error } = await admin.from("reference_sources").delete().eq("id", id);
  if (error) return [400, { message: error.message }];
  return [200, { data: { deleted: id } }];
}

// deno-lint-ignore no-explicit-any
async function referenceRoute(admin: Admin, rest: string[], body: any, userId: string | null): Promise<[number, unknown]> {
  // POST /reference {url, title?, maker?, note?}: a site added, and saved now.
  if (rest.length === 1) {
    const url = safeReferenceUrl(String(body?.url ?? ""));
    if (!url) return [400, { message: "reference_bad_url" }];
    const row = {
      kind: "site",
      url: url.href,
      title: String(body?.title ?? "").trim().slice(0, 300) || null,
      maker: String(body?.maker ?? "").trim().slice(0, 200) || null,
      note: String(body?.note ?? "").trim().slice(0, 1000) || null,
      ...(userId ? { created_by: userId } : {}),
    };
    const { data: had } = await admin.from("reference_sources").select("*").eq("kind", "site").eq("url", url.href).maybeSingle();
    const { data: src, error } = had
      ? await admin.from("reference_sources").update({ title: row.title ?? had.title, maker: row.maker ?? had.maker, note: row.note ?? had.note })
        .eq("id", had.id).select("*").single()
      : await admin.from("reference_sources").insert(row).select("*").single();
    if (error || !src) return [400, { message: error?.message ?? "source" }];
    const [status, out] = await snapshotSite(admin, src);
    return [status, status === 200 ? { data: { source: src, ...((out as { data: object }).data) } } : out];
  }
  // POST /reference/refresh: every site saved again (the monthly job).
  if (rest[1] === "refresh" && rest.length === 2) {
    const { data } = await admin.from("reference_sources").select("*").eq("kind", "site").order("id");
    const started = Date.now();
    let saved = 0;
    for (const src of data ?? []) {
      if (Date.now() - started > 110_000) break;
      const [status] = await snapshotSite(admin, src);
      if (status === 200) saved++;
    }
    return [200, { data: { sites: (data ?? []).length, saved } }];
  }
  // POST /reference/backfill: a first copy of catalogs that have none yet.
  if (rest[1] === "backfill" && rest.length === 2) {
    const { data: cats } = await admin.from("jan_catalogs").select("id").gt("entry_count", 0).order("id");
    const { data: have } = await admin.from("reference_sources").select("jan_catalog_id, reference_snapshots(id)").eq("kind", "catalog");
    const done = new Set((have ?? []).filter((h) => (h.reference_snapshots ?? []).length > 0).map((h) => h.jan_catalog_id));
    const todo = (cats ?? []).filter((c) => !done.has(c.id)).slice(0, 6);
    for (const c of todo) await snapshotCatalog(admin, c.id);
    return [200, { data: { copied: todo.length, left: (cats ?? []).length - done.size - todo.length } }];
  }
  const id = Number(rest[1]);
  if (!Number.isFinite(id)) return [404, { message: "not found" }];
  const { data: src } = await admin.from("reference_sources").select("*").eq("id", id).maybeSingle();
  if (!src) return [404, { message: "not found" }];
  // POST /reference/:id/save: saved again now.
  if (rest[2] === "save" && rest.length === 3) {
    return src.kind === "site" ? await snapshotSite(admin, src)
      : src.jan_catalog_id ? [200, { data: await snapshotCatalog(admin, src.jan_catalog_id) }]
      : [409, { message: "the catalog is gone" }];
  }
  return [404, { message: "not found" }];
}

/** A viewer catalog registered (or again) and set to be read from its first
 * page; /step reads it a few pages at a time. */
async function startSync(admin: Admin, url: string, userId: string | null): Promise<[number, unknown]> {
  const book = parseMeclibUrl(url);
  if (book) {
    const { data: row, error } = await admin
      .from("jan_catalogs")
      .upsert(
        {
          url: url.trim(),
          kind: "meclib",
          host: book.host,
          volume_id: "meclib",
          catalog_id: book.book,
          design_id: "",
          next_page: 0,
          sync_error: null,
          ...(userId ? { created_by: userId } : {}),
        },
        { onConflict: "volume_id,catalog_id" },
      )
      .select("*")
      .single();
    if (error || !row) return [400, { message: error?.message ?? "upsert failed" }];
    return [200, { data: row }];
  }
  const ref = parseCatalogUrl(url);
  if (!ref) return [400, { message: "jan_catalog_bad_url" }];
  const { data: row, error } = await admin
    .from("jan_catalogs")
    .upsert(
      {
        url: url.trim(),
        kind: "icata",
        host: ref.host,
        volume_id: ref.volumeId,
        catalog_id: ref.catalogId,
        design_id: ref.designId,
        next_page: 0,
        sync_error: null,
        ...(userId ? { created_by: userId } : {}),
      },
      { onConflict: "volume_id,catalog_id" },
    )
    .select("*")
    .single();
  if (error || !row) return [400, { message: error?.message ?? "upsert failed" }];
  return [200, { data: row }];
}

/** A meclib book read whole from its search text (one call: it is a single
 * file): its JANs and pages, no weights (see meclibTextEntries). */
// deno-lint-ignore no-explicit-any
async function stepMeclib(admin: Admin, cat: any): Promise<[number, unknown]> {
  const book: MeclibRef = { host: cat.host, book: cat.catalog_id };
  try {
    const info = meclibInfo(JSON.parse(await fetchText(meclibBase(book) + "data/book.txt")));
    if (!info.textAllowed) {
      await admin.from("jan_catalogs").update({ next_page: null, sync_error: "text search not offered", name: info.title })
        .eq("id", cat.id);
      return [422, { message: "jan_catalog_no_text" }];
    }
    const text = await fetchText(meclibBase(book) + "data/txtsearch.txt");
    const pages = text.split("\n").length;
    const del = await admin.from("jan_catalog_entries").delete().eq("catalog_id", cat.id);
    if (del.error) throw new Error(del.error.message);
    await admin.from("jan_catalogs").update({ name: info.title, page_count: pages }).eq("id", cat.id);
    await mergeEntries(admin, cat.id, meclibTextEntries(text));
    const done = await finishCatalog(admin, cat.id, pages, "jan_catalog.sync");
    return [200, { data: { done: true, catalog: done, page: pages, pages } }];
  } catch (e) {
    // A book with no search text (404) will not have one next time either:
    // not tried again until the monthly refresh.
    const gone = /HTTP 404/.test(`${e}`);
    await admin.from("jan_catalogs").update({ sync_error: `${e}`.slice(0, 500), ...(gone ? { next_page: null } : {}) })
      .eq("id", cat.id);
    return [502, { message: `jan_catalog_unreachable: ${e}` }];
  }
}

/** The next few pages of a catalog being read ([id], else the one waiting
 * longest): what it came to, and how far. */
async function stepSync(admin: Admin, id: number | null): Promise<[number, unknown]> {
  let q = admin.from("jan_catalogs").select("*").in("kind", ["icata", "meclib"]).not("next_page", "is", null);
  q = id != null ? q.eq("id", id) : q.order("synced_at", { ascending: true, nullsFirst: true });
  const { data: rows, error } = await q.limit(1);
  if (error) return [400, { message: error.message }];
  const cat = rows?.[0];
  if (!cat) return [200, { data: { done: true, idle: true } }];
  const from = Number(cat.next_page) || 0;
  if (cat.kind === "meclib") return await stepMeclib(admin, cat);
  const ref: CatalogRef = { host: cat.host, volumeId: cat.volume_id, catalogId: cat.catalog_id, designId: cat.design_id };
  try {
    const list = await listPages(ref);
    if (from === 0) {
      // Read again from the start: what it no longer prints goes.
      const del = await admin.from("jan_catalog_entries").delete().eq("catalog_id", cat.id);
      if (del.error) throw new Error(del.error.message);
      await admin.from("jan_catalogs").update({
        maker: list.maker, name: list.info.name, published: list.info.published, page_count: list.info.pageCount,
      }).eq("id", cat.id);
    }
    const slice = list.pages.slice(from, from + CHUNK);
    await mergeEntries(admin, cat.id, await readPages(ref, slice));
    const next = from + slice.length;
    if (next >= list.pages.length) {
      const done = await finishCatalog(admin, cat.id, list.pages.length, "jan_catalog.sync");
      return [200, { data: { done: true, catalog: done, page: next, pages: list.pages.length } }];
    }
    await admin.from("jan_catalogs").update({ next_page: next, pages_read: next }).eq("id", cat.id);
    return [200, { data: { done: false, catalog_id: cat.id, page: next, pages: list.pages.length } }];
  } catch (e) {
    // Left where it was: the next step tries these pages again.
    await admin.from("jan_catalogs").update({ sync_error: `${e}`.slice(0, 500) }).eq("id", cat.id);
    return [502, { message: `jan_catalog_unreachable: ${e}` }];
  }
}

const MAX_PAGES_A_CALL = 25;
const MAX_ITEMS_A_PAGE = 40000;

// deno-lint-ignore no-explicit-any
function itemsOf(raw: any): TextItem[] {
  const out: TextItem[] = [];
  for (const i of Array.isArray(raw) ? raw.slice(0, MAX_ITEMS_A_PAGE) : []) {
    if (!Array.isArray(i) || i.length < 4) continue;
    const [x, y, w, t] = [Number(i[0]), Number(i[1]), Number(i[2]), String(i[3] ?? "")];
    if (Number.isFinite(x) && Number.isFinite(y) && t) out.push({ x, y, w: Number.isFinite(w) ? w : 0, t: t.slice(0, 400) });
  }
  return out;
}

/** A PDF catalog read in the browser, step by step: start, its pages, finish. */
// deno-lint-ignore no-explicit-any
async function pdfStep(admin: Admin, step: string, body: any, userId: string | null): Promise<[number, unknown]> {
  if (step === "start") {
    const hash = String(body?.sha256 ?? "").toLowerCase();
    if (!/^[0-9a-f]{64}$/.test(hash)) return [400, { message: "sha256 is required" }];
    const url = String(body?.url ?? "").trim();
    if (url && !/^https?:\/\/\S+$/.test(url)) return [400, { message: "jan_catalog_bad_url" }];
    const name = String(body?.name ?? "").trim().slice(0, 200) || String(body?.file_name ?? "PDF").slice(0, 200);
    const { data: row, error } = await admin
      .from("jan_catalogs")
      .upsert(
        {
          kind: "pdf",
          url,
          host: url ? new URL(url).hostname : "",
          volume_id: "pdf",
          catalog_id: hash,
          design_id: "",
          name,
          maker: String(body?.maker ?? "").trim().slice(0, 200) || null,
          file_name: String(body?.file_name ?? "").slice(0, 300) || null,
          page_count: Number.isFinite(Number(body?.page_count)) ? Number(body.page_count) : null,
          pages_read: 0,
          entry_count: 0,
          sync_error: null,
          ...(userId ? { created_by: userId } : {}),
        },
        { onConflict: "volume_id,catalog_id" },
      )
      .select("*")
      .single();
    if (error || !row) return [400, { message: error?.message ?? "upsert failed" }];
    const del = await admin.from("jan_catalog_entries").delete().eq("catalog_id", row.id);
    if (del.error) return [400, { message: del.error.message }];
    return [200, { data: row }];
  }

  const id = Number(body?.catalog_id);
  if (!Number.isFinite(id)) return [400, { message: "catalog_id is required" }];
  const { data: cat } = await admin.from("jan_catalogs").select("id, kind").eq("id", id).maybeSingle();
  if (!cat || cat.kind !== "pdf") return [404, { message: "not a PDF catalog" }];

  if (step === "pages") {
    const pages = (Array.isArray(body?.pages) ? body.pages : []).slice(0, MAX_PAGES_A_CALL);
    const entries: CatalogEntry[] = [];
    for (const p of pages) {
      const index = String(Number(p?.index) || "");
      if (!index) continue;
      entries.push(...entriesFromItems(itemsOf(p?.items), { id: index, group: index, number: String(p?.label ?? index) }));
    }
    const unique = uniqueEntries(entries);
    const fresh = await mergeEntries(admin, id, unique);
    return [200, { data: { entries: fresh, weights: unique.filter((e) => e.weight_g != null).length } }];
  }

  if (step === "finish") {
    const pages = Number.isFinite(Number(body?.pages_read)) ? Number(body.pages_read) : 0;
    return [200, { data: await finishCatalog(admin, id, pages, "jan_catalog.pdf") }];
  }
  return [404, { message: "not found" }];
}

// verify_jwt=false: besides a signed-in person, the database's monthly job
// calls this with the shared secret (purge_expired_secret, see 0148/0153).
// Every route checks one or the other itself.
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const caller = callerClient(req, supabaseUrl);
    const admin = adminClient(supabaseUrl);
    const parts = new URL(req.url).pathname.split("/").filter(Boolean);
    const i = parts.indexOf("jan-catalog");
    const rest = i >= 0 ? parts.slice(i + 1) : [];
    // deno-lint-ignore no-explicit-any
    const secret = req.headers.get("x-purge-secret");
    // Asked twice: a cold start's first database call can fail.
    const byScheduler = !!secret &&
      ((await purgeAllowed(admin as any, secret)) || (await purgeAllowed(admin as any, secret)));

    if (req.method === "GET" && rest.length === 0) {
      if (!byScheduler && !(await clientPermitted(caller, "product.view"))) {
        return json({ message: notPermittedMessage("product.view") }, 403);
      }
      const { data, error } = await (byScheduler ? admin : caller).from("jan_catalogs").select("*").order("id");
      if (error) return json({ message: error.message }, 400);
      return json({ data: data ?? [] });
    }

    if (!byScheduler && !(await clientPermitted(caller, "product.manage"))) {
      return json({ message: notPermittedMessage("product.manage") }, 403);
    }
    const userId = byScheduler ? null : (await caller.auth.getUser()).data?.user?.id ?? null;

    if (req.method === "DELETE" && rest.length === 1 && /^\d+$/.test(rest[0])) {
      const { error } = await admin.from("jan_catalogs").delete().eq("id", Number(rest[0]));
      if (error) return json({ message: error.message }, 400);
      return json({ data: { deleted: Number(rest[0]) } });
    }

    if (req.method === "POST" && rest[0] === "sync" && rest.length === 1) {
      const body = await req.json().catch(() => ({}));
      const [status, out] = await startSync(admin, String(body?.url ?? ""), userId);
      return json(out, status);
    }

    // The next pages of a catalog being read (the app's loop, or the job's).
    if (req.method === "POST" && rest[0] === "step" && rest.length === 1) {
      const body = await req.json().catch(() => ({}));
      const id = Number(body?.catalog_id);
      const [status, out] = await stepSync(admin, Number.isFinite(id) && id > 0 ? id : null);
      return json(out, status);
    }

    // Every viewer catalog set to be read again (the monthly job); the
    // stepping job reads them a few pages at a time.
    if (req.method === "POST" && rest[0] === "refresh" && rest.length === 1) {
      const { data, error } = await admin.from("jan_catalogs").update({ next_page: 0 }).in("kind", ["icata", "meclib"]).select("id");
      if (error) return json({ message: error.message }, 400);
      return json({ data: { queued: (data ?? []).length } });
    }

    if (rest[0] === "reference") {
      if (req.method === "DELETE" && rest.length === 2 && /^\d+$/.test(rest[1])) {
        const [status, out] = await deleteSource(admin, Number(rest[1]));
        return json(out, status);
      }
      if (req.method === "POST") {
        const body = await req.json().catch(() => ({}));
        const [status, out] = await referenceRoute(admin, rest, body, userId);
        return json(out, status);
      }
    }

    // A product's picture from the web (0166): as the person who asked.
    if (req.method === "POST" && rest[0] === "photos" && rest.length === 1) {
      if (byScheduler || !userId) return json({ message: notPermittedMessage("product.manage") }, 403);
      const body = await req.json().catch(() => ({}));
      const [status, out] = await photosRoute(admin, caller, body);
      return json(out, status);
    }

    if (req.method === "POST" && rest[0] === "pdf" && rest.length === 2) {
      const body = await req.json().catch(() => ({}));
      const [status, out] = await pdfStep(admin, rest[1], body, userId);
      return json(out, status);
    }

    return json({ message: "not found" }, 404);
  } catch (e) {
    return json({ message: `${e}` }, 500);
  }
});
