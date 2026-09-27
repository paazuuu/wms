-- 0099 — inspect in bulk: by arrival date, by purchase order, by product, and
-- part of an inspection at a time.
--
-- Checking every line on a phone is still possible, but most deliveries are
-- fine, and the warehouse wants to say so in one go: "everything that arrived
-- on the 3rd is good", "everything from PO-000123 is good", "all of this
-- product is good" — while leaving the few lines someone still wants to look
-- at open. Until now an inspection was all-or-nothing: nothing moved to
-- shippable stock until every line was judged and the whole inspection closed.
--
--   * Receipts carry an arrival date (`arrived_on`), today in the warehouse's
--     time zone unless set by hand; it can be corrected later.
--   * An inspection line can be *finalized* on its own (`finalized_at`): its
--     goods move out of QC_PENDING at once and the line is locked. The
--     inspection closes itself when its last line is finalized, and 完了 on a
--     part-finalized inspection finalizes only what is left.
--   * `pass_inspection_items(ids)` passes the chosen lines in full and
--     finalizes them — the bulk "良品で検品完了", for one line or hundreds.
--   * `open_inspection_lines(warehouse)` lists every line still to be
--     inspected with what the bulk screen groups by: arrival date, receipt,
--     supplier, purchase order, product.

-- ---------------------------------------------------------------------------
-- Arrival date
-- ---------------------------------------------------------------------------

alter table public.delivery_reconciliations add column if not exists arrived_on date;

update public.delivery_reconciliations r
   set arrived_on = (r.created_at at time zone coalesce(
         (select w.timezone from public.delivery_plans p
            join public.warehouses w on w.id = p.warehouse_id
           where p.id = r.delivery_plan_id), 'Asia/Tokyo'))::date
 where r.arrived_on is null;

create or replace function public.receipt_arrived_on_default()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.arrived_on is null then
    new.arrived_on := public.warehouse_today(coalesce(
      (select p.warehouse_id from public.delivery_plans p where p.id = new.delivery_plan_id),
      public.default_warehouse_id()));
  end if;
  return new;
end;
$$;

revoke all on function public.receipt_arrived_on_default() from public, anon, authenticated;

drop trigger if exists delivery_reconciliations_arrived_on on public.delivery_reconciliations;
create trigger delivery_reconciliations_arrived_on
  before insert on public.delivery_reconciliations
  for each row execute function public.receipt_arrived_on_default();

alter table public.delivery_reconciliations alter column arrived_on set not null;

create or replace function public.set_receipt_arrived_on(
  p_reconciliation_id bigint, p_arrived_on date)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_warehouse bigint;
  v_state     text;
  v_before    date;
begin
  if not public.has_permission('receiving.confirm') then
    raise exception 'not permitted: receiving.confirm required';
  end if;
  select coalesce(p.warehouse_id, public.default_warehouse_id()), r.status, r.arrived_on
    into v_warehouse, v_state, v_before
    from public.delivery_reconciliations r
    join public.delivery_plans p on p.id = r.delivery_plan_id
   where r.id = p_reconciliation_id;
  if v_warehouse is null then
    raise exception 'receipt % not found', p_reconciliation_id;
  end if;
  if not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_state = 'cancelled' then
    raise exception 'receipt % is cancelled', p_reconciliation_id;
  end if;
  if p_arrived_on is null then
    raise exception 'an arrival date is required';
  end if;
  if p_arrived_on > public.warehouse_today(v_warehouse) then
    raise exception 'the arrival date % is in the future', p_arrived_on;
  end if;

  update public.delivery_reconciliations set arrived_on = p_arrived_on
   where id = p_reconciliation_id;
  perform public.log_audit('receiving.arrival_date_set', 'reconciliation',
    p_reconciliation_id::text, v_warehouse,
    jsonb_build_object('from', v_before, 'to', p_arrived_on));
  return jsonb_build_object('reconciliation_id', p_reconciliation_id, 'arrived_on', p_arrived_on);
end;
$$;

revoke all on function public.set_receipt_arrived_on(bigint, date) from public, anon;
grant execute on function public.set_receipt_arrived_on(bigint, date) to authenticated, service_role;

