-- 0128 — 商品ライブラリー becomes 価格台帳 (price book), in the database too.
--
-- What the library holds is each supplier's name, code and terms for a
-- product, by branch and period — a price book — so it is named for that:
--
--   catalog_items            → price_book_items
--   catalog_supplier_terms   → price_book_terms (catalog_item_id → item_id)
--   catalog_* functions      → price_book_* (renamed, so nothing is left
--                              under the old names, then rewritten for the
--                              new table names)
--   trigger products_z_catalog_relink → products_z_price_book_relink
--
-- Rows, keys, policies and grants carry over with the rename. Audit events
-- from here on are price_book.*.

alter table public.catalog_items rename to price_book_items;
alter table public.catalog_supplier_terms rename to price_book_terms;
alter table public.price_book_terms rename column catalog_item_id to item_id;

alter sequence public.catalog_items_id_seq rename to price_book_items_id_seq;
alter sequence public.catalog_supplier_terms_id_seq rename to price_book_terms_id_seq;
alter index public.catalog_items_jan rename to price_book_items_jan;
alter index public.catalog_items_maker_code rename to price_book_items_maker_code;
alter index public.catalog_items_product rename to price_book_items_product;
alter index public.catalog_terms_item rename to price_book_terms_item;
alter table public.price_book_items rename constraint catalog_items_pkey to price_book_items_pkey;
alter table public.price_book_items rename constraint catalog_items_list_price_check to price_book_items_list_price_check;
alter table public.price_book_items rename constraint catalog_items_name_check to price_book_items_name_check;
alter table public.price_book_items rename constraint catalog_items_product_id_fkey to price_book_items_product_id_fkey;
alter table public.price_book_items rename constraint catalog_items_source_check to price_book_items_source_check;
alter table public.price_book_items rename constraint catalog_items_spec_check to price_book_items_spec_check;
alter table public.price_book_terms rename constraint catalog_supplier_terms_pkey to price_book_terms_pkey;
alter table public.price_book_terms rename constraint catalog_supplier_terms_case_quantity_check to price_book_terms_case_quantity_check;
alter table public.price_book_terms rename constraint catalog_supplier_terms_catalog_item_id_fkey to price_book_terms_item_id_fkey;
alter table public.price_book_terms rename constraint catalog_supplier_terms_check to price_book_terms_period_check;
alter table public.price_book_terms rename constraint catalog_supplier_terms_discount_rate_check to price_book_terms_discount_rate_check;
alter table public.price_book_terms rename constraint catalog_supplier_terms_list_price_check to price_book_terms_list_price_check;
alter table public.price_book_terms rename constraint catalog_supplier_terms_moq_check to price_book_terms_moq_check;
alter table public.price_book_terms rename constraint catalog_supplier_terms_partner_id_fkey to price_book_terms_partner_id_fkey;
alter table public.price_book_terms rename constraint catalog_supplier_terms_source_check to price_book_terms_source_check;
alter table public.price_book_terms rename constraint catalog_supplier_terms_unit_price_check to price_book_terms_unit_price_check;
alter table public.price_book_terms rename constraint catalog_supplier_terms_warehouse_id_fkey to price_book_terms_warehouse_id_fkey;

alter policy "catalog_items: signed-in can read" on public.price_book_items rename to "price_book_items: signed-in can read";
alter policy "catalog_items: managers can remove" on public.price_book_items rename to "price_book_items: managers can remove";
alter policy "catalog_supplier_terms: signed-in can read" on public.price_book_terms rename to "price_book_terms: signed-in can read";
alter trigger products_z_catalog_relink on public.products rename to products_z_price_book_relink;

