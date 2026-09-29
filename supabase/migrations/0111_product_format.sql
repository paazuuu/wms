-- 0111 — our own product format: register products the company's way,
-- change the way later in one place.
--
-- Suppliers describe the same goods in their own shorthand — 半角カナ
-- ("ﾕﾆﾎﾞｰﾙ ｴｱ 0.5MM ｱｶ"), the colour glued to the name, the unit as ﾎﾝ / ｻﾂ /
-- P, sometimes no name at all (a PDF with only メーカー, 項目 and JAN). Our
-- own product master is kept in one format of our choosing instead, and a
-- product's name is BUILT from its parts, not typed:
--
--   * A product keeps its parts: `base_name` (the name without size or
--     colour), maker, 品番 (`sku`), JAN, `unit`, `list_price` (定価), and
--     its attributes (0110).
--   * `product_name_formats` — templates such as
--     "{base} {attr:size} {attr:color}" or "{maker} {base} ...". A product's
--     name is rendered from its format whenever a part changes. Change the
--     template, rename a maker, or change what a colour is called
--     (`rename_attribute_value`) and every affected product's name follows.
--     A product can still be named by hand (`name_manual`).
--   * Text is tidied the same way everywhere: NFKC (半角カナ → 全角,
--     全角英数 → 半角), one space between words.
--   * `unit_aliases` (ﾎﾝ → 本, ｻﾂ → 冊, P → パック, …) and colour words
--     (ｱｶ → 赤, BK → 黒, ｸﾞﾚｰ → グレー, …) are seeded so a supplier's line
--     proposes a tidy product.
--   * `propose_products_from_lines` turns a read document's lines that have
--     no product yet into proposals in our format (nothing written);
--     `register_products` creates what a person confirmed and learns the
--     supplier's writing against it at the same time.
--
-- Also from the same real samples: plan and shipment line prices keep
-- their decimals (¥41.6), and the reader's new fields — 定価, 掛率, 単位 and
-- the company's own 商品コード — have headings of their own.

-- ------------------------------------------------------------ prices with decimals

alter table public.delivery_plan_lines alter column unit_price type numeric(12, 2);
alter table public.shipment_lines alter column unit_price type numeric(12, 2);

-- ------------------------------------------------------------ headings

alter table public.column_aliases drop constraint if exists column_aliases_field_check;
alter table public.column_aliases add constraint column_aliases_field_check check (field in (
  'jan', 'maker', 'product_name', 'product_code', 'name_code', 'quantity',
  'case_quantity', 'cases', 'unit_price', 'amount', 'spec', 'tax_rate',
  'order_date', 'ignore', 'attr', 'list_price', 'discount_rate', 'unit', 'supplier_code'));

-- 定価 is the list price, not the price paid.
update public.column_aliases set field = 'list_price'
 where partner_id is null and header_key = public.normalize_product_text('定価');

insert into public.column_aliases (partner_id, header_raw, header_key, field, source)
select null, h, public.normalize_product_text(h), f, 'seed'
  from (values
    ('定価', 'list_price'), ('上代', 'list_price'), ('希望小売価格', 'list_price'),
    ('メーカー希望小売価格', 'list_price'), ('小売価格', 'list_price'), ('List Price', 'list_price'),
    ('Retail Price', 'list_price'), ('MSRP', 'list_price'),
    ('掛率', 'discount_rate'), ('掛け率', 'discount_rate'), ('掛', 'discount_rate'), ('仕切率', 'discount_rate'),
    ('単位', 'unit'), ('Unit', 'unit'), ('UOM', 'unit'), ('販売単位', 'unit'),
    ('見積単価', 'unit_price'), ('納品単価', 'unit_price'), ('仕切単価', 'unit_price'), ('仕切', 'unit_price'),
    ('社内コード', 'supplier_code'), ('自社コード', 'supplier_code'), ('貴社コード', 'supplier_code')
  ) s(h, f)
on conflict (coalesce(partner_id, 0), header_key) do nothing;

-- ------------------------------------------------------------ tidy text

