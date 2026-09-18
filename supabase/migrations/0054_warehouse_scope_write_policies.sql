-- §37 warehouse scope, write side.
--
-- 0052 scoped every SELECT policy, but only SELECT. Three write policies were
-- still `true` for `authenticated`, which means any signed-in user could,
-- straight over PostgREST and with no edge function involved:
--
--   * update ANY delivery plan in ANY warehouse (status, dates, supplier…),
--   * insert a reconciliation (a receipt) against ANY warehouse's plan,
--   * insert reconciliation lines under ANY of those.
--
-- Nothing in the app depends on that: the reconcile/cancel paths go through
-- `reconcile_delivery_plan` / `cancel_reconciliation`, which are SECURITY
-- DEFINER and so are not subject to these policies at all, and the Flutter
-- client never writes these tables directly (it calls the delivery-plans
-- edge function). So these policies only ever governed the direct-PostgREST
-- path — i.e. exactly the hole.
--
-- Same shape as 0052: only the USING/WITH CHECK expression changes, the
-- policy name and its role list stay as they were.

-- The plan carries the warehouse itself.
alter policy "update plan status" on public.delivery_plans
  using (public.can_access_warehouse(warehouse_id))
  with check (public.can_access_warehouse(warehouse_id));

-- A reconciliation belongs to a plan; the plan decides the warehouse.
alter policy "insert recons" on public.delivery_reconciliations
  with check (exists (
    select 1 from public.delivery_plans p
     where p.id = delivery_reconciliations.delivery_plan_id
       and public.can_access_warehouse(p.warehouse_id)));

-- And a line belongs to a reconciliation, so reach through both.
alter policy "insert recon lines" on public.reconciliation_lines
  with check (exists (
    select 1
      from public.delivery_reconciliations r
      join public.delivery_plans p on p.id = r.delivery_plan_id
     where r.id = reconciliation_lines.reconciliation_id
       and public.can_access_warehouse(p.warehouse_id)));
