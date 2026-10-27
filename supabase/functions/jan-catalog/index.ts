// JAN catalogs (0153): a maker's catalog read for its JAN codes.
//   GET    /jan-catalog            the catalogs registered, with their counts
//   POST   /jan-catalog/sync {url} read the catalog at a viewer URL (a mediapress
//                                  iCata page) and replace its JANs
//   DELETE /jan-catalog/:id        forget a catalog and its JANs
//
// Reading: every page a search for 49 / 45 (a Japanese JAN's start) finds,
// its text, each JAN with what is printed before it (see
// ../_shared/jan_catalog.ts). Only a mediapress host is fetched from.
// Writing needs product.manage and goes through the service role; reading
// the table is open to product.view through its own policy.
import { adminClient, callerClient, clientPermitted, notPermittedMessage } from "../_shared/require_permission.ts";
import {
  type CatalogEntry,
  catalogInfo,
  type CatalogRef,
  entriesFromPage,
  makerFromSearch,
  type PageRef,
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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const caller = callerClient(req, supabaseUrl);
    const parts = new URL(req.url).pathname.split("/").filter(Boolean);
    const i = parts.indexOf("jan-catalog");
    const rest = i >= 0 ? parts.slice(i + 1) : [];

    if (req.method === "GET" && rest.length === 0) {
      const { data, error } = await caller.from("jan_catalogs").select("*").order("id");
      if (error) return json({ message: error.message }, 400);
      return json({ data: data ?? [] });
    }

    if (!(await clientPermitted(caller, "product.manage"))) {
      return json({ message: notPermittedMessage("product.manage") }, 403);
    }
    const admin = adminClient(supabaseUrl);
    const { data: who } = await caller.auth.getUser();

    if (req.method === "DELETE" && rest.length === 1 && /^\d+$/.test(rest[0])) {
      const { error } = await admin.from("jan_catalogs").delete().eq("id", Number(rest[0]));
      if (error) return json({ message: error.message }, 400);
      return json({ data: { deleted: Number(rest[0]) } });
    }

    if (req.method === "POST" && rest[0] === "sync" && rest.length === 1) {
      const body = await req.json().catch(() => ({}));
      const ref = parseCatalogUrl(String(body?.url ?? ""));
      if (!ref) return json({ message: "jan_catalog_bad_url" }, 400);

      const { data: row, error: upErr } = await admin
        .from("jan_catalogs")
        .upsert(
          {
            url: String(body.url).trim(),
            host: ref.host,
            volume_id: ref.volumeId,
            catalog_id: ref.catalogId,
            design_id: ref.designId,
            created_by: who?.user?.id ?? null,
          },
          { onConflict: "volume_id,catalog_id" },
        )
        .select("id")
        .single();
      if (upErr || !row) return json({ message: upErr?.message ?? "upsert failed" }, 400);
      const id = row.id as number;

      let read;
      try {
        read = await readCatalog(ref);
      } catch (e) {
        await admin.from("jan_catalogs").update({ sync_error: `${e}`.slice(0, 500) }).eq("id", id);
        return json({ message: `jan_catalog_unreachable: ${e}` }, 502);
      }
      if (read.entries.length === 0) {
        await admin.from("jan_catalogs").update({ sync_error: "no JAN found", pages_read: read.pagesRead }).eq("id", id);
        return json({ message: "jan_catalog_empty" }, 422);
      }

      // Replace what the catalog had: what it no longer prints goes.
      const del = await admin.from("jan_catalog_entries").delete().eq("catalog_id", id);
      if (del.error) return json({ message: del.error.message }, 400);
      for (let k = 0; k < read.entries.length; k += 500) {
        const { error } = await admin
          .from("jan_catalog_entries")
          .insert(read.entries.slice(k, k + 500).map((e) => ({ catalog_id: id, ...e })));
        if (error) return json({ message: error.message }, 400);
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
      if (finErr) return json({ message: finErr.message }, 400);
      await admin.rpc("log_audit", {
        p_event_type: "jan_catalog.sync",
        p_entity_type: "jan_catalog",
        p_entity_id: String(id),
        p_warehouse_id: null,
        p_details: { url: body.url, entries: read.entries.length, pages: read.pagesRead },
      }).then(() => {}, () => {});
      return json({ data: done });
    }

    return json({ message: "not found" }, 404);
  } catch (e) {
    return json({ message: `${e}` }, 500);
  }
});
