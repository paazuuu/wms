-- 0101 — the delivery note is the checklist; a box is ticked, not counted.
--
-- Goods arrive in cartons of hundreds. Counting piece by piece (0100's scan
-- per piece) is for small lines; for the rest the warehouse wants to:
--   * photograph the supplier's delivery note and have its lines — product and
--     quantity, in the supplier's own format — laid against the inspection, so
--     the note's figure is right there on every line;
--   * go box by box and tick a line when the goods are the right ones and the
--     quantity is about right, without counting every piece;
--   * stop halfway (four of six cartons today) and carry on tomorrow, adding
--     to the count as each carton is done.
--
--   * `inspection_items.note_quantity` / `note_product_name` — what the
--     delivery note says for the line (persisted, so tomorrow's shift sees it).
--   * `apply_delivery_note(inspection, lines)` — the OCR'd note lines
--     ({jan_code, product_code, product_name, quantity}) matched to the
--     inspection's lines: by JAN, then by the supplier's own code or name for
--     the product (supplier_product_names, 0087), then by product name.
--     Matched lines get the note's figure; what did not match is returned for
--     the screen to show (possibly a wrong item, possibly an unregistered code).
--   * `record_inspection_count` gains two modes:
--       'check' — ticked: counted = the note's figure, or what arrived when
--                 there is no note; good by default (0100);
--       'clear' — the tick or count taken back, the line unchecked again.
--     'add' (0100) is how a carton's worth is added to yesterday's count.

alter table public.inspection_items add column if not exists note_quantity integer
  check (note_quantity is null or note_quantity >= 0);
alter table public.inspection_items add column if not exists note_product_name text;

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
  if v_mode not in ('set', 'add', 'check', 'clear') then
    raise exception 'unknown count mode %', p_mode;
  end if;

  select i.id, i.counted_quantity, i.actual_quantity, i.failed_quantity, i.result,
         i.note_quantity, i.finalized_at, ins.id as inspection_id,
         ins.status as inspection_status, ins.warehouse_id
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

  if v_mode = 'clear' then
    update public.inspection_items
       set counted_quantity = null,
           passed_quantity = 0,
           result = case when result = 'HOLD' or coalesce(failed_quantity, 0) > 0
                         then result else 'PENDING' end
     where id = p_item_id;
    return jsonb_build_object('item_id', p_item_id, 'counted', null,
      'received', it.actual_quantity, 'difference', null, 'result',
      (select result from public.inspection_items where id = p_item_id));
  end if;

  v_count := greatest(case v_mode
                        when 'add' then coalesce(it.counted_quantity, 0) + coalesce(p_quantity, 1)
                        when 'check' then coalesce(it.note_quantity, it.actual_quantity, 0)
                        else coalesce(p_quantity, 0) end, 0);

  -- Good by default (0100): what was counted passes, less anything failed.
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

-- Normalizes a product name for matching: no spaces of either width, lower
-- case, full-width letters and digits folded to half-width.
create or replace function public.normalize_product_text(p text)
returns text
language sql immutable set search_path = '' as $$
  select lower(translate(regexp_replace(coalesce(p, ''), '[\s　・\-‐－]', '', 'g'),
    'ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ０１２３４５６７８９',
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'));
$$;

revoke all on function public.normalize_product_text(text) from public, anon;
grant execute on function public.normalize_product_text(text) to authenticated, service_role;

create or replace function public.apply_delivery_note(p_inspection_id bigint, p_lines jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_warehouse bigint;
  v_state     text;
  v_supplier  bigint;
  e           jsonb;
  v_idx       int := 0;
  v_jan       text;
  v_code      text;
  v_name      text;
  v_qty       int;
  v_item      bigint;
  v_by        text;
  v_matched   jsonb := '[]'::jsonb;
  v_unmatched jsonb := '[]'::jsonb;
  v_touched   bigint[] := array[]::bigint[];
begin
  if not public.has_permission('inspection.confirm') then
    raise exception 'not permitted: inspection.confirm required';
  end if;
  select ins.warehouse_id, ins.status, coalesce(p.supplier_id, po.supplier_id)
    into v_warehouse, v_state, v_supplier
    from public.inspections ins
    left join public.delivery_plans p on p.id = ins.delivery_plan_id
    left join public.purchase_orders po on po.id = p.purchase_order_id
   where ins.id = p_inspection_id;
  if v_warehouse is null then
    raise exception 'inspection % not found', p_inspection_id;
  end if;
  if not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_state <> 'PENDING' then
    raise exception 'inspection % is already completed', p_inspection_id;
  end if;
  if jsonb_typeof(p_lines) is distinct from 'array' then
    raise exception 'lines must be a list';
  end if;

  for e in select * from jsonb_array_elements(p_lines) loop
    v_idx := v_idx + 1;
    v_jan := nullif(regexp_replace(coalesce(e->>'jan_code', ''), '\D', '', 'g'), '');
    v_code := nullif(btrim(coalesce(e->>'product_code', '')), '');
    v_name := nullif(btrim(coalesce(e->>'product_name', '')), '');
    v_qty := nullif(regexp_replace(coalesce(e->>'quantity', ''), '\D', '', 'g'), '')::int;
    v_item := null;
    v_by := null;

    -- 1. The JAN, when the note prints one.
    if v_jan is not null then
      select it.id into v_item from public.inspection_items it
       where it.inspection_id = p_inspection_id and it.finalized_at is null
         and it.jan_code = v_jan
       order by it.id limit 1;
      if v_item is not null then v_by := 'jan'; end if;
    end if;

    -- 2. The supplier's own code or name for the product (0087).
    if v_item is null and v_supplier is not null and (v_code is not null or v_name is not null) then
      select it.id into v_item
        from public.inspection_items it
        join public.supplier_product_names s on s.product_id = it.product_id
       where it.inspection_id = p_inspection_id and it.finalized_at is null
         and s.supplier_id = v_supplier
         and ((v_code is not null and public.normalize_product_text(s.supplier_code)
                                      = public.normalize_product_text(v_code))
              or (v_name is not null and public.normalize_product_text(s.supplier_name)
                                         = public.normalize_product_text(v_name)))
       order by it.id limit 1;
      if v_item is not null then v_by := 'supplier_name'; end if;
    end if;

    -- 3. The product's own name.
    if v_item is null and v_name is not null then
      select it.id into v_item
        from public.inspection_items it
        left join public.products pr on pr.id = it.product_id
       where it.inspection_id = p_inspection_id and it.finalized_at is null
         and public.normalize_product_text(v_name) in (
               public.normalize_product_text(it.product_name),
               public.normalize_product_text(pr.name))
       order by it.id limit 1;
      if v_item is not null then v_by := 'name'; end if;
    end if;

    if v_item is not null then
      -- One photo replaces what an earlier read said for the lines it names
      -- (a retake), and adds up a product the note lists more than once. A
      -- second page names other lines, so it leaves the first page's alone.
      update public.inspection_items
         set note_quantity = case
               when v_qty is null then note_quantity
               when v_item = any(v_touched) then coalesce(note_quantity, 0) + v_qty
               else v_qty end,
             note_product_name = coalesce(v_name, note_product_name)
       where id = v_item;
      v_touched := v_touched || v_item;
      v_matched := v_matched || jsonb_build_object(
        'line', v_idx, 'item_id', v_item, 'matched_by', v_by,
        'jan_code', v_jan, 'product_code', v_code, 'product_name', v_name, 'quantity', v_qty);
    else
      v_unmatched := v_unmatched || jsonb_build_object(
        'line', v_idx, 'jan_code', v_jan, 'product_code', v_code,
        'product_name', v_name, 'quantity', v_qty);
    end if;
  end loop;

  perform public.log_audit('inspection.delivery_note_applied', 'inspection',
    p_inspection_id::text, v_warehouse,
    jsonb_build_object('matched', jsonb_array_length(v_matched),
                       'unmatched', jsonb_array_length(v_unmatched)));

  return jsonb_build_object('matched', v_matched, 'unmatched', v_unmatched);
end;
$$;

revoke all on function public.apply_delivery_note(bigint, jsonb) from public, anon;
grant execute on function public.apply_delivery_note(bigint, jsonb) to authenticated, service_role;

-- The detail read carries the note's figure.
do $$
declare v_src text;
begin
  select pg_get_functiondef('public.inspection_detail_impl(bigint)'::regprocedure) into v_src;
  if position('note_quantity' in v_src) = 0 then
    v_src := replace(v_src, '''counted_quantity'', it.counted_quantity',
                            '''counted_quantity'', it.counted_quantity,
        ''note_quantity'', it.note_quantity,
        ''note_product_name'', it.note_product_name');
    if position('note_quantity' in v_src) = 0 then
      raise exception 'inspection_detail_impl did not have the expected shape';
    end if;
    execute v_src;
  end if;
end $$;
