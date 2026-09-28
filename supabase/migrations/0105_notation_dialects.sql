-- 0105 — every trading company's way of writing things is a dialect we know.
--
-- Almost everything arrives through trading companies (商社), and each writes
-- the same product its own way: a JAN with hyphens, dots, spaces or
-- underscores; the maker in katakana, kanji or English; the name shortened;
-- the 品番 (some call it 項目) with its own punctuation. Even the column
-- headings differ — 品名 / 商品名 / Product Name / ｼｮｳﾋﾝﾒｲ.
--
-- Each such way of writing is recorded once, as a dialect with its own id,
-- tied to our product (or our maker). Whatever arrives is converted to ours;
-- whatever we send out is written the one way we decide.
--
--   * `makers` — our maker master. A product must have one; `products.maker`
--     stays as its display copy and `products.maker_id` is the link.
--   * `notation_dialects` — (company, field, normalized form) → our product,
--     or our maker for the field 'maker'. Every raw spelling seen is kept in
--     `raw_values`; `seen_count` and `last_seen_at` say how live it is. A code
--     or name can be scoped to a maker, since two makers can share a 品番.
--   * `column_aliases` — how a company heads its columns → our field. Seeded
--     with the common Japanese, kana and English headings; each company's own
--     are learned as their files are read.
--   * Normalizing: NFKC, lower case, katakana folded to hiragana, spaces,
--     dots, hyphens, underscores, slashes and brackets dropped (a dot between
--     digits, as in 1.5L, is kept). A JAN keeps its digits only, and Excel's
--     trailing ".0" is dropped before that.
--   * `resolve_supplier_product` reads the dialects first (confirmed ones),
--     then our own JAN, 品番 and name, scoped by maker when the maker is known.
--   * `learn_notation` / `learn_notation_lines` record a company's writing
--     against a product once someone has confirmed it (an import reviewed, an
--     inspection line converted). A form already tied to another product is
--     reported as a conflict, never overwritten.
--   * Plan lines are booked under our JAN (the company's is kept in
--     `raw_jan_code`); outbound shipment lines are rewritten to our JAN,
--     maker, name and 品番 with the company's own kept beside them.

-- ---------------------------------------------------------------------------
-- Normalizing
-- ---------------------------------------------------------------------------

create or replace function public.normalize_product_text(p text)
returns text
language sql immutable set search_path = '' as $$
  select regexp_replace(
           regexp_replace(
             translate(lower(normalize(coalesce(p, ''), NFKC)),
               'ァアィイゥウェエォオカガキギクグケゲコゴサザシジスズセゼソゾタダチヂッツヅテデトドナニヌネノハバパヒビピフブプヘベペホボポマミムメモャヤュユョヨラリルレロヮワヰヱヲンヴヵヶ',
               'ぁあぃいぅうぇえぉおかがきぎくぐけげこごさざしじすずせぜそぞただちぢっつづてでとどなにぬねのはばぱひびぴふぶぷへべぺほぼぽまみむめもゃやゅゆょよらりるれろゎわゐゑをんゔゕゖ'),
             '[[:space:]・･\-‐‑‒–—―−_/\\,、，;:：；()\[\]{}「」【】『』〔〕<>#＃*]', '', 'g'),
           '(?<![0-9])\.|\.(?![0-9])', '', 'g');
$$;

create or replace function public.normalize_jan(p text)
returns text
language plpgsql immutable set search_path = '' as $$
declare
  v text := btrim(normalize(coalesce(p, ''), NFKC));
  d text;
  s int := 0;
  i int;
begin
  -- A JAN that went through a spreadsheet as a number comes back as 4901….0.
  if v ~ '^[0-9]{8,14}\.0+$' then
    v := split_part(v, '.', 1);
  end if;
  d := regexp_replace(v, '[^0-9]', '', 'g');
  if d = '' then
    return null;
  end if;
  if length(d) = 12 then
    return '0' || d;
  end if;
  if length(d) = 14 then
    if left(d, 1) = '0' then
      return substr(d, 2);
    end if;
    d := substr(d, 2, 12);
    for i in 1..12 loop
      s := s + substr(d, i, 1)::int * case when i % 2 = 0 then 3 else 1 end;
    end loop;
    return d || ((10 - s % 10) % 10)::text;
  end if;
  return d;
end;
$$;

-- A JAN's check digit is right (EAN-13 / EAN-8).
create or replace function public.jan_check_ok(p text)
returns boolean
language plpgsql immutable set search_path = '' as $$
declare
  d text := public.normalize_jan(p);
  s int := 0;
  n int;
  i int;
begin
  if d is null or length(d) not in (8, 13) then
    return false;
  end if;
  n := length(d);
  for i in 1..n - 1 loop
    s := s + substr(d, i, 1)::int *
         case when (n - i) % 2 = 1 then 3 else 1 end;
  end loop;
  return (10 - s % 10) % 10 = right(d, 1)::int;
end;
$$;

