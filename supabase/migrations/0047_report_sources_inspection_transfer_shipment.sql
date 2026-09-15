-- 0047 — Three more report sources: inspections, transfers, shipments
-- (spec §46 checklist item 10, extending 0037) + warehouse scope on run_report
--
-- The report builder shipped with six sources (stock movements, purchase
-- orders, sales orders, work orders, audit log, products). The three biggest
-- operational areas of the app had no reporting at all: QC inspections,
-- inter-warehouse transfers, and outbound shipments. Each is a table the app
-- already maintains, so this is a query per source rather than new data.
--
-- Folding in the §37 scope fallback at the same time, since run_report was on
-- the list of read RPCs still missing it (0044/0045) and rewriting it twice
-- would be worse. Same rule as the index RPCs: `warehouse_id` absent has
-- always meant "every warehouse", so for a scope-restricted caller it now
-- means "every warehouse you can act in" rather than literally every one.
-- `products` stays unscoped — it is company-wide master data with no
-- warehouse column, which is correct rather than an oversight.
--
-- One judgment call worth recording: `audit_log` rows can have a null
-- warehouse_id (company-level events like a role assignment). For a
-- scope-restricted caller those are now excluded rather than shown, on the
-- grounds that the filtered trail should read as "what happened in your
-- warehouses"; company-wide administration is not in that scope. Unrestricted
-- callers (admins) still see everything, which is where those events matter.
create or replace function public.run_report(
  p_source text,
  p_filters jsonb default '{}'::jsonb,
  p_limit integer default 500
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_warehouse_id bigint := nullif(p_filters->>'warehouse_id', '')::bigint;
  v_status text := nullif(p_filters->>'status', '');
  v_jan_code text := nullif(p_filters->>'jan_code', '');
  v_movement_type text := nullif(p_filters->>'movement_type', '');
  v_event_type text := nullif(p_filters->>'event_type', '');
  v_category text := nullif(p_filters->>'category', '');
  v_date_from timestamptz := nullif(p_filters->>'date_from', '')::timestamptz;
  v_date_to timestamptz := nullif(p_filters->>'date_to', '')::timestamptz;
  v_limit integer := greatest(1, least(coalesce(p_limit, 500), 2000));
  v_scope bigint[] := public.accessible_warehouse_ids();
  v_rows jsonb;
begin
  if not public.has_permission('report.view') then
    raise exception 'not permitted: report.view required';
  end if;
  if p_source not in ('stock_movements', 'purchase_orders', 'sales_orders',
                       'work_orders', 'audit_log', 'products',
                       'inspections', 'transfers', 'shipments') then
    raise exception 'unknown report source %', p_source;
  end if;

  if p_source = 'stock_movements' then
    select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into v_rows
      from (
        select m.id, m.warehouse_id, w.name as warehouse_name, m.jan_code,
               m.product_name, m.movement_type, m.quantity, m.quantity_before,
               m.quantity_after, m.created_at
          from public.stock_movements m
          left join public.warehouses w on w.id = m.warehouse_id
         where (v_warehouse_id is null or m.warehouse_id = v_warehouse_id)
           and (v_scope is null or m.warehouse_id = any(v_scope))
           and (v_jan_code is null or m.jan_code = v_jan_code)
           and (v_movement_type is null or m.movement_type = v_movement_type)
           and (v_date_from is null or m.created_at >= v_date_from)
           and (v_date_to is null or m.created_at <= v_date_to)
         order by m.created_at desc, m.id desc
         limit v_limit
      ) t;

  elsif p_source = 'purchase_orders' then
    select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into v_rows
      from (
        select o.id, o.po_number, o.supplier_name, o.warehouse_id,
               w.name as warehouse_name, o.status, o.order_date,
               o.expected_date, o.created_at,
               (select count(*) from public.purchase_order_lines l
                 where l.purchase_order_id = o.id) as line_count
          from public.purchase_orders o
          join public.warehouses w on w.id = o.warehouse_id
         where (v_warehouse_id is null or o.warehouse_id = v_warehouse_id)
           and (v_scope is null or o.warehouse_id = any(v_scope))
           and (v_status is null or o.status = v_status)
           and (v_date_from is null or o.created_at >= v_date_from)
           and (v_date_to is null or o.created_at <= v_date_to)
         order by o.id desc
         limit v_limit
      ) t;

  elsif p_source = 'sales_orders' then
    select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into v_rows
      from (
        select o.id, o.so_number, o.customer_name, o.warehouse_id,
               w.name as warehouse_name, o.status, o.order_date,
               o.requested_ship_date, o.created_at,
               (select count(*) from public.sales_order_lines l
                 where l.sales_order_id = o.id) as line_count
          from public.sales_orders o
          join public.warehouses w on w.id = o.warehouse_id
         where (v_warehouse_id is null or o.warehouse_id = v_warehouse_id)
           and (v_scope is null or o.warehouse_id = any(v_scope))
           and (v_status is null or o.status = v_status)
           and (v_date_from is null or o.created_at >= v_date_from)
           and (v_date_to is null or o.created_at <= v_date_to)
         order by o.id desc
         limit v_limit
      ) t;

  elsif p_source = 'work_orders' then
    select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into v_rows
      from (
        select o.id, o.wo_number, o.warehouse_id, w.name as warehouse_name,
               o.output_jan_code, o.output_product_name, o.output_quantity,
               o.status, o.created_at, o.started_at, o.completed_at
          from public.work_orders o
          join public.warehouses w on w.id = o.warehouse_id
         where (v_warehouse_id is null or o.warehouse_id = v_warehouse_id)
           and (v_scope is null or o.warehouse_id = any(v_scope))
           and (v_status is null or o.status = v_status)
           and (v_date_from is null or o.created_at >= v_date_from)
           and (v_date_to is null or o.created_at <= v_date_to)
         order by o.id desc
         limit v_limit
      ) t;

  elsif p_source = 'audit_log' then
    select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into v_rows
      from (
        select a.id, a.created_at, a.warehouse_id, w.name as warehouse_name,
               a.actor_user_id, a.event_type, a.entity_type, a.entity_id, a.details
          from public.audit_log a
          left join public.warehouses w on w.id = a.warehouse_id
         where (v_warehouse_id is null or a.warehouse_id = v_warehouse_id)
           and (v_scope is null or a.warehouse_id = any(v_scope))
           and (v_event_type is null or a.event_type = v_event_type)
           and (v_date_from is null or a.created_at >= v_date_from)
           and (v_date_to is null or a.created_at <= v_date_to)
         order by a.created_at desc, a.id desc
         limit v_limit
      ) t;

  elsif p_source = 'products' then
    select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into v_rows
      from (
        select p.id, p.jan_code, p.name, p.category, p.price, p.status, p.created_at
          from public.products p
         where (v_status is null or p.status = v_status)
           and (v_category is null or p.category = v_category)
         order by p.name
         limit v_limit
      ) t;

  -- QC results per inspection, with the pass/fail split rolled up from the
  -- items so a report row answers "how did this delivery inspect" without
  -- needing a second query per row.
  elsif p_source = 'inspections' then
    select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into v_rows
      from (
        select i.id, i.warehouse_id, w.name as warehouse_name,
               i.delivery_plan_id, d.delivery_number, d.supplier_name,
               i.status, i.created_at, i.completed_at,
               u.name as inspector_name,
               (select count(*) from public.inspection_items it
                 where it.inspection_id = i.id) as item_count,
               (select coalesce(sum(it.passed_quantity), 0)
                  from public.inspection_items it
                 where it.inspection_id = i.id) as passed_quantity,
               (select coalesce(sum(it.failed_quantity), 0)
                  from public.inspection_items it
                 where it.inspection_id = i.id) as failed_quantity,
               (select count(*) from public.inspection_items it
                 where it.inspection_id = i.id and it.result = 'FAIL')
                 as failed_lines
          from public.inspections i
          left join public.warehouses w on w.id = i.warehouse_id
          left join public.delivery_plans d on d.id = i.delivery_plan_id
          left join public.app_users u on u.id = i.inspector_user_id
         where (v_warehouse_id is null or i.warehouse_id = v_warehouse_id)
           and (v_scope is null or i.warehouse_id = any(v_scope))
           and (v_status is null or i.status = v_status)
           and (v_date_from is null or i.created_at >= v_date_from)
           and (v_date_to is null or i.created_at <= v_date_to)
         order by i.created_at desc, i.id desc
         limit v_limit
      ) t;

  -- Transfers span two warehouses, so the warehouse filter matches either
  -- end — the same rule transfer_order_index uses, so a report and the list
  -- screen agree on what belongs to a warehouse.
  elsif p_source = 'transfers' then
    select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into v_rows
      from (
        select o.id, o.transfer_number,
               o.source_warehouse_id, sw.name as source_warehouse_name,
               o.destination_warehouse_id, dw.name as destination_warehouse_name,
               o.status, o.created_at, o.approved_at, o.shipped_at, o.received_at,
               (select count(*) from public.transfer_order_lines l
                 where l.transfer_order_id = o.id) as line_count,
               (select coalesce(sum(l.requested_quantity), 0)
                  from public.transfer_order_lines l
                 where l.transfer_order_id = o.id) as requested_quantity,
               (select coalesce(sum(l.received_quantity), 0)
                  from public.transfer_order_lines l
                 where l.transfer_order_id = o.id) as received_quantity
          from public.transfer_orders o
          join public.warehouses sw on sw.id = o.source_warehouse_id
          join public.warehouses dw on dw.id = o.destination_warehouse_id
         where (v_warehouse_id is null
                or o.source_warehouse_id = v_warehouse_id
                or o.destination_warehouse_id = v_warehouse_id)
           and (v_scope is null
                or o.source_warehouse_id = any(v_scope)
                or o.destination_warehouse_id = any(v_scope))
           and (v_status is null or o.status = v_status)
           and (v_date_from is null or o.created_at >= v_date_from)
           and (v_date_to is null or o.created_at <= v_date_to)
         order by o.id desc
         limit v_limit
      ) t;

  -- Outbound, with the logistics fields §21 collects (weight/carrier/
  -- tracking) included: chasing "which shipments went out with which
  -- carrier" is exactly what a report is for.
  elsif p_source = 'shipments' then
    select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into v_rows
      from (
        select s.id, s.shipment_number, s.customer_name, s.customer_code,
               s.warehouse_id, w.name as warehouse_name,
               s.status, s.ship_date, s.shipped_at, s.created_at,
               s.weight_kg, s.carrier, s.tracking_number,
               (select count(*) from public.shipment_lines l
                 where l.shipment_plan_id = s.id) as line_count,
               (select coalesce(sum(l.quantity), 0) from public.shipment_lines l
                 where l.shipment_plan_id = s.id) as total_quantity,
               (select count(*) from public.shipment_cartons c
                 where c.shipment_plan_id = s.id) as carton_count
          from public.shipment_plans s
          left join public.warehouses w on w.id = s.warehouse_id
         where (v_warehouse_id is null or s.warehouse_id = v_warehouse_id)
           and (v_scope is null or s.warehouse_id = any(v_scope))
           and (v_status is null or s.status = v_status)
           and (v_date_from is null or s.created_at >= v_date_from)
           and (v_date_to is null or s.created_at <= v_date_to)
         order by s.id desc
         limit v_limit
      ) t;
  end if;

  return jsonb_build_object('source', p_source, 'rows', v_rows);
end;
$function$;
