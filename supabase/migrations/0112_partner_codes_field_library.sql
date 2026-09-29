-- 0112 — our own partner codes, the field library, and the codes a
-- trading company uses upstream of us.
--
-- A wholesaler's quote carries three codes that are not ours:
--   * 得意先コード (5001033) — the wholesaler's code for US;
--   * 仕入先コード (90, 724, …) — the wholesaler's code for ITS supplier,
--     the maker upstream of it (724 = ミツビシ);
--   * 商品コード — its own item code (0111 `supplier_code`).
-- We had no code of our own for the wholesaler. Now:
--
--   * Every trading company gets OUR code (`delivery_suppliers.code`),
--     numbered by a rule we set per kind (`partner_code_formats`, e.g.
--     S00001 for suppliers) when none is given, and changeable later.
--     Its code for us is kept beside it (`their_code_for_us`), filled from
--     the first document that shows it.
--   * `partner_vendor_codes` — a company's codes for its own suppliers,
--     learned with the maker of the product on the same line; a later line
--     with the code but no maker gets the maker from it.
--   * `document_fields` — the field library. Every field a document column
--     can mean (JAN, メーカー, 品番, …) is one row; the headings each company
--     uses for it (JAN, JANコード, ジャパンコード, …) hang off it through
--     `column_aliases`, and the name the system SHOWS for it is ours to
--     choose (`labels`, per language; empty = the built-in name).

-- ------------------------------------------------------------ field library

create table if not exists public.document_fields (
  key text primary key,
  labels jsonb not null default '{}'::jsonb,
  description text,
  sort_order int not null default 100,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
alter table public.document_fields enable row level security;
drop policy if exists "document_fields: signed-in can read" on public.document_fields;
create policy "document_fields: signed-in can read" on public.document_fields
  for select to authenticated using (true);

insert into public.document_fields (key, sort_order, description) values
  ('jan', 10, 'JANコード（バーコードの13桁・8桁）'),
  ('maker', 20, 'メーカー・ブランド'),
  ('product_name', 30, '商品名'),
  ('product_code', 40, 'メーカーの品番・型番'),
  ('name_code', 45, '商品名と品番が1つの欄に入っているもの'),
  ('supplier_code', 50, '取引先独自の商品コード'),
  ('upstream_code', 55, '取引先の仕入先コード（取引先がさらに仕入れているメーカー等のコード）'),
  ('customer_code', 57, '得意先コード（取引先から見た当社のコード）'),
  ('quantity', 60, '数量（総数）'),
  ('unit', 65, '単位（本・冊・個・パックなど）'),
  ('case_quantity', 70, '入数（1ケースあたり）'),
  ('cases', 75, 'ケース数・箱数'),
  ('unit_price', 80, '単価（実際に払う価格）'),
  ('list_price', 85, '定価・上代'),
  ('discount_rate', 88, '掛率'),
  ('amount', 90, '金額'),
  ('tax_rate', 95, '税率'),
  ('spec', 100, '規格・仕様'),
  ('order_date', 110, '日付'),
  ('attr', 120, '商品の属性（色・サイズなど。どの属性かは属性ごと）'),
  ('ignore', 200, '読まない欄（備考・行番号など）')
on conflict (key) do nothing;

-- A heading means one of the library's fields.
alter table public.column_aliases drop constraint if exists column_aliases_field_check;
alter table public.column_aliases drop constraint if exists column_aliases_field_fk;
alter table public.column_aliases add constraint column_aliases_field_fk
  foreign key (field) references public.document_fields(key) on update cascade;

insert into public.column_aliases (partner_id, header_raw, header_key, field, source)
select null, h, public.normalize_product_text(h), f, 'seed'
  from (values
    ('ジャパンコード', 'jan'), ('JAPANコード', 'jan'), ('JAN番号', 'jan'), ('商品JAN', 'jan'),
    ('JANCODE13', 'jan'), ('ジャン', 'jan'),
    ('仕入先コード', 'upstream_code'), ('仕入先CD', 'upstream_code'), ('仕入先番号', 'upstream_code'),
    ('仕入先No', 'upstream_code'), ('仕入れ先コード', 'upstream_code'), ('ベンダーコード', 'upstream_code'),
    ('Vendor Code', 'upstream_code'), ('Vendor No', 'upstream_code'),
    ('得意先コード', 'customer_code'), ('得意先CD', 'customer_code'), ('得意先番号', 'customer_code'),
    ('お客様コード', 'customer_code'), ('顧客コード', 'customer_code'), ('Customer Code', 'customer_code'),
    ('Customer No', 'customer_code'), ('Account No', 'customer_code'),
    ('店名', 'ignore'), ('件名', 'ignore'), ('行NO', 'ignore'), ('行備考', 'ignore'), ('見積NO', 'ignore'),
    ('見積日付', 'order_date')
  ) s(h, f)
on conflict (coalesce(partner_id, 0), header_key) do nothing;

-- Everyone may know what the system calls each field.
create or replace function public.document_field_labels()
returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_object_agg(key, labels), '{}'::jsonb)
    from public.document_fields where labels <> '{}'::jsonb;
