-- 0050 — Finish the anon surface started in 0048/0049.
--
-- After 0048 (RPC grants) and 0049 (table read policies), Supabase's
-- security advisor reported six `security definer` functions still
-- executable by `anon`. Four of them can go now; two are being left, with
-- reasons.
--
-- GOING:
--
-- `has_permission(text)` and `can_access_warehouse(bigint)` — the
-- authorization primitives. 0048 kept them on the grounds that they "must
-- stay callable", which conflated two things. They must stay callable by
-- `authenticated`, because RLS policy expressions and the RPC bodies
-- evaluate them as the calling role. They do not need to be callable by
-- `anon`, and after 0049 no anon-facing policy exists to evaluate them at
-- all. Nested calls from inside other `security definer` functions run as
-- the function owner, so those are unaffected regardless of the grant.
--
-- Leaving them anon-callable was also actively misleading:
-- `has_permission` returns TRUE for a null `auth.uid()`, so an
-- unauthenticated `POST /rest/v1/rpc/has_permission` with
-- `{"p_permission": "user.manage"}` answered `true`. Harmless in itself —
-- it grants nothing and reads nothing — but it is exactly the sort of
-- probe that makes a system look wide open, and there is no reason to
-- answer it.
--
-- `fill_default_warehouse()` and `rls_auto_enable()` return `trigger` and
-- `event_trigger`. Postgres refuses to call either directly ("trigger
-- functions can only be called as triggers"), so the advisor's finding is
-- conservative rather than exploitable. Revoking costs nothing and takes
-- them off the report, which matters: a security report with four known-
-- benign entries is one where the next real finding gets skimmed past.
--
-- STAYING, DELIBERATELY:
--
-- `my_access()` and `my_roles()` are the sign-in bootstrap.
-- `auth_repository.dart` calls `my_access` immediately after establishing
-- a session, on the Dio whose interceptor has just picked up that
-- session's token, so the call arrives as `authenticated` and the anon
-- grant should be redundant. "Should be" is the problem: sign-in is the
-- one flow in this project never exercised against the live database —
-- `auth.users` is still empty — so the claim rests on reading the code,
-- not on having watched it work. Both were verified to return nothing for
-- a null uid (`{"authenticated": false, "roles": [], "permissions": [],
-- "warehouse_ids": []}`), so what is being kept open leaks nothing. Revoke
-- these once a real sign-in has been observed end to end.
--
-- NOT CHANGED: `stock_count_lines` has RLS enabled and no policy, which
-- the advisor reports as `rls_enabled_no_policy`. That is the safe
-- direction, and it is not a functional bug: the only reader is
-- `stock-ops/index.ts`, which embeds `line_count:stock_count_lines(count)`
-- on the service-role client and so bypasses RLS. Adding a permissive
-- policy to satisfy the linter would open read surface that nothing needs.
-- Left as is on purpose.

revoke all on function public.has_permission(text) from public, anon;
grant execute on function public.has_permission(text) to authenticated, service_role;

revoke all on function public.can_access_warehouse(bigint) from public, anon;
grant execute on function public.can_access_warehouse(bigint) to authenticated, service_role;

revoke all on function public.fill_default_warehouse() from public, anon;
revoke all on function public.rls_auto_enable() from public, anon;
