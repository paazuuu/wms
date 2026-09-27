-- 0095 — an inspection is closed once, and it only moves its own goods.
--
-- complete_inspection (0068) had no guard on the inspection's state. Closing
-- an inspection a second time ran the stock moves again, and because they
-- draw on the product's QC_PENDING pool in the warehouse, a second close — or
-- a first close that passed more than this receipt brought in — released or
-- failed goods that belonged to another receipt still waiting to be checked.
-- save_inspection_item likewise rewrote findings on a closed inspection, so
-- the record no longer matched what the stock moves had done.
--
--   * save_inspection_item refuses once the inspection is closed;
--   * complete_inspection refuses a closed inspection (status ≠ PENDING);
--   * each item moves at most what its own receipt line put into QC_PENDING
--     (the receipt's parcels on that line), so one inspection can never
--     release another receipt's stock. What it judged beyond that is reported
--     as `not_in_qc_pending`, as before.

create or replace function public.save_inspection_item(
  p_item_id bigint, p_passed integer, p_failed integer,
  p_lot text default null, p_serial text default null, p_expiry date default null,
  p_packaging_condition text default null, p_product_condition text default null,
  p_label_ok boolean default null, p_note text default null, p_hold boolean default false)
returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_passed integer := greatest(coalesce(p_passed, 0), 0);
  v_failed integer := greatest(coalesce(p_failed, 0), 0);
  v_result text;
  v_inspection bigint;
  v_state text;
begin
  select i.id, i.status into v_inspection, v_state
    from public.inspection_items it
    join public.inspections i on i.id = it.inspection_id
   where it.id = p_item_id;
  if v_inspection is null then
    raise exception 'inspection item % not found', p_item_id;
  end if;
  if v_state <> 'PENDING' then
    raise exception 'inspection % is already completed and can no longer change', v_inspection;
  end if;

  v_result := case
    when p_hold then 'HOLD'
    when v_passed = 0 and v_failed = 0 then 'PENDING'
    when v_failed = 0 then 'PASS'
    when v_passed = 0 then 'FAIL'
    else 'PARTIAL'
  end;

  update public.inspection_items
     set passed_quantity = v_passed,
         failed_quantity = v_failed,
         actual_quantity = v_passed + v_failed,
         lot = p_lot,
         serial = p_serial,
         expiry = p_expiry,
         packaging_condition = p_packaging_condition,
         product_condition = p_product_condition,
         label_ok = p_label_ok,
         note = p_note,
         result = v_result
   where id = p_item_id;

  return v_result;
end;
$$;

create or replace function public.complete_inspection(
  p_inspection_id bigint, p_note text default null, p_fail_status text default 'DAMAGED')
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_total     int;
  v_hold      int;
  v_pass      int;
  v_fail      int;
  v_pending   int;
  v_status    text;
  v_state     text;
  v_warehouse bigint;
  v_to_ok     int := 0;
  v_to_fail   int := 0;
  v_unheld    int := 0;
  v_held      int;
  v_line_qc   int;
  v_want_ok   int;
  v_want_fail int;
  v_moved     int;
  v_fail_code text := upper(btrim(coalesce(nullif(btrim(coalesce(p_fail_status, '')), ''), 'DAMAGED')));
  it          record;
begin
  -- Locked, so two people pressing 完了 at once cannot both run the moves.
  select warehouse_id, status into v_warehouse, v_state
    from public.inspections where id = p_inspection_id
   for update;
  if v_warehouse is null then
    raise exception 'inspection % not found', p_inspection_id;
  end if;
  if v_state <> 'PENDING' then
    raise exception 'inspection % is already completed', p_inspection_id;
  end if;

  select count(*),
         count(*) filter (where result = 'HOLD'),
         count(*) filter (where result = 'PASS'),
         count(*) filter (where result = 'FAIL'),
         count(*) filter (where result = 'PENDING')
    into v_total, v_hold, v_pass, v_fail, v_pending
  from public.inspection_items
  where inspection_id = p_inspection_id;

  if v_total = 0 then
    raise exception 'inspection % has no items', p_inspection_id;
  end if;
  if v_pending > 0 then
    raise exception 'inspection % still has % unchecked item(s)', p_inspection_id, v_pending;
  end if;

  v_status := case
    when v_hold > 0 then 'HOLD'
    when v_pass = v_total then 'PASS'
    when v_fail = v_total then 'FAIL'
    else 'PARTIAL'
  end;

  for it in
    select i.id, i.product_id, i.lot_id, i.serial_id, i.result, i.reconciliation_line_id,
           i.actual_quantity, i.passed_quantity, i.failed_quantity
      from public.inspection_items i
     where i.inspection_id = p_inspection_id
       and i.product_id is not null
     order by i.id
  loop
    v_want_ok := it.passed_quantity;
    v_want_fail := it.failed_quantity;
    if v_want_ok = 0 and v_want_fail = 0 then
      if it.result = 'PASS' then
        v_want_ok := it.actual_quantity;
      elsif it.result in ('FAIL', 'HOLD') then
        v_want_fail := it.actual_quantity;
      end if;
    end if;

    select coalesce(sum(su.quantity), 0)::int into v_held
      from public.stock_units su
      join public.stock_statuses st on st.id = su.status_id
     where su.product_id = it.product_id
       and su.warehouse_id = v_warehouse
       and st.code = 'QC_PENDING'
       and (it.lot_id is null or su.lot_id = it.lot_id)
       and (it.serial_id is null or su.serial_id = it.serial_id);

    -- No more than this receipt line put into inspection.
    if it.reconciliation_line_id is not null then
      select coalesce(sum(ri.quantity), 0)::int into v_line_qc
        from public.receipt_items ri
        join public.stock_statuses st on st.id = ri.status_id
       where ri.reconciliation_line_id = it.reconciliation_line_id
         and st.code = 'QC_PENDING';
      v_held := least(v_held, v_line_qc);
    end if;

    if v_held = 0 then
      v_unheld := v_unheld + v_want_ok + v_want_fail;
      continue;
    end if;

    if v_want_ok > 0 then
      v_moved := public.move_stock_status_impl(
        it.product_id, v_warehouse, least(v_want_ok, v_held), 'OK', 'QC_PENDING',
        it.lot_id, it.serial_id,
        format('inspection %s passed', p_inspection_id));
      v_to_ok := v_to_ok + v_moved;
      v_held := v_held - v_moved;
      v_unheld := v_unheld + (v_want_ok - v_moved);
    end if;

    if v_want_fail > 0 then
      v_moved := public.move_stock_status_impl(
        it.product_id, v_warehouse, least(v_want_fail, v_held),
        case when it.result = 'HOLD' then 'HOLD' else v_fail_code end,
        'QC_PENDING', it.lot_id, it.serial_id,
        format('inspection %s failed', p_inspection_id));
      v_to_fail := v_to_fail + v_moved;
      v_unheld := v_unheld + (v_want_fail - v_moved);

      if it.serial_id is not null and v_moved > 0 then
        update public.serial_numbers set status = 'HOLD', updated_at = now()
         where id = it.serial_id;
      end if;
    end if;
  end loop;

  update public.inspections
     set status = v_status,
         note = coalesce(p_note, note),
         inspector_user_id = coalesce(inspector_user_id, auth.uid()),
         completed_at = now()
   where id = p_inspection_id;

  perform public.detect_qc_exceptions(p_inspection_id, v_fail_code);

  perform public.log_audit(
    'inspection.confirmed', 'inspection', p_inspection_id::text, v_warehouse,
    jsonb_build_object('status', v_status, 'items', v_total,
                       'released_to_ok', v_to_ok,
                       'held_as', v_fail_code, 'held_quantity', v_to_fail,
                       'not_in_qc_pending', v_unheld));

  return jsonb_build_object(
    'inspection_id', p_inspection_id,
    'status', v_status,
    'items', v_total,
    'released_to_ok', v_to_ok,
    'failed_to', v_fail_code,
    'failed_quantity', v_to_fail,
    'not_in_qc_pending', v_unheld);
end;
$$;

-- Both stay behind the inspections edge function (service role only).
revoke all on function public.save_inspection_item(
  bigint, integer, integer, text, text, date, text, text, boolean, text, boolean)
  from public, anon, authenticated;
revoke all on function public.complete_inspection(bigint, text, text)
  from public, anon, authenticated;
grant execute on function public.save_inspection_item(
  bigint, integer, integer, text, text, date, text, text, boolean, text, boolean) to service_role;
grant execute on function public.complete_inspection(bigint, text, text) to service_role;
