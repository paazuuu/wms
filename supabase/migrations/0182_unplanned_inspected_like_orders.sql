-- 0182: 予定外の入荷 goes the way 発注 goes — the note uploaded, what the AI
-- read checked beside it, the products registered, then the ordinary
-- 検品 screen with every line ticked.
--
-- * unplanned_register_products: the products the library lacks, made from
--   the note (JAN, name, maker, 品番) by whoever adjusts stock — not only
--   those who manage products. Its maker is the note's, else 「メーカー未確認」
--   to put right later.
-- * unplanned_stage: the lines kept for inspection as 予定外の入荷 (kind
--   unplanned, the supplier and date read from the note, the note kept as
--   検品時のファイル). Nothing is in stock until 検品完了.
-- * unplanned_close_lines: lines left unticked when the rest are checked in
--   — not delivered — closed (nothing added, not_delivered), so the receipt
--   does not wait for goods that are not coming. 取り消し opens one again.
-- * 検品履歴カレンダー leaves the closed lines out; the import's detail says
--   which they are.

alter table public.master_import_lines add column if not exists not_delivered boolean not null default false;

create or replace function public.unplanned_register_products(p_lines jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  e jsonb;
  v_company bigint := (select id from public.companies order by id limit 1);
  v_jan text;
  v_name text;
  v_made text[] := '{}';
begin
  if not public.has_permission('inventory.adjust') then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  if jsonb_typeof(p_lines) <> 'array' then
    raise exception 'no lines';
  end if;
  for e in select x.value from jsonb_array_elements(p_lines) as x(value) loop
    v_jan := regexp_replace(coalesce(e->>'jan_code', ''), '[^0-9]', '', 'g');
    if v_jan !~ '^[0-9]{8,14}$' or v_jan = any(v_made)
       or exists (select 1 from public.products where jan_code = v_jan) then
      continue;
    end if;
    v_name := coalesce(public.tidy_text(e->>'name'), public.tidy_text(e->>'code'), v_jan);
    insert into public.products (company_id, jan_code, name, maker, sku, base_name)
    values (v_company, v_jan, v_name, coalesce(public.tidy_text(e->>'maker'), 'メーカー未確認'),
            public.tidy_text(e->>'code'), v_name);
    v_made := v_made || v_jan;
  end loop;
  if cardinality(v_made) > 0 then
    perform public.log_audit('product.unplanned_registered', 'product', null, null,
      jsonb_build_object('jans', to_jsonb(v_made)));
  end if;
  return jsonb_build_object('created', cardinality(v_made), 'jans', to_jsonb(v_made));
end;
$$;
revoke all on function public.unplanned_register_products(jsonb) from public, anon;
grant execute on function public.unplanned_register_products(jsonb) to authenticated;

create or replace function public.unplanned_stage(
  p_warehouse_id bigint, p_lines jsonb, p_file_name text default null, p_file_type text default null,
  p_supplier text default null, p_document_id bigint default null, p_document_date date default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v jsonb;
  v_id bigint;
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
  if p_document_id is not null then
    update public.import_documents set inspection_import_id = v_id
     where id = p_document_id and purpose = 'ocr' and inspection_import_id is null;
  end if;
  perform public.log_audit('inventory.unplanned_staged', 'master_import', v_id::text, p_warehouse_id,
    jsonb_build_object('supplier', p_supplier, 'lines', v->'lines'));
  return v;
end;
$$;
revoke all on function public.unplanned_stage(bigint, jsonb, text, text, text, bigint, date) from public, anon;
grant execute on function public.unplanned_stage(bigint, jsonb, text, text, text, bigint, date) to authenticated;

create or replace function public.unplanned_close_lines(p_import_id bigint, p_line_nos integer[])
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_imp public.master_imports;
  v_n int;
  v_left int;
begin
  if not public.can_inspect_stock_files() then
    raise exception 'not permitted: inspection.confirm required';
  end if;
  select * into v_imp from public.master_imports where id = p_import_id for update;
  if v_imp.id is null or v_imp.kind is distinct from 'unplanned' or v_imp.undone_at is not null
     or v_imp.status <> 'awaiting_inspection' then
    raise exception 'import % not found', p_import_id;
  end if;
  if not public.can_access_warehouse(v_imp.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  update public.master_import_lines l set
    inspected_at = now(), inspected_by = auth.uid(), inspected_quantity = 0,
    on_hand_before = coalesce((select s.on_hand from public.stock_levels s
                                where s.warehouse_id = v_imp.warehouse_id and s.jan_code = l.jan_code), 0),
    added = 0,
    on_hand_after = coalesce((select s.on_hand from public.stock_levels s
                               where s.warehouse_id = v_imp.warehouse_id and s.jan_code = l.jan_code), 0),
    not_delivered = true
   where l.import_id = p_import_id and l.line_no = any(coalesce(p_line_nos, '{}')) and l.inspected_at is null;
  get diagnostics v_n = row_count;
  select count(*) into v_left from public.master_import_lines where import_id = p_import_id and inspected_at is null;
  update public.master_imports set
    stock_lines = (select count(*) from public.master_import_lines where import_id = p_import_id and inspected_at is not null),
    status = case when v_left = 0 then 'stock_done' else status end,
    stock_at = case when v_left = 0 then now() else stock_at end,
    stock_by = case when v_left = 0 then auth.uid() else stock_by end,
    updated_at = now()
   where id = p_import_id;
  perform public.log_audit('inventory.unplanned_closed', 'master_import', p_import_id::text, v_imp.warehouse_id,
    jsonb_build_object('lines', p_line_nos, 'closed', v_n, 'left', v_left));
  return jsonb_build_object('import_id', p_import_id, 'closed', v_n, 'left', v_left);
end;
$$;
revoke all on function public.unplanned_close_lines(bigint, integer[]) from public, anon;
grant execute on function public.unplanned_close_lines(bigint, integer[]) to authenticated;

-- 0181's take-back: a closed line opens again too.
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
    on_hand_before = null, added = null, on_hand_after = null, not_delivered = false,
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
         where l.inspected_at is not null and l.covered_by_import_id is null and not l.not_delivered
           and (l.inspected_at at time zone 'Asia/Tokyo')::date between p_from and p_to
         group by l.import_id, (l.inspected_at at time zone 'Asia/Tokyo')::date) x
      join public.master_imports m on m.id = x.import_id
      left join public.warehouses w on w.id = m.warehouse_id
     where m.source = 'stock_file' and m.undone_at is null
       and (m.warehouse_id is null or public.can_access_warehouse(m.warehouse_id))), '[]'::jsonb);
end;
$$;

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
             'invoiced_import_id', l.invoiced_import_id, 'not_delivered', l.not_delivered,
             'on_hand_now', case when p_warehouse_id is null then null else coalesce((
                select sl.on_hand from public.stock_levels sl
                 where sl.warehouse_id = p_warehouse_id and sl.jan_code = l.jan_code), 0) end)
           order by l.line_no)
      from public.master_import_lines l
      left join public.products p on p.id = l.product_id
     where l.import_id = p_id), '[]'::jsonb));
end;
$$;
