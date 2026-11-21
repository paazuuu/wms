-- 読み取り検査 (0225): in 管理 for the people in charge, not only システム管理.
-- Who looks at the list (and takes readings off it) now also includes
-- those who adjust stock, manage products or orders, read reports or ship —
-- the 管理者 roles (倉庫責任者, 在庫管理, 購買, 営業). The reading-audit
-- function asks this same check, so it follows.
create or replace function public.reading_audit_can_view()
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_system_admin() or public.has_permission('audit.view')
      or public.has_permission('user.manage') or public.has_permission('ai.review')
      or public.has_permission('inventory.adjust') or public.has_permission('product.manage')
      or public.has_permission('purchase_order.manage') or public.has_permission('report.view')
      or public.has_permission('report.manage') or public.has_permission('ship.complete');
$$;
grant execute on function public.reading_audit_can_view() to authenticated, service_role;
revoke execute on function public.reading_audit_can_view() from public, anon;
