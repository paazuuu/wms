// エラーログ (0227): errors erased for good — rows of app_error_logs and
// nothing else. Those who may look at the log may (app_error_log_can_view,
// asked on the caller's own token); the removal runs on the service role, as
// reading-audit and system-reset do.
//
//   POST /app-error-log  {ids?: number[], older_than_days?: number}  → {removed: number}
import { adminClient, callerClient } from "../_shared/require_permission.ts";
import { eraseAppErrors, readErase } from "../_shared/app_error_purge.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ message: "not found" }, 404);
  const caller = callerClient(req, supabaseUrl);
  const { data: userData } = await caller.auth.getUser();
  if (!userData?.user) return json({ message: "not permitted: sign in required" }, 401);
  const { data: can, error: canError } = await caller.rpc("app_error_log_can_view");
  if (canError || can !== true) return json({ message: "not permitted: audit.view required" }, 403);
  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch (_) {
    // Nothing asked: nothing erased.
  }
  const what = readErase(body);
  if (what.ids.length === 0 && what.olderThanDays === null) return json({ removed: 0 });
  try {
    return json({ removed: await eraseAppErrors(adminClient(supabaseUrl), what) });
  } catch (e) {
    console.error("app-error-log failed", String(e));
    return json({ message: String(e) }, 500);
  }
});
