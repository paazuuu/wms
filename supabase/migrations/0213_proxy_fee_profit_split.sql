-- 0213: 在庫外出荷 as it is used: the goods are ours (bought by us — the
-- supplier's regional allocation leaves no other way), kept in another
-- company's warehouse, and shipped by that company for a fee.
--
-- So we are the principal: the sale counts in full, and its cost is the
-- purchase price plus the fee paid for shipping it.
--
--   * outbound_files.fee_jpy: what was paid for a list's shipping (委託手数料,
--     yen), set on the list (outbound_file_set_fee) and shown in its detail
--     and the lists.
--   * profit_by_month_split: profit_by_month (0211) with each row's kind
--     (stock = our warehouse, proxy = 在庫外出荷) and its share of the fee —
--     a list's fee split over its lines by what each sold for (by quantity
--     when nothing has a price) — so the dashboard can show the two apart
--     and the fee as a cost.

alter table public.outbound_files add column if not exists fee_jpy numeric(14, 2);
comment on column public.outbound_files.fee_jpy is
  '0213: what was paid for this list''s shipping (委託手数料, yen) — for 在庫外出荷, the other company''s fee.';

create or replace function public.outbound_file_set_fee(p_id bigint, p_fee numeric)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_f public.outbound_files;
begin
  if auth.uid() is null or not public.can_post_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  select * into v_f from public.outbound_files where id = p_id for update;
  if v_f.id is null or not public.can_access_warehouse(v_f.warehouse_id) then
    raise exception 'outbound file % not found', p_id;
  end if;
  if p_fee is not null and p_fee < 0 then
    raise exception 'outbound_fee_negative';
  end if;
  update public.outbound_files set fee_jpy = p_fee where id = p_id;
  perform public.log_audit('outbound.fee_set', 'outbound_file', p_id::text, v_f.warehouse_id,
    jsonb_build_object('fee_jpy', p_fee, 'before', v_f.fee_jpy));
  return true;
end;
$$;
revoke all on function public.outbound_file_set_fee(bigint, numeric) from public, anon;
grant execute on function public.outbound_file_set_fee(bigint, numeric) to authenticated;

-- The fee in what a list's detail and the lists send.
do $$
declare
  v_def text;
  v_new text;
begin
  select pg_get_functiondef('public.outbound_file_detail(bigint)'::regprocedure) into v_def;
  v_new := replace(v_def, '''principal'', v_f.principal,', '''principal'', v_f.principal, ''fee_jpy'', v_f.fee_jpy,');
  if v_new = v_def then
    raise exception 'outbound_file_detail: pattern not found';
  end if;
  execute v_new;
end $$;

do $$
declare
  v_sig text;
  v_def text;
  v_new text;
begin
  select p.oid::regprocedure::text into v_sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'outbound_files_list';
  select pg_get_functiondef(v_sig::regprocedure) into v_def;
  v_new := replace(v_def, '''principal'', f.principal,', '''principal'', f.principal, ''fee_jpy'', f.fee_jpy,');
  if v_new = v_def then
    raise exception 'outbound_files_list: pattern not found';
  end if;
  execute v_new;
end $$;

create or replace function public.profit_by_month_split(p_from date, p_to date, p_warehouse_id bigint default null)
returns table (month text, product_id bigint, jan_code text, product_name text, maker text, kind text,
               quantity bigint, revenue numeric, revenue_costed numeric, cost numeric, fee numeric,
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
    select f.id as fid,
           f.kind as fkind,
           coalesce(f.fee_jpy, 0) as ffee,
           to_char(f.shipped_on, 'YYYY-MM') as mon,
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
             (select x.price from pts x where x.pid = s.pid and x.day > s.day order by x.day limit 1)) as buy,
           sum(coalesce(s.q * s.sale, 0)) over (partition by s.fid) as file_rev,
           sum(s.q) over (partition by s.fid) as file_q
      from sold s
     where s.q > 0
  ),
  shared as (
    select pc.*,
           case when pc.ffee = 0 then 0
                when pc.file_rev > 0 then pc.ffee * coalesce(pc.q * pc.sale, 0) / pc.file_rev
                when pc.file_q > 0 then pc.ffee * pc.q / pc.file_q
                else 0 end as share
      from priced pc
  )
  select sh.mon, sh.pid, sh.jan, sh.pname, sh.mk, sh.fkind,
         sum(sh.q)::bigint,
         round(coalesce(sum(sh.q * sh.sale) filter (where sh.sale is not null), 0), 2),
         round(coalesce(sum(sh.q * sh.sale) filter (where sh.sale is not null and sh.buy is not null), 0), 2),
         round(coalesce(sum(sh.q * sh.buy) filter (where sh.sale is not null and sh.buy is not null), 0), 2),
         round(coalesce(sum(sh.share), 0), 2),
         coalesce(sum(sh.q) filter (where sh.buy is null), 0)::bigint,
         coalesce(sum(sh.q) filter (where sh.sale is null), 0)::bigint
    from shared sh
   group by sh.mon, sh.pid, sh.jan, sh.pname, sh.mk, sh.fkind
   order by sh.mon, sh.pname, sh.fkind;
end;
$$;
revoke all on function public.profit_by_month_split(date, date, bigint) from public, anon;
grant execute on function public.profit_by_month_split(date, date, bigint) to authenticated;
