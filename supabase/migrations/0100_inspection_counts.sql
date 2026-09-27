-- 0100 — inspection is first of all a count: are these the right goods, and
-- is the number right. Condition is good unless someone says otherwise.
--
-- The user's rule for inspection: its main job is to confirm the goods and
-- their quantity match; the goods themselves are good by default. Until now
-- an inspection line was a pass/fail split the inspector typed, every line
-- had to be judged before the inspection could close, and nothing recorded
-- how many were actually counted — so "5 arrived, I counted 4" had nowhere to
-- go, and "this is not what we ordered" had no button.
--
--   * `inspection_items.counted_quantity` — what the inspector counted (null
--     until counted). `record_inspection_count(item, qty, mode)` sets it, or
--     adds to it one scan at a time ('add'), and — goods being good by
--     default — makes the line PASS with the counted goods passed, unless the
--     inspector has recorded failures or a hold on it.
--   * Settling a line (0099) checks the count against what arrived:
--       fewer counted  → the uncounted remainder goes to HOLD (it cannot be
--                        shipped if nobody can find it) and a 検品数の相違
--                        exception is raised to find out why;
--       more counted   → nothing extra enters the books (the receipt says what
--                        arrived), and the same exception asks for the extra to
--                        be received properly.
--   * 完了 no longer waits for every line to be judged: a line nobody touched
--     is good by default and passes in full.
--   * `report_inspection_wrong_item(inspection, jan, qty)` — a scanned product
--     that is not on this delivery is recorded as 誤品 for someone to deal
--     with, instead of just being refused.

alter table public.inspection_items add column if not exists counted_quantity integer
  check (counted_quantity is null or counted_quantity >= 0);

insert into public.exception_types
  (code, name, category, severity, requires_resolution, sort_order) values
  ('QC_COUNT_MISMATCH', '検品数の相違', 'QC', 'WARNING', true, 85),
  ('QC_WRONG_ITEM',     '誤品（注文と違う商品）', 'QC', 'BLOCKER', true, 86)
on conflict (code) do update
  set name = excluded.name, category = excluded.category,
      severity = excluded.severity,
      requires_resolution = excluded.requires_resolution,
      sort_order = excluded.sort_order;

-- ---------------------------------------------------------------------------
-- Counting
-- ---------------------------------------------------------------------------

create or replace function public.record_inspection_count(
  p_item_id bigint, p_quantity integer, p_mode text default 'set')
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  it       record;
  v_mode   text := lower(btrim(coalesce(p_mode, 'set')));
  v_count  integer;
  v_passed integer;
  v_result text;