alter function public.catalog_product_id(public.price_book_items) rename to price_book_product_id;
alter function public.catalog_term_json(public.price_book_terms) rename to price_book_term_json;
alter function public.catalog_line_spec(jsonb) rename to price_book_line_spec;
alter function public.catalog_line_attributes(jsonb) rename to price_book_line_attributes;
alter function public.catalog_relink_product() rename to price_book_relink_product;
alter function public.catalog_list(text) rename to price_book_list;
alter function public.catalog_term_history(bigint) rename to price_book_term_history;
alter function public.catalog_add_term_impl(bigint, jsonb, text, text) rename to price_book_add_term_impl;
alter function public.catalog_import(jsonb, bigint, text, date, text) rename to price_book_import;
alter function public.catalog_add_term(bigint, jsonb) rename to price_book_add_term;
alter function public.catalog_update_item(bigint, jsonb) rename to price_book_update_item;
alter function public.catalog_master_candidates(text) rename to price_book_master_candidates;
alter function public.catalog_from_master(bigint[]) rename to price_book_from_master;
alter function public.catalog_to_products(bigint[]) rename to price_book_to_products;

create or replace function public.price_book_product_id(p_item public.price_book_items)
returns bigint
language sql stable security definer set search_path = '' as $$
  select coalesce(p_item.product_id,
                  (select id from public.products where p_item.jan_code is not null and jan_code = p_item.jan_code limit 1));
$$;

create or replace function public.price_book_term_json(t public.price_book_terms)
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

create or replace function public.price_book_line_spec(e jsonb)
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

create or replace function public.price_book_line_attributes(e jsonb)
returns jsonb
language sql immutable set search_path = '' as $$
  select coalesce(jsonb_agg(a), '[]'::jsonb)
    from jsonb_array_elements(case when jsonb_typeof(e->'attributes') = 'array' then e->'attributes' else '[]'::jsonb end) a
   where coalesce(a->>'key', '') not in ('weight', 'dimensions');
$$;

create or replace function public.price_book_relink_product()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.jan_code is not null then
    update public.price_book_items
       set product_id = new.id, updated_at = now()
     where product_id is null and jan_code = new.jan_code;
  end if;
  return new;
end;
$$;

create or replace function public.price_book_list(p_search text default null)
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
             where i.product_id = public.price_book_product_id(c) and i.withdrawn_at is null
             order by i.position, i.id limit 1)),
          'image_count', greatest(coalesce(array_length(c.image_paths, 1), 0), (
            select count(*) from public.product_images i
             where i.product_id = public.price_book_product_id(c) and i.withdrawn_at is null)),
          'source', c.source, 'source_file', c.source_file,
          'created_at', c.created_at, 'updated_at', c.updated_at,
          'product', (select jsonb_build_object('id', p.id, 'name', p.name, 'lifecycle', p.lifecycle,
                                                'linked', c.product_id is not null)
                        from public.products p where p.id = public.price_book_product_id(c)),
          'stock', (select public.product_stock_json(public.price_book_product_id(c))
                     where public.price_book_product_id(c) is not null),
          'terms', coalesce((
            select jsonb_agg(public.price_book_term_json(t) order by t.unit_price nulls last, t.partner_id, t.branch)
              from (select distinct on (t0.partner_id, t0.branch, coalesce(t0.warehouse_id, 0)) t0.*
                      from public.price_book_terms t0
                     where t0.item_id = c.id
                       and t0.valid_from <= current_date
                       and (t0.valid_to is null or t0.valid_to >= current_date)
                     order by t0.partner_id, t0.branch, coalesce(t0.warehouse_id, 0), t0.valid_from desc, t0.id desc) t), '[]'::jsonb),
          'term_count', (select count(*) from public.price_book_terms t where t.item_id = c.id)
        ) as j
          from public.price_book_items c
         where v_q is null
            or c.name ilike '%' || v_q || '%'
            or c.maker ilike '%' || v_q || '%'
            or c.item_code ilike '%' || v_q || '%'
            or c.jan_code like '%' || v_q || '%'
            or exists (select 1 from public.price_book_terms t
                        where t.item_id = c.id
                          and (t.their_name ilike '%' || v_q || '%' or t.their_code ilike '%' || v_q || '%'))
      ) x), '[]'::jsonb);
end;
$$;

