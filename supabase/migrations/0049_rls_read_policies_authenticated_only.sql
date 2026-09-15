-- 0049 — Drop `anon` from every permissive table read policy.
--
-- THE HOLE 0048 DID NOT CLOSE
--
-- 0048 revoked the public/anon execute grant on fifteen RPCs that returned
-- business data, including `stock_ledger`. That was necessary and it was
-- not sufficient, because PostgREST does not only expose functions — it
-- exposes tables directly at `/rest/v1/<table>`. Twenty-two tables carried
-- a `SELECT` policy of the form
--
--     to {anon, authenticated} using (true)
--
-- so `GET /rest/v1/stock_movements?select=*` with the app's anon key
-- returned the entire ledger regardless of what the RPC layer allowed.
-- Locking `stock_ledger()` while `stock_movements` itself stayed
-- world-readable closed the side door and left the front door open.
--
-- What was reachable without signing in: the full stock movement ledger
-- and all stock levels, every bin and its contents, the whole warehouse /
-- zone / bin layout, all inspections and inspection items, pick lists and
-- pick tasks, shipment plans down to carton contents, transfer orders and
-- their lines, stock counts and adjustments, the company record, and —
-- worst for an attacker's purposes — `roles`, `permissions` and
-- `role_permissions`, i.e. a readable map of the authorization model
-- itself.
--
-- RLS was on for all twenty-two (the `rls_auto_enable` event trigger does
-- its job). The policies were simply written permissively, presumably as
-- scaffolding early on, and never tightened. The twenty-three other tables
-- in `public` have RLS on with no anon-facing policy at all and were
-- already denying by default — `audit_log`, `app_users`, `user_roles`,
-- `user_warehouses`, `products`, the order tables and the rest. So this is
-- a gap in a mostly-correct design, not a missing design.
--
-- WHY `alter policy ... to authenticated` RATHER THAN A REWRITE
--
-- Each statement changes only the policy's role list and leaves its
-- `USING` clause untouched. That keeps the diff to exactly the property
-- being fixed — who the policy applies to — and cannot accidentally change
-- which rows a signed-in user sees. Nothing changes for any authenticated
-- caller; the anon role simply stops matching a policy and RLS denies it
-- by default.
--
-- `using (true)` is still wrong for a signed-in user: a warehouse-scoped
-- operator can read every warehouse's rows through these tables, which is
-- the §37 restriction leaking at the table layer rather than the RPC
-- layer. Unlike the `security definer` RPCs of 0044-0047, RLS *does* fire
-- here, so a scoped `USING` clause is the right instrument. That is 0050,
-- kept separate because it changes what signed-in users see and therefore
-- needs its own verification; this migration changes nothing for them.
--
-- Nothing on the sign-in path depends on these: `bootstrap_first_admin`
-- and `my_access` are `security definer` and bypass RLS entirely, and the
-- client's direct table reads (`roles`, `warehouses`, `attachments`) all
-- run post-login on the authenticated Dio.
--
-- Only `SELECT` policies are touched because only `SELECT` policies ever
-- named `anon` — verified against `pg_policies` across all commands, so
-- there was never any anonymous write exposure.

alter policy "read stock movements" on public.stock_movements to authenticated;
alter policy "read stock" on public.stock_levels to authenticated;
alter policy "read bin stock" on public.bin_stock to authenticated;
alter policy "read bins" on public.bins to authenticated;
alter policy "read zones" on public.zones to authenticated;
alter policy "read warehouses" on public.warehouses to authenticated;
alter policy "read companies" on public.companies to authenticated;

alter policy "read inspections" on public.inspections to authenticated;
alter policy "read inspection items" on public.inspection_items to authenticated;

alter policy "pick_lists_read" on public.pick_lists to authenticated;
alter policy "pick_tasks_read" on public.pick_tasks to authenticated;

alter policy "read shipments" on public.shipment_plans to authenticated;
alter policy "read shipment lines" on public.shipment_lines to authenticated;
alter policy "read cartons" on public.shipment_cartons to authenticated;
alter policy "read carton items" on public.shipment_carton_items to authenticated;

alter policy "transfer_orders_read" on public.transfer_orders to authenticated;
alter policy "transfer_order_lines_read" on public.transfer_order_lines to authenticated;

alter policy "read counts" on public.stock_counts to authenticated;
alter policy "read adjustments" on public.stock_adjustments to authenticated;

-- The authorization model itself. Least data, most useful to an attacker:
-- knowing which permission codes exist and which role carries each one is
-- the map for choosing a target account.
alter policy "read roles" on public.roles to authenticated;
alter policy "read permissions" on public.permissions to authenticated;
alter policy "read role permissions" on public.role_permissions to authenticated;
