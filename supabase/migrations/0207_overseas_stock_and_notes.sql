-- 0207: 国外の仮想在庫 (its own tables, apart from our stock) and notes on
-- records.
--
-- 国外の仮想在庫: what our branches and partner companies abroad say they
-- hold, read from the files they send (Excel, CSV, or a PDF / photo the AI
-- reads), checked, and kept as that site's stock on a day. Nothing here
-- touches our products or stock: a JAN that is in our library is only
-- pointed out.
-- * overseas_sites: 拠点 — our branch or a partner, its country and town.
-- * overseas_stock_imports: one file read for a site, as of a day (the file
--   kept in the bucket 'overseas-files'); the latest one not taken back is
--   the site's stock now.
-- * overseas_stock_lines: its rows (JAN, 品番, 商品名, メーカー, 数量, 単位,
--   the row as it was).
-- * overseas_sites_list / overseas_site_save / overseas_site_archive,
--   overseas_stock_import / overseas_stock_imports / overseas_stock_undo,
--   overseas_stock_lines, overseas_stock_overview (each product across the
--   sites).
--
-- Notes (メモ) on a record, with files: on a 入荷希望リスト ('wish_list')
-- and on a site abroad ('overseas_site').
-- * record_notes / record_note_files, the bucket 'note-files'
--   (<note id>/<file>), read and written by whoever may see or edit the
--   record.
-- * record_notes_list / record_note_write / record_note_remove /
--   record_note_file_add / record_note_file_remove.
-- * purchase_requests_list says how many notes a list has.

-- ------------------------------------------------------------ who may

create or replace function public.overseas_can_view()
returns boolean language sql stable security definer set search_path = '' as $$
  select public.has_permission('inventory.view') or public.has_permission('product.view')
      or public.has_permission('report.view') or public.has_permission('purchase_order.view')
      or public.has_permission('sales_order.view');
$$;
create or replace function public.overseas_can_edit()
returns boolean language sql stable security definer set search_path = '' as $$
  select public.has_permission('inventory.adjust') or public.has_permission('product.manage')
      or public.has_permission('purchase_order.manage');
$$;
revoke all on function public.overseas_can_view() from public, anon;
revoke all on function public.overseas_can_edit() from public, anon;
grant execute on function public.overseas_can_view() to authenticated, service_role;
grant execute on function public.overseas_can_edit() to authenticated, service_role;

-- ------------------------------------------------------------ 国外の仮想在庫

create table if not exists public.overseas_sites (
  id bigint generated always as identity primary key,
  name text not null,
  kind text not null default 'branch' check (kind in ('branch', 'partner')),
  country text,
  city text,
  contact text,
  note text,
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz
);

create table if not exists public.overseas_stock_imports (
  id bigint generated always as identity primary key,
  site_id bigint not null references public.overseas_sites(id),
  as_of date not null,
  file_name text,
  storage_path text,
  file_size bigint,
  file_fingerprint text,
  sheet_name text,
  columns jsonb,
  read_by text not null default 'sheet' check (read_by in ('sheet', 'ai', 'manual')),
  line_count integer not null default 0,
  units numeric not null default 0,
  note text,
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  undone_at timestamptz,
  undone_by uuid
);
create index if not exists overseas_stock_imports_site on public.overseas_stock_imports (site_id, as_of desc, id desc);

create table if not exists public.overseas_stock_lines (
  id bigint generated always as identity primary key,
  import_id bigint not null references public.overseas_stock_imports(id),
  row_no integer,
  jan text,
  code text,
  name text,
  maker text,
  quantity numeric not null default 0,
  unit text,
  raw jsonb
);
create index if not exists overseas_stock_lines_import on public.overseas_stock_lines (import_id);
create index if not exists overseas_stock_lines_jan on public.overseas_stock_lines (jan) where jan is not null;

alter table public.overseas_sites enable row level security;
alter table public.overseas_stock_imports enable row level security;
alter table public.overseas_stock_lines enable row level security;

insert into storage.buckets (id, name, public, file_size_limit)
values ('overseas-files', 'overseas-files', false, 52428800)
on conflict (id) do nothing;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'overseas-files: editors upload') then
    create policy "overseas-files: editors upload" on storage.objects
      for insert to authenticated
      with check (bucket_id = 'overseas-files' and public.overseas_can_edit());
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'overseas-files: viewers read') then
    create policy "overseas-files: viewers read" on storage.objects
      for select to authenticated
      using (bucket_id = 'overseas-files' and public.overseas_can_view());
  end if;
end $$;

