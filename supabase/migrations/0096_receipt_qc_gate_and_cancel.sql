-- 0096 — goods counted in without parcel detail still go through inspection,
-- and cancelling a receipt takes back exactly what it put in.
--
-- 1. The QC gate (0068/0072) lived in `record_receipt_item_impl`, which is
--    what a parcel with detail (lot, expiry, location …) goes through. But
--    `reconcile_delivery_plan` posts whatever the parcels do not account for —
--    which, for a plain count, is the whole line — with its own stock
--    movement and a receipt item marked OK. So a product that requires
--    inspection, received the ordinary way (count, no parcels), landed
--    straight in shippable stock and never waited for QC. The remainder now
--    goes through `record_receipt_item_impl` like any other parcel, so it
--    lands QC_PENDING whenever the product (or product × warehouse) requires
--    inspection.
--
-- 2. `cancel_reconciliation` reversed each line by JAN as plain OK stock. A
--    receipt that went into QC_PENDING, HOLD or a lot was reversed out of the
--    wrong bucket: OK went negative and the QC stock stayed. It now reverses
--    each receipt item with the status, lot, serial and bin it went in with
--    (and, for rows from before 0067 that have no receipt item, the line's
--    uncovered quantity as before).
--
--    Once the receipt's inspection is closed, its goods have moved on (to OK,
--    DAMAGED, HOLD …) and there is no longer one bucket to take them back
--    from, so the cancel is refused. Correct the stock through an adjustment
--    instead. An inspection still open is deleted with the receipt, so a
--    cancelled delivery does not sit in the inspection list.

create or replace function public.reconcile_delivery_plan(
  p_plan_id bigint, p_complete boolean default true,
  p_note_reference text default null, p_lines jsonb default '[]'::jsonb)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_recon_id    bigint;
  v_supplier    bigint;
  v_ref         text;
  v_outstanding int;
  v_status      text;
  v_warehouse   bigint;
  e             jsonb;
  it            jsonb;
  v_jan         text;
  v_qty         int;
  v_plan_line   public.delivery_plan_lines;
  v_line_id     bigint;
  v_line_status text;
  v_item_total  int;
begin
  select supplier_id, coalesce(warehouse_id, public.default_warehouse_id())
    into v_supplier, v_warehouse
    from public.delivery_plans where id = p_plan_id;
  v_ref := public.assign_reference(v_supplier);

  insert into public.delivery_reconciliations
    (delivery_plan_id, note_reference, status, supplier_id, reference_no)
  values
    (p_plan_id, p_note_reference, 'received', v_supplier, v_ref)
  returning id into v_recon_id;

  for e in select * from jsonb_array_elements(p_lines) loop
    v_jan := e->>'jan_code';
    v_qty := coalesce((e->>'actual_quantity')::int, 0);

    select * into v_plan_line from public.delivery_plan_lines
     where delivery_plan_id = p_plan_id and jan_code = v_jan
     order by id limit 1;

    v_line_status := case
      when v_plan_line.id is null then 'unexpected'
      when v_qty = 0 then 'shortfall'
      when coalesce(v_plan_line.received_quantity, 0) + v_qty
           = v_plan_line.planned_quantity then 'matched'
      when coalesce(v_plan_line.received_quantity, 0) + v_qty
           < v_plan_line.planned_quantity then 'shortfall'
      else 'over'
    end;

    insert into public.reconciliation_lines
      (reconciliation_id, plan_line_id, jan_code, planned_quantity,
       actual_quantity, status, source)
    values
      (v_recon_id, v_plan_line.id, v_jan,
       coalesce(v_plan_line.planned_quantity, 0), v_qty, v_line_status,
       e->>'source')
    returning id into v_line_id;

    if v_plan_line.id is not null then
      update public.delivery_plan_lines
         set received_quantity = coalesce(received_quantity, 0) + v_qty
       where id = v_plan_line.id;
    end if;

    if v_qty <= 0 then
      continue;
    end if;

    v_item_total := 0;
    if jsonb_typeof(e->'items') = 'array' then
      for it in select * from jsonb_array_elements(e->'items') loop
        perform public.record_receipt_item_impl(
          v_recon_id, v_warehouse, v_line_id, v_jan,
          coalesce((it->>'quantity')::int, 0),
          it->>'lot_code',
          nullif(btrim(coalesce(it->>'expiry', '')), '')::date,
          it->>'serial_number',
          it->>'location_code',
          it->>'status',
          it->>'note');
        v_item_total := v_item_total + coalesce((it->>'quantity')::int, 0);
      end loop;
    end if;

    if v_item_total > v_qty then
      raise exception 'line % reported % but its parcels add up to %',
        v_jan, v_qty, v_item_total;
    end if;

    -- What the parcels did not account for is one more parcel, through the
    -- same gate: QC_PENDING when the product requires inspection (0096).
    if v_item_total < v_qty then
      perform public.record_receipt_item_impl(
        v_recon_id, v_warehouse, v_line_id, v_jan, v_qty - v_item_total);
    end if;
  end loop;

  select coalesce(sum(greatest(
           coalesce(planned_quantity, 0) - coalesce(received_quantity, 0), 0)), 0)
    into v_outstanding
  from public.delivery_plan_lines
  where delivery_plan_id = p_plan_id;

  v_status := case
    when v_outstanding = 0 then 'completed'
    when p_complete then 'completed'
    else 'partial'
  end;

  update public.delivery_plans set status = v_status where id = p_plan_id;
  update public.delivery_reconciliations
     set status = case when v_status = 'completed' then 'completed' else 'partial' end
   where id = v_recon_id;

  perform public.detect_receiving_exceptions(v_recon_id);

  perform public.log_audit(
    'receiving.confirmed', 'reconciliation', v_recon_id::text, v_warehouse,
    jsonb_build_object('plan_id', p_plan_id, 'status', v_status,
                       'outstanding', v_outstanding));

  return v_recon_id;