create or replace function public.tidy_text(p text)
returns text
language sql immutable set search_path = '' as $$
  select nullif(btrim(regexp_replace(normalize(coalesce(p, ''), NFKC), '\s+', ' ', 'g')), '');
$$;

-- ------------------------------------------------------------ product parts

alter table public.products add column if not exists base_name text;
alter table public.products add column if not exists unit text;
alter table public.products add column if not exists list_price numeric(12, 2);
alter table public.products add column if not exists name_format_id bigint;
alter table public.products add column if not exists name_manual boolean not null default false;

create table if not exists public.product_name_formats (
  id bigint generated always as identity primary key,
  name text not null unique check (btrim(name) <> ''),
  template text not null check (position('{base}' in template) > 0),
  is_default boolean not null default false,
  status text not null default 'active' check (status in ('active', 'inactive')),
  updated_at timestamptz not null default now(),
  updated_by uuid
);
create unique index if not exists product_name_formats_one_default
  on public.product_name_formats (is_default) where is_default;
alter table public.product_name_formats enable row level security;
drop policy if exists "product_name_formats: signed-in can read" on public.product_name_formats;
create policy "product_name_formats: signed-in can read" on public.product_name_formats
  for select to authenticated using (true);

insert into public.product_name_formats (name, template, is_default) values
  ('標準', '{base} {attr:size} {attr:color}', true),
  ('メーカー名つき', '{maker} {base} {attr:size} {attr:color}', false),
  ('品番つき', '{base} {attr:size} {attr:color} ({code})', false)
on conflict (name) do nothing;

alter table public.products drop constraint if exists products_name_format_fk;
alter table public.products add constraint products_name_format_fk
  foreign key (name_format_id) references public.product_name_formats(id) on delete set null;

create table if not exists public.unit_aliases (
  raw_key text primary key,
  raw text not null,
  unit text not null
);
alter table public.unit_aliases enable row level security;
drop policy if exists "unit_aliases: signed-in can read" on public.unit_aliases;
create policy "unit_aliases: signed-in can read" on public.unit_aliases for select to authenticated using (true);

insert into public.unit_aliases (raw_key, raw, unit)
select public.normalize_product_text(r), r, u
  from (values
    ('ﾎﾝ', '本'), ('ホン', '本'), ('本', '本'), ('ﾎﾟﾝ', '本'),
    ('ｻﾂ', '冊'), ('サツ', '冊'), ('冊', '冊'),
    ('ｺ', '個'), ('コ', '個'), ('個', '個'), ('PCS', '個'), ('PC', '個'), ('EA', '個'),
    ('P', 'パック'), ('PK', 'パック'), ('ﾊﾟｯｸ', 'パック'), ('パック', 'パック'), ('PACK', 'パック'),
    ('ｾｯﾄ', 'セット'), ('セット', 'セット'), ('SET', 'セット'), ('組', 'セット'),
    ('ﾏｲ', '枚'), ('枚', '枚'), ('ﾊｺ', '箱'), ('箱', '箱'), ('BOX', '箱'), ('BX', '箱'),
    ('ﾀﾞｰｽ', 'ダース'), ('DZ', 'ダース'), ('ｹｰｽ', 'ケース'), ('CS', 'ケース'),
    ('ｶﾝ', '缶'), ('缶', '缶'), ('ﾏｷ', '巻'), ('巻', '巻'), ('ﾀﾊﾞ', '束'), ('束', '束')
  ) s(r, u)
on conflict (raw_key) do nothing;

create or replace function public.our_unit(p_raw text)
returns text
language sql stable security definer set search_path = '' as $$
  select coalesce((select unit from public.unit_aliases where raw_key = public.normalize_product_text(p_raw)),
                  public.tidy_text(p_raw));
$$;

