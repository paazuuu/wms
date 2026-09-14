// Shared by every edge function that mutates data as service role: that
// client has no user JWT context (auth.uid() is null inside any RPC it
// calls), so has_permission() can't be trusted through it — and
// has_permission() itself treats a null auth.uid() as "allow" (meant for
// trusted server-side calls with no user at all, not for "nobody sent a
// token"). callerPermitted() builds a second, per-request client carrying
// the caller's own Authorization header, confirms a real signed-in user via
// auth.getUser(), and only then trusts has_permission()'s answer — the same
// rule every RPC called directly over PostgREST elsewhere in the app already
// follows via its own has_permission() check.
//
// Returns a bare boolean (not a Response) so each function builds its own
// 403 through its own json() helper — CORS headers differ per function and
// belong there, not here.
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
