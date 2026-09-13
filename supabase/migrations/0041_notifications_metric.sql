-- 0041 — Notifications: the one metric §30's alert row needs that
-- dashboard_metrics didn't already have (UI spec §30)
--
-- §30's mockup:
--   🔴 検品NG 2      🟠 入荷待ち 12
--   🟡 棚入れ待ち 7   🔵 ピック待ち 18
-- クリックで該当業務へ直接移動。
--
-- Three of those four numbers already exist in dashboard_metrics:
-- outstanding_plan_count (入荷待ち), putaway_pending_count (棚入れ待ち),
-- open_picking_count (ピック待ち). The one genuinely missing signal is 検品NG —
-- inspections that came back FAIL, which is a different (and more urgent)
-- fact than pending_inspection_count's "not inspected yet". Adding it here
-- rather than reusing pending_inspection_count: a NG result is a problem to
-- act on, not a queue to work through, and conflating the two would hide
-- failures inside an ordinary backlog number.
create or replace function public.dashboard_metrics(
  p_days integer default 14,
  p_low_threshold integer default 10,
  p_warehouse_id bigint default null
) returns jsonb
language sql
security definer
set search_path to 'public'
as $function$
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
  ),
  -- 検品待ち: inbound lots not yet fully inspected.
  pending_inspections as (
    select count(*) as n from inspections i
    where i.status = 'PENDING'
      and (p_warehouse_id is null or i.warehouse_id = p_warehouse_id)
  ),
  -- 検品NG (0041, §30): inspections that came back FAIL. Distinct from
  -- pending_inspection_count — this is "something is wrong", not "not done
  -- yet" — and from HOLD, which is a deliberate pause, not a failure.
  failed_inspections as (
    select count(*) as n from inspections i
    where i.status = 'FAIL'
      and (p_warehouse_id is null or i.warehouse_id = p_warehouse_id)
  ),
  -- 棚入れ待ち (0038): per-JAN warehouse stock not yet assigned to any bin,
  -- counted only for warehouses that opted into locations — without bins
  -- there is no put-away step. Same derivation as putaway_queue().
  putaway_pending as (
    select count(*) as n, coalesce(sum(pending),0)::bigint as units
    from (
      select s.warehouse_id, s.jan_code,
             s.on_hand - coalesce(b.binned,0) as pending
      from stock_levels s
      join warehouses w on w.id = s.warehouse_id and w.uses_locations
      left join (
        select bn.warehouse_id, bs.jan_code, sum(bs.on_hand)::int as binned
        from bin_stock bs join bins bn on bn.id = bs.bin_id
        group by bn.warehouse_id, bs.jan_code
      ) b on b.warehouse_id = s.warehouse_id and b.jan_code = s.jan_code
      where (p_warehouse_id is null or s.warehouse_id = p_warehouse_id)
    ) q
    where q.pending > 0
  ),
  -- ピッキング: pick lists currently being worked.
  open_picking as (
    select count(*) as n from pick_lists l
    where l.status = 'PICKING'
      and (p_warehouse_id is null or l.warehouse_id = p_warehouse_id)
  ),
  -- 梱包待ち / 出荷待ち: shipments not yet confirmed. 梱包待ち (still open, not
  -- even packing) and 出荷待ち (packing, ready to confirm) are both real
  -- states in shipment_plans.status.
  packing_wait as (
    select count(*) as n from shipment_plans s
    where s.status = 'open'
      and (p_warehouse_id is null or s.warehouse_id = p_warehouse_id)
  ),
  shipping_wait as (
    select count(*) as n from shipment_plans s
    where s.status = 'packing'
      and (p_warehouse_id is null or s.warehouse_id = p_warehouse_id)
  ),
  -- 棚卸: cycle counts still being counted.
  open_counts as (
    select count(*) as n from stock_counts c
    where c.status = 'COUNTING'
      and (p_warehouse_id is null or c.warehouse_id = p_warehouse_id)
  ),
  -- 倉庫間移動: transfers in flight, either direction for this warehouse.
  open_transfers as (
    select count(*) as n from transfer_orders t
    where t.status in ('PENDING_APPROVAL','APPROVED','PICKING','IN_TRANSIT','RECEIVING')
      and (p_warehouse_id is null
           or t.source_warehouse_id = p_warehouse_id
           or t.destination_warehouse_id = p_warehouse_id)
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
    'pending_inspection_count', (select n from pending_inspections),
    'failed_inspection_count', (select n from failed_inspections),
    'putaway_pending_count', (select n from putaway_pending),
    'putaway_pending_units', (select units from putaway_pending),
    'open_picking_count', (select n from open_picking),
    'packing_wait_count', (select n from packing_wait),
    'shipping_wait_count', (select n from shipping_wait),
    'open_count_count', (select n from open_counts),
    'open_transfer_count', (select n from open_transfers),
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
$function$;

-- Signature unchanged, so existing grants already cover it — re-stated for
-- clarity, not because anything actually changed.
grant execute on function public.dashboard_metrics(integer, integer, bigint)
  to anon, authenticated;
