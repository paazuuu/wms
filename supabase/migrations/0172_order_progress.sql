-- 0172: 会計 → 発注: each order (an invoice taken into stock) with how far
-- it has gone, and a warning when it may be one already taken in.
--
-- payments_list (0171) adds, per import:
-- * the steps: uploaded (when, by whom) · the reading checked by a person
--   (rows marked human_checked of those kept) · in 商品ライブラリー (lines
--   with a product) · 商品名 and 重量 by the AI (lines whose product has a
--   name of its own or was looked up, and a weight) · inspected and in stock
--   (lines inspected, stock_at) · 振込先 and amount · paid · proof kept.
-- * same_as: the other imports, not taken back, that look like the same
--   order — the same file (fingerprint 0147, or the evidence's SHA-256), the
--   same lines (JAN × quantity, 0147), or the same supplier, invoice number
--   and date. Only a warning: the same goods are ordered again, on another
--   day or the same one, and each such order is paid.

create or replace function public.payments_list(p_from date, p_to date, p_unpaid_only boolean default false)
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
             'created_at', m.created_at, 'created_by_name', public.user_display_name(m.created_by),
             'status', m.status, 'stock_at', m.stock_at,
             'original_name', m.original_name, 'original_path', m.original_path, 'original_type', m.original_type,
             'paid', m.paid, 'paid_at', m.paid_at, 'paid_by_name', public.user_display_name(m.paid_by), 'note', m.note,
             'warehouse_name', w.name, 'read_lines', coalesce(m.read_lines, '[]'::jsonb),
             'supplier_id', s.id, 'supplier_display_name', s.name,
             'payee', coalesce(doc.payee, s.bank_account),
             'payee_source', case when doc.payee is not null then 'invoice'
                                  when s.bank_account is not null then 'supplier' end,
             'supplier_bank_account', s.bank_account,
             'steps', st.steps,
             'same_as', coalesce((
               select jsonb_agg(jsonb_build_object(
                        'id', o.id, 'day', coalesce(o.document_date, (o.created_at at time zone 'Asia/Tokyo')::date),
                        'paid', o.paid,
                        'same_file', (o.file_fingerprint is not null and o.file_fingerprint = m.file_fingerprint)
                                     or (od.sha256 is not null and od.sha256 = doc.sha256),
                        'same_lines', o.lines_fingerprint is not null and o.lines_fingerprint = m.lines_fingerprint,
                        'same_invoice', od.doc_number is not null and od.doc_number = doc.doc_number
                                        and od.doc_date is not distinct from doc.doc_date
                                        and coalesce(od.supplier_id, -1) = coalesce(doc.supplier_id, -1))
                      order by o.id)
                 from public.master_imports o
                 left join public.import_documents od on od.id = o.document_id
                where o.id <> m.id and o.source = 'stock_file' and o.undone_at is null
                  and o.status in ('stock_done', 'awaiting_inspection')
                  and ((o.file_fingerprint is not null and o.file_fingerprint = m.file_fingerprint)
                    or (od.sha256 is not null and od.sha256 = doc.sha256)
                    or (o.lines_fingerprint is not null and o.lines_fingerprint = m.lines_fingerprint)
                    or (od.doc_number is not null and od.doc_number = doc.doc_number
                        and od.doc_date is not distinct from doc.doc_date
                        and coalesce(od.supplier_id, -1) = coalesce(doc.supplier_id, -1)))), '[]'::jsonb),
             'proofs', coalesce((
               select jsonb_agg(jsonb_build_object(
                        'id', p.id, 'storage_path', p.storage_path, 'file_name', p.file_name,
                        'content_type', p.content_type, 'byte_size', p.byte_size, 'note', p.note,
                        'created_at', p.created_at, 'created_by_name', p.created_by_name)
                      order by p.created_at)
                 from public.payment_proofs p
                where p.import_id = m.id and p.removed_at is null), '[]'::jsonb),
             'document', case when doc.id is null then null else jsonb_build_object(
               'id', doc.id, 'supplier_name', coalesce(s.name, doc.supplier_name),
               'registration_number', doc.registration_number,
               'doc_number', doc.doc_number, 'doc_date', doc.doc_date, 'addressee', doc.addressee,
               'totals', doc.totals, 'storage_path', doc.storage_path, 'file_name', doc.file_name,
               'content_type', doc.content_type, 'sha256', doc.sha256, 'byte_size', doc.byte_size) end)
           order by m.paid, d.day, m.id)
      from public.master_imports m
      cross join lateral (select coalesce(m.document_date, (m.created_at at time zone 'Asia/Tokyo')::date) as day) d
      left join public.import_documents doc on doc.id = m.document_id
      left join public.delivery_suppliers s on s.id = coalesce(m.supplier_id, doc.supplier_id)
      left join public.warehouses w on w.id = m.warehouse_id
      cross join lateral (
        select jsonb_build_object(
                 'read', (select count(*) from jsonb_array_elements(coalesce(m.read_lines, '[]'::jsonb)) r
                           where not coalesce(r->'flags', '[]'::jsonb) ? 'human_removed'),
                 'checked', (select count(*) from jsonb_array_elements(coalesce(m.read_lines, '[]'::jsonb)) r
                              where coalesce(r->'flags', '[]'::jsonb) ? 'human_checked'
                                and not coalesce(r->'flags', '[]'::jsonb) ? 'human_removed'),
                 'lines', count(l.id),
                 'in_library', count(l.id) filter (where l.product_id is not null),
                 'named', count(l.id) filter (where l.product_id is not null and (
                            exists (select 1 from public.jan_name_lookups j where j.jan = l.jan_code)
                            or (nullif(btrim(coalesce(p.base_name, '')), '') is not null
                                and p.base_name <> coalesce(p.sku, '') and p.base_name <> p.jan_code))),
                 'weighed', count(l.id) filter (where p.unit_weight_g is not null),
                 'inspected', count(l.id) filter (where l.inspected_at is not null),
                 'last_inspected_at', max(l.inspected_at)) as steps
          from public.master_import_lines l
          left join public.products p on p.id = l.product_id
         where l.import_id = m.id and coalesce(l.quantity, 0) > 0) st
     where m.source = 'stock_file' and m.undone_at is null
       and m.status in ('stock_done', 'awaiting_inspection')
       and (case when p_unpaid_only then not m.paid else d.day between p_from and p_to end)), '[]'::jsonb);
end;
$$;
revoke all on function public.payments_list(date, date, boolean) from public, anon;
grant execute on function public.payments_list(date, date, boolean) to authenticated;
