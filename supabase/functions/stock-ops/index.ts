// Stock corrections API: reason-coded adjustments and cycle counts
// (spec §17, §40). Mounted at /functions/v1/stock-ops.
//
//   GET   /stock-ops/adjustments?warehouse_id=      recent adjustments
//   POST  /stock-ops/adjustments                    {warehouse_id, jan_code,
//                                                    delta, reason, note?}
//   GET   /stock-ops/counts?warehouse_id=&status=   count sessions
//   POST  /stock-ops/counts                         {warehouse_id, blind?, note?}
//   GET   /stock-ops/counts/:id                     session + lines
//   PATCH /stock-ops/counts/:id/lines/:lineId       {counted}
//   POST  /stock-ops/counts/:id/complete            {note?}
//   POST  /stock-ops/counts/:id/cancel
//
// Warehouse scope (UI spec §37) is split by direction:
//
//   READS  run on the caller's client, so 0052's `read adjustments` /
//          `read counts` and 0053's `read count lines` policies scope them.
//          `stock_count_detail` does not scope itself, so countDetail() gates
//          on the caller being able to see the session first.
//   WRITES run on the service role, because adjust_stock, start_stock_count,
//          record_count_line and complete/cancel_stock_count are granted to
//          `service_role` only. adjust_stock in particular has no
//          has_permission() and no can_access_warehouse() of its own, so the
//          checks here are the only thing standing between a warehouse-1
//          operator and warehouse-2's stock.
//
// Both corrections post through the ledger, so nothing here can move stock
// without leaving a movement and an audit entry.
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

const REASONS = new Set([
  "DAMAGE", "LOSS", "FOUND", "CORRECTION", "RETURN", "OTHER",
]);

// The per-request caller client, threaded into helpers rather than captured
// from module scope — there is no module-level caller client, because it has
// to carry this request's JWT for warehouse scope to apply.
// deno-lint-ignore no-explicit-any
type Client = any;