-- Colour words anyone might write, as ours.
insert into public.attribute_value_aliases (partner_id, attribute_id, raw_value, value_key, value, source)
select null, (select id from public.product_attributes where key = 'color'), r, public.normalize_product_text(r), v, 'seed'
  from (values
    ('クロ', '黒'), ('ブラック', '黒'), ('BLACK', '黒'), ('BK', '黒'),
    ('アカ', '赤'), ('レッド', '赤'), ('RED', '赤'),
    ('アオ', '青'), ('ブルー', '青'), ('BLUE', '青'),
    ('ミドリ', '緑'), ('グリーン', '緑'), ('GREEN', '緑'),
    ('キイロ', '黄'), ('イエロー', '黄'), ('YELLOW', '黄'),
    ('シロ', '白'), ('ホワイト', '白'), ('WHITE', '白'),
    ('グレー', 'グレー'), ('グレイ', 'グレー'), ('GRAY', 'グレー'), ('GREY', 'グレー'), ('ハイイロ', 'グレー'),
    ('ピンク', 'ピンク'), ('PINK', 'ピンク'), ('モモ', 'ピンク'),
    ('オレンジ', 'オレンジ'), ('ORANGE', 'オレンジ'), ('ダイダイ', 'オレンジ'),
    ('ムラサキ', '紫'), ('パープル', '紫'), ('バイオレット', '紫'), ('PURPLE', '紫'), ('VIOLET', '紫'),
    ('ミズイロ', '水色'), ('ライトブルー', '水色'), ('ライトブル', '水色'),
    ('チャ', '茶'), ('チャイロ', '茶'), ('ブラウン', '茶'), ('BROWN', '茶'),
    ('キン', '金'), ('ゴールド', '金'), ('GOLD', '金'),
    ('ギン', '銀'), ('シルバー', '銀'), ('SILVER', '銀'), ('SV', '銀')
  ) s(r, v)
on conflict (coalesce(partner_id, 0), attribute_id, value_key) do nothing;

-- ------------------------------------------------------------ rendering a name

-- A template filled in: {base} {maker} {code} {jan} {unit} and {attr:<key>}
-- (from [p_attrs], {key: value}). A placeholder with nothing to put in it
-- disappears, and so does a bracket left empty.
create or replace function public.render_product_name(
  p_template text, p_maker text, p_base text, p_code text, p_jan text, p_unit text, p_attrs jsonb)
returns text
language plpgsql immutable set search_path = '' as $$
declare
  v text := coalesce(p_template, '{base}');
  e record;
begin
  v := replace(v, '{base}', coalesce(p_base, ''));
  v := replace(v, '{maker}', coalesce(p_maker, ''));
  v := replace(v, '{code}', coalesce(p_code, ''));
  v := replace(v, '{jan}', coalesce(p_jan, ''));
  v := replace(v, '{unit}', coalesce(p_unit, ''));
  for e in select key, value from jsonb_each_text(coalesce(p_attrs, '{}'::jsonb)) loop
    v := replace(v, '{attr:' || e.key || '}', coalesce(e.value, ''));
  end loop;
  v := regexp_replace(v, '\{attr:[a-z0-9_]+\}', '', 'g');
  v := regexp_replace(v, '\(\s*\)|（\s*）|\[\s*\]|【\s*】', '', 'g');
  return public.tidy_text(v);
end;
$$;

create or replace function public.product_attrs_json(p_product_id bigint)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_object_agg(a.key, v.value), '{}'::jsonb)
    from public.product_attribute_values v
    join public.product_attributes a on a.id = v.attribute_id
   where v.product_id = p_product_id;
$$;

create or replace function public.default_name_format_id()
returns bigint
language sql stable security definer set search_path = '' as $$
  select id from public.product_name_formats where is_default and status = 'active' limit 1;
$$;

-- Every change to a product's parts rebuilds its name (unless it is named
-- by hand, or has no base name yet — products from before 0111 keep theirs).
create or replace function public.products_render_name()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_template text;
  v_name text;
begin
  new.base_name := public.tidy_text(new.base_name);
  new.unit := public.tidy_text(new.unit);
  -- A name set directly (the product form) is a name chosen by hand.
  if tg_op = 'UPDATE' and new.base_name is not null and not new.name_manual
     and new.name is distinct from old.name and old.name_manual = new.name_manual then
    new.name_manual := true;
  end if;
  if new.name_manual or new.base_name is null then
    return new;
  end if;
  select template into v_template from public.product_name_formats
   where id = coalesce(new.name_format_id, public.default_name_format_id());
  v_name := public.render_product_name(coalesce(v_template, '{base}'), new.maker, new.base_name, new.sku,
                                       new.jan_code, new.unit, public.product_attrs_json(new.id));
  if v_name is not null then
    new.name := v_name;
  end if;
  return new;
