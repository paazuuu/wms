-- 読み取り検査 (0224): what a file reading in 発注, 予定外の入荷 and 出庫 could
-- not read, misread or read more than one way — kept on the server so every
-- PC sees it, with the file read. For improving the reader only: nothing
-- here is joined to products, stock or any other table, and no existing
-- table is changed. Taken out of the list by setting removed_at (the file
-- with it: the storage policy no longer lets it be read).

create table if not exists public.reading_audits (
  id bigint generated always as identity primary key,
  -- The app's id for one reading: kept once, updated as it is checked.
  client_id text not null unique,
  read_at timestamptz not null default now(),
  source text not null check (source in ('stock_file', 'unplanned', 'outbound')),
  file_name text not null,
  by_ai boolean not null default false,
  supplier text,
  line_count integer not null default 0,
  -- [{kind, field, line?, detail, remedy?}], in words.
  issues jsonb not null default '[]'::jsonb,
  storage_path text,
  content_type text,
  byte_size bigint,
  created_by uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  removed_at timestamptz,
  removed_by uuid
);
create index if not exists reading_audits_open on public.reading_audits (read_at desc) where removed_at is null;
-- Only through the functions below.
alter table public.reading_audits enable row level security;

insert into storage.buckets (id, name, public, file_size_limit)
values ('reading-audits', 'reading-audits', false, 26214400)
on conflict (id) do nothing;

-- Who looks at the list: the system administrator, and those who see the
-- audit log, manage users or review the AI.
create or replace function public.reading_audit_can_view()
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_system_admin() or public.has_permission('audit.view')
      or public.has_permission('user.manage') or public.has_permission('ai.review');
$$;
grant execute on function public.reading_audit_can_view() to authenticated, service_role;
revoke execute on function public.reading_audit_can_view() from public, anon;

-- [p_name]: <audit id>/<file>. Written once, by whoever made the reading;
-- read by those who look at the list.
create or replace function public.reading_audit_file_allowed(p_name text, p_write boolean)
returns boolean language sql stable security definer set search_path = '' as $$
  select split_part(coalesce(p_name, ''), '/', 1) ~ '^[0-9]+$'
     and exists (select 1 from public.reading_audits a
                  where a.id = split_part(p_name, '/', 1)::bigint and a.removed_at is null
                    and (not p_write or (a.created_by = auth.uid() and a.storage_path is null)))
     and (p_write or public.reading_audit_can_view());
$$;
grant execute on function public.reading_audit_file_allowed(text, boolean) to authenticated, service_role;
revoke execute on function public.reading_audit_file_allowed(text, boolean) from public, anon;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'reading-audits: reader uploads') then
    create policy "reading-audits: reader uploads" on storage.objects
      for insert to authenticated
      with check (bucket_id = 'reading-audits' and public.reading_audit_file_allowed(name, true));
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'reading-audits: viewers read') then
    create policy "reading-audits: viewers read" on storage.objects
      for select to authenticated
      using (bucket_id = 'reading-audits' and public.reading_audit_file_allowed(name, false));
  end if;
end $$;

