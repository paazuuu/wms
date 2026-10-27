// JAN catalogs (0153): a maker's catalog read for its JAN codes.
//   GET    /jan-catalog            the catalogs registered, with their counts
//   POST   /jan-catalog/sync {url} read the catalog at a viewer URL (a mediapress
//                                  iCata page) and replace its JANs
//   DELETE /jan-catalog/:id        forget a catalog and its JANs
//
// Reading: every page a search for 49 / 45 (a Japanese JAN's start) finds,
// its text, each JAN with what is printed before it (see
// ../_shared/jan_catalog.ts). Only a mediapress host is fetched from.
//   POST   /jan-catalog/refresh     every catalog read again (the monthly job)
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
import {
  type CatalogEntry,
  catalogInfo,
  type CatalogRef,
  entriesFromItems,
  entriesFromPage,
  makerFromSearch,
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

async function readCatalog(c: CatalogRef) {
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
  const entries: CatalogEntry[] = [];
  let read = 0;
  const queue = [...pages];
  await Promise.all(
    Array.from({ length: PARALLEL }, async () => {
      for (let p = queue.shift(); p; p = queue.shift()) {
        const xml = await fetchText(api(c, { api: "getCatalogviewTextposition", pageid: p.id, keyword: "" }));
        entries.push(...entriesFromPage(xml, p));
        read++;
      }
    }),
  );
  // Pages in order, so a JAN keeps the first page it is on.
  const order = new Map(pages.map((p, i) => [p.number + "/" + p.group, i]));
  entries.sort((a, b) => (order.get(a.page_number + "/" + a.page_group) ?? 0) - (order.get(b.page_number + "/" + b.page_group) ?? 0));
  return { info, maker, pagesRead: read, entries: uniqueEntries(entries) };
}

type Admin = ReturnType<typeof adminClient>;

/** Read the catalog at [url] and replace its JANs: [status, body]. */
async function syncCatalog(admin: Admin, url: string, userId: string | null): Promise<[number, unknown]> {
  const ref = parseCatalogUrl(url);
  if (!ref) return [400, { message: "jan_catalog_bad_url" }];

  const { data: row, error: upErr } = await admin
    .from("jan_catalogs")
    .upsert(
      {
        url: url.trim(),
        kind: "icata",
        host: ref.host,
        volume_id: ref.volumeId,
        catalog_id: ref.catalogId,
        design_id: ref.designId,
        ...(userId ? { created_by: userId } : {}),
      },
      { onConflict: "volume_id,catalog_id" },
    )
    .select("id")
    .single();
  if (upErr || !row) return [400, { message: upErr?.message ?? "upsert failed" }];
  const id = row.id as number;

  let read;
  try {
    read = await readCatalog(ref);
  } catch (e) {
    await admin.from("jan_catalogs").update({ sync_error: `${e}`.slice(0, 500) }).eq("id", id);
    return [502, { message: `jan_catalog_unreachable: ${e}` }];
  }
  if (read.entries.length === 0) {
    await admin.from("jan_catalogs").update({ sync_error: "no JAN found", pages_read: read.pagesRead }).eq("id", id);
    return [422, { message: "jan_catalog_empty" }];
  }

  // Replace what the catalog had: what it no longer prints goes.
  const del = await admin.from("jan_catalog_entries").delete().eq("catalog_id", id);
  if (del.error) return [400, { message: del.error.message }];
  for (let k = 0; k < read.entries.length; k += 500) {
    const { error } = await admin
      .from("jan_catalog_entries")
      .insert(read.entries.slice(k, k + 500).map((e) => ({ catalog_id: id, ...e })));
    if (error) return [400, { message: error.message }];
  }
  const { data: done, error: finErr } = await admin
    .from("jan_catalogs")
    .update({
      maker: read.maker,
      name: read.info.name,
      published: read.info.published,
      page_count: read.info.pageCount,
      pages_read: read.pagesRead,
      entry_count: read.entries.length,
      synced_at: new Date().toISOString(),
      sync_error: null,
    })
    .eq("id", id)
    .select("*")
    .single();
  if (finErr) return [400, { message: finErr.message }];
  await admin.rpc("apply_jan_weights", { p_jans: null });
  await admin.rpc("log_audit", {
    p_event_type: "jan_catalog.sync",
    p_entity_type: "jan_catalog",
    p_entity_id: String(id),
    p_warehouse_id: null,
    p_details: { url, entries: read.entries.length, pages: read.pagesRead },
  }).then(() => {}, () => {});
  return [200, { data: done }];
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
    if (unique.length === 0) return [200, { data: { entries: 0, weights: 0 } }];
    // What earlier pages already gave: kept; a weight added where it had none.
    const { data: had, error: hadErr } = await admin
      .from("jan_catalog_entries")
      .select("jan, weight_g")
      .eq("catalog_id", id)
      .in("jan", unique.map((e) => e.jan));
    if (hadErr) return [400, { message: hadErr.message }];
    const known = new Map((had ?? []).map((h) => [h.jan as string, h.weight_g as number | null]));
    const fresh = unique.filter((e) => !known.has(e.jan));
    if (fresh.length > 0) {
      const { error } = await admin.from("jan_catalog_entries").insert(fresh.map((e) => ({ catalog_id: id, ...e })));
      if (error) return [400, { message: error.message }];
    }
    for (const e of unique) {
      if (known.has(e.jan) && known.get(e.jan) == null && e.weight_g != null) {
        await admin.from("jan_catalog_entries")
          .update({ weight_g: e.weight_g, weight_text: e.weight_text, weight_basis: e.weight_basis })
          .eq("catalog_id", id).eq("jan", e.jan);
      }
    }
    return [200, { data: { entries: fresh.length, weights: unique.filter((e) => e.weight_g != null).length } }];
  }

  if (step === "finish") {
    const { count } = await admin.from("jan_catalog_entries").select("jan", { count: "exact", head: true }).eq("catalog_id", id);
    const { data: done, error } = await admin
      .from("jan_catalogs")
      .update({
        entry_count: count ?? 0,
        pages_read: Number.isFinite(Number(body?.pages_read)) ? Number(body.pages_read) : 0,
        synced_at: new Date().toISOString(),
        sync_error: (count ?? 0) === 0 ? "no JAN found" : null,
      })
      .eq("id", id)
      .select("*")
      .single();
    if (error) return [400, { message: error.message }];
    await admin.rpc("apply_jan_weights", { p_jans: null });
    await admin.rpc("log_audit", {
      p_event_type: "jan_catalog.pdf",
      p_entity_type: "jan_catalog",
      p_entity_id: String(id),
      p_warehouse_id: null,
      p_details: { entries: count ?? 0, pages: body?.pages_read ?? null },
    }).then(() => {}, () => {});
    return [200, { data: done }];
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
    const byScheduler = await purgeAllowed(admin as any, req.headers.get("x-purge-secret"));

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
      const [status, out] = await syncCatalog(admin, String(body?.url ?? ""), userId);
      return json(out, status);
    }

    // Every catalog read again (the monthly job): what each came to.
    if (req.method === "POST" && rest[0] === "refresh" && rest.length === 1) {
      const { data, error } = await admin.from("jan_catalogs").select("url").eq("kind", "icata").order("id");
      if (error) return json({ message: error.message }, 400);
      const results = [];
      for (const c of data ?? []) {
        const [status, out] = await syncCatalog(admin, c.url as string, userId);
        results.push({ url: c.url, status, ...(status === 200 ? {} : (out as object)) });
      }
      return json({ data: results });
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