end;
$$;
revoke all on function public.products_render_name() from public, anon, authenticated;

drop trigger if exists products_b_render_name on public.products;
create trigger products_b_render_name
  before insert or update on public.products
  for each row execute function public.products_render_name();

create or replace function public.product_attribute_values_rerender()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.products set base_name = base_name
   where id = coalesce(new.product_id, old.product_id) and base_name is not null and not name_manual;
  return null;
end;
$$;
revoke all on function public.product_attribute_values_rerender() from public, anon, authenticated;

drop trigger if exists product_attribute_values_rerender on public.product_attribute_values;
create trigger product_attribute_values_rerender
  after insert or update or delete on public.product_attribute_values
  for each row execute function public.product_attribute_values_rerender();

-- A maker renamed: every product of it follows (its display copy, and so
-- its name).
create or replace function public.makers_rename_products()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.name is distinct from old.name then
    update public.products set maker = new.name where maker_id = new.id;
  end if;
  return null;
end;
$$;
revoke all on function public.makers_rename_products() from public, anon, authenticated;

drop trigger if exists makers_rename_products on public.makers;
create trigger makers_rename_products
  after update of name on public.makers
  for each row execute function public.makers_rename_products();

create or replace function public.rename_maker(p_id bigint, p_name text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_name text := public.tidy_text(p_name);
  v_key text := public.normalize_product_text(p_name);
  v_old text;
  n int;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if v_name is null then
    raise exception 'maker name is required';
  end if;
  if exists (select 1 from public.makers where name_key = v_key and id <> p_id) then
    raise exception 'another maker is already called %', v_name;
  end if;
  select name into v_old from public.makers where id = p_id;
  update public.makers set name = v_name, name_key = v_key, updated_at = now() where id = p_id;
  -- The old name still reads as this maker.
  if v_old is not null and public.normalize_product_text(v_old) <> v_key then
    insert into public.notation_dialects (partner_id, field, raw_value, raw_values, value_key, maker_id, confirmed, source)
    values (null, 'maker', v_old, array[v_old], public.normalize_product_text(v_old), p_id, true, 'manual')
    on conflict do nothing;
  end if;
  select count(*) into n from public.products where maker_id = p_id;
  perform public.log_audit('maker.renamed', 'maker', p_id::text, null,
    jsonb_build_object('from', v_old, 'to', v_name, 'products', n));
  return jsonb_build_object('id', p_id, 'name', v_name, 'products', n);
end;
$$;

-- ------------------------------------------------------------ formats, for people

create or replace function public.list_name_formats()
returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', f.id, 'name', f.name, 'template', f.template, 'is_default', f.is_default,
           'status', f.status,
           'products', (select count(*) from public.products p
                         where p.base_name is not null and not p.name_manual
                           and coalesce(p.name_format_id, public.default_name_format_id()) = f.id))
         order by f.is_default desc, f.id), '[]'::jsonb)
    from public.product_name_formats f;
$$;

-- What the names would become under [p_template] (nothing written): the
-- products using format [p_format_id] (all built names when null).
create or replace function public.preview_name_format(p_template text, p_format_id bigint default null, p_limit int default 20)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('product.view') or public.has_permission('product.manage')) then
    raise exception 'not permitted: product.view required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('product_id', q.id, 'current', q.name, 'next', q.next) order by q.id)
      from (
        select p.id, p.name,
               public.render_product_name(p_template, p.maker, p.base_name, p.sku, p.jan_code, p.unit,
                                          public.product_attrs_json(p.id)) as next
          from public.products p
         where p.base_name is not null and not p.name_manual
           and (p_format_id is null or coalesce(p.name_format_id, public.default_name_format_id()) = p_format_id)
         order by p.id
         limit greatest(1, least(coalesce(p_limit, 20), 200))
      ) q), '[]'::jsonb);
end;
$$;

