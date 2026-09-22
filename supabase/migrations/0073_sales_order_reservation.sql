-- 0073 — Phase C: approving a sales order makes the promise real (§6, §36)
--
-- §6's flow is:
--
--     Sales Order -> Reservation -> Allocation -> Pick -> Pack -> Ship
--
-- 0064 built the whole Reservation/Allocation engine and even named
-- 'sales_order' and 'shipment' as reference_type values it accepts — pointed
-- at this exact day. But nothing called it: approving a sales order (0034) was
-- a pure bookkeeping transition. Two approved orders for the last 10 units on
-- hand could both say yes, because "approved" promised nothing to inventory.
-- This migration is where that promise starts.
--
-- DESIGN
--
--   * Best-effort, not all-or-nothing. A sales order line can name a JAN with
--     no product record yet (the same "unlinked" case 0067 tolerates on
--     receiving) or ask for more than is available. Neither should block
--     approving the order itself — the commercial decision (do we accept this
--     order) and the inventory promise (can we back it right now) are
--     different questions, and §34 already says order and execution stay
--     apart. Approval always succeeds once permitted; its return reports which
--     lines got a reservation and which did not, and why, so the approver sees
--     a shortfall immediately rather than discovering it at pick time.
--
--   * Reservations are inserted directly here rather than through the
--     `reserve_stock` RPC. `reserve_stock` re-checks permission against the
--     calling user (`sales_order.manage` or `inventory.adjust`), which would
--     make an approver holding only `sales_order.approve` — the role this
--     function is explicitly for — unable to finish approving. The act of
--     approving is what authorizes the promise; gating it twice would not add
--     safety, only a trap for the correctly-scoped role.
--
--   * `create_shipment_from_sales_order` re-keys the reservation's reference
--     from the order to the new shipment rather than creating a second one.
--     The promise was made once, at approval; turning an order into a shipment
--     moves where the promise is filed, not what it is. A shipment created
--     this way inherits exactly the stock already set aside for it.
--
--   * Cancelling an approved order releases what it reserved, the same way
--     `release_reservation` does (status -> RELEASED, allocations dropped) —
--     inlined for the same permission reason as above: `cancel_sales_order`
--     already requires `sales_order.manage`, but the reservation being
--     released belongs to the order, not to a fresh `inventory.adjust` check.
--     A rejected order never reserved anything (rejection only follows
--     SUBMITTED, before approval), so it needs no release logic.

-- ---------------------------------------------------------------------------
-- 1. A shipment now knows which sales order, if any, produced it
-- ---------------------------------------------------------------------------

alter table public.shipment_plans
  add column if not exists sales_order_id bigint references public.sales_orders(id);

create index if not exists shipment_plans_sales_order_idx
  on public.shipment_plans (sales_order_id) where sales_order_id is not null;

-- At most one live shipment per sales order — a second one would draw against
-- reservations the first already claimed.
create unique index if not exists shipment_plans_one_active_per_so
  on public.shipment_plans (sales_order_id)
  where sales_order_id is not null and status <> 'cancelled';

-- ---------------------------------------------------------------------------
-- 2. Approving reserves, best-effort
-- ---------------------------------------------------------------------------

-- Return type changes (boolean -> jsonb), so the old signature has to go
-- first; CREATE OR REPLACE cannot change what a function returns.
drop function if exists public.approve_sales_order(bigint);

create or replace function public.approve_sales_order(p_id bigint)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_status text;
  v_warehouse_id bigint;
  v_company_id bigint;
  v_requested_by uuid;
  v_approver uuid := auth.uid();
  r record;
  v_product_id bigint;
  v_available integer;
  v_reservation_id bigint;
  v_reserved_lines integer := 0;
  v_skipped jsonb := '[]'::jsonb;
