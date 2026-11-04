-- 0191: 出庫予定 — a shipping list registered for a day, shipped when the
-- warehouse confirms it.
--
-- * outbound_files.status: 'shipped' (0188: taken out of stock when posted)
--   or 'planned' (no stock moved yet); planned_on, the day it was meant for.
--   A planned list sits on the 出庫カレンダー on that day (shipped_on).
-- * outbound_file_plan: as outbound_file_post (same rows, same checks), but
--   nothing leaves stock and nothing is short yet.
-- * outbound_file_confirm(id, day): the warehouse ships it — each 'ship' row
--   takes what there is then, the rest recorded as short — and it becomes
--   'shipped' on that day.
-- * outbound_file_reschedule(id, day): a planned list moved to another day.
-- * outbound_file_undo (0188) cancels a planned list too (nothing to put
--   back). outbound_files_list / outbound_file_detail give status, planned_on.

alter table public.outbound_files add column if not exists status text not null default 'shipped';
alter table public.outbound_files add column if not exists planned_on date;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'outbound_files_status_check') then
    alter table public.outbound_files add constraint outbound_files_status_check check (status in ('planned', 'shipped'));
  end if;
end $$;

do $mig$
declare
  d text;
  p text;
  r text;
begin
  -- outbound_file_plan: outbound_file_post with nothing taken out of stock.
  d := pg_get_functiondef('public.outbound_file_post(bigint, date, text, jsonb, text, text, integer, text, text, text, text, jsonb, boolean)'::regprocedure);
  p := replace(d, 'public.outbound_file_post(', 'public.outbound_file_plan(');
  p := replace(p, 'fingerprint, sheet_name, destination, note, columns)', 'fingerprint, sheet_name, destination, note, columns, status, planned_on)');
  p := replace(p, 'coalesce(p_columns, ''{}''::jsonb))
  returning id into v_id;', 'coalesce(p_columns, ''{}''::jsonb), ''planned'',
          coalesce(p_shipped_on, (now() at time zone ''Asia/Tokyo'')::date))
  returning id into v_id;');
  p := replace(p, 'if v_action = ''ship'' and v_qty > 0 then', 'if false then');
  p := replace(p, 'case when v_action = ''ship'' then v_qty - v_ship else 0 end', '0');
  p := replace(p, '''outbound.file_posted''', '''outbound.file_planned''');
  if p not like '%status, planned_on)%' or p not like '%''planned'',%' or p not like '%if false then%'
     or p not like '%outbound.file_planned%' or p like '%v_qty - v_ship else 0 end%' then
    raise exception 'outbound_file_plan: a replacement did not apply';
  end if;
  execute p;
  execute 'revoke all on function public.outbound_file_plan(bigint, date, text, jsonb, text, text, integer, text, text, text, text, jsonb, boolean) from public, anon';
  execute 'grant execute on function public.outbound_file_plan(bigint, date, text, jsonb, text, text, integer, text, text, text, text, jsonb, boolean) to authenticated';

  d := pg_get_functiondef('public.outbound_files_list(date, date, bigint)'::regprocedure);
  r := replace(d, '''kind'', f.kind,', '''kind'', f.kind, ''status'', f.status, ''planned_on'', f.planned_on,');
  if r = d then raise exception 'outbound_files_list: no change'; end if;
  execute r;
  d := pg_get_functiondef('public.outbound_file_detail(bigint)'::regprocedure);
  r := replace(d, '''kind'', v_f.kind,', '''kind'', v_f.kind, ''status'', v_f.status, ''planned_on'', v_f.planned_on,');
  if r = d then raise exception 'outbound_file_detail: no change'; end if;
  execute r;
end
$mig$;

-- The warehouse ships a planned list: each row takes what there is now.
create or replace function public.outbound_file_confirm(p_id bigint, p_shipped_on date default null)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_f public.outbound_files;
  v_l public.outbound_file_lines;
  v_before integer;
  v_ship integer;
  v_mid bigint;
  v_n integer := 0;
begin
  if auth.uid() is null or not public.can_post_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  select * into v_f from public.outbound_files where id = p_id for update;
  if v_f.id is null or not public.can_access_warehouse(v_f.warehouse_id) then
    raise exception 'outbound file % not found', p_id;
  end if;
  if v_f.undone_at is not null then
    raise exception 'outbound_already_undone';
  end if;
  if v_f.status <> 'planned' then
    raise exception 'outbound_not_planned';
  end if;
  for v_l in select * from public.outbound_file_lines
              where file_id = p_id and action = 'ship' and product_id is not null and quantity > 0
              order by row_no, id loop
    select coalesce(sum(on_hand), 0)::integer into v_before from public.stock_levels
     where warehouse_id = v_f.warehouse_id and jan_code = v_l.jan_code;
    v_ship := least(v_l.quantity, greatest(v_before, 0));
    v_mid := null;
    if v_ship > 0 then
      v_mid := public.apply_stock_movement_detail(v_f.warehouse_id, v_l.jan_code, -v_ship, 'SHIP',
                 'outbound_file', p_id::text, v_l.product_name, null, 'row ' || v_l.row_no,
                 null, null, null, v_l.product_id);
    end if;
    update public.outbound_file_lines set
      shipped_quantity = v_ship, short_quantity = v_l.quantity - v_ship,
      on_hand_before = v_before, on_hand_after = v_before - v_ship, movement_id = v_mid
     where id = v_l.id;
    v_n := v_n + v_ship;
  end loop;
  update public.outbound_files f set
    status = 'shipped',
    shipped_on = coalesce(p_shipped_on, (now() at time zone 'Asia/Tokyo')::date),
    shipped_total = x.s, short_total = x.sh
    from (select coalesce(sum(shipped_quantity), 0) as s, coalesce(sum(short_quantity), 0) as sh
            from public.outbound_file_lines where file_id = p_id) x
   where f.id = p_id;
  perform public.log_audit('outbound.file_confirmed', 'outbound_file', p_id::text, v_f.warehouse_id,
    jsonb_build_object('file', v_f.file_name, 'planned_on', v_f.planned_on, 'shipped_on', p_shipped_on, 'shipped', v_n));
  return v_n;
end;
$$;
revoke all on function public.outbound_file_confirm(bigint, date) from public, anon;
grant execute on function public.outbound_file_confirm(bigint, date) to authenticated;

-- A planned list moved to another day.
create or replace function public.outbound_file_reschedule(p_id bigint, p_day date)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_f public.outbound_files;
begin
  if auth.uid() is null or not public.can_post_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  select * into v_f from public.outbound_files where id = p_id for update;
  if v_f.id is null or not public.can_access_warehouse(v_f.warehouse_id) then
    raise exception 'outbound file % not found', p_id;
  end if;
  if v_f.status <> 'planned' or v_f.undone_at is not null then
    raise exception 'outbound_not_planned';
  end if;
  if p_day is null then
    raise exception 'outbound_day_required';
  end if;
  update public.outbound_files set shipped_on = p_day, planned_on = p_day where id = p_id;
  perform public.log_audit('outbound.file_rescheduled', 'outbound_file', p_id::text, v_f.warehouse_id,
    jsonb_build_object('from', v_f.shipped_on, 'to', p_day));
  return true;
end;
$$;
revoke all on function public.outbound_file_reschedule(bigint, date) from public, anon;
grant execute on function public.outbound_file_reschedule(bigint, date) to authenticated;
