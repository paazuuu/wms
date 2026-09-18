// Inbound inspection (検品) API for the WMS client (spec §10, §11, §40).
// Routes (function is mounted at /functions/v1/inspections):
//   GET   /inspections                      list (?status=&warehouse_id=)
//   GET   /inspections/:id                  one inspection + its items
//   POST  /inspections                      {reconciliation_id} start (idempotent)
//   PATCH /inspections/:id/items/:itemId    record one item's findings
//   POST  /inspections/:id/complete         {note?} roll up and close
//
// Warehouse scope (UI spec §37) is split by direction:
//
//   READS  run on the caller's client, so 0052's `read inspections` /
//          `read inspection items` policies scope them. `inspection_detail`
//          does not scope itself, so detail() gates first.
//   WRITES run on the service role, because start_inspection,
//          save_inspection_item and complete_inspection are granted to
//          `service_role` only and contain no has_permission() or
//          can_access_warehouse() of their own. The gate in front of each is
//          the only warehouse check on these paths.
//
// See ../_shared/require_permission.ts for the full rule.
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
function int(v: unknown): number {
  const n = Number(v);
  return Number.isFinite(n) ? Math.max(Math.round(n), 0) : 0;
}

// The per-request caller client, threaded into helpers rather than captured
// from module scope — there is no module-level client any more, because the
// client has to carry the caller's JWT for warehouse scope to apply.
// deno-lint-ignore no-explicit-any
type Client = any;

// The visibility check is what scopes this read, and since every mutation
// answers with detail(), it doubles as their post-write gate. Out of scope and
// non-existent both answer 404 on purpose.
async function detail(supabase: Client, id: number): Promise<Response> {
  if (!(await callerCanSee(supabase, "inspections", id))) {
    return json({ message: "inspection not found" }, 404);
  }
  const { data, error } = await supabase.rpc("inspection_detail", {
    p_inspection_id: id,
  });
  if (error) return json({ message: error.message }, 400);
  if (!data) return json({ message: "inspection not found" }, 404);
  return json({ data });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    // One client per request, carrying the caller's Authorization header.
    const supabase = callerClient(req, supabaseUrl);
    const url = new URL(req.url);
    const parts = url.pathname.split("/").filter(Boolean);
    const i = parts.indexOf("inspections");
    const rest = i >= 0 ? parts.slice(i + 1) : [];

    // GET /inspections
    if (req.method === "GET" && rest.length === 0) {
      const status = url.searchParams.get("status");
      const warehouseId = url.searchParams.get("warehouse_id");
      let q = supabase
        .from("inspections")
        .select(
          "*, item_count:inspection_items(count), plan:delivery_plans(delivery_number,supplier_name)",
        )
        .order("id", { ascending: false })
        .limit(50);
      if (status) q = q.eq("status", status);
      if (warehouseId) q = q.eq("warehouse_id", Number(warehouseId));
      const { data, error } = await q;
      if (error) return json({ message: error.message }, 400);
      const flat = (data ?? []).map((row: Record<string, unknown>) => {
        const c = row["item_count"];
        if (Array.isArray(c)) row["item_count"] = (c[0]?.count as number) ?? 0;
        const plan = row["plan"] as Record<string, unknown> | null;
        row["delivery_number"] = plan?.["delivery_number"] ?? null;
        row["supplier_name"] = plan?.["supplier_name"] ?? null;
        delete row["plan"];
        return row;
      });
      return json({ data: flat });
    }

    // GET /inspections/:id
    if (req.method === "GET" && rest.length === 1) {
      const id = Number(rest[0]);
      if (!Number.isFinite(id)) return json({ message: "bad id" }, 400);
      return await detail(supabase, id);
    }

    // POST /inspections  {reconciliation_id}
    if (req.method === "POST" && rest.length === 0) {
      if (!(await clientPermitted(supabase, "inspection.confirm"))) {
        return json({ message: notPermittedMessage("inspection.confirm") }, 403);
      }
      const body = await req.json().catch(() => ({}));
      const reconId = Number(body.reconciliation_id);
      if (!Number.isFinite(reconId)) {
        return json({ message: "reconciliation_id is required" }, 422);
      }
      // The inspection inherits the receipt's warehouse, so the receipt is
      // what to gate on — "read recons" reaches through to its plan.
      if (!(await callerCanSee(supabase, "delivery_reconciliations", reconId))) {
        return json({ message: "reconciliation not found" }, 404);
      }
      const { data, error } = await admin.rpc("start_inspection", {
        p_reconciliation_id: reconId,
      });
      if (error) return json({ message: error.message }, 400);
      return await detail(supabase, Number(data));
    }

    // PATCH /inspections/:id/items/:itemId
    if (
      req.method === "PATCH" && rest.length === 3 && rest[1] === "items"
    ) {
      if (!(await clientPermitted(supabase, "inspection.confirm"))) {
        return json({ message: notPermittedMessage("inspection.confirm") }, 403);
      }
      const id = Number(rest[0]);
      const itemId = Number(rest[2]);
      if (!Number.isFinite(id) || !Number.isFinite(itemId)) {
        return json({ message: "bad id" }, 400);
      }
      // On the caller's client, so "read inspection items" (which reaches
      // through to the inspection's warehouse) gates the write. Matching
      // inspection_id also stops an item from one inspection being saved
      // through another inspection's URL.
      const { data: item, error: itemErr } = await supabase
        .from("inspection_items")
        .select("id, inspection_id")
        .eq("id", itemId)
        .maybeSingle();
      if (itemErr || !item) return json({ message: "inspection item not found" }, 404);
      if ((item as { inspection_id: number }).inspection_id !== id) {
        return json({ message: "inspection item not found" }, 404);
      }
      const body = await req.json().catch(() => ({}));
      const { error } = await admin.rpc("save_inspection_item", {
        p_item_id: itemId,
        p_passed: int(body.passed_quantity),
        p_failed: int(body.failed_quantity),
        p_lot: str(body.lot),
        p_serial: str(body.serial),
        p_expiry: str(body.expiry),
        p_packaging_condition: str(body.packaging_condition),
        p_product_condition: str(body.product_condition),
        p_label_ok: typeof body.label_ok === "boolean" ? body.label_ok : null,
        p_note: str(body.note),
        p_hold: body.hold === true,
      });
      if (error) return json({ message: error.message }, 400);
      return await detail(supabase, id);
    }

    // POST /inspections/:id/complete
    if (
      req.method === "POST" && rest.length === 2 && rest[1] === "complete"
    ) {
      if (!(await clientPermitted(supabase, "inspection.confirm"))) {
        return json({ message: notPermittedMessage("inspection.confirm") }, 403);
      }
      const id = Number(rest[0]);
      if (!Number.isFinite(id)) return json({ message: "bad id" }, 400);
      if (!(await callerCanSee(supabase, "inspections", id))) {
        return json({ message: "inspection not found" }, 404);
      }
      const body = await req.json().catch(() => ({}));
      const { error } = await admin.rpc("complete_inspection", {
        p_inspection_id: id,
        p_note: str(body.note),
      });
      // The RPC refuses to close an inspection that still has unchecked items;
      // surface that as a 422 the UI can show rather than a generic failure.
      if (error) {
        const unchecked = error.message.includes("unchecked");
        return json({ message: error.message }, unchecked ? 422 : 400);
      }
      return await detail(supabase, id);
    }

    return json({ message: "not found" }, 404);
  } catch (e) {
    return json({ message: `${e}` }, 500);
  }
});
