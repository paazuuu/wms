-- 0169: an import's supplier is the one its invoice names, and what was
-- bought from a supplier counts the invoices taken into stock.
--
-- * master_imports.supplier_id from the evidence document (0132), which
--   import-plan fills from the invoice (its 社名・登録番号): on insert, on a
--   new document, and for those already in. The reading's Excel (0146) and
--   the detail then name the supplier (master_import_detail adds
--   supplier_name / registration_number).
-- * supplier_purchase_lines_v2: as supplier_purchase_lines (0143), and
--   - a stock file counts while it waits for inspection too (not only once
--     in stock), not when taken back, dated by the document;
--   - its lines carry the 単価 and 定価 the invoice printed (read_lines), so
--     a supplier's history shows the prices and the rate (掛率) paid.
-- * supplier_cards and supplier_purchase_history read it; the history's
--   products add last_list_price, last_rate, min_price, max_price.

update public.master_imports m
   set supplier_id = d.supplier_id
  from public.import_documents d
 where d.id = m.document_id and m.supplier_id is null and d.supplier_id is not null;

create or replace function public.master_imports_supplier_from_document()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.supplier_id is null and new.document_id is not null then
    select d.supplier_id into new.supplier_id from public.import_documents d where d.id = new.document_id;
  end if;
  return new;
end;
$$;
revoke all on function public.master_imports_supplier_from_document() from public, anon, authenticated;
create or replace trigger master_imports_supplier_from_document before insert or update of document_id on public.master_imports
  for each row execute function public.master_imports_supplier_from_document();

-- A number as an invoice prints it ("1,234", "¥63.6"), or null.
create or replace function public.money_of(p text)
returns numeric
language sql immutable set search_path = '' as $$
  select case when regexp_replace(coalesce(p, ''), '[^0-9.]', '', 'g') ~ '^[0-9]+(\.[0-9]+)?$'
              then regexp_replace(p, '[^0-9.]', '', 'g')::numeric end;
$$;

create or replace function public.supplier_purchase_lines_v2(p_supplier_id bigint default null)
returns table (supplier_id bigint, product_id bigint, jan_code text, name text, quantity integer,
               unit_price numeric, list_price numeric, at date, source text, ref_id bigint, ref_no text)
language sql stable security definer set search_path = '' as $function$
  select po.supplier_id, l.product_id, l.jan_code, l.product_name, l.quantity, l.unit_price, null::numeric,
         coalesce(po.order_date, po.created_at::date), 'po', po.id, po.po_number
    from public.purchase_orders po
    join public.purchase_order_lines l on l.purchase_order_id = po.id
   where po.supplier_id is not null
     and (p_supplier_id is null or po.supplier_id = p_supplier_id)
     and po.status not in ('DRAFT', 'REJECTED', 'CANCELLED')
     and not exists (select 1 from public.delivery_plans d where d.purchase_order_id = po.id)
  union all
  select d.supplier_id, l.product_id, l.jan_code, l.product_name,
         case when coalesce(l.received_quantity, 0) > 0 then l.received_quantity else l.planned_quantity end,
         l.unit_price, null::numeric,
         coalesce(
           case when d.delivery_date ~ '^\d{4}-\d{2}-\d{2}' then left(d.delivery_date, 10)::date end,
           case when d.order_date ~ '^\d{4}-\d{2}-\d{2}' then left(d.order_date, 10)::date end,
           d.expected_arrival_date, d.created_at::date),
         'delivery', d.id, coalesce(d.doc_number, d.delivery_number)
    from public.delivery_plans d
    join public.delivery_plan_lines l on l.delivery_plan_id = d.id
   where d.supplier_id is not null
     and (p_supplier_id is null or d.supplier_id = p_supplier_id)
  union all
  select m.supplier_id, l.product_id, l.jan_code, coalesce(nullif(r.row->>'name', ''), l.supplier_name),
         case when coalesce(l.added, 0) > 0 then l.added else l.quantity end,
         public.money_of(r.row->>'unit_price'), public.money_of(r.row->>'list_price'),
         coalesce(m.document_date, (coalesce(m.stock_at, m.master_at, m.created_at) at time zone 'Asia/Tokyo')::date),
         'import', m.id, m.original_name
    from public.master_imports m
    join public.master_import_lines l on l.import_id = m.id
    left join lateral (
      select x as row from jsonb_array_elements(coalesce(m.read_lines, '[]'::jsonb)) x
       where (x->>'line_no') ~ '^\d+$' and (x->>'line_no')::int = l.line_no
       limit 1) r on true
   where m.supplier_id is not null
     and (p_supplier_id is null or m.supplier_id = p_supplier_id)
     and m.status in ('stock_done', 'awaiting_inspection')
     and m.undone_at is null
     and coalesce(l.quantity, 0) > 0;
