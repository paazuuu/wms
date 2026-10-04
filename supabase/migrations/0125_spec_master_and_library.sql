-- 0125 — 商品マスタ as the product's spec, 商品ライブラリー as its own record.
--
-- 商品マスタ is what the product is, as a buyer would read it: maker, name,
-- 品番, JAN, attributes, weight and now its size. Who supplies it and on
-- what terms is the library's business (0124), so the master's screens no
-- longer show suppliers.
--
--   * `products.width_mm / depth_mm / height_mm` (幅・奥行・高さ, mm) and
--     `size_note` for a size that is not three figures (A4, φ10×140mm),
--     with where it came from (`size_source`: manual / web / measured /
--     file). `set_product_size` sets or clears them.
--   * The library keeps its own copy of everything it shows: weight, size
--     and the storage paths of its pictures (`catalog_items.image_paths`).
--     Taking a product out of the master never reaches the library: the
--     item stays with its terms, names and pictures; only its link to the
--     product is cleared. The stock the library shows is the product's,
--     and the stock tables refuse to lose a product that has any (their
--     foreign keys restrict), so stock cannot vanish with a master row.
--   * When a product with the JAN of an unlinked item appears in the
--     master again, the item is linked to it again (trigger).
--   * `catalog_from_master(ids)` brings master products that are not in the
--     library yet into it — with their attributes, weight, size, pictures
--     and each supplier's name, code and terms as they stand — and
--     `catalog_master_candidates` lists the ones that can be brought in.
--   * A read file's weight (attribute `weight`) and outer size (new
--     attribute `dimensions`, 寸法) go to the item's weight and size.
--   * `catalog_update_item` corrects an item by hand.

-- ------------------------------------------------------------ size

alter table public.products add column if not exists width_mm numeric(10, 1);
alter table public.products add column if not exists depth_mm numeric(10, 1);
alter table public.products add column if not exists height_mm numeric(10, 1);
alter table public.products add column if not exists size_note text;
alter table public.products add column if not exists size_source text;
alter table public.products add column if not exists size_updated_at timestamptz;
alter table public.products add column if not exists size_updated_by uuid;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'products_size_check') then
    alter table public.products add constraint products_size_check
      check (coalesce(width_mm, 0) >= 0 and coalesce(depth_mm, 0) >= 0 and coalesce(height_mm, 0) >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'products_size_source_check') then
    alter table public.products add constraint products_size_source_check
      check (size_source is null or size_source in ('manual', 'web', 'measured', 'file'));
  end if;
end $$;

alter table public.catalog_items add column if not exists weight_g numeric(12, 3);
alter table public.catalog_items add column if not exists width_mm numeric(10, 1);
alter table public.catalog_items add column if not exists depth_mm numeric(10, 1);
alter table public.catalog_items add column if not exists height_mm numeric(10, 1);
alter table public.catalog_items add column if not exists size_note text;
alter table public.catalog_items add column if not exists image_paths text[] not null default '{}';
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'catalog_items_spec_check') then
    alter table public.catalog_items add constraint catalog_items_spec_check
      check (coalesce(weight_g, 0) >= 0 and coalesce(width_mm, 0) >= 0
             and coalesce(depth_mm, 0) >= 0 and coalesce(height_mm, 0) >= 0);
  end if;
end $$;

-- The outer size as an attribute a file can carry (the reader learns our
-- attributes from this table). サイズ stays for 0.5mm, A4 and the like.
insert into public.product_attributes (key, name, unit, sort_order)
values ('dimensions', '寸法', 'mm', 65)
on conflict (key) do nothing;

-- "W100×D50×H20mm", "100x50x20", "10×5×2cm" → {100, 50, 20} in mm; null
-- unless there are exactly three figures.
create or replace function public.parse_dimensions_mm(p text)
returns numeric[]
language plpgsql immutable set search_path = '' as $$
declare
  s text := lower(normalize(coalesce(p, ''), NFKC));
  f numeric := 1;
  n numeric[];
begin
  if s ~ 'cm' then
    f := 10;
  elsif s !~ 'mm' and s ~ '[0-9]\s*m($|[^a-z])' then
    f := 1000;
  end if;
  select array_agg(t.m[1]::numeric * f order by t.ord)
    into n
    from regexp_matches(s, '([0-9]+(?:\.[0-9]+)?)', 'g') with ordinality as t(m, ord);
  return case when array_length(n, 1) = 3 then n end;
