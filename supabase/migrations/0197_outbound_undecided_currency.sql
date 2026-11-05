-- 0197: 出庫予定日「未定」 and each shipping-list row's currency.
--
-- 未定: a planned list (0191) may have no day yet. date_undecided marks it;
-- it is kept off the 出庫カレンダー's days (outbound_files_list) and listed by
-- outbound_files_undecided until a day is set (outbound_file_reschedule, or
-- outbound_file_confirm when it ships). outbound_file_mark_undecided puts a
-- planned list back to 未定.
--
-- Currency: a sales price may be written in 人民元 by whoever made the list.
-- Each row keeps its currency (JPY / CNY / USD) and how it was decided
-- (file: the sheet says; ai: judged against the purchase price; manual), the
-- list its main currency and, if given, the rate (1 CNY in JPY) — so 入荷 and
-- 出荷 can be put in one currency for the profit and loss later.
-- outbound_file_set_currency writes them after the list is posted.

alter table public.outbound_files add column if not exists date_undecided boolean not null default false;
alter table public.outbound_files add column if not exists currency text;
alter table public.outbound_files add column if not exists fx_cny_jpy numeric;
alter table public.outbound_file_lines add column if not exists currency text not null default 'JPY';
alter table public.outbound_file_lines add column if not exists currency_source text;

do $$
declare
  d text;
  r text;
begin
  -- The calendar's days leave out lists with no day; each says if it has one.
  d := pg_get_functiondef('public.outbound_files_list(date, date, bigint)'::regprocedure);
  if position('date_undecided' in d) = 0 then
    r := replace(d, '''kind'', f.kind, ''status'', f.status, ''planned_on'', f.planned_on,',
                    '''kind'', f.kind, ''status'', f.status, ''planned_on'', f.planned_on, ''date_undecided'', f.date_undecided, '
                    || '''currency'', f.currency, ''fx_cny_jpy'', f.fx_cny_jpy,');
    r := replace(r, 'and (p_warehouse_id is null or f.warehouse_id = p_warehouse_id)), ''[]''::jsonb);',
                    'and (p_warehouse_id is null or f.warehouse_id = p_warehouse_id)'
                    || ' and not f.date_undecided), ''[]''::jsonb);');
    if r = d or position('not f.date_undecided' in r) = 0 or position('''date_undecided'', f.date_undecided' in r) = 0 then
      raise exception 'outbound_files_list: the text to change was not found';
    end if;
    execute r;
  end if;

  d := pg_get_functiondef('public.outbound_file_detail(bigint)'::regprocedure);
  if position('date_undecided' in d) = 0 then
    r := replace(d, '''kind'', v_f.kind, ''status'', v_f.status, ''planned_on'', v_f.planned_on,',
                    '''kind'', v_f.kind, ''status'', v_f.status, ''planned_on'', v_f.planned_on, '
                    || '''date_undecided'', v_f.date_undecided, ''currency'', v_f.currency, ''fx_cny_jpy'', v_f.fx_cny_jpy,');
    r := replace(r, '''unit_price'', l.unit_price,',
                    '''unit_price'', l.unit_price, ''currency'', l.currency, ''currency_source'', l.currency_source,');
    if r = d or position('''currency'', l.currency' in r) = 0 or position('''date_undecided'', v_f.date_undecided' in r) = 0 then
      raise exception 'outbound_file_detail: the text to change was not found';
    end if;
    execute r;
  end if;

  -- A day set, or the list shipped: no longer 未定.
  d := pg_get_functiondef('public.outbound_file_reschedule(bigint, date)'::regprocedure);
  if position('date_undecided' in d) = 0 then
    r := replace(d, 'set shipped_on = p_day, planned_on = p_day where id = p_id;',
                    'set shipped_on = p_day, planned_on = p_day, date_undecided = false where id = p_id;');
    if r = d then
      raise exception 'outbound_file_reschedule: the text to change was not found';
    end if;
    execute r;
  end if;

  d := pg_get_functiondef('public.outbound_file_confirm(bigint, date)'::regprocedure);
  if position('date_undecided' in d) = 0 then
    r := replace(d, 'shipped_on = coalesce(p_shipped_on, (now() at time zone ''Asia/Tokyo'')::date),',
                    'shipped_on = coalesce(p_shipped_on, (now() at time zone ''Asia/Tokyo'')::date), date_undecided = false,');
    if r = d then
      raise exception 'outbound_file_confirm: the text to change was not found';
    end if;
    execute r;
  end if;
end $$;

-- The planned lists with no day yet (oldest first).
create or replace function public.outbound_files_undecided(p_warehouse_id bigint default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.can_view_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', f.id, 'warehouse_id', f.warehouse_id, 'warehouse_name', w.name, 'shipped_on', f.shipped_on,
             'kind', f.kind, 'status', f.status, 'planned_on', f.planned_on, 'date_undecided', true,
             'destination_id', f.destination_id, 'ship_to', f.ship_to, 'file_name', f.file_name,
             'destination', f.destination, 'note', f.note, 'line_count', f.line_count,
             'quantity_total', f.quantity_total, 'amount_total', f.amount_total, 'currency', f.currency,
             'created_at', f.created_at, 'created_by_name', public.user_display_name(f.created_by))
           order by f.created_at, f.id)
      from public.outbound_files f
      join public.warehouses w on w.id = f.warehouse_id
     where f.date_undecided and f.status = 'planned' and f.undone_at is null
       and public.can_access_warehouse(f.warehouse_id)
       and (p_warehouse_id is null or f.warehouse_id = p_warehouse_id)), '[]'::jsonb);