-- The site's stock now: its latest import not taken back.
create or replace function public.overseas_latest_import(p_site_id bigint)
returns bigint language sql stable security definer set search_path = '' as $$
  select i.id from public.overseas_stock_imports i
   where i.site_id = p_site_id and i.undone_at is null
   order by i.as_of desc, i.id desc limit 1;
$$;
revoke all on function public.overseas_latest_import(bigint) from public, anon;
grant execute on function public.overseas_latest_import(bigint) to authenticated;

-- ------------------------------------------------------------ notes

create table if not exists public.record_notes (
  id bigint generated always as identity primary key,
  subject_kind text not null check (subject_kind in ('wish_list', 'overseas_site')),
  subject_id bigint not null,
  body text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  updated_by uuid,
  removed_at timestamptz,
  removed_by uuid
);
create index if not exists record_notes_subject on public.record_notes (subject_kind, subject_id) where removed_at is null;

create table if not exists public.record_note_files (
  id bigint generated always as identity primary key,
  note_id bigint not null references public.record_notes(id),
  storage_path text not null unique,
  file_name text not null,
  content_type text,
  byte_size integer,
  uploaded_at timestamptz not null default now(),
  uploaded_by uuid default auth.uid(),
  removed_at timestamptz,
  removed_by uuid
);
create index if not exists record_note_files_note on public.record_note_files (note_id) where removed_at is null;

alter table public.record_notes enable row level security;
alter table public.record_note_files enable row level security;

create or replace function public.record_note_can(p_kind text, p_write boolean)
returns boolean language sql stable security definer set search_path = '' as $$
  select case p_kind
    when 'wish_list' then case when p_write then public.purchase_request_can_edit() else public.purchase_request_can_view() end
    when 'overseas_site' then case when p_write then public.overseas_can_edit() else public.overseas_can_view() end
    else false end;
$$;
revoke all on function public.record_note_can(text, boolean) from public, anon;
grant execute on function public.record_note_can(text, boolean) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit)
values ('note-files', 'note-files', false, 20971520)
on conflict (id) do nothing;

-- [p_name]: <note id>/<file>.
create or replace function public.note_file_allowed(p_name text, p_write boolean)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.record_notes n
     where n.id::text = split_part(coalesce(p_name, ''), '/', 1)
       and n.removed_at is null
       and public.record_note_can(n.subject_kind, p_write));
$$;
grant execute on function public.note_file_allowed(text, boolean) to authenticated;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'note-files: editors upload') then
    create policy "note-files: editors upload" on storage.objects
      for insert to authenticated
      with check (bucket_id = 'note-files' and public.note_file_allowed(name, true));
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'note-files: viewers read') then
    create policy "note-files: viewers read" on storage.objects
      for select to authenticated
      using (bucket_id = 'note-files' and public.note_file_allowed(name, false));
  end if;
end $$;

create or replace function public.record_notes_list(p_kind text, p_subject_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.record_note_can(p_kind, false) then
    raise exception 'not permitted';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', n.id,
      'body', n.body,
      'created_at', n.created_at,
      'updated_at', n.updated_at,
      'created_by_name', (select coalesce(u.name, u.email) from public.app_users u where u.id = n.created_by),
      'files', coalesce((select jsonb_agg(jsonb_build_object(
                  'id', f.id, 'file_name', f.file_name, 'storage_path', f.storage_path,
                  'content_type', f.content_type, 'byte_size', f.byte_size) order by f.id)
                 from public.record_note_files f where f.note_id = n.id and f.removed_at is null), '[]'::jsonb)
    ) order by n.created_at desc, n.id desc)
      from public.record_notes n
     where n.subject_kind = p_kind and n.subject_id = p_subject_id and n.removed_at is null), '[]'::jsonb);
end;
$$;

create or replace function public.record_note_write(p_id bigint, p_kind text, p_subject_id bigint, p_body text)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
  v_kind text;
begin
  if p_id is null then
    if not public.record_note_can(p_kind, true) then
      raise exception 'not permitted';
    end if;
    insert into public.record_notes (subject_kind, subject_id, body)
    values (p_kind, p_subject_id, coalesce(p_body, ''))
    returning id into v_id;
    return v_id;
  end if;
  select subject_kind into v_kind from public.record_notes where id = p_id and removed_at is null;
  if v_kind is null then
    raise exception 'note % not found', p_id;
  end if;
  if not public.record_note_can(v_kind, true) then
    raise exception 'not permitted';
  end if;
  update public.record_notes set body = coalesce(p_body, ''), updated_at = now(), updated_by = auth.uid()
   where id = p_id;
  return p_id;