end;
$$;

-- "12g", "1.2kg", "12" → grams.
create or replace function public.parse_weight_g(p text)
returns numeric
language plpgsql immutable set search_path = '' as $$
declare
  s text := lower(normalize(coalesce(p, ''), NFKC));
  v numeric := substring(s from '([0-9]+(?:\.[0-9]+)?)')::numeric;
begin
  if v is null then return null; end if;
  if s ~ 'kg' then return v * 1000; end if;
  if s ~ 'mg' then return v / 1000; end if;
  return v;
end;
$$;

-- A read line's weight and size: its own fields, else its weight and
-- dimensions attributes.
create or replace function public.catalog_line_spec(e jsonb)
returns jsonb
language plpgsql immutable set search_path = '' as $$
declare
  v_attrs jsonb := case when jsonb_typeof(e->'attributes') = 'array' then e->'attributes' else '[]'::jsonb end;
  v_wt text := (select a->>'value' from jsonb_array_elements(v_attrs) a where a->>'key' = 'weight' limit 1);
  v_dim text := (select a->>'value' from jsonb_array_elements(v_attrs) a where a->>'key' = 'dimensions' limit 1);
  v_d numeric[] := public.parse_dimensions_mm(v_dim);
begin
  return jsonb_strip_nulls(jsonb_build_object(
    'weight_g', coalesce(nullif(e->>'weight_g', '')::numeric, public.parse_weight_g(v_wt)),
    'width_mm', coalesce(nullif(e->>'width_mm', '')::numeric, v_d[1]),
    'depth_mm', coalesce(nullif(e->>'depth_mm', '')::numeric, v_d[2]),
    'height_mm', coalesce(nullif(e->>'height_mm', '')::numeric, v_d[3]),
    'size_note', coalesce(public.tidy_text(e->>'size_note'), case when v_d is null then public.tidy_text(v_dim) end)));
end;
$$;

-- The attributes left once weight and size have their own columns.
create or replace function public.catalog_line_attributes(e jsonb)
returns jsonb
language sql immutable set search_path = '' as $$
  select coalesce(jsonb_agg(a), '[]'::jsonb)
    from jsonb_array_elements(case when jsonb_typeof(e->'attributes') = 'array' then e->'attributes' else '[]'::jsonb end) a
   where coalesce(a->>'key', '') not in ('weight', 'dimensions');
$$;

-- A product's size, or clearing it (all null).
create or replace function public.set_product_size(
  p_product_id bigint, p_width_mm numeric, p_depth_mm numeric, p_height_mm numeric,
  p_note text default null, p_source text default 'manual')
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_note text := public.tidy_text(p_note);
  v_empty boolean := p_width_mm is null and p_depth_mm is null and p_height_mm is null and v_note is null;
  v_source text := case when v_empty then null else coalesce(nullif(btrim(p_source), ''), 'manual') end;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if coalesce(p_width_mm, 0) < 0 or coalesce(p_depth_mm, 0) < 0 or coalesce(p_height_mm, 0) < 0 then
    raise exception 'size cannot be negative';
  end if;
  if v_source is not null and v_source not in ('manual', 'web', 'measured', 'file') then
    raise exception 'unknown size source %', p_source;
  end if;
  update public.products
     set width_mm = p_width_mm, depth_mm = p_depth_mm, height_mm = p_height_mm,
         size_note = v_note, size_source = v_source,
         size_updated_at = now(), size_updated_by = auth.uid(), updated_at = now()
   where id = p_product_id;
  if not found then
    raise exception 'product % not found', p_product_id;
  end if;
  perform public.log_audit('product.size_set', 'product', p_product_id::text, null,
    jsonb_build_object('width_mm', p_width_mm, 'depth_mm', p_depth_mm, 'height_mm', p_height_mm,
                       'note', v_note, 'source', v_source));
  return jsonb_build_object('product_id', p_product_id, 'width_mm', p_width_mm, 'depth_mm', p_depth_mm,
                            'height_mm', p_height_mm, 'size_note', v_note, 'size_source', v_source);
end;
$$;

-- ------------------------------------------------------------ the master list

