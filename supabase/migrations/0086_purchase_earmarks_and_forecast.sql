-- 0086 — a purchase keeps its word to the orders it was bought for, and what
-- nobody ordered yet is stock bought ahead, not stock that just happened.
--
-- 0084 linked a purchase-order line to the sales-order lines it was raised for,
-- but only as a record: when the goods landed they were free stock like any
-- other, handed out oldest-approval-first. In practice the link is a decision
-- someone made — "this purchase is for customer A" — and it was being ignored
-- the moment it mattered. Now:
--
--   * Arrived goods are promised to the orders their purchase was linked to,
--     automatically, as soon as the receipt commits — and again whenever an
--     approval or a fill-from-stock runs, so goods released from inspection
--     later are not handed to someone else first.
--   * What a purchase ordered beyond its links is 見込み (bought ahead of
--     orders). It is shown as such, counts as incoming against any order, and
--     once landed is free stock for whichever order comes next — which is the
--     whole point of buying ahead.
--   * Links are edited by hand after the order exists: add, move, remove.
--     Moving a link after the goods landed moves the promise with it.
--
-- A promise made this way remembers which purchase-order line it came from
-- (`stock_reservations.purchase_order_line_id`). Quantity, not parcel, is what
-- is kept: stock is one pool per product whichever supplier sent it, so a
-- shipment draws from the same shelf however the goods were bought.

alter table public.stock_reservations
  add column if not exists purchase_order_line_id bigint
    references public.purchase_order_lines (id) on delete set null;

create index if not exists stock_reservations_po_line_idx
  on public.stock_reservations (purchase_order_line_id)
  where purchase_order_line_id is not null;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Received for one purchase-order line. Receipts are recorded per JAN on the
-- order's delivery plans; when one order carries a JAN on several lines, the
-- receipts fill them in line order.
create or replace function public.purchase_order_line_received(p_line_id bigint)
returns integer
language sql stable security definer set search_path = '' as $$
  select coalesce(least(l.quantity, greatest(0,
           coalesce((select sum(dpl.received_quantity)
                       from public.delivery_plan_lines dpl
                       join public.delivery_plans dp on dp.id = dpl.delivery_plan_id
                      where dp.purchase_order_id = l.purchase_order_id
                        and dpl.jan_code = l.jan_code), 0)
           - coalesce((select sum(e.quantity) from public.purchase_order_lines e
                        where e.purchase_order_id = l.purchase_order_id
                          and e.jan_code = l.jan_code and e.id < l.id), 0))), 0)::integer
    from public.purchase_order_lines l
   where l.id = p_line_id;
$$;

-- How much of a purchase-order line has been promised to one sales-order line
-- from what that purchase delivered.
create or replace function public.purchase_link_filled(p_po_line_id bigint, p_so_line_id bigint)
returns integer
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(case
           when r.status = 'FULFILLED' then r.quantity
           when r.status = 'ACTIVE' and (r.expires_at is null or r.expires_at > now())
             then r.quantity
           else r.fulfilled_quantity end), 0)::integer
    from public.stock_reservations r
   where r.purchase_order_line_id = p_po_line_id
     and r.sales_order_line_id = p_so_line_id;
$$;

-- What a purchase-order line still has to deliver to its linked orders. The
-- links share the receipts in the order they were made.
create or replace function public.purchase_order_line_linked_outstanding(p_line_id bigint)
returns integer
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(greatest(0, least(x.quantity, x.cum - x.received))), 0)::integer
    from (
      select d.quantity,
             sum(d.quantity) over (order by d.id) as cum,
             public.purchase_order_line_received(p_line_id) as received
        from public.purchase_order_line_demands d
       where d.purchase_order_line_id = p_line_id
    ) x;
$$;

-- Gives a released promise back, newest first, until `p_quantity` is freed.
create or replace function public.shrink_purchase_link(
  p_po_line_id bigint, p_so_line_id bigint, p_quantity integer)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  v_left integer := p_quantity;
  v_cut integer;
begin
  for r in
    select id, quantity, fulfilled_quantity from public.stock_reservations
     where purchase_order_line_id = p_po_line_id
       and sales_order_line_id = p_so_line_id
       and status = 'ACTIVE' and reference_type = 'sales_order'
     order by id desc
  loop
    exit when v_left <= 0;
    v_cut := least(v_left, r.quantity - r.fulfilled_quantity);
    continue when v_cut <= 0;
    if r.quantity - v_cut <= 0 then
      update public.stock_reservations set status = 'RELEASED', updated_at = now()
       where id = r.id;
      delete from public.stock_allocations where reservation_id = r.id;
    else
      update public.stock_reservations
         set quantity = quantity - v_cut, updated_at = now()
       where id = r.id;
    end if;
    v_left := v_left - v_cut;
  end loop;
  return p_quantity - v_left;
end;
$$;

-- The heart of it: bring what one purchase-order line's links have been
-- promised in line with what it has delivered. Idempotent — run it as often
-- as anything changes. Only live promises still filed on an order are ever
-- taken back; one already on a shipment is left for the shipment to settle.
create or replace function public.allocate_purchase_line(p_line_id bigint)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_pl record;
  v_link record;
  v_share integer;
  v_filled integer;
  v_need integer;
  v_back integer;
  v_avail integer;
  v_take integer;
  v_made integer := 0;
