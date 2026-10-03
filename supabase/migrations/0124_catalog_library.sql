-- 0124 — 商品ライブラリー on its own, and terms by period and branch.
--
-- The product library is now its own set of tables, apart from the product
-- master (`products`) that stock, orders, receipts and shipments hang off:
--
--   * `catalog_items` — every product a file (quotation, invoice, catalogue)
--     or a person brought in: maker, name, 品番, JAN, spec, unit, list price,
--     attributes. Reading a file again updates these rows; deleting one
--     removes only it. Neither touches the master or anything booked.
--   * `catalog_supplier_terms` — what a supplier offers an item on: its
--     name and code for it, unit price, list price, rate, case quantity and
--     minimum order, for one of its branches (支店) or our warehouse, from a
--     date (and until one). A new term for the same supplier, branch and
--     warehouse closes the one before it the day before, so the history of
--     prices stays readable.
--   * An item can be taken into the master (`catalog_to_products`): it
--     becomes a product, or is linked to the product with its JAN, and keeps
--     `product_id`. Deleting the product later only clears the link.
--   * `catalog_list` shows each item with its current terms per supplier and
--     branch, and the stock of its product (linked, or found by JAN) where
--     the caller may look.

create table if not exists public.catalog_items (
  id bigserial primary key,
  jan_code text,
  maker text,
  name text not null check (btrim(name) <> ''),
  base_name text,
  item_code text,
  spec text,
  unit text,
  category text,
  list_price numeric check (list_price is null or list_price >= 0),
  attributes jsonb not null default '[]'::jsonb,
  note text,
  source text not null default 'file' check (source in ('file', 'manual', 'master')),
  source_file text,
  product_id bigint references public.products(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid
);
create unique index if not exists catalog_items_jan on public.catalog_items (jan_code) where jan_code is not null;
create index if not exists catalog_items_maker_code on public.catalog_items (lower(maker), lower(item_code));
create index if not exists catalog_items_product on public.catalog_items (product_id);
alter table public.catalog_items enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'catalog_items'
                  and policyname = 'catalog_items: signed-in can read') then
    create policy "catalog_items: signed-in can read" on public.catalog_items for select to authenticated using (true);
  end if;
end $$;

create table if not exists public.catalog_supplier_terms (
  id bigserial primary key,
  catalog_item_id bigint not null references public.catalog_items(id) on delete cascade,
  partner_id bigint not null references public.delivery_suppliers(id) on delete cascade,
  branch text not null default '',
  warehouse_id bigint references public.warehouses(id) on delete cascade,
  their_name text,
  their_code text,
  unit_price numeric check (unit_price is null or unit_price >= 0),
  list_price numeric check (list_price is null or list_price >= 0),
  discount_rate numeric check (discount_rate is null or (discount_rate >= 0 and discount_rate <= 2)),
  case_quantity integer check (case_quantity is null or case_quantity > 0),
  moq integer check (moq is null or moq > 0),
  currency text not null default 'JPY',
  valid_from date not null default current_date,
  valid_to date,
  source text not null default 'file' check (source in ('file', 'manual')),
  source_file text,
  note text,
  created_at timestamptz not null default now(),
  created_by uuid,
  check (valid_to is null or valid_to >= valid_from)
);
create index if not exists catalog_terms_item on public.catalog_supplier_terms (catalog_item_id, partner_id, branch, valid_from desc);
alter table public.catalog_supplier_terms enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'catalog_supplier_terms'
                  and policyname = 'catalog_supplier_terms: signed-in can read') then
    create policy "catalog_supplier_terms: signed-in can read" on public.catalog_supplier_terms
      for select to authenticated using (true);
  end if;
end $$;

-- The product an item stands for in the master: its link, else its JAN.
create or replace function public.catalog_product_id(p_item public.catalog_items)
returns bigint
language sql stable security definer set search_path = '' as $$
  select coalesce(p_item.product_id,
                  (select id from public.products where p_item.jan_code is not null and jan_code = p_item.jan_code limit 1));
$$;

-- One term as JSON.
create or replace function public.catalog_term_json(t public.catalog_supplier_terms)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', t.id, 'partner_id', t.partner_id,
    'partner_name', (select name from public.delivery_suppliers where id = t.partner_id),
    'branch', nullif(t.branch, ''), 'warehouse_id', t.warehouse_id,
    'warehouse_name', (select name from public.warehouses where id = t.warehouse_id),
    'their_name', t.their_name, 'their_code', t.their_code,
    'unit_price', t.unit_price, 'list_price', t.list_price, 'discount_rate', t.discount_rate,
    'case_quantity', t.case_quantity, 'moq', t.moq, 'currency', t.currency,
    'valid_from', t.valid_from, 'valid_to', t.valid_to, 'source', t.source,
    'source_file', t.source_file, 'note', t.note, 'created_at', t.created_at);
