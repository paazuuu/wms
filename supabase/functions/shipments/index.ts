// Outbound / shipping API for the WMS mobile client.
// Routes (function is mounted at /functions/v1/shipments):
//   GET    /shipments                       list (?status=&search=&warehouse_id=)
//   GET    /shipments/:id                   one shipment + lines + cartons(+items)
//   POST   /shipments/:id/ship              confirm: deduct stock, mark shipped
//   POST   /shipments/:id/cancel            undo: restore stock, back to open
//   POST   /shipments/:id/cartons           create a carton {label?}
//   PUT    /shipments/:id/cartons/:cid      replace a carton {label?, items:[…]}
//   DELETE /shipments/:id/cartons/:cid      delete a carton
//
// Warehouse scope (UI spec §37) is split by direction:
//
//   READS  run on the caller's client, so 0052's `read shipments`,
//          `read shipment lines`, `read cartons` and `read carton items`
//          policies scope them. Before this, every read here ran as service
//          role, which holds `rolbypassrls` — so a warehouse-1 packer could
//          list and open every warehouse's shipments.
//   WRITES run on the service role: ship_plan and cancel_shipment are granted
//          to `service_role` only, and there are no INSERT/UPDATE/DELETE
//          policies for `authenticated` on the carton tables. Neither RPC
//          contains a has_permission() or can_access_warehouse() call, so the
//          gate in front of each write is the only warehouse check on these
//          paths.
//
// The carton routes address a carton by id and the plan by id separately, so
// each one proves the carton actually belongs to that plan as well — otherwise
// a guessed carton id would be editable through any plan's URL.
//
// Stock is only ever changed by the ship/cancel RPCs. ship.complete gates
// confirming/cancelling the shipment itself; pack.complete gates the carton
// edits that lead up to it. See ../_shared/require_permission.ts.
import {
  adminClient,
  callerCanSee,
  callerClient,
  clientPermitted,
  notPermittedMessage,
} from "../_shared/require_permission.ts";

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

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
// Writes only, and only behind a scope gate. See the header.
const admin = adminClient(supabaseUrl);

const DETAIL =
  "*, lines:shipment_lines(*), cartons:shipment_cartons(*, items:shipment_carton_items(*))";

// The per-request caller client, threaded in rather than captured from module
// scope — it has to carry this request's JWT for warehouse scope to apply.
// deno-lint-ignore no-explicit-any
type Client = any;