begin
  select l.id, l.quantity, l.jan_code, po.warehouse_id, po.status,
         coalesce(l.product_id, (select p.id from public.products p
                                  where p.jan_code = l.jan_code)) as product_id,
         public.purchase_order_line_received(l.id) as received
    into v_pl
    from public.purchase_order_lines l
    join public.purchase_orders po on po.id = l.purchase_order_id
   where l.id = p_line_id;
  if v_pl.id is null or v_pl.product_id is null then return 0; end if;

  for v_link in
    select d.id, d.sales_order_line_id, d.quantity,
           coalesce(sum(d.quantity) over (order by d.id rows between unbounded preceding
                                           and 1 preceding), 0) as before,
           sl.quantity as so_quantity, so.id as so_id, so.status as so_status
      from public.purchase_order_line_demands d
      join public.sales_order_lines sl on sl.id = d.sales_order_line_id
      join public.sales_orders so on so.id = sl.sales_order_id
     where d.purchase_order_line_id = p_line_id
     order by d.id
  loop
    v_share := least(v_link.quantity, greatest(0, v_pl.received - v_link.before));
    v_filled := public.purchase_link_filled(p_line_id, v_link.sales_order_line_id);
    v_need := v_share - v_filled;

    if v_need < 0 then
      perform public.shrink_purchase_link(p_line_id, v_link.sales_order_line_id, -v_need);
      continue;
    end if;
    continue when v_need = 0 or v_link.so_status <> 'APPROVED';

    v_back := v_link.so_quantity - public.sales_order_line_promised(v_link.sales_order_line_id);
    continue when v_back <= 0;
    v_avail := public.stock_available(v_pl.product_id, v_pl.warehouse_id);
    v_take := least(v_need, v_back, greatest(v_avail, 0));
    continue when v_take <= 0;

    insert into public.stock_reservations (
      company_id, product_id, warehouse_id, quantity, reference_type, reference_id,
      note, sales_order_line_id, purchase_order_line_id)
    values (
      (select company_id from public.products where id = v_pl.product_id),
      v_pl.product_id, v_pl.warehouse_id, v_take, 'sales_order', v_link.so_id::text,
      'SO line ' || v_link.sales_order_line_id || ' (PO line ' || p_line_id || ')',
      v_link.sales_order_line_id, p_line_id);
    v_made := v_made + v_take;
  end loop;

  if v_made > 0 then
    perform public.log_audit('purchase_order.receipt_promised', 'purchase_order_line',
      p_line_id::text, v_pl.warehouse_id, jsonb_build_object('reserved_units', v_made));
  end if;
  return v_made;
end;
$$;

create or replace function public.allocate_purchase_receipts(p_purchase_order_id bigint)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  v_total integer := 0;
begin
  for r in
    select l.id from public.purchase_order_lines l
     where l.purchase_order_id = p_purchase_order_id
       and exists (select 1 from public.purchase_order_line_demands d
                    where d.purchase_order_line_id = l.id)
     order by l.id
  loop
    v_total := v_total + public.allocate_purchase_line(r.id);
  end loop;
  return v_total;
end;
$$;

-- Every linked purchase line for a product (or every product) in a warehouse.
create or replace function public.honor_purchase_earmarks(
  p_warehouse_id bigint, p_product_id bigint default null)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  v_total integer := 0;
begin
  for r in
    select l.id
      from public.purchase_order_lines l
      join public.purchase_orders po on po.id = l.purchase_order_id
     where po.warehouse_id = p_warehouse_id
       and po.status in ('SUBMITTED', 'APPROVED', 'COMPLETED')
       and exists (select 1 from public.purchase_order_line_demands d
                    where d.purchase_order_line_id = l.id)
       and (p_product_id is null
            or coalesce(l.product_id, (select p.id from public.products p
                                        where p.jan_code = l.jan_code)) = p_product_id)
     order by po.approved_at nulls last, po.id, l.id
  loop
    v_total := v_total + public.allocate_purchase_line(r.id);
  end loop;
  return v_total;
end;
$$;

revoke all on function public.purchase_order_line_received(bigint) from public, anon, authenticated;
revoke all on function public.purchase_link_filled(bigint, bigint) from public, anon, authenticated;
revoke all on function public.purchase_order_line_linked_outstanding(bigint) from public, anon, authenticated;
revoke all on function public.shrink_purchase_link(bigint, bigint, integer) from public, anon, authenticated;
revoke all on function public.allocate_purchase_line(bigint) from public, anon, authenticated;
revoke all on function public.allocate_purchase_receipts(bigint) from public, anon, authenticated;
revoke all on function public.honor_purchase_earmarks(bigint, bigint) from public, anon, authenticated;
grant execute on function public.purchase_order_line_received(bigint) to service_role;
grant execute on function public.purchase_link_filled(bigint, bigint) to service_role;
grant execute on function public.purchase_order_line_linked_outstanding(bigint) to service_role;
grant execute on function public.shrink_purchase_link(bigint, bigint, integer) to service_role;
grant execute on function public.allocate_purchase_line(bigint) to service_role;
grant execute on function public.allocate_purchase_receipts(bigint) to service_role;
grant execute on function public.honor_purchase_earmarks(bigint, bigint) to service_role;

-- ---------------------------------------------------------------------------
-- When goods land (or a receipt is taken back)
-- ---------------------------------------------------------------------------

