-- 0110 — the product library as the hub: each supplier's way of naming a
-- product, and its attributes, hang from the product.
--
-- Until now what a trading company calls our product lived in two places
-- that did not know about each other: `supplier_product_names` (0087/0103:
-- one name, 品番, JAN and maker per supplier and product, typed by a person
-- or remembered at inspection) and `notation_dialects` (0105: every spelling
-- seen, learned from imports and pre-training). Pre-training filled only the
-- second, so the product page never showed what training had learned. And a
-- product's attributes — colour, size, capacity, material — had no place at
-- all, though each company heads and writes them its own way ("カラー: BK"
-- for our "色: 黒").
--
--   * `product_attributes` — our attribute master (色, サイズ, 容量, 規格,
--     材質, 重量, 入数 to start; more can be added). `product_attribute_values`
--     — our value of each for each product.
--   * `supplier_product_attributes` — per supplier and product: how that
--     company heads the attribute and what it writes for it.
--   * `attribute_value_aliases` — a company's word for one of our values
--     ("BK" → "黒"), learned whenever a supplier's value sits beside ours.
--   * `column_aliases` learns attribute headings too (field 'attr' with the
--     attribute), so the reader puts "カラー" / "Colour" / "色番" columns into
--     the right attribute; 色 / サイズ / 容量, which the reader used to lump
--     into 規格, now go to their own attributes.
--   * Learning (imports, pre-training, the product page) now writes the
--     supplier's profile row as well as the dialects, plus the attributes.
--   * `product_supplier_profile(product)` — everything each supplier calls
--     this product, in one answer, for the product library.
--   * The library versions of 0108 carry attribute headings and value words.

-- ------------------------------------------------------------ attributes

create table if not exists public.product_attributes (
  id bigint generated always as identity primary key,
  key text not null unique check (key ~ '^[a-z][a-z0-9_]{1,39}$'),
  name text not null check (btrim(name) <> ''),
  unit text,
  sort_order integer not null default 100,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now()
);
alter table public.product_attributes enable row level security;
drop policy if exists "product_attributes: signed-in can read" on public.product_attributes;
create policy "product_attributes: signed-in can read" on public.product_attributes
  for select to authenticated using (true);

insert into public.product_attributes (key, name, unit, sort_order) values
  ('color', '色', null, 10), ('size', 'サイズ', null, 20), ('capacity', '容量', null, 30),
  ('spec', '規格', null, 40), ('material', '材質', null, 50), ('weight', '重量', 'g', 60),
  ('case_quantity', '入数', '個', 70)
on conflict (key) do nothing;

create table if not exists public.product_attribute_values (
  product_id bigint not null references public.products(id) on delete cascade,
  attribute_id bigint not null references public.product_attributes(id) on delete cascade,
  value text not null check (btrim(value) <> ''),
  value_key text not null,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  primary key (product_id, attribute_id)
);
alter table public.product_attribute_values enable row level security;
drop policy if exists "product_attribute_values: signed-in can read" on public.product_attribute_values;
create policy "product_attribute_values: signed-in can read" on public.product_attribute_values
  for select to authenticated using (true);

create table if not exists public.supplier_product_attributes (
  id bigint generated always as identity primary key,
  supplier_id bigint not null references public.delivery_suppliers(id) on delete cascade,
  product_id bigint not null references public.products(id) on delete cascade,
  attribute_id bigint not null references public.product_attributes(id) on delete cascade,
  raw_name text,
  raw_value text not null check (btrim(raw_value) <> ''),
  value_key text not null,
  source text not null default 'manual'
    check (source in ('manual', 'import', 'inspection', 'ai', 'restore')),
  seen_count integer not null default 1,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (supplier_id, product_id, attribute_id)
);
create index if not exists supplier_product_attributes_product on public.supplier_product_attributes (product_id);
alter table public.supplier_product_attributes enable row level security;
drop policy if exists "supplier_product_attributes: product viewers can read" on public.supplier_product_attributes;
create policy "supplier_product_attributes: product viewers can read" on public.supplier_product_attributes
  for select to authenticated using (
    public.has_permission('product.view') or public.has_permission('purchase_order.view')
    or public.has_permission('receiving.view') or public.has_permission('inspection.view'));