// A plain table read, so `read shipments` scopes it: a plan outside the
// caller's warehouses is simply not found. Every mutation answers with
// loadDetail(), so it is also their post-write confirmation.
async function loadDetail(supabase: Client, id: number): Promise<Response> {
  const { data, error } = await supabase
    .from("shipment_plans").select(DETAIL).eq("id", id).maybeSingle();
  if (error) return json({ message: error.message }, 400);
  if (!data) return json({ message: "shipment not found" }, 404);
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
    // One caller-scoped client per request. Only writes reach for `admin`.
    const supabase = callerClient(req, supabaseUrl);
    const url = new URL(req.url);
    const parts = url.pathname.split("/").filter(Boolean);
    const i = parts.indexOf("shipments");
    const rest = i >= 0 ? parts.slice(i + 1) : [];

    /** Gate for the carton routes: the plan must be visible to the caller AND
     * the carton must belong to it. One lookup on the caller's client settles
     * both, because `read cartons` reaches through to the plan's warehouse. */
    const cartonInPlan = async (planId: number, cartonId: number) => {
      if (!Number.isFinite(planId) || !Number.isFinite(cartonId)) return false;
      const { data, error } = await supabase
        .from("shipment_cartons")
        .select("id")
        .eq("id", cartonId)
        .eq("shipment_plan_id", planId)
        .maybeSingle();
      return !error && !!data;
    };

    // GET /shipments
    if (req.method === "GET" && rest.length === 0) {
      const status = url.searchParams.get("status");
      const search = url.searchParams.get("search");
      // Optional warehouse scope (UI spec §4: switching the current warehouse
      // switches Shipping too). Omitted = every warehouse, which is what the
      // "all warehouses" scope and every older client sends.
      const warehouseId = Number(url.searchParams.get("warehouse_id"));
      let q = supabase
        .from("shipment_plans")
        .select("*, line_count:shipment_lines(count), carton_count:shipment_cartons(count)")
        .order("id", { ascending: false })
        .limit(50);
      if (status) q = q.eq("status", status);
      if (Number.isFinite(warehouseId) && warehouseId > 0) {
        q = q.eq("warehouse_id", warehouseId);
      }
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
      return await loadDetail(supabase, Number(rest[0]));
    }

    // POST /shipments/:id/ship
    if (req.method === "POST" && rest.length === 2 && rest[1] === "ship") {
      if (!(await clientPermitted(supabase, "ship.complete"))) {
        return json({ message: notPermittedMessage("ship.complete") }, 403);
      }
      const id = Number(rest[0]);
      // ship_plan debits the ledger and checks nothing itself. This is the gate.
      if (!(await callerCanSee(supabase, "shipment_plans", id))) {
        return json({ message: "shipment not found" }, 404);
      }
      const { error } = await admin.rpc("ship_plan", { p_plan_id: id });
      if (error) return json({ message: error.message }, 400);
      return await loadDetail(supabase, id);
    }

    // POST /shipments/:id/cancel
    if (req.method === "POST" && rest.length === 2 && rest[1] === "cancel") {
      if (!(await clientPermitted(supabase, "ship.complete"))) {
        return json({ message: notPermittedMessage("ship.complete") }, 403);
      }
      const id = Number(rest[0]);
      if (!(await callerCanSee(supabase, "shipment_plans", id))) {
        return json({ message: "shipment not found" }, 404);
      }
      const { error } = await admin.rpc("cancel_shipment", { p_plan_id: id });
      if (error) return json({ message: error.message }, 400);
      return await loadDetail(supabase, id);
    }

    // POST /shipments/:id/cartons  → create a carton
    if (req.method === "POST" && rest.length === 2 && rest[1] === "cartons") {
      if (!(await clientPermitted(supabase, "pack.complete"))) {
        return json({ message: notPermittedMessage("pack.complete") }, 403);
      }
      const id = Number(rest[0]);
      // No carton yet, so the plan itself is what to gate on.
      if (!(await callerCanSee(supabase, "shipment_plans", id))) {
        return json({ message: "shipment not found" }, 404);
      }
      const body = await req.json().catch(() => ({}));
      const { data: last } = await supabase
        .from("shipment_cartons")
        .select("carton_no")
        .eq("shipment_plan_id", id)
        .order("carton_no", { ascending: false })
        .limit(1)
        .maybeSingle();
      const nextNo = ((last?.carton_no as number) ?? 0) + 1;
      const { error } = await admin.from("shipment_cartons").insert({
        shipment_plan_id: id, carton_no: nextNo, label: str(body.label),
      });
      if (error) return json({ message: error.message }, 400);
      return await loadDetail(supabase, id);
    }

    // PUT /shipments/:id/cartons/:cid  → replace a carton's label + items
    if (req.method === "PUT" && rest.length === 3 && rest[1] === "cartons") {
      if (!(await clientPermitted(supabase, "pack.complete"))) {
        return json({ message: notPermittedMessage("pack.complete") }, 403);
      }
      const id = Number(rest[0]);
      const cid = Number(rest[2]);
      if (!(await cartonInPlan(id, cid))) {
        return json({ message: "carton not found" }, 404);
      }
      const body = await req.json().catch(() => ({}));
      if (body.label !== undefined) {
        await admin.from("shipment_cartons")
          .update({ label: str(body.label) }).eq("id", cid);
      }
      await admin.from("shipment_carton_items").delete().eq("carton_id", cid);
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
        const { error } = await admin.from("shipment_carton_items").insert(rows);
        if (error) return json({ message: error.message }, 400);
      }
      return await loadDetail(supabase, id);
    }

    // DELETE /shipments/:id/cartons/:cid
    if (req.method === "DELETE" && rest.length === 3 && rest[1] === "cartons") {
      if (!(await clientPermitted(supabase, "pack.complete"))) {
        return json({ message: notPermittedMessage("pack.complete") }, 403);
      }
      const id = Number(rest[0]);
      const cid = Number(rest[2]);
      if (!(await cartonInPlan(id, cid))) {
        return json({ message: "carton not found" }, 404);
      }
      const { error } = await admin.from("shipment_cartons").delete().eq("id", cid);
      if (error) return json({ message: error.message }, 400);
      return await loadDetail(supabase, id);
    }

    return json({ message: "Not found" }, 404);
  } catch (e) {
    return json({ message: String(e) }, 500);
  }
});