end;
$$;

create or replace function public.record_note_remove(p_id bigint)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_kind text;
begin
  select subject_kind into v_kind from public.record_notes where id = p_id and removed_at is null;
  if v_kind is null then
    return false;
  end if;
  if not public.record_note_can(v_kind, true) then
    raise exception 'not permitted';
  end if;
  update public.record_notes set removed_at = now(), removed_by = auth.uid() where id = p_id;
  return true;
end;
$$;

create or replace function public.record_note_file_add(
  p_note_id bigint, p_path text, p_name text, p_type text default null, p_size integer default null)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_kind text;
  v_id bigint;
begin
  select subject_kind into v_kind from public.record_notes where id = p_note_id and removed_at is null;
  if v_kind is null then
    raise exception 'note % not found', p_note_id;
  end if;
  if not public.record_note_can(v_kind, true) then
    raise exception 'not permitted';
  end if;
  if split_part(coalesce(p_path, ''), '/', 1) <> p_note_id::text then
    raise exception 'note_file_path';
  end if;
  insert into public.record_note_files (note_id, storage_path, file_name, content_type, byte_size)
  values (p_note_id, p_path, p_name, p_type, p_size)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.record_note_file_remove(p_id bigint)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_kind text;
begin
  select n.subject_kind into v_kind
    from public.record_note_files f join public.record_notes n on n.id = f.note_id
   where f.id = p_id and f.removed_at is null;
  if v_kind is null then
    return false;
  end if;
  if not public.record_note_can(v_kind, true) then
    raise exception 'not permitted';
  end if;
  update public.record_note_files set removed_at = now(), removed_by = auth.uid() where id = p_id;
  return true;
end;
$$;

revoke all on function public.record_notes_list(text, bigint) from public, anon;
revoke all on function public.record_note_write(bigint, text, bigint, text) from public, anon;
revoke all on function public.record_note_remove(bigint) from public, anon;
revoke all on function public.record_note_file_add(bigint, text, text, text, integer) from public, anon;
revoke all on function public.record_note_file_remove(bigint) from public, anon;
grant execute on function public.record_notes_list(text, bigint) to authenticated;
grant execute on function public.record_note_write(bigint, text, bigint, text) to authenticated;
grant execute on function public.record_note_remove(bigint) to authenticated;
grant execute on function public.record_note_file_add(bigint, text, text, text, integer) to authenticated;
grant execute on function public.record_note_file_remove(bigint) to authenticated;

-- ------------------------------------------------------------ sites

create or replace function public.overseas_sites_list(p_include_archived boolean default false)
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when not public.overseas_can_view() then '[]'::jsonb else coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', s.id, 'name', s.name, 'kind', s.kind, 'country', s.country, 'city', s.city,
      'contact', s.contact, 'note', s.note, 'archived_at', s.archived_at, 'updated_at', s.updated_at,
      'latest', (select jsonb_build_object('id', i.id, 'as_of', i.as_of, 'line_count', i.line_count,
                                           'units', i.units, 'file_name', i.file_name, 'read_by', i.read_by,
                                           'created_at', i.created_at)
                   from public.overseas_stock_imports i where i.id = public.overseas_latest_import(s.id)),
      'import_count', (select count(*) from public.overseas_stock_imports i where i.site_id = s.id and i.undone_at is null),
      'note_count', (select count(*) from public.record_notes n
                      where n.subject_kind = 'overseas_site' and n.subject_id = s.id and n.removed_at is null)
    ) order by s.archived_at nulls first, s.name, s.id)
      from public.overseas_sites s
     where p_include_archived or s.archived_at is null), '[]'::jsonb) end;
$$;

