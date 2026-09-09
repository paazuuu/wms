// Inter-warehouse transfer API for the WMS mobile client (spec Step 11, §16).
// Routes (function is mounted at /functions/v1/transfers):
//   GET   /transfers?warehouse_id=&status=        transfer index (either direction)
//   POST  /transfers                              {source_warehouse_id, destination_warehouse_id, lines:[{jan_code,product_name?,quantity}], note?}
//   GET   /transfers/:id                          one transfer + its lines
//   POST  /transfers/:id/submit                   DRAFT → PENDING_APPROVAL
//   POST  /transfers/:id/approve                  PENDING_APPROVAL → APPROVED
//   POST  /transfers/:id/reject                   {reason?} PENDING_APPROVAL → REJECTED
//   POST  /transfers/:id/cancel                   → CANCELLED (before anything shipped)
//   POST  /transfers/:id/start-picking             APPROVED → PICKING
//   PATCH /transfers/lines/:lineId/pick            {quantity} record what left the shelf
//   POST  /transfers/:id/complete-picking          PICKING → IN_TRANSIT, debits the source
//   POST  /transfers/:id/start-receiving           IN_TRANSIT → RECEIVING
//   PATCH /transfers/lines/:lineId/receive         {quantity} record what arrived
//   POST  /transfers/:id/complete-receiving        RECEIVING → COMPLETED, credits the destination
//
// Uses the service role internally; verify_jwt=true. Stock moves exactly
// twice per transfer — TRANSFER_OUT on complete-picking, TRANSFER_IN on
// complete-receiving — both inside the RPCs, never here.
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

async function detail(id: number): Promise<Response> {
  const { data, error } = await supabase.rpc("transfer_order_detail", {
    p_transfer_id: id,
  });
  if (error) return json({ message: error.message }, 400);
  if (!data || (data as Record<string, unknown>).id === undefined) {
    return json({ message: "transfer not found" }, 404);
  }
  return json({ data });
}

// A pick/receive PATCH addresses a line directly; look up its transfer so the
// response can hand back the refreshed parent.
async function transferIdForLine(lineId: number): Promise<number | null> {
  const { data, error } = await supabase
    .from("transfer_order_lines").select("transfer_order_id").eq("id", lineId)
    .single();
  if (error || !data) return null;
  return (data as { transfer_order_id: number }).transfer_order_id;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const url = new URL(req.url);
    const parts = url.pathname.split("/").filter(Boolean);
    const i = parts.indexOf("transfers");
    const rest = i >= 0 ? parts.slice(i + 1) : [];
    const warehouseId = url.searchParams.get("warehouse_id");

    // GET /transfers
    if (req.method === "GET" && rest.length === 0) {
      const status = url.searchParams.get("status");
      const { data, error } = await supabase.rpc("transfer_order_index", {
        p_warehouse_id: warehouseId ? Number(warehouseId) : null,
        p_status: status,
        p_limit: 50,
      });
      if (error) return json({ message: error.message }, 400);
      return json({ data: data ?? [] });
    }

    // POST /transfers
    if (req.method === "POST" && rest.length === 0) {
      // TODO(auth): require transfer.request for the caller.
      const body = await req.json().catch(() => ({}));
      const source = Number(body.source_warehouse_id);
      const destination = Number(body.destination_warehouse_id);
      if (!Number.isFinite(source) || !Number.isFinite(destination)) {
        return json(
          { message: "source_warehouse_id and destination_warehouse_id are required" },
          422,
        );
      }
      const lines = Array.isArray(body.lines) ? body.lines : [];
      const { data, error } = await supabase.rpc("create_transfer_order", {
        p_source_warehouse_id: source,
        p_destination_warehouse_id: destination,
        p_lines: lines.map((l: Record<string, unknown>) => ({
          jan_code: String(l.jan_code ?? ""),
          product_name: str(l.product_name),
          quantity: Number(l.quantity),
        })),
        p_note: str(body.note),
      });
      if (error) return json({ message: error.message }, 400);
      return await detail(Number(data));
    }

    // GET /transfers/:id
    if (req.method === "GET" && rest.length === 1) {
      const id = Number(rest[0]);
      if (!Number.isFinite(id)) return json({ message: "bad id" }, 400);
      return await detail(id);
    }

    // POST /transfers/:id/submit | approve | reject | cancel | start-picking
    // | complete-picking | start-receiving | complete-receiving
    if (req.method === "POST" && rest.length === 2) {
      const id = Number(rest[0]);
      if (!Number.isFinite(id)) return json({ message: "bad id" }, 400);
      const action = rest[1];

      const rpcByAction: Record<string, string> = {
        "submit": "submit_transfer_order",
        "approve": "approve_transfer_order",
        "cancel": "cancel_transfer_order",
        "start-picking": "start_transfer_picking",
        "complete-picking": "complete_transfer_picking",
        "start-receiving": "start_transfer_receiving",
      };

      if (action === "reject") {
        // TODO(auth): require transfer.approve for the caller.
        const body = await req.json().catch(() => ({}));
        const { error } = await supabase.rpc("reject_transfer_order", {
          p_transfer_id: id,
          p_reason: str(body.reason),
        });
        if (error) return json({ message: error.message }, 400);
        return await detail(id);
      }

      if (action === "complete-receiving") {
        const { data, error } = await supabase.rpc(
          "complete_transfer_receiving",
          { p_transfer_id: id },
        );
        if (error) return json({ message: error.message }, 400);
        const refreshed = await supabase.rpc("transfer_order_detail", {
          p_transfer_id: id,
        });
        return json({ data: refreshed.data, summary: data });
      }

      const rpc = rpcByAction[action];
      if (!rpc) return json({ message: "not found" }, 404);
      // TODO(auth): approve requires transfer.approve; the rest require
      // transfer.request/perform for the caller's warehouse.
      const { error } = await supabase.rpc(rpc, { p_transfer_id: id });
      if (error) return json({ message: error.message }, 400);
      return await detail(id);
    }

    // PATCH /transfers/lines/:lineId/pick | receive
    if (
      req.method === "PATCH" && rest[0] === "lines" && rest.length === 3
    ) {
      const lineId = Number(rest[1]);
      const action = rest[2];
      if (!Number.isFinite(lineId)) return json({ message: "bad id" }, 400);
      const body = await req.json().catch(() => ({}));
      const quantity = Number(body.quantity);
      if (!Number.isFinite(quantity)) {
        return json({ message: "quantity must be a number" }, 422);
      }
      const rpc = action === "pick"
        ? "record_transfer_pick"
        : action === "receive"
        ? "record_transfer_receipt"
        : null;
      if (!rpc) return json({ message: "not found" }, 404);

      const transferId = await transferIdForLine(lineId);
      if (transferId === null) {
        return json({ message: "transfer line not found" }, 404);
      }
      const { error } = await supabase.rpc(rpc, {
        p_line_id: lineId,
        p_quantity: Math.round(quantity),
      });
      if (error) return json({ message: error.message }, 400);
      return await detail(transferId);
    }

    return json({ message: "not found" }, 404);
  } catch (e) {
    return json({ message: `${e}` }, 500);
  }
});
