// Audit trail API for the WMS mobile client (spec Step 12, §33).
// Routes (function is mounted at /functions/v1/audit-log):
//   GET /audit-log?warehouse_id=&entity_type=&event_type=&since=&until=&limit=
//   GET /audit-log/event-types   distinct event types actually logged so far
//
// Read-only; verify_jwt=true. audit_log has RLS restricted to `authenticated`
// (0012), which the still-login-free app never satisfies as anon — so this
// reads through the SECURITY DEFINER `audit_log_query` RPC rather than the
// table directly, same pattern as stock-ops' masked count lines.
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "GET") return json({ message: "not found" }, 404);

  try {
    const url = new URL(req.url);
    const parts = url.pathname.split("/").filter(Boolean);
    const i = parts.indexOf("audit-log");
    const rest = i >= 0 ? parts.slice(i + 1) : [];

    if (rest[0] === "event-types" && rest.length === 1) {
      const { data, error } = await supabase.rpc("audit_event_types");
      if (error) return json({ message: error.message }, 400);
      return json({ data: data ?? [] });
    }

    if (rest.length === 0) {
      const warehouseId = url.searchParams.get("warehouse_id");
      const limit = url.searchParams.get("limit");
      const { data, error } = await supabase.rpc("audit_log_query", {
        p_warehouse_id: warehouseId ? Number(warehouseId) : null,
        p_entity_type: url.searchParams.get("entity_type"),
        p_event_type: url.searchParams.get("event_type"),
        p_since: url.searchParams.get("since"),
        p_until: url.searchParams.get("until"),
        p_limit: limit ? Number(limit) : 100,
      });
      if (error) return json({ message: error.message }, 400);
      return json({ data: data ?? [] });
    }

    return json({ message: "not found" }, 404);
  } catch (e) {
    return json({ message: `${e}` }, 500);
  }
});
