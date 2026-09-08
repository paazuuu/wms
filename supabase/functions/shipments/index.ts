// Outbound / shipping API for the WMS mobile client.
// Routes (function is mounted at /functions/v1/shipments):
//   GET    /shipments                       list (?status=&search=)
//   GET    /shipments/:id                   one shipment + lines + cartons(+items)
//   POST   /shipments/:id/ship              confirm: deduct stock, mark shipped
//   POST   /shipments/:id/cancel            undo: restore stock, back to open
//   POST   /shipments/:id/cartons           create a carton {label?}
//   PUT    /shipments/:id/cartons/:cid      replace a carton {label?, items:[…]}
//   DELETE /shipments/:id/cartons/:cid      delete a carton
//
// Uses the service role internally; verify_jwt=true (the app's anon key
// qualifies). Stock is only ever changed by the ship/cancel RPCs.
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
};
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const DETAIL =
  "*, lines:shipment_lines(*), cartons:shipment_cartons(*, items:shipment_carton_items(*))";

async function loadDetail(id: number): Promise<Response> {
  const { data, error } = await supabase
    .from("shipment_plans").select(DETAIL).eq("id", id).single();
  if (error) return json({ message: error.message }, 404);
  return json({ data });
}

function toInt(v: unknown): number {
  const n = Number(v);
  return Number.isFinite(n) ? Math.round(n) : 0;
}
function str(v: unknown): string | null {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  return s === "" ? null : s;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const url = new URL(req.url);
    const parts = url.pathname.split("/").filter(Boolean);
    const i = parts.indexOf("shipments");
    const rest = i >= 0 ? parts.slice(i + 1) : [];

    // GET /shipments
    if (req.method === "GET" && rest.length === 0) {
      const status = url.searchParams.get("status");
      const search = url.searchParams.get("search");
      let q = supabase
        .from("shipment_plans")
        .select("*, line_count:shipment_lines(count), carton_count:shipment_cartons(count)")
        .order("id", { ascending: false })
        .limit(50);
      if (status) q = q.eq("status", status);
      if (search && search.trim()) {
        const s = search.trim();
        q = q.or(`shipment_number.ilike.%${s}%,customer_name.ilike.%${s}%,customer_code.ilike.%${s}%`);
      }
      const { data, error } = await q;
      if (error) return json({ message: error.message }, 400);
      const flat = (data ?? []).map((p: Record<string, unknown>) => {
        const lc = p["line_count"];
        const cc = p["carton_count"];
        if (Array.isArray(lc)) p["line_count"] = (lc[0]?.count as number) ?? 0;
        if (Array.isArray(cc)) p["carton_count"] = (cc[0]?.count as number) ?? 0;
        return p;
      });
      return json({ data: flat });
    }

    // GET /shipments/:id
    if (req.method === "GET" && rest.length === 1) {
      return await loadDetail(Number(rest[0]));
    }

    // POST /shipments/:id/ship
    if (req.method === "POST" && rest.length === 2 && rest[1] === "ship") {
      const id = Number(rest[0]);
      const { error } = await supabase.rpc("ship_plan", { p_plan_id: id });
      if (error) return json({ message: error.message }, 400);
      return await loadDetail(id);
    }

    // POST /shipments/:id/cancel
    if (req.method === "POST" && rest.length === 2 && rest[1] === "cancel") {
      const id = Number(rest[0]);
      const { error } = await supabase.rpc("cancel_shipment", { p_plan_id: id });
      if (error) return json({ message: error.message }, 400);
      return await loadDetail(id);
    }

    // POST /shipments/:id/cartons  → create a carton
    if (req.method === "POST" && rest.length === 2 && rest[1] === "cartons") {
      const id = Number(rest[0]);
      const body = await req.json().catch(() => ({}));
      const { data: last } = await supabase
        .from("shipment_cartons")
        .select("carton_no")
        .eq("shipment_plan_id", id)
        .order("carton_no", { ascending: false })
        .limit(1)
        .maybeSingle();
      const nextNo = ((last?.carton_no as number) ?? 0) + 1;
      const { error } = await supabase.from("shipment_cartons").insert({
        shipment_plan_id: id, carton_no: nextNo, label: str(body.label),
      });
      if (error) return json({ message: error.message }, 400);
      return await loadDetail(id);
    }

    // PUT /shipments/:id/cartons/:cid  → replace a carton's label + items
    if (req.method === "PUT" && rest.length === 3 && rest[1] === "cartons") {
      const id = Number(rest[0]);
      const cid = Number(rest[2]);
      const body = await req.json().catch(() => ({}));
      if (body.label !== undefined) {
        await supabase.from("shipment_cartons")
          .update({ label: str(body.label) }).eq("id", cid);
      }
      await supabase.from("shipment_carton_items").delete().eq("carton_id", cid);
      const items = Array.isArray(body.items) ? body.items : [];
      const rows = items
        .map((it: Record<string, unknown>) => ({
          carton_id: cid,
          shipment_line_id: it.shipment_line_id ?? null,
          jan_code: String(it.jan_code ?? ""),
          product_name: str(it.product_name) ?? "",
          spec: str(it.spec),
          quantity: toInt(it.quantity),
        }))
        .filter((r) => r.jan_code !== "" && r.quantity > 0);
      if (rows.length > 0) {
        const { error } = await supabase.from("shipment_carton_items").insert(rows);
        if (error) return json({ message: error.message }, 400);
      }
      return await loadDetail(id);
    }

    // DELETE /shipments/:id/cartons/:cid
    if (req.method === "DELETE" && rest.length === 3 && rest[1] === "cartons") {
      const id = Number(rest[0]);
      const cid = Number(rest[2]);
      const { error } = await supabase.from("shipment_cartons").delete().eq("id", cid);
      if (error) return json({ message: error.message }, 400);
      return await loadDetail(id);
    }

    return json({ message: "Not found" }, 404);
  } catch (e) {
    return json({ message: String(e) }, 500);
  }
});
