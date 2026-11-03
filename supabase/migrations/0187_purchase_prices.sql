-- 0187: 仕入れ値の履歴 — each time a product was bought, at what price, from
-- which supplier; by month on average.
--
-- Where the prices come from:
-- * receipt  — the lines read from stock files (発注 / 予定外の入荷,
--   master_imports.read_lines): unit_price is taken as 税抜, its tax_rate
--   (else 10%). Undone imports, summary invoices (kind 'invoice') and lines
--   closed as not delivered are left out.
-- * manual   — purchase_price_entries, written by hand on the product
--   (a price agreed on the phone, a receipt with no file).
-- * outbound — the 出荷リスト lines (0188) carry the supplier and price
--   they were bought at; shown as their own series, not in the averages,
--   so a purchase seen twice is not counted twice.
-- product_purchase_prices(product) gives every point, the month's average
-- (weighted by quantity) and each supplier's last and average price.

create or replace function public.price_num(p text)
returns numeric
language sql immutable set search_path = '' as $$
  select case when t ~ '^-?[0-9]+(\.[0-9]+)?$' then t::numeric end
    from (select regexp_replace(translate(coalesce(p, ''), '０１２３４５６７８９．，', '0123456789.,'),
                                '[^0-9.\-]', '', 'g') as t) x;
$$;

create table if not exists public.purchase_price_entries (
  id bigint generated always as identity primary key,
  product_id bigint not null references public.products(id),
  supplier_id bigint references public.delivery_suppliers(id),
  supplier_name text,
  unit_price numeric(14, 2) not null check (unit_price >= 0),
  tax_rate numeric(5, 2) not null default 10,
  quantity integer,
  priced_on date not null default ((now() at time zone 'Asia/Tokyo')::date),
  note text,
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  removed_at timestamptz,
  removed_by uuid
);
alter table public.purchase_price_entries enable row level security;
create index if not exists purchase_price_entries_product on public.purchase_price_entries (product_id, priced_on)
  where removed_at is null;

-- Who may see what was paid.
create or replace function public.can_view_purchase_prices()
returns boolean
language sql stable security definer set search_path = '' as $$
  select public.can_view_purchase_books() or public.has_permission('product.manage')
      or public.has_permission('purchase_order.view');
$$;
grant execute on function public.can_view_purchase_prices() to authenticated;

-- The receipt points of one product: each line of a stock file it was
-- bought on.
create or replace function public.receipt_price_points(p_product_id bigint)
returns table (id text, day date, supplier_id bigint, supplier_name text, unit_price numeric, tax_rate numeric,
               quantity integer, import_id bigint, line_no integer, file_name text, kind text)
language sql stable security definer set search_path = '' as $$
  select 'r' || m.id || '-' || (e->>'line_no'),
         coalesce(m.document_date, (m.created_at at time zone 'Asia/Tokyo')::date),
         m.supplier_id,
         coalesce(nullif(btrim(s.name), ''), nullif(btrim(m.note_supplier), ''), nullif(btrim(e->>'supplier'), '')),
         round(coalesce(public.price_num(e->>'unit_price'),
                        public.price_num(e->>'amount') / nullif(public.price_num(e->>'quantity'), 0)), 2),
         coalesce(public.price_num(e->>'tax_rate'), 10),
         coalesce(l.inspected_quantity, public.price_num(e->>'quantity')::integer),
         m.id, (e->>'line_no')::integer, m.original_name, coalesce(m.kind, 'order')
    from public.master_imports m
    cross join lateral jsonb_array_elements(coalesce(m.read_lines, '[]'::jsonb)) e
    left join public.master_import_lines l on l.import_id = m.id and l.line_no = (e->>'line_no')::integer
    left join public.delivery_suppliers s on s.id = m.supplier_id
    join public.products p on p.id = p_product_id
   where m.source = 'stock_file' and m.undone_at is null
     and m.kind is distinct from 'invoice'
     and m.status in ('stock_done', 'awaiting_inspection')
     and (e->>'line_no') ~ '^[0-9]+$'
     and coalesce(l.not_delivered, false) = false
     and (l.product_id = p_product_id
          or (l.product_id is null and nullif(btrim(e->>'jan'), '') = p.jan_code))
     and coalesce(public.price_num(e->>'unit_price'), public.price_num(e->>'amount')) > 0;
