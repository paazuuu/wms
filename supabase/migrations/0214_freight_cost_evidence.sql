-- 0214: 輸送費 (freight) on a shipment list, and the bills behind it and
-- behind the 委託手数料 (0213) kept as evidence.
--
-- How it is usually done: freight out is a selling cost (発送費・荷造運賃),
-- and the carrier's bill often comes after the goods have left. So it is
-- entered as an estimate while the list is planned and set to the billed
-- amount when the bill arrives, and once the list is closed only a person
-- in charge may change it, with a record of who did.
--
--   * outbound_files.freight_jpy: what shipping the list cost (yen).
--   * Changing a list's costs (freight, fee, evidence): anyone who may post
--     shipments, while the list is not yet 出庫済み; after that only a
--     system admin. A 在庫外出荷 is recorded once shipped by the other
--     company and its bill comes later, so its costs stay open.
--   * outbound_cost_files + bucket cost-evidence: the bills, shown in the
--     list's detail, opened on the spot and downloaded again later. Taking
--     one away only marks it; the file stays.
--   * profit_by_month_costs: profit_by_month_split (0213) with each row's
--     share of the freight, split like the fee (by sales, else quantity).

alter table public.outbound_files add column if not exists freight_jpy numeric(14, 2);
comment on column public.outbound_files.freight_jpy is
  '0214: what shipping this list cost (輸送費, yen) — the estimate, then the billed amount.';

create or replace function public.outbound_costs_editable(p_id bigint)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((
    select auth.uid() is not null and public.can_post_outbound()
       and public.can_access_warehouse(f.warehouse_id)
       and f.undone_at is null
       and (f.kind = 'proxy' or f.status <> 'shipped' or public.is_system_admin())
      from public.outbound_files f where f.id = p_id), false);
$$;
revoke all on function public.outbound_costs_editable(bigint) from public, anon;
grant execute on function public.outbound_costs_editable(bigint) to authenticated;

create table if not exists public.outbound_cost_files (
  id bigint generated always as identity primary key,
  file_id bigint not null references public.outbound_files(id),
  cost_kind text not null check (cost_kind in ('freight', 'fee')),
  storage_path text not null unique,
  file_name text not null,
  content_type text,
  byte_size integer,
  uploaded_at timestamptz not null default now(),
  uploaded_by uuid default auth.uid(),
  removed_at timestamptz,
  removed_by uuid
);
create index if not exists outbound_cost_files_file on public.outbound_cost_files (file_id) where removed_at is null;
alter table public.outbound_cost_files enable row level security;

insert into storage.buckets (id, name, public, file_size_limit)
values ('cost-evidence', 'cost-evidence', false, 20971520)
on conflict (id) do nothing;

-- [p_name]: <warehouse id>/<list id>/<file>.
create or replace function public.cost_evidence_allowed(p_name text, p_write boolean)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.outbound_files f
     where split_part(coalesce(p_name, ''), '/', 2) ~ '^[0-9]+$'
       and f.id = split_part(p_name, '/', 2)::bigint
       and f.warehouse_id::text = split_part(p_name, '/', 1)
       and case when p_write then public.outbound_costs_editable(f.id)
                else public.can_view_outbound() and public.can_access_warehouse(f.warehouse_id) end);
$$;
grant execute on function public.cost_evidence_allowed(text, boolean) to authenticated;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'cost-evidence: editors upload') then
    create policy "cost-evidence: editors upload" on storage.objects
      for insert to authenticated
      with check (bucket_id = 'cost-evidence' and public.cost_evidence_allowed(name, true));
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'cost-evidence: viewers read') then
    create policy "cost-evidence: viewers read" on storage.objects
      for select to authenticated
      using (bucket_id = 'cost-evidence' and public.cost_evidence_allowed(name, false));
  end if;
end $$;

create or replace function public.outbound_cost_files_json(p_id bigint)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', c.id, 'cost_kind', c.cost_kind, 'storage_path', c.storage_path, 'file_name', c.file_name,
           'content_type', c.content_type, 'byte_size', c.byte_size, 'uploaded_at', c.uploaded_at,
           'uploaded_by_name', public.user_display_name(c.uploaded_by)) order by c.uploaded_at, c.id), '[]'::jsonb)
    from public.outbound_cost_files c
   where c.file_id = p_id and c.removed_at is null;
$$;
revoke all on function public.outbound_cost_files_json(bigint) from public, anon;
grant execute on function public.outbound_cost_files_json(bigint) to authenticated;

create or replace function public.outbound_file_set_freight(p_id bigint, p_amount numeric)
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
  if not public.outbound_costs_editable(p_id) then
    raise exception 'outbound_costs_locked';
  end if;
  if p_amount is not null and p_amount < 0 then
    raise exception 'outbound_fee_negative';
  end if;
  update public.outbound_files set freight_jpy = p_amount where id = p_id;
  perform public.log_audit('outbound.freight_set', 'outbound_file', p_id::text, v_f.warehouse_id,
    jsonb_build_object('freight_jpy', p_amount, 'before', v_f.freight_jpy, 'status', v_f.status));
  return true;
end;
$$;
revoke all on function public.outbound_file_set_freight(bigint, numeric) from public, anon;
grant execute on function public.outbound_file_set_freight(bigint, numeric) to authenticated;

create or replace function public.outbound_cost_file_add(
  p_file_id bigint, p_kind text, p_path text, p_name text, p_type text default null, p_size integer default null)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_f public.outbound_files;
  v_id bigint;
