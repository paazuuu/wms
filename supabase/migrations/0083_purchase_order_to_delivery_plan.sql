-- 0083 — the inbound sibling of 0073: a purchase order becomes a delivery plan.
--
-- 0073 wired Sales Order -> Reservation -> Shipment on the outbound side.
-- Purchase orders (0033) never got the matching wire: approving or
-- completing one never touched delivery_plans, so receiving a PO's goods
-- meant re-typing the same lines into a second, unrelated document by hand.
-- 0033's own header comment named this exact follow-up and left it undone
-- ("pre-filling a delivery plan from an approved PO... a natural follow-up,
-- not required for this to be useful on its own").
--
-- Deliberately narrower than 0073: a purchase order reserves nothing (there
-- is no stock to set aside on the way in, only stock still to arrive), so
-- this only copies the order's lines into a new delivery plan for
-- reconciliation to work from -- no stock moves, and none should.

alter table public.delivery_plans
  add column if not exists purchase_order_id bigint references public.purchase_orders(id);

create index if not exists delivery_plans_purchase_order_idx
  on public.delivery_plans (purchase_order_id) where purchase_order_id is not null;

-- At most one delivery plan per purchase order. Unconditional (not filtered
-- by status the way 0073's shipment index excludes 'cancelled') because
-- delivery_plans has no cancelled state to exclude -- once created, a plan
-- lives in open/reconciling/partial/completed forever.
create unique index if not exists delivery_plans_one_per_po
  on public.delivery_plans (purchase_order_id) where purchase_order_id is not null;

create or replace function public.create_delivery_plan_from_purchase_order(
  p_purchase_order_id bigint,
  p_note text default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_po record;
  v_plan_id bigint;
  v_line_count integer;
begin
  if not public.has_permission('purchase_order.manage') then
    raise exception 'not permitted: purchase_order.manage required';
  end if;

  select * into v_po from public.purchase_orders where id = p_purchase_order_id;
  if v_po.id is null then
    raise exception 'purchase order % not found', p_purchase_order_id;
  end if;
  if not public.can_access_warehouse(v_po.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_po.status <> 'APPROVED' then
    raise exception 'purchase order % is % and must be APPROVED to receive',
      p_purchase_order_id, v_po.status;
  end if;

  insert into public.delivery_plans (
    delivery_number, supplier_id, supplier_name, warehouse_id,
    purchase_order_id, reference_no, order_date, status)
  values (
    '', v_po.supplier_id, v_po.supplier_name, v_po.warehouse_id,
    p_purchase_order_id, v_po.po_number, v_po.order_date::text, 'open')
  returning id into v_plan_id;

  update public.delivery_plans
     set delivery_number = 'DP-' || lpad(v_plan_id::text, 6, '0')
   where id = v_plan_id;

  insert into public.delivery_plan_lines (
    delivery_plan_id, jan_code, product_name, planned_quantity, unit_price, product_id)
  select v_plan_id, l.jan_code, l.product_name, l.quantity,
         round(l.unit_price)::int, l.product_id
    from public.purchase_order_lines l
   where l.purchase_order_id = p_purchase_order_id;
  get diagnostics v_line_count = row_count;

  perform public.log_audit('delivery_plan.created_from_purchase_order', 'delivery_plan',
    v_plan_id::text, v_po.warehouse_id,
    jsonb_build_object('purchase_order_id', p_purchase_order_id, 'lines', v_line_count,
                       'note', p_note));

  return jsonb_build_object(
    'delivery_plan_id', v_plan_id,
    'purchase_order_id', p_purchase_order_id,
    'lines', v_line_count);
end;
$$;

revoke all on function public.create_delivery_plan_from_purchase_order(bigint, text)
  from public, anon;
grant execute on function public.create_delivery_plan_from_purchase_order(bigint, text)
  to authenticated, service_role;

-- purchase_order_detail now shows the delivery plan it became, if approval
-- has been turned into one -- the same shape sales_order_detail already has
-- for shipment_plan_id.
create or replace function public.purchase_order_detail(p_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('purchase_order.view') then
    raise exception 'not permitted: purchase_order.view required';
  end if;

  return (
    select jsonb_build_object(
      'id', o.id,
      'po_number', o.po_number,
      'supplier_id', o.supplier_id,
      'supplier_name', o.supplier_name,
      'warehouse_id', o.warehouse_id,
      'warehouse_name', w.name,
      'status', o.status,
      'order_date', o.order_date,
      'expected_date', o.expected_date,
      'note', o.note,
      'approved_at', o.approved_at,
      'created_at', o.created_at,
      'delivery_plan_id', (
        select dp.id from public.delivery_plans dp
         where dp.purchase_order_id = o.id
         order by dp.id desc limit 1),
      'lines', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'id', l.id, 'jan_code', l.jan_code, 'product_name', l.product_name,
                 'quantity', l.quantity, 'unit_price', l.unit_price) order by l.id)
          from public.purchase_order_lines l
         where l.purchase_order_id = o.id), '[]'::jsonb))
    from public.purchase_orders o
    join public.warehouses w on w.id = o.warehouse_id
   where o.id = p_id);
end;
$$;
