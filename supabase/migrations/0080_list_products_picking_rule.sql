-- 0080 — Phase C client follow-up: the picking rule, settable from the client
--
-- 0074 gave every product a `picking_rule` column (§16: FIFO/FEFO/LIFO/MANUAL)
-- and `set_picking_rule` to change it, but `list_products` — the one read the
-- product screens use — never learned to return it. A setting nothing can
-- read is not reachable: the form would have to guess the current value
-- before showing a picker for it. Same shape as 0079: found while finishing
-- the client for a Phase C migration, fixed forward with its own.
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
