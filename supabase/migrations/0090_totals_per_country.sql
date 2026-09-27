-- 0090 — stock is added up within one country, never across a border.
--
-- 0087 put warehouses in more than one country, but three reads still added
-- every warehouse together: the warehouse overview's company total, the
-- dashboard's headline figures when no warehouse is selected, and the
-- dashboard stock chart (0089), which stacked a Japan warehouse and a China
-- one into the same bar. Goods in two countries are not one stock — once they
-- cross, this system does not even hold them (0087) — so a sum across a
-- border is a number nobody can act on.
--
-- Now every total is per country:
--   * warehouse_overview: each warehouse carries its country, `country_totals`
--     has one total per country, and the old single `totals` is the home
--     country's (the default warehouse's) so an older client never shows a
--     cross-border sum either;
--   * dashboard_metrics with no warehouse: the home country's warehouses;
--   * dashboard_stock_chart: one country at a time, with the list of
--     countries to choose from.

create or replace function public.home_country_code()
returns text
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select w.country_code from public.warehouses w where w.is_default order by w.id limit 1),
    (select w.country_code from public.warehouses w order by w.id limit 1),
    'JP');
$$;

revoke all on function public.home_country_code() from public, anon;
grant execute on function public.home_country_code() to authenticated, service_role;

create or replace function public.warehouse_overview_impl()
returns jsonb
language sql security definer set search_path to 'public' as $$
  with scope as (select accessible_warehouse_ids() as ids),
  per as (
    select
      w.id, w.code, w.name, w.status, w.is_default, w.timezone, w.country_code,
      (select count(*) from stock_levels s
        where s.warehouse_id = w.id and s.on_hand > 0)::bigint as sku_count,
      (select coalesce(sum(s.on_hand),0) from stock_levels s
        where s.warehouse_id = w.id)::bigint as on_hand,
      (select count(*) from delivery_plans p
        where p.warehouse_id = w.id
          and p.status in ('open','reconciling','partial'))::bigint as inbound_open,
      (select count(*) from shipment_plans sp
        where sp.warehouse_id = w.id and sp.status = 'open')::bigint as outbound_open
    from warehouses w, scope
    where scope.ids is null or w.id = any(scope.ids)
    order by w.is_default desc, w.name
  ),
  -- SKUs are counted per country, not summed per warehouse: one product in two
  -- warehouses of the same country is one SKU there.
  countries as (
    select per.country_code,
           count(*) as warehouse_count,
           (select count(distinct s.jan_code) from stock_levels s
             where s.on_hand > 0
               and s.warehouse_id in (select p2.id from per p2
                                       where p2.country_code = per.country_code)) as sku_count,
           coalesce(sum(on_hand), 0) as on_hand,
           coalesce(sum(inbound_open), 0) as inbound_open,
           coalesce(sum(outbound_open), 0) as outbound_open
      from per
     group by per.country_code
  )
  select jsonb_build_object(
    'warehouses', coalesce((select jsonb_agg(jsonb_build_object(
      'id', id, 'code', code, 'name', name, 'status', status,
      'is_default', is_default, 'timezone', timezone, 'country_code', country_code,
      'sku_count', sku_count, 'on_hand', on_hand,
      'inbound_open', inbound_open, 'outbound_open', outbound_open
    )) from per), '[]'::jsonb),
    'country_totals', coalesce((select jsonb_agg(jsonb_build_object(
      'country_code', country_code,
      'warehouse_count', warehouse_count, 'sku_count', sku_count, 'on_hand', on_hand,
      'inbound_open', inbound_open, 'outbound_open', outbound_open)
      order by (country_code = public.home_country_code()) desc, country_code)
      from countries), '[]'::jsonb),
    'totals', coalesce((select jsonb_build_object(
      'warehouse_count', warehouse_count, 'sku_count', sku_count, 'on_hand', on_hand,
      'inbound_open', inbound_open, 'outbound_open', outbound_open)
      from countries where country_code = public.home_country_code()),
      jsonb_build_object('warehouse_count', 0, 'sku_count', 0, 'on_hand', 0,
                         'inbound_open', 0, 'outbound_open', 0))
  );
$$;

-- dashboard_metrics_impl: "no warehouse" means the home country's warehouses.
-- Rewritten in place from the live definition so every per-warehouse filter
-- in it goes through the same scope, including the ones added after 0041.
do $$
declare v_src text;
begin
  select pg_get_functiondef('public.dashboard_metrics_impl(integer,integer,bigint)'::regprocedure)
    into v_src;
  if position('wh_scope' in v_src) = 0 then
    v_src := replace(v_src,
      '(p_warehouse_id is null or t.source_warehouse_id = p_warehouse_id or t.destination_warehouse_id = p_warehouse_id)',
      '(t.source_warehouse_id in (select id from wh_scope) or t.destination_warehouse_id in (select id from wh_scope))');
    v_src := regexp_replace(v_src,
      '\(p_warehouse_id is null or ([a-z_.]+) = p_warehouse_id\)',
      '\1 in (select id from wh_scope)', 'g');
    v_src := replace(v_src,
      'with tz as (select ''Asia/Tokyo''::text as zone),',
      'with tz as (select ''Asia/Tokyo''::text as zone),
  wh_scope as (
    select w.id from warehouses w
     where (p_warehouse_id is not null and w.id = p_warehouse_id)
        or (p_warehouse_id is null and w.country_code = public.home_country_code())
  ),');
    v_src := replace(v_src,
      '''warehouse_id'', p_warehouse_id,',
      '''warehouse_id'', p_warehouse_id,
    ''country_code'', coalesce((select country_code from warehouses where id = p_warehouse_id),
                              public.home_country_code()),');
    execute v_src;
  end if;
end $$;

-- The stock chart, one country at a time.
drop function if exists public.dashboard_stock_chart(integer);

create or replace function public.dashboard_stock_chart(
  p_limit integer default 10, p_country_code text default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 10), 30));
  v_country text := upper(coalesce(nullif(btrim(p_country_code), ''), public.home_country_code()));