create table if not exists public.attribute_value_aliases (
  id bigint generated always as identity primary key,
  partner_id bigint references public.delivery_suppliers(id) on delete cascade,
  attribute_id bigint not null references public.product_attributes(id) on delete cascade,
  raw_value text not null,
  value_key text not null,
  value text not null,
  source text not null default 'manual'
    check (source in ('manual', 'import', 'inspection', 'ai', 'seed', 'restore')),
  seen_count integer not null default 1,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
create unique index if not exists attribute_value_aliases_key
  on public.attribute_value_aliases (coalesce(partner_id, 0), attribute_id, value_key);
alter table public.attribute_value_aliases enable row level security;
drop policy if exists "attribute_value_aliases: signed-in can read" on public.attribute_value_aliases;
create policy "attribute_value_aliases: signed-in can read" on public.attribute_value_aliases
  for select to authenticated using (true);

-- ------------------------------------------------------------ attribute headings

alter table public.column_aliases add column if not exists attribute_id bigint
  references public.product_attributes(id) on delete cascade;
alter table public.column_aliases drop constraint if exists column_aliases_field_check;
alter table public.column_aliases add constraint column_aliases_field_check check (field in (
  'jan', 'maker', 'product_name', 'product_code', 'name_code', 'quantity',
  'case_quantity', 'cases', 'unit_price', 'amount', 'spec', 'tax_rate',
  'order_date', 'ignore', 'attr'));
alter table public.column_aliases drop constraint if exists column_aliases_attr_check;
alter table public.column_aliases add constraint column_aliases_attr_check
  check ((field = 'attr') = (attribute_id is not null));

-- 色 / サイズ / 容量 were read as 規格; they are attributes of their own now.
update public.column_aliases a
   set field = 'attr', attribute_id = (select id from public.product_attributes where key = m.k)
  from (values ('色', 'color'), ('カラー', 'color'), ('Color', 'color'), ('Colour', 'color'),
               ('サイズ', 'size'), ('Size', 'size'), ('容量', 'capacity'), ('Capacity', 'capacity')) m(h, k)
 where a.partner_id is null and a.header_key = public.normalize_product_text(m.h);

insert into public.column_aliases (partner_id, header_raw, header_key, field, attribute_id, source)
select null, h, public.normalize_product_text(h), 'attr', (select id from public.product_attributes where key = k), 'seed'
  from (values
    ('色', 'color'), ('カラー', 'color'), ('Color', 'color'), ('Colour', 'color'), ('色番', 'color'),
    ('カラー名', 'color'), ('色名', 'color'),
    ('サイズ', 'size'), ('Size', 'size'), ('寸法', 'size'), ('大きさ', 'size'), ('Dimensions', 'size'),
    ('容量', 'capacity'), ('Capacity', 'capacity'), ('内容量', 'capacity'), ('Volume', 'capacity'),
    ('材質', 'material'), ('素材', 'material'), ('Material', 'material'),
    ('重量', 'weight'), ('重さ', 'weight'), ('Weight', 'weight'), ('正味重量', 'weight')
  ) s(h, k)
on conflict (coalesce(partner_id, 0), header_key) do nothing;

create or replace function public.column_alias_map(p_partner_id bigint default null)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'header_key', a.header_key, 'field', a.field,
           'attribute', pa.key,
           'partner', a.partner_id is not null, 'source', a.source)
         order by (a.partner_id is null)), '[]'::jsonb)
    from public.column_aliases a
    left join public.product_attributes pa on pa.id = a.attribute_id
   where (a.partner_id is null or a.partner_id = p_partner_id)
     and (a.attribute_id is null or pa.status = 'active');
$$;

-- [{header, field, attribute?}] as confirmed for this company's file.
create or replace function public.learn_column_aliases(
  p_partner_id bigint, p_map jsonb, p_source text default 'import')
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  e jsonb;
  v_key text;
  v_n int := 0;
  g record;
  v_attr bigint;
begin
  if not (public.has_permission('receiving.confirm') or public.has_permission('product.manage')
          or public.has_permission('pack.complete')) then
    raise exception 'not permitted: receiving.confirm required';
  end if;
  if p_partner_id is null then
    return 0;
  end if;
  for e in select * from jsonb_array_elements(coalesce(p_map, '[]'::jsonb)) loop
    v_key := public.normalize_product_text(e->>'header');
    continue when nullif(v_key, '') is null or nullif(e->>'field', '') is null;
    v_attr := null;
    if e->>'field' = 'attr' then
      select id into v_attr from public.product_attributes where key = e->>'attribute';
      continue when v_attr is null;
    end if;
    -- A heading everyone uses the same way needs no entry of this company's own.
    select field, attribute_id into g from public.column_aliases
     where partner_id is null and header_key = v_key;
    continue when g.field = e->>'field' and g.attribute_id is not distinct from v_attr;
    insert into public.column_aliases (partner_id, header_raw, header_key, field, attribute_id, source)
    values (p_partner_id, btrim(e->>'header'), v_key, e->>'field', v_attr,
            case when p_source in ('manual', 'import', 'ai') then p_source else 'import' end)
    on conflict (coalesce(partner_id, 0), header_key) do update
       set field = excluded.field, attribute_id = excluded.attribute_id,
           seen_count = column_aliases.seen_count + 1, last_seen_at = now();
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

