-- 0181: 予定外の入荷 — goods a regular supplier brings without an order or
-- an invoice first (no file to import), registered on the spot from the
-- delivery note (or by scanning) and checked in at once.
--
-- * An unplanned receipt is a stock file import like any other (取込 #…),
--   marked kind = 'unplanned', with the supplier as read from the note
--   (note_supplier). Its lines are checked in as it is registered, so its
--   stock goes in at once; 取り消し, 検品時のファイル and 検品履歴カレンダー
--   work as for any import.
-- * It is not a purchase to pay or to give the accountant: 支払い and
--   税理士用ファイル leave it out. The invoice that comes later is.
-- * The invoice imported later through 発注 is not to add the same goods
--   again: unplanned_open_lines finds what was received and not yet
--   invoiced, and stock_file_cover_lines checks those invoice lines in as
--   already received (0 added), each tied to the line that brought the
--   goods (covered_by_*, and invoiced_import_id on that line).
-- * Neither side can then be taken back alone (uninspect_covered /
--   uninspect_invoiced / undo_invoiced): the invoice is undone first, which
--   frees the receipt again.
-- No foreign keys on the new columns: システムの初期化 empties
-- master_imports and its lines together.

alter table public.master_imports add column if not exists kind text;
alter table public.master_imports add column if not exists note_supplier text;
alter table public.master_import_lines add column if not exists covered_by_import_id bigint;
alter table public.master_import_lines add column if not exists covered_by_line_no integer;
alter table public.master_import_lines add column if not exists invoiced_import_id bigint;
create index if not exists master_imports_unplanned on public.master_imports (created_at) where kind = 'unplanned';
create index if not exists master_import_lines_invoiced on public.master_import_lines (invoiced_import_id)
  where invoiced_import_id is not null;

-- Registered and checked in, in one go. [p_lines]: {line_no, jan_code,
-- quantity}, products the library has (the app registers the others first).
create or replace function public.unplanned_receipt(
  p_warehouse_id bigint, p_lines jsonb, p_file_name text default null, p_file_type text default null,
  p_supplier text default null, p_document_id bigint default null, p_document_date date default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v jsonb;
  v_id bigint;
  v_in jsonb;
begin
  if not public.has_permission('inventory.adjust') then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  v := public.stock_file_stage(p_warehouse_id, p_lines, coalesce(public.tidy_text(p_file_name), '予定外の入荷'), p_file_type);
  v_id := (v->>'import_id')::bigint;
  if coalesce((v->>'lines')::int, 0) = 0 then
    raise exception 'unplanned_no_known_products';
  end if;
  update public.master_imports set
    kind = 'unplanned',
    note_supplier = public.tidy_text(p_supplier),
    document_date = coalesce(p_document_date, (now() at time zone 'Asia/Tokyo')::date),
    document_date_source = case when p_document_date is null then 'uploaded' else 'content' end
   where id = v_id;
  v_in := public.stock_file_inspect(v_id, (
    select jsonb_agg(jsonb_build_object('line_no', line_no, 'quantity', quantity))
      from public.master_import_lines where import_id = v_id));
  if p_document_id is not null then
    update public.import_documents set inspection_import_id = v_id
     where id = p_document_id and purpose = 'ocr' and inspection_import_id is null;
  end if;
  perform public.log_audit('inventory.unplanned_received', 'master_import', v_id::text, p_warehouse_id,
    jsonb_build_object('supplier', p_supplier, 'lines', v_in->'lines', 'change', v_in->'change'));
  return jsonb_build_object('import_id', v_id, 'lines', v_in->'lines', 'change', v_in->'change',
                            'skipped', v->'skipped', 'awaiting', 0, 'detail', '[]'::jsonb);
end;
$$;
revoke all on function public.unplanned_receipt(bigint, jsonb, text, text, text, bigint, date) from public, anon;
grant execute on function public.unplanned_receipt(bigint, jsonb, text, text, text, bigint, date) to authenticated;

-- What unplanned receipts brought of [p_jans] and no invoice has covered
-- yet, oldest first.
create or replace function public.unplanned_open_lines(p_jans text[], p_warehouse_id bigint default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.master_import_viewer() or public.has_permission('inventory.adjust')) then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'import_id', m.id, 'line_no', l.line_no, 'jan_code', l.jan_code, 'quantity', l.inspected_quantity,
             'name', p.name, 'supplier', m.note_supplier, 'received_at', l.inspected_at,
             'file_name', m.original_name, 'warehouse_id', m.warehouse_id)
           order by l.inspected_at, m.id, l.line_no)
      from public.master_import_lines l
      join public.master_imports m on m.id = l.import_id
      left join public.products p on p.id = l.product_id
     where m.kind = 'unplanned' and m.undone_at is null
       and l.inspected_at is not null and coalesce(l.inspected_quantity, 0) > 0
       and l.invoiced_import_id is null
       and l.jan_code = any(coalesce(p_jans, '{}'))
       and (p_warehouse_id is null or m.warehouse_id = p_warehouse_id)
       and public.can_access_warehouse(m.warehouse_id)), '[]'::jsonb);