$$;

create or replace function public.document_headings_json(p_field text, p_attribute_id bigint)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', a.id, 'header', a.header_raw, 'partner_id', a.partner_id,
           'partner_name', s.name, 'source', a.source, 'seen_count', a.seen_count)
         order by (a.partner_id is not null), s.name, a.header_raw), '[]'::jsonb)
    from public.column_aliases a
    left join public.delivery_suppliers s on s.id = a.partner_id
   where a.field = p_field and a.attribute_id is not distinct from p_attribute_id;
$$;
revoke all on function public.document_headings_json(text, bigint) from public, anon, authenticated;

-- The library: each field with our names for it and every heading that
-- means it, then each attribute likewise.
create or replace function public.list_document_fields()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('product.view') or public.has_permission('product.manage')
          or public.has_permission('purchase_order.view')) then
    raise exception 'not permitted: product.view required';
  end if;
  return jsonb_build_object(
    'fields', coalesce((
      select jsonb_agg(jsonb_build_object(
               'key', f.key, 'labels', f.labels, 'description', f.description, 'sort_order', f.sort_order,
               'headings', case when f.key = 'attr' then '[]'::jsonb
                                else public.document_headings_json(f.key, null) end)
             order by f.sort_order, f.key)
        from public.document_fields f), '[]'::jsonb),
    'attributes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', p.id, 'key', p.key, 'name', p.name, 'unit', p.unit, 'status', p.status,
               'headings', public.document_headings_json('attr', p.id))
             order by p.id)
        from public.product_attributes p), '[]'::jsonb));
end;
$$;

