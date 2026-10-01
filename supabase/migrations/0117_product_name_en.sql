-- 0117 — an English name for each product.
--
-- Product names are Japanese, as the makers and suppliers write them, and a
-- Chinese or English screen showed them as they were. `products.name_en` is
-- the name for everyone who does not read Japanese: shown instead of the
-- Japanese name on English and Chinese screens, and under it on Japanese
-- ones. Set by hand (`set_product_name_en`), searchable like the name.

alter table public.products add column if not exists name_en text;

create or replace function public.set_product_name_en(p_product_id bigint, p_name_en text)
returns text
language plpgsql security definer set search_path = '' as $$
declare v_name text := public.tidy_text(p_name_en);
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  update public.products set name_en = v_name, updated_at = now() where id = p_product_id;
  if not found then
    raise exception 'product % not found', p_product_id;
  end if;
  perform public.log_audit('product.name_en_set', 'product', p_product_id::text, null,
    jsonb_build_object('name_en', v_name));
  return v_name;
end;
$$;

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
        'category', p.category, 'price', p.price, 'status', p.status,
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

create or replace function public.product_library(
  p_query text default null,
  p_without_images boolean default false,
  p_limit int default 60,
  p_offset int default 0
) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_q text := nullif(trim(p_query), '');
begin
  if not public.can_view_product_images() then
    raise exception 'not permitted: product.view required';
  end if;
  return coalesce((
    select jsonb_agg(row_to_json(t)::jsonb order by t.name, t.id)
      from (
        select p.id, p.jan_code, p.name, p.name_en, p.sku, p.maker, p.category, p.status,
               f.storage_path, coalesce(f.n, 0) as image_count
          from public.products p
          left join lateral (
            select i.storage_path, count(*) over () as n
              from public.product_images i
             where i.product_id = p.id and i.withdrawn_at is null
             order by i.position, i.id limit 1
          ) f on true
         where (v_q is null
                or p.name ilike '%' || v_q || '%'
                or p.name_en ilike '%' || v_q || '%'
                or p.jan_code like '%' || regexp_replace(v_q, '\D', '', 'g') || '%' and regexp_replace(v_q, '\D', '', 'g') <> ''
                or p.sku ilike '%' || v_q || '%'
                or p.maker ilike '%' || v_q || '%')
           and (not p_without_images or f.storage_path is null)
         order by p.name, p.id
         limit greatest(1, least(coalesce(p_limit, 60), 200)) offset greatest(0, coalesce(p_offset, 0))
      ) t), '[]'::jsonb);
end;
$$;

revoke all on function public.set_product_name_en(bigint, text) from public, anon;
grant execute on function public.set_product_name_en(bigint, text) to authenticated, service_role;
grant execute on function public.list_products(text, text) to authenticated, service_role;
grant execute on function public.product_library(text, boolean, int, int) to authenticated, service_role;