revoke all on function public.jan_check_ok(text) from public, anon;
grant execute on function public.jan_check_ok(text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Makers
-- ---------------------------------------------------------------------------

create table if not exists public.makers (
  id bigint generated always as identity primary key,
  name text not null,
  name_key text not null,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists makers_name_key on public.makers (name_key);
alter table public.makers enable row level security;
drop policy if exists "makers: signed-in can read" on public.makers;
create policy "makers: signed-in can read" on public.makers
  for select to authenticated using (true);

alter table public.products add column if not exists maker_id bigint
  references public.makers(id) on delete set null;
create index if not exists products_maker_id on public.products (maker_id);

-- ---------------------------------------------------------------------------
-- Dialects and column headings
-- ---------------------------------------------------------------------------

create table if not exists public.notation_dialects (
  id bigint generated always as identity primary key,
  partner_id bigint references public.delivery_suppliers(id) on delete cascade,
  field text not null check (field in ('jan', 'maker', 'name', 'code')),
  raw_value text not null,
  raw_values text[] not null default '{}',
  value_key text not null,
  product_id bigint references public.products(id) on delete cascade,
  maker_id bigint references public.makers(id) on delete cascade,
  scope_maker_id bigint references public.makers(id) on delete set null,
  confirmed boolean not null default false,
  source text not null default 'manual'
    check (source in ('manual', 'import', 'inspection', 'ai', 'seed', 'legacy')),
  seen_count integer not null default 1,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  constraint notation_dialects_target check (
    (field = 'maker' and maker_id is not null and product_id is null)
    or (field <> 'maker' and product_id is not null))
);
create unique index if not exists notation_dialects_key on public.notation_dialects
  (coalesce(partner_id, 0), field, value_key, coalesce(scope_maker_id, 0));
create index if not exists notation_dialects_product on public.notation_dialects (product_id);
alter table public.notation_dialects enable row level security;
drop policy if exists "notation_dialects: signed-in can read" on public.notation_dialects;
create policy "notation_dialects: signed-in can read" on public.notation_dialects
  for select to authenticated using (true);

create table if not exists public.column_aliases (
  id bigint generated always as identity primary key,
  partner_id bigint references public.delivery_suppliers(id) on delete cascade,
  header_raw text not null,
  header_key text not null,
  field text not null check (field in (
    'jan', 'maker', 'product_name', 'product_code', 'name_code', 'quantity',
    'case_quantity', 'cases', 'unit_price', 'amount', 'spec', 'tax_rate',
    'order_date', 'ignore')),
  source text not null default 'seed' check (source in ('seed', 'manual', 'import', 'ai')),
  seen_count integer not null default 1,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
create unique index if not exists column_aliases_key on public.column_aliases
  (coalesce(partner_id, 0), header_key);
alter table public.column_aliases enable row level security;
drop policy if exists "column_aliases: signed-in can read" on public.column_aliases;
create policy "column_aliases: signed-in can read" on public.column_aliases
  for select to authenticated using (true);

insert into public.column_aliases (partner_id, header_raw, header_key, field, source)
select null, h, public.normalize_product_text(h), f, 'seed'
  from (values
    ('JAN','jan'),('JANコード','jan'),('JANｺｰﾄﾞ','jan'),('JAN CD','jan'),('JANCD','jan'),
    ('ジャンコード','jan'),('EAN','jan'),('EANコード','jan'),('EAN13','jan'),('GTIN','jan'),
    ('バーコード','jan'),('バーコード番号','jan'),('Barcode','jan'),('Bar Code','jan'),
    ('JAN Code','jan'),('UPC','jan'),('共通商品コード','jan'),('JAN/EAN','jan'),
    ('メーカー','maker'),('メーカー名','maker'),('メーカ','maker'),('メーカ名','maker'),
    ('製造元','maker'),('製造者','maker'),('製造メーカー','maker'),('発売元','maker'),
    ('販売元','maker'),('ブランド','maker'),('ブランド名','maker'),('Brand','maker'),
    ('Maker','maker'),('Maker Name','maker'),('Manufacturer','maker'),('Mfr','maker'),
    ('品名','product_name'),('商品名','product_name'),('商品名称','product_name'),
    ('品目','product_name'),('品目名','product_name'),('名称','product_name'),
    ('商品','product_name'),('製品名','product_name'),('品物','product_name'),
    ('ひんめい','product_name'),('しょうひんめい','product_name'),
    ('Item','product_name'),('Item Name','product_name'),('Product','product_name'),
    ('Product Name','product_name'),('Description','product_name'),('Goods','product_name'),
    ('Goods Name','product_name'),('Commodity','product_name'),
    ('品番','product_code'),('型番','product_code'),('型式','product_code'),('項目','product_code'),
    ('商品番号','product_code'),('商品コード','product_code'),('品目コード','product_code'),
    ('製品番号','product_code'),('製品コード','product_code'),('メーカー品番','product_code'),
    ('品番号','product_code'),('ひんばん','product_code'),('Item No','product_code'),
    ('Item Number','product_code'),('Item Code','product_code'),('Item #','product_code'),
    ('Model','product_code'),('Model No','product_code'),('Model Number','product_code'),
    ('Part No','product_code'),('Part Number','product_code'),('SKU','product_code'),
    ('Article No','product_code'),('Product Code','product_code'),('Code','product_code'),
    ('Ref','product_code'),('Style No','product_code'),
    ('品名・品番','name_code'),('品番・品名','name_code'),('品名/型番','name_code'),
    ('商品名・型番','name_code'),('商品名/品番','name_code'),('品名(品番)','name_code'),
    ('品番/商品名','name_code'),('Description/Model','name_code'),('Item/Description','name_code'),
    ('Product/Model','name_code'),
    ('数量','quantity'),('数','quantity'),('発注数','quantity'),('発注数量','quantity'),
    ('入荷数','quantity'),('入荷数量','quantity'),('納品数','quantity'),('納品数量','quantity'),
    ('出荷数','quantity'),('出荷数量','quantity'),('個数','quantity'),('注文数','quantity'),
    ('受注数','quantity'),('バラ数','quantity'),('総数','quantity'),('すうりょう','quantity'),
    ('Qty','quantity'),('Q''ty','quantity'),('Quantity','quantity'),('Pcs','quantity'),
    ('Units','quantity'),('Order Qty','quantity'),('Total Qty','quantity'),
    ('入数','case_quantity'),('ケース入数','case_quantity'),('入り数','case_quantity'),
    ('箱入数','case_quantity'),('Case Pack','case_quantity'),('Inner Qty','case_quantity'),
    ('Units/Case','case_quantity'),('Qty/Case','case_quantity'),('Pack Size','case_quantity'),
    ('ケース数','cases'),('箱数','cases'),('梱数','cases'),('口数','cases'),('カートン数','cases'),
    ('Cases','cases'),('Cartons','cases'),('CTN','cases'),
    ('単価','unit_price'),('定価','unit_price'),('仕入単価','unit_price'),('卸単価','unit_price'),
    ('原価','unit_price'),('売価','unit_price'),('Unit Price','unit_price'),('Price','unit_price'),
    ('Unit Cost','unit_price'),('U/P','unit_price'),
    ('金額','amount'),('合計金額','amount'),('小計','amount'),('金額(税抜)','amount'),
    ('Amount','amount'),('Total','amount'),('Subtotal','amount'),('Line Total','amount'),
    ('規格','spec'),('仕様','spec'),('容量','spec'),('サイズ','spec'),('色','spec'),
    ('カラー','spec'),('入り目','spec'),('Spec','spec'),('Specification','spec'),('Size','spec'),
    ('Color','spec'),('Colour','spec'),('Capacity','spec'),
    ('税率','tax_rate'),('消費税率','tax_rate'),('Tax Rate','tax_rate'),('Tax','tax_rate'),
    ('注文日','order_date'),('発注日','order_date'),('日付','order_date'),('納品日','order_date'),
    ('出荷日','order_date'),('Order Date','order_date'),('Date','order_date'),
    ('備考','ignore'),('摘要','ignore'),('Remarks','ignore'),('Note','ignore'),('No','ignore'),
    ('No.','ignore'),('行','ignore'),('行番号','ignore')
  ) as seed(h, f)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Makers: resolving, creating, keeping products in step
-- ---------------------------------------------------------------------------

-- Our maker for a way of writing one, from this company or anyone.
create or replace function public.resolve_maker(p_raw text, p_partner_id bigint default null)
returns bigint
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select m.id from public.makers m
      where m.name_key = public.normalize_product_text(p_raw) limit 1),
    (select d.maker_id from public.notation_dialects d
      where d.field = 'maker' and d.confirmed
        and d.value_key = public.normalize_product_text(p_raw)
        and (d.partner_id = p_partner_id or d.partner_id is null)
      order by (d.partner_id is null), d.seen_count desc limit 1))
  where nullif(public.normalize_product_text(p_raw), '') is not null;
$$;

revoke all on function public.resolve_maker(text, bigint) from public, anon;
grant execute on function public.resolve_maker(text, bigint) to authenticated, service_role;

create or replace function public.ensure_maker_impl(p_name text)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
  v_key text := public.normalize_product_text(p_name);
begin
  if nullif(v_key, '') is null then
    return null;
  end if;
  v_id := public.resolve_maker(p_name);
  if v_id is null then
    insert into public.makers (name, name_key) values (btrim(p_name), v_key)
    on conflict (name_key) do update set updated_at = now()
    returning id into v_id;
  end if;
  return v_id;
end;
$$;

revoke all on function public.ensure_maker_impl(text) from public, anon, authenticated;

create or replace function public.products_sync_maker()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.maker_id is not null
     and (tg_op = 'INSERT' or new.maker_id is distinct from old.maker_id) then
    new.maker := (select name from public.makers where id = new.maker_id);
  elsif nullif(btrim(coalesce(new.maker, '')), '') is not null
     and (tg_op = 'INSERT' or new.maker is distinct from old.maker or new.maker_id is null) then
    new.maker_id := public.ensure_maker_impl(new.maker);
    new.maker := (select name from public.makers where id = new.maker_id);
  elsif nullif(btrim(coalesce(new.maker, '')), '') is null then
    new.maker := null;
    new.maker_id := null;
  end if;
  return new;
end;
$$;

revoke all on function public.products_sync_maker() from public, anon, authenticated;

drop trigger if exists products_a_sync_maker on public.products;
create trigger products_a_sync_maker
  before insert or update of maker, maker_id on public.products
  for each row execute function public.products_sync_maker();

-- Existing makers become master rows.
update public.products set maker = maker where nullif(btrim(coalesce(maker, '')), '') is not null;

create or replace function public.list_makers(p_search text default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('product.view') or public.has_permission('purchase_order.view')
          or public.has_permission('receiving.view')) then
    raise exception 'not permitted: product.view required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', m.id, 'name', m.name,
             'products', (select count(*) from public.products p where p.maker_id = m.id),
             'dialects', (select count(*) from public.notation_dialects d
                           where d.field = 'maker' and d.maker_id = m.id))
           order by m.name)
      from public.makers m
     where m.status = 'active'
       and (nullif(btrim(coalesce(p_search, '')), '') is null
            or m.name_key like '%' || public.normalize_product_text(p_search) || '%'
            or exists (select 1 from public.notation_dialects d
                        where d.field = 'maker' and d.maker_id = m.id
                          and d.value_key like '%' || public.normalize_product_text(p_search) || '%'))
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.list_makers(text) from public, anon;
grant execute on function public.list_makers(text) to authenticated, service_role;

