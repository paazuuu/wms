-- 0081 — Phase B client follow-up: QC requirement, settable from the client
--
-- The same gap 0080 closed for the picking rule, one migration later: 0068
-- gave every product a `requires_inspection` flag and `set_inspection_requirement`
-- to change it, but nothing has ever called that setter, and `list_products` —
-- the one read the product screens use — never returned the flag either. The
-- QC gate itself is not the gap: `receiving_status_for`/`resolve_barcode` already
-- read `requires_inspection` live and hold goods on arrival correctly (§13's
-- actual safety property, enforced in `project_stock_movement`, is untouched by
-- this migration). The gap is narrower and purely administrative: nobody using
-- the app can turn that flag on or off for a product, because there was never a
-- way to see or set it outside raw SQL.
--
-- Adds one field to `list_products`'s existing jsonb_build_object — no grant,
-- policy or guard changes, so this does not touch any of `verify_security.sql`'s
-- checks.

create or replace function public.list_products(
  p_search text default null,
  p_status text default 'active'
) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.has_permission('product.view') then
    raise exception 'not permitted: product.view required';
  end if;

  return coalesce(
    (select jsonb_agg(jsonb_build_object(
        'id', p.id, 'jan_code', p.jan_code, 'name', p.name,
        'category', p.category, 'price', p.price, 'status', p.status,
        'sku', p.sku, 'tracking_mode', p.tracking_mode,
        'picking_rule', p.picking_rule,
        'requires_inspection', p.requires_inspection,
        'created_at', p.created_at, 'updated_at', p.updated_at,
        'base_uom', (select jsonb_build_object('id', u.id, 'code', u.code, 'name', u.name)
                       from public.uoms u where u.id = p.base_uom_id),
        'uoms', coalesce((
          select jsonb_agg(jsonb_build_object(
                   'code', u.code, 'name', u.name,
                   'conversion_factor', pu.conversion_factor,
                   'is_base', pu.uom_id = p.base_uom_id)
                 order by pu.conversion_factor)
            from public.product_uoms pu
            join public.uoms u on u.id = pu.uom_id
           where pu.product_id = p.id), '[]'::jsonb),
        'barcodes', coalesce((
          select jsonb_agg(jsonb_build_object(
                   'id', b.id, 'barcode', b.barcode,
                   'barcode_type', b.barcode_type,
                   'is_primary', b.is_primary,
                   'quantity_per_scan', b.quantity_per_scan,
                   'uom', (select u.code from public.uoms u where u.id = b.uom_id))
                 order by b.is_primary desc, b.barcode)
            from public.product_barcodes b where b.product_id = p.id
        ), '[]'::jsonb)
      ) order by p.name)
      from public.products p
     where (p_status is null or p.status = p_status)
       and (p_search is null or p_search = '' or
            p.name ilike '%' || p_search || '%' or
            p.jan_code ilike '%' || p_search || '%' or
            p.sku ilike '%' || p_search || '%' or
            exists (select 1 from public.product_barcodes b
                     where b.product_id = p.id
                       and b.barcode ilike '%' ||
                           coalesce(public.normalize_barcode(p_search), p_search) || '%'))),
    '[]'::jsonb);
end;
$$;

revoke all on function public.list_products(text, text) from public, anon;
grant execute on function public.list_products(text, text) to authenticated, service_role;
