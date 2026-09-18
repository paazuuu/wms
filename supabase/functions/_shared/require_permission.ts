// Authorization helpers shared by every edge function.
//
// A function's data client decides two things at once: whether
// has_permission() can be trusted, and whether warehouse scope applies. The
// service-role client has no user JWT context, so auth.uid() is null inside
// any RPC it calls — and has_permission() treats a null auth.uid() as "allow"
// (meant for trusted server-side calls with no user at all, not for "nobody
// sent a token"). callerPermitted() builds a per-request client carrying the
// caller's own Authorization header, confirms a real signed-in user via
// auth.getUser(), and only then trusts has_permission()'s answer — the same
// rule every RPC called directly over PostgREST elsewhere in the app already
// follows via its own has_permission() check.
//
// Returns a bare boolean (not a Response) so each function builds its own
// 403 through its own json() helper — CORS headers differ per function and
// belong there, not here.
//
// THE SAME null-uid PROBLEM APPLIES TO WAREHOUSE SCOPE (UI spec §37), which
// is why `callerClient` is exported and not just used internally. The service
// role additionally holds `rolbypassrls`, so on that client:
//
//   * 0052's row-level policies do not apply at all, and
//   * `accessible_warehouse_ids()` and `can_access_warehouse()` both take
//     their null-uid branch and answer "every warehouse".
//
// So a query issued on the service-role client is unscoped no matter how much
// scope enforcement exists in the database. Both halves of §37 — 0044-0047's
// RPC fallbacks and 0052's table policies — key off `auth.uid()`, and both
// bind the moment the same query is issued on the caller's client instead.
//
// The rule each function follows:
//
//   reads            -> caller's client, so policies and RPC scope apply
//   RPC writes       -> caller's client, so the RPC's own has_permission()
//                       and can_access_warehouse() bind on a real uid; the
//                       body still runs as its owner, so it writes past RLS
//   direct writes    -> service role (there are no INSERT policies for
//                       `authenticated`), and therefore need an explicit
//                       scope check written at the call site
import { createClient } from "jsr:@supabase/supabase-js@2";

export function callerClient(req: Request, supabaseUrl: string) {
  const authHeader = req.headers.get("Authorization") ?? "";
  return createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
}

export async function callerPermitted(
  req: Request,
  supabaseUrl: string,
  permission: string,
): Promise<boolean> {
  const client = callerClient(req, supabaseUrl);
  return await clientPermitted(client, permission);
}

/** Same check against a client the caller already built, so a request that
 * needs both a permission check and scoped reads does not construct two. */
export async function clientPermitted(
  // deno-lint-ignore no-explicit-any
  client: any,
  permission: string,
): Promise<boolean> {
  const { data: userData, error: userError } = await client.auth.getUser();
  if (userError || !userData?.user) return false;

  const { data, error } = await client.rpc("has_permission", {
    p_permission: permission,
  });
  return !error && data === true;
}

/** Same shape a Postgres RPC's `raise exception 'not permitted: ... required'`
 * produces, so the client's existing humanizer treats both the same way
 * regardless of which layer the check ran in. */
export function notPermittedMessage(permission: string): string {
  return `not permitted: ${permission} required`;
}
