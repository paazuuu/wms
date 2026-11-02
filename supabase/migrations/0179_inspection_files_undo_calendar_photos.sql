-- 0179: inspecting with the delivery note in hand, kept and undoable.
--
-- * jan_photos: a picture found for a JAN on the web, kept (product-images,
--   jan/<JAN>.<ext>) so the same JAN is never looked up twice — before a
--   product has it, and for a product registered again later. A JAN tried
--   without finding one is noted too (found = false).
-- * import_documents.inspection_import_id: the delivery note photographed
--   while inspecting a stock file, kept with that import to look back at.
--   ocr documents are seen by those who inspect too.
-- * stock_file_uninspect: a line checked in by mistake taken back by those
--   who inspect — its stock booked back (修正), the line waiting again, the
--   import waiting again if it was done.
-- * stock_file_inspection_calendar: the days lines were checked in, by
--   import: how many, by whom — the inspection's own calendar.
-- No foreign keys on the new columns and table: システムの初期化 empties
-- import_documents and master_imports together.

create table if not exists public.jan_photos (
  jan text primary key check (jan ~ '^[0-9]{8,14}$'),
  storage_path text,
  content_type text,
  byte_size integer,
  page_url text,
  image_url text,
  found boolean not null default false,
  reason text,
  looked_at timestamptz not null default now()
);
alter table public.jan_photos enable row level security;

alter table public.import_documents add column if not exists inspection_import_id bigint;
create index if not exists import_documents_inspection on public.import_documents (inspection_import_id)
  where inspection_import_id is not null;

create or replace function public.can_inspect_stock_files()
returns boolean
language sql stable security definer set search_path = '' as $$
  select public.has_permission('inspection.confirm') or public.has_permission('inventory.adjust');
$$;
grant execute on function public.can_inspect_stock_files() to authenticated;

create or replace function public.import_document_visible(p_purpose text, p_warehouse_id bigint)
returns boolean
language sql stable security definer set search_path = '' as $$
  select (public.has_permission('audit.view')
          or case when p_purpose = 'ocr' then public.has_permission('receiving.view')
                                               or public.has_permission('receiving.confirm')
                                               or public.can_inspect_stock_files()
                                               or public.has_permission('inspection.view')
                  when p_purpose = 'plan' then public.has_permission('receiving.view')
                                               or public.has_permission('receiving.confirm')
                  when p_purpose = 'shipment' then public.has_permission('pack.complete')
                  else public.has_permission('product.view') end)
     and (p_warehouse_id is null or public.can_access_warehouse(p_warehouse_id));
$$;

-- The note read while inspecting [p_import_id], kept with it.
create or replace function public.stock_file_link_inspection_document(p_import_id bigint, p_document_id bigint)
returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not public.can_inspect_stock_files() then
    raise exception 'not permitted: inspection.confirm required';
  end if;
  if not exists (select 1 from public.master_imports where id = p_import_id and source = 'stock_file') then
    raise exception 'import % not found', p_import_id;
  end if;
  update public.import_documents set inspection_import_id = p_import_id
   where id = p_document_id and purpose = 'ocr'
     and (inspection_import_id is null or inspection_import_id = p_import_id);
  return found;
end;
$$;
revoke all on function public.stock_file_link_inspection_document(bigint, bigint) from public, anon;
grant execute on function public.stock_file_link_inspection_document(bigint, bigint) to authenticated;

create or replace function public.stock_file_inspection_documents(p_import_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.can_inspect_stock_files() or public.master_import_viewer()) then
    raise exception 'not permitted: inspection.confirm required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', d.id, 'file_name', d.file_name, 'content_type', d.content_type, 'storage_path', d.storage_path,
             'byte_size', d.byte_size, 'uploaded_at', d.uploaded_at,
             'uploaded_by_name', public.user_display_name(d.uploaded_by))
           order by d.uploaded_at)
      from public.import_documents d
     where d.inspection_import_id = p_import_id), '[]'::jsonb);
end;
$$;
revoke all on function public.stock_file_inspection_documents(bigint) from public, anon;
grant execute on function public.stock_file_inspection_documents(bigint) to authenticated;

-- A line checked in by mistake, taken back.
create or replace function public.stock_file_uninspect(p_id bigint, p_line_no integer)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_imp public.master_imports;
  l public.master_import_lines;
  v_now int;
  v_name text;
  v_m bigint;
