-- 0127 — a file into 商品マスタ in one go.
--
-- `catalog_import` (0124/0125) now also returns the library items each line
-- became or updated (`ids`), so the app can take them into the master
-- (`catalog_to_products`) right after reading a file — what 商品マスタ's
-- ファイルから登録 does. The file always goes into 商品ライブラリー first,
-- so each supplier's names and prices are kept there as before.

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
    v_ids := v_ids || v_id;
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
  return jsonb_build_object('created', v_created, 'updated', v_updated, 'terms', v_terms, 'skipped', v_skipped,
                            'ids', to_jsonb(v_ids));
end;
$$;