-- Our names for a field, per language ({"ja": "JAN", "en": "JAN code"});
-- an empty one falls back to the built-in name.
create or replace function public.save_document_field(p_key text, p_labels jsonb, p_description text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_labels jsonb := '{}'::jsonb;
  e record;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if not exists (select 1 from public.document_fields where key = p_key) then
    raise exception 'unknown field %', p_key;
  end if;
  for e in select key, value from jsonb_each_text(coalesce(p_labels, '{}'::jsonb)) loop
    if e.key in ('ja', 'en', 'zh') and public.tidy_text(e.value) is not null then
      v_labels := v_labels || jsonb_build_object(e.key, public.tidy_text(e.value));
    end if;
  end loop;
  update public.document_fields
     set labels = v_labels,
         description = coalesce(public.tidy_text(p_description), description),
         updated_at = now(), updated_by = auth.uid()
   where key = p_key;
  perform public.log_audit('document_field.saved', 'document_field', p_key, null,
    jsonb_build_object('labels', v_labels));
  return public.list_document_fields();
end;
$$;

-- A heading taught by hand, for one company (or everyone when null), that
-- may mean one of our attributes.
create or replace function public.set_column_alias(
  p_partner_id bigint, p_header text, p_field text, p_attribute text)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
  v_key text := public.normalize_product_text(p_header);
  v_attr bigint;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if nullif(v_key, '') is null then
    raise exception 'a column heading is required';
  end if;
  if p_field = 'attr' then
    select id into v_attr from public.product_attributes where key = p_attribute;
    if v_attr is null then
      raise exception 'unknown attribute %', p_attribute;
    end if;
  end if;
  insert into public.column_aliases (partner_id, header_raw, header_key, field, attribute_id, source)
  values (p_partner_id, btrim(p_header), v_key, p_field, v_attr, 'manual')
  on conflict (coalesce(partner_id, 0), header_key) do update
     set field = excluded.field, attribute_id = excluded.attribute_id, source = 'manual', last_seen_at = now()
  returning id into v_id;
  return v_id;
end;
$$;

-- ------------------------------------------------------------ our partner codes

alter table public.delivery_suppliers add column if not exists their_code_for_us text;

create table if not exists public.partner_code_formats (
  kind text primary key check (kind in ('supplier', 'customer', 'both')),
  prefix text not null default '' check (prefix ~ '^[A-Za-z0-9_-]{0,10}$'),
  digits int not null default 5 check (digits between 1 and 10),
  next_number bigint not null default 1 check (next_number >= 1),
  updated_at timestamptz not null default now(),
  updated_by uuid
);
alter table public.partner_code_formats enable row level security;
drop policy if exists "partner_code_formats: signed-in can read" on public.partner_code_formats;
create policy "partner_code_formats: signed-in can read" on public.partner_code_formats
  for select to authenticated using (true);

insert into public.partner_code_formats (kind, prefix, digits) values
  ('supplier', 'S', 5), ('customer', 'C', 5), ('both', 'B', 5)
on conflict (kind) do nothing;

-- The next free code of a kind (a code someone typed by hand is skipped).
create or replace function public.next_partner_code(p_kind text)
returns text
language plpgsql security definer set search_path = '' as $$
declare
  f record;
  v_code text;
begin
  loop
    update public.partner_code_formats set next_number = next_number + 1
     where kind = coalesce(p_kind, 'supplier')
     returning prefix, digits, next_number - 1 as n into f;
    if f.n is null then
      raise exception 'no code format for %', p_kind;
    end if;
    v_code := f.prefix || lpad(f.n::text, greatest(f.digits, length(f.n::text)), '0');
    exit when not exists (select 1 from public.delivery_suppliers where code = v_code);
  end loop;
  return v_code;
end;
$$;
revoke all on function public.next_partner_code(text) from public, anon, authenticated;

create or replace function public.delivery_suppliers_issue_code()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if nullif(btrim(coalesce(new.code, '')), '') is null then
    new.code := public.next_partner_code(coalesce(new.kind, 'supplier'));
  end if;
  return new;
end;
$$;
revoke all on function public.delivery_suppliers_issue_code() from public, anon, authenticated;

drop trigger if exists delivery_suppliers_b_issue_code on public.delivery_suppliers;
create trigger delivery_suppliers_b_issue_code
  before insert on public.delivery_suppliers
  for each row execute function public.delivery_suppliers_issue_code();

-- Companies without a code get one now.
update public.delivery_suppliers set code = public.next_partner_code(kind)
 where nullif(btrim(coalesce(code, '')), '') is null;

create or replace function public.list_partner_code_formats()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('partner.view') then
    raise exception 'not permitted: partner.view required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'kind', kind, 'prefix', prefix, 'digits', digits, 'next_number', next_number,
             'next_code', prefix || lpad(next_number::text, greatest(digits, length(next_number::text)), '0'))
           order by case kind when 'supplier' then 1 when 'customer' then 2 else 3 end)
      from public.partner_code_formats), '[]'::jsonb);
end;
$$;