-- {id?, name, template, is_default?, status?}. Saving rebuilds the names of
-- every product that uses the format; returns how many.
create or replace function public.save_name_format(p jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint := nullif(p->>'id', '')::bigint;
  v_default boolean := coalesce((p->>'is_default')::boolean, false);
  n int;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if position('{base}' in coalesce(p->>'template', '')) = 0 then
    raise exception 'a format needs {base}';
  end if;
  if v_default then
    update public.product_name_formats set is_default = false where is_default and id is distinct from v_id;
  end if;
  if v_id is null then
    insert into public.product_name_formats (name, template, is_default, updated_by)
    values (public.tidy_text(p->>'name'), btrim(p->>'template'), v_default, auth.uid())
    returning id into v_id;
  else
    update public.product_name_formats
       set name = coalesce(public.tidy_text(p->>'name'), name),
           template = btrim(p->>'template'),
           is_default = case when p ? 'is_default' then v_default else is_default end,
           status = coalesce(nullif(p->>'status', ''), status),
           updated_at = now(), updated_by = auth.uid()
     where id = v_id;
  end if;
  if not exists (select 1 from public.product_name_formats where is_default) then
    update public.product_name_formats set is_default = true where id = v_id;
  end if;
  update public.products set base_name = base_name
   where base_name is not null and not name_manual
     and (coalesce(name_format_id, public.default_name_format_id()) = v_id or v_default);
  get diagnostics n = row_count;
  perform public.log_audit('product.name_format_saved', 'product_name_format', v_id::text, null,
    p || jsonb_build_object('renamed', n));
  return jsonb_build_object('id', v_id, 'renamed', n, 'formats', public.list_name_formats());
end;
$$;

-- A product's parts, for its name: {base_name, unit, list_price,
-- name_format_id, name_manual, name (when manual), sku, maker}.
create or replace function public.set_product_naming(p_product_id bigint, p jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  update public.products set
    base_name = case when p ? 'base_name' then p->>'base_name' else base_name end,
    unit = case when p ? 'unit' then p->>'unit' else unit end,
    list_price = case when p ? 'list_price' then nullif(p->>'list_price', '')::numeric else list_price end,
    name_format_id = case when p ? 'name_format_id' then nullif(p->>'name_format_id', '')::bigint else name_format_id end,
    name_manual = case when p ? 'name_manual' then coalesce((p->>'name_manual')::boolean, false) else name_manual end,
    name = case when coalesce((p->>'name_manual')::boolean, name_manual) and nullif(btrim(coalesce(p->>'name', '')), '') is not null
                then public.tidy_text(p->>'name') else name end,
    sku = case when p ? 'sku' then public.tidy_text(p->>'sku') else sku end,
    maker = case when p ? 'maker' and public.tidy_text(p->>'maker') is not null then public.tidy_text(p->>'maker') else maker end,
    updated_at = now()
  where id = p_product_id
  returning id, name, base_name, unit, list_price, name_format_id, name_manual, sku, maker into r;
  if r.id is null then
    raise exception 'product % not found', p_product_id;
  end if;
  perform public.log_audit('product.naming_set', 'product', p_product_id::text, null, p);
  return to_jsonb(r);
end;
$$;

-- What a product's naming parts are now.
create or replace function public.product_naming(p_product_id bigint)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', id, 'name', name, 'base_name', base_name, 'unit', unit,
                            'list_price', list_price, 'name_format_id', name_format_id,
                            'name_manual', name_manual, 'sku', sku, 'maker', maker, 'jan_code', jan_code)
    from public.products where id = p_product_id;
$$;