$$;

-- The library: every item with its current terms (one per supplier, branch
-- and warehouse: the latest that has started and not ended), how many terms
-- it has had, its product in the master, and that product's stock.
create or replace function public.catalog_list(p_search text default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_q text := nullif(btrim(coalesce(p_search, '')), '');
begin
  if not public.has_permission('product.view') then
    raise exception 'not permitted: product.view required';
  end if;
  return coalesce((
    select jsonb_agg(x.j order by x.name, x.id)
      from (
        select c.id, c.name, jsonb_build_object(
          'id', c.id, 'jan_code', c.jan_code, 'maker', c.maker, 'name', c.name, 'base_name', c.base_name,
          'item_code', c.item_code, 'spec', c.spec, 'unit', c.unit, 'category', c.category,
          'list_price', c.list_price, 'attributes', c.attributes, 'note', c.note,
          'source', c.source, 'source_file', c.source_file,
          'created_at', c.created_at, 'updated_at', c.updated_at,
          'product', (select jsonb_build_object('id', p.id, 'name', p.name, 'lifecycle', p.lifecycle,
                                                'linked', c.product_id is not null)
                        from public.products p where p.id = public.catalog_product_id(c)),
          'stock', (select public.product_stock_json(public.catalog_product_id(c))
                     where public.catalog_product_id(c) is not null),
          'terms', coalesce((
            select jsonb_agg(public.catalog_term_json(t) order by t.unit_price nulls last, t.partner_id, t.branch)
              from (select distinct on (t0.partner_id, t0.branch, coalesce(t0.warehouse_id, 0)) t0.*
                      from public.catalog_supplier_terms t0
                     where t0.catalog_item_id = c.id
                       and t0.valid_from <= current_date
                       and (t0.valid_to is null or t0.valid_to >= current_date)
                     order by t0.partner_id, t0.branch, coalesce(t0.warehouse_id, 0), t0.valid_from desc, t0.id desc) t), '[]'::jsonb),
          'term_count', (select count(*) from public.catalog_supplier_terms t where t.catalog_item_id = c.id)
        ) as j
          from public.catalog_items c
         where v_q is null
            or c.name ilike '%' || v_q || '%'
            or c.maker ilike '%' || v_q || '%'
            or c.item_code ilike '%' || v_q || '%'
            or c.jan_code like '%' || v_q || '%'
            or exists (select 1 from public.catalog_supplier_terms t
                        where t.catalog_item_id = c.id
                          and (t.their_name ilike '%' || v_q || '%' or t.their_code ilike '%' || v_q || '%'))
      ) x), '[]'::jsonb);
end;
$$;

-- Every term an item has had, newest first.
create or replace function public.catalog_term_history(p_item_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('product.view') then
    raise exception 'not permitted: product.view required';
  end if;
  return coalesce((select jsonb_agg(public.catalog_term_json(t) order by t.partner_id, t.branch, t.valid_from desc, t.id desc)
                     from public.catalog_supplier_terms t where t.catalog_item_id = p_item_id), '[]'::jsonb);
end;
$$;

-- A new term: closes the open one for the same supplier, branch and
-- warehouse that started before it, the day before this one starts.
create or replace function public.catalog_add_term_impl(p_item_id bigint, e jsonb, p_source text, p_file text)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_partner bigint := nullif(e->>'partner_id', '')::bigint;
  v_branch text := coalesce(public.tidy_text(e->>'branch'), '');
  v_wh bigint := nullif(e->>'warehouse_id', '')::bigint;
  v_from date := coalesce(nullif(e->>'valid_from', '')::date, current_date);
  v_to date := nullif(e->>'valid_to', '')::date;
  v_unit numeric := nullif(e->>'unit_price', '')::numeric;
  v_list numeric := nullif(e->>'list_price', '')::numeric;
  v_rate numeric := nullif(e->>'discount_rate', '')::numeric;
  v_id bigint;
begin
  if v_partner is null then
    raise exception 'partner_id is required';
  end if;
  if v_unit is null and v_list is not null and v_rate is not null then
    v_unit := round(v_list * v_rate, 2);
  end if;
  update public.catalog_supplier_terms
     set valid_to = v_from - 1
   where catalog_item_id = p_item_id and partner_id = v_partner and branch = v_branch
     and coalesce(warehouse_id, 0) = coalesce(v_wh, 0)
     and valid_from < v_from and (valid_to is null or valid_to >= v_from);
  insert into public.catalog_supplier_terms
    (catalog_item_id, partner_id, branch, warehouse_id, their_name, their_code, unit_price, list_price,
     discount_rate, case_quantity, moq, currency, valid_from, valid_to, source, source_file, note, created_by)
  values (p_item_id, v_partner, v_branch, v_wh,
          public.tidy_text(e->>'their_name'), public.tidy_text(e->>'their_code'),
          case when v_unit >= 0 then v_unit end, case when v_list >= 0 then v_list end,
          case when v_rate between 0 and 2 then v_rate end,
          case when nullif(e->>'case_quantity', '')::numeric > 0 then (e->>'case_quantity')::numeric::int end,
          case when nullif(e->>'moq', '')::numeric > 0 then (e->>'moq')::numeric::int end,
          coalesce(public.tidy_text(e->>'currency'), 'JPY'),
          v_from, case when v_to >= v_from then v_to end, p_source, p_file, public.tidy_text(e->>'note'), auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.catalog_add_term_impl(bigint, jsonb, text, text) from public, anon, authenticated;

-- A read file into the library: an item per line (found again by its JAN,
-- else by maker and 品番, else new), and — with a supplier — its terms
-- for that supplier and branch from [p_valid_from].
-- Lines: [{jan_code, maker, product_name, base_name, product_code, spec,
--          unit, list_price, unit_price, discount_rate, case_quantity,
--          supplier_code, attributes:[{key,name,value}]}]
create or replace function public.catalog_import(
  p_lines jsonb, p_partner_id bigint default null, p_branch text default null,
  p_valid_from date default null, p_source_file text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  e jsonb;
  v_jan text;
  v_maker text;
  v_code text;
  v_name text;
  v_id bigint;
  v_created int := 0;
  v_updated int := 0;
  v_terms int := 0;
  v_skipped int := 0;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  for e in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_jan := public.normalize_jan(coalesce(nullif(e->>'raw_jan_code', ''), e->>'jan_code'));
    if length(coalesce(v_jan, '')) not in (8, 13) then v_jan := null; end if;
    v_maker := public.tidy_text(e->>'maker');
    v_code := public.tidy_text(e->>'product_code');
    v_name := coalesce(public.tidy_text(e->>'product_name'), public.tidy_text(e->>'base_name'), v_code);
    if v_name is null then
      v_skipped := v_skipped + 1;
      continue;
    end if;
    v_id := null;
    if v_jan is not null then
      select id into v_id from public.catalog_items where jan_code = v_jan;
    elsif v_code is not null then
      select id into v_id from public.catalog_items
       where jan_code is null and lower(coalesce(maker, '')) = lower(coalesce(v_maker, '')) and lower(item_code) = lower(v_code)
       limit 1;
    end if;
    if v_id is null then
      insert into public.catalog_items
        (jan_code, maker, name, base_name, item_code, spec, unit, list_price, attributes, source, source_file, created_by)
      values (v_jan, v_maker, v_name, public.tidy_text(e->>'base_name'), v_code, public.tidy_text(e->>'spec'),
              public.tidy_text(e->>'unit'), nullif(e->>'list_price', '')::numeric,
              coalesce(e->'attributes', '[]'::jsonb), 'file', p_source_file, auth.uid())
      returning id into v_id;
      v_created := v_created + 1;
    else
      update public.catalog_items
         set maker = coalesce(v_maker, maker),
             item_code = coalesce(v_code, item_code),
             spec = coalesce(public.tidy_text(e->>'spec'), spec),
             unit = coalesce(public.tidy_text(e->>'unit'), unit),
             list_price = coalesce(nullif(e->>'list_price', '')::numeric, list_price),
             attributes = case when jsonb_array_length(coalesce(e->'attributes', '[]'::jsonb)) > 0
                               then e->'attributes' else attributes end,
             source_file = coalesce(p_source_file, source_file),
             updated_at = now()
       where id = v_id;
      v_updated := v_updated + 1;
    end if;
    if p_partner_id is not null
       and (nullif(e->>'unit_price', '') is not null or nullif(e->>'list_price', '') is not null
            or public.tidy_text(e->>'supplier_code') is not null) then
      perform public.catalog_add_term_impl(v_id, jsonb_build_object(
        'partner_id', p_partner_id, 'branch', p_branch, 'valid_from', p_valid_from,
        'their_name', e->>'product_name', 'their_code', coalesce(e->>'supplier_code', e->>'product_code'),
        'unit_price', e->>'unit_price', 'list_price', e->>'list_price', 'discount_rate', e->>'discount_rate',
        'case_quantity', e->>'case_quantity'), 'file', p_source_file);
      v_terms := v_terms + 1;
    end if;
  end loop;
  perform public.log_audit('catalog.imported', 'catalog', coalesce(p_source_file, ''), null,
    jsonb_build_object('created', v_created, 'updated', v_updated, 'terms', v_terms, 'partner_id', p_partner_id));
  return jsonb_build_object('created', v_created, 'updated', v_updated, 'terms', v_terms, 'skipped', v_skipped);
end;
$$;

-- A term set by hand.
create or replace function public.catalog_add_term(p_item_id bigint, p jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if not exists (select 1 from public.catalog_items where id = p_item_id) then
    raise exception 'catalog item % not found', p_item_id;
  end if;
  perform public.catalog_add_term_impl(p_item_id, p, 'manual', null);
  return public.catalog_term_history(p_item_id);
end;
$$;

-- Items into the master: a product made for each (in our format's fields),
-- or the one with its JAN linked. The item keeps the link.
create or replace function public.catalog_to_products(p_ids bigint[])
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  c public.catalog_items;
  v_company bigint;
  v_pid bigint;
  v_created int := 0;
  v_linked int := 0;
  v_skipped int := 0;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  select id into v_company from public.companies order by id limit 1;
  for c in select * from public.catalog_items where id = any(coalesce(p_ids, '{}')) loop
    v_pid := public.catalog_product_id(c);
    if v_pid is null then
      if c.jan_code is null or public.tidy_text(c.maker) is null then
        v_skipped := v_skipped + 1;
        continue;
      end if;
      insert into public.products (company_id, jan_code, name, maker, sku, base_name, unit, list_price, category)
      values (v_company, c.jan_code, c.name, c.maker, c.item_code, coalesce(c.base_name, c.name), c.unit, c.list_price, c.category)
      returning id into v_pid;
      perform public.log_audit('product.created', 'product', v_pid::text, null,
        jsonb_build_object('jan_code', c.jan_code, 'from', 'catalog', 'catalog_item_id', c.id));
      v_created := v_created + 1;
    else
      v_linked := v_linked + 1;
    end if;
    update public.catalog_items set product_id = v_pid, updated_at = now() where id = c.id;
  end loop;
  return jsonb_build_object('created', v_created, 'linked', v_linked, 'skipped', v_skipped);
end;
$$;

-- Deleting an item is a row delete under this policy (its terms go with
-- it). A function holding a delete statement could not be applied here (a
-- migration with one waits for a confirmation, see 0118).
do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'catalog_items'
                  and policyname = 'catalog_items: managers can remove') then
    create policy "catalog_items: managers can remove" on public.catalog_items
      for delete to authenticated using (public.has_permission('product.manage'));
  end if;
end $$;
grant delete on public.catalog_items to authenticated;

grant select on public.catalog_items, public.catalog_supplier_terms to authenticated;
revoke all on function public.catalog_product_id(public.catalog_items) from public, anon;
revoke all on function public.catalog_term_json(public.catalog_supplier_terms) from public, anon;
revoke all on function public.catalog_list(text) from public, anon;
revoke all on function public.catalog_term_history(bigint) from public, anon;
revoke all on function public.catalog_import(jsonb, bigint, text, date, text) from public, anon;
revoke all on function public.catalog_add_term(bigint, jsonb) from public, anon;
revoke all on function public.catalog_to_products(bigint[]) from public, anon;
grant execute on function public.catalog_product_id(public.catalog_items) to authenticated, service_role;
grant execute on function public.catalog_term_json(public.catalog_supplier_terms) to authenticated, service_role;
grant execute on function public.catalog_list(text) to authenticated, service_role;
grant execute on function public.catalog_term_history(bigint) to authenticated, service_role;
grant execute on function public.catalog_import(jsonb, bigint, text, date, text) to authenticated, service_role;
grant execute on function public.catalog_add_term(bigint, jsonb) to authenticated, service_role;
grant execute on function public.catalog_to_products(bigint[]) to authenticated, service_role;
