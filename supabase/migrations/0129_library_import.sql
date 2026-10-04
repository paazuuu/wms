-- 0129 — 商品マスタ is called 商品ライブラリー; products come in from a file
-- of our own, or from 価格台帳.
--
-- The screens call the product table (`products`) 商品ライブラリー from now
-- on: the products we stock, receive and ship. 価格台帳 (0128) keeps what
-- suppliers quoted, which may never be bought, and nothing moves from there
-- until someone takes it in. The table keeps its name: `products` already
-- says what it is, and every stock, order and shipment table points at it.
--
--   * `products_import(lines, file)`: a file of our own (Excel, PDF, photo,
--     read by import-plan) straight into the library, line by line: the
--     product with the line's JAN is updated with what the line gives, else
--     one is made. A line needs a JAN (8 or 13 digits), a maker and a name;
--     the rest are skipped and returned with why. Attributes the file gives
--     (色, サイズ …) are set on the product. 価格台帳 is not touched.
--   * `price_book_to_products` now also copies the item's attributes.
--   * Comments on the tables say which is which.

comment on table public.products is
  '商品ライブラリー: the products we stock, receive and ship. Stock, orders, receipts and shipments point here.';
comment on table public.price_book_items is
  '価格台帳: products suppliers quoted, which may never be bought. Taken into products only when chosen.';
comment on table public.price_book_terms is
  '価格台帳: each supplier''s name, code and terms for an item, by branch and period.';

-- Attributes as files and the price book carry them ([{key, name, value}],
-- key = ours) onto a product. Internal: callers check permissions.
create or replace function public.product_put_attributes(p_product_id bigint, p_attrs jsonb)
returns int
language plpgsql security definer set search_path = '' as $$
declare
  a jsonb;
  v_attr bigint;
  v text;
  n int := 0;
begin
  for a in select * from jsonb_array_elements(case when jsonb_typeof(p_attrs) = 'array' then p_attrs else '[]'::jsonb end) loop
    v := public.tidy_text(a->>'value');
    select id into v_attr from public.product_attributes where key = a->>'key' and status = 'active';
    continue when v is null or v_attr is null or a->>'key' in ('weight', 'dimensions');
    insert into public.product_attribute_values (product_id, attribute_id, value, value_key, updated_by)
    values (p_product_id, v_attr, v, public.normalize_product_text(v), auth.uid())
    on conflict (product_id, attribute_id) do update
       set value = excluded.value, value_key = excluded.value_key, updated_at = now(), updated_by = excluded.updated_by;
    n := n + 1;
  end loop;
  return n;
end;
$$;
revoke all on function public.product_put_attributes(bigint, jsonb) from public, anon, authenticated;

-- A file of our own into the library. Lines as import-plan reads them:
-- [{jan_code | raw_jan_code, maker, product_name, base_name, product_code,
--   unit, list_price, category, weight_g, width_mm, depth_mm, height_mm,
--   size_note, attributes:[{key,name,value}]}]
create or replace function public.products_import(p_lines jsonb, p_source_file text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  e jsonb;
  v_row int := 0;
  v_jan text;
  v_maker text;
  v_code text;
  v_name text;
  v_spec jsonb;
  v_pid bigint;
  v_company bigint;
  v_created int := 0;
  v_updated int := 0;
  v_inactive int := 0;
  v_skipped jsonb := '[]'::jsonb;
  v_ids bigint[] := '{}';
  v_lifecycle text;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  select id into v_company from public.companies order by id limit 1;
  for e in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_row := v_row + 1;
    v_jan := public.normalize_jan(coalesce(nullif(e->>'raw_jan_code', ''), e->>'jan_code'));
    if length(coalesce(v_jan, '')) not in (8, 13) then v_jan := null; end if;
    v_maker := public.tidy_text(e->>'maker');
    v_code := public.tidy_text(e->>'product_code');
    v_name := coalesce(public.tidy_text(e->>'product_name'), public.tidy_text(e->>'base_name'), v_code);
    if v_jan is null or v_maker is null or v_name is null then
      v_skipped := v_skipped || jsonb_build_object('row', v_row, 'name', v_name,
        'reason', case when v_jan is null then 'jan' when v_maker is null then 'maker' else 'name' end);
      continue;
    end if;
    v_spec := public.price_book_line_spec(e);
    select id, lifecycle into v_pid, v_lifecycle from public.products where jan_code = v_jan limit 1;
    if v_pid is null then
      insert into public.products
        (company_id, jan_code, name, maker, sku, base_name, unit, list_price, category,
         unit_weight_g, weight_source, weight_note, width_mm, depth_mm, height_mm, size_note, size_source)
      values (v_company, v_jan, v_name, v_maker, v_code,
              coalesce(public.tidy_text(e->>'base_name'), v_name), public.tidy_text(e->>'unit'),
              nullif(e->>'list_price', '')::numeric, public.tidy_text(e->>'category'),
              (v_spec->>'weight_g')::numeric, case when v_spec ? 'weight_g' then 'manual' end,
              case when v_spec ? 'weight_g' then 'ファイルから' end,
              (v_spec->>'width_mm')::numeric, (v_spec->>'depth_mm')::numeric, (v_spec->>'height_mm')::numeric,
              v_spec->>'size_note',
              case when v_spec ?| array['width_mm', 'depth_mm', 'height_mm', 'size_note'] then 'file' end)
      returning id into v_pid;
      v_created := v_created + 1;
      perform public.log_audit('product.created', 'product', v_pid::text, null,
        jsonb_build_object('jan_code', v_jan, 'from', 'file', 'file', p_source_file));
    else
      update public.products
         set maker = v_maker,
             name = v_name,
             sku = coalesce(v_code, sku),
             base_name = coalesce(public.tidy_text(e->>'base_name'), base_name),
             unit = coalesce(public.tidy_text(e->>'unit'), unit),
             list_price = coalesce(nullif(e->>'list_price', '')::numeric, list_price),
             category = coalesce(public.tidy_text(e->>'category'), category),
             unit_weight_g = coalesce((v_spec->>'weight_g')::numeric, unit_weight_g),
             weight_source = case when v_spec ? 'weight_g' then 'manual' else weight_source end,
             width_mm = coalesce((v_spec->>'width_mm')::numeric, width_mm),
             depth_mm = coalesce((v_spec->>'depth_mm')::numeric, depth_mm),
             height_mm = coalesce((v_spec->>'height_mm')::numeric, height_mm),
             size_note = coalesce(v_spec->>'size_note', size_note),
             size_source = case when v_spec ?| array['width_mm', 'depth_mm', 'height_mm', 'size_note'] then 'file' else size_source end,
             updated_at = now()
       where id = v_pid;
      v_updated := v_updated + 1;
      if v_lifecycle <> 'active' then v_inactive := v_inactive + 1; end if;
    end if;
    perform public.product_put_attributes(v_pid, e->'attributes');
    v_ids := v_ids || v_pid;
  end loop;
  perform public.log_audit('product.imported', 'product', coalesce(p_source_file, ''), null,
    jsonb_build_object('created', v_created, 'updated', v_updated, 'skipped', jsonb_array_length(v_skipped)));
  return jsonb_build_object('created', v_created, 'updated', v_updated, 'inactive', v_inactive,
                            'skipped', v_skipped, 'ids', to_jsonb(v_ids));
end;
$$;
revoke all on function public.products_import(jsonb, text) from public, anon;
grant execute on function public.products_import(jsonb, text) to authenticated, service_role;

-- Items into the library, as in 0128, with their attributes.
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
      perform public.product_put_attributes(v_pid, c.attributes);
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