begin
  if not public.has_permission('sales_order.approve') then
    raise exception 'not permitted: sales_order.approve required';
  end if;

  select status, warehouse_id, company_id, requested_by
    into v_status, v_warehouse_id, v_company_id, v_requested_by
    from public.sales_orders where id = p_id;
  if v_status is null then raise exception 'sales order % not found', p_id; end if;
  if v_status <> 'SUBMITTED' then
    raise exception 'sales order % is % and cannot be approved', p_id, v_status;
  end if;
  if v_requested_by is not null and v_approver is not null and v_requested_by = v_approver then
    raise exception 'a sales order cannot be approved by the person who requested it';
  end if;

  update public.sales_orders
     set status = 'APPROVED', approved_by = v_approver, approved_at = now()
   where id = p_id;

  for r in
    select l.id as line_id, l.jan_code, l.quantity
      from public.sales_order_lines l where l.sales_order_id = p_id
     order by l.id
  loop
    v_product_id := null;
    select id into v_product_id from public.products where jan_code = r.jan_code;

    if v_product_id is null then
      v_skipped := v_skipped || jsonb_build_object(
        'line_id', r.line_id, 'jan_code', r.jan_code, 'reason', 'unlinked_jan_code');
      continue;
    end if;

    -- Reads what earlier lines in this same loop already claimed, so two lines
    -- of the same product on one order cannot both be promised the same units.
    v_available := public.stock_available(v_product_id, v_warehouse_id);
    if v_available < r.quantity then
      v_skipped := v_skipped || jsonb_build_object(
        'line_id', r.line_id, 'jan_code', r.jan_code, 'reason', 'insufficient_available',
        'available', v_available, 'requested', r.quantity);
      continue;
    end if;

    insert into public.stock_reservations (
      company_id, product_id, warehouse_id, quantity, reference_type, reference_id, note)
    values (
      v_company_id, v_product_id, v_warehouse_id, r.quantity, 'sales_order', p_id::text,
      'SO line ' || r.line_id)
    returning id into v_reservation_id;
    v_reserved_lines := v_reserved_lines + 1;
  end loop;

  perform public.log_audit('sales_order.approved', 'sales_order', p_id::text, v_warehouse_id,
    jsonb_build_object('reserved_lines', v_reserved_lines, 'skipped', v_skipped));

  return jsonb_build_object(
    'sales_order_id', p_id,
    'status', 'APPROVED',
    'reserved_lines', v_reserved_lines,
    'skipped', v_skipped);
end;
$$;

revoke all on function public.approve_sales_order(bigint) from public, anon;
grant execute on function public.approve_sales_order(bigint) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. Cancelling releases what it reserved
-- ---------------------------------------------------------------------------

create or replace function public.cancel_sales_order(p_id bigint)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_status text;
  v_warehouse_id bigint;
begin
  if not public.has_permission('sales_order.manage') then
    raise exception 'not permitted: sales_order.manage required';
  end if;

  select status, warehouse_id into v_status, v_warehouse_id
    from public.sales_orders where id = p_id;
  if v_status is null then raise exception 'sales order % not found', p_id; end if;
  if v_status not in ('DRAFT', 'SUBMITTED', 'APPROVED') then
    raise exception 'sales order % is % and can no longer be cancelled', p_id, v_status;
  end if;

  update public.sales_orders set status = 'CANCELLED' where id = p_id;

  -- Only an APPROVED order can have reserved anything (see the header); DRAFT
  -- and SUBMITTED touch no rows here.
  delete from public.stock_allocations a
   using public.stock_reservations r
   where r.id = a.reservation_id
     and r.reference_type = 'sales_order' and r.reference_id = p_id::text
     and r.status = 'ACTIVE';
  update public.stock_reservations
     set status = 'RELEASED', updated_at = now()
   where reference_type = 'sales_order' and reference_id = p_id::text
     and status = 'ACTIVE';

  perform public.log_audit('sales_order.cancelled', 'sales_order', p_id::text,
    v_warehouse_id, jsonb_build_object('was', v_status));
  return true;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Turning an approved order into something the floor can pick
-- ---------------------------------------------------------------------------

