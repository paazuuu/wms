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
// Uses the service role internally; verify_jwt=true. Stock never moves here —
// picking only records what left the shelf; shipping (the `shipments`
// function) is what actually debits the ledger.
import { createClient } from "jsr:@supabase/supabase-js@2";

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

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

function str(v: unknown): string | null {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  return s === "" ? null : s;
}

async function listDetail(id: number): Promise<Response> {
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
      // TODO(auth): require picking.perform for the caller.
      const body = await req.json().catch(() => ({}));
      const planId = Number(body.shipment_plan_id);
      if (!Number.isFinite(planId)) {
        return json({ message: "shipment_plan_id is required" }, 422);
      }
      const { data, error } = await supabase.rpc("start_pick_list", {
        p_shipment_plan_id: planId,
        p_note: str(body.note),
      });
      if (error) return json({ message: error.message }, 400);
      return await listDetail(Number(data));
    }

    // GET /picking/lists/:id
    if (req.method === "GET" && rest[0] === "lists" && rest.length === 2) {
      const id = Number(rest[1]);
      if (!Number.isFinite(id)) return json({ message: "bad id" }, 400);
      return await listDetail(id);
    }

    // POST /picking/lists/:id/complete
    if (
      req.method === "POST" && rest[0] === "lists" && rest.length === 3 &&
      rest[2] === "complete"
    ) {
      const id = Number(rest[1]);
      if (!Number.isFinite(id)) return json({ message: "bad id" }, 400);
      const { data, error } = await supabase.rpc("complete_pick_list", {
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
      const id = Number(rest[1]);
      if (!Number.isFinite(id)) return json({ message: "bad id" }, 400);
      const { error } = await supabase.rpc("cancel_pick_list", {
        p_pick_list_id: id,
      });
      if (error) return json({ message: error.message }, 400);
      return await listDetail(id);
    }

    // PATCH /picking/tasks/:id  → record what was actually picked
    if (req.method === "PATCH" && rest[0] === "tasks" && rest.length === 2) {
      const taskId = Number(rest[1]);
      if (!Number.isFinite(taskId)) return json({ message: "bad id" }, 400);
      const body = await req.json().catch(() => ({}));
      const quantity = Number(body.quantity);
      if (!Number.isFinite(quantity)) {
        return json({ message: "quantity must be a number" }, 422);
      }
      const { data: listId, error: listErr } = await supabase
        .from("pick_tasks").select("pick_list_id").eq("id", taskId).single();
      if (listErr || !listId) return json({ message: "pick task not found" }, 404);
      const { error } = await supabase.rpc("record_pick", {
        p_task_id: taskId,
        p_quantity: Math.round(quantity),
        p_bin_id: body.bin_id != null ? Number(body.bin_id) : null,
        p_note: str(body.note),
      });
      if (error) return json({ message: error.message }, 400);
      return await listDetail((listId as { pick_list_id: number }).pick_list_id);
    }

    // GET /picking/availability
    if (req.method === "GET" && rest[0] === "availability" && rest.length === 1) {
      const janCode = url.searchParams.get("jan_code");
      const { data, error } = await supabase.rpc("stock_availability", {
        p_warehouse_id: warehouseId ? Number(warehouseId) : null,
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
