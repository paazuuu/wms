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
// After every read, products' weights are filled from the catalogs (and the
// AI's where there is none) by apply_jan_weights (0155).
// Writing needs product.manage (or the scheduler's secret) and goes through
// the service role; reading the table is open to product.view.
import { adminClient, callerClient, clientPermitted, notPermittedMessage } from "../_shared/require_permission.ts";
import { purgeAllowed } from "../_shared/purge.ts";
import { getDocumentProxy } from "npm:unpdf@0.12.1";
import {
  type CatalogEntry,
  catalogInfo,
  type CatalogRef,
  entriesFromItems,
  entriesFromPage,
  makerFromSearch,
  meclibBase,
  meclibInfo,
  meclibJanPages,
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
// A meclib book is read page by page from its PDFs: fewer at a time.
const PDF_CHUNK = 12;

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

async function fetchBytes(url: string): Promise<Uint8Array> {
  for (let attempt = 0; ; attempt++) {
    try {
      const r = await fetch(url, { headers: { "User-Agent": "wms-jan-catalog/1.0" } });
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      return new Uint8Array(await r.arrayBuffer());
    } catch (e) {
      if (attempt >= 2) throw e;
      await new Promise((ok) => setTimeout(ok, 500 * (attempt + 1)));
    }
  }
}

/** One page's PDF as runs of text, y down the page (as the browser's). */
async function pdfItems(bytes: Uint8Array): Promise<TextItem[]> {
  const pdf = await getDocumentProxy(bytes);
  const out: TextItem[] = [];
  try {
    for (let n = 1; n <= pdf.numPages; n++) {
      const page = await pdf.getPage(n);
      const vp = page.getViewport({ scale: 1 });
      const tc = await page.getTextContent();
      for (const it of tc.items) {
        // deno-lint-ignore no-explicit-any
        const i = it as any;
        if (typeof i.str !== "string" || !i.str.trim()) continue;
        out.push({ x: i.transform[4], y: vp.height - i.transform[5], w: i.width ?? 0, t: i.str });
      }
      page.cleanup();
    }
  } finally {
    await pdf.destroy();
  }
  return out;
}

/** A meclib book's title, whether its pages may be had as PDFs, and the
 * pages whose text has a JAN. */
async function meclibPages(m: MeclibRef) {
  const info = meclibInfo(JSON.parse(await fetchText(meclibBase(m) + "data/book.txt")));
  const text = await fetchText(meclibBase(m) + "data/txtsearch.txt");
  return { ...info, pages: meclibJanPages(text), pageCount: text.split("\n").length };
}

/** These pages of a meclib book read from their PDFs. */
async function readMeclibPages(m: MeclibRef, pages: number[]): Promise<CatalogEntry[]> {
  const byPage: CatalogEntry[][] = pages.map(() => []);
  let next = 0;
  await Promise.all(
    Array.from({ length: 4 }, async () => {
      for (let i = next++; i < pages.length; i = next++) {
        const n = pages[i];
        const bytes = await fetchBytes(`${meclibBase(m)}pdf/${String(n).padStart(4, "0")}.pdf`);
        byPage[i] = entriesFromItems(await pdfItems(bytes), { id: String(n), group: String(n), number: String(n) });
      }
    }),
  );
  return uniqueEntries(byPage.flat());
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
  await admin.rpc("log_audit", {
    p_event_type: event,
    p_entity_type: "jan_catalog",
    p_entity_id: String(id),
    p_warehouse_id: null,
    p_details: { entries: count ?? 0, pages: pagesRead },
  }).then(() => {}, () => {});
  return done;
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

/** The next pages of a meclib book: read from their PDFs, when the book lets
 * a page be had as a PDF; else it is not read at all. */
// deno-lint-ignore no-explicit-any
async function stepMeclib(admin: Admin, cat: any, from: number): Promise<[number, unknown]> {
  const book: MeclibRef = { host: cat.host, book: cat.catalog_id };
  try {
    const list = await meclibPages(book);
    if (!list.pdfAllowed) {
      await admin.from("jan_catalogs").update({ next_page: null, sync_error: "PDF not offered", name: list.title }).eq("id", cat.id);
      return [422, { message: "jan_catalog_no_pdf" }];
    }
    if (from === 0) {
      const del = await admin.from("jan_catalog_entries").delete().eq("catalog_id", cat.id);
      if (del.error) throw new Error(del.error.message);
      await admin.from("jan_catalogs").update({ name: list.title, page_count: list.pageCount }).eq("id", cat.id);
    }
    const slice = list.pages.slice(from, from + PDF_CHUNK);
    await mergeEntries(admin, cat.id, await readMeclibPages(book, slice));
    const next = from + slice.length;
    if (next >= list.pages.length) {
      const done = await finishCatalog(admin, cat.id, list.pages.length, "jan_catalog.sync");
      return [200, { data: { done: true, catalog: done, page: next, pages: list.pages.length } }];
    }
    await admin.from("jan_catalogs").update({ next_page: next, pages_read: next }).eq("id", cat.id);
    return [200, { data: { done: false, catalog_id: cat.id, page: next, pages: list.pages.length } }];
  } catch (e) {
    await admin.from("jan_catalogs").update({ sync_error: `${e}`.slice(0, 500) }).eq("id", cat.id);
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
  if (cat.kind === "meclib") return await stepMeclib(admin, cat, from);
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
