// Picking API for the WMS mobile client (spec Step 7, §14).
// Routes (function is mounted at /functions/v1/picking):
//   GET   /picking/lists?warehouse_id=&status=      pick list index
//   POST  /picking/lists                            {shipment_plan_id, note?} → open/return one
//   GET   /picking/lists/:id                         one list + its tasks
//   PATCH /picking/tasks/:id                         {quantity, bin_id?, note?} record a pick
//   POST  /picking/lists/:id/complete                close the list, hand off to packing
//   POST  /picking/lists/:id/cancel                  release without moving stock
//   GET   /picking/availability?warehouse_id=&jan_code=  on-hand minus open reservations
//
// Stock never moves here — picking only records what left the shelf; shipping
// (the `shipments` function) is what actually debits the ledger.
//
// Warehouse scope (UI spec §37) is split by direction here:
//
//   READS  run on the caller's client, so 0052's `pick_lists_read` /
//          `pick_tasks_read` policies scope them, and since 0056 both
//          `pick_list_index` and `pick_list_detail` scope themselves as well.
//          listDetail() still gates first, so an out-of-scope id answers 404
//          rather than a null body.
//   WRITES run on the service role, because start/complete/cancel_pick_list
//          and record_pick are granted to `service_role` only — an
//          `authenticated` client gets "permission denied for function". They
//          also contain no has_permission() or can_access_warehouse() of
//          their own, so the gate in front of each one is the only warehouse
//          check that exists on these paths.
//
// See ../_shared/require_permission.ts for the full rule.
import {
  adminClient,
  callerCanSee,
  callerClient,
  clientCanAccessWarehouse,
  clientPermitted,
  notInScopeMessage,
  notPermittedMessage,
} from "../_shared/require_permission.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, PATCH, OPTIONS",
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

function str(v: unknown): string | null {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  return s === "" ? null : s;
}

// The per-request caller client, threaded into helpers rather than captured
// from module scope — there is no module-level client any more, because the
// client has to carry the caller's JWT for warehouse scope to apply.
// deno-lint-ignore no-explicit-any
type Client = any;

