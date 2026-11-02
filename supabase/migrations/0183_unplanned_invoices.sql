-- 0183: 予定外の入荷 and the invoice that comes — or does not.
--
-- * 請求書待ち (unplanned_awaiting_invoice): every unplanned receipt with
--   goods checked in that no invoice has covered yet, with what is left and
--   since when — shown in 予定外の入荷 (its own tab) and pointed to from
--   発注's 注文の進み具合・支払い.
-- * 請求書なしで完了 (unplanned_settle_without_invoice): a receipt no invoice
--   will come for — a sample, given free, the supplier's mistake, returned
--   — closed with the reason, and opened again if one comes after all
--   (unplanned_reopen_invoice).
-- * One invoice line for several receipts (stock_file_cover_lines): the same
--   invoice line may cover receipt lines of several receipts (ペン30 = 11/1
--   の20 + 11/5 の10); every one is tied.
-- * A summary invoice with no JAN lines (unplanned_invoice_create): the
--   receipts it covers chosen by hand; the invoice becomes its own 取込 #…
--   (kind invoice, nothing to put in stock) for 支払い and 税理士用ファイル,
--   and every waiting line of those receipts is tied to it. Undoing it frees
--   them again (0181).

alter table public.master_imports add column if not exists no_invoice_reason text;
alter table public.master_imports add column if not exists no_invoice_note text;
alter table public.master_imports add column if not exists no_invoice_at timestamptz;
alter table public.master_imports add column if not exists no_invoice_by uuid;

-- [p_settled]: false — waiting for an invoice; true — closed without one.
create or replace function public.unplanned_awaiting_invoice(p_settled boolean default false)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.master_import_viewer() or public.has_permission('inventory.adjust')) then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'import_id', m.id, 'received_at', coalesce(m.stock_at, m.created_at), 'created_at', m.created_at,
             'document_date', m.document_date, 'supplier', m.note_supplier, 'file_name', m.original_name,
             'warehouse_id', m.warehouse_id, 'warehouse_name', w.name, 'status', m.status,
             'no_invoice_reason', m.no_invoice_reason, 'no_invoice_note', m.no_invoice_note,
             'no_invoice_at', m.no_invoice_at,
             'no_invoice_by', public.user_display_name(m.no_invoice_by),
             'lines', (select coalesce(jsonb_agg(jsonb_build_object(
                                'line_no', l.line_no, 'jan_code', l.jan_code, 'name', p.name,
                                'quantity', l.inspected_quantity) order by l.line_no), '[]'::jsonb)
                         from public.master_import_lines l
                         left join public.products p on p.id = l.product_id
                        where l.import_id = m.id and l.inspected_at is not null
                          and coalesce(l.inspected_quantity, 0) > 0 and l.invoiced_import_id is null),
             'invoiced_lines', (select count(*) from public.master_import_lines l
                                 where l.import_id = m.id and l.invoiced_import_id is not null))
           order by coalesce(m.stock_at, m.created_at), m.id)
      from public.master_imports m
      left join public.warehouses w on w.id = m.warehouse_id
     where m.kind = 'unplanned' and m.undone_at is null
       and (m.warehouse_id is null or public.can_access_warehouse(m.warehouse_id))
       and case when coalesce(p_settled, false) then m.no_invoice_at is not null
                else m.no_invoice_at is null and exists (
                  select 1 from public.master_import_lines l
                   where l.import_id = m.id and l.inspected_at is not null
                     and coalesce(l.inspected_quantity, 0) > 0 and l.invoiced_import_id is null) end), '[]'::jsonb);
end;
$$;
revoke all on function public.unplanned_awaiting_invoice(boolean) from public, anon;
grant execute on function public.unplanned_awaiting_invoice(boolean) to authenticated;

