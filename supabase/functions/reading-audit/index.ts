// 読み取り検査 (0224): readings removed for good — their rows in
// reading_audits and their files in the reading-audits bucket — and nothing
// else. Those who look at the list may (reading_audit_can_view, asked on the
// caller's own token); the removal itself runs on the service role, as
// system-reset and purge-expired do.
//
//   POST /reading-audit  {ids: number[]}
//     → {removed: number[], files: number, kept: number[]}
//
// Readings taken out of the list before (removed_at set) go with them. A
// reading whose files could not be removed is only taken out of the list
// (kept), so no file is left without its row.
import { adminClient, callerClient } from "../_shared/require_permission.ts";
import { purgeReadingAudits, readIds } from "../_shared/reading_audit_purge.ts";

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
  const { data: can, error: canError } = await caller.rpc("reading_audit_can_view");
  if (canError || can !== true) return json({ message: "not permitted: audit.view required" }, 403);
  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch (_) {
    // No body: only what was taken out of the list before.
  }
  try {
    const r = await purgeReadingAudits(adminClient(supabaseUrl), readIds(body.ids));
    // Whatever could not be erased is at least out of the list.
    if (r.kept.length > 0) await caller.rpc("reading_audit_remove", { p_ids: r.kept });
    return json(r);
  } catch (e) {
    console.error("reading-audit failed", String(e));
    return json({ message: String(e) }, 500);
  }
});