create or replace function public.list_column_aliases(p_partner_id bigint default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('product.view') or public.has_permission('purchase_order.view')) then
    raise exception 'not permitted: product.view required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', a.id, 'partner_id', a.partner_id, 'partner_name', s.name,
             'header', a.header_raw, 'field', a.field,
             'attribute', pa.key, 'attribute_name', pa.name, 'source', a.source,
             'seen_count', a.seen_count, 'last_seen_at', a.last_seen_at)
           order by (a.partner_id is null), a.field, a.header_raw)
      from public.column_aliases a
      left join public.delivery_suppliers s on s.id = a.partner_id
      left join public.product_attributes pa on pa.id = a.attribute_id
     where p_partner_id is null or a.partner_id = p_partner_id or a.partner_id is null
  ), '[]'::jsonb);
end;
$$;

-- ------------------------------------------------------------ learning

-- A supplier's value for one of a product's attributes: kept on the
-- product, and, when we have our own value, the supplier's word for it
-- remembered ("BK" → "黒"). A word already meaning another of our values
-- is left as it is.
create or replace function public.learn_supplier_attribute_impl(
  p_supplier_id bigint, p_product_id bigint, p_attribute_id bigint,
  p_raw_name text, p_raw_value text, p_source text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_raw  text := nullif(btrim(coalesce(p_raw_value, '')), '');
  v_key  text;
  v_ours record;
  v_src  text := case when p_source in ('manual', 'import', 'inspection', 'ai', 'restore') then p_source else 'import' end;
  v_alias boolean := false;
begin
  if v_raw is null or p_supplier_id is null or p_product_id is null or p_attribute_id is null then
    return null;
  end if;
  v_key := public.normalize_product_text(v_raw);
  insert into public.supplier_product_attributes
    (supplier_id, product_id, attribute_id, raw_name, raw_value, value_key, source)
  values (p_supplier_id, p_product_id, p_attribute_id, nullif(btrim(coalesce(p_raw_name, '')), ''), v_raw, v_key, v_src)
  on conflict (supplier_id, product_id, attribute_id) do update
     set raw_name = coalesce(excluded.raw_name, supplier_product_attributes.raw_name),
         raw_value = excluded.raw_value, value_key = excluded.value_key,
         source = excluded.source,
         seen_count = supplier_product_attributes.seen_count + 1, last_seen_at = now();

  select value, value_key into v_ours from public.product_attribute_values
   where product_id = p_product_id and attribute_id = p_attribute_id;
  if v_ours.value is not null and v_ours.value_key <> v_key then
    insert into public.attribute_value_aliases (partner_id, attribute_id, raw_value, value_key, value, source)
    values (p_supplier_id, p_attribute_id, v_raw, v_key, v_ours.value,
            case when v_src = 'restore' then 'restore' else v_src end)
    on conflict (coalesce(partner_id, 0), attribute_id, value_key) do update
       set seen_count = attribute_value_aliases.seen_count + 1, last_seen_at = now()
     where attribute_value_aliases.value = excluded.value;
    v_alias := true;
  end if;
  return jsonb_build_object('attribute_id', p_attribute_id, 'alias', v_alias);
end;
$$;
revoke all on function public.learn_supplier_attribute_impl(bigint, bigint, bigint, text, text, text)
  from public, anon, authenticated;

-- What a supplier's word for an attribute value means in ours.
create or replace function public.our_attribute_value(p_partner_id bigint, p_attribute_id bigint, p_raw text)
returns text
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select value from public.attribute_value_aliases
      where attribute_id = p_attribute_id and value_key = public.normalize_product_text(p_raw)
        and (partner_id = p_partner_id or partner_id is null)
      order by (partner_id is null) limit 1),
    p_raw);
$$;
revoke all on function public.our_attribute_value(bigint, bigint, text) from public, anon;
grant execute on function public.our_attribute_value(bigint, bigint, text) to authenticated, service_role;