begin
  select * into v_f from public.outbound_files where id = p_file_id;
  if v_f.id is null or not public.can_access_warehouse(v_f.warehouse_id) then
    raise exception 'outbound file % not found', p_file_id;
  end if;
  if not public.outbound_costs_editable(p_file_id) then
    raise exception 'outbound_costs_locked';
  end if;
  if p_kind not in ('freight', 'fee') then
    raise exception 'outbound_cost_kind %', p_kind;
  end if;
  if split_part(coalesce(p_path, ''), '/', 1) <> v_f.warehouse_id::text
     or split_part(p_path, '/', 2) <> p_file_id::text then
    raise exception 'outbound_file_path';
  end if;
  insert into public.outbound_cost_files (file_id, cost_kind, storage_path, file_name, content_type, byte_size)
  values (p_file_id, p_kind, p_path, coalesce(nullif(btrim(coalesce(p_name, '')), ''), 'file'), p_type, p_size)
  returning id into v_id;
  perform public.log_audit('outbound.cost_file_add', 'outbound_file', p_file_id::text, v_f.warehouse_id,
    jsonb_build_object('cost_kind', p_kind, 'file_name', p_name, 'cost_file_id', v_id));
  return v_id;
end;
$$;
revoke all on function public.outbound_cost_file_add(bigint, text, text, text, text, integer) from public, anon;
grant execute on function public.outbound_cost_file_add(bigint, text, text, text, text, integer) to authenticated;

-- Taken off the list; the file itself is kept.
create or replace function public.outbound_cost_file_remove(p_id bigint)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_c public.outbound_cost_files;
  v_wh bigint;
begin
  select * into v_c from public.outbound_cost_files where id = p_id and removed_at is null;
  if v_c.id is null then
    return false;
  end if;
  if not public.outbound_costs_editable(v_c.file_id) then
    raise exception 'outbound_costs_locked';
  end if;
  update public.outbound_cost_files set removed_at = now(), removed_by = auth.uid() where id = p_id;
  select warehouse_id into v_wh from public.outbound_files where id = v_c.file_id;
  perform public.log_audit('outbound.cost_file_remove', 'outbound_file', v_c.file_id::text, v_wh,
    jsonb_build_object('cost_kind', v_c.cost_kind, 'file_name', v_c.file_name, 'cost_file_id', p_id));
  return true;
end;
$$;
revoke all on function public.outbound_cost_file_remove(bigint) from public, anon;
grant execute on function public.outbound_cost_file_remove(bigint) to authenticated;

-- The fee (0213) under the same rule as the freight.
do $$
declare
  v_def text;
  v_new text;
begin
  select pg_get_functiondef('public.outbound_file_set_fee(bigint, numeric)'::regprocedure) into v_def;
  v_new := replace(v_def,
    '  if p_fee is not null and p_fee < 0 then',
    '  if not public.outbound_costs_editable(p_id) then
    raise exception ''outbound_costs_locked'';
  end if;
  if p_fee is not null and p_fee < 0 then');
  if v_new = v_def then
    raise exception 'outbound_file_set_fee: pattern not found';
  end if;
  execute v_new;
end $$;

-- The freight, the bills and whether this person may change them, in the detail.
do $$
declare
  v_def text;
  v_new text;
begin
  select pg_get_functiondef('public.outbound_file_detail(bigint)'::regprocedure) into v_def;
  v_new := replace(v_def, '''fee_jpy'', v_f.fee_jpy,',
    '''fee_jpy'', v_f.fee_jpy, ''freight_jpy'', v_f.freight_jpy, '
    || '''costs_editable'', public.outbound_costs_editable(v_f.id), '
    || '''cost_files'', public.outbound_cost_files_json(v_f.id),');
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
  v_new := replace(v_def, '''fee_jpy'', f.fee_jpy,', '''fee_jpy'', f.fee_jpy, ''freight_jpy'', f.freight_jpy,');
  if v_new = v_def then
    raise exception 'outbound_files_list: pattern not found';
  end if;
  execute v_new;
end $$;

-- 月ごとの収益 with the freight.
create or replace function public.profit_by_month_costs(p_from date, p_to date, p_warehouse_id bigint default null)
returns table (month text, product_id bigint, jan_code text, product_name text, maker text, kind text,
               quantity bigint, revenue numeric, revenue_costed numeric, cost numeric, fee numeric, freight numeric,
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
           coalesce(f.freight_jpy, 0) as ffreight,
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
                else 0 end as share,
           case when pc.ffreight = 0 then 0
                when pc.file_rev > 0 then pc.ffreight * coalesce(pc.q * pc.sale, 0) / pc.file_rev
                when pc.file_q > 0 then pc.ffreight * pc.q / pc.file_q
                else 0 end as fshare
      from priced pc
  )
  select sh.mon, sh.pid, sh.jan, sh.pname, sh.mk, sh.fkind,
         sum(sh.q)::bigint,
         round(coalesce(sum(sh.q * sh.sale) filter (where sh.sale is not null), 0), 2),
         round(coalesce(sum(sh.q * sh.sale) filter (where sh.sale is not null and sh.buy is not null), 0), 2),
         round(coalesce(sum(sh.q * sh.buy) filter (where sh.sale is not null and sh.buy is not null), 0), 2),
         round(coalesce(sum(sh.share), 0), 2),
         round(coalesce(sum(sh.fshare), 0), 2),
         coalesce(sum(sh.q) filter (where sh.buy is null), 0)::bigint,
         coalesce(sum(sh.q) filter (where sh.sale is null), 0)::bigint
    from shared sh
   group by sh.mon, sh.pid, sh.jan, sh.pname, sh.mk, sh.fkind
   order by sh.mon, sh.pname, sh.fkind;
end;
$$;
revoke all on function public.profit_by_month_costs(date, date, bigint) from public, anon;
grant execute on function public.profit_by_month_costs(date, date, bigint) to authenticated;