-- Call a value something else everywhere: every product with it, and every
-- supplier word that meant it. The old word still reads as the new one.
create or replace function public.rename_attribute_value(p_attribute_id bigint, p_from text, p_to text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_to text := public.tidy_text(p_to);
  v_from_key text := public.normalize_product_text(p_from);
  n int;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if v_to is null or nullif(v_from_key, '') is null then
    raise exception 'both values are required';
  end if;
  update public.product_attribute_values
     set value = v_to, value_key = public.normalize_product_text(v_to), updated_at = now(), updated_by = auth.uid()
   where attribute_id = p_attribute_id and value_key = v_from_key;
  get diagnostics n = row_count;
  update public.attribute_value_aliases set value = v_to
   where attribute_id = p_attribute_id and public.normalize_product_text(value) = v_from_key;
  insert into public.attribute_value_aliases (partner_id, attribute_id, raw_value, value_key, value, source)
  values (null, p_attribute_id, public.tidy_text(p_from), v_from_key, v_to, 'manual')
  on conflict (coalesce(partner_id, 0), attribute_id, value_key) do update set value = excluded.value;
  perform public.log_audit('product.attribute_value_renamed', 'product_attribute', p_attribute_id::text, null,
    jsonb_build_object('from', p_from, 'to', v_to, 'products', n));
  return jsonb_build_object('products', n);
end;
$$;

-- ------------------------------------------------------------ proposing products

-- Our colour for a word, if it is one (a supplier's word first).
create or replace function public.colour_word(p_partner_id bigint, p_word text)
returns text
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select v.value from public.attribute_value_aliases v
      where v.attribute_id = (select id from public.product_attributes where key = 'color')
        and v.value_key = public.normalize_product_text(p_word)
        and (v.partner_id = p_partner_id or v.partner_id is null)
      order by (v.partner_id is null) limit 1),
    (select v.value from public.attribute_value_aliases v
      where v.attribute_id = (select id from public.product_attributes where key = 'color')
        and public.normalize_product_text(v.value) = public.normalize_product_text(p_word)
      limit 1))
  where nullif(public.normalize_product_text(p_word), '') is not null;
$$;

-- One supplier line → our product's parts: the tidy name without the size
-- and colour it carried, which become attributes.
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

-- The lines of a read document that have no product yet, as proposals in
-- our format. Nothing is written.
create or replace function public.propose_products_from_lines(p_partner_id bigint, p_lines jsonb)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  e jsonb;
  i int := 0;
  v_out jsonb := '[]'::jsonb;
  seen text[] := '{}';
  v_jan text;
  prop jsonb;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  for e in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    i := i + 1;
    continue when nullif(e->>'product_id', '') is not null;
    v_jan := public.normalize_jan(coalesce(e->>'raw_jan_code', e->>'jan_code'));
    continue when length(v_jan) not in (8, 13) or v_jan = any(seen);
    continue when exists (select 1 from public.products where jan_code = v_jan);
    seen := seen || v_jan;
    prop := public.propose_product_parts(p_partner_id, e);
    v_out := v_out || jsonb_build_array(prop || jsonb_build_object('row', coalesce((e->>'row')::int, i), 'source', e));
  end loop;
  return v_out;
end;
$$;

-- Creates the products a person confirmed: [{jan_code, maker, code,
-- base_name, unit, list_price, attributes: {key: value}, source: <line>}]
-- in format [p_format_id] (the default when null), and learns each
-- supplier line against its new product.
create or replace function public.register_products(p_partner_id bigint, p_items jsonb, p_format_id bigint default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  e jsonb;
  kv record;
  v_company bigint;
  v_jan text;
  v_id bigint;
  v_attr bigint;
  created jsonb := '[]'::jsonb;
  learn jsonb := '[]'::jsonb;
  src jsonb;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  select id into v_company from public.companies order by id limit 1;
  for e in select * from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) loop
    v_jan := public.normalize_jan(e->>'jan_code');
    if length(v_jan) not in (8, 13) then
      raise exception 'jan_code % is not a JAN', e->>'jan_code';
    end if;
    if exists (select 1 from public.products where jan_code = v_jan) then
      raise exception 'a product with jan_code % already exists', v_jan;
    end if;
    if public.tidy_text(e->>'maker') is null then
      raise exception 'maker is required';
    end if;
    if public.tidy_text(e->>'base_name') is null then
      raise exception 'name is required';
    end if;
    insert into public.products (company_id, jan_code, name, maker, sku, base_name, unit, list_price, name_format_id)
    values (v_company, v_jan, public.tidy_text(e->>'base_name'), public.tidy_text(e->>'maker'),
            public.tidy_text(e->>'code'), e->>'base_name', e->>'unit',
            nullif(e->>'list_price', '')::numeric, p_format_id)
    returning id into v_id;
    for kv in select key, value from jsonb_each_text(coalesce(e->'attributes', '{}'::jsonb)) loop
      select id into v_attr from public.product_attributes where key = kv.key;
      continue when v_attr is null or public.tidy_text(kv.value) is null;
      insert into public.product_attribute_values (product_id, attribute_id, value, value_key, updated_by)
      values (v_id, v_attr, public.tidy_text(kv.value), public.normalize_product_text(kv.value), auth.uid())
      on conflict (product_id, attribute_id) do update set value = excluded.value, value_key = excluded.value_key;
    end loop;
    perform public.log_audit('product.created', 'product', v_id::text, null,
      jsonb_build_object('jan_code', v_jan, 'from', 'document', 'partner_id', p_partner_id));
    src := coalesce(e->'source', '{}'::jsonb);
    if p_partner_id is not null and src <> '{}'::jsonb then
      learn := learn || jsonb_build_array(src || jsonb_build_object('product_id', v_id));
    end if;
    created := created || jsonb_build_array(jsonb_build_object(
      'row', e->'row', 'jan_code', v_jan, 'product_id', v_id,
      'name', (select name from public.products where id = v_id)));
  end loop;
  if jsonb_array_length(learn) > 0 then
    perform public.learn_notation_lines(p_partner_id, learn, 'import', true);
  end if;
  return created;
