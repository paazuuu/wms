-- 0211: 月ごとの収益 from every shipment: what each line sold for, less what
-- the product was bought for.
--
--   * Sold: each 出荷明細 line that left (出庫済み, not undone, 在庫外出荷
--     included), at its own unit price excluding tax (or amount ÷ quantity),
--     times what went out: a stock line's shipped quantity, a recorded line's
--     quantity. CNY is put in yen with the list's rate (1元 = ?円); a line
--     whose currency has no rate is counted apart (qty_no_price).
--   * Bought: the purchase price on or before the day it shipped — the
--     latest from 仕入れ値の履歴 (supplier invoices read in, and prices entered
--     by hand); if there is none before, the first one after. A line with no
--     purchase price at all is counted apart (qty_no_cost) and left out of
--     the profit, so a missing price never reads as pure profit.
--   * One row per month and product, so the app can filter by product and
--     maker and draw the months.
-- Only for those who may see purchase prices, over the warehouses they can
-- see.

create or replace function public.profit_by_month(p_from date, p_to date, p_warehouse_id bigint default null)
returns table (month text, product_id bigint, jan_code text, product_name text, maker text,
               quantity bigint, revenue numeric, revenue_costed numeric, cost numeric,
               qty_no_cost bigint, qty_no_price bigint)
language plpgsql
stable
security definer
set search_path to ''
as $$
#variable_conflict use_column
begin
  if auth.uid() is null or not public.can_view_purchase_prices() then
    raise exception 'not permitted: purchase prices';
  end if;
  return query
  with pts as (
    select coalesce(il.product_id, p.id) as pid,
           coalesce(m.document_date, (m.created_at at time zone 'Asia/Tokyo')::date) as day,
           round(coalesce(public.price_num(e->>'unit_price'),
                          public.price_num(e->>'amount') / nullif(public.price_num(e->>'quantity'), 0)), 2) as price
      from public.master_imports m
      cross join lateral jsonb_array_elements(coalesce(m.read_lines, '[]'::jsonb)) e
      left join public.master_import_lines il on il.import_id = m.id and il.line_no = (e->>'line_no')::integer
      left join public.products p on il.product_id is null and p.jan_code = nullif(btrim(e->>'jan'), '')
     where m.source = 'stock_file' and m.undone_at is null
       and m.kind is distinct from 'invoice'
       and m.status in ('stock_done', 'awaiting_inspection')
       and (e->>'line_no') ~ '^[0-9]+$'
       and coalesce(il.not_delivered, false) = false
       and coalesce(public.price_num(e->>'unit_price'), public.price_num(e->>'amount')) > 0
       and coalesce(il.product_id, p.id) is not null
    union all
    select pe.product_id, pe.priced_on, pe.unit_price
      from public.purchase_price_entries pe
     where pe.removed_at is null and pe.unit_price > 0
  ),
  sold as (
    select to_char(f.shipped_on, 'YYYY-MM') as mon,
           l.product_id as pid,
           coalesce(pr.jan_code, l.jan_code) as jan,
           coalesce(pr.name, l.product_name) as pname,
           coalesce(nullif(btrim(pr.maker), ''), nullif(btrim(l.maker), '')) as mk,
           (case when f.kind = 'stock' and l.action = 'ship' then l.shipped_quantity else l.quantity end)::bigint as q,
           coalesce(l.unit_price, l.amount / nullif(l.quantity, 0))
             * (case upper(coalesce(l.currency, 'JPY')) when 'JPY' then 1 when 'CNY' then f.fx_cny_jpy end) as sale,
           f.shipped_on as day
      from public.outbound_files f
      join public.outbound_file_lines l on l.file_id = f.id
      left join public.products pr on pr.id = l.product_id
     where f.status = 'shipped' and f.undone_at is null and not coalesce(f.date_undecided, false)
       and l.action <> 'skip'
       and f.shipped_on between p_from and p_to
       and (p_warehouse_id is null or f.warehouse_id = p_warehouse_id)
       and public.can_access_warehouse(f.warehouse_id)
  ),
  priced as (
    select s.*,
           coalesce(
             (select x.price from pts x where x.pid = s.pid and x.day <= s.day order by x.day desc limit 1),
             (select x.price from pts x where x.pid = s.pid and x.day > s.day order by x.day limit 1)) as buy
      from sold s
     where s.q > 0
  )
  select pc.mon, pc.pid, pc.jan, pc.pname, pc.mk,
         sum(pc.q)::bigint,
         round(coalesce(sum(pc.q * pc.sale) filter (where pc.sale is not null), 0), 2),
         round(coalesce(sum(pc.q * pc.sale) filter (where pc.sale is not null and pc.buy is not null), 0), 2),
         round(coalesce(sum(pc.q * pc.buy) filter (where pc.sale is not null and pc.buy is not null), 0), 2),
         coalesce(sum(pc.q) filter (where pc.buy is null), 0)::bigint,
         coalesce(sum(pc.q) filter (where pc.sale is null), 0)::bigint
    from priced pc
   group by pc.mon, pc.pid, pc.jan, pc.pname, pc.mk
   order by pc.mon, pc.pname;
end;
$$;

revoke all on function public.profit_by_month(date, date, bigint) from public, anon;
grant execute on function public.profit_by_month(date, date, bigint) to authenticated;
