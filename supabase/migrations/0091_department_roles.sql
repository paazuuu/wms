-- 0091 — roles for the office departments.
--
-- The system is run by the company's departments, each with its own role.
-- The 0012 roles cover the warehouse floor (receiving, picking, packing …)
-- and the admins, but not the two office teams the order-first flow (0084–
-- 0086) is built around: whoever buys from suppliers and whoever takes
-- customer orders. Without them an admin had to hand out Inventory Controller
-- (stock adjustments included) or Warehouse Manager to let someone raise a
-- purchase order.
--
--   purchasing — suppliers, their product names, purchase orders from open
--                demand and the links to sales orders; sees stock, incoming
--                receipts and the sales orders it buys for. No stock changes.
--   sales      — customer orders from entry to approval, backorder filling
--                from free stock, customers; sees stock and incoming POs to
--                promise dates. No stock changes, no purchase orders.
--
-- Approval sits in the department (purchase_order.approve / sales_order.
-- approve); the existing self-approval rule still keeps one person from
-- approving what they raised.

insert into public.roles (code, name, description) values
  ('purchasing', 'Purchasing', 'Suppliers and purchase orders'),
  ('sales',      'Sales',      'Customer orders')
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
  from public.roles r
  join public.permissions p on p.code = any (case r.code
    when 'purchasing' then array[
      'purchase_order.view', 'purchase_order.manage', 'purchase_order.approve',
      'partner.view', 'partner.manage',
      'product.view', 'product.manage',
      'sales_order.view', 'inventory.view', 'receiving.view',
      'warehouse.view', 'report.view']
    when 'sales' then array[
      'sales_order.view', 'sales_order.manage', 'sales_order.approve',
      'partner.view', 'partner.manage',
      'product.view', 'purchase_order.view', 'inventory.view',
      'warehouse.view', 'report.view']
    end)
 where r.code in ('purchasing', 'sales')
on conflict do nothing;
