-- 0173: 取込カレンダー says, beside 振込済・未払い, whether the transfer's
-- proof is kept (payment_proofs, 0171), and the app whether the stock is
-- inspected (in stock) or still waiting.
create or replace function public.stock_file_calendar(p_from date, p_to date)
returns jsonb
language sql stable security definer set search_path = '' as $function$
  select case when not public.master_import_viewer() then '[]'::jsonb else coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', m.id, 'day', d.day, 'day_kind', d.kind,
             'document_date', m.document_date, 'document_date_source', m.document_date_source,
             'created_at', m.created_at, 'original_name', m.original_name, 'warehouse_name', w.name,
             'status', m.status, 'undone_at', m.undone_at, 'line_count', m.line_count,
             'stock_lines', m.stock_lines, 'stock_added', m.stock_added, 'paid', m.paid, 'note', m.note,
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
$function$;