-- Deferred to commit on purpose: reconcile_delivery_plan bumps
-- received_quantity *before* it posts the stock movement, so a trigger that
-- ran immediately would find nothing on the shelf to promise.
create or replace function public.delivery_plan_line_received_changed()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_po bigint;
begin
  if new.received_quantity is not distinct from old.received_quantity then
    return null;
  end if;
  select purchase_order_id into v_po from public.delivery_plans
   where id = new.delivery_plan_id;
  if v_po is not null then
    perform public.allocate_purchase_receipts(v_po);
  end if;
  return null;
end;
$$;

revoke all on function public.delivery_plan_line_received_changed() from public, anon, authenticated;

drop trigger if exists delivery_plan_lines_promise_receipts on public.delivery_plan_lines;
create constraint trigger delivery_plan_lines_promise_receipts
  after update of received_quantity on public.delivery_plan_lines
  deferrable initially deferred
  for each row execute function public.delivery_plan_line_received_changed();

-- ---------------------------------------------------------------------------
-- Editing the links by hand
-- ---------------------------------------------------------------------------

-- The order lines one purchase-order line could be for: every approved order
-- line for the same product in the same warehouse, plus whatever it is linked
-- to now whatever state that order is in.
create or replace function public.purchase_line_demand_candidates(p_purchase_order_line_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_pl record;
begin
  if not public.has_permission('purchase_order.view') then
    raise exception 'not permitted: purchase_order.view required';
  end if;
  select l.id, l.quantity, l.jan_code, po.warehouse_id,
         coalesce(l.product_id, (select p.id from public.products p
                                  where p.jan_code = l.jan_code)) as product_id
    into v_pl
    from public.purchase_order_lines l
    join public.purchase_orders po on po.id = l.purchase_order_id
   where l.id = p_purchase_order_line_id;
  if v_pl.id is null then
    raise exception 'purchase order line % not found', p_purchase_order_line_id;
  end if;
  if not public.can_access_warehouse(v_pl.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'sales_order_line_id', sl.id,
             'sales_order_id', so.id,
             'so_number', so.so_number,
             'customer_name', so.customer_name,
             'status', so.status,
             'requested_ship_date', so.requested_ship_date,
             'ordered', sl.quantity,
             'promised', public.sales_order_line_promised(sl.id),
             'backordered', greatest(sl.quantity - public.sales_order_line_promised(sl.id), 0),
             'on_order', public.sales_order_line_on_order(sl.id),
             'linked', coalesce(d.quantity, 0),
             'filled', public.purchase_link_filled(v_pl.id, sl.id))
           order by (d.id is null), so.approved_at nulls last, so.id, sl.id)
      from public.sales_order_lines sl
      join public.sales_orders so on so.id = sl.sales_order_id
      left join public.purchase_order_line_demands d
             on d.purchase_order_line_id = v_pl.id and d.sales_order_line_id = sl.id
     where so.warehouse_id = v_pl.warehouse_id
       and coalesce(sl.product_id, (select p.id from public.products p
                                     where p.jan_code = sl.jan_code)) = v_pl.product_id
       and (so.status = 'APPROVED' or d.id is not null)), '[]'::jsonb);
end;
$$;

revoke all on function public.purchase_line_demand_candidates(bigint) from public, anon;
grant execute on function public.purchase_line_demand_candidates(bigint) to authenticated, service_role;

