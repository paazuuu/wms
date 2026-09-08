-- Aggregated dashboard metrics for the home overview: today's inbound/outbound,
-- outstanding (未納) plans, stock totals, low-stock watch, and a daily trend.
-- SECURITY DEFINER so the anon client can read cross-table aggregates without
-- widening row-level access to the underlying tables.
create or replace function public.dashboard_metrics(
  p_days integer default 14,
  p_low_threshold integer default 10
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
    left join reconciliation_lines rl on rl.reconciliation_id = r.id
    where coalesce(r.status,'') <> 'cancelled'
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
    group by p.id, p.delivery_number, p.supplier_name
    having coalesce(sum(greatest(l.planned_quantity - coalesce(l.received_quantity,0),0)),0) > 0
  ),
  low_stock as (
    select jan_code, product_name, on_hand
    from stock_levels
    where on_hand <= p_low_threshold
  )
  select jsonb_build_object(
    'as_of', (select d from today),
    'inbound_today_units', (select coalesce(sum(units),0) from inbound where day = (select d from today)),
    'inbound_today_events', (select coalesce(sum(events),0) from inbound where day = (select d from today)),
    'outbound_today_units', (select coalesce(sum(units),0) from outbound where day = (select d from today)),
    'outbound_today_events', (select coalesce(sum(events),0) from outbound where day = (select d from today)),
    'outstanding_plan_count', (select count(*) from outstanding_plans),
    'outstanding_units', (select coalesce(sum(outstanding),0) from outstanding_plans),
    'total_skus', (select count(*) from stock_levels where on_hand > 0),
    'total_on_hand', (select coalesce(sum(on_hand),0) from stock_levels),
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

grant execute on function public.dashboard_metrics(integer, integer) to anon, authenticated;