create or replace function public.list_products(p_search text default null, p_status text default 'active')
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('product.view') then
    raise exception 'not permitted: product.view required';
  end if;

  return coalesce(
    (select jsonb_agg(jsonb_build_object(
        'id', p.id, 'jan_code', p.jan_code, 'name', p.name, 'name_en', p.name_en,
        'names', public.product_names_of(p.id),
        'category', p.category, 'price', p.price, 'status', p.status,
        'lifecycle', p.lifecycle, 'lifecycle_reason', p.lifecycle_reason,
        'lifecycle_changed_at', p.lifecycle_changed_at,
        'stock', public.product_stock_json(p.id),
        'suppliers', public.product_suppliers_json(p.id),
        'base_name', p.base_name, 'unit', p.unit, 'list_price', p.list_price,
        'image_count', (select count(*) from public.product_images i
                         where i.product_id = p.id and i.withdrawn_at is null),
        'attributes', coalesce((
          select jsonb_agg(jsonb_build_object('key', a.key, 'name', a.name, 'value', v.value) order by a.id)
            from public.product_attribute_values v
            join public.product_attributes a on a.id = v.attribute_id
           where v.product_id = p.id), '[]'::jsonb),
        'sku', p.sku, 'tracking_mode', p.tracking_mode,
        'picking_rule', p.picking_rule,
        'requires_inspection', p.requires_inspection,
        'maker', p.maker,
        'unit_weight_g', p.unit_weight_g, 'weight_source', p.weight_source,
        'weight_source_url', p.weight_source_url, 'weight_note', p.weight_note,
        'width_mm', p.width_mm, 'depth_mm', p.depth_mm, 'height_mm', p.height_mm,
        'size_note', p.size_note, 'size_source', p.size_source,
        'created_at', p.created_at, 'updated_at', p.updated_at,
        'base_uom', (select jsonb_build_object('id', u.id, 'code', u.code, 'name', u.name)
                       from public.uoms u where u.id = p.base_uom_id),
        'uoms', coalesce((
          select jsonb_agg(jsonb_build_object(
                   'code', u.code, 'name', u.name,
                   'conversion_factor', pu.conversion_factor,
                   'is_base', pu.uom_id = p.base_uom_id,
                   'package_weight_g', pu.package_weight_g,
                   'gross_weight_g', pu.gross_weight_g,
                   'pack_weight_g', public.pack_weight_g(p.id, pu.uom_id))
                 order by pu.conversion_factor)
            from public.product_uoms pu
            join public.uoms u on u.id = pu.uom_id
           where pu.product_id = p.id), '[]'::jsonb),
        'barcodes', coalesce((
          select jsonb_agg(jsonb_build_object(
                   'id', b.id, 'barcode', b.barcode,
                   'barcode_type', b.barcode_type,
                   'is_primary', b.is_primary,
                   'quantity_per_scan', b.quantity_per_scan,
                   'uom', (select u.code from public.uoms u where u.id = b.uom_id))
                 order by b.is_primary desc, b.barcode)
            from public.product_barcodes b where b.product_id = p.id
        ), '[]'::jsonb),
        'supplier_names', coalesce((
          select jsonb_agg(jsonb_build_object(
                   'supplier_id', n.supplier_id, 'supplier_display_name', s.name,
                   'supplier_code', n.supplier_code, 'supplier_name', n.supplier_name)
                 order by s.name)
            from public.supplier_product_names n
            join public.delivery_suppliers s on s.id = n.supplier_id
           where n.product_id = p.id), '[]'::jsonb)
      ) order by p.name)
      from public.products p
     where (p_status is null or p.status = p_status)
       and (p_search is null or p_search = '' or
            p.name ilike '%' || p_search || '%' or
            p.name_en ilike '%' || p_search || '%' or
            exists (select 1 from public.product_names pn
                     where pn.product_id = p.id and pn.name ilike '%' || p_search || '%') or
            p.jan_code ilike '%' || p_search || '%' or
            p.sku ilike '%' || p_search || '%' or
            p.maker ilike '%' || p_search || '%' or
            exists (select 1 from public.product_barcodes b
                     where b.product_id = p.id
                       and b.barcode ilike '%' ||
                           coalesce(public.normalize_barcode(p_search), p_search) || '%') or
            exists (select 1 from public.supplier_product_names n
                     where n.product_id = p.id
                       and (n.supplier_name ilike '%' || p_search || '%'
                            or n.supplier_code ilike '%' || p_search || '%')))),
    '[]'::jsonb);