-- Replaces a purchase-order line's links. p_demands: [{sales_order_line_id,
-- quantity}]; an empty array means "bought ahead, for nobody yet". The links
-- may add up to less than the line (the rest is 見込み) but never to more.
-- Promises already made from this line to an order no longer linked are given
-- back, and the new links are filled from what has already arrived.
create or replace function public.set_purchase_order_line_demands(
  p_purchase_order_line_id bigint,
  p_demands jsonb
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_pl record;
  v_demand jsonb;
  v_so record;
  v_qty integer;
  v_links integer := 0;
  v_total integer := 0;
  v_released integer := 0;
  r record;
begin
  if not public.has_permission('purchase_order.manage') then
    raise exception 'not permitted: purchase_order.manage required';
  end if;
  if jsonb_typeof(p_demands) is distinct from 'array' then
    raise exception 'demands must be a list';
  end if;

  select l.id, l.quantity, l.jan_code, po.id as po_id, po.warehouse_id, po.status,
         coalesce(l.product_id, (select p.id from public.products p
                                  where p.jan_code = l.jan_code)) as product_id
    into v_pl
    from public.purchase_order_lines l
    join public.purchase_orders po on po.id = l.purchase_order_id
   where l.id = p_purchase_order_line_id;
  if v_pl.id is null then
    raise exception 'purchase order line % not found', p_purchase_order_line_id;
  end if;
  if not public.can_access_warehouse(v_pl.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_pl.status in ('REJECTED', 'CANCELLED') then
    raise exception 'purchase order % is % and its links can no longer change',
      v_pl.po_id, v_pl.status;
  end if;

  delete from public.purchase_order_line_demands
   where purchase_order_line_id = v_pl.id;

  for v_demand in select * from jsonb_array_elements(p_demands) loop
    v_qty := coalesce((v_demand->>'quantity')::int, 0);
    continue when v_qty <= 0;
    select sl.id, sl.quantity, so.status, so.warehouse_id,
           coalesce(sl.product_id, (select p.id from public.products p
                                     where p.jan_code = sl.jan_code)) as product_id
      into v_so
      from public.sales_order_lines sl
      join public.sales_orders so on so.id = sl.sales_order_id
     where sl.id = (v_demand->>'sales_order_line_id')::bigint;
    if v_so.id is null then
      raise exception 'sales order line % not found', v_demand->>'sales_order_line_id';
    end if;
    if v_so.warehouse_id <> v_pl.warehouse_id then
      raise exception 'sales order line % is for another warehouse', v_so.id;
    end if;
    if v_so.product_id is distinct from v_pl.product_id then
      raise exception 'sales order line % is for a different product than %',
        v_so.id, v_pl.jan_code;
    end if;
    if v_qty > v_so.quantity then
      raise exception 'sales order line % ordered only %, cannot be linked for %',
        v_so.id, v_so.quantity, v_qty;
    end if;
    insert into public.purchase_order_line_demands
      (purchase_order_line_id, sales_order_line_id, quantity)
    values (v_pl.id, v_so.id, v_qty)
    on conflict (purchase_order_line_id, sales_order_line_id)
      do update set quantity = public.purchase_order_line_demands.quantity + excluded.quantity;
    v_links := v_links + 1;
    v_total := v_total + v_qty;
  end loop;

  if v_total > v_pl.quantity then
    raise exception 'the orders linked to % add up to % but it orders only %',
      v_pl.jan_code, v_total, v_pl.quantity;
  end if;

  -- An order that lost its link loses what this purchase had promised it.
  for r in
    select distinct x.sales_order_line_id from public.stock_reservations x
     where x.purchase_order_line_id = v_pl.id
       and x.status = 'ACTIVE'
       and x.sales_order_line_id is not null
       and not exists (select 1 from public.purchase_order_line_demands d
                        where d.purchase_order_line_id = v_pl.id
                          and d.sales_order_line_id = x.sales_order_line_id)
  loop
    v_released := v_released + public.shrink_purchase_link(v_pl.id, r.sales_order_line_id, 2147483647);
  end loop;

  perform public.log_audit('purchase_order.demands_changed', 'purchase_order',
    v_pl.po_id::text, v_pl.warehouse_id,
    jsonb_build_object('purchase_order_line_id', v_pl.id, 'demands', p_demands,
                       'released_units', v_released));

  return jsonb_build_object(
    'purchase_order_line_id', v_pl.id,
    'links', v_links,
    'linked_units', v_total,
    'released_units', v_released,
    'reserved_units', public.allocate_purchase_line(v_pl.id));
end;
$$;

revoke all on function public.set_purchase_order_line_demands(bigint, jsonb) from public, anon;
grant execute on function public.set_purchase_order_line_demands(bigint, jsonb)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- The purchasing worklist, with every supplier's purchase in one total
-- ---------------------------------------------------------------------------

-- A product is listed while orders wait for it OR any open purchase is still
-- bringing it in — a purchase bought ahead of orders is worth seeing too. Every
-- supplier's purchase of a product adds into one incoming total, broken down
-- per purchase order, with how much of each nobody has ordered yet (見込み).
create or replace function public.open_demand(p_warehouse_id bigint default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('sales_order.view')
          or public.has_permission('purchase_order.view')
          or public.has_permission('inventory.view')) then
    raise exception 'not permitted: sales_order.view required';
  end if;
  if p_warehouse_id is not null and not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  return coalesce((
    with so_lines as (
      select o.warehouse_id, l.id as line_id, o.id as so_id, o.so_number,
             o.customer_name, o.approved_at, o.requested_ship_date,
             coalesce(l.product_id, (select pp.id from public.products pp
                                      where pp.jan_code = l.jan_code)) as product_id,
             l.quantity as ordered,
             public.sales_order_line_promised(l.id) as promised,
             public.sales_order_line_shipped(l.id) as shipped,
             public.sales_order_line_on_order(l.id) as on_order
        from public.sales_order_lines l
        join public.sales_orders o on o.id = l.sales_order_id
       where o.status = 'APPROVED'
         and (p_warehouse_id is null or o.warehouse_id = p_warehouse_id)
         and public.can_access_warehouse(o.warehouse_id)
    ),
    demand as (
      select warehouse_id, product_id,
             sum(ordered)::int as ordered, sum(promised)::int as promised,
             sum(shipped)::int as shipped,
             sum(greatest(ordered - promised, 0))::int as backordered,
             jsonb_agg(jsonb_build_object(
               'sales_order_line_id', line_id, 'sales_order_id', so_id,
               'so_number', so_number, 'customer_name', customer_name,
               'approved_at', approved_at, 'requested_ship_date', requested_ship_date,
               'ordered', ordered, 'promised', promised, 'shipped', shipped,
               'backordered', greatest(ordered - promised, 0), 'on_order', on_order)
               order by approved_at nulls last, so_id, line_id)
               filter (where ordered > promised) as lines
        from so_lines
       where product_id is not null
       group by warehouse_id, product_id
      having sum(greatest(ordered - promised, 0)) > 0
    ),
    po_lines as (
      select po.warehouse_id, po.id as po_id, po.po_number, po.supplier_name,
             po.status, po.expected_date,
             coalesce(l.product_id, (select pp.id from public.products pp
                                      where pp.jan_code = l.jan_code)) as product_id,
             greatest(l.quantity - public.purchase_order_line_received(l.id), 0) as outstanding,
             public.purchase_order_line_linked_outstanding(l.id) as linked_outstanding
        from public.purchase_order_lines l
        join public.purchase_orders po on po.id = l.purchase_order_id
       where po.status in ('DRAFT', 'SUBMITTED', 'APPROVED')
         and (p_warehouse_id is null or po.warehouse_id = p_warehouse_id)
         and public.can_access_warehouse(po.warehouse_id)
    ),
    incoming as (
      select warehouse_id, product_id,
             sum(outstanding)::int as incoming,
             sum(greatest(outstanding - linked_outstanding, 0))::int as incoming_unlinked,
             jsonb_agg(jsonb_build_object(
               'purchase_order_id', po_id, 'po_number', po_number,
               'supplier_name', supplier_name, 'status', status,
               'expected_date', expected_date, 'outstanding', outstanding,
               'unlinked', greatest(outstanding - linked_outstanding, 0))
               order by expected_date nulls last, po_id) as orders
        from po_lines
       where product_id is not null and outstanding > 0
       group by warehouse_id, product_id
    ),
    keys as (
      select warehouse_id, product_id from demand
      union
      select warehouse_id, product_id from incoming
    )
    select jsonb_agg(row_to_json(t)::jsonb order by t.to_purchase desc, t.backordered desc,
                                                   t.product_name)
      from (
        select k.warehouse_id, w.name as warehouse_name, k.product_id,
               p.jan_code, p.name as product_name,
               coalesce(d.ordered, 0) as ordered,
               coalesce(d.promised, 0) as promised,
               coalesce(d.shipped, 0) as shipped,
               coalesce(d.backordered, 0) as backordered,
               public.stock_available(k.product_id, k.warehouse_id) as available,
               coalesce(i.incoming, 0) as incoming,
               coalesce(i.incoming_unlinked, 0) as incoming_unlinked,
               least(coalesce(d.backordered, 0),
                     greatest(public.stock_available(k.product_id, k.warehouse_id), 0))
                 as can_fill_now,
               greatest(coalesce(d.backordered, 0)
                        - greatest(public.stock_available(k.product_id, k.warehouse_id), 0)
                        - coalesce(i.incoming, 0), 0) as to_purchase,
               wp.preferred_supplier_id,
               s.name as preferred_supplier_name,
               coalesce(d.lines, '[]'::jsonb) as lines,
               coalesce(i.orders, '[]'::jsonb) as incoming_orders
          from keys k
          left join demand d on d.warehouse_id = k.warehouse_id and d.product_id = k.product_id
          left join incoming i on i.warehouse_id = k.warehouse_id and i.product_id = k.product_id
          join public.products p on p.id = k.product_id
          join public.warehouses w on w.id = k.warehouse_id
          left join public.warehouse_products wp
                 on wp.product_id = k.product_id and wp.warehouse_id = k.warehouse_id
                and wp.is_active
          left join public.delivery_suppliers s on s.id = wp.preferred_supplier_id
      ) t), '[]'::jsonb);
end;
$$;

revoke all on function public.open_demand(bigint) from public, anon;
grant execute on function public.open_demand(bigint) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- The functions that now honour a purchase's links first
-- ---------------------------------------------------------------------------

create or replace function public.approve_sales_order(p_id bigint)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_status text;
  v_warehouse_id bigint;
  v_requested_by uuid;
  v_approver uuid := auth.uid();
  r record;
  v_product_id bigint;
  v_available integer;
  v_take integer;
  v_reserved_lines integer := 0;
  v_backordered integer := 0;
  v_skipped jsonb := '[]'::jsonb;
begin
  if not public.has_permission('sales_order.approve') then
    raise exception 'not permitted: sales_order.approve required';
  end if;

  select status, warehouse_id, requested_by
    into v_status, v_warehouse_id, v_requested_by
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
    select l.id as line_id, l.jan_code, l.quantity, l.product_id
      from public.sales_order_lines l where l.sales_order_id = p_id
     order by l.id
  loop
    v_product_id := coalesce(r.product_id,
      (select p.id from public.products p where p.jan_code = r.jan_code));

    if v_product_id is null then
      v_skipped := v_skipped || jsonb_build_object(
        'line_id', r.line_id, 'jan_code', r.jan_code, 'reason', 'unlinked_jan_code',
        'requested', r.quantity, 'reserved', 0, 'backordered', r.quantity);
      v_backordered := v_backordered + r.quantity;
      continue;
    end if;

    -- Reads what earlier lines in this loop already claimed, so two lines of
    -- one product cannot both be promised the same units.
    -- Goods that arrived on a purchase bought for other orders go to those
    -- orders first; only what is left over is free for this one (0086).
    perform public.honor_purchase_earmarks(v_warehouse_id, v_product_id);
    v_available := public.stock_available(v_product_id, v_warehouse_id);
    v_take := least(r.quantity, greatest(v_available, 0));

    if v_take > 0 then
      insert into public.stock_reservations (
        company_id, product_id, warehouse_id, quantity, reference_type, reference_id,
        note, sales_order_line_id)
      values (
        (select company_id from public.products where id = v_product_id),
        v_product_id, v_warehouse_id, v_take, 'sales_order', p_id::text,
        'SO line ' || r.line_id, r.line_id);
      v_reserved_lines := v_reserved_lines + 1;
    end if;

    if v_take < r.quantity then
      v_skipped := v_skipped || jsonb_build_object(
        'line_id', r.line_id, 'jan_code', r.jan_code, 'reason', 'insufficient_available',
        'available', v_available, 'requested', r.quantity,
        'reserved', v_take, 'backordered', r.quantity - v_take);
      v_backordered := v_backordered + (r.quantity - v_take);
    end if;
  end loop;

  perform public.log_audit('sales_order.approved', 'sales_order', p_id::text, v_warehouse_id,
    jsonb_build_object('reserved_lines', v_reserved_lines,
                       'backordered_units', v_backordered, 'skipped', v_skipped));

  return jsonb_build_object(
    'sales_order_id', p_id,
    'status', 'APPROVED',
    'reserved_lines', v_reserved_lines,
    'backordered_units', v_backordered,
    'skipped', v_skipped);
end;
$$;

create or replace function public.fill_backorders(
  p_warehouse_id bigint,
  p_product_id bigint default null,
  p_sales_order_line_id bigint default null,
  p_quantity integer default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  v_need integer;
  v_avail integer;
  v_take integer;
  v_left integer := p_quantity;
  v_units integer := 0;
  v_filled jsonb := '[]'::jsonb;
begin
  if not (public.has_permission('sales_order.manage')
          or public.has_permission('inventory.adjust')) then
    raise exception 'not permitted: sales_order.manage required';
  end if;
  if p_warehouse_id is null then
    raise exception 'warehouse is required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if p_quantity is not null and p_quantity <= 0 then
    raise exception 'quantity must be greater than zero';
  end if;

  -- Arrived purchases go to the orders they were bought for before anything
  -- is handed out oldest-first (0086).
  if p_sales_order_line_id is not null then
    perform public.honor_purchase_earmarks(p_warehouse_id,
      (select coalesce(l.product_id, (select p.id from public.products p
                                       where p.jan_code = l.jan_code))
         from public.sales_order_lines l where l.id = p_sales_order_line_id));
  else
    perform public.honor_purchase_earmarks(p_warehouse_id, p_product_id);
  end if;

  for r in
    select l.id as line_id, l.quantity, l.jan_code, o.id as so_id, o.so_number,
           coalesce(l.product_id,
             (select p.id from public.products p where p.jan_code = l.jan_code)) as product_id
      from public.sales_order_lines l
      join public.sales_orders o on o.id = l.sales_order_id
     where o.status = 'APPROVED'
       and o.warehouse_id = p_warehouse_id
       and (p_sales_order_line_id is null or l.id = p_sales_order_line_id)
     order by o.approved_at nulls last, o.id, l.id
  loop
    exit when v_left is not null and v_left <= 0;
    continue when r.product_id is null;
    continue when p_product_id is not null and r.product_id <> p_product_id;

    v_need := r.quantity - public.sales_order_line_promised(r.line_id);
    continue when v_need <= 0;
    v_avail := public.stock_available(r.product_id, p_warehouse_id);
    continue when v_avail <= 0;
    v_take := least(v_need, v_avail, coalesce(v_left, v_need));

    insert into public.stock_reservations (
      company_id, product_id, warehouse_id, quantity, reference_type, reference_id,
      note, sales_order_line_id)
    values (
      (select company_id from public.products where id = r.product_id),
      r.product_id, p_warehouse_id, v_take, 'sales_order', r.so_id::text,
      'SO line ' || r.line_id, r.line_id);

    v_units := v_units + v_take;
    if v_left is not null then v_left := v_left - v_take; end if;
    v_filled := v_filled || jsonb_build_object(
      'sales_order_line_id', r.line_id, 'sales_order_id', r.so_id,
      'so_number', r.so_number, 'jan_code', r.jan_code,
      'reserved', v_take, 'still_backordered', v_need - v_take);
  end loop;

  if v_units > 0 then
    perform public.log_audit('sales_order.backorders_filled', 'warehouse',
      p_warehouse_id::text, p_warehouse_id,
      jsonb_build_object('reserved_units', v_units, 'filled', v_filled));
  end if;

  return jsonb_build_object('reserved_units', v_units, 'filled', v_filled);
end;
$$;

create or replace function public.link_delivery_plan_to_purchase_order(
  p_delivery_plan_id bigint,
  p_purchase_order_id bigint
) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_plan record;
  v_po record;
begin
  if not (public.has_permission('purchase_order.manage')
          or public.has_permission('receiving.confirm')) then
    raise exception 'not permitted: purchase_order.manage required';
  end if;

  select id, warehouse_id, purchase_order_id into v_plan
    from public.delivery_plans where id = p_delivery_plan_id;
  if v_plan.id is null then
    raise exception 'delivery plan % not found', p_delivery_plan_id;
  end if;
  select id, warehouse_id, status into v_po
    from public.purchase_orders where id = p_purchase_order_id;
  if v_po.id is null then
    raise exception 'purchase order % not found', p_purchase_order_id;
  end if;
  if not public.can_access_warehouse(v_po.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_plan.warehouse_id is not null and v_plan.warehouse_id <> v_po.warehouse_id then
    raise exception 'delivery plan % is for another warehouse than purchase order %',
      p_delivery_plan_id, p_purchase_order_id;
  end if;
  if v_plan.purchase_order_id is not null
     and v_plan.purchase_order_id <> p_purchase_order_id then
    raise exception 'delivery plan % is already linked to purchase order %',
      p_delivery_plan_id, v_plan.purchase_order_id;
  end if;
  if v_po.status not in ('SUBMITTED', 'APPROVED') then
    raise exception 'purchase order % is % and cannot take a delivery',
      p_purchase_order_id, v_po.status;
  end if;

  update public.delivery_plans
     set purchase_order_id = p_purchase_order_id,
         warehouse_id = coalesce(warehouse_id, v_po.warehouse_id)
   where id = p_delivery_plan_id;

  -- Whatever this plan already received now counts for the order's buyers.
  perform public.allocate_purchase_receipts(p_purchase_order_id);

  perform public.log_audit('delivery_plan.linked_to_purchase_order', 'delivery_plan',
    p_delivery_plan_id::text, v_po.warehouse_id,
    jsonb_build_object('purchase_order_id', p_purchase_order_id));
  return true;
end;
$$;

create or replace function public.create_purchase_order_from_demand(
  p_supplier_name text,
  p_warehouse_id bigint,
  p_lines jsonb,
  p_supplier_id bigint default null,
  p_expected_date date default null,
  p_note text default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_po_id bigint;
  v_line jsonb;
  v_pl record;
  v_demand jsonb;
  v_so_line record;
  v_left integer;
  v_take integer;
  v_qty integer;
  v_links integer := 0;
  v_free integer;
  v_uncovered integer;
begin
  -- create_purchase_order does the permission, scope, supplier and line checks.
  if jsonb_typeof(p_lines) is distinct from 'array' then
    raise exception 'at least one line is required';
  end if;
  if (select count(*) from jsonb_array_elements(p_lines) e)
       <> (select count(distinct e->>'jan_code') from jsonb_array_elements(p_lines) e) then
    raise exception 'each product may appear only once on a purchase order raised from demand';
  end if;

  v_po_id := public.create_purchase_order(
    p_supplier_name, p_warehouse_id, p_lines, p_supplier_id, p_expected_date, p_note);

  for v_pl in
    select l.id, l.jan_code, l.quantity,
           coalesce(l.product_id, (select p.id from public.products p
                                    where p.jan_code = l.jan_code)) as product_id
      from public.purchase_order_lines l where l.purchase_order_id = v_po_id
     order by l.id
  loop
    select e into v_line from jsonb_array_elements(p_lines) e
     where e->>'jan_code' = v_pl.jan_code limit 1;

    if v_line ? 'demands' and jsonb_typeof(v_line->'demands') = 'array' then
      for v_demand in select * from jsonb_array_elements(v_line->'demands') loop
        v_qty := coalesce((v_demand->>'quantity')::int, 0);
        continue when v_qty <= 0;
        select l.id, l.quantity,
               coalesce(l.product_id, (select p.id from public.products p
                                        where p.jan_code = l.jan_code)) as product_id,
               o.status, o.warehouse_id
          into v_so_line
          from public.sales_order_lines l
          join public.sales_orders o on o.id = l.sales_order_id
         where l.id = (v_demand->>'sales_order_line_id')::bigint;
        if v_so_line.id is null then
          raise exception 'sales order line % not found', v_demand->>'sales_order_line_id';
        end if;
        if v_so_line.status <> 'APPROVED' or v_so_line.warehouse_id <> p_warehouse_id then
          raise exception 'sales order line % is not an approved order in this warehouse',
            v_so_line.id;
        end if;
        if v_qty > v_so_line.quantity then
          raise exception 'sales order line % ordered only %, cannot be linked for %',
            v_so_line.id, v_so_line.quantity, v_qty;
        end if;
        if v_so_line.product_id is distinct from v_pl.product_id then
          raise exception 'sales order line % is for a different product than %',
            v_so_line.id, v_pl.jan_code;
        end if;
        insert into public.purchase_order_line_demands
          (purchase_order_line_id, sales_order_line_id, quantity)
        values (v_pl.id, v_so_line.id, v_qty);
        v_links := v_links + 1;
      end loop;
      if (select coalesce(sum(d.quantity), 0) from public.purchase_order_line_demands d
           where d.purchase_order_line_id = v_pl.id) > v_pl.quantity then
        raise exception 'the orders linked to % add up to more than its quantity %',
          v_pl.jan_code, v_pl.quantity;
      end if;
    elsif v_pl.product_id is not null then
      v_left := v_pl.quantity;
      v_free := greatest(public.stock_available(v_pl.product_id, p_warehouse_id), 0);
      for v_so_line in
        select l.id,
               greatest(l.quantity - public.sales_order_line_promised(l.id)
                        - public.sales_order_line_on_order(l.id), 0) as uncovered
          from public.sales_order_lines l
          join public.sales_orders o on o.id = l.sales_order_id
         where o.status = 'APPROVED' and o.warehouse_id = p_warehouse_id
           and coalesce(l.product_id, (select p.id from public.products p
                                        where p.jan_code = l.jan_code)) = v_pl.product_id
         order by o.approved_at nulls last, o.id, l.id
      loop
        exit when v_left <= 0;
        -- Free stock will reach the oldest waiting lines first (fill_backorders
        -- walks them in this same order), so they are not what is being bought for.
        v_uncovered := v_so_line.uncovered - least(v_free, v_so_line.uncovered);
        v_free := v_free - least(v_free, v_so_line.uncovered);
        continue when v_uncovered <= 0;
        v_take := least(v_left, v_uncovered);
        insert into public.purchase_order_line_demands
          (purchase_order_line_id, sales_order_line_id, quantity)
        values (v_pl.id, v_so_line.id, v_take);
        v_left := v_left - v_take;
        v_links := v_links + 1;
      end loop;
    end if;
  end loop;

  perform public.log_audit('purchase_order.created_from_demand', 'purchase_order',
    v_po_id::text, p_warehouse_id, jsonb_build_object('links', v_links));

  return jsonb_build_object(
    'purchase_order_id', v_po_id,
    'lines', (select count(*) from public.purchase_order_lines where purchase_order_id = v_po_id),
    'links', v_links);
end;
$$;

revoke all on function public.create_purchase_order_from_demand(text, bigint, jsonb, bigint, date, text)
  from public, anon;
grant execute on function public.create_purchase_order_from_demand(text, bigint, jsonb, bigint, date, text)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Reading it
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
                 'quantity', l.quantity, 'unit_price', l.unit_price,
                 'product_id', coalesce(l.product_id, (select pp.id from public.products pp
                                                        where pp.jan_code = l.jan_code)),
                 'promised', public.sales_order_line_promised(l.id),
                 'shipped', public.sales_order_line_shipped(l.id),
                 'backordered', greatest(l.quantity - public.sales_order_line_promised(l.id), 0),
                 'on_order', public.sales_order_line_on_order(l.id),
                 'purchase_orders', coalesce((
                   select jsonb_agg(jsonb_build_object(
                            'purchase_order_id', po.id, 'po_number', po.po_number,
                            'status', po.status, 'supplier_name', po.supplier_name,
                            'quantity', d.quantity,
                            'filled', public.purchase_link_filled(pl.id, l.id)) order by po.id)
                     from public.purchase_order_line_demands d
                     join public.purchase_order_lines pl on pl.id = d.purchase_order_line_id
                     join public.purchase_orders po on po.id = pl.purchase_order_id
                    where d.sales_order_line_id = l.id), '[]'::jsonb))
               order by l.id)
          from public.sales_order_lines l
         where l.sales_order_id = o.id), '[]'::jsonb),
      -- The shipment still to go out if there is one, else the latest.
      'shipment_plan_id', coalesce(
        (select sp.id from public.shipment_plans sp
          where sp.sales_order_id = o.id and sp.status not in ('cancelled', 'shipped')
          order by sp.id desc limit 1),
        (select sp.id from public.shipment_plans sp
          where sp.sales_order_id = o.id and sp.status <> 'cancelled'
          order by sp.id desc limit 1)),
      'open_shipment_plan_id', (
        select sp.id from public.shipment_plans sp
         where sp.sales_order_id = o.id and sp.status not in ('cancelled', 'shipped')
         order by sp.id desc limit 1),
      'shipments', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'id', sp.id, 'shipment_number', sp.shipment_number, 'status', sp.status)
               order by sp.id)
          from public.shipment_plans sp
         where sp.sales_order_id = o.id and sp.status <> 'cancelled'), '[]'::jsonb),
      'reservations', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'id', r.id, 'jan_code', p.jan_code, 'quantity', r.quantity,
                 'fulfilled_quantity', r.fulfilled_quantity, 'status', r.status,
                 'sales_order_line_id', r.sales_order_line_id)
               order by r.id)
          from public.stock_reservations r
          join public.products p on p.id = r.product_id
         where r.sales_order_line_id in (select id from public.sales_order_lines
                                          where sales_order_id = o.id)
            or (r.reference_type = 'sales_order' and r.reference_id = o.id::text)
            or (r.reference_type = 'shipment' and r.reference_id in (
                  select sp.id::text from public.shipment_plans sp
                   where sp.sales_order_id = o.id))
        ), '[]'::jsonb))
    from public.sales_orders o
    join public.warehouses w on w.id = o.warehouse_id
   where o.id = p_id);