create or replace function public.price_book_term_history(p_item_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('product.view') then
    raise exception 'not permitted: product.view required';
  end if;
  return coalesce((select jsonb_agg(public.price_book_term_json(t) order by t.partner_id, t.branch, t.valid_from desc, t.id desc)
                     from public.price_book_terms t where t.item_id = p_item_id), '[]'::jsonb);
end;
$$;

create or replace function public.price_book_add_term_impl(p_item_id bigint, e jsonb, p_source text, p_file text)
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
  update public.price_book_terms
     set valid_to = v_from - 1
   where item_id = p_item_id and partner_id = v_partner and branch = v_branch
     and coalesce(warehouse_id, 0) = coalesce(v_wh, 0)
     and valid_from < v_from and (valid_to is null or valid_to >= v_from);
  insert into public.price_book_terms
    (item_id, partner_id, branch, warehouse_id, their_name, their_code, unit_price, list_price,
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

create or replace function public.price_book_import(
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
  v_ids bigint[] := '{}';
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
    v_spec := public.price_book_line_spec(e);
    v_attrs := public.price_book_line_attributes(e);
    v_id := null;
    if v_jan is not null then
      select id into v_id from public.price_book_items where jan_code = v_jan;
    elsif v_code is not null then
      select id into v_id from public.price_book_items
       where jan_code is null and lower(coalesce(maker, '')) = lower(coalesce(v_maker, '')) and lower(item_code) = lower(v_code)
       limit 1;
    end if;
    if v_id is null then
      insert into public.price_book_items
        (jan_code, maker, name, base_name, item_code, spec, unit, list_price, attributes,
         weight_g, width_mm, depth_mm, height_mm, size_note, source, source_file, created_by)
      values (v_jan, v_maker, v_name, public.tidy_text(e->>'base_name'), v_code, public.tidy_text(e->>'spec'),
              public.tidy_text(e->>'unit'), nullif(e->>'list_price', '')::numeric, v_attrs,
              (v_spec->>'weight_g')::numeric, (v_spec->>'width_mm')::numeric, (v_spec->>'depth_mm')::numeric,
              (v_spec->>'height_mm')::numeric, v_spec->>'size_note', 'file', p_source_file, auth.uid())
      returning id into v_id;
      v_created := v_created + 1;
    else
      update public.price_book_items
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
    v_ids := v_ids || v_id;
    if p_partner_id is not null
       and (nullif(e->>'unit_price', '') is not null or nullif(e->>'list_price', '') is not null
            or public.tidy_text(e->>'supplier_code') is not null) then
      perform public.price_book_add_term_impl(v_id, jsonb_build_object(
        'partner_id', p_partner_id, 'branch', p_branch, 'valid_from', p_valid_from,
        'their_name', e->>'product_name', 'their_code', coalesce(e->>'supplier_code', e->>'product_code'),
        'unit_price', e->>'unit_price', 'list_price', e->>'list_price', 'discount_rate', e->>'discount_rate',
        'case_quantity', e->>'case_quantity'), 'file', p_source_file);
      v_terms := v_terms + 1;
    end if;
  end loop;
  perform public.log_audit('price_book.imported', 'price_book', coalesce(p_source_file, ''), null,
    jsonb_build_object('created', v_created, 'updated', v_updated, 'terms', v_terms, 'partner_id', p_partner_id));
  return jsonb_build_object('created', v_created, 'updated', v_updated, 'terms', v_terms, 'skipped', v_skipped,
                            'ids', to_jsonb(v_ids));
end;
$$;

create or replace function public.price_book_add_term(p_item_id bigint, p jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if not exists (select 1 from public.price_book_items where id = p_item_id) then
    raise exception 'price book item % not found', p_item_id;
  end if;
  perform public.price_book_add_term_impl(p_item_id, p, 'manual', null);
  return public.price_book_term_history(p_item_id);
end;
$$;

create or replace function public.price_book_update_item(p_id bigint, p jsonb)
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
  update public.price_book_items set
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
    raise exception 'price book item % not found', p_id;
  end if;
  perform public.log_audit('price_book.item_updated', 'price_book', p_id::text, null, p);
  return jsonb_build_object('id', p_id);
end;
$$;

create or replace function public.price_book_master_candidates(p_search text default null)
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
     where not exists (select 1 from public.price_book_items c
                        where c.product_id = p.id or (p.jan_code is not null and c.jan_code = p.jan_code))
       and (v_q is null or p.name ilike '%' || v_q || '%' or p.maker ilike '%' || v_q || '%'
            or p.sku ilike '%' || v_q || '%' or p.jan_code like '%' || v_q || '%')), '[]'::jsonb);
end;
$$;

create or replace function public.price_book_from_master(p_ids bigint[] default null)
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
    if exists (select 1 from public.price_book_items c
                where c.product_id = p.id or (p.jan_code is not null and c.jan_code = p.jan_code)) then
      v_skipped := v_skipped + 1;
      continue;
    end if;
    insert into public.price_book_items
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
      perform public.price_book_add_term_impl(v_id, jsonb_build_object(
        'partner_id', s.partner_id, 'their_name', s.supplier_name, 'their_code', s.code,
        'unit_price', s.unit_price, 'list_price', s.list_price, 'discount_rate', s.discount_rate,
        'case_quantity', s.order_lot, 'currency', s.currency, 'valid_from', least(s.since, current_date),
        'note', '商品マスタから取り込み'), 'manual', null);
      v_terms := v_terms + 1;
    end loop;
  end loop;
  perform public.log_audit('price_book.from_master', 'price_book', '', null,
    jsonb_build_object('created', v_created, 'terms', v_terms, 'skipped', v_skipped));
  return jsonb_build_object('created', v_created, 'terms', v_terms, 'skipped', v_skipped);
end;
$$;

create or replace function public.price_book_to_products(p_ids bigint[])
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  c public.price_book_items;
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
  for c in select * from public.price_book_items where id = any(coalesce(p_ids, '{}')) loop
    v_pid := public.price_book_product_id(c);
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
              case when c.weight_g is not null then '価格台帳から' end,
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
        jsonb_build_object('jan_code', c.jan_code, 'from', 'price_book', 'price_book_item_id', c.id));
      v_created := v_created + 1;
    else
      v_linked := v_linked + 1;
    end if;
    update public.price_book_items set product_id = v_pid, updated_at = now() where id = c.id;
  end loop;
  return jsonb_build_object('created', v_created, 'linked', v_linked, 'skipped', v_skipped);
end;
$$;

revoke all on function public.price_book_product_id(public.price_book_items) from public, anon;
revoke all on function public.price_book_term_json(public.price_book_terms) from public, anon;
revoke all on function public.price_book_line_spec(jsonb) from public, anon;
revoke all on function public.price_book_line_attributes(jsonb) from public, anon;
revoke all on function public.price_book_list(text) from public, anon;
revoke all on function public.price_book_term_history(bigint) from public, anon;
revoke all on function public.price_book_add_term_impl(bigint, jsonb, text, text) from public, anon;
revoke all on function public.price_book_import(jsonb, bigint, text, date, text) from public, anon;
revoke all on function public.price_book_add_term(bigint, jsonb) from public, anon;
revoke all on function public.price_book_update_item(bigint, jsonb) from public, anon;
revoke all on function public.price_book_master_candidates(text) from public, anon;
revoke all on function public.price_book_from_master(bigint[]) from public, anon;
revoke all on function public.price_book_to_products(bigint[]) from public, anon;
grant execute on function public.price_book_product_id(public.price_book_items) to authenticated, service_role;
grant execute on function public.price_book_term_json(public.price_book_terms) to authenticated, service_role;
grant execute on function public.price_book_line_spec(jsonb) to authenticated, service_role;
grant execute on function public.price_book_line_attributes(jsonb) to authenticated, service_role;
grant execute on function public.price_book_list(text) to authenticated, service_role;
grant execute on function public.price_book_term_history(bigint) to authenticated, service_role;
grant execute on function public.price_book_import(jsonb, bigint, text, date, text) to authenticated, service_role;
grant execute on function public.price_book_add_term(bigint, jsonb) to authenticated, service_role;
grant execute on function public.price_book_update_item(bigint, jsonb) to authenticated, service_role;
grant execute on function public.price_book_master_candidates(text) to authenticated, service_role;
grant execute on function public.price_book_from_master(bigint[]) to authenticated, service_role;
grant execute on function public.price_book_to_products(bigint[]) to authenticated, service_role;
revoke all on function public.price_book_add_term_impl(bigint, jsonb, text, text) from authenticated;
revoke all on function public.price_book_relink_product() from public, anon, authenticated;