end;
$$;

create or replace function public.cancel_reconciliation(p_recon_id bigint)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_plan        bigint;
  v_status      text;
  v_received    int;
  v_outstanding int;
  v_warehouse   bigint;
  v_inspection  bigint;
  r             record;
begin
  select delivery_plan_id, status into v_plan, v_status
    from public.delivery_reconciliations where id = p_recon_id
   for update;
  if v_plan is null then
    raise exception 'reconciliation % not found', p_recon_id;
  end if;
  if v_status = 'cancelled' then
    return p_recon_id;
  end if;

  if exists (select 1 from public.inspections
              where reconciliation_id = p_recon_id and status <> 'PENDING') then
    raise exception
      'receipt % has a completed inspection, so its goods have already moved on and it cannot be cancelled — correct the stock with an adjustment instead',
      p_recon_id;
  end if;

  select coalesce(warehouse_id, public.default_warehouse_id()) into v_warehouse
    from public.delivery_plans where id = v_plan;

  update public.delivery_plan_lines pl
     set received_quantity = greatest(coalesce(pl.received_quantity, 0) - agg.qty, 0)
  from (
    select plan_line_id, sum(coalesce(actual_quantity, 0)) as qty
    from public.reconciliation_lines
    where reconciliation_id = p_recon_id and plan_line_id is not null
    group by plan_line_id
  ) agg
  where pl.id = agg.plan_line_id;

  -- Each parcel back out of the bucket it went into.
  for r in
    select ri.jan_code, ri.product_id, ri.product_name, ri.quantity, ri.lot_id,
           ri.serial_id, ri.bin_id, st.code as status_code
      from public.receipt_items ri
      left join public.stock_statuses st on st.id = ri.status_id
     where ri.reconciliation_id = p_recon_id and ri.quantity > 0
     order by ri.id
  loop
    perform public.apply_stock_movement_detail(
      v_warehouse, r.jan_code, -r.quantity, 'RECEIPT_CANCEL',
      'reconciliation', p_recon_id::text, r.product_name,
      r.bin_id, null, r.lot_id, r.serial_id, r.status_code, r.product_id);
  end loop;

  -- Rows from before 0067 carry no receipt item: reverse what the line
  -- counted beyond its parcels, as before.
  for r in
    select rl.jan_code as jan,
           (coalesce(rl.actual_quantity, 0)
            - coalesce((select sum(ri.quantity) from public.receipt_items ri
                         where ri.reconciliation_line_id = rl.id), 0))::int as qty
      from public.reconciliation_lines rl
     where rl.reconciliation_id = p_recon_id
  loop
    continue when r.qty <= 0;
    perform public.apply_stock_movement(
      v_warehouse, r.jan, -r.qty, 'RECEIPT_CANCEL',
      'reconciliation', p_recon_id::text);
  end loop;

  -- An inspection nobody closed goes with the receipt.
  select id into v_inspection from public.inspections
   where reconciliation_id = p_recon_id and status = 'PENDING';
  if v_inspection is not null then
    delete from public.inspections where id = v_inspection;
  end if;

  update public.delivery_reconciliations set status = 'cancelled' where id = p_recon_id;

  select coalesce(sum(coalesce(received_quantity, 0)), 0),
         coalesce(sum(greatest(
           coalesce(planned_quantity, 0) - coalesce(received_quantity, 0), 0)), 0)
    into v_received, v_outstanding
  from public.delivery_plan_lines where delivery_plan_id = v_plan;

  update public.delivery_plans
     set status = case
       when v_received = 0 then 'open'
       when v_outstanding = 0 then 'completed'
       else 'partial' end
   where id = v_plan;

  perform public.log_audit(
    'receiving.cancelled', 'reconciliation', p_recon_id::text, v_warehouse,
    jsonb_build_object('plan_id', v_plan, 'open_inspection_removed', v_inspection));

  return p_recon_id;
end;
$$;