-- A product must name its maker (0105).
drop function if exists public.create_product(text, text, text, numeric);
create or replace function public.create_product(
  p_jan_code text, p_name text, p_category text default null,
  p_price numeric default null, p_maker text default null)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
  v_company_id bigint;
  -- A JAN is kept in our one form (digits only); any other code as given.
  v_jan text := case when length(public.normalize_jan(p_jan_code)) in (8, 13)
                     then public.normalize_jan(p_jan_code)
                     else nullif(btrim(coalesce(p_jan_code, '')), '') end;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if v_jan is null then
    raise exception 'jan_code is required';
  end if;
  if p_name is null or btrim(p_name) = '' then
    raise exception 'name is required';
  end if;
  if nullif(btrim(coalesce(p_maker, '')), '') is null then
    raise exception 'maker is required';
  end if;

  select id into v_company_id from public.companies order by id limit 1;

  if exists (select 1 from public.products
              where company_id = v_company_id and jan_code = v_jan) then
    raise exception 'a product with jan_code % already exists', v_jan;
  end if;

  insert into public.products (company_id, jan_code, name, category, price, maker)
  values (v_company_id, v_jan, btrim(p_name), p_category, p_price, btrim(p_maker))
  returning id into v_id;

  perform public.log_audit('product.created', 'product', v_id::text, null,
    jsonb_build_object('jan_code', v_jan, 'name', p_name, 'maker', p_maker));

  return v_id;