end;
$$;
revoke all on function public.outbound_files_undecided(bigint) from public, anon;
grant execute on function public.outbound_files_undecided(bigint) to authenticated;

create or replace function public.outbound_file_mark_undecided(p_id bigint)
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
  update public.outbound_files set date_undecided = true, planned_on = null where id = p_id;
  perform public.log_audit('outbound.file_undecided', 'outbound_file', p_id::text, v_f.warehouse_id,
    jsonb_build_object('was', v_f.shipped_on));
  return true;
end;
$$;
revoke all on function public.outbound_file_mark_undecided(bigint) from public, anon;
grant execute on function public.outbound_file_mark_undecided(bigint) to authenticated;

-- [p_lines]: [{row_no, currency, source}]; [p_currency] the list's main one;
-- [p_fx_cny_jpy] 1 CNY in JPY, if known.
create or replace function public.outbound_file_set_currency(
  p_id bigint, p_lines jsonb, p_currency text default null, p_fx_cny_jpy numeric default null)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_f public.outbound_files;
  v_line jsonb;
  v_n integer := 0;
  v_c text;
begin
  if auth.uid() is null or not public.can_post_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  select * into v_f from public.outbound_files where id = p_id for update;
  if v_f.id is null or not public.can_access_warehouse(v_f.warehouse_id) then
    raise exception 'outbound file % not found', p_id;
  end if;
  for v_line in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_c := upper(coalesce(v_line->>'currency', ''));
    if v_c not in ('JPY', 'CNY', 'USD') then
      continue;
    end if;
    update public.outbound_file_lines
       set currency = v_c, currency_source = nullif(v_line->>'source', '')
     where file_id = p_id and row_no = (v_line->>'row_no')::integer;
    if found then
      v_n := v_n + 1;
    end if;
  end loop;
  update public.outbound_files
     set currency = coalesce(nullif(upper(p_currency), ''), currency),
         fx_cny_jpy = coalesce(p_fx_cny_jpy, fx_cny_jpy)
   where id = p_id;
  return v_n;
end;
$$;
revoke all on function public.outbound_file_set_currency(bigint, jsonb, text, numeric) from public, anon;
grant execute on function public.outbound_file_set_currency(bigint, jsonb, text, numeric) to authenticated;