// 0056 gave `pick_list_detail` its own scope predicate, so this check is no
// longer the only thing standing between a guessed id and another warehouse's
// list. It stays because it turns "scoped out" into a clean 404 here rather
// than a null body the caller has to interpret.
async function listDetail(supabase: Client, id: number): Promise<Response> {
  if (!(await callerCanSee(supabase, "pick_lists", id))) {
    return json({ message: "pick list not found" }, 404);
  }
  const { data, error } = await supabase.rpc("pick_list_detail", {
    p_pick_list_id: id,
  });
  if (error) return json({ message: error.message }, 400);
  if (!data || (data as Record<string, unknown>).id === undefined) {
    return json({ message: "pick list not found" }, 404);
  }
  return json({ data });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    // One client per request, carrying the caller's Authorization header.
    const supabase = callerClient(req, supabaseUrl);
    const url = new URL(req.url);
    const parts = url.pathname.split("/").filter(Boolean);
    const i = parts.indexOf("picking");
    const rest = i >= 0 ? parts.slice(i + 1) : [];
    const warehouseId = url.searchParams.get("warehouse_id");

    // GET /picking/lists
    if (req.method === "GET" && rest[0] === "lists" && rest.length === 1) {
      const status = url.searchParams.get("status");
      const { data, error } = await supabase.rpc("pick_list_index", {
        p_warehouse_id: warehouseId ? Number(warehouseId) : null,
        p_status: status,
        p_limit: 50,
      });
      if (error) return json({ message: error.message }, 400);
      return json({ data: data ?? [] });
    }

    // POST /picking/lists  → open (or return) the list for one shipment plan
    if (req.method === "POST" && rest[0] === "lists" && rest.length === 1) {
      if (!(await clientPermitted(supabase, "pick.confirm"))) {
        return json({ message: notPermittedMessage("pick.confirm") }, 403);
      }
      const body = await req.json().catch(() => ({}));
      const planId = Number(body.shipment_plan_id);
      if (!Number.isFinite(planId)) {
        return json({ message: "shipment_plan_id is required" }, 422);
      }
      // The list inherits the plan's warehouse, so the plan is what to gate on.
      if (!(await callerCanSee(supabase, "shipment_plans", planId))) {
        return json({ message: "shipment plan not found" }, 404);
      }
      const { data, error } = await admin.rpc("start_pick_list", {
        p_shipment_plan_id: planId,
        p_note: str(body.note),
      });
      if (error) return json({ message: error.message }, 400);
      return await listDetail(supabase, Number(data));
    }

    // GET /picking/lists/:id
    if (req.method === "GET" && rest[0] === "lists" && rest.length === 2) {
      const id = Number(rest[1]);
      if (!Number.isFinite(id)) return json({ message: "bad id" }, 400);
      return await listDetail(supabase, id);
    }

    // POST /picking/lists/:id/complete
    if (
      req.method === "POST" && rest[0] === "lists" && rest.length === 3 &&
      rest[2] === "complete"
    ) {
      if (!(await clientPermitted(supabase, "pick.confirm"))) {
        return json({ message: notPermittedMessage("pick.confirm") }, 403);
      }
      const id = Number(rest[1]);
      if (!Number.isFinite(id)) return json({ message: "bad id" }, 400);
      if (!(await callerCanSee(supabase, "pick_lists", id))) {
        return json({ message: "pick list not found" }, 404);
      }
      const { data, error } = await admin.rpc("complete_pick_list", {
        p_pick_list_id: id,
      });
      if (error) return json({ message: error.message }, 400);
      const detail = await supabase.rpc("pick_list_detail", {
        p_pick_list_id: id,
      });
      return json({ data: detail.data, summary: data });
    }

    // POST /picking/lists/:id/cancel
    if (
      req.method === "POST" && rest[0] === "lists" && rest.length === 3 &&
      rest[2] === "cancel"
    ) {
      if (!(await clientPermitted(supabase, "pick.confirm"))) {
        return json({ message: notPermittedMessage("pick.confirm") }, 403);
      }
      const id = Number(rest[1]);
      if (!Number.isFinite(id)) return json({ message: "bad id" }, 400);
      if (!(await callerCanSee(supabase, "pick_lists", id))) {
        return json({ message: "pick list not found" }, 404);
      }
      const { error } = await admin.rpc("cancel_pick_list", {
        p_pick_list_id: id,
      });
      if (error) return json({ message: error.message }, 400);
      return await listDetail(supabase, id);
    }

    // PATCH /picking/tasks/:id  → record what was actually picked
    if (req.method === "PATCH" && rest[0] === "tasks" && rest.length === 2) {
      if (!(await clientPermitted(supabase, "pick.confirm"))) {
        return json({ message: notPermittedMessage("pick.confirm") }, 403);
      }
      const taskId = Number(rest[1]);
      if (!Number.isFinite(taskId)) return json({ message: "bad id" }, 400);
      const body = await req.json().catch(() => ({}));
      const quantity = Number(body.quantity);
      if (!Number.isFinite(quantity)) {
        return json({ message: "quantity must be a number" }, 422);
      }
      // On the caller's client, so `pick_tasks_read` (which reaches through to
      // the list's warehouse) makes this lookup the scope gate for the write.
      const { data: listId, error: listErr } = await supabase
        .from("pick_tasks").select("pick_list_id").eq("id", taskId).maybeSingle();
      if (listErr || !listId) return json({ message: "pick task not found" }, 404);
      const { error } = await admin.rpc("record_pick", {
        p_task_id: taskId,
        p_quantity: Math.round(quantity),
        p_bin_id: body.bin_id != null ? Number(body.bin_id) : null,
        p_note: str(body.note),
      });
      if (error) return json({ message: error.message }, 400);
      return await listDetail(supabase, (listId as { pick_list_id: number }).pick_list_id);
    }

    // GET /picking/availability
    if (req.method === "GET" && rest[0] === "availability" && rest.length === 1) {
      const janCode = url.searchParams.get("jan_code");
      // 0056 put the scope predicate inside `stock_availability` itself, so an
      // omitted warehouse now means "every warehouse I may see" rather than
      // every warehouse. This check stays so a NAMED warehouse outside the
      // caller's scope is refused outright instead of silently returning [].
      const wh = warehouseId ? Number(warehouseId) : null;
      if (wh !== null && !(await clientCanAccessWarehouse(supabase, wh))) {
        return json({ message: notInScopeMessage(wh) }, 403);
      }
      const { data, error } = await supabase.rpc("stock_availability", {
        p_warehouse_id: wh,
        p_jan_code: janCode,
      });
      if (error) return json({ message: error.message }, 400);
      return json({ data: data ?? [] });
    }

    return json({ message: "not found" }, 404);
  } catch (e) {
    return json({ message: `${e}` }, 500);
  }
});