end;
$$;

-- ------------------------------------------------------------ learning, extended

-- The company's own 商品コード is its code for the item in its profile and
-- in the dictionary; 単位 and 定価 fill ours when we have none.
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
  return true;
end;
$$;
revoke all on function public.learn_supplier_profile_impl(bigint, bigint, jsonb) from public, anon, authenticated;

revoke all on function public.tidy_text(text) from public, anon;
revoke all on function public.our_unit(text) from public, anon;
revoke all on function public.render_product_name(text, text, text, text, text, text, jsonb) from public, anon;
revoke all on function public.product_attrs_json(bigint) from public, anon;
revoke all on function public.default_name_format_id() from public, anon;
revoke all on function public.rename_maker(bigint, text) from public, anon;
revoke all on function public.list_name_formats() from public, anon;
revoke all on function public.preview_name_format(text, bigint, int) from public, anon;
revoke all on function public.save_name_format(jsonb) from public, anon;
revoke all on function public.set_product_naming(bigint, jsonb) from public, anon;
revoke all on function public.product_naming(bigint) from public, anon;
revoke all on function public.rename_attribute_value(bigint, text, text) from public, anon;
revoke all on function public.colour_word(bigint, text) from public, anon;
revoke all on function public.propose_product_parts(bigint, jsonb) from public, anon;
revoke all on function public.propose_products_from_lines(bigint, jsonb) from public, anon;
revoke all on function public.register_products(bigint, jsonb, bigint) from public, anon;
grant execute on function public.tidy_text(text) to authenticated, service_role;
grant execute on function public.our_unit(text) to authenticated, service_role;
grant execute on function public.render_product_name(text, text, text, text, text, text, jsonb) to authenticated, service_role;
grant execute on function public.product_attrs_json(bigint) to authenticated, service_role;
grant execute on function public.default_name_format_id() to authenticated, service_role;
grant execute on function public.rename_maker(bigint, text) to authenticated, service_role;
grant execute on function public.list_name_formats() to authenticated, service_role;
grant execute on function public.preview_name_format(text, bigint, int) to authenticated, service_role;
grant execute on function public.save_name_format(jsonb) to authenticated, service_role;
grant execute on function public.set_product_naming(bigint, jsonb) to authenticated, service_role;
grant execute on function public.product_naming(bigint) to authenticated, service_role;
grant execute on function public.rename_attribute_value(bigint, text, text) to authenticated, service_role;
grant execute on function public.colour_word(bigint, text) to authenticated, service_role;
grant execute on function public.propose_product_parts(bigint, jsonb) to authenticated, service_role;
grant execute on function public.propose_products_from_lines(bigint, jsonb) to authenticated, service_role;
grant execute on function public.register_products(bigint, jsonb, bigint) to authenticated, service_role;