begin
  if not public.can_inspect_stock_files() then
    raise exception 'not permitted: inspection.confirm required';
  end if;
  select * into v_imp from public.master_imports where id = p_id for update;
  if v_imp.id is null or v_imp.source <> 'stock_file' or v_imp.undone_at is not null
     or v_imp.status not in ('awaiting_inspection', 'stock_done') then
    raise exception 'import % not found', p_id;
  end if;
  if not public.can_access_warehouse(v_imp.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  select * into l from public.master_import_lines where import_id = p_id and line_no = p_line_no for update;
  if l.id is null or l.inspected_at is null then
    raise exception 'line % is not checked in', p_line_no;
  end if;
  if coalesce(l.added, 0) <> 0 then
    select coalesce(on_hand, 0) into v_now from public.stock_levels
     where warehouse_id = v_imp.warehouse_id and jan_code = l.jan_code for update;
    if coalesce(v_now, 0) - l.added < 0 then
      raise exception 'uninspect_below_zero: % now %, the line added %', l.jan_code, coalesce(v_now, 0), l.added;
    end if;
    select name into v_name from public.products where id = l.product_id;
    v_m := public.master_import_post(v_imp.warehouse_id, l.jan_code, l.product_id, -l.added, 'CORRECTION',
      '在庫ファイル取込 #' || p_id || ' の検品取り消し', p_id::text, v_name);
  end if;
  update public.master_import_lines set
    inspected_at = null, inspected_by = null, inspected_quantity = null,
    on_hand_before = null, added = null, on_hand_after = null,
    movement_ids = coalesce(movement_ids, '{}') || array_remove(array[v_m], null)
   where id = l.id;
  update public.master_imports set
    status = 'awaiting_inspection', stock_at = null, stock_by = null,
    stock_lines = (select count(*) from public.master_import_lines where import_id = p_id and inspected_at is not null),
    stock_added = (select coalesce(sum(added), 0) from public.master_import_lines where import_id = p_id),
    updated_at = now()
   where id = p_id;
  perform public.log_audit('inventory.stock_file_uninspected', 'master_import', p_id::text, v_imp.warehouse_id,
    jsonb_build_object('line_no', p_line_no, 'jan_code', l.jan_code, 'quantity', l.added));
  return jsonb_build_object('import_id', p_id, 'line_no', p_line_no, 'quantity', coalesce(l.added, 0));
end;
$$;
revoke all on function public.stock_file_uninspect(bigint, integer) from public, anon;
grant execute on function public.stock_file_uninspect(bigint, integer) to authenticated;

-- The days lines were checked in (Japan time), by import.
create or replace function public.stock_file_inspection_calendar(p_from date, p_to date)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.can_inspect_stock_files() or public.master_import_viewer()) then
    raise exception 'not permitted: inspection.confirm required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'import_id', x.import_id, 'day', x.day, 'lines', x.lines, 'units', x.units,
             'first_at', x.first_at, 'last_at', x.last_at, 'by', x.by_names,
             'original_name', m.original_name, 'warehouse_name', w.name, 'status', m.status,
             'line_count', (select count(*) from public.master_import_lines t where t.import_id = m.id),
             'documents', (select count(*) from public.import_documents d where d.inspection_import_id = m.id))
           order by x.day, x.first_at)
      from (
        select l.import_id, (l.inspected_at at time zone 'Asia/Tokyo')::date as day,
               count(*) as lines, coalesce(sum(l.inspected_quantity), 0) as units,
               min(l.inspected_at) as first_at, max(l.inspected_at) as last_at,
               string_agg(distinct public.user_display_name(l.inspected_by), '、') as by_names
          from public.master_import_lines l
         where l.inspected_at is not null
           and (l.inspected_at at time zone 'Asia/Tokyo')::date between p_from and p_to
         group by l.import_id, (l.inspected_at at time zone 'Asia/Tokyo')::date) x
      join public.master_imports m on m.id = x.import_id
      left join public.warehouses w on w.id = m.warehouse_id
     where m.source = 'stock_file' and m.undone_at is null
       and (m.warehouse_id is null or public.can_access_warehouse(m.warehouse_id))), '[]'::jsonb);
end;
$$;
revoke all on function public.stock_file_inspection_calendar(date, date) from public, anon;
grant execute on function public.stock_file_inspection_calendar(date, date) to authenticated;