end;
$$;


-- ------------------------------------------------------------ the library

-- An unlinked item finds its product again by JAN when one appears.
create or replace function public.catalog_relink_product()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.jan_code is not null then
    update public.catalog_items
       set product_id = new.id, updated_at = now()
     where product_id is null and jan_code = new.jan_code;
  end if;
  return new;
end;
$$;
create or replace trigger products_z_catalog_relink
  after insert or update of jan_code on public.products
  for each row execute function public.catalog_relink_product();

-- The library, as in 0124, with each item's weight, size and face: its own
-- first picture, else its product's.
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
          'weight_g', c.weight_g, 'width_mm', c.width_mm, 'depth_mm', c.depth_mm, 'height_mm', c.height_mm,
          'size_note', c.size_note, 'image_paths', to_jsonb(c.image_paths),
          'face_path', coalesce(c.image_paths[1], (
            select i.storage_path from public.product_images i
             where i.product_id = public.catalog_product_id(c) and i.withdrawn_at is null
             order by i.position, i.id limit 1)),
          'image_count', greatest(coalesce(array_length(c.image_paths, 1), 0), (
            select count(*) from public.product_images i
             where i.product_id = public.catalog_product_id(c) and i.withdrawn_at is null)),
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

-- A read file into the library, as in 0124, now with weight and size.
create or replace function public.catalog_import(
  p_lines jsonb, p_partner_id bigint default null, p_branch text default null,
  p_valid_from date default null, p_source_file text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  e jsonb;
  v_spec jsonb;
  v_attrs jsonb;
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
    v_spec := public.catalog_line_spec(e);
    v_attrs := public.catalog_line_attributes(e);
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
        (jan_code, maker, name, base_name, item_code, spec, unit, list_price, attributes,
         weight_g, width_mm, depth_mm, height_mm, size_note, source, source_file, created_by)
      values (v_jan, v_maker, v_name, public.tidy_text(e->>'base_name'), v_code, public.tidy_text(e->>'spec'),
              public.tidy_text(e->>'unit'), nullif(e->>'list_price', '')::numeric, v_attrs,
              (v_spec->>'weight_g')::numeric, (v_spec->>'width_mm')::numeric, (v_spec->>'depth_mm')::numeric,
              (v_spec->>'height_mm')::numeric, v_spec->>'size_note', 'file', p_source_file, auth.uid())
      returning id into v_id;
      v_created := v_created + 1;
    else
      update public.catalog_items
         set maker = coalesce(v_maker, maker),
             item_code = coalesce(v_code, item_code),
             spec = coalesce(public.tidy_text(e->>'spec'), spec),
             unit = coalesce(public.tidy_text(e->>'unit'), unit),
             list_price = coalesce(nullif(e->>'list_price', '')::numeric, list_price),
             attributes = case when jsonb_array_length(v_attrs) > 0 then v_attrs else attributes end,
             weight_g = coalesce((v_spec->>'weight_g')::numeric, weight_g),
             width_mm = coalesce((v_spec->>'width_mm')::numeric, width_mm),
             depth_mm = coalesce((v_spec->>'depth_mm')::numeric, depth_mm),
             height_mm = coalesce((v_spec->>'height_mm')::numeric, height_mm),
             size_note = coalesce(v_spec->>'size_note', size_note),
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

-- Correcting an item by hand: only the keys given change (null clears).
create or replace function public.catalog_update_item(p_id bigint, p jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_jan text;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if p ? 'jan_code' then
    v_jan := public.normalize_jan(p->>'jan_code');
    if length(coalesce(v_jan, '')) not in (8, 13) then v_jan := null; end if;
  end if;
  if p ? 'name' and public.tidy_text(p->>'name') is null then
    raise exception 'name is required';
  end if;
  update public.catalog_items set
    name = case when p ? 'name' then public.tidy_text(p->>'name') else name end,
    maker = case when p ? 'maker' then public.tidy_text(p->>'maker') else maker end,
    base_name = case when p ? 'base_name' then public.tidy_text(p->>'base_name') else base_name end,
    item_code = case when p ? 'item_code' then public.tidy_text(p->>'item_code') else item_code end,
    jan_code = case when p ? 'jan_code' then v_jan else jan_code end,
    unit = case when p ? 'unit' then public.tidy_text(p->>'unit') else unit end,
    category = case when p ? 'category' then public.tidy_text(p->>'category') else category end,
    list_price = case when p ? 'list_price' then nullif(p->>'list_price', '')::numeric else list_price end,
    weight_g = case when p ? 'weight_g' then nullif(p->>'weight_g', '')::numeric else weight_g end,
    width_mm = case when p ? 'width_mm' then nullif(p->>'width_mm', '')::numeric else width_mm end,
    depth_mm = case when p ? 'depth_mm' then nullif(p->>'depth_mm', '')::numeric else depth_mm end,
    height_mm = case when p ? 'height_mm' then nullif(p->>'height_mm', '')::numeric else height_mm end,
    size_note = case when p ? 'size_note' then public.tidy_text(p->>'size_note') else size_note end,
    note = case when p ? 'note' then public.tidy_text(p->>'note') else note end,
    updated_at = now()
  where id = p_id;
  if not found then
    raise exception 'catalog item % not found', p_id;
  end if;
  perform public.log_audit('catalog.item_updated', 'catalog', p_id::text, null, p);
  return jsonb_build_object('id', p_id);
end;
$$;

-- Master products not in the library yet: no item links to them and none
-- carries their JAN.
create or replace function public.catalog_master_candidates(p_search text default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_q text := nullif(btrim(coalesce(p_search, '')), '');
begin
  if not public.has_permission('product.view') then
    raise exception 'not permitted: product.view required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', p.id, 'name', p.name, 'maker', p.maker, 'sku', p.sku, 'jan_code', p.jan_code,
             'lifecycle', p.lifecycle,
             'supplier_count', (select count(distinct sp.partner_id) from public.supply_chain_supplier_products sp
                                 where sp.product_id = p.id and sp.active))
           order by p.name, p.id)
      from public.products p
     where not exists (select 1 from public.catalog_items c
                        where c.product_id = p.id or (p.jan_code is not null and c.jan_code = p.jan_code))
       and (v_q is null or p.name ilike '%' || v_q || '%' or p.maker ilike '%' || v_q || '%'
            or p.sku ilike '%' || v_q || '%' or p.jan_code like '%' || v_q || '%')), '[]'::jsonb);
