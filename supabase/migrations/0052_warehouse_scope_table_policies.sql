-- 0052 — Warehouse-scope the table read policies (UI spec §37).
--
-- 0049 changed these policies from `{anon, authenticated}` to `authenticated`,
-- and said plainly what it was leaving behind: the `USING (true)` clause
-- itself. That is this migration. A warehouse-scoped operator could still
-- read every warehouse's rows by querying the tables directly through
-- PostgREST — the §37 restriction leaking at the table layer rather than the
-- RPC layer.
--
-- WHY RLS IS THE RIGHT INSTRUMENT HERE, UNLIKE 0044-0047
--
-- Those migrations had to put scope checks inside function bodies because a
-- `security definer` function runs as its owner and RLS never fires for it.
-- These are direct table reads by the `authenticated` role, so RLS does fire,
-- and a scoped `USING` clause is the natural and complete answer: it applies
-- to every column selection, filter and embedded PostgREST join at once,
-- with no per-query code to remember.
--
-- WHY THE BLAST RADIUS IS SMALL
--
-- `service_role` has `rolbypassrls`, verified against `pg_roles` before
-- writing this. Every edge function uses the service-role client, so none of
-- them is affected by any policy here. The only caller these changes can
-- touch is the Flutter client reading tables directly as `authenticated`,
-- which it does for `roles`, `warehouses` and `attachments`. Of those only
-- `warehouses` is scoped below, and scoping it is the point: the warehouse
-- picker should offer the operator's warehouses, not the company's.
--
-- WHY `can_access_warehouse()` RATHER THAN A NEW PREDICATE
--
-- It already exists and already encodes this exact rule — admins unrestricted,
-- everyone else by `user_warehouses` membership. Being `security definer`, it
-- reads `user_roles` / `user_warehouses` without those tables' own policies
-- interfering, which a hand-written `EXISTS` in each policy would trip over.
-- Adding a near-duplicate helper would have meant two definitions of "may
-- this person see this warehouse" to keep in step.
--
-- A NULL `warehouse_id` IS INVISIBLE TO A SCOPED OPERATOR, AND VISIBLE TO AN
-- ADMIN. `can_access_warehouse(null)` returns false, but the admin branch
-- returns true before that test is reached. This is the same judgment call
-- 0047 made for `audit_log`: a row with no warehouse cannot be proved to
-- belong to yours, and excluding is the safe reading. It matters for
-- `delivery_plans`, whose `warehouse_id` is filled by a trigger and could be
-- null on a row predating it.
--
-- CHILD TABLES reach their warehouse through their parent. The parent's own
-- policy also applies inside that `EXISTS`, which is redundant but never
-- looser — RLS can only narrow — so the composition is safe. It is written
-- out explicitly rather than left to the parent's policy, so that loosening
-- one table cannot silently loosen another.
--
-- LEFT UNSCOPED, DELIBERATELY. These have no warehouse dimension, so there is
-- nothing to scope them by:
--   * `companies` — one row; every signed-in user needs it.
--   * `roles`, `permissions`, `role_permissions` — the authorization model
--     itself. Company-wide configuration, not warehouse data.
--   * `delivery_suppliers` — the trading-partner directory. 0035 widened it
--     into suppliers-and-customers and deliberately kept its read policy open
--     so delivery-note import and shipment lookups keep working; it is master
--     data like `products`, not per-warehouse data.
--
-- Each statement is an `alter policy ... using (...)`, touching only the
-- predicate and leaving the role list from 0049 alone.

-- Tables carrying warehouse_id directly.
alter policy "read stock movements" on public.stock_movements
  using (public.can_access_warehouse(warehouse_id));
alter policy "read stock" on public.stock_levels
  using (public.can_access_warehouse(warehouse_id));
alter policy "read bins" on public.bins
  using (public.can_access_warehouse(warehouse_id));
alter policy "read zones" on public.zones
  using (public.can_access_warehouse(warehouse_id));
alter policy "read inspections" on public.inspections
  using (public.can_access_warehouse(warehouse_id));
alter policy "pick_lists_read" on public.pick_lists
  using (public.can_access_warehouse(warehouse_id));
alter policy "read shipments" on public.shipment_plans
  using (public.can_access_warehouse(warehouse_id));
alter policy "read counts" on public.stock_counts
  using (public.can_access_warehouse(warehouse_id));
alter policy "read adjustments" on public.stock_adjustments
  using (public.can_access_warehouse(warehouse_id));
alter policy "read plans" on public.delivery_plans
  using (public.can_access_warehouse(warehouse_id));

-- The warehouse row itself: scoped by its own id, so the picker offers the
-- operator's warehouses rather than the company's.
alter policy "read warehouses" on public.warehouses
  using (public.can_access_warehouse(id));

-- A transfer is visible from either end, matching how 0045 scoped
-- `transfer_order_index`: the sending and receiving sites both have a
-- legitimate interest in it.
alter policy "transfer_orders_read" on public.transfer_orders
  using (public.can_access_warehouse(source_warehouse_id)
      or public.can_access_warehouse(destination_warehouse_id));

-- Children, one hop to their parent's warehouse.
alter policy "read bin stock" on public.bin_stock using (exists (
  select 1 from public.bins b
   where b.id = bin_stock.bin_id
     and public.can_access_warehouse(b.warehouse_id)));

alter policy "read inspection items" on public.inspection_items using (exists (
  select 1 from public.inspections i
   where i.id = inspection_items.inspection_id
     and public.can_access_warehouse(i.warehouse_id)));

alter policy "pick_tasks_read" on public.pick_tasks using (exists (
  select 1 from public.pick_lists l
   where l.id = pick_tasks.pick_list_id
     and public.can_access_warehouse(l.warehouse_id)));

alter policy "read shipment lines" on public.shipment_lines using (exists (
  select 1 from public.shipment_plans p
   where p.id = shipment_lines.shipment_plan_id
     and public.can_access_warehouse(p.warehouse_id)));

alter policy "read cartons" on public.shipment_cartons using (exists (
  select 1 from public.shipment_plans p
   where p.id = shipment_cartons.shipment_plan_id
     and public.can_access_warehouse(p.warehouse_id)));

alter policy "transfer_order_lines_read" on public.transfer_order_lines using (exists (
  select 1 from public.transfer_orders o
   where o.id = transfer_order_lines.transfer_order_id
     and (public.can_access_warehouse(o.source_warehouse_id)
       or public.can_access_warehouse(o.destination_warehouse_id))));

alter policy "read plan lines" on public.delivery_plan_lines using (exists (
  select 1 from public.delivery_plans p
   where p.id = delivery_plan_lines.delivery_plan_id
     and public.can_access_warehouse(p.warehouse_id)));

alter policy "read recons" on public.delivery_reconciliations using (exists (
  select 1 from public.delivery_plans p
   where p.id = delivery_reconciliations.delivery_plan_id
     and public.can_access_warehouse(p.warehouse_id)));

-- Children, two hops.
alter policy "read carton items" on public.shipment_carton_items using (exists (
  select 1 from public.shipment_cartons c
     join public.shipment_plans p on p.id = c.shipment_plan_id
   where c.id = shipment_carton_items.carton_id
     and public.can_access_warehouse(p.warehouse_id)));

alter policy "read recon lines" on public.reconciliation_lines using (exists (
  select 1 from public.delivery_reconciliations r
     join public.delivery_plans p on p.id = r.delivery_plan_id
   where r.id = reconciliation_lines.reconciliation_id
     and public.can_access_warehouse(p.warehouse_id)));
