-- 0215: 作業実績 — a month's work, for the record and the memoranda that
-- follow from it: each receipt read from a file (its supplier), each list
-- shipped or planned (where it went, by whom for a 在庫外出荷), and the
-- warehouse's own memos, with the notes and instructions written on each.
--
-- One row per piece of work; amounts only when asked for and only to those
-- who may see prices (p_amounts), since such a record is often handed on.
-- Nothing taken back is in it.

create or replace function public.work_log(
  p_from date, p_to date, p_warehouse_id bigint default null, p_amounts boolean default false)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_money boolean := coalesce(p_amounts, false) and public.can_view_purchase_prices();
  v_out jsonb := '[]'::jsonb;
begin
  if auth.uid() is null then
    raise exception 'not permitted: sign in required';
  end if;
  if p_warehouse_id is not null and not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  -- 入荷: the files read as stock, on the day the work was done.
  if public.master_import_viewer() then
    v_out := v_out || coalesce((
      select jsonb_agg(jsonb_build_object(
        'kind', case when m.kind = 'unplanned' then 'unplanned' else 'receipt' end,
        'day', (coalesce(m.stock_at, m.created_at) at time zone 'Asia/Tokyo')::date,
        'doc_day', m.document_date,
        'warehouse_id', m.warehouse_id,
        'warehouse_name', w.name,
        'partner', coalesce(s.name, m.note_supplier),
        'file_name', m.original_name,
        'lines', m.line_count,
        'quantity', case when m.status = 'stock_done' then m.stock_added end,
        'status', m.status,
        'note', nullif(concat_ws(' / ',
                  nullif(btrim(coalesce(m.note, '')), ''),
                  case when m.no_invoice_reason is not null or m.no_invoice_note is not null then
                    '請求書なし: ' || concat_ws(' ', m.no_invoice_reason, m.no_invoice_note) end), ''),
        'amount', case when v_money then (d.totals->>'doc_total') end,
        'by', public.user_display_name(coalesce(m.stock_by, m.created_by))))
        from public.master_imports m
        left join public.delivery_suppliers s on s.id = m.supplier_id
        left join public.warehouses w on w.id = m.warehouse_id
        left join public.import_documents d on d.id = m.document_id
       where m.source = 'stock_file' and m.undone_at is null
         and m.kind is distinct from 'invoice'
         and (coalesce(m.stock_at, m.created_at) at time zone 'Asia/Tokyo')::date between p_from and p_to
         and (p_warehouse_id is null or m.warehouse_id = p_warehouse_id)
         and (m.warehouse_id is null or public.can_access_warehouse(m.warehouse_id))), '[]'::jsonb);
  end if;

  -- 出庫 / 在庫外出荷: the lists, on the day they left (or are to leave).
  if public.can_view_outbound() then
    v_out := v_out || coalesce((
      select jsonb_agg(jsonb_build_object(
        'kind', case when f.kind = 'proxy' then 'proxy' else 'outbound' end,
        'day', case when f.status = 'planned' then coalesce(f.planned_on, f.shipped_on) else f.shipped_on end,
        'warehouse_id', f.warehouse_id,
        'warehouse_name', w.name,
        'partner', coalesce(nullif(f.ship_to->>'name', ''), f.destination),
        'file_name', f.file_name,
        'lines', f.line_count,
        'quantity', case when f.kind = 'stock' and f.status = 'shipped' then f.shipped_total else f.quantity_total end,
        'short', nullif(f.short_total, 0),
        'cartons', f.pack_carton_count,
        'status', f.status,
        'note', nullif(concat_ws(' / ',
                  case when f.kind = 'proxy' and f.principal is not null then '委託先: ' || f.principal end,
                  nullif(btrim(coalesce(f.note, '')), '')), ''),
        'amount', case when v_money then f.amount_total end,
        'currency', case when v_money then f.currency end,
        'fee', case when v_money then f.fee_jpy end,
        'freight', case when v_money then f.freight_jpy end,
        'by', public.user_display_name(coalesce(f.shipped_by, f.created_by))))
        from public.outbound_files f
        join public.warehouses w on w.id = f.warehouse_id
       where f.undone_at is null and not coalesce(f.date_undecided, false)
         and (case when f.status = 'planned' then coalesce(f.planned_on, f.shipped_on) else f.shipped_on end)
             between p_from and p_to
         and (p_warehouse_id is null or f.warehouse_id = p_warehouse_id)
         and public.can_access_warehouse(f.warehouse_id)), '[]'::jsonb);
  end if;

  -- メモ・指示: the warehouse's memos — a calendar memo on its day, a
  -- board memo on the day it was written.
  v_out := v_out || coalesce((
    select jsonb_agg(jsonb_build_object(
      'kind', 'memo',
      'day', case when m.kind = 'calendar' then m.memo_date else (m.created_at at time zone 'Asia/Tokyo')::date end,
      'warehouse_id', m.warehouse_id,
      'warehouse_name', w.name,
      'note', m.body,
      'by', public.user_display_name(coalesce(m.updated_by, m.created_by))))
      from public.warehouse_memos m
      join public.warehouses w on w.id = m.warehouse_id
     where m.removed_at is null
       and (case when m.kind = 'calendar' then m.memo_date else (m.created_at at time zone 'Asia/Tokyo')::date end)
           between p_from and p_to
       and (p_warehouse_id is null or m.warehouse_id = p_warehouse_id)
       and public.can_access_warehouse(m.warehouse_id)), '[]'::jsonb);

  return coalesce((
    select jsonb_agg(e order by (e->>'day'), (e->>'kind'), (e->>'warehouse_name'))
      from jsonb_array_elements(v_out) e), '[]'::jsonb);
end;
$$;
revoke all on function public.work_log(date, date, bigint, boolean) from public, anon;
grant execute on function public.work_log(date, date, bigint, boolean) to authenticated;

-- A receipt not yet in stock shows the quantity read from its file.
do $$
declare
  v_def text;
  v_new text;
begin
  select pg_get_functiondef('public.work_log(date, date, bigint, boolean)'::regprocedure) into v_def;
  v_new := replace(v_def,
    $r$'quantity', case when m.status = 'stock_done' then m.stock_added end,$r$,
    $r$'quantity', case when m.status = 'stock_done' then m.stock_added
                          else (select sum(public.price_num(e->>'quantity'))::integer
                                  from jsonb_array_elements(coalesce(m.read_lines, '[]'::jsonb)) e) end,$r$);
  if v_new = v_def then
    raise exception 'work_log: pattern not found';
  end if;
  execute v_new;
end $$;