begin
  if not public.has_permission('inventory.view') then
    raise exception 'not permitted: inventory.view required';
  end if;

  return (
    with real_wh as (
      select w.id, w.name, w.country_code
        from public.warehouses w
       where w.status = 'active' and w.country_code = v_country
         and public.can_access_warehouse(w.id)
         and exists (select 1 from public.stock_levels sl
                      where sl.warehouse_id = w.id and sl.on_hand <> 0)
    ),
    virtual_wh as (
      select w.id, w.name, w.country_code
        from public.warehouses w
       where w.country_code = v_country and public.can_access_warehouse(w.id)
         and exists (select 1 from public.virtual_stock_entries e where e.warehouse_id = w.id)
    ),
    real_cells as (
      select x.product_id, x.warehouse_id,
             public.stock_on_hand(x.product_id, x.warehouse_id) as on_hand,
             public.stock_reserved(x.product_id, x.warehouse_id) as reserved,
             public.stock_available(x.product_id, x.warehouse_id) as available
        from (select distinct sl.product_id, sl.warehouse_id
                from public.stock_levels sl
               where sl.product_id is not null and sl.on_hand <> 0
                 and sl.warehouse_id in (select id from real_wh)) x
    ),
    virtual_cells as (
      select x.product_id, x.warehouse_id,
             greatest(public.virtual_balance(x.warehouse_id, x.product_id,
                                             public.warehouse_today(x.warehouse_id)), 0) as quantity
        from (select distinct e.product_id, e.warehouse_id
                from public.virtual_stock_entries e
               where e.warehouse_id in (select id from virtual_wh)) x
    ),
    per_product as (
      select p.id as product_id, p.jan_code, p.name as product_name,
             coalesce((select sum(greatest(c.on_hand, 0)) from real_cells c where c.product_id = p.id), 0)::int as on_hand,
             coalesce((select sum(greatest(least(c.available, c.on_hand), 0)) from real_cells c where c.product_id = p.id), 0)::int as free,
             coalesce((select sum(greatest(least(c.available + c.reserved, c.on_hand) - greatest(c.available, 0), 0))
                         from real_cells c where c.product_id = p.id), 0)::int as reserved,
             coalesce((select sum(greatest(c.on_hand - greatest(c.available + c.reserved, 0), 0))
                         from real_cells c where c.product_id = p.id), 0)::int as unusable,
             coalesce((select sum(v.quantity) from virtual_cells v where v.product_id = p.id), 0)::int as virtual_abroad,
             coalesce((select jsonb_agg(jsonb_build_object('warehouse_id', c.warehouse_id,
                                                           'quantity', greatest(c.on_hand, 0))
                                        order by c.warehouse_id)
                         from real_cells c where c.product_id = p.id and c.on_hand > 0), '[]'::jsonb)
             || coalesce((select jsonb_agg(jsonb_build_object('warehouse_id', v.warehouse_id,
                                                              'quantity', v.quantity, 'virtual', true)
                                           order by v.warehouse_id)
                            from virtual_cells v where v.product_id = p.id and v.quantity > 0), '[]'::jsonb)
               as by_warehouse
        from public.products p
       where p.id in (select product_id from real_cells union select product_id from virtual_cells)
    ),
    ranked as (
      select *, on_hand + virtual_abroad as total,
             row_number() over (order by on_hand + virtual_abroad desc, product_name) as rn,
             count(*) over () as product_count
        from per_product
       where on_hand + virtual_abroad > 0
    )
    select jsonb_build_object(
      'country_code', v_country,
      -- Countries with anything to chart, home first.
      'countries', coalesce((
        select jsonb_agg(c order by (c = public.home_country_code()) desc, c)
          from (select distinct w.country_code as c
                  from public.warehouses w
                 where public.can_access_warehouse(w.id)
                   and (exists (select 1 from public.stock_levels sl
                                 where sl.warehouse_id = w.id and sl.on_hand <> 0)
                        or exists (select 1 from public.virtual_stock_entries e
                                    where e.warehouse_id = w.id))) x), '[]'::jsonb),
      'warehouses',
        coalesce((select jsonb_agg(jsonb_build_object('id', id, 'name', name,
                                                      'country_code', country_code,
                                                      'virtual', false) order by id)
                    from real_wh), '[]'::jsonb)
        || coalesce((select jsonb_agg(jsonb_build_object('id', id, 'name', name,
                                                         'country_code', country_code,
                                                         'virtual', true) order by id)
                       from virtual_wh), '[]'::jsonb),
      'product_count', coalesce((select max(product_count) from ranked), 0),
      'products', coalesce((select jsonb_agg(jsonb_build_object(
                     'product_id', product_id, 'jan_code', jan_code,
                     'product_name', product_name, 'total', total, 'on_hand', on_hand,
                     'free', free, 'reserved', reserved, 'unusable', unusable,
                     'virtual_abroad', virtual_abroad, 'by_warehouse', by_warehouse)
                     order by rn)
                     from ranked where rn <= v_limit), '[]'::jsonb)));
end;
$$;

revoke all on function public.dashboard_stock_chart(integer, text) from public, anon;
grant execute on function public.dashboard_stock_chart(integer, text) to authenticated, service_role;