-- The receipt detail read carries it.
do $$
declare v_src text;
begin
  select pg_get_functiondef('public.receipt_detail_impl(bigint)'::regprocedure) into v_src;
  if position('''arrived_on''' in v_src) = 0 then
    v_src := replace(v_src, '''created_at'', r.created_at,',
                            '''created_at'', r.created_at,
    ''arrived_on'', r.arrived_on,');
    if position('''arrived_on''' in v_src) = 0 then
      raise exception 'receipt_detail_impl did not have the expected shape';
    end if;
    execute v_src;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- A line finalized on its own
-- ---------------------------------------------------------------------------

alter table public.inspection_items add column if not exists finalized_at timestamptz;

-- Lines of inspections closed before this migration are final.
update public.inspection_items it set finalized_at = i.completed_at
  from public.inspections i
 where i.id = it.inspection_id and i.status <> 'PENDING' and it.finalized_at is null;

-- The stock moves for one judged line, then the lock. Returns what moved.
create or replace function public.finalize_inspection_item_impl(
  p_item_id bigint, p_fail_code text default 'DAMAGED')
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  it          record;
  v_warehouse bigint;
  v_inspection bigint;
  v_held      int;
  v_line_qc   int;
  v_want_ok   int;
  v_want_fail int;
  v_moved     int;
  v_to_ok     int := 0;
  v_to_fail   int := 0;
  v_unheld    int := 0;
  v_fail_code text := upper(btrim(coalesce(nullif(btrim(coalesce(p_fail_code, '')), ''), 'DAMAGED')));
begin
  select i.id, i.product_id, i.lot_id, i.serial_id, i.result, i.reconciliation_line_id,
         i.actual_quantity, i.passed_quantity, i.failed_quantity, i.finalized_at,
         i.inspection_id, ins.warehouse_id
    into it
    from public.inspection_items i
    join public.inspections ins on ins.id = i.inspection_id
   where i.id = p_item_id
   for update of i;
  if it.id is null then
    raise exception 'inspection item % not found', p_item_id;
  end if;
  if it.finalized_at is not null then
    return jsonb_build_object('released_to_ok', 0, 'failed_quantity', 0, 'not_in_qc_pending', 0);
  end if;
  if it.result = 'PENDING' then
    raise exception 'inspection item % has not been checked', p_item_id;
  end if;
  v_warehouse := it.warehouse_id;
  v_inspection := it.inspection_id;

  if it.product_id is not null then
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

    -- No more than this receipt line put into inspection (0095).
    if it.reconciliation_line_id is not null then
      select coalesce(sum(ri.quantity), 0)::int into v_line_qc
        from public.receipt_items ri
        join public.stock_statuses st on st.id = ri.status_id
       where ri.reconciliation_line_id = it.reconciliation_line_id
         and st.code = 'QC_PENDING';
      v_held := least(v_held, v_line_qc);
    end if;

    if v_held = 0 then
      v_unheld := v_want_ok + v_want_fail;
    else
      if v_want_ok > 0 then
        v_moved := public.move_stock_status_impl(
          it.product_id, v_warehouse, least(v_want_ok, v_held), 'OK', 'QC_PENDING',
          it.lot_id, it.serial_id, format('inspection %s passed', v_inspection));
        v_to_ok := v_moved;
        v_held := v_held - v_moved;
        v_unheld := v_unheld + (v_want_ok - v_moved);
      end if;
      if v_want_fail > 0 then
        v_moved := public.move_stock_status_impl(
          it.product_id, v_warehouse, least(v_want_fail, v_held),
          case when it.result = 'HOLD' then 'HOLD' else v_fail_code end,
          'QC_PENDING', it.lot_id, it.serial_id, format('inspection %s failed', v_inspection));
        v_to_fail := v_moved;
        v_unheld := v_unheld + (v_want_fail - v_moved);
        if it.serial_id is not null and v_moved > 0 then
          update public.serial_numbers set status = 'HOLD', updated_at = now()
           where id = it.serial_id;
        end if;
      end if;
    end if;
  end if;

  update public.inspection_items set finalized_at = now() where id = p_item_id;

  return jsonb_build_object('released_to_ok', v_to_ok, 'failed_quantity', v_to_fail,
                            'not_in_qc_pending', v_unheld);
end;
$$;

revoke all on function public.finalize_inspection_item_impl(bigint, text) from public, anon, authenticated;

-- Closes an inspection whose every line is final. Returns the new status, or
-- null while lines remain.
create or replace function public.close_inspection_if_final_impl(
  p_inspection_id bigint, p_note text default null, p_fail_code text default 'DAMAGED')
returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_total int; v_hold int; v_pass int; v_fail int; v_open int;
  v_status text;
  v_warehouse bigint;
begin
  select count(*),
         count(*) filter (where result = 'HOLD'),
         count(*) filter (where result = 'PASS'),
         count(*) filter (where result = 'FAIL'),
         count(*) filter (where finalized_at is null)
    into v_total, v_hold, v_pass, v_fail, v_open
    from public.inspection_items where inspection_id = p_inspection_id;
  if v_total = 0 or v_open > 0 then
    return null;
  end if;

  v_status := case
    when v_hold > 0 then 'HOLD'
    when v_pass = v_total then 'PASS'
    when v_fail = v_total then 'FAIL'
    else 'PARTIAL'
  end;

  update public.inspections
     set status = v_status,
         note = coalesce(p_note, note),
         inspector_user_id = coalesce(inspector_user_id, auth.uid()),
         completed_at = now()
   where id = p_inspection_id and status = 'PENDING'
   returning warehouse_id into v_warehouse;
  if v_warehouse is null then
    return null;
  end if;

  perform public.detect_qc_exceptions(p_inspection_id,
    upper(btrim(coalesce(nullif(btrim(coalesce(p_fail_code, '')), ''), 'DAMAGED'))));
  return v_status;
end;
$$;

revoke all on function public.close_inspection_if_final_impl(bigint, text, text) from public, anon, authenticated;

-- 完了: finalize what is left, then close. Same contract as 0095.
create or replace function public.complete_inspection(
  p_inspection_id bigint, p_note text default null, p_fail_status text default 'DAMAGED')
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_state     text;
  v_warehouse bigint;
  v_total     int;
  v_pending   int;
  v_status    text;
  v_to_ok     int := 0;
  v_to_fail   int := 0;
  v_unheld    int := 0;
  v_fail_code text := upper(btrim(coalesce(nullif(btrim(coalesce(p_fail_status, '')), ''), 'DAMAGED')));
  v_moved     jsonb;
  r           record;
begin
  select warehouse_id, status into v_warehouse, v_state
    from public.inspections where id = p_inspection_id
   for update;
  if v_warehouse is null then
    raise exception 'inspection % not found', p_inspection_id;
  end if;
  if v_state <> 'PENDING' then
    raise exception 'inspection % is already completed', p_inspection_id;
  end if;

  select count(*), count(*) filter (where result = 'PENDING' and finalized_at is null)
    into v_total, v_pending
    from public.inspection_items where inspection_id = p_inspection_id;
  if v_total = 0 then
    raise exception 'inspection % has no items', p_inspection_id;
  end if;
  if v_pending > 0 then
    raise exception 'inspection % still has % unchecked item(s)', p_inspection_id, v_pending;
  end if;

  for r in
    select id from public.inspection_items
     where inspection_id = p_inspection_id and finalized_at is null
     order by id
  loop
    v_moved := public.finalize_inspection_item_impl(r.id, v_fail_code);
    v_to_ok := v_to_ok + (v_moved->>'released_to_ok')::int;
    v_to_fail := v_to_fail + (v_moved->>'failed_quantity')::int;
    v_unheld := v_unheld + (v_moved->>'not_in_qc_pending')::int;
  end loop;

  v_status := public.close_inspection_if_final_impl(p_inspection_id, p_note, v_fail_code);

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

revoke all on function public.complete_inspection(bigint, text, text) from public, anon, authenticated;
grant execute on function public.complete_inspection(bigint, text, text) to service_role;

-- A finalized line is locked like a closed inspection (0095).
do $$
declare v_src text;
begin
  select pg_get_functiondef(
    'public.save_inspection_item(bigint,integer,integer,text,text,date,text,text,boolean,text,boolean)'::regprocedure)
    into v_src;
  if position('finalized_at' in v_src) = 0 then
    v_src := replace(v_src,
      '  select i.id, i.status into v_inspection, v_state
    from public.inspection_items it',
      '  if exists (select 1 from public.inspection_items
              where id = p_item_id and finalized_at is not null) then
    raise exception ''inspection item % is already completed and can no longer change'', p_item_id;
  end if;

  select i.id, i.status into v_inspection, v_state
    from public.inspection_items it');
    if position('finalized_at' in v_src) = 0 then
      raise exception 'save_inspection_item did not have the expected shape';
    end if;
    execute v_src;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Bulk pass
-- ---------------------------------------------------------------------------

create or replace function public.pass_inspection_items(
  p_item_ids bigint[], p_note text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r          record;
  v_moved    jsonb;
  v_items    int := 0;
  v_to_ok    int := 0;
  v_unheld   int := 0;
  v_closed   int := 0;
  v_status   text;
  v_touched  bigint[] := array[]::bigint[];
  v_id       bigint;
begin
  if not public.has_permission('inspection.confirm') then
    raise exception 'not permitted: inspection.confirm required';
  end if;
  if coalesce(array_length(p_item_ids, 1), 0) = 0 then
    raise exception 'no inspection lines were chosen';
  end if;

  for r in
    select it.id, it.inspection_id, it.actual_quantity, it.finalized_at,
           ins.status as inspection_status, ins.warehouse_id
      from public.inspection_items it
      join public.inspections ins on ins.id = it.inspection_id
     where it.id = any(p_item_ids)
     order by it.inspection_id, it.id
  loop
    if not public.can_access_warehouse(r.warehouse_id) then
      raise exception 'not permitted: warehouse.scope required';
    end if;
    continue when r.finalized_at is not null or r.inspection_status <> 'PENDING';

    update public.inspection_items
       set passed_quantity = coalesce(actual_quantity, 0),
           failed_quantity = 0,
           result = 'PASS',
           note = coalesce(nullif(btrim(coalesce(p_note, '')), ''), note)
     where id = r.id;
    v_moved := public.finalize_inspection_item_impl(r.id);
    v_items := v_items + 1;
    v_to_ok := v_to_ok + (v_moved->>'released_to_ok')::int;
    v_unheld := v_unheld + (v_moved->>'not_in_qc_pending')::int;
    if not r.inspection_id = any(v_touched) then
      v_touched := v_touched || r.inspection_id;
    end if;
  end loop;

  foreach v_id in array v_touched loop
    v_status := public.close_inspection_if_final_impl(v_id);
    if v_status is not null then
      v_closed := v_closed + 1;
    end if;
    perform public.log_audit('inspection.bulk_passed', 'inspection', v_id::text,
      (select warehouse_id from public.inspections where id = v_id),
      jsonb_build_object('closed', v_status is not null, 'note', p_note));
  end loop;

  return jsonb_build_object('items', v_items, 'released_to_ok', v_to_ok,
                            'not_in_qc_pending', v_unheld,
                            'inspections', coalesce(array_length(v_touched, 1), 0),
                            'closed_inspections', v_closed);
end;
$$;

revoke all on function public.pass_inspection_items(bigint[], text) from public, anon;
grant execute on function public.pass_inspection_items(bigint[], text) to authenticated, service_role;

-- Every line still to inspect, with what the bulk screen groups by.
create or replace function public.open_inspection_lines(p_warehouse_id bigint default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('inspection.view') or public.has_permission('inspection.confirm')) then
    raise exception 'not permitted: inspection.view required';
  end if;
  if p_warehouse_id is not null and not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'item_id', it.id,
      'inspection_id', ins.id,
      'reconciliation_id', r.id,
      'reference_no', r.reference_no,
      'arrived_on', r.arrived_on,
      'delivery_plan_id', p.id,
      'delivery_number', p.delivery_number,
      'supplier_name', coalesce(po.supplier_name, p.supplier_name),
      'purchase_order_id', po.id,
      'po_number', po.po_number,
      'warehouse_id', ins.warehouse_id,
      'jan_code', it.jan_code,
      'product_id', it.product_id,
      'product_name', coalesce(pr.name, it.product_name),
      'quantity', it.actual_quantity,
      'expected_quantity', it.expected_quantity,
      'result', it.result,
      'lot', coalesce((select l.lot_code from public.lots l where l.id = it.lot_id), it.lot)
    ) order by r.arrived_on desc, r.id desc, it.id)
      from public.inspection_items it
      join public.inspections ins on ins.id = it.inspection_id
      join public.delivery_reconciliations r on r.id = ins.reconciliation_id
      join public.delivery_plans p on p.id = r.delivery_plan_id
      left join public.purchase_orders po on po.id = p.purchase_order_id
      left join public.products pr on pr.id = it.product_id
     where ins.status = 'PENDING'
       and it.finalized_at is null
       and (p_warehouse_id is null or ins.warehouse_id = p_warehouse_id)
       and public.can_access_warehouse(ins.warehouse_id)), '[]'::jsonb);
end;
$$;

revoke all on function public.open_inspection_lines(bigint) from public, anon;
grant execute on function public.open_inspection_lines(bigint) to authenticated, service_role;

-- The inspection detail says which lines are final and when the goods arrived.
do $$
declare v_src text;
begin
  select pg_get_functiondef('public.inspection_detail_impl(bigint)'::regprocedure) into v_src;
  if position('finalized_at' in v_src) = 0 then
    v_src := replace(v_src, '''note'', it.note
      ) order by it.id)',
      '''note'', it.note,
        ''finalized_at'', it.finalized_at
      ) order by it.id)');
    v_src := replace(v_src, '''completed_at'', i.completed_at,',
      '''completed_at'', i.completed_at,
    ''arrived_on'', (select r.arrived_on from public.delivery_reconciliations r
                     where r.id = i.reconciliation_id),');
    if position('finalized_at' in v_src) = 0 or position('arrived_on' in v_src) = 0 then
      raise exception 'inspection_detail_impl did not have the expected shape';
    end if;
    execute v_src;
  end if;
end $$;
