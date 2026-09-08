-- Step 2 support (spec §46, §23, §50): make the dashboard warehouse-aware and
-- add the per-warehouse rollup the top-level picker / "all warehouses" view needs.
--
-- dashboard_metrics gains p_warehouse_id (null = every warehouse). The old
-- two-argument version is dropped: keeping both would make a call that passes
-- only p_days/p_low_threshold ambiguous ("function is not unique"), since the
-- new third argument is defaulted. The Flutter client always sends all three.

drop function if exists public.dashboard_metrics(integer, integer);

create or replace function public.dashboard_metrics(
  p_days integer default 14,
  p_low_threshold integer default 10,
  p_warehouse_id bigint default null
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  with tz as (select 'Asia/Tokyo'::text as zone),
  today as (select (now() at time zone (select zone from tz))::date as d),
  span_start as (select (select d from today) - (greatest(p_days,1) - 1) as d),
  inbound as (
    select ((r.created_at at time zone (select zone from tz))::date) as day,
           coalesce(sum(rl.actual_quantity),0)::bigint as units,
           count(distinct r.id) as events
    from delivery_reconciliations r
    join delivery_plans dp on dp.id = r.delivery_plan_id
    left join reconciliation_lines rl on rl.reconciliation_id = r.id
    where coalesce(r.status,'') <> 'cancelled'
      and (p_warehouse_id is null or dp.warehouse_id = p_warehouse_id)
      and (r.created_at at time zone (select zone from tz))::date >= (select d from span_start)
    group by 1
  ),
  outbound as (
    select ((s.shipped_at at time zone (select zone from tz))::date) as day,
           coalesce(sum(sl.quantity),0)::bigint as units,
           count(distinct s.id) as events
    from shipment_plans s
    left join shipment_lines sl on sl.shipment_plan_id = s.id
    where s.status = 'shipped' and s.shipped_at is not null
      and (p_warehouse_id is null or s.warehouse_id = p_warehouse_id)
      and (s.shipped_at at time zone (select zone from tz))::date >= (select d from span_start)
    group by 1
  ),
  days as (
    select generate_series((select d from span_start), (select d from today), interval '1 day')::date as day
  ),
  trend as (
    select d.day,
           coalesce(i.units,0) as inbound,
           coalesce(o.units,0) as outbound
    from days d
    left join inbound i on i.day = d.day
    left join outbound o on o.day = d.day
  ),
  outstanding_plans as (
    select p.id, p.delivery_number, p.supplier_name,
           coalesce(sum(greatest(l.planned_quantity - coalesce(l.received_quantity,0),0)),0)::bigint as outstanding
    from delivery_plans p
    join delivery_plan_lines l on l.delivery_plan_id = p.id
    where p.status in ('open','reconciling','partial')
      and (p_warehouse_id is null or p.warehouse_id = p_warehouse_id)
    group by p.id, p.delivery_number, p.supplier_name
    having coalesce(sum(greatest(l.planned_quantity - coalesce(l.received_quantity,0),0)),0) > 0
  ),
  low_stock as (
    select jan_code, product_name, on_hand
    from stock_levels
    where on_hand <= p_low_threshold
      and (p_warehouse_id is null or warehouse_id = p_warehouse_id)
  ),
  stock_scope as (
    select * from stock_levels
    where (p_warehouse_id is null or warehouse_id = p_warehouse_id)
  )
  select jsonb_build_object(
    'as_of', (select d from today),
    'warehouse_id', p_warehouse_id,
    'inbound_today_units', (select coalesce(sum(units),0) from inbound where day = (select d from today)),
    'inbound_today_events', (select coalesce(sum(events),0) from inbound where day = (select d from today)),
    'outbound_today_units', (select coalesce(sum(units),0) from outbound where day = (select d from today)),
    'outbound_today_events', (select coalesce(sum(events),0) from outbound where day = (select d from today)),
    'outstanding_plan_count', (select count(*) from outstanding_plans),
    'outstanding_units', (select coalesce(sum(outstanding),0) from outstanding_plans),
    'total_skus', (select count(*) from stock_scope where on_hand > 0),
    'total_on_hand', (select coalesce(sum(on_hand),0) from stock_scope),
    'low_stock_count', (select count(*) from low_stock),
    'low_threshold', p_low_threshold,
    'trend', (select coalesce(jsonb_agg(jsonb_build_object('day', to_char(day,'YYYY-MM-DD'), 'inbound', inbound, 'outbound', outbound) order by day), '[]'::jsonb) from trend),
    'outstanding_list', (
      select coalesce(jsonb_agg(jsonb_build_object('id', id, 'delivery_number', delivery_number, 'supplier_name', supplier_name, 'outstanding', outstanding) order by outstanding desc), '[]'::jsonb)
      from (select * from outstanding_plans order by outstanding desc limit 8) t
    ),
    'low_stock_list', (
      select coalesce(jsonb_agg(jsonb_build_object('jan_code', jan_code, 'product_name', product_name, 'on_hand', on_hand) order by on_hand asc), '[]'::jsonb)
      from (select * from low_stock order by on_hand asc, jan_code limit 8) t
    )
  );
$$;

grant execute on function public.dashboard_metrics(integer, integer, bigint) to anon, authenticated;

-- Per-warehouse rollup for the warehouse picker and the admin "all warehouses"
-- view (spec §4.2, §50): each warehouse plus its headline figures, and a total.
create or replace function public.warehouse_overview()
returns jsonb
language sql
security definer
set search_path = public
as $$
  with per as (
    select
      w.id,
      w.code,
      w.name,
      w.status,
      w.is_default,
      w.timezone,
      (select count(*) from stock_levels s
        where s.warehouse_id = w.id and s.on_hand > 0)::bigint as sku_count,
      (select coalesce(sum(s.on_hand),0) from stock_levels s
        where s.warehouse_id = w.id)::bigint as on_hand,
      (select count(*) from delivery_plans p
        where p.warehouse_id = w.id
          and p.status in ('open','reconciling','partial'))::bigint as inbound_open,
      (select count(*) from shipment_plans sp
        where sp.warehouse_id = w.id and sp.status = 'open')::bigint as outbound_open
    from warehouses w
    order by w.is_default desc, w.name
  )
  select jsonb_build_object(
    'warehouses', coalesce(jsonb_agg(jsonb_build_object(
      'id', id, 'code', code, 'name', name, 'status', status,
      'is_default', is_default, 'timezone', timezone,
      'sku_count', sku_count, 'on_hand', on_hand,
      'inbound_open', inbound_open, 'outbound_open', outbound_open
    )), '[]'::jsonb),
    'totals', jsonb_build_object(
      'warehouse_count', count(*),
      'sku_count', coalesce(sum(sku_count),0),
      'on_hand', coalesce(sum(on_hand),0),
      'inbound_open', coalesce(sum(inbound_open),0),
      'outbound_open', coalesce(sum(outbound_open),0)
    )
  )
  from per;
$$;

grant execute on function public.warehouse_overview() to anon, authenticated;
