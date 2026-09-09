// Inbound inspection (検品) API for the WMS client (spec §10, §11, §40).
// Routes (function is mounted at /functions/v1/inspections):
//   GET   /inspections                      list (?status=&warehouse_id=)
//   GET   /inspections/:id                  one inspection + its items
//   POST  /inspections                      {reconciliation_id} start (idempotent)
//   PATCH /inspections/:id/items/:itemId    record one item's findings
//   POST  /inspections/:id/complete         {note?} roll up and close
//
// Uses the service role internally; verify_jwt=true (the app's anon key
// qualifies). The tables are read-only to the client, so every mutation lands
// here. Per-user role/warehouse-scope checks arrive with Step 3's sign-in —
// the TODOs mark exactly where.
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
function int(v: unknown): number {
  const n = Number(v);
  return Number.isFinite(n) ? Math.max(Math.round(n), 0) : 0;
}

async function detail(id: number): Promise<Response> {
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
      return await detail(id);
    }

    // POST /inspections  {reconciliation_id}
    if (req.method === "POST" && rest.length === 0) {
      // TODO(auth): require inspection.confirm for the caller.
      const body = await req.json().catch(() => ({}));
      const reconId = Number(body.reconciliation_id);
      if (!Number.isFinite(reconId)) {
        return json({ message: "reconciliation_id is required" }, 422);
      }
      const { data, error } = await supabase.rpc("start_inspection", {
        p_reconciliation_id: reconId,
      });
      if (error) return json({ message: error.message }, 400);
      return await detail(Number(data));
    }

    // PATCH /inspections/:id/items/:itemId
    if (
      req.method === "PATCH" && rest.length === 3 && rest[1] === "items"
    ) {
      // TODO(auth): require inspection.confirm + warehouse scope.
      const id = Number(rest[0]);
      const itemId = Number(rest[2]);
      if (!Number.isFinite(id) || !Number.isFinite(itemId)) {
        return json({ message: "bad id" }, 400);
      }
      const body = await req.json().catch(() => ({}));
      const { error } = await supabase.rpc("save_inspection_item", {
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
      return await detail(id);
    }

    // POST /inspections/:id/complete
    if (
      req.method === "POST" && rest.length === 2 && rest[1] === "complete"
    ) {
      // TODO(auth): require inspection.confirm + warehouse scope.
      const id = Number(rest[0]);
      if (!Number.isFinite(id)) return json({ message: "bad id" }, 400);
      const body = await req.json().catch(() => ({}));
      const { error } = await supabase.rpc("complete_inspection", {
        p_inspection_id: id,
        p_note: str(body.note),
      });
      // The RPC refuses to close an inspection that still has unchecked items;
      // surface that as a 422 the UI can show rather than a generic failure.
      if (error) {
        const unchecked = error.message.includes("unchecked");
        return json({ message: error.message }, unchecked ? 422 : 400);
      }
      return await detail(id);
    }

    return json({ message: "not found" }, 404);
  } catch (e) {
    return json({ message: `${e}` }, 500);
  }
});