-- The supplier's profile row for a product, from a line it wrote.
create or replace function public.learn_supplier_profile_impl(p_supplier_id bigint, p_product_id bigint, e jsonb)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  pr record;
  v_name text := nullif(btrim(coalesce(e->>'product_name', '')), '');
  v_code text := nullif(btrim(coalesce(e->>'product_code', '')), '');
  v_jan  text := nullif(btrim(coalesce(e->>'jan_code', '')), '');
  v_maker text := nullif(btrim(coalesce(e->>'maker', '')), '');
begin
  if p_supplier_id is null or p_product_id is null
     or (v_name is null and v_code is null and v_jan is null and v_maker is null) then
    return false;
  end if;
  select id, name, jan_code into pr from public.products where id = p_product_id;
  if pr.id is null then return false; end if;
  if v_code is not null and exists (
       select 1 from public.supplier_product_names
        where supplier_id = p_supplier_id and supplier_code = v_code and product_id <> p_product_id) then
    v_code := null;
  end if;
  if public.normalize_jan(v_jan) = pr.jan_code then v_jan := null; end if;
  insert into public.supplier_product_names
    (supplier_id, product_id, supplier_code, supplier_name, supplier_jan_code, supplier_maker)
  values (p_supplier_id, p_product_id, v_code, coalesce(v_name, pr.name), v_jan, v_maker)
  on conflict (supplier_id, product_id) do update
     set supplier_code = coalesce(excluded.supplier_code, supplier_product_names.supplier_code),
         supplier_name = coalesce(v_name, supplier_product_names.supplier_name),
         supplier_jan_code = coalesce(excluded.supplier_jan_code, supplier_product_names.supplier_jan_code),
         supplier_maker = coalesce(excluded.supplier_maker, supplier_product_names.supplier_maker),
         updated_at = now();
  return true;
end;
$$;
revoke all on function public.learn_supplier_profile_impl(bigint, bigint, jsonb) from public, anon, authenticated;

-- The profile row feeds the dictionary (0105) — except while a line is being
-- learned, which feeds the dictionary itself (so nothing is counted twice).
create or replace function public.supplier_product_name_to_dialects()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if current_setting('wms.learning_lines', true) = 'on' then
    return null;
  end if;
  perform public.learn_notation_impl(new.supplier_id, new.product_id, 'code', new.supplier_code, 'manual', true);
  perform public.learn_notation_impl(new.supplier_id, new.product_id, 'name', new.supplier_name, 'manual', true);
  perform public.learn_notation_impl(new.supplier_id, new.product_id, 'jan', new.supplier_jan_code, 'manual', true);
  perform public.learn_notation_impl(new.supplier_id, new.product_id, 'maker', new.supplier_maker, 'manual', true);
  return null;
end;
$$;

-- Lines of {product_id, jan_code, maker, product_name, product_code,
-- attributes: [{key, name, value}]} as a company wrote them, now tied to our
-- products: the dictionary, the supplier's profile of the product, and its
-- attributes.
create or replace function public.learn_notation_lines(
  p_partner_id bigint, p_lines jsonb, p_source text default 'import',
  p_confirmed boolean default true)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  e         jsonb;
  a         jsonb;
  r         jsonb;
  v_pid     bigint;
  v_attr    bigint;
  v_learned int := 0;
  v_new     int := 0;
  v_profiles int := 0;
  v_attrs   int := 0;
  v_conf    jsonb := '[]'::jsonb;
  f         text;
begin
  if not (public.has_permission('receiving.confirm') or public.has_permission('product.manage')
          or public.has_permission('inspection.confirm') or public.has_permission('pack.complete')) then
    raise exception 'not permitted: receiving.confirm required';
  end if;
  if p_source not in ('manual', 'import', 'inspection', 'ai') then
    raise exception 'unknown source %', p_source;
  end if;
  perform set_config('wms.learning_lines', 'on', true);
  for e in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_pid := nullif(e->>'product_id', '')::bigint;
    continue when v_pid is null;
    foreach f in array array['jan', 'maker', 'name', 'code'] loop
      r := public.learn_notation_impl(p_partner_id, v_pid, f,
             e->>(case f when 'jan' then 'jan_code' when 'maker' then 'maker'
                         when 'name' then 'product_name' else 'product_code' end),
             p_source, p_confirmed);
      continue when r is null;
      if (r->>'conflict')::boolean is true then
        v_conf := v_conf || r;
      else
        v_learned := v_learned + 1;
        if (r->>'new')::boolean is true then v_new := v_new + 1; end if;
      end if;
    end loop;
    if p_confirmed and p_partner_id is not null then
      if public.learn_supplier_profile_impl(p_partner_id, v_pid, e) then
        v_profiles := v_profiles + 1;
      end if;
      for a in select * from jsonb_array_elements(coalesce(e->'attributes', '[]'::jsonb)) loop
        select id into v_attr from public.product_attributes
         where key = a->>'key' or id = nullif(a->>'attribute_id', '')::bigint
         limit 1;
        continue when v_attr is null;
        if public.learn_supplier_attribute_impl(p_partner_id, v_pid, v_attr, a->>'name', a->>'value', p_source) is not null then
          v_attrs := v_attrs + 1;
        end if;
      end loop;
    end if;
  end loop;
  perform set_config('wms.learning_lines', 'off', true);
  return jsonb_build_object('learned', v_learned, 'new', v_new, 'conflicts', v_conf,
                            'profiles', v_profiles, 'attributes', v_attrs);
