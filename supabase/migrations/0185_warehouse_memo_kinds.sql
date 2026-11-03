-- 0185: メモ in two — カレンダー and 掲示板.
--
-- * kind 'calendar': a note put on a day chosen by hand (memo_date) — goods
--   due at the warehouse, the day's arrangements, how many part-timers came;
--   any day, past or to come.
-- * kind 'board': a note on the board, tied to no day but the one it was
--   written (掲示板).
-- Notes written before (0184) are on the board.
-- warehouse_memos_search / warehouse_memo_write take the kind (and the day);
-- 0184's list and save are no longer called by the app.

alter table public.warehouse_memos add column if not exists kind text not null default 'board';
alter table public.warehouse_memos add column if not exists memo_date date;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'warehouse_memos_kind_check') then
    alter table public.warehouse_memos add constraint warehouse_memos_kind_check
      check (kind in ('board', 'calendar') and (kind <> 'calendar' or memo_date is not null));
  end if;
end;
$$;
create index if not exists warehouse_memos_by_date on public.warehouse_memos (warehouse_id, memo_date)
  where removed_at is null and kind = 'calendar';

-- [p_kind] 'calendar': by the day chosen (from/to on it), the earliest day
-- first; 'board': by when written, the newest first.
create or replace function public.warehouse_memos_search(
  p_kind text, p_warehouse_id bigint default null, p_from date default null, p_to date default null,
  p_query text default null, p_limit integer default 300)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_q text := nullif(btrim(coalesce(p_query, '')), '');
  v_cal boolean := p_kind = 'calendar';
begin
  if auth.uid() is null then
    raise exception 'not permitted: sign in required';
  end if;
  if p_kind is null or p_kind not in ('board', 'calendar') then
    raise exception 'memo_kind_required';
  end if;
  if p_warehouse_id is not null and not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(x) order by
             case when v_cal then x.day end asc, case when v_cal then x.created_at end asc,
             case when not v_cal then x.created_at end desc, x.id desc)
      from (select m.id, m.kind, m.warehouse_id, w.name as warehouse_name, m.body,
                   case when m.kind = 'calendar' then m.memo_date
                        else (m.created_at at time zone 'Asia/Tokyo')::date end as day,
                   m.memo_date, m.created_at,
                   public.user_display_name(m.created_by) as created_by_name,
                   m.updated_at, public.user_display_name(m.updated_by) as updated_by_name
              from public.warehouse_memos m
              join public.warehouses w on w.id = m.warehouse_id
             where m.removed_at is null and m.kind = p_kind
               and public.can_access_warehouse(m.warehouse_id)
               and (p_warehouse_id is null or m.warehouse_id = p_warehouse_id)
               and (p_from is null or (case when m.kind = 'calendar' then m.memo_date
                                            else (m.created_at at time zone 'Asia/Tokyo')::date end) >= p_from)
               and (p_to is null or (case when m.kind = 'calendar' then m.memo_date
                                          else (m.created_at at time zone 'Asia/Tokyo')::date end) <= p_to)
               and (v_q is null or strpos(lower(m.body), lower(v_q)) > 0)
             order by case when v_cal then m.memo_date end asc, case when v_cal then m.created_at end asc,
                      case when not v_cal then m.created_at end desc, m.id desc
             limit greatest(1, least(coalesce(p_limit, 300), 1000))) x), '[]'::jsonb);
end;
$$;
revoke all on function public.warehouse_memos_search(text, bigint, date, date, text, integer) from public, anon;
grant execute on function public.warehouse_memos_search(text, bigint, date, date, text, integer) to authenticated;

-- [p_id] null: a new note of [p_kind]; else that note changed (its kind
-- stays). A calendar note needs its day.
create or replace function public.warehouse_memo_write(
  p_id bigint, p_kind text, p_warehouse_id bigint, p_body text, p_memo_date date default null)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_body text := btrim(coalesce(p_body, ''));
  v_old public.warehouse_memos;
  v_kind text;
  v_id bigint;
begin
  if auth.uid() is null then
    raise exception 'not permitted: sign in required';
  end if;
  if p_warehouse_id is null or not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if length(v_body) = 0 then
    raise exception 'memo_empty';
  end if;
  if length(v_body) > 4000 then
    raise exception 'memo_too_long';
  end if;
  if p_id is not null then
    select * into v_old from public.warehouse_memos where id = p_id and removed_at is null for update;
    if v_old.id is null or not public.can_access_warehouse(v_old.warehouse_id) then
      raise exception 'memo % not found', p_id;
    end if;
  end if;
  v_kind := coalesce(v_old.kind, p_kind);
  if v_kind is null or v_kind not in ('board', 'calendar') then
    raise exception 'memo_kind_required';
  end if;
  if v_kind = 'calendar' and coalesce(p_memo_date, v_old.memo_date) is null then
    raise exception 'memo_date_required';
  end if;
  if p_id is null then
    insert into public.warehouse_memos (warehouse_id, body, kind, memo_date)
    values (p_warehouse_id, v_body, v_kind, case when v_kind = 'calendar' then p_memo_date end)
    returning id into v_id;
    perform public.log_audit('warehouse.memo_written', 'warehouse_memo', v_id::text, p_warehouse_id,
      jsonb_build_object('kind', v_kind, 'memo_date', p_memo_date));
    return v_id;
  end if;
  update public.warehouse_memos set
    warehouse_id = p_warehouse_id, body = v_body,
    memo_date = case when v_kind = 'calendar' then coalesce(p_memo_date, memo_date) end,
    updated_at = now(), updated_by = auth.uid()
   where id = p_id;
  perform public.log_audit('warehouse.memo_changed', 'warehouse_memo', p_id::text, p_warehouse_id,
    jsonb_build_object('before', v_old.body, 'before_date', v_old.memo_date));
  return p_id;
end;
$$;
revoke all on function public.warehouse_memo_write(bigint, text, bigint, text, date) from public, anon;
grant execute on function public.warehouse_memo_write(bigint, text, bigint, text, date) to authenticated;
