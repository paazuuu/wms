// Delivery plans API for the WMS mobile client.
// Routes (function is mounted at /functions/v1/delivery-plans):
//   GET  /delivery-plans                          list (?status=&search=)
//   GET  /delivery-plans/:id                      one plan with its expected lines
//   POST /delivery-plans/:id/reconcile            record a reconciliation
//   GET  /delivery-plans/:id/receipts             list this plan's receipts
//   POST /delivery-plans/:id/receipts/:rid/cancel void a receipt (correction)
//
// Uses the service role internally. verify_jwt=true means the caller must send
// a valid Supabase JWT (the app's anon key qualifies). For production, move to
// per-user Supabase Auth + RLS and drop the service-role shortcut.
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
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

function flattenCount(plan: Record<string, unknown>): Record<string, unknown> {
  const lc = plan["line_count"];
  if (Array.isArray(lc)) plan["line_count"] = lc[0]?.count ?? 0;
  return plan;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const url = new URL(req.url);
    const parts = url.pathname.split("/").filter(Boolean);
    const i = parts.indexOf("delivery-plans");
    const rest = i >= 0 ? parts.slice(i + 1) : [];

    // GET /delivery-plans
    if (req.method === "GET" && rest.length === 0) {
      const status = url.searchParams.get("status");
      const search = url.searchParams.get("search");
      let q = supabase
        .from("delivery_plans")
        .select("*, line_count:delivery_plan_lines(count)")
        .order("id", { ascending: false })
        .limit(50);
      if (status) q = q.eq("status", status);
      if (search && search.trim()) {
        const s = search.trim();
        q = q.or(`delivery_number.ilike.%${s}%,supplier_name.ilike.%${s}%,supplier_code.ilike.%${s}%`);
      }
      const { data, error } = await q;
      if (error) return json({ message: error.message }, 400);
      return json({ data: (data ?? []).map(flattenCount) });
    }

    // GET /delivery-plans/:id
    if (req.method === "GET" && rest.length === 1) {
      const id = Number(rest[0]);
      const { data, error } = await supabase
        .from("delivery_plans")
        .select("*, lines:delivery_plan_lines(*)")
        .eq("id", id)
        .single();
      if (error) return json({ message: error.message }, 404);
      return json({ data });
    }

    // GET /delivery-plans/:id/receipts
    if (req.method === "GET" && rest.length === 2 && rest[1] === "receipts") {
      const id = Number(rest[0]);
      const { data, error } = await supabase
        .from("delivery_reconciliations")
        .select(
          "id, reference_no, note_reference, status, created_at, lines:reconciliation_lines(actual_quantity)")
        .eq("delivery_plan_id", id)
        .order("id", { ascending: false });
      if (error) return json({ message: error.message }, 400);
      const receipts = (data ?? []).map((r: Record<string, unknown>) => {
        const lines = (r.lines as { actual_quantity: number | null }[]) ?? [];
        const totalUnits = lines.reduce((s, l) => s + (l.actual_quantity ?? 0), 0);
        return {
          id: r.id,
          reference_no: r.reference_no,
          note_reference: r.note_reference,
          status: r.status,
          created_at: r.created_at,
          total_units: totalUnits,
          line_count: lines.filter((l) => (l.actual_quantity ?? 0) > 0).length,
        };
      });
      return json({ data: receipts });
    }

    // POST /delivery-plans/:id/receipts/:rid/cancel
    if (
      req.method === "POST" && rest.length === 4 &&
      rest[1] === "receipts" && rest[3] === "cancel"
    ) {
      const id = Number(rest[0]);
      const rid = Number(rest[2]);
      const { error: rpcError } = await supabase.rpc("cancel_reconciliation", {
        p_recon_id: rid,
      });
      if (rpcError) return json({ message: rpcError.message }, 400);
      const { data, error } = await supabase
        .from("delivery_plans")
        .select("*, lines:delivery_plan_lines(*)")
        .eq("id", id)
        .single();
      if (error) return json({ message: error.message }, 400);
      return json({ data });
    }

    // POST /delivery-plans/:id/reconcile
    if (req.method === "POST" && rest.length === 2 && rest[1] === "reconcile") {
      const id = Number(rest[0]);
      const body = await req.json().catch(() => ({}));
      const { error: rpcError } = await supabase.rpc("reconcile_delivery_plan", {
        p_plan_id: id,
        p_complete: body.complete ?? true,
        p_note_reference: body.note_reference ?? null,
        p_lines: body.lines ?? [],
      });
      if (rpcError) return json({ message: rpcError.message }, 400);
      const { data, error } = await supabase
        .from("delivery_plans")
        .select("*, lines:delivery_plan_lines(*)")
        .eq("id", id)
        .single();
      if (error) return json({ message: error.message }, 400);
      return json({ data });
    }

    return json({ message: "Not found" }, 404);
  } catch (e) {
    return json({ message: String(e) }, 500);
  }
});