create or replace function public.save_partner_code_format(
  p_kind text, p_prefix text, p_digits int, p_next_number bigint default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_permission('partner.manage') then
    raise exception 'not permitted: partner.manage required';
  end if;
  update public.partner_code_formats
     set prefix = coalesce(btrim(p_prefix), ''),
         digits = coalesce(p_digits, digits),
         next_number = coalesce(p_next_number, next_number),
         updated_at = now(), updated_by = auth.uid()
   where kind = p_kind;
  if not found then
    raise exception 'unknown kind %', p_kind;
  end if;
  perform public.log_audit('partner.code_format_saved', 'partner_code_format', p_kind, null,
    jsonb_build_object('prefix', p_prefix, 'digits', p_digits, 'next_number', p_next_number));
  return public.list_partner_code_formats();
end;
$$;

-- Our code for a company, and its code for us. An empty code of ours keeps
-- the one it has.
create or replace function public.set_partner_codes(p_id bigint, p_code text, p_their_code_for_us text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_code text := nullif(btrim(coalesce(p_code, '')), '');
  v_old text;
begin
  if not public.has_permission('partner.manage') then
    raise exception 'not permitted: partner.manage required';
  end if;
  select code into v_old from public.delivery_suppliers where id = p_id;
  if not found then
    raise exception 'trading partner % not found', p_id;
  end if;
  if v_old = 'UNKNOWN' and v_code is distinct from v_old then
    raise exception 'the unidentified bucket keeps its code';
  end if;
  if v_code is not null and exists (select 1 from public.delivery_suppliers where code = v_code and id <> p_id) then
    raise exception 'code % is already used by another company', v_code;
  end if;
  update public.delivery_suppliers
     set code = coalesce(v_code, code),
         their_code_for_us = nullif(btrim(coalesce(p_their_code_for_us, '')), ''),
         updated_at = now()
   where id = p_id;
  perform public.log_audit('partner.codes_set', 'trading_partner', p_id::text, null,
    jsonb_build_object('from', v_old, 'code', coalesce(v_code, v_old), 'their_code_for_us', p_their_code_for_us));
  return (select jsonb_build_object('id', id, 'code', code, 'their_code_for_us', their_code_for_us)
            from public.delivery_suppliers where id = p_id);
end;
$$;

create or replace function public.issue_missing_partner_codes()
returns integer
language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  if not public.has_permission('partner.manage') then
    raise exception 'not permitted: partner.manage required';
  end if;
  update public.delivery_suppliers set code = public.next_partner_code(kind)
   where nullif(btrim(coalesce(code, '')), '') is null;
  get diagnostics n = row_count;
  return n;
end;
$$;

-- ------------------------------------------------------------ codes upstream of us

create table if not exists public.partner_vendor_codes (
  id bigint generated always as identity primary key,
  partner_id bigint not null references public.delivery_suppliers(id) on delete cascade,
  code text not null,
  code_key text not null,
  maker_id bigint references public.makers(id) on delete set null,
  raw_maker text,
  source text not null default 'import',
  seen_count int not null default 1,
  last_seen_at timestamptz not null default now(),
  unique (partner_id, code_key)
);
alter table public.partner_vendor_codes enable row level security;
drop policy if exists "partner_vendor_codes: signed-in can read" on public.partner_vendor_codes;
create policy "partner_vendor_codes: signed-in can read" on public.partner_vendor_codes
  for select to authenticated using (true);

create or replace function public.list_partner_vendor_codes(p_partner_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('partner.view') then
    raise exception 'not permitted: partner.view required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', c.id, 'code', c.code, 'maker_id', c.maker_id, 'maker_name', m.name,
             'raw_maker', c.raw_maker, 'seen_count', c.seen_count, 'last_seen_at', c.last_seen_at)
           order by c.code)
      from public.partner_vendor_codes c
      left join public.makers m on m.id = c.maker_id
     where c.partner_id = p_partner_id), '[]'::jsonb);
end;
$$;