end;
$$;

revoke all on function public.create_product(text, text, text, numeric, text) from public, anon;
grant execute on function public.create_product(text, text, text, numeric, text)
  to authenticated, service_role;

do $$
declare v_src text;
begin
  select pg_get_functiondef('public.set_product_identity(bigint,text,text,text)'::regprocedure)
    into v_src;
  if position('maker is required' in v_src) = 0 then
    v_src := replace(v_src,
'  if v_mode is not null and v_mode not in',
'  if v_clear_maker then
    raise exception ''maker is required'';
  end if;
  if v_mode is not null and v_mode not in');
    if position('maker is required' in v_src) = 0 then
      raise exception 'set_product_identity did not have the expected shape';
    end if;
    execute v_src;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Resolving a company's writing to our product
-- ---------------------------------------------------------------------------

create or replace function public.resolve_supplier_product(
  p_supplier_id bigint, p_jan text, p_code text default null,
  p_name text default null, p_maker text default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_jan   text := public.normalize_jan(p_jan);
  v_code  text := nullif(public.normalize_product_text(p_code), '');
  v_name  text := nullif(public.normalize_product_text(p_name), '');
  v_maker bigint := public.resolve_maker(p_maker, p_supplier_id);
  v_id    bigint;
  v_d     bigint;
  v_n     int;
begin
  -- 1. The JAN: ours or a registered barcode, then a JAN dialect.
  if v_jan is not null then
    v_id := coalesce(public.product_for_jan(p_jan), public.product_for_jan(v_jan));
    if v_id is null then
      select p.id into v_id from public.products p
       where public.normalize_jan(p.jan_code) = v_jan limit 1;
    end if;
    if v_id is not null then
      return jsonb_build_object('product_id', v_id, 'matched_by', 'jan', 'maker_id', v_maker);
    end if;
    select d.product_id, d.id into v_id, v_d from public.notation_dialects d
     where d.field = 'jan' and d.confirmed and d.value_key = v_jan
       and (d.partner_id = p_supplier_id or d.partner_id is null)
     order by (d.partner_id is null), d.seen_count desc limit 1;
    if v_id is not null then
      return jsonb_build_object('product_id', v_id, 'matched_by', 'dialect_jan',
                                'dialect_id', v_d, 'maker_id', v_maker);
    end if;
  end if;

  -- 2. A 品番: this company's dialect (within the maker when known), then ours.
  if v_code is not null then
    select d.product_id, d.id into v_id, v_d from public.notation_dialects d
     where d.field = 'code' and d.confirmed and d.value_key = v_code
       and (d.partner_id = p_supplier_id or d.partner_id is null)
       and (v_maker is null or d.scope_maker_id is null or d.scope_maker_id = v_maker)
     order by (d.partner_id is null), (d.scope_maker_id is distinct from v_maker), d.seen_count desc
     limit 1;
    if v_id is not null then
      return jsonb_build_object('product_id', v_id, 'matched_by', 'dialect_code',
                                'dialect_id', v_d, 'maker_id', v_maker);
    end if;
    select count(*), min(p.id) into v_n, v_id from public.products p
     where public.normalize_product_text(p.sku) = v_code and p.status = 'active'
       and (v_maker is null or p.maker_id is null or p.maker_id = v_maker);
    if v_n = 1 then
      return jsonb_build_object('product_id', v_id, 'matched_by', 'sku', 'maker_id', v_maker);
    end if;
  end if;

  -- 3. A name, the same way.
  if v_name is not null then
    select d.product_id, d.id into v_id, v_d from public.notation_dialects d
     where d.field = 'name' and d.confirmed and d.value_key = v_name
       and (d.partner_id = p_supplier_id or d.partner_id is null)
       and (v_maker is null or d.scope_maker_id is null or d.scope_maker_id = v_maker)
     order by (d.partner_id is null), (d.scope_maker_id is distinct from v_maker), d.seen_count desc
     limit 1;
    if v_id is not null then
      return jsonb_build_object('product_id', v_id, 'matched_by', 'dialect_name',
                                'dialect_id', v_d, 'maker_id', v_maker);
    end if;
    select count(*), min(p.id) into v_n, v_id from public.products p
     where public.normalize_product_text(p.name) = v_name and p.status = 'active'
       and (v_maker is null or p.maker_id is null or p.maker_id = v_maker);
    if v_n = 1 then
      return jsonb_build_object('product_id', v_id, 'matched_by', 'name', 'maker_id', v_maker);
    end if;
  end if;

  return jsonb_build_object('product_id', null, 'matched_by', null, 'maker_id', v_maker);
end;
$$;

-- Many lines at once, for the importer: each comes back with our product.
create or replace function public.resolve_notation_lines(p_partner_id bigint, p_lines jsonb)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  e      jsonb;
  r      jsonb;
  v_prod jsonb;
  out    jsonb := '[]'::jsonb;
begin
  if not (public.has_permission('receiving.view') or public.has_permission('product.view')
          or public.has_permission('purchase_order.view')) then
    raise exception 'not permitted: receiving.view required';
  end if;
  for e in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    r := public.resolve_supplier_product(p_partner_id, e->>'jan_code', e->>'product_code',
                                         e->>'product_name', e->>'maker');
    v_prod := (select jsonb_build_object('id', p.id, 'jan_code', p.jan_code, 'name', p.name,
                                         'sku', p.sku, 'maker', p.maker)
                 from public.products p where p.id = (r->>'product_id')::bigint);
    out := out || jsonb_build_object(
      'matched_by', r->>'matched_by',
      'dialect_id', r->'dialect_id',
      'maker_id', r->'maker_id',
      'maker_name', (select name from public.makers where id = (r->>'maker_id')::bigint),
      'jan_valid', public.jan_check_ok(e->>'jan_code'),
      'product', v_prod);
  end loop;
  return out;
end;
$$;

revoke all on function public.resolve_notation_lines(bigint, jsonb) from public, anon;
grant execute on function public.resolve_notation_lines(bigint, jsonb) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Learning a company's writing
-- ---------------------------------------------------------------------------

create or replace function public.learn_notation_impl(
  p_partner_id bigint, p_product_id bigint, p_field text, p_raw text,
  p_source text, p_confirmed boolean)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  pr      record;
  v_raw   text := nullif(btrim(coalesce(p_raw, '')), '');
  v_key   text;
  v_own   text;
  v_scope bigint;
  v_maker bigint;
  cur     record;
  v_new   bigint;
begin
  if v_raw is null or p_product_id is null then
    return null;
  end if;
  select id, jan_code, name, sku, maker, maker_id into pr
    from public.products where id = p_product_id;
  if pr.id is null then
    return null;
  end if;

  if p_field = 'jan' then
    v_key := public.normalize_jan(v_raw);
    v_own := pr.jan_code;
  elsif p_field = 'maker' then
    if pr.maker_id is null then return null; end if;
    v_key := public.normalize_product_text(v_raw);
    v_own := pr.maker;
    v_maker := pr.maker_id;
  elsif p_field = 'code' then
    v_key := public.normalize_product_text(v_raw);
    v_own := pr.sku;
    v_scope := pr.maker_id;
  elsif p_field = 'name' then
    v_key := public.normalize_product_text(v_raw);
    v_own := pr.name;
    v_scope := pr.maker_id;
  else
    raise exception 'unknown notation field %', p_field;
  end if;
  if nullif(v_key, '') is null or v_raw = coalesce(v_own, '') then
    return null;        -- written exactly as we write it: nothing to learn
  end if;

  select * into cur from public.notation_dialects d
   where coalesce(d.partner_id, 0) = coalesce(p_partner_id, 0)
     and d.field = p_field and d.value_key = v_key
     and coalesce(d.scope_maker_id, 0) = coalesce(v_scope, 0)
   for update;

  if cur.id is not null then
    if (p_field = 'maker' and cur.maker_id is distinct from v_maker)
       or (p_field <> 'maker' and cur.product_id is distinct from p_product_id) then
      if cur.confirmed then
        return jsonb_build_object('conflict', true, 'dialect_id', cur.id, 'field', p_field,
          'raw', v_raw, 'product_id', cur.product_id, 'maker_id', cur.maker_id);
      end if;
      update public.notation_dialects
         set product_id = case when p_field = 'maker' then null else p_product_id end,
             maker_id = v_maker, confirmed = p_confirmed, source = p_source
       where id = cur.id;
    end if;
    update public.notation_dialects
       set seen_count = seen_count + 1, last_seen_at = now(),
           raw_values = case when v_raw = any(raw_values) then raw_values
                             else raw_values || v_raw end,
           confirmed = confirmed or p_confirmed
     where id = cur.id;
    return jsonb_build_object('dialect_id', cur.id, 'field', p_field, 'raw', v_raw);
  end if;

  insert into public.notation_dialects
    (partner_id, field, raw_value, raw_values, value_key, product_id, maker_id,
     scope_maker_id, confirmed, source)
  values (p_partner_id, p_field, v_raw, array[v_raw], v_key,
          case when p_field = 'maker' then null else p_product_id end,
          v_maker, v_scope, p_confirmed, p_source)
  returning id into v_new;
  return jsonb_build_object('dialect_id', v_new, 'field', p_field, 'raw', v_raw, 'new', true);
end;
$$;

revoke all on function public.learn_notation_impl(bigint, bigint, text, text, text, boolean)
  from public, anon, authenticated;

-- Lines of {product_id, jan_code, maker, product_name, product_code} as a
-- company wrote them, now tied to our products.
create or replace function public.learn_notation_lines(
  p_partner_id bigint, p_lines jsonb, p_source text default 'import',
  p_confirmed boolean default true)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  e         jsonb;
  r         jsonb;
  v_pid     bigint;
  v_learned int := 0;
  v_new     int := 0;
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
  end loop;
  return jsonb_build_object('learned', v_learned, 'new', v_new, 'conflicts', v_conf);
end;
$$;

revoke all on function public.learn_notation_lines(bigint, jsonb, text, boolean) from public, anon;
grant execute on function public.learn_notation_lines(bigint, jsonb, text, boolean)
  to authenticated, service_role;

-- What 0087's supplier names say, and whatever sets them later, feeds the
-- dictionary too.
create or replace function public.supplier_product_name_to_dialects()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform public.learn_notation_impl(new.supplier_id, new.product_id, 'code', new.supplier_code, 'manual', true);
  perform public.learn_notation_impl(new.supplier_id, new.product_id, 'name', new.supplier_name, 'manual', true);
  perform public.learn_notation_impl(new.supplier_id, new.product_id, 'jan', new.supplier_jan_code, 'manual', true);
  perform public.learn_notation_impl(new.supplier_id, new.product_id, 'maker', new.supplier_maker, 'manual', true);
  return null;
end;
$$;

revoke all on function public.supplier_product_name_to_dialects() from public, anon, authenticated;

drop trigger if exists supplier_product_names_to_dialects on public.supplier_product_names;
create trigger supplier_product_names_to_dialects
  after insert or update on public.supplier_product_names
  for each row execute function public.supplier_product_name_to_dialects();

do $$
declare n record;
begin
  for n in select * from public.supplier_product_names loop
    perform public.learn_notation_impl(n.supplier_id, n.product_id, 'code', n.supplier_code, 'legacy', true);
    perform public.learn_notation_impl(n.supplier_id, n.product_id, 'name', n.supplier_name, 'legacy', true);
    perform public.learn_notation_impl(n.supplier_id, n.product_id, 'jan', n.supplier_jan_code, 'legacy', true);
    perform public.learn_notation_impl(n.supplier_id, n.product_id, 'maker', n.supplier_maker, 'legacy', true);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- The dictionary, for people
-- ---------------------------------------------------------------------------

create or replace function public.list_notation_dialects(
  p_partner_id bigint default null, p_field text default null,
  p_search text default null, p_unconfirmed_only boolean default false,
  p_limit integer default 300)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_q text := nullif(public.normalize_product_text(p_search), '');
begin
  if not (public.has_permission('product.view') or public.has_permission('purchase_order.view')) then
    raise exception 'not permitted: product.view required';
  end if;
  return coalesce((
    select jsonb_agg(row order by (row->>'last_seen_at') desc)
      from (
        select jsonb_build_object(
          'id', d.id, 'code', 'D-' || lpad(d.id::text, 6, '0'),
          'partner_id', d.partner_id, 'partner_name', s.name,
          'field', d.field, 'raw_value', d.raw_value, 'raw_values', to_jsonb(d.raw_values),
          'product_id', d.product_id, 'product_jan', p.jan_code, 'product_name', p.name,
          'product_sku', p.sku, 'product_maker', p.maker,
          'maker_id', d.maker_id, 'maker_name', m.name,
          'scope_maker_name', sm.name,
          'confirmed', d.confirmed, 'source', d.source, 'seen_count', d.seen_count,
          'created_at', d.created_at, 'last_seen_at', d.last_seen_at) as row
          from public.notation_dialects d
          left join public.delivery_suppliers s on s.id = d.partner_id
          left join public.products p on p.id = d.product_id
          left join public.makers m on m.id = d.maker_id
          left join public.makers sm on sm.id = d.scope_maker_id
         where (p_partner_id is null or d.partner_id = p_partner_id)
           and (p_field is null or d.field = p_field)
           and (not coalesce(p_unconfirmed_only, false) or not d.confirmed)
           and (v_q is null or d.value_key like '%' || v_q || '%'
                or public.normalize_product_text(p.name) like '%' || v_q || '%'
                or public.normalize_product_text(m.name) like '%' || v_q || '%'
                or p.jan_code like '%' || v_q || '%')
         order by d.last_seen_at desc
         limit greatest(1, least(coalesce(p_limit, 300), 1000))
      ) q), '[]'::jsonb);
end;
$$;

revoke all on function public.list_notation_dialects(bigint, text, text, boolean, integer) from public, anon;
grant execute on function public.list_notation_dialects(bigint, text, text, boolean, integer)
  to authenticated, service_role;

create or replace function public.add_notation_dialect(
  p_partner_id bigint, p_field text, p_raw text,
  p_product_id bigint default null, p_maker_id bigint default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r jsonb; v_key text; v_id bigint;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if p_field = 'maker' then
    if p_maker_id is null then raise exception 'a maker dialect needs our maker'; end if;
    v_key := public.normalize_product_text(p_raw);
    if nullif(v_key, '') is null then raise exception 'the way it is written is required'; end if;
    insert into public.notation_dialects
      (partner_id, field, raw_value, raw_values, value_key, maker_id, confirmed, source)
    values (p_partner_id, 'maker', btrim(p_raw), array[btrim(p_raw)], v_key, p_maker_id, true, 'manual')
    on conflict (coalesce(partner_id, 0), field, value_key, coalesce(scope_maker_id, 0))
      do update set maker_id = excluded.maker_id, confirmed = true, last_seen_at = now()
    returning id into v_id;
    return jsonb_build_object('dialect_id', v_id);
  end if;
  r := public.learn_notation_impl(p_partner_id, p_product_id, p_field, p_raw, 'manual', true);
  if r is null then
    raise exception 'that is written exactly as our own, so there is nothing to record';
  end if;
  if (r->>'conflict')::boolean is true then
    raise exception 'this way of writing is already tied to another product (dialect %)', r->>'dialect_id';
  end if;
  return r;
end;
$$;

revoke all on function public.add_notation_dialect(bigint, text, text, bigint, bigint) from public, anon;
grant execute on function public.add_notation_dialect(bigint, text, text, bigint, bigint)
  to authenticated, service_role;

create or replace function public.set_notation_dialect(
  p_id bigint, p_product_id bigint default null, p_maker_id bigint default null,
  p_confirmed boolean default true)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare d record;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  select * into d from public.notation_dialects where id = p_id for update;
  if d.id is null then
    raise exception 'dialect % not found', p_id;
  end if;
  update public.notation_dialects
     set product_id = case when d.field = 'maker' then null else coalesce(p_product_id, product_id) end,
         maker_id = case when d.field = 'maker' then coalesce(p_maker_id, maker_id) else maker_id end,
         confirmed = coalesce(p_confirmed, confirmed),
         source = case when p_product_id is not null or p_maker_id is not null then 'manual' else source end
   where id = p_id;
  perform public.log_audit('notation.dialect_set', 'notation_dialect', p_id::text, null,
    jsonb_build_object('product_id', p_product_id, 'maker_id', p_maker_id, 'confirmed', p_confirmed));
  return true;
end;
$$;

revoke all on function public.set_notation_dialect(bigint, bigint, bigint, boolean) from public, anon;
grant execute on function public.set_notation_dialect(bigint, bigint, bigint, boolean)
  to authenticated, service_role;

create or replace function public.remove_notation_dialect(p_id bigint)
returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  delete from public.notation_dialects where id = p_id;
  perform public.log_audit('notation.dialect_removed', 'notation_dialect', p_id::text, null, '{}'::jsonb);
  return found;
end;
$$;

revoke all on function public.remove_notation_dialect(bigint) from public, anon;
grant execute on function public.remove_notation_dialect(bigint) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Column headings
-- ---------------------------------------------------------------------------

-- How this company heads its columns, then how anyone does.
create or replace function public.column_alias_map(p_partner_id bigint default null)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'header_key', a.header_key, 'field', a.field,
           'partner', a.partner_id is not null, 'source', a.source)
         order by (a.partner_id is null)), '[]'::jsonb)
    from public.column_aliases a
   where a.partner_id is null or a.partner_id = p_partner_id;
