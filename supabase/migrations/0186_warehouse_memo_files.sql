-- 0186: files on メモ — カレンダー and 掲示板 alike.
--
-- * The private `memo-files` bucket, a folder per note (<memo id>/…): put in
--   and read by whoever may see the note's warehouse (memo_file_allowed).
-- * warehouse_memo_files: each file kept with its note — name, type, size,
--   who put it there and when; taken away without being deleted
--   (removed_at), out of the lists.
-- * warehouse_memos_search (0185) gives each note its files.

insert into storage.buckets (id, name, public, file_size_limit)
values ('memo-files', 'memo-files', false, 20971520)
on conflict (id) do nothing;

-- [p_name]: the object's path in the bucket, <memo id>/<file>.
create or replace function public.memo_file_allowed(p_name text)
returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.warehouse_memos m
     where m.id::text = split_part(coalesce(p_name, ''), '/', 1)
       and m.removed_at is null
       and public.can_access_warehouse(m.warehouse_id));
$$;
grant execute on function public.memo_file_allowed(text) to authenticated;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'memo-files: warehouse people upload') then
    create policy "memo-files: warehouse people upload" on storage.objects
      for insert to authenticated
      with check (bucket_id = 'memo-files' and public.memo_file_allowed(name));
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'memo-files: warehouse people read') then
    create policy "memo-files: warehouse people read" on storage.objects
      for select to authenticated
      using (bucket_id = 'memo-files' and public.memo_file_allowed(name));
  end if;
end $$;

create table if not exists public.warehouse_memo_files (
  id bigint generated always as identity primary key,
  memo_id bigint not null references public.warehouse_memos(id),
  storage_path text not null unique,
  file_name text not null,
  content_type text,
  byte_size integer,
  uploaded_at timestamptz not null default now(),
  uploaded_by uuid default auth.uid(),
  removed_at timestamptz,
  removed_by uuid
);
alter table public.warehouse_memo_files enable row level security;
create index if not exists warehouse_memo_files_memo on public.warehouse_memo_files (memo_id) where removed_at is null;

create or replace function public.warehouse_memo_file_add(
  p_memo_id bigint, p_path text, p_name text, p_type text default null, p_size integer default null)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_memo public.warehouse_memos;
  v_id bigint;
begin
  if auth.uid() is null then
    raise exception 'not permitted: sign in required';
  end if;
  select * into v_memo from public.warehouse_memos where id = p_memo_id and removed_at is null;
  if v_memo.id is null or not public.can_access_warehouse(v_memo.warehouse_id) then
    raise exception 'memo % not found', p_memo_id;
  end if;
  if coalesce(p_path, '') not like p_memo_id::text || '/%' then
    raise exception 'memo_file_path';
  end if;
  insert into public.warehouse_memo_files (memo_id, storage_path, file_name, content_type, byte_size)
  values (p_memo_id, p_path, coalesce(public.tidy_text(p_name), 'file'), public.tidy_text(p_type), p_size)
  returning id into v_id;
  perform public.log_audit('warehouse.memo_file_added', 'warehouse_memo', p_memo_id::text, v_memo.warehouse_id,
    jsonb_build_object('file', p_name, 'size', p_size));
  return v_id;
end;
$$;
revoke all on function public.warehouse_memo_file_add(bigint, text, text, text, integer) from public, anon;
grant execute on function public.warehouse_memo_file_add(bigint, text, text, text, integer) to authenticated;

create or replace function public.warehouse_memo_file_remove(p_id bigint)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_file public.warehouse_memo_files;
  v_wh bigint;
begin
  if auth.uid() is null then
    raise exception 'not permitted: sign in required';
  end if;
  select f.* into v_file from public.warehouse_memo_files f where f.id = p_id and f.removed_at is null for update;
  select warehouse_id into v_wh from public.warehouse_memos where id = v_file.memo_id;
  if v_file.id is null or not public.can_access_warehouse(v_wh) then
    raise exception 'memo file % not found', p_id;
  end if;
  update public.warehouse_memo_files set removed_at = now(), removed_by = auth.uid() where id = p_id;
  perform public.log_audit('warehouse.memo_file_removed', 'warehouse_memo', v_file.memo_id::text, v_wh,
    jsonb_build_object('file', v_file.file_name));
  return true;
end;
$$;
revoke all on function public.warehouse_memo_file_remove(bigint) from public, anon;
grant execute on function public.warehouse_memo_file_remove(bigint) to authenticated;

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
                   m.updated_at, public.user_display_name(m.updated_by) as updated_by_name,
                   (select coalesce(jsonb_agg(jsonb_build_object(
                             'id', f.id, 'path', f.storage_path, 'name', f.file_name, 'type', f.content_type,
                             'size', f.byte_size, 'uploaded_at', f.uploaded_at,
                             'uploaded_by_name', public.user_display_name(f.uploaded_by)) order by f.uploaded_at), '[]'::jsonb)
                      from public.warehouse_memo_files f
                     where f.memo_id = m.id and f.removed_at is null) as files
              from public.warehouse_memos m
              join public.warehouses w on w.id = m.warehouse_id
             where m.removed_at is null and m.kind = p_kind
               and public.can_access_warehouse(m.warehouse_id)
               and (p_warehouse_id is null or m.warehouse_id = p_warehouse_id)
               and (p_from is null or (case when m.kind = 'calendar' then m.memo_date
                                            else (m.created_at at time zone 'Asia/Tokyo')::date end) >= p_from)
               and (p_to is null or (case when m.kind = 'calendar' then m.memo_date
                                          else (m.created_at at time zone 'Asia/Tokyo')::date end) <= p_to)
               and (v_q is null or strpos(lower(m.body), lower(v_q)) > 0
                    or exists (select 1 from public.warehouse_memo_files f
                                where f.memo_id = m.id and f.removed_at is null
                                  and strpos(lower(f.file_name), lower(v_q)) > 0))
             order by case when v_cal then m.memo_date end asc, case when v_cal then m.created_at end asc,
                      case when not v_cal then m.created_at end desc, m.id desc
             limit greatest(1, least(coalesce(p_limit, 300), 1000))) x), '[]'::jsonb);
end;
$$;