end;
$$;

-- Master products into the library (all candidates when [p_ids] is null):
-- an item each, a copy of the product's spec and pictures, and each
-- supplier's name, code and terms for it as they stand today. Products
-- already in the library are skipped, never overwritten.
create or replace function public.catalog_from_master(p_ids bigint[] default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  p public.products;
  v_id bigint;
  v_created int := 0;
  v_terms int := 0;
  v_skipped int := 0;
  s record;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  for p in select * from public.products where p_ids is null or id = any(p_ids) order by id loop
    if exists (select 1 from public.catalog_items c
                where c.product_id = p.id or (p.jan_code is not null and c.jan_code = p.jan_code)) then
      v_skipped := v_skipped + 1;
      continue;
    end if;
    insert into public.catalog_items
      (jan_code, maker, name, base_name, item_code, unit, category, list_price, attributes,
       weight_g, width_mm, depth_mm, height_mm, size_note, image_paths, source, product_id, created_by)
    values (
      case when length(coalesce(p.jan_code, '')) in (8, 13) then p.jan_code end,
      p.maker, p.name, p.base_name, p.sku, p.unit, p.category, p.list_price,
      coalesce((select jsonb_agg(jsonb_build_object('key', a.key, 'name', a.name, 'value', v.value) order by a.id)
                  from public.product_attribute_values v
                  join public.product_attributes a on a.id = v.attribute_id
                 where v.product_id = p.id), '[]'::jsonb),
      p.unit_weight_g, p.width_mm, p.depth_mm, p.height_mm, p.size_note,
      coalesce((select array_agg(i.storage_path order by i.position, i.id) from public.product_images i
                 where i.product_id = p.id and i.withdrawn_at is null), '{}'),
      'master', p.id, auth.uid())
    returning id into v_id;
    v_created := v_created + 1;
    for s in
      select sp.partner_id, n.supplier_name, coalesce(sp.supplier_sku, n.supplier_code) as code,
             sp.unit_price, sp.list_price, sp.discount_rate, sp.order_lot, sp.currency,
             coalesce(sp.updated_at, now())::date as since
        from public.supply_chain_supplier_products sp
        left join public.supplier_product_names n on n.supplier_id = sp.partner_id and n.product_id = p.id
       where sp.product_id = p.id and sp.active
      union all
      select n.supplier_id, n.supplier_name, n.supplier_code, null, null, null, null, null,
             coalesce(n.updated_at, now())::date
        from public.supplier_product_names n
       where n.product_id = p.id
         and not exists (select 1 from public.supply_chain_supplier_products sp
                          where sp.product_id = p.id and sp.partner_id = n.supplier_id and sp.active)
    loop
      perform public.catalog_add_term_impl(v_id, jsonb_build_object(
        'partner_id', s.partner_id, 'their_name', s.supplier_name, 'their_code', s.code,
        'unit_price', s.unit_price, 'list_price', s.list_price, 'discount_rate', s.discount_rate,
        'case_quantity', s.order_lot, 'currency', s.currency, 'valid_from', least(s.since, current_date),
        'note', '商品マスタから取り込み'), 'manual', null);
      v_terms := v_terms + 1;
    end loop;
  end loop;
  perform public.log_audit('catalog.from_master', 'catalog', '', null,
    jsonb_build_object('created', v_created, 'terms', v_terms, 'skipped', v_skipped));
  return jsonb_build_object('created', v_created, 'terms', v_terms, 'skipped', v_skipped);
end;
$$;

-- Items into the master, as in 0124, with their weight, size and pictures.
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
  v_path text;
  v_pos int;
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
      insert into public.products
        (company_id, jan_code, name, maker, sku, base_name, unit, list_price, category,
         unit_weight_g, weight_source, weight_note, width_mm, depth_mm, height_mm, size_note, size_source)
      values (v_company, c.jan_code, c.name, c.maker, c.item_code, coalesce(c.base_name, c.name), c.unit,
              c.list_price, c.category,
              c.weight_g, case when c.weight_g is not null then 'manual' end,
              case when c.weight_g is not null then '商品ライブラリーから' end,
              c.width_mm, c.depth_mm, c.height_mm, c.size_note,
              case when coalesce(c.width_mm, c.depth_mm, c.height_mm) is not null or c.size_note is not null then 'file' end)
      returning id into v_pid;
      v_pos := 0;
      foreach v_path in array c.image_paths loop
        if not exists (select 1 from public.product_images where storage_path = v_path) then
          v_pos := v_pos + 1;
          insert into public.product_images (product_id, storage_path, position, uploaded_by)
          values (v_pid, v_path, v_pos, auth.uid());
        end if;
      end loop;
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

revoke all on function public.parse_dimensions_mm(text) from public, anon;
revoke all on function public.parse_weight_g(text) from public, anon;
revoke all on function public.catalog_line_spec(jsonb) from public, anon;
revoke all on function public.catalog_line_attributes(jsonb) from public, anon;
revoke all on function public.set_product_size(bigint, numeric, numeric, numeric, text, text) from public, anon;
revoke all on function public.catalog_relink_product() from public, anon, authenticated;
revoke all on function public.catalog_update_item(bigint, jsonb) from public, anon;
revoke all on function public.catalog_master_candidates(text) from public, anon;
revoke all on function public.catalog_from_master(bigint[]) from public, anon;
grant execute on function public.parse_dimensions_mm(text) to authenticated, service_role;
grant execute on function public.parse_weight_g(text) to authenticated, service_role;
grant execute on function public.catalog_line_spec(jsonb) to authenticated, service_role;
grant execute on function public.catalog_line_attributes(jsonb) to authenticated, service_role;
grant execute on function public.set_product_size(bigint, numeric, numeric, numeric, text, text) to authenticated, service_role;
grant execute on function public.catalog_update_item(bigint, jsonb) to authenticated, service_role;
grant execute on function public.catalog_master_candidates(text) to authenticated, service_role;
grant execute on function public.catalog_from_master(bigint[]) to authenticated, service_role;
