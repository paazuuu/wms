// Authorization helpers shared by every edge function.
//
// A function's data client decides two things at once: whether
// has_permission() can be trusted, and whether warehouse scope applies. The
// service-role client has no user JWT context, so auth.uid() is null inside
// any RPC it calls — and has_permission() treats a null auth.uid() as "allow"
// (meant for trusted server-side calls with no user at all, not for "nobody
// sent a token"). So clientPermitted() takes a client carrying the caller's own
// Authorization header, confirms a real signed-in user via auth.getUser(), and
// only then trusts has_permission()'s answer.
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
// scope enforcement exists in the database: 0052/0053's table policies key off
// `auth.uid()` and bind the moment the same query is issued on the caller's
// client instead.
//
// BUT THE MUTATION RPCs ARE NOT A SECOND LINE OF DEFENCE. It is tempting to
// assume they check for themselves, and they do not. Measured against the live
// database:
//
//   * `ship_plan`, `cancel_shipment`, `reconcile_delivery_plan`,
//     `cancel_reconciliation`, `adjust_stock`, `record_pick`,
//     `start/complete/cancel_pick_list`, `start/save/complete_inspection`,
//     `record_count_line`, `complete/cancel_stock_count`, the
//     `*_transfer_order*` family and `log_audit` contain NO has_permission()
//     and NO can_access_warehouse() call at all, and
//   * every one of them is granted to `service_role` only — `authenticated`
//     has no EXECUTE on them.
//
// That combination is deliberate and sound: they are the trusted mutation
// layer, unreachable from a browser, and the edge function in front of them is
// the gate. But it has two consequences this file exists to make unmissable:
//
//   1. Calling one on the caller's client FAILS with "permission denied for
//      function …", because that client authenticates as `authenticated`.
//   2. There is therefore no warehouse check anywhere on a write path unless
//      the edge function performs it. RLS cannot help: the RPC is SECURITY
//      DEFINER and runs as its owner.
//
// So the rule each function follows is:
//
//   reads            -> caller's client, so 0052/0053's policies scope them
//   permission check -> caller's client (has_permission needs a real uid)
//   scope check      -> caller's client, EXPLICIT, at the call site, before
//                       the write — `callerCanSee` is the usual form
//   writes           -> service role, RPC and direct alike, because the
//                       mutation RPCs are granted to service_role only
//
// The read RPCs are the other way round: the 0051 wrappers are granted to
// `authenticated` and each opens with has_permission(), so they belong on the
// caller's client. Note that only `pick_list_index`, `transfer_order_index`
// and `warehouse_overview` scope their own results; the eleven detail/search
// wrappers do not, so a caller who reaches one with an id from another
// warehouse still sees it. Guard those at the call site too.
import { createClient } from "jsr:@supabase/supabase-js@2";

export function callerClient(req: Request, supabaseUrl: string) {
  const authHeader = req.headers.get("Authorization") ?? "";
  return createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
}

/** The write client. Every mutation RPC is granted to `service_role` only, so
 * writes have no alternative — which is exactly why the call site owes an
 * explicit scope check first. */
export function adminClient(supabaseUrl: string) {
  return createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
}

/** The permission check, against the client the request already built — every
 * function needs both this and scoped reads, so it never constructs two. */
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

/** The explicit §37 scope check for the "direct writes" row of the table
 * above. A write that has to run on the service role gets no help from
 * 0052's policies and no help from the RPC fallbacks, so the call site asks
 * this first — on the CALLER's client, because `can_access_warehouse()` reads
 * `auth.uid()` and answers "every warehouse" without one.
 *
 * Fails closed: an error, a missing session or a null answer all read as "no".
 * Pass the client the request already built, not the service-role one. */
export async function clientCanAccessWarehouse(
  // deno-lint-ignore no-explicit-any
  client: any,
  warehouseId: number | null,
): Promise<boolean> {
  if (warehouseId === null || !Number.isFinite(warehouseId)) return false;
  const { data, error } = await client.rpc("can_access_warehouse", {
    p_warehouse_id: warehouseId,
  });
  return !error && data === true;
}

/** The §37 gate for a write, and the usual form of it: can the caller SEE the
 * row they are about to mutate? Asked on the CALLER's client, where
 * 0052/0053's policies apply, so one lookup answers both "does this exist" and
 * "is it in your warehouses" — including for child rows, whose policies reach
 * through to the parent's warehouse.
 *
 * Prefer this over fetching a warehouse_id and calling
 * clientCanAccessWarehouse: it cannot pick the wrong column, and it stays
 * correct when a table's scope rule changes, because the rule lives in the
 * policy rather than being restated here.
 *
 * Fails closed — an error or a hidden row both read as "no". Callers answer a
 * false with 404, not 403: whether the row is missing or merely out of scope
 * is not something an out-of-scope caller should be able to tell apart. */
export async function callerCanSee(
  // deno-lint-ignore no-explicit-any
  client: any,
  table: string,
  id: number,
): Promise<boolean> {
  if (!Number.isFinite(id)) return false;
  const { data, error } = await client
    .from(table).select("id").eq("id", id).maybeSingle();
  return !error && !!data;
}

/** The caller's warehouse scope: an array of ids, or null for "every
 * warehouse" (admins). Distinguishing those two is the point — null is not
 * "none", and a failed call must not read as "all", so an error becomes an
 * empty array. */
export async function accessibleWarehouseIds(
  // deno-lint-ignore no-explicit-any
  client: any,
): Promise<number[] | null> {
  const { data, error } = await client.rpc("accessible_warehouse_ids");
  if (error) return [];
  if (data === null) return null;
  return (data as unknown[]).map(Number).filter(Number.isFinite);
}

/** Message for a refused cross-warehouse operation.
 *
 * Deliberately the same shape every Postgres guard raises — 0046 and 0056 both
 * use `not permitted: warehouse.scope required` — because the client matches
 * exactly `not permitted: <code> required` (see
 * `mobile/lib/core/api/api_error_text.dart`) to decide it may show its own
 * translated text. A friendlier-looking message like "warehouse 3 is outside
 * your scope" misses that regex and reaches the operator as raw English, which
 * is the §34 problem the humanizer exists to prevent.
 *
 * The warehouse id is deliberately not in the message: it would tell a caller
 * that the warehouse exists. Call sites log it instead. */
export function notInScopeMessage(warehouseId: number | null): string {
  if (warehouseId !== null) {
    console.error("warehouse scope refused", { warehouseId });
  }
  return "not permitted: warehouse.scope required";
}