end;
$$;
revoke all on function public.unplanned_open_lines(text[], bigint) from public, anon;
grant execute on function public.unplanned_open_lines(text[], bigint) to authenticated;

-- Lines of an invoice import already received as an unplanned receipt:
-- checked in as received (0 added), each tied to the line that brought it.
-- [p_covers]: {line_no, from_import_id, from_line_no}.
create or replace function public.stock_file_cover_lines(p_import_id bigint, p_covers jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_imp public.master_imports;
  e jsonb;
  l public.master_import_lines;
  u public.master_import_lines;
  v_now int;
  v_n int := 0;
  v_left int;
begin
  if not public.has_permission('inventory.adjust') then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  select * into v_imp from public.master_imports where id = p_import_id for update;
  if v_imp.id is null or v_imp.source <> 'stock_file' or v_imp.undone_at is not null
     or v_imp.status <> 'awaiting_inspection' or v_imp.kind is not distinct from 'unplanned' then
    raise exception 'import % not found', p_import_id;
  end if;
  if not public.can_access_warehouse(v_imp.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if jsonb_typeof(p_covers) <> 'array' then
    raise exception 'no lines to cover';
  end if;
  for e in select x.value from jsonb_array_elements(p_covers) as x(value) loop
    select * into l from public.master_import_lines
     where import_id = p_import_id and line_no = (e->>'line_no')::int for update;
    if l.id is null or l.inspected_at is not null then
      continue;
    end if;
    select li.* into u from public.master_import_lines li
      join public.master_imports m on m.id = li.import_id
     where li.import_id = (e->>'from_import_id')::bigint and li.line_no = (e->>'from_line_no')::int
       and m.kind = 'unplanned' and m.undone_at is null and m.warehouse_id = v_imp.warehouse_id
       and li.inspected_at is not null and li.invoiced_import_id is null and li.jan_code = l.jan_code
     for update of li;
    if u.id is null then
      raise exception 'cover_line_unavailable: line % (%)', l.line_no, l.jan_code;
    end if;
    select coalesce(on_hand, 0) into v_now from public.stock_levels
     where warehouse_id = v_imp.warehouse_id and jan_code = l.jan_code;
    update public.master_import_lines set
      inspected_at = now(), inspected_by = auth.uid(), inspected_quantity = 0,
      on_hand_before = coalesce(v_now, 0), added = 0, on_hand_after = coalesce(v_now, 0),
      covered_by_import_id = u.import_id, covered_by_line_no = u.line_no
     where id = l.id;
    update public.master_import_lines set invoiced_import_id = p_import_id where id = u.id;
    v_n := v_n + 1;
  end loop;
  select count(*) into v_left from public.master_import_lines where import_id = p_import_id and inspected_at is null;
  update public.master_imports set
    stock_lines = (select count(*) from public.master_import_lines where import_id = p_import_id and inspected_at is not null),
    stock_added = (select coalesce(sum(added), 0) from public.master_import_lines where import_id = p_import_id),
    status = case when v_left = 0 then 'stock_done' else status end,
    stock_at = case when v_left = 0 then now() else stock_at end,
    stock_by = case when v_left = 0 then auth.uid() else stock_by end,
    updated_at = now()
   where id = p_import_id;
  perform public.log_audit('inventory.stock_file_covered', 'master_import', p_import_id::text, v_imp.warehouse_id,
    jsonb_build_object('covered', v_n, 'left', v_left, 'covers', p_covers));
  return jsonb_build_object('import_id', p_import_id, 'covered', v_n, 'left', v_left);
end;
$$;
revoke all on function public.stock_file_cover_lines(bigint, jsonb) from public, anon;
grant execute on function public.stock_file_cover_lines(bigint, jsonb) to authenticated;

-- 0179's take-back, refusing either side of a receipt and its invoice.
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
  if l.covered_by_import_id is not null then
    raise exception 'uninspect_covered: received as 取込 #%', l.covered_by_import_id;
  end if;
  if l.invoiced_import_id is not null then
    raise exception 'uninspect_invoiced: invoiced in 取込 #%', l.invoiced_import_id;
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

-- The whole import taken back: not an unplanned receipt an invoice has
-- covered (undo the invoice first); an invoice frees what it covered.
create or replace function public.stock_file_import_undo(p_id bigint)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_imp public.master_imports;
  l record;
  v_now int;
  v_name text;
  v_lines int := 0;
  v_change int := 0;
  v_by bigint;
begin
  if not public.has_permission('inventory.adjust') then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  select * into v_imp from public.master_imports where id = p_id for update;
  if v_imp.id is null or v_imp.source <> 'stock_file' then
    raise exception 'import % not found', p_id;
  end if;
  if v_imp.undone_at is not null then
    raise exception 'import % is already undone', p_id;
  end if;
  if v_imp.warehouse_id is null or not public.can_access_warehouse(v_imp.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  select invoiced_import_id into v_by from public.master_import_lines
   where import_id = p_id and invoiced_import_id is not null limit 1;
  if v_by is not null then
    raise exception 'undo_invoiced: invoiced in 取込 #%', v_by;
  end if;
  for l in select * from public.master_import_lines where import_id = p_id and coalesce(added, 0) <> 0 loop
    select coalesce(on_hand, 0) into v_now from public.stock_levels
     where warehouse_id = v_imp.warehouse_id and jan_code = l.jan_code for update;
    if coalesce(v_now, 0) - l.added < 0 then
      raise exception 'undo would leave % below zero (now %, the import added %)', l.jan_code, coalesce(v_now, 0), l.added;
    end if;
  end loop;
  for l in select * from public.master_import_lines where import_id = p_id and coalesce(added, 0) <> 0 order by line_no loop
    select name into v_name from public.products where id = l.product_id;
    perform public.master_import_post(v_imp.warehouse_id, l.jan_code, l.product_id, -l.added, 'CORRECTION',
      '在庫ファイル取込 #' || p_id || ' の取り消し', p_id::text, v_name);
    v_lines := v_lines + 1;
    v_change := v_change - l.added;
  end loop;
  -- What this invoice covered waits for an invoice again.
  update public.master_import_lines set invoiced_import_id = null where invoiced_import_id = p_id;
  update public.master_imports set undone_at = now(), undone_by = auth.uid(), status = 'cancelled', updated_at = now()
   where id = p_id;
  perform public.log_audit('inventory.stock_file_undone', 'master_import', p_id::text, v_imp.warehouse_id,
    jsonb_build_object('lines', v_lines, 'change', v_change));
  return jsonb_build_object('import_id', p_id, 'lines', v_lines, 'change', v_change);
end;
$$;

-- 0179's inspection days, without the invoice lines checked in as already
-- received (nothing was counted then).
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
             'original_name', m.original_name, 'warehouse_name', w.name, 'status', m.status, 'kind', m.kind,
             'line_count', (select count(*) from public.master_import_lines t where t.import_id = m.id),
             'documents', (select count(*) from public.import_documents d where d.inspection_import_id = m.id))
           order by x.day, x.first_at)
      from (
        select l.import_id, (l.inspected_at at time zone 'Asia/Tokyo')::date as day,
               count(*) as lines, coalesce(sum(l.inspected_quantity), 0) as units,
               min(l.inspected_at) as first_at, max(l.inspected_at) as last_at,
               string_agg(distinct public.user_display_name(l.inspected_by), '、') as by_names
          from public.master_import_lines l
         where l.inspected_at is not null and l.covered_by_import_id is null
           and (l.inspected_at at time zone 'Asia/Tokyo')::date between p_from and p_to
         group by l.import_id, (l.inspected_at at time zone 'Asia/Tokyo')::date) x
      join public.master_imports m on m.id = x.import_id
      left join public.warehouses w on w.id = m.warehouse_id
     where m.source = 'stock_file' and m.undone_at is null
       and (m.warehouse_id is null or public.can_access_warehouse(m.warehouse_id))), '[]'::jsonb);