$$;
revoke all on function public.receipt_price_points(bigint) from public, anon, authenticated;

-- Every price point of one product: receipts and hand-written ones (0188
-- adds the 出荷リスト's).
create or replace function public.purchase_price_points(p_product_id bigint)
returns table (id text, source text, day date, supplier_id bigint, supplier_name text, unit_price numeric,
               tax_rate numeric, quantity integer, import_id bigint, file_id bigint, line_no integer,
               file_name text, kind text, note text, entry_id bigint)
language sql stable security definer set search_path = '' as $$
  select r.id, 'receipt', r.day, r.supplier_id, r.supplier_name, r.unit_price, r.tax_rate, r.quantity,
         r.import_id, null::bigint, r.line_no, r.file_name, r.kind, null::text, null::bigint
    from public.receipt_price_points(p_product_id) r
  union all
  select 'm' || e.id, 'manual', e.priced_on, e.supplier_id,
         coalesce(nullif(btrim(s.name), ''), nullif(btrim(e.supplier_name), '')),
         e.unit_price, e.tax_rate, e.quantity, null, null, null, null, null, e.note, e.id
    from public.purchase_price_entries e
    left join public.delivery_suppliers s on s.id = e.supplier_id
   where e.product_id = p_product_id and e.removed_at is null;
$$;
revoke all on function public.purchase_price_points(bigint) from public, anon, authenticated;

create or replace function public.product_purchase_prices(p_product_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_points jsonb;
  v_monthly jsonb;
  v_suppliers jsonb;
begin
  if auth.uid() is null then
    raise exception 'not permitted: sign in required';
  end if;
  if not public.can_view_purchase_prices() then
    raise exception 'not permitted: report.view required';
  end if;
  if not exists (select 1 from public.products where id = p_product_id) then
    raise exception 'product % not found', p_product_id;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', x.id, 'source', x.source, 'day', x.day, 'supplier_id', x.supplier_id,
           'supplier_name', coalesce(x.supplier_name, ''), 'unit_price', x.unit_price, 'tax_rate', x.tax_rate,
           'unit_price_tax', round(x.unit_price * (1 + x.tax_rate / 100), 2), 'quantity', x.quantity,
           'import_id', x.import_id, 'file_id', x.file_id, 'line_no', x.line_no, 'file_name', x.file_name,
           'kind', x.kind, 'note', x.note, 'entry_id', x.entry_id) order by x.day, x.id), '[]'::jsonb)
    into v_points from public.purchase_price_points(p_product_id) x;

  -- The month's price over every supplier, weighted by how many were bought
  -- (a line without a quantity counts once).
  select coalesce(jsonb_agg(jsonb_build_object(
           'month', month, 'average', average, 'min', lo, 'max', hi, 'quantity', qty, 'count', n) order by month), '[]'::jsonb)
    into v_monthly
    from (select to_char(p.day, 'YYYY-MM') as month,
                 round(sum(p.unit_price * greatest(coalesce(p.quantity, 1), 1)) / sum(greatest(coalesce(p.quantity, 1), 1)), 2) as average,
                 min(p.unit_price) as lo, max(p.unit_price) as hi, sum(coalesce(p.quantity, 0)) as qty, count(*) as n
            from public.purchase_price_points(p_product_id) p where p.source <> 'outbound'
           group by 1) x;

  select coalesce(jsonb_agg(jsonb_build_object(
           'supplier_id', supplier_id, 'supplier_name', supplier_name, 'count', n, 'quantity', qty,
           'average', average, 'last_price', last_price, 'last_day', last_day, 'min', lo, 'max', hi)
           order by last_day desc nulls last), '[]'::jsonb)
    into v_suppliers
    from (select p.supplier_id, coalesce(p.supplier_name, '') as supplier_name, count(*) as n,
                 sum(coalesce(p.quantity, 0)) as qty,
                 round(sum(p.unit_price * greatest(coalesce(p.quantity, 1), 1)) / sum(greatest(coalesce(p.quantity, 1), 1)), 2) as average,
                 (array_agg(p.unit_price order by p.day desc, p.id desc))[1] as last_price,
                 max(p.day) as last_day, min(p.unit_price) as lo, max(p.unit_price) as hi
            from public.purchase_price_points(p_product_id) p where p.source <> 'outbound'
           group by p.supplier_id, coalesce(p.supplier_name, '')) y;

  return jsonb_build_object('product_id', p_product_id, 'points', v_points, 'monthly', v_monthly,
                            'suppliers', v_suppliers);
