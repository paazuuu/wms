-- 0045 — Per-user warehouse scope, batch 2: the list/index read paths
-- (UI spec §37, continuing 0044)
--
-- 0044 closed the write side by checking the two functions every stock
-- quantity change funnels through. These are the read side: the index RPCs
-- behind each list screen. They leak *reads* across warehouses rather than
-- allowing writes, which is why they sort after batch 1 — but a user
-- restricted to one warehouse could still list every other warehouse's
-- picks, orders and transfers, so they are a real gap.
--
-- The important subtlety, same as 0044's: every one of these treats
-- `p_warehouse_id IS NULL` as "every warehouse" — a deliberate
-- all-warehouses view for admins. A guard that only validated an explicitly
-- passed id would leave a restricted caller free to omit the filter and get
-- everything. So the fix is in the WHERE clause: the no-filter case now
-- falls back to `accessible_warehouse_ids()` instead of to everything.
-- Unrestricted callers (admins, trusted server-side calls with a null
-- auth.uid()) get null from that helper and so keep seeing all warehouses,
-- exactly as before.
--
-- Reads filter rather than raise: an out-of-scope warehouse simply yields
-- nothing. That keeps "all warehouses" calls working unchanged, and it
-- cannot arise from the UI anyway now that 0044 narrowed the picker itself
-- — only from a crafted request, where returning nothing is the right
-- answer rather than confirming the record exists.