$$;

revoke all on function public.column_alias_map(bigint) from public, anon;
grant execute on function public.column_alias_map(bigint) to authenticated, service_role;

-- [{header, field}] as confirmed for this company's file.
create or replace function public.learn_column_aliases(
  p_partner_id bigint, p_map jsonb, p_source text default 'import')
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  e jsonb;
  v_key text;
  v_n int := 0;
  v_global text;
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
    -- A heading everyone uses the same way needs no entry of this company's own.
    v_global := null;
    select field into v_global from public.column_aliases
     where partner_id is null and header_key = v_key;
    continue when v_global = e->>'field';
    insert into public.column_aliases (partner_id, header_raw, header_key, field, source)
    values (p_partner_id, btrim(e->>'header'), v_key, e->>'field',
            case when p_source in ('manual', 'import', 'ai') then p_source else 'import' end)
    on conflict (coalesce(partner_id, 0), header_key) do update
       set field = excluded.field, seen_count = column_aliases.seen_count + 1,
           last_seen_at = now();
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

revoke all on function public.learn_column_aliases(bigint, jsonb, text) from public, anon;
grant execute on function public.learn_column_aliases(bigint, jsonb, text) to authenticated, service_role;

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
             'header', a.header_raw, 'field', a.field, 'source', a.source,
             'seen_count', a.seen_count, 'last_seen_at', a.last_seen_at)
           order by (a.partner_id is null), a.field, a.header_raw)
      from public.column_aliases a
      left join public.delivery_suppliers s on s.id = a.partner_id
     where p_partner_id is null or a.partner_id = p_partner_id or a.partner_id is null
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.list_column_aliases(bigint) from public, anon;
grant execute on function public.list_column_aliases(bigint) to authenticated, service_role;