end;
$$;
revoke all on function public.product_purchase_prices(bigint) from public, anon;
grant execute on function public.product_purchase_prices(bigint) to authenticated;

-- A price written by hand. [p_supplier_id] or [p_supplier_name] (a supplier
-- not in the list).
create or replace function public.purchase_price_record(
  p_product_id bigint, p_unit_price numeric, p_priced_on date default null,
  p_supplier_id bigint default null, p_supplier_name text default null,
  p_tax_rate numeric default 10, p_quantity integer default null, p_note text default null)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
begin
  if auth.uid() is null then
    raise exception 'not permitted: sign in required';
  end if;
  if not (public.has_permission('product.manage') or public.has_permission('inventory.adjust')
          or public.has_permission('purchase_order.manage')) then
    raise exception 'not permitted: product.manage required';
  end if;
  if not exists (select 1 from public.products where id = p_product_id) then
    raise exception 'product % not found', p_product_id;
  end if;
  if p_unit_price is null or p_unit_price < 0 then
    raise exception 'price_required';
  end if;
  if p_supplier_id is null and nullif(btrim(coalesce(p_supplier_name, '')), '') is null then
    raise exception 'supplier_required';
  end if;
  insert into public.purchase_price_entries (product_id, supplier_id, supplier_name, unit_price, tax_rate, quantity,
                                             priced_on, note)
  values (p_product_id, p_supplier_id, nullif(btrim(coalesce(p_supplier_name, '')), ''), round(p_unit_price, 2),
          coalesce(p_tax_rate, 10), p_quantity, coalesce(p_priced_on, (now() at time zone 'Asia/Tokyo')::date),
          nullif(btrim(coalesce(p_note, '')), ''))
  returning id into v_id;
  perform public.log_audit('product.purchase_price_recorded', 'product', p_product_id::text, null,
    jsonb_build_object('entry', v_id, 'unit_price', p_unit_price, 'supplier_id', p_supplier_id,
                       'supplier_name', p_supplier_name, 'priced_on', p_priced_on));
  return v_id;
end;
$$;
revoke all on function public.purchase_price_record(bigint, numeric, date, bigint, text, numeric, integer, text) from public, anon;
grant execute on function public.purchase_price_record(bigint, numeric, date, bigint, text, numeric, integer, text) to authenticated;

-- Taken away (kept, out of the history).
create or replace function public.purchase_price_withdraw(p_id bigint)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_e public.purchase_price_entries;
begin
  if not (public.has_permission('product.manage') or public.has_permission('inventory.adjust')
          or public.has_permission('purchase_order.manage')) then
    raise exception 'not permitted: product.manage required';
  end if;
  select * into v_e from public.purchase_price_entries where id = p_id and removed_at is null for update;
  if v_e.id is null then
    raise exception 'price entry % not found', p_id;
  end if;
  update public.purchase_price_entries set removed_at = now(), removed_by = auth.uid() where id = p_id;
  perform public.log_audit('product.purchase_price_withdrawn', 'product', v_e.product_id::text, null,
    jsonb_build_object('entry', p_id, 'unit_price', v_e.unit_price));
  return true;
end;
$$;
revoke all on function public.purchase_price_withdraw(bigint) from public, anon;
grant execute on function public.purchase_price_withdraw(bigint) to authenticated;