create or replace function public.overseas_site_save(p jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint := (p->>'id')::bigint;
  v_name text := nullif(btrim(coalesce(p->>'name', '')), '');
  v_kind text := coalesce(nullif(p->>'kind', ''), 'branch');
begin
  if not public.overseas_can_edit() then
    raise exception 'not permitted';
  end if;
  if v_name is null then
    raise exception 'overseas_site_name_required';
  end if;
  if v_id is null then
    insert into public.overseas_sites (name, kind, country, city, contact, note)
    values (v_name, v_kind, nullif(btrim(coalesce(p->>'country', '')), ''), nullif(btrim(coalesce(p->>'city', '')), ''),
            nullif(btrim(coalesce(p->>'contact', '')), ''), nullif(btrim(coalesce(p->>'note', '')), ''))
    returning id into v_id;
  else
    update public.overseas_sites set
      name = v_name, kind = v_kind,
      country = nullif(btrim(coalesce(p->>'country', '')), ''),
      city = nullif(btrim(coalesce(p->>'city', '')), ''),
      contact = nullif(btrim(coalesce(p->>'contact', '')), ''),
      note = nullif(btrim(coalesce(p->>'note', '')), ''),
      updated_at = now()
     where id = v_id;
    if not found then
      raise exception 'overseas site % not found', v_id;
    end if;
  end if;
  return v_id;
end;
$$;

create or replace function public.overseas_site_archive(p_id bigint, p_archived boolean)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if not public.overseas_can_edit() then
    raise exception 'not permitted';
  end if;
  update public.overseas_sites set archived_at = case when p_archived then now() end, updated_at = now()
   where id = p_id;
  return found;
end;
$$;

-- ------------------------------------------------------------ stock files

create or replace function public.overseas_stock_import(p jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_site bigint := (p->>'site_id')::bigint;
  v_id bigint;
  v_lines integer;
  v_units numeric;
begin
  if not public.overseas_can_edit() then
    raise exception 'not permitted';
  end if;
  if not exists (select 1 from public.overseas_sites where id = v_site and archived_at is null) then
    raise exception 'overseas site % not found', v_site;
  end if;
  if jsonb_typeof(p->'lines') <> 'array' or jsonb_array_length(p->'lines') = 0 then
    raise exception 'overseas_no_lines';
  end if;
  insert into public.overseas_stock_imports (site_id, as_of, file_name, storage_path, file_size, file_fingerprint,
                                             sheet_name, columns, read_by, note)
  values (v_site, coalesce((p->>'as_of')::date, current_date), nullif(p->>'file_name', ''), nullif(p->>'storage_path', ''),
          (p->>'file_size')::bigint, nullif(p->>'fingerprint', ''), nullif(p->>'sheet_name', ''),
          case when jsonb_typeof(p->'columns') = 'object' then p->'columns' end,
          coalesce(nullif(p->>'read_by', ''), 'sheet'), nullif(btrim(coalesce(p->>'note', '')), ''))
  returning id into v_id;
  insert into public.overseas_stock_lines (import_id, row_no, jan, code, name, maker, quantity, unit, raw)
  select v_id, (l->>'row_no')::int, nullif(btrim(coalesce(l->>'jan', '')), ''), nullif(btrim(coalesce(l->>'code', '')), ''),
         nullif(btrim(coalesce(l->>'name', '')), ''), nullif(btrim(coalesce(l->>'maker', '')), ''),
         coalesce((l->>'quantity')::numeric, 0), nullif(btrim(coalesce(l->>'unit', '')), ''),
         case when jsonb_typeof(l->'raw') = 'object' then l->'raw' end
    from jsonb_array_elements(p->'lines') l;
  select count(*), coalesce(sum(quantity), 0) into v_lines, v_units from public.overseas_stock_lines where import_id = v_id;
  update public.overseas_stock_imports set line_count = v_lines, units = v_units where id = v_id;
  update public.overseas_sites set updated_at = now() where id = v_site;
  return v_id;
end;
$$;

create or replace function public.overseas_stock_imports(p_site_id bigint)
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when not public.overseas_can_view() then '[]'::jsonb else coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', i.id, 'site_id', i.site_id, 'as_of', i.as_of, 'file_name', i.file_name, 'storage_path', i.storage_path,
      'sheet_name', i.sheet_name, 'read_by', i.read_by, 'line_count', i.line_count, 'units', i.units, 'note', i.note,
      'created_at', i.created_at, 'undone_at', i.undone_at,
      'created_by_name', (select coalesce(u.name, u.email) from public.app_users u where u.id = i.created_by)
    ) order by i.as_of desc, i.id desc)
      from public.overseas_stock_imports i where i.site_id = p_site_id), '[]'::jsonb) end;
$$;

create or replace function public.overseas_stock_undo(p_import_id bigint)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if not public.overseas_can_edit() then
    raise exception 'not permitted';
  end if;
  update public.overseas_stock_imports set undone_at = now(), undone_by = auth.uid()
   where id = p_import_id and undone_at is null;
  return found;
end;
$$;