create or replace function public.unplanned_settle_without_invoice(p_import_id bigint, p_reason text, p_note text default null)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_imp public.master_imports;
begin
  if not public.has_permission('inventory.adjust') then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  if p_reason is null or p_reason not in ('sample', 'free', 'supplier_error', 'returned', 'other') then
    raise exception 'no_invoice_reason_required';
  end if;
  if p_reason = 'other' and public.tidy_text(p_note) is null then
    raise exception 'no_invoice_note_required';
  end if;
  select * into v_imp from public.master_imports where id = p_import_id for update;
  if v_imp.id is null or v_imp.kind is distinct from 'unplanned' or v_imp.undone_at is not null then
    raise exception 'import % not found', p_import_id;
  end if;
  if not public.can_access_warehouse(v_imp.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  update public.master_imports set
    no_invoice_reason = p_reason, no_invoice_note = public.tidy_text(p_note),
    no_invoice_at = now(), no_invoice_by = auth.uid(), updated_at = now()
   where id = p_import_id;
  perform public.log_audit('inventory.unplanned_no_invoice', 'master_import', p_import_id::text, v_imp.warehouse_id,
    jsonb_build_object('reason', p_reason, 'note', p_note));
  return true;
end;
$$;
revoke all on function public.unplanned_settle_without_invoice(bigint, text, text) from public, anon;
grant execute on function public.unplanned_settle_without_invoice(bigint, text, text) to authenticated;

create or replace function public.unplanned_reopen_invoice(p_import_id bigint)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_imp public.master_imports;
begin
  if not public.has_permission('inventory.adjust') then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  select * into v_imp from public.master_imports where id = p_import_id for update;
  if v_imp.id is null or v_imp.kind is distinct from 'unplanned' or v_imp.no_invoice_at is null then
    raise exception 'import % not found', p_import_id;
  end if;
  if not public.can_access_warehouse(v_imp.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  update public.master_imports set
    no_invoice_reason = null, no_invoice_note = null, no_invoice_at = null, no_invoice_by = null, updated_at = now()
   where id = p_import_id;
  perform public.log_audit('inventory.unplanned_invoice_reopened', 'master_import', p_import_id::text, v_imp.warehouse_id,
    jsonb_build_object('reason', v_imp.no_invoice_reason));
  return true;
end;
$$;
revoke all on function public.unplanned_reopen_invoice(bigint) from public, anon;
grant execute on function public.unplanned_reopen_invoice(bigint) to authenticated;

-- A summary invoice for the receipts chosen: its own import, nothing to put
-- in stock, tied to every waiting line of them.
create or replace function public.unplanned_invoice_create(
  p_receipt_ids bigint[], p_file_name text default null, p_file_type text default null,
  p_document_id bigint default null, p_document_date date default null, p_read jsonb default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_wh bigint;
  v_whs int;
  v_id bigint;
  v_n int;
begin
  if not public.has_permission('inventory.adjust') then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  select min(m.warehouse_id), count(distinct m.warehouse_id) into v_wh, v_whs
    from public.master_imports m
   where m.id = any(coalesce(p_receipt_ids, '{}')) and m.kind = 'unplanned' and m.undone_at is null;
  if v_wh is null then
    raise exception 'invoice_no_receipts';
  end if;
  if v_whs > 1 then
    raise exception 'invoice_mixed_warehouses';
  end if;
  if not public.can_access_warehouse(v_wh) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  insert into public.master_imports (company_id, status, source, kind, warehouse_id, original_name, original_type,
                                     line_count, document_id, document_date, document_date_source,
                                     read_lines, read_by, stock_lines, stock_added, stock_at, stock_by)
  values ((select id from public.companies order by id limit 1), 'stock_done', 'stock_file', 'invoice', v_wh,
          coalesce(public.tidy_text(p_file_name), '請求書'), public.tidy_text(p_file_type),
          0, p_document_id, coalesce(p_document_date, (now() at time zone 'Asia/Tokyo')::date),
          case when p_document_date is null then 'uploaded' else 'content' end,
          case when jsonb_typeof(p_read) = 'array' then p_read end, case when jsonb_typeof(p_read) = 'array' then 'ai' end,
          0, 0, now(), auth.uid())
  returning id into v_id;
  update public.master_import_lines l set invoiced_import_id = v_id
    from public.master_imports m
   where m.id = l.import_id and m.id = any(p_receipt_ids) and m.kind = 'unplanned' and m.undone_at is null
     and m.warehouse_id = v_wh
     and l.inspected_at is not null and coalesce(l.inspected_quantity, 0) > 0 and l.invoiced_import_id is null;
  get diagnostics v_n = row_count;
  perform public.log_audit('inventory.unplanned_invoiced', 'master_import', v_id::text, v_wh,
    jsonb_build_object('receipts', to_jsonb(p_receipt_ids), 'lines', v_n));
  return jsonb_build_object('import_id', v_id, 'lines', v_n);
end;
$$;
revoke all on function public.unplanned_invoice_create(bigint[], text, text, bigint, date, jsonb) from public, anon;
grant execute on function public.unplanned_invoice_create(bigint[], text, text, bigint, date, jsonb) to authenticated;

-- 0181's covering, many to one: an invoice line already covered in this
-- import ties further receipt lines of its JAN too.
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
  v_tied int := 0;
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
    -- Not this import's, or counted in by hand: nothing to cover.
    if l.id is null or (l.inspected_at is not null and l.covered_by_import_id is null) then
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
    if l.inspected_at is null then
      select coalesce(on_hand, 0) into v_now from public.stock_levels
       where warehouse_id = v_imp.warehouse_id and jan_code = l.jan_code;
      update public.master_import_lines set
        inspected_at = now(), inspected_by = auth.uid(), inspected_quantity = 0,
        on_hand_before = coalesce(v_now, 0), added = 0, on_hand_after = coalesce(v_now, 0),
        covered_by_import_id = u.import_id, covered_by_line_no = u.line_no
       where id = l.id;
      v_n := v_n + 1;
    end if;
    update public.master_import_lines set invoiced_import_id = p_import_id where id = u.id;
    v_tied := v_tied + 1;
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
    jsonb_build_object('covered', v_n, 'tied', v_tied, 'left', v_left, 'covers', p_covers));
  return jsonb_build_object('import_id', p_import_id, 'covered', v_n, 'tied', v_tied, 'left', v_left);
end;
$$;
