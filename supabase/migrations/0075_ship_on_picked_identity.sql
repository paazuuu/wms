-- 0075 — Phase C: shipping draws on what was picked, and keeps the promise (§6)
--
-- 0074 recorded which parcels a picker actually took. This is where that record
-- starts deciding the ledger, and where §6's last arrow finally exists:
--
--     Sales Order -> Reservation -> Allocation -> Pick -> Pack -> Ship
--                    ^^^^^^^^^^^ (0073)                           ^^^^ (here)
--
-- TWO THINGS CHANGE
--
-- 1. **A shipment posts one movement per parcel, with its lot and serial**, for
--    everything `pick_items` recorded. Before this, `ship_plan` posted one
--    JAN-level movement per line and 0068's draw order picked a lot on its own —
--    correct by default, wrong exactly when the picker took a different carton
--    than the rule suggested. That case is the whole reason 0074 exists, and
--    until now the record of it stopped at the pick list.
--
--    Quantity a task carries *without* parcel detail still posts exactly as it
--    did before, JAN-level and FEFO-drawn. So a warehouse that never scans a lot
--    sees no change, and one that scans some of them gets identity for the part
--    it scanned. `greatest(picked - detailed, 0)` is what splits the two, and it
--    is per task, not per JAN, so one line scanned and another keyed still adds
--    up to what left the building.
--
-- 2. **Shipping fulfils the reservations filed against it** (0073 re-keyed them
--    from the order to the shipment). `fulfil_reservation` is not called: it
--    re-checks permissions against the caller, and `ship_plan` runs as
--    service_role behind the shipments edge function, where `auth.uid()` is null
--    and the gate has already been passed. The update is inlined instead — the
--    same reason 0073 inlined its inserts.
--
--    It does **not** move stock. The movements above did that, and doing it
--    again here is precisely the double count §5 warns about. What this records
--    is that the promise has been kept, so it stops holding the quantity it was
--    holding, and availability rises because the stock left rather than because
--    the promise was forgotten.
--
--    How much to fulfil comes from the ledger, not from the order lines: a plan
--    whose lines were edited after shipping would otherwise credit the wrong
--    amount. Two reservations for the same product on one shipment are handled
--    by re-reading what is already fulfilled on each pass, so the second one
--    cannot claim what the first just took.
--
-- Cancelling a shipment reverses both halves: the ledger parcel by parcel (0018
-- reversed `shipped_net`, which is per JAN — see the comment in the function for
-- why that is not good enough once lots are recorded) and the fulfilment, back
-- to ACTIVE with nothing fulfilled, because this API un-ships a whole plan and
-- has no partial. A RELEASED reservation stays released: somebody let that one
-- go on purpose.
--
-- KNOWN LIMIT, STATED RATHER THAN HIDDEN
--
-- `apply_stock_movement_detail` deliberately does not pass `bin_id` down to
-- `apply_stock_unit_delta` (0066: at warehouse scope a unit is "in the
-- building", and a receipt has no bin until put-away). So a movement here
-- records the bin the picker took from, and the parcel the draw lands on is
-- chosen by product + lot + status, not by bin. With one lot split across two
-- bins, `stock_units` can therefore attribute the decrement to the wrong bin
-- while the warehouse and lot totals stay exactly right. Fixing it means letting
-- a negative movement with a bin draw from that bin, which would also change
-- transfers and adjustments that name one — a separate concern, and a separate
-- migration.

create or replace function public.ship_plan(p_plan_id bigint)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_status    text;
  v_warehouse bigint;
  v_picked    bigint;
  r           record;
  v_res       record;
  v_shipped   integer;
  v_already   integer;
  v_take      integer;
begin
  select status, coalesce(warehouse_id, public.default_warehouse_id())
    into v_status, v_warehouse
    from public.shipment_plans where id = p_plan_id;
  if v_status is null then raise exception 'shipment % not found', p_plan_id; end if;
  if v_status = 'shipped' then return p_plan_id; end if;

  -- A completed pick list is the truth about what is on the cart. Without one
  -- the order lines still stand in, so plans that never went through picking
  -- ship exactly as they did before.
  select id into v_picked from public.pick_lists
   where shipment_plan_id = p_plan_id and status = 'PICKED'
   order by id desc limit 1;

  -- 1. Parcels the picker recorded, each with its own identity (0074).
  if v_picked is not null then
    for r in
      select i.product_id,
             coalesce(p.jan_code, t.jan_code) as jan_code,
             coalesce(nullif(t.product_name, ''), p.name, '') as product_name,
             i.lot_id, i.serial_id, i.bin_id,
             sum(i.quantity)::int as qty
        from public.pick_items i
        join public.pick_tasks t on t.id = i.pick_task_id
        left join public.products p on p.id = i.product_id
       where t.pick_list_id = v_picked
       group by i.product_id, coalesce(p.jan_code, t.jan_code),
                coalesce(nullif(t.product_name, ''), p.name, ''),
                i.lot_id, i.serial_id, i.bin_id
       order by 1, 4, 5, 6
    loop
      -- No status is passed on purpose: a null status_id is what makes 0068's
      -- gate apply, so this draws from shippable parcels of that lot only.
      perform public.apply_stock_movement_detail(
        p_warehouse_id   => v_warehouse,
        p_jan_code       => r.jan_code,
        p_quantity       => -r.qty,
        p_movement_type  => 'SHIP',
        p_reference_type => 'shipment_plan',
        p_reference_id   => p_plan_id::text,
        p_product_name   => r.product_name,
        p_bin_id         => r.bin_id,
        p_lot_id         => r.lot_id,
        p_serial_id      => r.serial_id,
        p_product_id     => r.product_id);
    end loop;
  end if;

  -- 2. Everything picked or ordered without parcel detail, exactly as before.
  for r in
    select q.jan, q.qty, q.pname from (
      select t.jan_code as jan,
             sum(greatest(coalesce(t.picked_quantity, 0)
                          - coalesce(d.detailed, 0), 0))::int as qty,
             coalesce(max(t.product_name), '') as pname
        from public.pick_tasks t
        left join (select pick_task_id, sum(quantity)::int as detailed
                     from public.pick_items group by pick_task_id) d
               on d.pick_task_id = t.id
       where v_picked is not null and t.pick_list_id = v_picked
       group by t.jan_code
      union all
      select l.jan_code,
             sum(coalesce(l.quantity, 0))::int,
             coalesce(max(l.product_name), '')
        from public.shipment_lines l
       where v_picked is null and l.shipment_plan_id = p_plan_id
       group by l.jan_code
    ) q
    where q.qty > 0
  loop
    perform public.apply_stock_movement(
      v_warehouse, r.jan, -r.qty, 'SHIP',
      'shipment_plan', p_plan_id::text, r.pname);
  end loop;

  update public.shipment_plans
     set status = 'shipped', shipped_at = now()
   where id = p_plan_id;

  -- 3. §6: the promise has been kept. No stock moves here — see the header.
  for v_res in
    select r2.id, r2.product_id, r2.quantity - r2.fulfilled_quantity as outstanding
      from public.stock_reservations r2
     where r2.reference_type = 'shipment'
       and r2.reference_id = p_plan_id::text
       and r2.status = 'ACTIVE'
     order by r2.id
  loop
    continue when v_res.outstanding <= 0;

    -- What the ledger says actually left for this product on this shipment.
    select coalesce(sum(-m.quantity), 0)::int into v_shipped
      from public.stock_movements m
     where m.reference_type = 'shipment_plan'
       and m.reference_id = p_plan_id::text
       and m.movement_type in ('SHIP', 'SHIP_CANCEL')
       and m.balance_scope = 'WAREHOUSE'
       and m.product_id = v_res.product_id;

    -- Re-read each pass, so two reservations for one product share the shipment
    -- rather than both claiming all of it.
    select coalesce(sum(r3.fulfilled_quantity), 0)::int into v_already
      from public.stock_reservations r3
     where r3.reference_type = 'shipment'
       and r3.reference_id = p_plan_id::text
       and r3.product_id = v_res.product_id;

    v_take := least(v_res.outstanding, greatest(v_shipped - v_already, 0));
    if v_take <= 0 then continue; end if;

    update public.stock_reservations
       set fulfilled_quantity = fulfilled_quantity + v_take,
           status = case when fulfilled_quantity + v_take >= quantity
                         then 'FULFILLED' else status end,
           updated_at = now()
     where id = v_res.id;

    -- A fully kept promise has nothing left to plan for (0064's own rule).
    delete from public.stock_allocations
     where reservation_id = v_res.id
       and exists (select 1 from public.stock_reservations x
                    where x.id = v_res.id and x.status = 'FULFILLED');
  end loop;

  perform public.log_audit(
    'shipment.completed', 'shipment_plan', p_plan_id::text, v_warehouse,
    jsonb_build_object(
      'pick_list_id', v_picked,
      'parcels_posted', (
        select count(*) from public.pick_items i
          join public.pick_tasks t on t.id = i.pick_task_id
         where v_picked is not null and t.pick_list_id = v_picked),
      'reservations_fulfilled', (
        select count(*) from public.stock_reservations r4
         where r4.reference_type = 'shipment'
           and r4.reference_id = p_plan_id::text
           and r4.status = 'FULFILLED')));

  return p_plan_id;
end;
$$;

create or replace function public.cancel_shipment(p_plan_id bigint)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_status    text;
  v_warehouse bigint;
  v_back_to   text;
  r           record;
begin
  select status, coalesce(warehouse_id, public.default_warehouse_id())
    into v_status, v_warehouse
    from public.shipment_plans where id = p_plan_id;
  if v_status is null then raise exception 'shipment % not found', p_plan_id; end if;

  if v_status = 'shipped' then
    -- Reverse the ledger's own net, parcel by parcel, so this puts back exactly
    -- what went out — the same lot, serial and bin it left from. `shipped_net`
    -- (0018) aggregates per JAN, and reversing that way would return the
    -- quantity as a *lot-less* parcel: the warehouse total would be right and
    -- the lot attribution silently wrong, which is the one thing 0075 exists to
    -- stop. Grouping the movements by identity and negating each group's net
    -- also makes this idempotent against a plan that was shipped, cancelled and
    -- shipped again.
    --
    -- Status is not restated, because the SHIP row deliberately carries none
    -- (that null is what arms 0068's gate). A reversal therefore returns stock
    -- as OK, which is what it must have been: `record_pick_item` only accepts a
    -- parcel in a shippable condition.
    for r in
      select m.product_id, m.jan_code,
             coalesce(max(m.product_name), '') as product_name,
             m.lot_id, m.serial_id, m.bin_id,
             sum(m.quantity)::int as net
        from public.stock_movements m
       where m.reference_type = 'shipment_plan'
         and m.reference_id = p_plan_id::text
         and m.movement_type in ('SHIP', 'SHIP_CANCEL')
         and m.balance_scope = 'WAREHOUSE'
       group by m.product_id, m.jan_code, m.lot_id, m.serial_id, m.bin_id
      having sum(m.quantity) <> 0
    loop
      perform public.apply_stock_movement_detail(
        p_warehouse_id   => v_warehouse,
        p_jan_code       => r.jan_code,
        p_quantity       => -r.net,
        p_movement_type  => 'SHIP_CANCEL',
        p_reference_type => 'shipment_plan',
        p_reference_id   => p_plan_id::text,
        p_product_name   => r.product_name,
        p_bin_id         => r.bin_id,
        p_lot_id         => r.lot_id,
        p_serial_id      => r.serial_id,
        p_product_id     => r.product_id);
    end loop;

    -- The promise is a promise again. Whole-plan, because this API un-ships a
    -- whole plan; a RELEASED reservation stays released, since someone let that
    -- one go deliberately.
    update public.stock_reservations
       set fulfilled_quantity = 0,
           status = case when status = 'FULFILLED' then 'ACTIVE' else status end,
           updated_at = now()
     where reference_type = 'shipment'
       and reference_id = p_plan_id::text
       and status in ('ACTIVE', 'FULFILLED');
  end if;

  -- Back to packing when the picking still stands, otherwise back to open.
  select case when exists (
           select 1 from public.pick_lists
            where shipment_plan_id = p_plan_id and status = 'PICKED')
         then 'packing' else 'open' end
    into v_back_to;

  update public.shipment_plans
     set status = v_back_to, shipped_at = null
   where id = p_plan_id;

  perform public.log_audit(
    'shipment.cancelled', 'shipment_plan', p_plan_id::text, v_warehouse,
    jsonb_build_object('was', v_status, 'now', v_back_to));

  return p_plan_id;
end;
$$;

-- What left the building on this shipment, parcel by parcel. The read a recall
-- starts from: "which lots went to this customer, and when". Lives beside the
-- shipment rather than in `stock_ledger` because the question is asked about a
-- shipment, and answering it from the ledger means knowing to filter on a
-- reference pair.
create or replace function public.shipment_parcels(p_plan_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_warehouse bigint;
begin
  select coalesce(warehouse_id, public.default_warehouse_id()) into v_warehouse
    from public.shipment_plans where id = p_plan_id;
  if v_warehouse is null then
    raise exception 'shipment % not found', p_plan_id;
  end if;
  if not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'movement_id', m.id,
             'created_at', m.created_at,
             'movement_type', m.movement_type,
             'jan_code', m.jan_code,
             'product_id', m.product_id,
             'product_name', m.product_name,
             -- Positive: how many units this row took out. SHIP_CANCEL rows
             -- carry the opposite sign and are shown as they are, because a
             -- reversal is part of the answer, not noise.
             'quantity', -m.quantity,
             'lot_id', m.lot_id,
             'lot_code', l.lot_code,
             'expiry_date', l.expiry_date,
             'serial_id', m.serial_id,
             'serial_number', sn.serial_number,
             'bin_id', m.bin_id,
             'bin_code', b.code)
           order by m.id)
      from public.stock_movements m
      left join public.lots l on l.id = m.lot_id
      left join public.serial_numbers sn on sn.id = m.serial_id
      left join public.bins b on b.id = m.bin_id
     where m.reference_type = 'shipment_plan'
       and m.reference_id = p_plan_id::text
       and m.movement_type in ('SHIP', 'SHIP_CANCEL')
       and m.balance_scope = 'WAREHOUSE'), '[]'::jsonb);
end;
$$;

revoke all on function public.shipment_parcels(bigint) from public, anon;
grant execute on function public.shipment_parcels(bigint)
  to authenticated, service_role;
