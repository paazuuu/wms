-- 0120 — a product's lifecycle, its stock beside it, and filtering the
-- product library.
--
--   * `products.lifecycle` says where a product stands:
--       active        取扱中   — handled as usual
--       dormant       休眠     — not handled for now; can be woken any time
--       discontinued  提供終了 — no longer offered (the maker or we ended it)
--       archived      削除済み — taken out of the library (a logical delete:
--                                nothing is removed, and it can be restored)
--     `status` (active/inactive) stays what every screen and RPC already
--     filters on, and is kept in step: only `active` is active. Setting
--     `status` the old way (set_product_status) moves `lifecycle` between
--     active and dormant.
--   * `product.lifecycle` is the permission to change it, for many products
--     at once — the system administrator's.
--   * `product_stock_json` is a product's stock in the warehouses the caller
--     can see: on hand, reserved and available, in total and per warehouse.
--     `list_products` carries it, with the lifecycle and every supplier that
--     sells the product, so the library can show and filter by them.
--   * `product_library_facets` lists the makers, suppliers and categories
--     with how many products each has, for the library's filters.
--
-- No `drop` here (see 0118): the old status check stays, and the new column
-- carries its own.

alter table public.products
  add column if not exists lifecycle text not null default 'active',
  add column if not exists lifecycle_reason text,
  add column if not exists lifecycle_changed_at timestamptz,
  add column if not exists lifecycle_changed_by uuid;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'products_lifecycle_check') then
    alter table public.products add constraint products_lifecycle_check
      check (lifecycle in ('active', 'dormant', 'discontinued', 'archived'));
  end if;
end $$;

-- What is inactive today is dormant: it was switched off, not ended.
update public.products set lifecycle = 'dormant' where status = 'inactive' and lifecycle = 'active';

create or replace function public.products_sync_lifecycle()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if new.lifecycle <> 'active' then
      new.status := 'inactive';
    elsif new.status = 'inactive' then
      new.lifecycle := 'dormant';
    end if;
    return new;
  end if;
  if new.lifecycle is distinct from old.lifecycle then
    new.status := case when new.lifecycle = 'active' then 'active' else 'inactive' end;
  elsif new.status is distinct from old.status then
    if new.status = 'active' then
      new.lifecycle := 'active';
    elsif old.lifecycle = 'active' then
      new.lifecycle := 'dormant';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.products_sync_lifecycle() from public, anon, authenticated;

create or replace trigger products_a_sync_lifecycle
  before insert or update of status, lifecycle on public.products
  for each row execute function public.products_sync_lifecycle();

insert into public.permissions (code, description)
values ('product.lifecycle', 'Make products dormant, discontinued or archived, many at once')
on conflict (code) do nothing;
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r, public.permissions p
 where r.code = 'system_admin' and p.code = 'product.lifecycle'
on conflict do nothing;