end;
$$;

-- ------------------------------------------------------------ for people

create or replace function public.list_product_attributes()
returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', id, 'key', key, 'name', name, 'unit', unit,
           'sort_order', sort_order, 'status', status) order by sort_order, id), '[]'::jsonb)
    from public.product_attributes;
$$;

create or replace function public.save_product_attribute(p jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_id bigint := nullif(p->>'id', '')::bigint;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if nullif(btrim(coalesce(p->>'name', '')), '') is null then
    raise exception 'attribute name is required';
  end if;
  if v_id is null then
    insert into public.product_attributes (key, name, unit, sort_order)
    values (coalesce(nullif(lower(btrim(coalesce(p->>'key', ''))), ''),
                     'attr_' || ((select coalesce(max(id), 0) from public.product_attributes) + 1)),
            btrim(p->>'name'), nullif(btrim(coalesce(p->>'unit', '')), ''),
            coalesce(nullif(p->>'sort_order', '')::int,
                     (select coalesce(max(sort_order), 0) + 10 from public.product_attributes)))
    returning id into v_id;
  else
    update public.product_attributes
       set name = btrim(p->>'name'), unit = nullif(btrim(coalesce(p->>'unit', '')), ''),
           sort_order = coalesce(nullif(p->>'sort_order', '')::int, sort_order),
           status = coalesce(nullif(p->>'status', ''), status)
     where id = v_id;
  end if;
  perform public.log_audit('product.attribute_saved', 'product_attribute', v_id::text, null, p);
  return public.list_product_attributes();
end;
$$;

-- Our values for a product: [{attribute_id, value}]; an empty value removes it.
create or replace function public.set_product_attribute_values(p_product_id bigint, p_values jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare e jsonb; v text; v_attr bigint;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  for e in select * from jsonb_array_elements(coalesce(p_values, '[]'::jsonb)) loop
    v_attr := nullif(e->>'attribute_id', '')::bigint;
    continue when v_attr is null;
    v := nullif(btrim(coalesce(e->>'value', '')), '');
    if v is null then
      delete from public.product_attribute_values where product_id = p_product_id and attribute_id = v_attr;
    else
      insert into public.product_attribute_values (product_id, attribute_id, value, value_key, updated_by)
      values (p_product_id, v_attr, v, public.normalize_product_text(v), auth.uid())
      on conflict (product_id, attribute_id) do update
         set value = excluded.value, value_key = excluded.value_key,
             updated_at = now(), updated_by = excluded.updated_by;
      -- Each supplier's word already on file for it is now understood.
      insert into public.attribute_value_aliases (partner_id, attribute_id, raw_value, value_key, value, source)
      select s.supplier_id, v_attr, s.raw_value, s.value_key, v, 'manual'
        from public.supplier_product_attributes s
       where s.product_id = p_product_id and s.attribute_id = v_attr
         and s.value_key <> public.normalize_product_text(v)
      on conflict (coalesce(partner_id, 0), attribute_id, value_key) do nothing;
    end if;
  end loop;
  perform public.log_audit('product.attributes_set', 'product', p_product_id::text, null,
    jsonb_build_object('values', p_values));
  return public.product_supplier_profile(p_product_id);
end;
$$;

-- Everything about how this product is called: ours, and each supplier's
-- name / 品番 / JAN / maker, every spelling seen, and its attributes.
create or replace function public.product_supplier_profile(p_product_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare pr record;
begin
  if not (public.has_permission('product.view') or public.has_permission('purchase_order.view')
          or public.has_permission('receiving.view') or public.has_permission('inspection.view')) then
    raise exception 'not permitted: product.view required';
  end if;
  select id, jan_code, name, sku, maker, maker_id into pr from public.products where id = p_product_id;
  if pr.id is null then
    raise exception 'product % not found', p_product_id;
  end if;
  return jsonb_build_object(
    'product', jsonb_build_object('id', pr.id, 'jan_code', pr.jan_code, 'name', pr.name,
                                  'sku', pr.sku, 'maker', pr.maker),
    'attributes', coalesce((
      select jsonb_agg(jsonb_build_object('attribute_id', a.id, 'key', a.key, 'name', a.name,
                                          'unit', a.unit, 'value', v.value) order by a.sort_order, a.id)
        from public.product_attributes a
        left join public.product_attribute_values v on v.attribute_id = a.id and v.product_id = pr.id
       where a.status = 'active' or v.value is not null), '[]'::jsonb),
    'suppliers', coalesce((
      select jsonb_agg(jsonb_build_object(
               'supplier_id', s.id, 'supplier_name', s.name,
               'name', n.supplier_name, 'code', n.supplier_code,
               'jan_code', n.supplier_jan_code, 'maker', n.supplier_maker,
               'note', n.note, 'updated_at', n.updated_at,
               'writings', coalesce((
                 select jsonb_agg(jsonb_build_object('id', d.id, 'field', d.field,
                          'raw_values', to_jsonb(d.raw_values), 'seen_count', d.seen_count,
                          'confirmed', d.confirmed, 'source', d.source) order by d.field, d.last_seen_at desc)
                   from public.notation_dialects d
                  where d.partner_id = s.id
                    and (d.product_id = pr.id or (d.field = 'maker' and d.maker_id = pr.maker_id))), '[]'::jsonb),
               'attributes', coalesce((
                 select jsonb_agg(jsonb_build_object('id', x.id, 'attribute_id', a.id, 'key', a.key,
                          'name', a.name, 'raw_name', x.raw_name, 'raw_value', x.raw_value,
                          'our_value', public.our_attribute_value(s.id, a.id, x.raw_value),
                          'seen_count', x.seen_count, 'source', x.source) order by a.sort_order, a.id)
                   from public.supplier_product_attributes x
                   join public.product_attributes a on a.id = x.attribute_id
                  where x.supplier_id = s.id and x.product_id = pr.id), '[]'::jsonb))
             order by s.name)
        from public.delivery_suppliers s
        left join public.supplier_product_names n on n.supplier_id = s.id and n.product_id = pr.id
       where n.id is not null
          or exists (select 1 from public.notation_dialects d
                      where d.partner_id = s.id and d.product_id = pr.id)
          or exists (select 1 from public.supplier_product_attributes x
                      where x.supplier_id = s.id and x.product_id = pr.id)), '[]'::jsonb));
end;
$$;

-- A person sets how a supplier calls this product:
-- {supplier_id, product_id, name, code, jan_code, maker,
--  attributes: [{attribute_id, raw_name, raw_value}]} — an empty raw_value
-- removes that attribute from the supplier's profile.
create or replace function public.save_supplier_product_profile(p jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_sup bigint := nullif(p->>'supplier_id', '')::bigint;
  v_pid bigint := nullif(p->>'product_id', '')::bigint;
  v_name text := nullif(btrim(coalesce(p->>'name', '')), '');
  v_code text := nullif(btrim(coalesce(p->>'code', '')), '');
  a jsonb;
  v_attr bigint;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if v_sup is null or v_pid is null then
    raise exception 'supplier_id and product_id are required';
  end if;
  if v_code is not null and exists (
       select 1 from public.supplier_product_names
        where supplier_id = v_sup and supplier_code = v_code and product_id <> v_pid) then
    raise exception 'this supplier already uses the code % for another product', v_code;
  end if;
  insert into public.supplier_product_names
    (supplier_id, product_id, supplier_code, supplier_name, supplier_jan_code, supplier_maker, note)
  values (v_sup, v_pid, v_code,
          coalesce(v_name, (select name from public.products where id = v_pid)),
          nullif(btrim(coalesce(p->>'jan_code', '')), ''), nullif(btrim(coalesce(p->>'maker', '')), ''),
          nullif(btrim(coalesce(p->>'note', '')), ''))
  on conflict (supplier_id, product_id) do update
     set supplier_code = excluded.supplier_code,
         supplier_name = excluded.supplier_name,
         supplier_jan_code = excluded.supplier_jan_code,
         supplier_maker = excluded.supplier_maker,
         note = excluded.note,
         updated_at = now();
  for a in select * from jsonb_array_elements(coalesce(p->'attributes', '[]'::jsonb)) loop
    v_attr := nullif(a->>'attribute_id', '')::bigint;
    continue when v_attr is null;
    if nullif(btrim(coalesce(a->>'raw_value', '')), '') is null then
      delete from public.supplier_product_attributes
       where supplier_id = v_sup and product_id = v_pid and attribute_id = v_attr;
    else
      perform public.learn_supplier_attribute_impl(v_sup, v_pid, v_attr, a->>'raw_name', a->>'raw_value', 'manual');
    end if;
  end loop;
  perform public.log_audit('product.supplier_profile_saved', 'product', v_pid::text, null,
    jsonb_build_object('supplier_id', v_sup, 'profile', p));
  return public.product_supplier_profile(v_pid);
end;
$$;

-- The supplier's profile row and attributes for this product removed. The
-- spellings in the dictionary stay: documents in them still read.
create or replace function public.remove_supplier_product_profile(p_supplier_id bigint, p_product_id bigint)
returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  delete from public.supplier_product_names where supplier_id = p_supplier_id and product_id = p_product_id;
  delete from public.supplier_product_attributes where supplier_id = p_supplier_id and product_id = p_product_id;
  perform public.log_audit('product.supplier_profile_removed', 'product', p_product_id::text, null,
    jsonb_build_object('supplier_id', p_supplier_id));
  return public.product_supplier_profile(p_product_id);
end;
$$;

revoke all on function public.list_product_attributes() from public, anon;
revoke all on function public.save_product_attribute(jsonb) from public, anon;
revoke all on function public.set_product_attribute_values(bigint, jsonb) from public, anon;
revoke all on function public.product_supplier_profile(bigint) from public, anon;
revoke all on function public.save_supplier_product_profile(jsonb) from public, anon;
revoke all on function public.remove_supplier_product_profile(bigint, bigint) from public, anon;
grant execute on function public.list_product_attributes() to authenticated, service_role;
grant execute on function public.save_product_attribute(jsonb) to authenticated, service_role;
grant execute on function public.set_product_attribute_values(bigint, jsonb) to authenticated, service_role;
grant execute on function public.product_supplier_profile(bigint) to authenticated, service_role;
grant execute on function public.save_supplier_product_profile(jsonb) to authenticated, service_role;
grant execute on function public.remove_supplier_product_profile(bigint, bigint) to authenticated, service_role;

-- ------------------------------------------------------------ library versions

alter table public.notation_library_versions
  add column if not exists attribute_values jsonb not null default '[]'::jsonb;

create or replace function public.snapshot_notation_library_impl(
  p_partner_id bigint, p_note text, p_source text, p_training_id bigint)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
  v_dialects jsonb;
  v_aliases jsonb;
  v_values jsonb;
begin
  perform pg_advisory_xact_lock(hashtext('notation_library'), p_partner_id::integer);
  select coalesce(jsonb_agg(jsonb_build_object(
           'field', d.field, 'raw_value', d.raw_value, 'raw_values', to_jsonb(d.raw_values),
           'value_key', d.value_key, 'product_id', d.product_id, 'maker_id', d.maker_id,
           'scope_maker_id', d.scope_maker_id, 'confirmed', d.confirmed, 'source', d.source,
           'seen_count', d.seen_count) order by d.field, d.value_key), '[]')
    into v_dialects
    from public.notation_dialects d where d.partner_id = p_partner_id;
  select coalesce(jsonb_agg(jsonb_build_object(
           'header_raw', a.header_raw, 'header_key', a.header_key, 'field', a.field,
           'attribute', pa.key, 'source', a.source, 'seen_count', a.seen_count) order by a.header_key), '[]')
    into v_aliases
    from public.column_aliases a
    left join public.product_attributes pa on pa.id = a.attribute_id
   where a.partner_id = p_partner_id;
  select coalesce(jsonb_agg(jsonb_build_object(
           'attribute', pa.key, 'raw_value', v.raw_value, 'value_key', v.value_key,
           'value', v.value, 'seen_count', v.seen_count) order by pa.key, v.value_key), '[]')
    into v_values
    from public.attribute_value_aliases v
    join public.product_attributes pa on pa.id = v.attribute_id
   where v.partner_id = p_partner_id;
  insert into public.notation_library_versions
    (partner_id, version, source, training_id, note, dialects, column_aliases, attribute_values,
     dialect_count, alias_count)
  values (p_partner_id,
          coalesce((select max(version) from public.notation_library_versions where partner_id = p_partner_id), 0) + 1,
          coalesce(p_source, 'manual'), p_training_id, nullif(btrim(p_note), ''),
          v_dialects, v_aliases, v_values,
          jsonb_array_length(v_dialects), jsonb_array_length(v_aliases) + jsonb_array_length(v_values))
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.restore_notation_library_version(p_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v public.notation_library_versions%rowtype;
  d jsonb;
  a jsonb;
  v_dialects integer := 0;
  v_aliases integer := 0;
  v_conflicts jsonb := '[]'::jsonb;
  cur public.notation_dialects%rowtype;
  v_new bigint;
  v_attr bigint;
begin
  if not public.notation_training_allowed() then
    raise exception 'not permitted: product.manage required';
  end if;
  select * into v from public.notation_library_versions where id = p_id;
  if not found then raise exception 'version % not found', p_id; end if;

  for d in select * from jsonb_array_elements(v.dialects) loop
    select * into cur from public.notation_dialects x
     where coalesce(x.partner_id, 0) = v.partner_id and x.field = d->>'field'
       and x.value_key = d->>'value_key'
       and coalesce(x.scope_maker_id, 0) = coalesce((d->>'scope_maker_id')::bigint, 0);
    if not found then
      insert into public.notation_dialects (partner_id, field, raw_value, raw_values, value_key,
        product_id, maker_id, scope_maker_id, confirmed, source, seen_count)
      values (v.partner_id, d->>'field', d->>'raw_value',
        coalesce((select array_agg(e) from jsonb_array_elements_text(coalesce(d->'raw_values', '[]')) e), array[d->>'raw_value']),
        d->>'value_key', (d->>'product_id')::bigint, (d->>'maker_id')::bigint,
        (d->>'scope_maker_id')::bigint, coalesce((d->>'confirmed')::boolean, false),
        'restore', coalesce((d->>'seen_count')::integer, 1));
      v_dialects := v_dialects + 1;
    elsif cur.product_id is distinct from (d->>'product_id')::bigint
       or cur.maker_id is distinct from (d->>'maker_id')::bigint then
      v_conflicts := v_conflicts || jsonb_build_object('field', d->>'field', 'raw_value', d->>'raw_value',
        'now_product_id', cur.product_id, 'then_product_id', (d->>'product_id')::bigint);
    end if;
  end loop;

  for a in select * from jsonb_array_elements(v.column_aliases) loop
    v_attr := null;
    if a->>'field' = 'attr' then
      select id into v_attr from public.product_attributes where key = a->>'attribute';
      continue when v_attr is null;
    end if;
    if not exists (select 1 from public.column_aliases x
                    where coalesce(x.partner_id, 0) = v.partner_id and x.header_key = a->>'header_key') then
      insert into public.column_aliases (partner_id, header_raw, header_key, field, attribute_id, source, seen_count)
      values (v.partner_id, a->>'header_raw', a->>'header_key', a->>'field', v_attr, 'restore',
              coalesce((a->>'seen_count')::integer, 1));
      v_aliases := v_aliases + 1;
    end if;
  end loop;

  for a in select * from jsonb_array_elements(coalesce(v.attribute_values, '[]'::jsonb)) loop
    select id into v_attr from public.product_attributes where key = a->>'attribute';
    continue when v_attr is null;
    insert into public.attribute_value_aliases (partner_id, attribute_id, raw_value, value_key, value, source, seen_count)
    values (v.partner_id, v_attr, a->>'raw_value', a->>'value_key', a->>'value', 'restore',
            coalesce((a->>'seen_count')::integer, 1))
    on conflict (coalesce(partner_id, 0), attribute_id, value_key) do nothing;
    if found then v_aliases := v_aliases + 1; end if;
  end loop;

  v_new := public.snapshot_notation_library_impl(v.partner_id, 'v' || v.version, 'restore', null);
  perform public.log_audit('notation.library_restore', 'notation_library_version', p_id::text, null,
    jsonb_build_object('dialects', v_dialects, 'aliases', v_aliases, 'conflicts', jsonb_array_length(v_conflicts)));
  return jsonb_build_object('restored_dialects', v_dialects, 'restored_aliases', v_aliases,
                            'conflicts', v_conflicts, 'version_id', v_new);
end;
$$;
