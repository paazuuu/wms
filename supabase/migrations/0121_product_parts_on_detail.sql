-- 0121 — the product's parts on the product screen.
--
-- `list_products` also returns what the product's name is built from (0111):
-- its base name (品名), unit, list price (定価) and attributes (色, サイズ,
-- 容量 …) with their names. The product screen shows them as one table:
-- maker, 品名, 品番, JAN, attributes, so a product reads at a glance.

create or replace function public.list_products(p_search text default null, p_status text default 'active')
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('product.view') then
    raise exception 'not permitted: product.view required';
  end if;

  return coalesce(
    (select jsonb_agg(jsonb_build_object(
        'id', p.id, 'jan_code', p.jan_code, 'name', p.name, 'name_en', p.name_en,
        'names', public.product_names_of(p.id),
        'category', p.category, 'price', p.price, 'status', p.status,
        'lifecycle', p.lifecycle, 'lifecycle_reason', p.lifecycle_reason,
        'lifecycle_changed_at', p.lifecycle_changed_at,
        'stock', public.product_stock_json(p.id),
        'suppliers', public.product_suppliers_json(p.id),
        'base_name', p.base_name, 'unit', p.unit, 'list_price', p.list_price,
        'attributes', coalesce((
          select jsonb_agg(jsonb_build_object('key', a.key, 'name', a.name, 'value', v.value) order by a.id)
            from public.product_attribute_values v
            join public.product_attributes a on a.id = v.attribute_id
           where v.product_id = p.id), '[]'::jsonb),
        'sku', p.sku, 'tracking_mode', p.tracking_mode,
        'picking_rule', p.picking_rule,
        'requires_inspection', p.requires_inspection,
        'maker', p.maker,
        'unit_weight_g', p.unit_weight_g, 'weight_source', p.weight_source,
        'weight_source_url', p.weight_source_url, 'weight_note', p.weight_note,
        'created_at', p.created_at, 'updated_at', p.updated_at,
        'base_uom', (select jsonb_build_object('id', u.id, 'code', u.code, 'name', u.name)
                       from public.uoms u where u.id = p.base_uom_id),
        'uoms', coalesce((
          select jsonb_agg(jsonb_build_object(
                   'code', u.code, 'name', u.name,
                   'conversion_factor', pu.conversion_factor,
                   'is_base', pu.uom_id = p.base_uom_id,
                   'package_weight_g', pu.package_weight_g,
                   'gross_weight_g', pu.gross_weight_g,
                   'pack_weight_g', public.pack_weight_g(p.id, pu.uom_id))
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
        ), '[]'::jsonb),
        'supplier_names', coalesce((
          select jsonb_agg(jsonb_build_object(
                   'supplier_id', n.supplier_id, 'supplier_display_name', s.name,
                   'supplier_code', n.supplier_code, 'supplier_name', n.supplier_name)
                 order by s.name)
            from public.supplier_product_names n
            join public.delivery_suppliers s on s.id = n.supplier_id
           where n.product_id = p.id), '[]'::jsonb)
      ) order by p.name)
      from public.products p
     where (p_status is null or p.status = p_status)
       and (p_search is null or p_search = '' or
            p.name ilike '%' || p_search || '%' or
            p.name_en ilike '%' || p_search || '%' or
            exists (select 1 from public.product_names pn
                     where pn.product_id = p.id and pn.name ilike '%' || p_search || '%') or
            p.jan_code ilike '%' || p_search || '%' or
            p.sku ilike '%' || p_search || '%' or
            p.maker ilike '%' || p_search || '%' or
            exists (select 1 from public.product_barcodes b
                     where b.product_id = p.id
                       and b.barcode ilike '%' ||
                           coalesce(public.normalize_barcode(p_search), p_search) || '%') or
            exists (select 1 from public.supplier_product_names n
                     where n.product_id = p.id
                       and (n.supplier_name ilike '%' || p_search || '%'
                            or n.supplier_code ilike '%' || p_search || '%')))),
    '[]'::jsonb);
end;
$$;