end;
$$;

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
      'delivery_plans', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'id', dp.id, 'delivery_number', dp.delivery_number,
                 'status', dp.status, 'created_at', dp.created_at) order by dp.id)
          from public.delivery_plans dp
         where dp.purchase_order_id = o.id), '[]'::jsonb),
      'lines', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'id', l.id, 'jan_code', l.jan_code, 'product_name', l.product_name,
                 'quantity', l.quantity, 'unit_price', l.unit_price,
                 'planned', coalesce((
                   select sum(dpl.planned_quantity) from public.delivery_plan_lines dpl
                     join public.delivery_plans dp on dp.id = dpl.delivery_plan_id
                    where dp.purchase_order_id = o.id and dpl.jan_code = l.jan_code), 0),
                 'received', public.purchase_order_line_received(l.id),
                 'linked', coalesce((select sum(d.quantity) from public.purchase_order_line_demands d
                                      where d.purchase_order_line_id = l.id), 0),
                 'demands', coalesce((
                   select jsonb_agg(jsonb_build_object(
                            'sales_order_line_id', d.sales_order_line_id,
                            'sales_order_id', so.id, 'so_number', so.so_number,
                            'customer_name', so.customer_name, 'quantity', d.quantity,
                            'filled', public.purchase_link_filled(l.id, sl.id))
                          order by so.id)
                     from public.purchase_order_line_demands d
                     join public.sales_order_lines sl on sl.id = d.sales_order_line_id
                     join public.sales_orders so on so.id = sl.sales_order_id
                    where d.purchase_order_line_id = l.id), '[]'::jsonb))
               order by l.id)
          from public.purchase_order_lines l
         where l.purchase_order_id = o.id), '[]'::jsonb))
    from public.purchase_orders o
    join public.warehouses w on w.id = o.warehouse_id
   where o.id = p_id);
end;
$$;