-- p: {client_id, source, file_name, by_ai, supplier?, line_count, issues}.
-- Kept (or updated) by whoever read the file; a reading with nothing to say
-- is not kept, and one taken out of the list stays out.
-- {id, has_file, removed}; id null when nothing was kept.
create or replace function public.reading_audit_save(p jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_client text := nullif(btrim(coalesce(p->>'client_id', '')), '');
  v_source text := coalesce(p->>'source', '');
  v_issues jsonb := case when jsonb_typeof(p->'issues') = 'array' then p->'issues' else '[]'::jsonb end;
  v_lines integer := greatest(coalesce(nullif(p->>'line_count', '')::integer, 0), 0);
  v_supplier text := nullif(left(btrim(coalesce(p->>'supplier', '')), 200), '');
  v_row public.reading_audits%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not permitted: sign in required';
  end if;
  if v_client is null or length(v_client) > 64 then
    raise exception 'reading_audit_client_id';
  end if;
  if v_source not in ('stock_file', 'unplanned', 'outbound') then
    raise exception 'reading_audit_source';
  end if;
  if jsonb_array_length(v_issues) > 3000 or pg_column_size(v_issues) > 2000000 then
    raise exception 'reading_audit_too_large';
  end if;
  select * into v_row from public.reading_audits where client_id = v_client;
  if not found then
    if jsonb_array_length(v_issues) = 0 then
      return jsonb_build_object('id', null, 'has_file', false, 'removed', false);
    end if;
    insert into public.reading_audits (client_id, source, file_name, by_ai, supplier, line_count, issues, created_by)
    values (v_client, v_source, left(coalesce(nullif(btrim(p->>'file_name'), ''), '-'), 300),
            coalesce((p->>'by_ai')::boolean, false), v_supplier, v_lines, v_issues, auth.uid())
    returning * into v_row;
  elsif v_row.created_by is distinct from auth.uid() then
    raise exception 'not permitted: another person''s reading';
  elsif v_row.removed_at is null then
    update public.reading_audits
       set issues = v_issues, line_count = v_lines, supplier = coalesce(v_supplier, supplier), updated_at = now()
     where id = v_row.id
    returning * into v_row;
  end if;
  return jsonb_build_object('id', v_row.id, 'has_file', v_row.storage_path is not null,
                            'removed', v_row.removed_at is not null);
end;
$$;
grant execute on function public.reading_audit_save(jsonb) to authenticated, service_role;
revoke execute on function public.reading_audit_save(jsonb) from public, anon;

-- The file read, once uploaded to <id>/…: set on the reading, once.
create or replace function public.reading_audit_attach(p_id bigint, p_path text, p_type text, p_size bigint)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  update public.reading_audits
     set storage_path = p_path, content_type = p_type, byte_size = p_size, updated_at = now()
   where id = p_id and created_by = auth.uid() and removed_at is null and storage_path is null
     and split_part(coalesce(p_path, ''), '/', 1) = p_id::text;
  return found;
end;
$$;
grant execute on function public.reading_audit_attach(bigint, text, text, bigint) to authenticated, service_role;
revoke execute on function public.reading_audit_attach(bigint, text, text, bigint) from public, anon;

-- The readings kept, newest first.
create or replace function public.reading_audits_list(p_limit integer default 500)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.reading_audit_can_view() then
    raise exception 'not permitted: audit.view required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', a.id, 'client_id', a.client_id, 'read_at', a.read_at, 'updated_at', a.updated_at,
             'source', a.source, 'file_name', a.file_name, 'by_ai', a.by_ai, 'supplier', a.supplier,
             'line_count', a.line_count, 'issues', a.issues,
             'storage_path', a.storage_path, 'content_type', a.content_type, 'byte_size', a.byte_size,
             'created_by_name', (select coalesce(u.name, u.email) from public.app_users u where u.id = a.created_by))
           order by a.read_at desc, a.id desc)
      from (select * from public.reading_audits
             where removed_at is null and jsonb_array_length(issues) > 0
             order by read_at desc, id desc
             limit least(greatest(coalesce(p_limit, 500), 1), 2000)) a), '[]'::jsonb);
end;
$$;
grant execute on function public.reading_audits_list(integer) to authenticated, service_role;
revoke execute on function public.reading_audits_list(integer) from public, anon;

-- Taken out of the list, with their files; how many.
create or replace function public.reading_audit_remove(p_ids bigint[])
returns integer language plpgsql security definer set search_path = '' as $$
declare
  n integer;
begin
  if not public.reading_audit_can_view() then
    raise exception 'not permitted: audit.view required';
  end if;
  update public.reading_audits set removed_at = now(), removed_by = auth.uid()
   where id = any(coalesce(p_ids, '{}')) and removed_at is null;
  get diagnostics n = row_count;
  return n;
end;
$$;
grant execute on function public.reading_audit_remove(bigint[]) to authenticated, service_role;
revoke execute on function public.reading_audit_remove(bigint[]) from public, anon;