$function$;
revoke all on function public.supplier_purchase_lines_v2(bigint) from public, anon;
grant execute on function public.supplier_purchase_lines_v2(bigint) to authenticated;

create or replace function public.supplier_cards(p_search text default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $function$
declare
  v_q text := nullif(lower(trim(coalesce(p_search, ''))), '');
begin
  if not public.supplier_history_viewer() then
    raise exception 'not permitted: product.view required';
  end if;
  return coalesce((
    with h as (select * from public.supplier_purchase_lines_v2(null)),
    per as (
      select h.supplier_id,
             count(distinct (h.source, h.ref_id)) as purchases,
             coalesce(sum(h.quantity), 0) as units,
             coalesce(sum(h.quantity * h.unit_price), 0) as amount,
             max(h.at) as last_at
        from h group by h.supplier_id
    ),
    top as (
      select t.supplier_id, jsonb_agg(t.name order by t.n desc, t.name) filter (where t.rk <= 3) as names
        from (
          select h.supplier_id, coalesce(p.name, h.name) as name, count(*) as n,
                 row_number() over (partition by h.supplier_id order by count(*) desc, coalesce(p.name, h.name)) as rk
            from h left join public.products p on p.id = h.product_id
           group by h.supplier_id, coalesce(p.name, h.name)
        ) t group by t.supplier_id
    ),
    prods as (
      select x.supplier_id, count(distinct x.k) as products
        from (
          select n.supplier_id, n.product_id::text as k from public.supplier_product_names n where coalesce(n.is_active, true)
          union
          select h.supplier_id, coalesce(h.product_id::text, h.jan_code, h.name) from h
        ) x group by x.supplier_id
    )
    select jsonb_agg(jsonb_build_object(
             'id', s.id, 'name', s.name, 'code', s.code, 'kind', s.kind, 'status', s.status,
             'contact_name', s.contact_name, 'phone', s.phone, 'email', s.email,
             'products', coalesce(pr.products, 0),
             'purchases', coalesce(per.purchases, 0),
             'units', coalesce(per.units, 0),
             'amount', coalesce(per.amount, 0),
             'last_at', per.last_at,
             'top', coalesce(top.names, '[]'::jsonb))
           order by per.last_at desc nulls last, s.name)
      from public.delivery_suppliers s
      left join per on per.supplier_id = s.id
      left join top on top.supplier_id = s.id
      left join prods pr on pr.supplier_id = s.id
     where coalesce(s.kind, 'supplier') <> 'customer'
       and coalesce(s.status, 'active') <> 'inactive'
       and (v_q is null or lower(concat_ws(' ', s.name, s.code, s.contact_name)) like '%' || v_q || '%')), '[]'::jsonb);
end;
$function$;

create or replace function public.supplier_purchase_history(p_supplier_id bigint, p_warehouse_id bigint default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $function$
declare
  v_s public.delivery_suppliers%rowtype;
  v_products jsonb;
  v_events jsonb;
  v_totals jsonb;
begin
  if not public.supplier_history_viewer() then
    raise exception 'not permitted: product.view required';
  end if;
  if p_warehouse_id is not null and not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse';
  end if;
  select * into v_s from public.delivery_suppliers where id = p_supplier_id;
  if not found then
    raise exception 'not_found: supplier';
  end if;

  with h as (
    select l.*, coalesce(l.product_id::text, 'j:' || coalesce(l.jan_code, l.name, '')) as k
      from public.supplier_purchase_lines_v2(p_supplier_id) l
     where coalesce(l.quantity, 0) > 0
  ),
  agg as (
    select h.k, max(h.product_id) as product_id, max(h.jan_code) as jan_code, max(h.name) as hname,
           count(distinct (h.source, h.ref_id)) as times,
           sum(h.quantity) as total,
           min(h.at) as first_at, max(h.at) as last_at,
           (array_agg(h.quantity order by h.at desc, h.ref_id desc))[1] as last_qty,
           (array_agg(h.unit_price order by h.at desc, h.ref_id desc) filter (where h.unit_price is not null))[1] as last_price,
           (array_agg(h.list_price order by h.at desc, h.ref_id desc) filter (where h.list_price is not null))[1] as last_list_price,
           min(h.unit_price) as min_price, max(h.unit_price) as max_price
      from h group by h.k
  ),
  names as (
    select distinct on (n.product_id) n.product_id, n.supplier_name, n.supplier_code
      from public.supplier_product_names n
     where n.supplier_id = p_supplier_id and coalesce(n.is_active, true)
     order by n.product_id, n.last_seen_at desc nulls last, n.id desc
  ),
  keys as (
    select agg.k from agg
    union
    select names.product_id::text from names
  ),
  prod_rows as (
    select keys.k, agg.times, agg.total, agg.first_at, agg.last_at, agg.last_qty, agg.last_price,
           coalesce(agg.last_list_price, p.list_price) as last_list_price, agg.min_price, agg.max_price,
           p.id as product_id, coalesce(p.jan_code, agg.jan_code) as jan_code,
           coalesce(p.name, agg.hname) as name, p.name_en, p.maker, p.sku, p.unit,
           n.supplier_name as their_name, n.supplier_code as their_code
      from keys
      left join agg on agg.k = keys.k
      left join public.products p on p.id = case when keys.k ~ '^\d+$' then keys.k::bigint end
      left join names n on n.product_id = p.id
  )
  select jsonb_agg(jsonb_build_object(
           'product_id', r.product_id, 'jan_code', r.jan_code, 'name', r.name, 'name_en', r.name_en,
           'maker', r.maker, 'sku', r.sku, 'unit', r.unit,
           'their_name', r.their_name, 'their_code', r.their_code,
           'times', coalesce(r.times, 0), 'total', coalesce(r.total, 0),
           'avg_qty', case when coalesce(r.times, 0) > 0 then round(r.total::numeric / r.times) end,
           'last_qty', r.last_qty, 'last_price', r.last_price,
           'last_list_price', r.last_list_price,
           'last_rate', case when r.last_price is not null and coalesce(r.last_list_price, 0) > 0
                             then round(r.last_price / r.last_list_price, 4) end,
           'min_price', r.min_price, 'max_price', r.max_price,
           'first_at', r.first_at, 'last_at', r.last_at,
           'interval_days', case when r.times > 1 then round((r.last_at - r.first_at)::numeric / (r.times - 1)) end,
           'next_due', case when r.times > 1 then r.last_at + round((r.last_at - r.first_at)::numeric / (r.times - 1))::int end,
           'on_hand', (select coalesce(sum(s.on_hand), 0)::int from public.stock_levels s
                        where (case when r.product_id is not null then s.product_id = r.product_id else s.jan_code = r.jan_code end)
                          and (case when p_warehouse_id is not null then s.warehouse_id = p_warehouse_id
                                    else public.can_access_warehouse(s.warehouse_id) end)))
         order by coalesce(r.times, 0) desc, r.last_at desc nulls last, r.name)
    into v_products
    from prod_rows r;

  select jsonb_agg(e order by e->>'at' desc, (e->>'ref_id')::bigint desc) into v_events
    from (
      select jsonb_build_object('source', h.source, 'ref_id', h.ref_id, 'ref_no', max(h.ref_no), 'at', max(h.at),
               'lines', count(*), 'units', sum(h.quantity), 'amount', sum(h.quantity * h.unit_price)) as e
        from public.supplier_purchase_lines_v2(p_supplier_id) h
       group by h.source, h.ref_id
       order by max(h.at) desc, h.ref_id desc
       limit 50
    ) x;

  select jsonb_build_object('purchases', count(distinct (h.source, h.ref_id)), 'units', coalesce(sum(h.quantity), 0),
           'amount', coalesce(sum(h.quantity * h.unit_price), 0), 'first_at', min(h.at), 'last_at', max(h.at))
    into v_totals
    from public.supplier_purchase_lines_v2(p_supplier_id) h;

  return jsonb_build_object(
    'supplier', jsonb_build_object('id', v_s.id, 'name', v_s.name, 'code', v_s.code, 'contact_name', v_s.contact_name,
                                   'phone', v_s.phone, 'email', v_s.email, 'address', v_s.address,
                                   'payment_terms', v_s.payment_terms, 'notes', v_s.notes),
    'totals', v_totals,
    'products', coalesce(v_products, '[]'::jsonb),
    'events', coalesce(v_events, '[]'::jsonb));
end;
$function$;

-- The import's detail names its supplier (the invoice's, or the one chosen).
create or replace function public.master_import_detail(p_id bigint, p_warehouse_id bigint default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $function$
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
           'supplier_name', coalesce(s.name, d.supplier_name),
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
             'on_hand_now', case when p_warehouse_id is null then null else coalesce((
                select sl.on_hand from public.stock_levels sl
                 where sl.warehouse_id = p_warehouse_id and sl.jan_code = l.jan_code), 0) end)
           order by l.line_no)
      from public.master_import_lines l
      left join public.products p on p.id = l.product_id
     where l.import_id = p_id), '[]'::jsonb));
end;
$function$;
