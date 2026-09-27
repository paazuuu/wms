-- 0104 — each warehouse says how what comes from a supplier is inspected.
--
-- Until now inspection was asked for product by product and nothing was
-- inspected unless someone had flagged it. The warehouse decides instead:
--
--   * `warehouses.inspection_mode`
--       'FULL'   (default, and what a new warehouse gets) — everything that
--                arrives from a supplier waits for inspection;
--       'SAMPLE' — it still waits, but each line is checked on a sample
--                (`sample_percent` of the pieces, at least `sample_min`) and
--                the whole line is accepted once its sample is done;
--       'NONE'   — receive only: the warehouse inspects its own way, outside
--                this system, and goods go straight to usable stock.
--   * A product can still be an exception in one warehouse
--     (`warehouse_products.requires_inspection`, set_inspection_requirement);
--     the product-wide flag no longer decides anything.
--   * An inspection records how it was run (`inspections.method`, with the
--     sample rate of the day), and each line its `sample_quantity`.
--   * `record_inspection_count(item, n, 'sample')` — n more pieces of the
--     sample checked (a scan is 1); when the sample is complete the line is
--     accepted as the delivery note (or the receipt) says.
--   * `set_warehouse_inspection(warehouse, mode, percent, min)`.

alter table public.warehouses add column if not exists inspection_mode text not null default 'FULL';
alter table public.warehouses drop constraint if exists warehouses_inspection_mode_check;
alter table public.warehouses add constraint warehouses_inspection_mode_check
  check (inspection_mode in ('FULL', 'SAMPLE', 'NONE'));
alter table public.warehouses add column if not exists sample_percent integer not null default 10;
alter table public.warehouses drop constraint if exists warehouses_sample_percent_check;
alter table public.warehouses add constraint warehouses_sample_percent_check
  check (sample_percent between 1 and 100);
alter table public.warehouses add column if not exists sample_min integer not null default 1;
alter table public.warehouses drop constraint if exists warehouses_sample_min_check;
alter table public.warehouses add constraint warehouses_sample_min_check check (sample_min >= 1);

alter table public.inspections add column if not exists method text not null default 'FULL';
alter table public.inspections drop constraint if exists inspections_method_check;
alter table public.inspections add constraint inspections_method_check
  check (method in ('FULL', 'SAMPLE'));
alter table public.inspections add column if not exists sample_percent integer;
alter table public.inspections add column if not exists sample_min integer;

alter table public.inspection_items add column if not exists sample_quantity integer;
alter table public.inspection_items add column if not exists sampled_quantity integer;

-- ---------------------------------------------------------------------------
-- Whether goods from a supplier wait for inspection
-- ---------------------------------------------------------------------------

create or replace function public.receiving_status_for(p_product_id bigint, p_warehouse_id bigint)
returns text
language sql stable security definer set search_path = '' as $$
  select case
    when wp.requires_inspection is not null then
      case when wp.requires_inspection then 'QC_PENDING' else 'OK' end
    when coalesce(w.inspection_mode, 'FULL') = 'NONE' then 'OK'
    else 'QC_PENDING'
  end
  from (select 1) one
  left join public.warehouses w on w.id = p_warehouse_id
  left join public.warehouse_products wp
    on wp.product_id = p_product_id and wp.warehouse_id = p_warehouse_id;
$$;

-- ---------------------------------------------------------------------------
-- Sampling
-- ---------------------------------------------------------------------------

create or replace function public.inspection_takes_method()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare w record;
begin
  select inspection_mode, sample_percent, sample_min into w
    from public.warehouses where id = new.warehouse_id;
  if w.inspection_mode = 'SAMPLE' then
    new.method := 'SAMPLE';
    new.sample_percent := w.sample_percent;
    new.sample_min := w.sample_min;
  end if;
  return new;
end;
$$;

revoke all on function public.inspection_takes_method() from public, anon, authenticated;

drop trigger if exists inspections_take_method on public.inspections;
create trigger inspections_take_method
  before insert on public.inspections
  for each row execute function public.inspection_takes_method();

create or replace function public.inspection_item_sample_size()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare ins record;
begin
  select method, sample_percent, sample_min into ins
    from public.inspections where id = new.inspection_id;
  if ins.method = 'SAMPLE' then
    new.sample_quantity := least(coalesce(new.actual_quantity, 0),
      greatest(coalesce(ins.sample_min, 1),
               ceil(coalesce(new.actual_quantity, 0) * coalesce(ins.sample_percent, 10) / 100.0)::int));
  end if;
  return new;
end;
$$;

revoke all on function public.inspection_item_sample_size() from public, anon, authenticated;

drop trigger if exists inspection_items_b_sample_size on public.inspection_items;
create trigger inspection_items_b_sample_size
  before insert or update of actual_quantity on public.inspection_items
  for each row execute function public.inspection_item_sample_size();

create or replace function public.record_inspection_count(
  p_item_id bigint, p_quantity integer, p_mode text default 'set')
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  it        record;
  v_mode    text := lower(btrim(coalesce(p_mode, 'set')));
  v_count   integer;
  v_passed  integer;
  v_result  text;
  v_sampled integer;
