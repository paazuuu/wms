-- 0168: 税理士用ファイル — each month's purchases (仕入れ) as read from the
-- invoices that went into stock (ファイルから在庫登録), with 税抜・消費税・税込
-- by rate, the supplier's 登録番号, and the invoice itself as evidence. The
-- app builds the Excel from this and the evidence (import_documents, 0132)
-- and the import's own copy (master-import-files) — kept 7 years from the
-- document's date (0148's purge), as the files are.
--
-- * import_documents.totals: the document's own 小計・消費税・合計 as read
--   (import-plan's Totals), so a month's figures are checked against what
--   the invoice says; null for documents read before.
-- * tax_purchases(from, to): every stock file whose document date (or day
--   taken in) falls in the range, not taken back. Who may see the books:
--   stock adjustment, reports or user management.

alter table public.import_documents add column if not exists totals jsonb;

create or replace function public.can_view_purchase_books()
returns boolean
language sql stable security definer set search_path = '' as $$
  select public.has_permission('inventory.adjust') or public.has_permission('report.view')
      or public.has_permission('user.manage');
$$;
grant execute on function public.can_view_purchase_books() to authenticated;

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
     where m.source = 'stock_file' and m.undone_at is null
       and m.status in ('stock_done', 'awaiting_inspection')
       and d.day between p_from and p_to), '[]'::jsonb);
end;
$$;
revoke all on function public.tax_purchases(date, date) from public, anon;
grant execute on function public.tax_purchases(date, date) to authenticated;