end;
$$;

-- One import with its lines: the supplier an unplanned receipt was read
-- from, and each line's receipt or invoice.
create or replace function public.master_import_detail(p_id bigint, p_warehouse_id bigint default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_head jsonb;
begin
  if not (public.master_import_viewer() or public.has_permission('inspection.confirm')) then
    raise exception 'not permitted: product.view required';
  end if;
  if p_warehouse_id is not null and not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  select (to_jsonb(m) - 'company_id') || jsonb_build_object(
           'supplier_name', coalesce(s.name, d.supplier_name, m.note_supplier),
           'registration_number', d.registration_number,
           'doc_number', d.doc_number)
    into v_head
    from public.master_imports m
    left join public.import_documents d on d.id = m.document_id
    left join public.delivery_suppliers s on s.id = coalesce(m.supplier_id, d.supplier_id)
   where m.id = p_id;
  if v_head is null then
    raise exception 'import % not found', p_id;
  end if;
  return v_head || jsonb_build_object('lines', coalesce((
    select jsonb_agg(jsonb_build_object(
             'line_no', l.line_no, 'jan_code', l.jan_code, 'product_id', l.product_id,
             'name', p.name, 'name_en', p.name_en, 'maker', p.maker, 'sku', p.sku,
             'supplier_name', l.supplier_name, 'quantity', l.quantity, 'master_status', l.master_status,
             'on_hand_before', l.on_hand_before, 'on_hand_set', l.on_hand_set, 'added', l.added,
             'on_hand_after', l.on_hand_after,
             'inspected_at', l.inspected_at, 'inspected_quantity', l.inspected_quantity,
             'inspected_by_name', (select coalesce(u.name, u.email) from public.app_users u where u.id = l.inspected_by),
             'covered_by_import_id', l.covered_by_import_id, 'covered_by_line_no', l.covered_by_line_no,
             'invoiced_import_id', l.invoiced_import_id,
             'on_hand_now', case when p_warehouse_id is null then null else coalesce((
                select sl.on_hand from public.stock_levels sl
                 where sl.warehouse_id = p_warehouse_id and sl.jan_code = l.jan_code), 0) end)
           order by l.line_no)
      from public.master_import_lines l
      left join public.products p on p.id = l.product_id
     where l.import_id = p_id), '[]'::jsonb));
end;
$$;

create or replace function public.master_imports_list(p_limit integer default 50)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when not public.master_import_viewer() then '[]'::jsonb else coalesce((
    select jsonb_agg(to_jsonb(x) order by x.created_at desc, x.id desc)
      from (select m.id, m.status, m.source, m.kind, m.supplier_id, coalesce(s.name, m.note_supplier) as supplier_name,
                   m.warehouse_id,
                   w.name as warehouse_name, m.original_name, m.original_path, m.converted_name, m.converted_path,
                   m.corrected_name, m.corrected_path, m.line_count, m.issues, m.master_created, m.master_updated,
                   m.master_mapped, m.stock_lines, m.stock_added, m.created_at, m.master_at, m.stock_at,
                   m.undone_at, m.document_date, m.document_date_source, m.paid, m.note,
                   (select coalesce(u.name, u.email) from public.app_users u where u.id = m.created_by) as created_by_name
              from public.master_imports m
              left join public.delivery_suppliers s on s.id = m.supplier_id
              left join public.warehouses w on w.id = m.warehouse_id
             order by m.created_at desc, m.id desc
             limit greatest(1, least(coalesce(p_limit, 50), 200))) x), '[]'::jsonb) end;
$$;

-- 取込カレンダー: an unplanned receipt is shown as one (no payment labels).
create or replace function public.stock_file_calendar(p_from date, p_to date)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when not public.master_import_viewer() then '[]'::jsonb else coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', m.id, 'day', d.day, 'day_kind', d.kind,
             'document_date', m.document_date, 'document_date_source', m.document_date_source,
             'created_at', m.created_at, 'original_name', m.original_name, 'warehouse_name', w.name,
             'status', m.status, 'undone_at', m.undone_at, 'line_count', m.line_count,
             'stock_lines', m.stock_lines, 'stock_added', m.stock_added, 'paid', m.paid, 'note', m.note,
             'kind', m.kind, 'supplier', m.note_supplier,
             'proof_count', (select count(*) from public.payment_proofs p where p.import_id = m.id and p.removed_at is null))
           order by d.day, m.id)
      from public.master_imports m
      cross join lateral (
        select v.day, case when count(*) > 1 then 'both' else min(v.kind) end as kind
          from (values (m.document_date, 'document'),
                       ((m.created_at at time zone 'Asia/Tokyo')::date, 'imported')) v(day, kind)
         where v.day is not null
         group by v.day) d
      left join public.warehouses w on w.id = m.warehouse_id
     where m.source = 'stock_file' and d.day between p_from and p_to
       and (m.warehouse_id is null or public.can_access_warehouse(m.warehouse_id))), '[]'::jsonb) end;