create or replace function public.list_trading_partners(
  p_kind text default null,
  p_search text default null,
  p_status text default 'active'
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('partner.view') then
    raise exception 'not permitted: partner.view required';
  end if;

  return coalesce(
    (select jsonb_agg(jsonb_build_object(
        'id', s.id, 'code', s.code, 'name', s.name, 'kind', s.kind,
        'contact_name', s.contact_name, 'phone', s.phone, 'email', s.email,
        'address', s.address, 'payment_terms', s.payment_terms, 'notes', s.notes,
        'status', s.status, 'country_code', s.country_code, 'created_at', s.created_at, 'updated_at', s.updated_at,
        'their_code_for_us', s.their_code_for_us,
        'vendor_codes', (select count(*) from public.partner_vendor_codes c where c.partner_id = s.id)
      ) order by s.name)
      from public.delivery_suppliers s
     where (p_status is null or s.status = p_status)
       and (p_kind is null or s.kind = p_kind or s.kind = 'both')
       and (p_search is null or p_search = '' or
            s.name ilike '%' || p_search || '%' or
            coalesce(s.code, '') ilike '%' || p_search || '%' or
            coalesce(s.their_code_for_us, '') ilike '%' || p_search || '%')),
    '[]'::jsonb);
end;
$$;

-- ------------------------------------------------------------ learning and proposing

create or replace function public.learn_supplier_profile_impl(p_supplier_id bigint, p_product_id bigint, e jsonb)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  pr record;
  v_name text := nullif(btrim(coalesce(e->>'product_name', '')), '');
  v_code text := coalesce(nullif(btrim(coalesce(e->>'supplier_code', '')), ''),
                          nullif(btrim(coalesce(e->>'product_code', '')), ''));
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
  update public.products
     set unit = coalesce(unit, public.our_unit(e->>'unit')),
         list_price = coalesce(list_price, nullif(e->>'list_price', '')::numeric)
   where id = p_product_id
     and ((unit is null and public.tidy_text(e->>'unit') is not null)
          or (list_price is null and nullif(e->>'list_price', '') is not null));
  if nullif(btrim(coalesce(e->>'supplier_code', '')), '') is not null then
    perform public.learn_notation_impl(p_supplier_id, p_product_id, 'code', e->>'supplier_code', 'import', true);
  end if;
  -- The company's code for its own supplier of this product (0112).
  if public.tidy_text(e->>'upstream_code') is not null then
    insert into public.partner_vendor_codes (partner_id, code, code_key, maker_id, raw_maker, source)
    values (p_supplier_id, public.tidy_text(e->>'upstream_code'), public.normalize_product_text(e->>'upstream_code'),
            (select maker_id from public.products where id = p_product_id), v_maker, 'import')
    on conflict (partner_id, code_key) do update
       set maker_id = coalesce(partner_vendor_codes.maker_id, excluded.maker_id),
           raw_maker = coalesce(excluded.raw_maker, partner_vendor_codes.raw_maker),
           seen_count = partner_vendor_codes.seen_count + 1, last_seen_at = now();
  end if;
  return true;
end;
$$;


create or replace function public.propose_product_parts(p_partner_id bigint, e jsonb)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_name text := public.tidy_text(e->>'product_name');
  v_code text := public.tidy_text(e->>'product_code');
  v_jan text := public.normalize_jan(coalesce(e->>'raw_jan_code', e->>'jan_code'));
  v_maker_raw text := public.tidy_text(e->>'maker');
  v_maker_id bigint;
  v_maker text;
  tokens text[];
  kept text[] := '{}';
  t text;
  c text;
  m text[];
  attrs jsonb := '{}'::jsonb;
  a jsonb;
  v_attr record;
  v_base text;
  w record;
begin
  v_maker_id := public.resolve_maker(v_maker_raw, p_partner_id);
  -- No maker written, but the company's code for its supplier is one we
  -- have seen with a maker (仕入先コード 724 → 三菱鉛筆).
  if v_maker_id is null and v_maker_raw is null and public.tidy_text(e->>'upstream_code') is not null then
    select pv.maker_id, pv.raw_maker into v_maker_id, v_maker_raw
      from public.partner_vendor_codes pv
     where pv.partner_id = p_partner_id
       and pv.code_key = public.normalize_product_text(e->>'upstream_code');
  end if;
  v_maker := coalesce((select name from public.makers where id = v_maker_id), v_maker_raw);

  -- Attribute columns the reader found, in ours.
  for a in select * from jsonb_array_elements(coalesce(e->'attributes', '[]'::jsonb)) loop
    select id, key into v_attr from public.product_attributes where key = a->>'key' and status = 'active';
    continue when v_attr.id is null or public.tidy_text(a->>'value') is null;
    attrs := attrs || jsonb_build_object(v_attr.key,
      public.tidy_text(public.our_attribute_value(p_partner_id, v_attr.id, public.tidy_text(a->>'value'))));
  end loop;

  -- Size and colour written into the name.
  tokens := regexp_split_to_array(coalesce(v_name, ''), ' ');
  foreach t in array tokens loop
    continue when t = '';
    m := regexp_match(t, '^([0-9]+(?:\.[0-9]+)?)(mm|MM|Mm|cm|CM|ml|ML|mL|l|L|g|G|kg|KG)$');
    if m is not null then
      if lower(m[2]) in ('mm', 'cm') and not attrs ? 'size' then
        attrs := attrs || jsonb_build_object('size', m[1] || lower(m[2]));
        continue;
      elsif lower(m[2]) in ('ml', 'l') and not attrs ? 'capacity' then
        attrs := attrs || jsonb_build_object('capacity', m[1] || case when lower(m[2]) = 'l' then 'L' else 'mL' end);
        continue;
      elsif lower(m[2]) in ('g', 'kg') and not attrs ? 'weight' then
        attrs := attrs || jsonb_build_object('weight', m[1] || lower(m[2]));
        continue;
      end if;
    end if;
    if t ~ '^[0-9]+\.[0-9]+$' and not attrs ? 'size' then
      attrs := attrs || jsonb_build_object('size', t);
      continue;
    end if;
    c := public.colour_word(p_partner_id, t);
    if c is not null and not attrs ? 'color' then
      attrs := attrs || jsonb_build_object('color', c);
      continue;
    end if;
    kept := kept || t;
  end loop;
  -- A colour glued to the end of the last word (…A4ﾗｲﾄﾌﾞﾙ).
  if not attrs ? 'color' and array_length(kept, 1) > 0 then
    t := kept[array_length(kept, 1)];
    for w in
      select public.tidy_text(v.raw_value) as raw, v.value
        from public.attribute_value_aliases v
       where v.attribute_id = (select id from public.product_attributes where key = 'color')
         and (v.partner_id = p_partner_id or v.partner_id is null)
         and length(public.tidy_text(v.raw_value)) >= 2
       order by length(v.raw_value) desc
    loop
      -- A Latin word (RED, BK) only when it does not continue another word.
      if length(t) > length(w.raw) and right(upper(t), length(w.raw)) = upper(w.raw)
         and (w.raw !~ '^[A-Za-z]+$' or substr(t, length(t) - length(w.raw), 1) !~ '[A-Za-z]') then
        kept[array_length(kept, 1)] := left(t, length(t) - length(w.raw));
        attrs := attrs || jsonb_build_object('color', w.value);
        exit;
      end if;
    end loop;
  end if;
  v_base := public.tidy_text(array_to_string(kept, ' '));

  return jsonb_build_object(
    'jan_code', v_jan,
    'maker', v_maker,
    'maker_id', v_maker_id,
    'code', v_code,
    'base_name', coalesce(v_base, v_code),
    'base_from_code', v_base is null,
    'unit', public.our_unit(e->>'unit'),
    'list_price', nullif(e->>'list_price', '')::numeric,
    'attributes', attrs,
    'name', public.render_product_name(
       coalesce((select template from public.product_name_formats where id = public.default_name_format_id()), '{base}'),
       v_maker, coalesce(v_base, v_code), v_code, v_jan, public.our_unit(e->>'unit'), attrs));
end;
$$;


revoke all on function public.document_field_labels() from public, anon;
revoke all on function public.list_document_fields() from public, anon;
revoke all on function public.save_document_field(text, jsonb, text) from public, anon;
revoke all on function public.set_column_alias(bigint, text, text, text) from public, anon;
revoke all on function public.list_partner_code_formats() from public, anon;
revoke all on function public.save_partner_code_format(text, text, int, bigint) from public, anon;
revoke all on function public.set_partner_codes(bigint, text, text) from public, anon;
revoke all on function public.issue_missing_partner_codes() from public, anon;
revoke all on function public.list_partner_vendor_codes(bigint) from public, anon;
revoke all on function public.list_trading_partners(text, text, text) from public, anon;
revoke all on function public.learn_supplier_profile_impl(bigint, bigint, jsonb) from public, anon, authenticated;
revoke all on function public.propose_product_parts(bigint, jsonb) from public, anon;
grant execute on function public.document_field_labels() to authenticated, service_role;
grant execute on function public.list_document_fields() to authenticated, service_role;
grant execute on function public.save_document_field(text, jsonb, text) to authenticated, service_role;
grant execute on function public.set_column_alias(bigint, text, text, text) to authenticated, service_role;
grant execute on function public.list_partner_code_formats() to authenticated, service_role;
grant execute on function public.save_partner_code_format(text, text, int, bigint) to authenticated, service_role;
grant execute on function public.set_partner_codes(bigint, text, text) to authenticated, service_role;
grant execute on function public.issue_missing_partner_codes() to authenticated, service_role;
grant execute on function public.list_partner_vendor_codes(bigint) to authenticated, service_role;
grant execute on function public.list_trading_partners(text, text, text) to authenticated, service_role;
grant execute on function public.propose_product_parts(bigint, jsonb) to authenticated, service_role;