create or replace function public.pick_list_index(
  p_warehouse_id bigint default null,
  p_status text default null,
  p_limit integer default 50
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $function$
  select coalesce(jsonb_agg(row_to_json(x)::jsonb order by x.id desc), '[]'::jsonb)
  from (
    select l.id,
           l.shipment_plan_id,
           p.shipment_number,
           p.customer_name,
           l.warehouse_id,
           w.name as warehouse_name,
           l.status,
           l.created_at,
           l.completed_at,
           (select count(*) from public.pick_tasks t where t.pick_list_id = l.id)
             as task_count,
           (select count(*) from public.pick_tasks t
             where t.pick_list_id = l.id and t.picked_quantity is not null)
             as picked_count,
           (select count(*) from public.pick_tasks t
             where t.pick_list_id = l.id and t.status = 'SHORT')
             as short_count
      from public.pick_lists l
      join public.shipment_plans p on p.id = l.shipment_plan_id
      left join public.warehouses w on w.id = l.warehouse_id
     where (p_warehouse_id is null or l.warehouse_id = p_warehouse_id)
       and (public.accessible_warehouse_ids() is null
            or l.warehouse_id = any(public.accessible_warehouse_ids()))
       and (p_status is null or l.status = p_status)
     order by l.id desc
     limit greatest(1, least(coalesce(p_limit, 50), 200))
  ) x;
$function$;

create or replace function public.purchase_order_index(
  p_warehouse_id bigint default null,
  p_status text default null,
  p_limit integer default 50
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare v_scope bigint[] := public.accessible_warehouse_ids();
begin
  if not public.has_permission('purchase_order.view') then
    raise exception 'not permitted: purchase_order.view required';
  end if;

  return coalesce((
    select jsonb_agg(row_to_json(x)::jsonb order by x.id desc)
    from (
      select o.id, o.po_number, o.supplier_name, o.warehouse_id, w.name as warehouse_name,
             o.status, o.order_date, o.expected_date, o.created_at,
             (select count(*) from public.purchase_order_lines l
               where l.purchase_order_id = o.id) as line_count,
             (select coalesce(sum(l.quantity * coalesce(l.unit_price, 0)), 0)
                from public.purchase_order_lines l
               where l.purchase_order_id = o.id) as total_amount
        from public.purchase_orders o
        join public.warehouses w on w.id = o.warehouse_id
       where (p_warehouse_id is null or o.warehouse_id = p_warehouse_id)
         and (v_scope is null or o.warehouse_id = any(v_scope))
         and (p_status is null or o.status = p_status)
       order by o.id desc
       limit greatest(1, least(coalesce(p_limit, 50), 200))
    ) x), '[]'::jsonb);
end;
$function$;

create or replace function public.sales_order_index(
  p_warehouse_id bigint default null,
  p_status text default null,
  p_limit integer default 50
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare v_scope bigint[] := public.accessible_warehouse_ids();
begin
  if not public.has_permission('sales_order.view') then
    raise exception 'not permitted: sales_order.view required';
  end if;

  return coalesce((
    select jsonb_agg(row_to_json(x)::jsonb order by x.id desc)
    from (
      select o.id, o.so_number, o.customer_name, o.warehouse_id, w.name as warehouse_name,
             o.status, o.order_date, o.requested_ship_date, o.created_at,
             (select count(*) from public.sales_order_lines l
               where l.sales_order_id = o.id) as line_count,
             (select coalesce(sum(l.quantity * coalesce(l.unit_price, 0)), 0)
                from public.sales_order_lines l
               where l.sales_order_id = o.id) as total_amount
        from public.sales_orders o
        join public.warehouses w on w.id = o.warehouse_id
       where (p_warehouse_id is null or o.warehouse_id = p_warehouse_id)
         and (v_scope is null or o.warehouse_id = any(v_scope))
         and (p_status is null or o.status = p_status)
       order by o.id desc
       limit greatest(1, least(coalesce(p_limit, 50), 200))
    ) x), '[]'::jsonb);
end;
$function$;

create or replace function public.work_order_index(
  p_warehouse_id bigint default null,
  p_status text default null,
  p_limit integer default 50
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare v_scope bigint[] := public.accessible_warehouse_ids();
begin
  if not public.has_permission('work_order.view') then
    raise exception 'not permitted: work_order.view required';
  end if;

  return coalesce((
    select jsonb_agg(row_to_json(x)::jsonb order by x.id desc)
    from (
      select o.id, o.wo_number, o.warehouse_id, w.name as warehouse_name,
             o.output_jan_code, o.output_product_name, o.output_quantity,
             o.status, o.created_at, o.started_at, o.completed_at,
             (select count(*) from public.work_order_components c
               where c.work_order_id = o.id) as component_count
        from public.work_orders o
        join public.warehouses w on w.id = o.warehouse_id
       where (p_warehouse_id is null or o.warehouse_id = p_warehouse_id)
         and (v_scope is null or o.warehouse_id = any(v_scope))
         and (p_status is null or o.status = p_status)
       order by o.id desc
       limit greatest(1, least(coalesce(p_limit, 50), 200))
    ) x), '[]'::jsonb);
end;
$function$;

-- A transfer touches two warehouses, so a scoped user should see it when
-- they can access *either* end — the source side to send, the destination
-- side to receive. Matches how 0044 gates the two halves of the lifecycle
-- separately (transfer.create on the source, transfer.receive on the
-- destination).
create or replace function public.transfer_order_index(
  p_warehouse_id bigint default null,
  p_status text default null,
  p_limit integer default 50
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $function$
  select coalesce(jsonb_agg(row_to_json(x)::jsonb order by x.id desc), '[]'::jsonb)
  from (
    select o.id,
           o.transfer_number,
           o.source_warehouse_id,
           sw.name as source_warehouse_name,
           o.destination_warehouse_id,
           dw.name as destination_warehouse_name,
           o.status,
           o.created_at,
           o.shipped_at,
           o.received_at,
           (select count(*) from public.transfer_order_lines l
             where l.transfer_order_id = o.id) as line_count
      from public.transfer_orders o
      join public.warehouses sw on sw.id = o.source_warehouse_id
      join public.warehouses dw on dw.id = o.destination_warehouse_id
     where (p_warehouse_id is null
            or o.source_warehouse_id = p_warehouse_id
            or o.destination_warehouse_id = p_warehouse_id)
       and (public.accessible_warehouse_ids() is null
            or o.source_warehouse_id = any(public.accessible_warehouse_ids())
            or o.destination_warehouse_id = any(public.accessible_warehouse_ids()))
       and (p_status is null or o.status = p_status)
     order by o.id desc
     limit greatest(1, least(coalesce(p_limit, 50), 200))
  ) x;
$function$;

-- putaway_queue takes a required warehouse, so there is no "all warehouses"
-- fallback to fix — just the one id to check. Raises rather than returning
-- an empty queue, so a genuinely out-of-scope request is not mistaken for
-- "nothing to put away".
create or replace function public.putaway_queue(p_warehouse_id bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if not public.has_permission('inventory.view') then
    raise exception 'not permitted: inventory.view required';
  end if;
  if p_warehouse_id is null then
    raise exception 'warehouse is required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if not public.warehouse_uses_locations(p_warehouse_id) then
    return '[]'::jsonb;
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'jan_code', q.jan_code,
      'product_name', q.product_name,
      'warehouse_on_hand', q.on_hand,
      'binned_quantity', q.binned,
      'pending_quantity', q.pending,
      -- The bin that already holds the most of this JAN here, so repeat
      -- receipts of the same item keep landing in the same place; falls back
      -- to the lowest-coded active pickable bin for a first-time item.
      'suggested_bin_id', q.suggested_bin_id,
      'suggested_bin_code', q.suggested_bin_code
    ) order by q.pending desc, q.jan_code)
    from (
      select s.jan_code,
             s.product_name,
             s.on_hand,
             coalesce(b.binned, 0) as binned,
             s.on_hand - coalesce(b.binned, 0) as pending,
             sg.bin_id as suggested_bin_id,
             sg.bin_code as suggested_bin_code
        from public.stock_levels s
        left join (
          select bs.jan_code, sum(bs.on_hand)::int as binned
            from public.bin_stock bs
            join public.bins bn on bn.id = bs.bin_id
           where bn.warehouse_id = p_warehouse_id
           group by bs.jan_code
        ) b on b.jan_code = s.jan_code
        left join lateral (
          select bn.id as bin_id, bn.code as bin_code
            from public.bins bn
            left join public.bin_stock bs
                   on bs.bin_id = bn.id and bs.jan_code = s.jan_code
           where bn.warehouse_id = p_warehouse_id
             and bn.is_active
             and bn.bin_type in ('PICKABLE', 'PICKABLE_STAGING')
           order by coalesce(bs.on_hand, 0) desc, bn.code
           limit 1
        ) sg on true
       where s.warehouse_id = p_warehouse_id
         and s.on_hand - coalesce(b.binned, 0) > 0
    ) q), '[]'::jsonb);
end;
$function$;
