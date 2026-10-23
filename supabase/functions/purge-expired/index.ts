// Deletes stock-file imports seven years past their date, with their files
// (0148). Called once a day by pg_cron (see migration 0148) with the shared
// secret in `x-purge-secret`; nobody else can run it.
//
//   POST /purge-expired            deletes what is due (at most 200 a run)
//   POST /purge-expired?dry_run=1  only says what is due
//
// verify_jwt=false: the caller is the database's scheduler, which has no
// user token. The check is the shared secret instead: a random value 0148
// put in the database vault (purge_expired_secret), which the scheduler
// sends and purge_secret_matches() compares. No person ever sees it.
import { adminClient } from "../_shared/require_permission.ts";
import { purgeAllowed, purgeExpired } from "../_shared/purge.ts";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ message: "not found" }, 404);
  const admin = adminClient(Deno.env.get("SUPABASE_URL")!) as never;
  if (!(await purgeAllowed(admin, req.headers.get("x-purge-secret")))) {
    return json({ message: "not permitted" }, 401);
  }
  const dryRun = new URL(req.url).searchParams.get("dry_run") === "1";
  try {
    const r = await purgeExpired(admin, { dryRun });
    console.log("purge-expired", JSON.stringify(r));
    return json(r);
  } catch (e) {
    console.error("purge-expired failed", String(e));
    return json({ message: String(e) }, 500);
  }
});