$$;

-- 税理士用ファイル: purchases are the invoices, not the goods received
-- before them.
create or replace function public.tax_purchases(p_from date, p_to date)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.can_view_purchase_books() then
    raise exception 'not permitted: report.view required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', m.id, 'day', d.day, 'document_date', m.document_date,
             'document_date_source', m.document_date_source,
             'created_at', m.created_at, 'status', m.status,
             'original_name', m.original_name, 'original_path', m.original_path, 'original_type', m.original_type,
             'paid', m.paid, 'paid_at', m.paid_at, 'note', m.note,
             'warehouse_name', w.name, 'read_lines', coalesce(m.read_lines, '[]'::jsonb),
             'document', case when doc.id is null then null else jsonb_build_object(
               'id', doc.id, 'supplier_name', doc.supplier_name, 'registration_number', doc.registration_number,
               'doc_number', doc.doc_number, 'doc_date', doc.doc_date, 'addressee', doc.addressee,
               'totals', doc.totals, 'storage_path', doc.storage_path, 'file_name', doc.file_name,
               'content_type', doc.content_type, 'sha256', doc.sha256, 'byte_size', doc.byte_size) end)
           order by d.day, m.id)
      from public.master_imports m
      cross join lateral (select coalesce(m.document_date, (m.created_at at time zone 'Asia/Tokyo')::date) as day) d
      left join public.import_documents doc on doc.id = m.document_id
      left join public.warehouses w on w.id = m.warehouse_id
     where m.source = 'stock_file' and m.undone_at is null and m.kind is distinct from 'unplanned'
       and m.status in ('stock_done', 'awaiting_inspection')
       and d.day between p_from and p_to), '[]'::jsonb);
end;
$$;

-- 支払い (0171/0172): the same — what is paid is the invoice. payments_list
-- is long; its two "which imports" conditions are narrowed in place.
do $$
declare
  v text := pg_get_functiondef('public.payments_list(date, date, boolean)'::regprocedure);
  v_new text;
begin
  v_new := replace(v, 'where m.source = ''stock_file'' and m.undone_at is null',
                      'where m.source = ''stock_file'' and m.undone_at is null and m.kind is distinct from ''unplanned''');
  v_new := replace(v_new, 'where o.id <> m.id and o.source = ''stock_file'' and o.undone_at is null',
                      'where o.id <> m.id and o.source = ''stock_file'' and o.undone_at is null and o.kind is distinct from ''unplanned''');
  if v_new = v or position('m.kind is distinct from' in v_new) = 0 or position('o.kind is distinct from' in v_new) = 0 then
    raise exception 'payments_list was not as expected';
  end if;
  execute v_new;
end;
$$;