begin
  if not public.has_permission('inspection.confirm') then
    raise exception 'not permitted: inspection.confirm required';
  end if;
  if v_mode not in ('set', 'add', 'check', 'clear', 'sample') then
    raise exception 'unknown count mode %', p_mode;
  end if;

  select i.id, i.counted_quantity, i.actual_quantity, i.failed_quantity, i.result,
         i.note_quantity, i.finalized_at, i.sample_quantity, i.sampled_quantity,
         ins.id as inspection_id, ins.status as inspection_status, ins.warehouse_id,
         ins.method
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
           sampled_quantity = null,
           passed_quantity = 0,
           result = case when result = 'HOLD' or coalesce(failed_quantity, 0) > 0
                         then result else 'PENDING' end
     where id = p_item_id;
    return jsonb_build_object('item_id', p_item_id, 'counted', null, 'sampled', null,
      'received', it.actual_quantity, 'difference', null, 'result',
      (select result from public.inspection_items where id = p_item_id));
  end if;

  if v_mode = 'sample' then
    if it.method <> 'SAMPLE' then
      raise exception 'inspection % is not a sampling inspection', it.inspection_id;
    end if;
    v_sampled := greatest(coalesce(it.sampled_quantity, 0) + coalesce(p_quantity, 1), 0);
    update public.inspection_items set sampled_quantity = v_sampled where id = p_item_id;
    if v_sampled < coalesce(it.sample_quantity, 1) or it.counted_quantity is not null then
      return jsonb_build_object('item_id', p_item_id, 'sampled', v_sampled,
        'sample', it.sample_quantity, 'counted', it.counted_quantity,
        'received', it.actual_quantity, 'result', it.result);
    end if;
    -- The sample is done: the line is accepted as the note, or the receipt, says.
    v_mode := 'check';
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
    'sampled', coalesce(v_sampled, it.sampled_quantity), 'sample', it.sample_quantity,
    'difference', v_count - coalesce(it.actual_quantity, 0), 'result', v_result);
end;
$$;

revoke all on function public.record_inspection_count(bigint, integer, text) from public, anon;
grant execute on function public.record_inspection_count(bigint, integer, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Setting it, and reading it back
-- ---------------------------------------------------------------------------

create or replace function public.set_warehouse_inspection(
  p_warehouse_id bigint, p_mode text,
  p_sample_percent integer default null, p_sample_min integer default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_mode text := upper(btrim(coalesce(p_mode, '')));
  v_before record;
  v_after record;
begin
  if not public.has_permission('warehouse.manage') then
    raise exception 'not permitted: warehouse.manage required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_mode not in ('FULL', 'SAMPLE', 'NONE') then
    raise exception 'inspection mode must be FULL, SAMPLE or NONE';
  end if;
  if p_sample_percent is not null and (p_sample_percent < 1 or p_sample_percent > 100) then
    raise exception 'sample percent must be between 1 and 100';
  end if;
  if p_sample_min is not null and p_sample_min < 1 then
    raise exception 'sample minimum must be at least 1';
  end if;

  select inspection_mode, sample_percent, sample_min into v_before
    from public.warehouses where id = p_warehouse_id;
  if not found then
    raise exception 'warehouse % not found', p_warehouse_id;
  end if;

  update public.warehouses
     set inspection_mode = v_mode,
         sample_percent = coalesce(p_sample_percent, sample_percent),
         sample_min = coalesce(p_sample_min, sample_min),
         updated_at = now()
   where id = p_warehouse_id
   returning inspection_mode, sample_percent, sample_min into v_after;

  perform public.log_audit('warehouse.inspection_mode', 'warehouse', p_warehouse_id::text,
    p_warehouse_id, jsonb_build_object(
      'before', to_jsonb(v_before), 'after', to_jsonb(v_after)));

  return jsonb_build_object('warehouse_id', p_warehouse_id,
    'inspection_mode', v_after.inspection_mode,
    'sample_percent', v_after.sample_percent, 'sample_min', v_after.sample_min);
end;
$$;

revoke all on function public.set_warehouse_inspection(bigint, text, integer, integer) from public, anon;
grant execute on function public.set_warehouse_inspection(bigint, text, integer, integer)
  to authenticated, service_role;

do $$
declare v_src text;
begin
  select pg_get_functiondef('public.warehouse_roles()'::regprocedure) into v_src;
  if position('inspection_mode' in v_src) = 0 then
    v_src := replace(v_src,
'             ''receives_cross_border'', w.receives_cross_border)',
'             ''receives_cross_border'', w.receives_cross_border,
             ''inspection_mode'', w.inspection_mode,
             ''sample_percent'', w.sample_percent,
             ''sample_min'', w.sample_min)');
    if position('inspection_mode' in v_src) = 0 then
      raise exception 'warehouse_roles did not have the expected shape';
    end if;
    execute v_src;
  end if;

  select pg_get_functiondef('public.inspection_detail_impl(bigint)'::regprocedure) into v_src;
  if position('sample_quantity' in v_src) = 0 then
    v_src := replace(v_src,
'    ''arrived_on'', (select r.arrived_on',
'    ''method'', i.method,
    ''sample_percent'', i.sample_percent,
    ''sample_min'', i.sample_min,
    ''arrived_on'', (select r.arrived_on');
    v_src := replace(v_src,
'        ''counted_quantity'', it.counted_quantity,',
'        ''counted_quantity'', it.counted_quantity,
        ''sample_quantity'', it.sample_quantity,
        ''sampled_quantity'', it.sampled_quantity,');
    if position('sample_quantity' in v_src) = 0 or position('i.method' in v_src) = 0 then
      raise exception 'inspection_detail_impl did not have the expected shape';
    end if;
    execute v_src;
  end if;
end $$;