// `stock_count_detail` is SECURITY DEFINER and returns whatever id it is
// given, so the policy-backed visibility check in front of it is what scopes
// this read. Every mutation below answers with countDetail(), so it doubles as
// their post-write gate. Out of scope and non-existent both answer 404.
async function countDetail(supabase: Client, id: number): Promise<Response> {
  if (!(await callerCanSee(supabase, "stock_counts", id))) {
    return json({ message: "stock count not found" }, 404);
  }
  const { data, error } = await supabase.rpc("stock_count_detail", {
    p_count_id: id,
  });
  if (error) return json({ message: error.message }, 400);
  if (!data) return json({ message: "stock count not found" }, 404);
  return json({ data });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    // One caller-scoped client per request, carrying the Authorization header.
    const supabase = callerClient(req, supabaseUrl);
    const url = new URL(req.url);
    const parts = url.pathname.split("/").filter(Boolean);
    const i = parts.indexOf("stock-ops");
    const rest = i >= 0 ? parts.slice(i + 1) : [];
    const warehouseId = url.searchParams.get("warehouse_id");

    // GET /stock-ops/adjustments
    if (req.method === "GET" && rest[0] === "adjustments" && rest.length === 1) {
      let q = supabase
        .from("stock_adjustments")
        .select("*")
        .order("id", { ascending: false })
        .limit(100);
      if (warehouseId) q = q.eq("warehouse_id", Number(warehouseId));
      const { data, error } = await q;
      if (error) return json({ message: error.message }, 400);
      return json({ data });
    }

    // POST /stock-ops/adjustments
    if (req.method === "POST" && rest[0] === "adjustments" && rest.length === 1) {
      if (!(await clientPermitted(supabase, "inventory.adjust"))) {
        return json({ message: notPermittedMessage("inventory.adjust") }, 403);
      }
      const body = await req.json().catch(() => ({}));
      const reason = str(body.reason)?.toUpperCase() ?? "OTHER";
      if (!REASONS.has(reason)) {
        return json({ message: `unknown reason ${reason}` }, 422);
      }
      const delta = Number(body.delta);
      if (!Number.isFinite(delta) || Math.round(delta) === 0) {
        return json({ message: "delta must be a non-zero number" }, 422);
      }
      const janCode = str(body.jan_code);
      if (!janCode) return json({ message: "jan_code is required" }, 422);
      const wh = Number(body.warehouse_id);
      if (!Number.isFinite(wh)) {
        return json({ message: "warehouse_id is required" }, 422);
      }
      // adjust_stock moves stock and checks nothing itself. This is the gate.
      if (!(await clientCanAccessWarehouse(supabase, wh))) {
        return json({ message: notInScopeMessage(wh) }, 403);
      }

      const { data, error } = await admin.rpc("adjust_stock", {
        p_warehouse_id: wh,
        p_jan_code: janCode,
        p_delta: Math.round(delta),
        p_reason: reason,
        p_note: str(body.note),
        p_product_name: str(body.product_name),
      });
      if (error) return json({ message: error.message }, 400);
      return json({ data }, 201);
    }

    // GET /stock-ops/counts
    if (req.method === "GET" && rest[0] === "counts" && rest.length === 1) {
      const status = url.searchParams.get("status");
      let q = supabase
        .from("stock_counts")
        .select("*, line_count:stock_count_lines(count)")
        .order("id", { ascending: false })
        .limit(50);
      if (warehouseId) q = q.eq("warehouse_id", Number(warehouseId));
      if (status) q = q.eq("status", status);
      const { data, error } = await q;
      if (error) return json({ message: error.message }, 400);
      const flat = (data ?? []).map((row: Record<string, unknown>) => {
        const c = row["line_count"];
        if (Array.isArray(c)) row["line_count"] = (c[0]?.count as number) ?? 0;
        return row;
      });
      return json({ data: flat });
    }

    // POST /stock-ops/counts
    if (req.method === "POST" && rest[0] === "counts" && rest.length === 1) {
      if (!(await clientPermitted(supabase, "count.perform"))) {
        return json({ message: notPermittedMessage("count.perform") }, 403);
      }
      const body = await req.json().catch(() => ({}));
      const wh = Number(body.warehouse_id);
      if (!Number.isFinite(wh)) {
        return json({ message: "warehouse_id is required" }, 422);
      }
      // start_stock_count does call can_access_warehouse(), but on the service
      // role that call sees a null auth.uid() and answers "every warehouse",
      // so it is not a substitute for this.
      if (!(await clientCanAccessWarehouse(supabase, wh))) {
        return json({ message: notInScopeMessage(wh) }, 403);
      }
      const { data, error } = await admin.rpc("start_stock_count", {
        p_warehouse_id: wh,
        p_blind: body.blind !== false,
        p_note: str(body.note),
      });
      if (error) return json({ message: error.message }, 400);
      return await countDetail(supabase, Number(data));
    }

    // GET /stock-ops/counts/:id
    if (req.method === "GET" && rest[0] === "counts" && rest.length === 2) {
      const id = Number(rest[1]);
      if (!Number.isFinite(id)) return json({ message: "bad id" }, 400);
      return await countDetail(supabase, id);
    }

    // PATCH /stock-ops/counts/:id/lines/:lineId
    if (
      req.method === "PATCH" && rest[0] === "counts" && rest.length === 4 &&
      rest[2] === "lines"
    ) {
      const id = Number(rest[1]);
      const lineId = Number(rest[3]);
      if (!Number.isFinite(id) || !Number.isFinite(lineId)) {
        return json({ message: "bad id" }, 400);
      }
      if (!(await clientPermitted(supabase, "count.perform"))) {
        return json({ message: notPermittedMessage("count.perform") }, 403);
      }
      const body = await req.json().catch(() => ({}));
      const counted = Number(body.counted);
      if (!Number.isFinite(counted)) {
        return json({ message: "counted must be a number" }, 422);
      }
      // On the caller's client, so 0053's "read count lines" policy (which
      // reaches through to the session's warehouse) gates the write. Matching
      // stock_count_id also stops a line from one session being recorded
      // through another session's URL.
      const { data: line, error: lineErr } = await supabase
        .from("stock_count_lines")
        .select("id, stock_count_id")
        .eq("id", lineId)
        .maybeSingle();
      if (lineErr || !line) return json({ message: "count line not found" }, 404);
      if ((line as { stock_count_id: number }).stock_count_id !== id) {
        return json({ message: "count line not found" }, 404);
      }
      const { error } = await admin.rpc("record_count_line", {
        p_line_id: lineId,
        p_counted: Math.round(counted),
      });
      if (error) return json({ message: error.message }, 400);
      return await countDetail(supabase, id);
    }

    // POST /stock-ops/counts/:id/complete
    if (
      req.method === "POST" && rest[0] === "counts" && rest.length === 3 &&
      rest[2] === "complete"
    ) {
      const id = Number(rest[1]);
      if (!Number.isFinite(id)) return json({ message: "bad id" }, 400);
      if (!(await clientPermitted(supabase, "count.approve"))) {
        return json({ message: notPermittedMessage("count.approve") }, 403);
      }
      // Completing a count writes adjustments through the ledger, so gate it.
      if (!(await callerCanSee(supabase, "stock_counts", id))) {
        return json({ message: "stock count not found" }, 404);
      }
      const body = await req.json().catch(() => ({}));
      const { data, error } = await admin.rpc("complete_stock_count", {
        p_count_id: id,
        p_note: str(body.note),
      });
      if (error) return json({ message: error.message }, 400);
      // Return the summary alongside the refreshed session.
      const detail = await supabase.rpc("stock_count_detail", {
        p_count_id: id,
      });
      return json({ data: detail.data, summary: data });
    }

    // POST /stock-ops/counts/:id/cancel
    if (
      req.method === "POST" && rest[0] === "counts" && rest.length === 3 &&
      rest[2] === "cancel"
    ) {
      const id = Number(rest[1]);
      if (!Number.isFinite(id)) return json({ message: "bad id" }, 400);
      if (!(await clientPermitted(supabase, "count.perform"))) {
        return json({ message: notPermittedMessage("count.perform") }, 403);
      }
      if (!(await callerCanSee(supabase, "stock_counts", id))) {
        return json({ message: "stock count not found" }, 404);
      }
      const { error } = await admin.rpc("cancel_stock_count", {
        p_count_id: id,
      });
      if (error) return json({ message: error.message }, 400);
      return await countDetail(supabase, id);
    }

    return json({ message: "not found" }, 404);
  } catch (e) {
    return json({ message: `${e}` }, 500);
  }
});