create or replace function public.set_column_alias(
  p_partner_id bigint, p_header text, p_field text)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare v_id bigint; v_key text := public.normalize_product_text(p_header);
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if nullif(v_key, '') is null then
    raise exception 'a column heading is required';
  end if;
  insert into public.column_aliases (partner_id, header_raw, header_key, field, source)
  values (p_partner_id, btrim(p_header), v_key, p_field, 'manual')
  on conflict (coalesce(partner_id, 0), header_key) do update
     set field = excluded.field, source = 'manual', last_seen_at = now()
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.set_column_alias(bigint, text, text) from public, anon;
grant execute on function public.set_column_alias(bigint, text, text) to authenticated, service_role;

create or replace function public.remove_column_alias(p_id bigint)
returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  delete from public.column_aliases where id = p_id and source <> 'seed';
  return found;
end;
$$;

revoke all on function public.remove_column_alias(bigint) from public, anon;
grant execute on function public.remove_column_alias(bigint) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- In: plan lines under our JAN.  Out: shipment lines in our words.
-- ---------------------------------------------------------------------------

alter table public.delivery_plan_lines add column if not exists raw_jan_code text;
alter table public.delivery_plan_lines add column if not exists raw_name_code text;
alter table public.delivery_plan_lines add column if not exists review_flags jsonb;