begin
  if not public.has_permission('inspection.confirm') then
    raise exception 'not permitted: inspection.confirm required';
  end if;
  if v_mode not in ('set', 'add') then
    raise exception 'unknown count mode %', p_mode;
  end if;

  select i.id, i.counted_quantity, i.actual_quantity, i.failed_quantity, i.result,
         i.finalized_at, ins.id as inspection_id, ins.status as inspection_status,
         ins.warehouse_id
    into it
    from public.inspection_items i
    join public.inspections ins on ins.id = i.inspection_id
   where i.id = p_item_id
   for update of i;
  if it.id is null then
    raise exception 'inspection item % not found', p_item_id;
  end if;
  if not public.can_access_warehouse(it.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if it.inspection_status <> 'PENDING' or it.finalized_at is not null then
    raise exception 'inspection item % is already completed and can no longer change', p_item_id;
  end if;

  v_count := greatest(case v_mode
                        when 'add' then coalesce(it.counted_quantity, 0) + coalesce(p_quantity, 1)
                        else coalesce(p_quantity, 0) end, 0);

  -- Good by default: what was counted passes, less anything recorded as failed.
  v_passed := greatest(least(v_count, coalesce(it.actual_quantity, 0)) - coalesce(it.failed_quantity, 0), 0);
  v_result := case
    when it.result = 'HOLD' then 'HOLD'
    when coalesce(it.failed_quantity, 0) > 0 and v_passed > 0 then 'PARTIAL'
    when coalesce(it.failed_quantity, 0) > 0 then 'FAIL'
    else 'PASS'
  end;

  update public.inspection_items
     set counted_quantity = v_count,
         passed_quantity = v_passed,
         result = v_result
   where id = p_item_id;

  return jsonb_build_object(
    'item_id', p_item_id, 'counted', v_count, 'received', it.actual_quantity,
    'difference', v_count - coalesce(it.actual_quantity, 0), 'result', v_result);
end;
$$;

revoke all on function public.record_inspection_count(bigint, integer, text) from public, anon;
grant execute on function public.record_inspection_count(bigint, integer, text) to authenticated, service_role;

-- A product scanned during inspection that this delivery did not bring.
create or replace function public.report_inspection_wrong_item(
  p_inspection_id bigint, p_jan_code text, p_quantity integer default 1, p_note text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_warehouse bigint;
  v_recon     bigint;
  v_jan       text := nullif(btrim(coalesce(p_jan_code, '')), '');
  v_product   bigint;
  v_id        bigint;
begin
  if not public.has_permission('inspection.confirm') then
    raise exception 'not permitted: inspection.confirm required';
  end if;
  select warehouse_id, reconciliation_id into v_warehouse, v_recon
    from public.inspections where id = p_inspection_id;
  if v_warehouse is null then
    raise exception 'inspection % not found', p_inspection_id;
  end if;
  if not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_jan is null then
    raise exception 'jan_code is required';
  end if;
  select id into v_product from public.products where jan_code = v_jan;

  v_id := public.raise_exception_impl(
    'QC_WRONG_ITEM', v_warehouse,
    format('inspection:%s:wrong:%s', p_inspection_id, v_jan),
    v_recon, null, null, p_inspection_id, v_product, null, v_jan,
    greatest(coalesce(p_quantity, 1), 1),
    concat_ws(' / ', '検品で見つかった誤品', nullif(btrim(coalesce(p_note, '')), '')));

  perform public.log_audit('inspection.wrong_item', 'inspection', p_inspection_id::text,
    v_warehouse, jsonb_build_object('jan_code', v_jan, 'quantity', p_quantity));
  return jsonb_build_object('exception_id', v_id, 'jan_code', v_jan);
end;
$$;

revoke all on function public.report_inspection_wrong_item(bigint, text, integer, text) from public, anon;
grant execute on function public.report_inspection_wrong_item(bigint, text, integer, text)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Settling checks the count (0099's finalize, extended)
-- ---------------------------------------------------------------------------

create or replace function public.finalize_inspection_item_impl(
  p_item_id bigint, p_fail_code text default 'DAMAGED')
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  it          record;
  v_warehouse bigint;
  v_inspection bigint;
  v_recon     bigint;
  v_held      int;
  v_line_qc   int;
  v_want_ok   int;
  v_want_fail int;
  v_moved     int;
  v_to_ok     int := 0;
  v_to_fail   int := 0;
  v_unheld    int := 0;
  v_short     int := 0;
  v_rest      int;
  v_fail_code text := upper(btrim(coalesce(nullif(btrim(coalesce(p_fail_code, '')), ''), 'DAMAGED')));
begin
  select i.id, i.product_id, i.lot_id, i.serial_id, i.result, i.reconciliation_line_id,
         i.actual_quantity, i.passed_quantity, i.failed_quantity, i.finalized_at,
         i.counted_quantity, i.jan_code, i.inspection_id, ins.warehouse_id,
         ins.reconciliation_id
    into it
    from public.inspection_items i
    join public.inspections ins on ins.id = i.inspection_id
   where i.id = p_item_id
   for update of i;
  if it.id is null then
    raise exception 'inspection item % not found', p_item_id;
  end if;
  if it.finalized_at is not null then
    return jsonb_build_object('released_to_ok', 0, 'failed_quantity', 0,
                              'not_in_qc_pending', 0, 'count_short_held', 0);
  end if;
  if it.result = 'PENDING' then
    raise exception 'inspection item % has not been checked', p_item_id;
  end if;
  v_warehouse := it.warehouse_id;
  v_inspection := it.inspection_id;
  v_recon := it.reconciliation_id;

  if it.product_id is not null then
    v_want_ok := it.passed_quantity;
    v_want_fail := it.failed_quantity;
    if v_want_ok = 0 and v_want_fail = 0 then
      if it.result = 'PASS' then
        v_want_ok := coalesce(least(it.counted_quantity, it.actual_quantity), it.actual_quantity);
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
        v_held := v_held - v_moved;
        v_unheld := v_unheld + (v_want_fail - v_moved);
        if it.serial_id is not null and v_moved > 0 then
          update public.serial_numbers set status = 'HOLD', updated_at = now()
           where id = it.serial_id;
        end if;
      end if;

      -- Counted fewer than arrived: what nobody could count cannot ship.
      if it.counted_quantity is not null and it.counted_quantity < coalesce(it.actual_quantity, 0) then
        v_rest := least(v_held, it.actual_quantity - it.counted_quantity);
        if v_rest > 0 then
          v_short := public.move_stock_status_impl(
            it.product_id, v_warehouse, v_rest, 'HOLD', 'QC_PENDING',
            it.lot_id, it.serial_id,
            format('inspection %s: counted %s of %s', v_inspection,
                   it.counted_quantity, it.actual_quantity));
        end if;
      end if;
    end if;
  end if;

  if it.counted_quantity is not null and it.counted_quantity <> coalesce(it.actual_quantity, 0) then
    perform public.raise_exception_impl(
      'QC_COUNT_MISMATCH', v_warehouse,
      format('inspection:%s:item:%s:count', v_inspection, it.id),
      v_recon, it.reconciliation_line_id, null, v_inspection, it.product_id, it.lot_id,
      it.jan_code, abs(it.counted_quantity - coalesce(it.actual_quantity, 0)),
      format('検品数 %s / 入荷数 %s（%s）', it.counted_quantity, it.actual_quantity,
             case when it.counted_quantity < it.actual_quantity
                  then '不足分は保留に移動' else '超過分は在庫に計上されていません' end));
  end if;

  update public.inspection_items set finalized_at = now() where id = p_item_id;

  return jsonb_build_object('released_to_ok', v_to_ok, 'failed_quantity', v_to_fail,
                            'not_in_qc_pending', v_unheld, 'count_short_held', v_short);
end;
$$;

revoke all on function public.finalize_inspection_item_impl(bigint, text) from public, anon, authenticated;

-- 完了: a line nobody judged is good by default and passes in full (by its
-- count when it was counted).
do $$
declare v_src text;
begin
  select pg_get_functiondef('public.complete_inspection(bigint,text,text)'::regprocedure) into v_src;
  if position('good by default' in v_src) = 0 then
    v_src := replace(v_src,
      '  if v_pending > 0 then
    raise exception ''inspection % still has % unchecked item(s)'', p_inspection_id, v_pending;
  end if;',
      '  -- A line nobody judged is good by default (0100).
  update public.inspection_items
     set passed_quantity = coalesce(least(counted_quantity, actual_quantity), actual_quantity, 0),
         failed_quantity = 0,
         result = ''PASS''
   where inspection_id = p_inspection_id and finalized_at is null and result = ''PENDING'';');
    if position('good by default' in v_src) = 0 then
      raise exception 'complete_inspection did not have the expected shape';
    end if;
    execute v_src;
  end if;
end $$;

-- Reads carry the count.
do $$
declare v_src text;
begin
  select pg_get_functiondef('public.inspection_detail_impl(bigint)'::regprocedure) into v_src;
  if position('counted_quantity' in v_src) = 0 then
    v_src := replace(v_src, '''finalized_at'', it.finalized_at',
                            '''finalized_at'', it.finalized_at,
        ''counted_quantity'', it.counted_quantity');
    if position('counted_quantity' in v_src) = 0 then
      raise exception 'inspection_detail_impl did not have the expected shape';
    end if;
    execute v_src;
  end if;

  select pg_get_functiondef('public.open_inspection_lines(bigint)'::regprocedure) into v_src;
  if position('counted_quantity' in v_src) = 0 then
    v_src := replace(v_src, '''result'', it.result,',
                            '''result'', it.result,
      ''counted_quantity'', it.counted_quantity,');
    if position('counted_quantity' in v_src) = 0 then
      raise exception 'open_inspection_lines did not have the expected shape';
    end if;
    execute v_src;
  end if;
end $$;

-- Findings recorded line by line are a count too: they set the counted
-- quantity and leave what arrived alone. (Before, they overwrote the arrived
-- quantity, which would erase exactly the difference this migration checks.)
do $$
declare v_src text;
begin
  select pg_get_functiondef(
    'public.save_inspection_item(bigint,integer,integer,text,text,date,text,text,boolean,text,boolean)'::regprocedure)
    into v_src;
  if position('counted_quantity' in v_src) = 0 then
    v_src := replace(v_src, 'actual_quantity = v_passed + v_failed,',
                            'counted_quantity = nullif(v_passed + v_failed, 0),');
    if position('counted_quantity' in v_src) = 0 then
      raise exception 'save_inspection_item did not have the expected shape';
    end if;
    execute v_src;
  end if;
end $$;

-- 完了 reports what a short count sent to HOLD, apart from failures.
do $$
declare v_src text;
begin
  select pg_get_functiondef('public.complete_inspection(bigint,text,text)'::regprocedure) into v_src;
  if position('count_short_held' in v_src) = 0 then
    v_src := replace(v_src, '  v_unheld    int := 0;', '  v_unheld    int := 0;
  v_short     int := 0;');
    v_src := replace(v_src, '    v_unheld := v_unheld + (v_moved->>''not_in_qc_pending'')::int;',
      '    v_unheld := v_unheld + (v_moved->>''not_in_qc_pending'')::int;
    v_short := v_short + coalesce((v_moved->>''count_short_held'')::int, 0);');
    v_src := replace(v_src, '    ''not_in_qc_pending'', v_unheld);',
      '    ''not_in_qc_pending'', v_unheld,
    ''count_short_held'', v_short);');
    if (length(v_src) - length(replace(v_src, 'v_short', ''))) / length('v_short') < 3 then
      raise exception 'complete_inspection did not have the expected shape';
    end if;
    execute v_src;
  end if;
end $$;
