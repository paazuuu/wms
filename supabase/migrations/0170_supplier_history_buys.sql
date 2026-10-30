-- 0170: a supplier's history lists, for each product, every time it was
-- bought — the day, how many, the 単価 and 定価 paid and where it came
-- from (an order, a delivery or the invoice taken into stock) — so what was
-- ordered and at what price and rate (掛率) can be looked back on.

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
           min(h.unit_price) as min_price, max(h.unit_price) as max_price,
           jsonb_agg(jsonb_build_object('at', h.at, 'quantity', h.quantity, 'unit_price', h.unit_price,
                                        'list_price', h.list_price, 'source', h.source, 'ref_id', h.ref_id,
                                        'ref_no', h.ref_no)
                     order by h.at desc, h.ref_id desc) as buys
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
           coalesce(agg.last_list_price, p.list_price) as last_list_price, agg.min_price, agg.max_price, agg.buys,
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
           'buys', coalesce(r.buys, '[]'::jsonb),
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
