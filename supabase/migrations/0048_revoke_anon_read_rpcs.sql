-- 0048 — Revoke the `anon` execute grant from every RPC that returns
-- business data.
--
-- WHY THIS IS THE FIRST FIX, AND WHY IT IS A REVOKE RATHER THAN A CHECK
--
-- Twenty-one `security definer` functions in `public` were executable by
-- the `anon` role. The anon key is embedded in the shipped mobile app, so
-- it is public by construction. Fifteen of those twenty-one return real
-- business data, and only one (`bin_by_code`) carried a permission check
-- at all. The practical consequence: anyone holding the app's anon key
-- could read the complete stock movement ledger, every on-hand and
-- reserved quantity, the dashboard KPIs, the cross-entity search index,
-- every bin's contents, and any pick list / transfer / inspection /
-- stock-count detail — for every warehouse, without signing in.
--
-- Two properties of this schema mean a permission check would NOT have
-- closed it, which is why the grant is what has to go:
--
--   1. `has_permission(text)` returns TRUE when `auth.uid()` is null. That
--      is deliberate — it is what lets trusted server-side callers (the
--      edge functions, on the service-role client) run without a user. An
--      anon-key request also has a null `auth.uid()`, so it lands in the
--      same "trusted" branch. Adding `has_permission('inventory.view')` to
--      `stock_ledger` would not have stopped an anon caller by even one
--      row. This is the same footgun 0043 hit on the audit log; there too,
--      the revoke was the fix and the check was defence in depth.
--
--   2. `accessible_warehouse_ids()` (0044) returns NULL for a null
--      `auth.uid()`, and NULL means "every warehouse" throughout this app.
--      So the entire §37 scope enforcement built in 0044-0047 is a no-op
--      for an anon caller. Every scope check added in those four
--      migrations only ever bound signed-in users. Revoking `anon` is what
--      makes that work load-bearing rather than decorative.
--
-- Both properties are correct as designed. The bug was never the null-uid
-- branch; it was handing the public a role that reaches it.
--
-- WHAT IS DELIBERATELY LEFT ALONE
--
-- `has_permission`, `can_access_warehouse`, `my_access`, `my_roles` and
-- `bootstrap_first_admin` keep their grants. The first two are the
-- authorization primitives themselves and must stay callable. The last
-- three are the sign-in bootstrap: `auth_repository.dart` calls
-- `bootstrap_first_admin` and `my_access` immediately after a session is
-- established, and all three key off `auth.uid()`, so an anon caller gets
-- an empty answer rather than anyone else's data. Sign-in is also the one
-- flow in this project that has never been exercised against the live
-- database (there is no `auth.users` row yet), so it is the last place to
-- make an untested change. Revisit once a real sign-in has been observed.
--
-- `rls_auto_enable` and `fill_default_warehouse` also keep their grants:
-- they return `event_trigger` and `trigger` respectively, which PostgREST
-- cannot invoke and SQL cannot call directly. Their grants are untidy, not
-- reachable.
--
-- WHY EACH STATEMENT REVOKES FROM `public` AND NOT JUST `anon`
--
-- The ACL on each of these functions reads
-- `{=X/postgres, postgres=X/postgres, anon=X/postgres, ...}`. That leading
-- `=X` — an empty grantee — is a grant to PUBLIC, which is Postgres's
-- default for a newly created function. So there are *two* independent
-- paths by which `anon` reaches these: its own explicit grant, and the
-- default PUBLIC one. `revoke ... from anon` alone leaves the PUBLIC grant
-- standing and `has_function_privilege('anon', ...)` still answers true —
-- verified against the live database before writing this. Both have to go,
-- which is the form 0043 already used on the audit log.
--
-- The matching `grant execute ... to authenticated, service_role` is
-- belt-and-braces: those two already hold explicit grants that a revoke
-- from PUBLIC does not touch, but stating the intended end state makes the
-- migration idempotent and makes the target ACL readable from the file.
-- The shape to end at is the one `bin_by_code` and 0043's
-- `audit_log_query` already have: `{postgres=X, authenticated=X,
-- service_role=X}` and nothing else.
--
-- No function body changes here, so no behaviour changes for any signed-in
-- user. The missing `has_permission` checks (defence in depth, for a
-- signed-in user without the right role) and the remaining §37 scope
-- fallbacks follow in 0049 and 0050 — separately, because they do change
-- behaviour and this does not.

-- Inventory reads — the worst of the exposure.
revoke all on function public.stock_ledger(text, bigint, integer, text) from public, anon;
grant execute on function public.stock_ledger(text, bigint, integer, text) to authenticated, service_role;

revoke all on function public.stock_availability(bigint, text) from public, anon;
grant execute on function public.stock_availability(bigint, text) to authenticated, service_role;

revoke all on function public.bin_stock_overview(bigint) from public, anon;
grant execute on function public.bin_stock_overview(bigint) to authenticated, service_role;

-- Aggregates and search across every entity.
revoke all on function public.dashboard_metrics(integer, integer, bigint) from public, anon;
grant execute on function public.dashboard_metrics(integer, integer, bigint) to authenticated, service_role;

revoke all on function public.global_search(text, bigint, integer) from public, anon;
grant execute on function public.global_search(text, bigint, integer) to authenticated, service_role;

-- Operational documents.
revoke all on function public.pick_list_index(bigint, text, integer) from public, anon;
grant execute on function public.pick_list_index(bigint, text, integer) to authenticated, service_role;

revoke all on function public.pick_list_detail(bigint) from public, anon;
grant execute on function public.pick_list_detail(bigint) to authenticated, service_role;

revoke all on function public.transfer_order_index(bigint, text, integer) from public, anon;
grant execute on function public.transfer_order_index(bigint, text, integer) to authenticated, service_role;

revoke all on function public.transfer_order_detail(bigint) from public, anon;
grant execute on function public.transfer_order_detail(bigint) to authenticated, service_role;

revoke all on function public.inspection_detail(bigint) from public, anon;
grant execute on function public.inspection_detail(bigint) to authenticated, service_role;

revoke all on function public.stock_count_detail(bigint) from public, anon;
grant execute on function public.stock_count_detail(bigint) to authenticated, service_role;

-- Warehouse shape and configuration. `warehouse_overview` was flagged as
-- open in 0045/0046 pending "a look at the sign-in flow"; that look is now
-- done — the sign-in path uses only `bootstrap_first_admin` and
-- `my_access`, and the warehouse picker runs post-login on the
-- authenticated Dio, so the grant is safe to drop.
revoke all on function public.warehouse_overview() from public, anon;
grant execute on function public.warehouse_overview() to authenticated, service_role;

revoke all on function public.warehouse_uses_locations(bigint) from public, anon;
grant execute on function public.warehouse_uses_locations(bigint) to authenticated, service_role;

revoke all on function public.default_staging_bin(bigint) from public, anon;
grant execute on function public.default_staging_bin(bigint) to authenticated, service_role;

revoke all on function public.default_warehouse_id() from public, anon;
grant execute on function public.default_warehouse_id() to authenticated, service_role;
