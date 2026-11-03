-- 0184: メモ — notes kept per warehouse, in place of 棚入れ in the menu.
--
-- * warehouse_memos: a note written for one warehouse, on the day it was
--   written (Japan time), by whom; changed or taken away later by anyone
--   who works there, with who and when kept. Taken away is not deleted
--   (removed_at): the note leaves the lists.
-- * warehouse_memos_list: the notes of a warehouse (or of every warehouse one
--   may see), of some days (the calendar) and/or holding some words (検索).
-- * warehouse_memo_save / warehouse_memo_remove: write, change, take away.
-- Anyone signed in who may see the warehouse reads and writes its notes.

create table if not exists public.warehouse_memos (
  id bigint generated always as identity primary key,
  warehouse_id bigint not null references public.warehouses(id),
  body text not null check (length(btrim(body)) between 1 and 4000),
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz,
  updated_by uuid,
  removed_at timestamptz,
  removed_by uuid
);
alter table public.warehouse_memos enable row level security;
create index if not exists warehouse_memos_by_day on public.warehouse_memos (warehouse_id, created_at)
  where removed_at is null;

create or replace function public.warehouse_memos_list(
  p_warehouse_id bigint default null, p_from date default null, p_to date default null,
  p_query text default null, p_limit integer default 300)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_q text := nullif(btrim(coalesce(p_query, '')), '');
begin
  if auth.uid() is null then
    raise exception 'not permitted: sign in required';
  end if;
  if p_warehouse_id is not null and not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(x) order by x.created_at desc, x.id desc)
      from (select m.id, m.warehouse_id, w.name as warehouse_name, m.body,
                   (m.created_at at time zone 'Asia/Tokyo')::date as day, m.created_at,
                   public.user_display_name(m.created_by) as created_by_name,
                   m.updated_at, public.user_display_name(m.updated_by) as updated_by_name
              from public.warehouse_memos m
              join public.warehouses w on w.id = m.warehouse_id
             where m.removed_at is null
               and public.can_access_warehouse(m.warehouse_id)
               and (p_warehouse_id is null or m.warehouse_id = p_warehouse_id)
               and (p_from is null or (m.created_at at time zone 'Asia/Tokyo')::date >= p_from)
               and (p_to is null or (m.created_at at time zone 'Asia/Tokyo')::date <= p_to)
               and (v_q is null or strpos(lower(m.body), lower(v_q)) > 0)
             order by m.created_at desc, m.id desc
             limit greatest(1, least(coalesce(p_limit, 300), 1000))) x), '[]'::jsonb);
end;
$$;
revoke all on function public.warehouse_memos_list(bigint, date, date, text, integer) from public, anon;
grant execute on function public.warehouse_memos_list(bigint, date, date, text, integer) to authenticated;

-- [p_id] null: a new note; else that note changed.
create or replace function public.warehouse_memo_save(p_id bigint, p_warehouse_id bigint, p_body text)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_body text := btrim(coalesce(p_body, ''));
  v_old public.warehouse_memos;
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
  if p_id is null then
    insert into public.warehouse_memos (warehouse_id, body) values (p_warehouse_id, v_body) returning id into v_id;
    perform public.log_audit('warehouse.memo_written', 'warehouse_memo', v_id::text, p_warehouse_id, '{}'::jsonb);
    return v_id;
  end if;
  select * into v_old from public.warehouse_memos where id = p_id and removed_at is null for update;
  if v_old.id is null or not public.can_access_warehouse(v_old.warehouse_id) then
    raise exception 'memo % not found', p_id;
  end if;
  update public.warehouse_memos set
    warehouse_id = p_warehouse_id, body = v_body, updated_at = now(), updated_by = auth.uid()
   where id = p_id;
  perform public.log_audit('warehouse.memo_changed', 'warehouse_memo', p_id::text, p_warehouse_id,
    jsonb_build_object('before', v_old.body));
  return p_id;
end;
$$;
revoke all on function public.warehouse_memo_save(bigint, bigint, text) from public, anon;
grant execute on function public.warehouse_memo_save(bigint, bigint, text) to authenticated;

create or replace function public.warehouse_memo_remove(p_id bigint)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_old public.warehouse_memos;
begin
  if auth.uid() is null then
    raise exception 'not permitted: sign in required';
  end if;
  select * into v_old from public.warehouse_memos where id = p_id and removed_at is null for update;
  if v_old.id is null or not public.can_access_warehouse(v_old.warehouse_id) then
    raise exception 'memo % not found', p_id;
  end if;
  update public.warehouse_memos set removed_at = now(), removed_by = auth.uid() where id = p_id;
  perform public.log_audit('warehouse.memo_removed', 'warehouse_memo', p_id::text, v_old.warehouse_id,
    jsonb_build_object('body', v_old.body));
  return true;
end;
$$;
revoke all on function public.warehouse_memo_remove(bigint) from public, anon;
grant execute on function public.warehouse_memo_remove(bigint) to authenticated;