create or replace function public.create_shipment_from_sales_order(
  p_sales_order_id bigint,
  p_note text default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_so record;
  v_shipment_id bigint;
  v_line_count integer;
  v_relinked integer;
begin
  if not public.has_permission('sales_order.manage') then
    raise exception 'not permitted: sales_order.manage required';
  end if;

  select * into v_so from public.sales_orders where id = p_sales_order_id;
  if v_so.id is null then
    raise exception 'sales order % not found', p_sales_order_id;
  end if;
  if not public.can_access_warehouse(v_so.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_so.status <> 'APPROVED' then
    raise exception 'sales order % is % and must be APPROVED to ship', p_sales_order_id, v_so.status;
  end if;

  insert into public.shipment_plans (
    shipment_number, party_id, customer_name, warehouse_id, sales_order_id, order_date)
  values ('', v_so.customer_id, v_so.customer_name, v_so.warehouse_id, p_sales_order_id,
          v_so.order_date::text)
  returning id into v_shipment_id;

  update public.shipment_plans
     set shipment_number = 'SHP-' || lpad(v_shipment_id::text, 6, '0')
   where id = v_shipment_id;

  insert into public.shipment_lines (
    shipment_plan_id, jan_code, product_name, quantity, unit_price, amount)
  select v_shipment_id, l.jan_code, l.product_name, l.quantity, l.unit_price,
         round(l.quantity * coalesce(l.unit_price, 0))::int
    from public.sales_order_lines l
   where l.sales_order_id = p_sales_order_id;
  get diagnostics v_line_count = row_count;

  -- The promise moves house: still active, now filed against what will
  -- actually be picked rather than the order that asked for it.
  update public.stock_reservations
     set reference_type = 'shipment', reference_id = v_shipment_id::text, updated_at = now()
   where reference_type = 'sales_order' and reference_id = p_sales_order_id::text
     and status = 'ACTIVE';
  get diagnostics v_relinked = row_count;

  perform public.log_audit('shipment.created_from_sales_order', 'shipment_plan',
    v_shipment_id::text, v_so.warehouse_id,
    jsonb_build_object('sales_order_id', p_sales_order_id, 'lines', v_line_count,
                       'reservations_relinked', v_relinked, 'note', p_note));

  return jsonb_build_object(
    'shipment_plan_id', v_shipment_id,
    'sales_order_id', p_sales_order_id,
    'lines', v_line_count,
    'reservations_relinked', v_relinked);
end;
$$;

revoke all on function public.create_shipment_from_sales_order(bigint, text) from public, anon;
grant execute on function public.create_shipment_from_sales_order(bigint, text)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. Reading it: a sales order now shows its own promise
-- ---------------------------------------------------------------------------

create or replace function public.sales_order_detail(p_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('sales_order.view') then
    raise exception 'not permitted: sales_order.view required';
  end if;

  return (
    select jsonb_build_object(
      'id', o.id,
      'so_number', o.so_number,
      'customer_id', o.customer_id,
      'customer_name', o.customer_name,
      'warehouse_id', o.warehouse_id,
      'warehouse_name', w.name,
      'status', o.status,
      'order_date', o.order_date,
      'requested_ship_date', o.requested_ship_date,
      'note', o.note,
      'approved_at', o.approved_at,
      'created_at', o.created_at,
      'lines', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'id', l.id, 'jan_code', l.jan_code, 'product_name', l.product_name,
                 'quantity', l.quantity, 'unit_price', l.unit_price) order by l.id)
          from public.sales_order_lines l
         where l.sales_order_id = o.id), '[]'::jsonb),
      -- The still-open live shipment, if approval has been turned into one
      -- (0073's own unique index guarantees at most one).
      'shipment_plan_id', (
        select sp.id from public.shipment_plans sp
         where sp.sales_order_id = o.id and sp.status <> 'cancelled'
         order by sp.id desc limit 1),
      -- §6's promise, wherever it is currently filed: still against the order
      -- before a shipment exists, re-keyed to the shipment after.
      'reservations', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'id', r.id, 'jan_code', p.jan_code, 'quantity', r.quantity,
                 'fulfilled_quantity', r.fulfilled_quantity, 'status', r.status)
               order by r.id)
          from public.stock_reservations r
          join public.products p on p.id = r.product_id
         where (r.reference_type = 'sales_order' and r.reference_id = o.id::text)
            or (r.reference_type = 'shipment' and r.reference_id in (
                  select sp.id::text from public.shipment_plans sp
                   where sp.sales_order_id = o.id))
        ), '[]'::jsonb))
    from public.sales_orders o
    join public.warehouses w on w.id = o.warehouse_id
   where o.id = p_id);
end;
$$;