create or replace function public.delivery_plan_line_resolve_supplier_name()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_supplier bigint;
  r jsonb;
  v_own text;
begin
  if new.product_id is null then
    select supplier_id into v_supplier from public.delivery_plans where id = new.delivery_plan_id;
    r := public.resolve_supplier_product(v_supplier, new.jan_code, new.product_code,
                                         new.product_name, new.maker);
    new.product_id := (r->>'product_id')::bigint;
  end if;
  if new.product_id is not null then
    select jan_code into v_own from public.products where id = new.product_id;
    if nullif(btrim(coalesce(v_own, '')), '') is not null
       and v_own is distinct from new.jan_code then
      new.raw_jan_code := coalesce(new.raw_jan_code, nullif(new.jan_code, ''));
      new.jan_code := v_own;
    end if;
  end if;
  return new;
end;
$$;

-- The inspection line keeps the company's JAN, not the one we booked it under.
do $$
declare v_src text;
begin
  select pg_get_functiondef('public.inspection_item_convert()'::regprocedure) into v_src;
  if position('raw_jan_code' in v_src) = 0 then
    v_src := replace(v_src,
      'select coalesce(rl.product_id, pl.product_id) as product_id, pl.jan_code,',
      'select coalesce(rl.product_id, pl.product_id) as product_id,
         coalesce(pl.raw_jan_code, pl.jan_code) as jan_code,');
    if position('raw_jan_code' in v_src) = 0 then
      raise exception 'inspection_item_convert did not have the expected shape';
    end if;
    execute v_src;
  end if;
end $$;

alter table public.shipment_lines add column if not exists maker text;
alter table public.shipment_lines add column if not exists source_jan_code text;
alter table public.shipment_lines add column if not exists source_product_code text;
alter table public.shipment_lines add column if not exists source_maker text;

create or replace function public.shipment_line_canonical()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_partner bigint;
  r jsonb;
  p record;
begin
  if new.product_id is null then
    select party_id into v_partner from public.shipment_plans where id = new.shipment_plan_id;
    r := public.resolve_supplier_product(v_partner, new.jan_code, new.product_code,
                                         new.product_name, new.maker);
    new.product_id := (r->>'product_id')::bigint;
  elsif tg_op = 'UPDATE' and new.product_id is not distinct from old.product_id then
    return new;
  end if;
  if new.product_id is null then
    return new;
  end if;
  select jan_code, name, sku, maker into p from public.products where id = new.product_id;
  -- What went out is written our way; how the order wrote it stays beside it.
  if nullif(btrim(coalesce(p.jan_code, '')), '') is not null and p.jan_code is distinct from new.jan_code then
    new.source_jan_code := coalesce(new.source_jan_code, nullif(new.jan_code, ''));
    new.jan_code := p.jan_code;
  end if;
  if nullif(btrim(coalesce(p.name, '')), '') is not null and p.name is distinct from new.product_name then
    new.source_product_name := coalesce(new.source_product_name, nullif(new.product_name, ''));
    new.product_name := p.name;
  end if;
  if p.sku is distinct from new.product_code then
    new.source_product_code := coalesce(new.source_product_code, nullif(new.product_code, ''));
    new.product_code := p.sku;
  end if;
  if p.maker is distinct from new.maker then
    new.source_maker := coalesce(new.source_maker, nullif(new.maker, ''));
    new.maker := p.maker;
  end if;
  return new;
end;
$$;

revoke all on function public.shipment_line_canonical() from public, anon, authenticated;

drop trigger if exists shipment_lines_master_name on public.shipment_lines;
drop trigger if exists shipment_lines_a_canonical on public.shipment_lines;
create trigger shipment_lines_a_canonical
  before insert or update of product_id on public.shipment_lines
  for each row execute function public.shipment_line_canonical();