-- An import's rows; null: [p_site_id]'s stock now. Each row says whether its
-- JAN is in our library (pointed out only).
create or replace function public.overseas_stock_lines(p_import_id bigint, p_site_id bigint default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_id bigint := coalesce(p_import_id, public.overseas_latest_import(p_site_id));
begin
  if not public.overseas_can_view() then
    raise exception 'not permitted';
  end if;
  if v_id is null then
    return jsonb_build_object('import', null, 'lines', '[]'::jsonb);
  end if;
  return jsonb_build_object(
    'import', (select to_jsonb(i) - 'created_by' - 'undone_by' from public.overseas_stock_imports i where i.id = v_id),
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', l.id, 'row_no', l.row_no, 'jan', l.jan, 'code', l.code, 'name', l.name, 'maker', l.maker,
        'quantity', l.quantity, 'unit', l.unit, 'raw', l.raw,
        'ours', (select pr.name from public.products pr where l.jan is not null and pr.jan_code = l.jan limit 1)
      ) order by l.row_no nulls last, l.id)
        from public.overseas_stock_lines l where l.import_id = v_id), '[]'::jsonb));
end;
$$;

-- Each product across the sites' stock now: what each holds, as of when.
create or replace function public.overseas_stock_overview(p_q text default null, p_limit integer default 500)
returns jsonb language sql stable security definer set search_path = '' as $$
  with cur as (
    select s.id as site_id, s.name as site_name, s.kind, s.country, i.id as import_id, i.as_of
      from public.overseas_sites s
      join public.overseas_stock_imports i on i.id = public.overseas_latest_import(s.id)
     where s.archived_at is null
  ), rows as (
    select coalesce(l.jan, 'code:' || lower(coalesce(l.code, '')) || ':' || lower(coalesce(l.name, ''))) as k,
           l.jan, l.code, l.name, l.maker, l.quantity, l.unit, c.site_id, c.site_name, c.kind, c.country, c.as_of
      from public.overseas_stock_lines l join cur c on c.import_id = l.import_id
     where p_q is null or btrim(p_q) = ''
        or concat_ws(' ', l.jan, l.code, l.name, l.maker) ilike '%' || btrim(p_q) || '%'
  ), g as (
    select k, max(jan) as jan, max(code) as code, max(name) as name, max(maker) as maker, max(unit) as unit,
           sum(quantity) as total,
           jsonb_agg(jsonb_build_object('site_id', site_id, 'site_name', site_name, 'kind', kind, 'country', country,
                                        'quantity', quantity, 'as_of', as_of) order by site_name) as sites
      from rows group by k
  )
  select case when not public.overseas_can_view() then '[]'::jsonb else coalesce((
    select jsonb_agg(jsonb_build_object(
      'jan', g.jan, 'code', g.code, 'name', g.name, 'maker', g.maker, 'unit', g.unit, 'total', g.total, 'sites', g.sites,
      'ours', (select pr.name from public.products pr where g.jan is not null and pr.jan_code = g.jan limit 1)
    ) order by g.total desc, g.name)
      from (select * from g order by total desc, name limit greatest(1, least(coalesce(p_limit, 500), 5000))) g), '[]'::jsonb) end;
$$;

revoke all on function public.overseas_sites_list(boolean) from public, anon;
revoke all on function public.overseas_site_save(jsonb) from public, anon;
revoke all on function public.overseas_site_archive(bigint, boolean) from public, anon;
revoke all on function public.overseas_stock_import(jsonb) from public, anon;
revoke all on function public.overseas_stock_imports(bigint) from public, anon;
revoke all on function public.overseas_stock_undo(bigint) from public, anon;
revoke all on function public.overseas_stock_lines(bigint, bigint) from public, anon;
revoke all on function public.overseas_stock_overview(text, integer) from public, anon;
grant execute on function public.overseas_sites_list(boolean) to authenticated;
grant execute on function public.overseas_site_save(jsonb) to authenticated;
grant execute on function public.overseas_site_archive(bigint, boolean) to authenticated;
grant execute on function public.overseas_stock_import(jsonb) to authenticated;
grant execute on function public.overseas_stock_imports(bigint) to authenticated;
grant execute on function public.overseas_stock_undo(bigint) to authenticated;
grant execute on function public.overseas_stock_lines(bigint, bigint) to authenticated;
grant execute on function public.overseas_stock_overview(text, integer) to authenticated;

-- ------------------------------------------------------------ wish lists

do $$
declare
  d text;
  r text;
begin
  d := pg_get_functiondef('public.purchase_requests_list(integer)'::regprocedure);
  r := replace(d, 'r.file_name, r.storage_path, r.created_at,',
    'r.file_name, r.storage_path, r.created_at, (select count(*) from public.record_notes n where n.subject_kind = ''wish_list'' and n.subject_id = r.id and n.removed_at is null) as note_count,');
  if r = d then
    raise exception 'purchase_requests_list: the text to change was not found';
  end if;
  execute r;
end;
$$;