-- Many products at once into one lifecycle, with why.
create or replace function public.set_products_lifecycle(p_ids bigint[], p_lifecycle text, p_reason text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_reason text := public.tidy_text(p_reason);
  v_changed int;
begin
  if not public.has_permission('product.lifecycle') then
    raise exception 'not permitted: product.lifecycle required';
  end if;
  if p_lifecycle not in ('active', 'dormant', 'discontinued', 'archived') then
    raise exception 'unknown lifecycle %', p_lifecycle;
  end if;
  if coalesce(array_length(p_ids, 1), 0) = 0 then
    raise exception 'choose at least one product';
  end if;
  update public.products
     set lifecycle = p_lifecycle,
         lifecycle_reason = case when p_lifecycle = 'active' then null else v_reason end,
         lifecycle_changed_at = now(),
         lifecycle_changed_by = auth.uid(),
         updated_at = now()
   where id = any(p_ids) and lifecycle is distinct from p_lifecycle;
  get diagnostics v_changed = row_count;
  perform public.log_audit('product.lifecycle_set', 'product', array_to_string(p_ids, ','), null,
    jsonb_build_object('lifecycle', p_lifecycle, 'reason', v_reason, 'count', v_changed));
  return jsonb_build_object('changed', v_changed, 'lifecycle', p_lifecycle);
end;
$$;

-- A product's stock where the caller may look.
create or replace function public.product_stock_json(p_product_id bigint)
returns jsonb
language sql stable security definer set search_path = '' as $$
  with per as (
    select w.id as warehouse_id, w.name,
           coalesce((select sum(s.on_hand) from public.stock_levels s
                      where s.product_id = p_product_id and s.warehouse_id = w.id), 0)::int as on_hand,
           coalesce((select sum(greatest(r.quantity - coalesce(r.fulfilled_quantity, 0), 0))
                       from public.stock_reservations r
                      where r.product_id = p_product_id and r.warehouse_id = w.id and r.status = 'ACTIVE'), 0)::int as reserved
      from public.warehouses w
     where public.can_access_warehouse(w.id)
  )
  select jsonb_build_object(
    'on_hand', coalesce(sum(on_hand), 0),
    'reserved', coalesce(sum(reserved), 0),
    'available', coalesce(sum(on_hand - reserved), 0),
    'warehouses', coalesce(jsonb_agg(jsonb_build_object(
        'warehouse_id', warehouse_id, 'name', name, 'on_hand', on_hand, 'reserved', reserved,
        'available', on_hand - reserved) order by name)
      filter (where on_hand <> 0 or reserved <> 0), '[]'::jsonb))
  from per;
$$;

-- Every supplier that sells a product: by their names for it (0087) or
-- their prices (0107, 0119).
create or replace function public.product_suppliers_json(p_product_id bigint)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name) order by s.name), '[]'::jsonb)
    from public.delivery_suppliers s
   where s.id in (select supplier_id from public.supplier_product_names where product_id = p_product_id
                  union
                  select partner_id from public.supply_chain_supplier_products
                   where product_id = p_product_id and active);
$$;

-- The makers, suppliers and categories in the library, with counts.
create or replace function public.product_library_facets()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('product.view') then
    raise exception 'not permitted: product.view required';
  end if;
  return jsonb_build_object(
    'makers', coalesce((select jsonb_agg(jsonb_build_object('name', maker, 'count', n) order by maker)
                          from (select maker, count(*) n from public.products
                                 where lifecycle <> 'archived' and btrim(coalesce(maker, '')) <> ''
                                 group by maker) m), '[]'::jsonb),
    'suppliers', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'name', name, 'count', n) order by name)
                             from (select s.id, s.name, count(distinct p.id) n
                                     from public.delivery_suppliers s
                                     join (select supplier_id sid, product_id from public.supplier_product_names
                                           union
                                           select partner_id, product_id from public.supply_chain_supplier_products where active) x
                                       on x.sid = s.id
                                     join public.products p on p.id = x.product_id and p.lifecycle <> 'archived'
                                    group by s.id, s.name) t), '[]'::jsonb),
    'categories', coalesce((select jsonb_agg(jsonb_build_object('name', category, 'count', n) order by category)
                              from (select category, count(*) n from public.products
                                     where lifecycle <> 'archived' and btrim(coalesce(category, '')) <> ''
                                     group by category) c), '[]'::jsonb),
    'lifecycles', coalesce((select jsonb_object_agg(lifecycle, n)
                              from (select lifecycle, count(*) n from public.products group by lifecycle) l), '{}'::jsonb));
end;
$$;

-- list_products as 0118 left it, with the lifecycle, the stock and the
-- suppliers. p_status = 'active' still means what it did; null lists every
-- product, archived ones too, for the library to filter.
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

revoke all on function public.set_products_lifecycle(bigint[], text, text) from public, anon;
revoke all on function public.product_stock_json(bigint) from public, anon;
revoke all on function public.product_suppliers_json(bigint) from public, anon;
revoke all on function public.product_library_facets() from public, anon;
grant execute on function public.set_products_lifecycle(bigint[], text, text) to authenticated, service_role;
grant execute on function public.product_stock_json(bigint) to authenticated, service_role;
grant execute on function public.product_suppliers_json(bigint) to authenticated, service_role;
grant execute on function public.product_library_facets() to authenticated, service_role;
