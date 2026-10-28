-- 0156: a shipment's weight from one unit's weight × its quantity, with the
-- catalogs' and the AI's weights (0155) where a product has none.
--
-- unit_weight_of(product, jan): the weight of ONE unit as counted in a
-- quantity (one pen; for a JAN that is itself a pack, the pack), and where
-- it came from:
--   the product's own (a person's, or filled by rule from a catalog / the AI)
--   else the catalog's for the JAN, else the AI's (found on a page, sure).
-- A weight printed for several together (a box, a dozen, N本入) is never
-- taken: the catalog reader leaves it out (jan_catalog.ts SEVERAL), and the
-- AI is told to give one unit, or nothing when it cannot divide.
--
-- shipment_weight_estimate (0115) is the same but for that: each line now
-- says its unit weight, where it came from, and what it weighs (basis, as
-- printed), so 数量 × 1単位 = 行の重さ can be read off line by line.

create or replace function public.unit_weight_of(p_product_id bigint, p_jan text)
returns table (weight_g numeric, source text, basis text, note text)
language sql stable security definer set search_path = '' as $$
  select x.weight_g, x.source, x.basis, x.note
    from (
      select p.unit_weight_g as weight_g, coalesce(p.weight_source, 'manual') as source,
             null::text as basis, p.weight_note as note, 1 as rank
        from public.products p
       where p.id = p_product_id and p.unit_weight_g is not null
      union all
      select cw.weight_g, 'catalog', cw.weight_basis, cw.weight_text, 2
        from public.jan_catalog_weight(coalesce(p_jan, (select jan_code from public.products where id = p_product_id))) cw
      union all
      select aw.weight_g, 'ai', aw.weight_basis, aw.note, 3
        from public.jan_ai_weight(coalesce(p_jan, (select jan_code from public.products where id = p_product_id))) aw
    ) x
   where x.weight_g is not null
   order by x.rank
   limit 1;
$$;
revoke all on function public.unit_weight_of(bigint, text) from public, anon;

create or replace function public.shipment_weight_estimate(p_plan_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_warehouse bigint;
  v_found boolean;
  v_lines jsonb;
  v_goods numeric;
  v_missing int;
  v_cartons jsonb;
  v_planned jsonb;
  v_boxes numeric;
  v_material numeric;
  v_measured numeric;
  v_real boolean;
  v_box_count int;
  v_suggest jsonb;
begin
  select warehouse_id, true into v_warehouse, v_found from public.shipment_plans where id = p_plan_id;
  if not coalesce(v_found, false) then
    raise exception 'shipment % not found', p_plan_id;
  end if;
  if v_warehouse is not null and not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'product_id', x.product_id, 'jan_code', x.jan_code, 'product_name', x.product_name,
           'quantity', x.quantity, 'unit_weight_g', x.unit_weight_g,
           'weight_source', x.weight_source, 'weight_basis', x.weight_basis, 'weight_text', x.weight_text,
           'line_weight_g', x.line_weight_g)
           order by x.product_name), '[]'::jsonb),
         coalesce(sum(x.line_weight_g), 0),
         count(*) filter (where x.unit_weight_g is null)
    into v_lines, v_goods, v_missing
    from (select g.product_id, g.jan_code, g.product_name, g.quantity,
                 w.weight_g as unit_weight_g, w.source as weight_source, w.basis as weight_basis, w.note as weight_text,
                 w.weight_g * g.quantity as line_weight_g
            from (select sl.product_id, max(sl.jan_code) as jan_code,
                         coalesce(max(p.name), max(sl.product_name)) as product_name,
                         sum(sl.quantity)::int as quantity
                    from public.shipment_lines sl
                    left join public.products p on p.id = sl.product_id
                   where sl.shipment_plan_id = p_plan_id
                   group by sl.product_id, coalesce(sl.product_id::text, sl.jan_code)) g
            left join lateral public.unit_weight_of(g.product_id, g.jan_code) w on true) x;

  select coalesce(jsonb_agg(jsonb_build_object(
           'carton_id', c.id, 'carton_no', c.carton_no, 'carton_type_id', c.carton_type_id,
           'carton_type', c.carton_type, 'status', c.status,
           'empty_weight_g', c.empty_weight_g, 'packing_material_g', c.packing_material_g,
           'contents_weight_g', (select sum(i.quantity * w.weight_g) from public.shipment_carton_items i
                                   left join lateral public.unit_weight_of(i.product_id, i.jan_code) w on true
                                  where i.carton_id = c.id),
           'measured_weight_kg', c.weight_kg) order by c.carton_no), '[]'::jsonb),
         count(*) > 0,
         coalesce(sum(coalesce(c.empty_weight_g, 0)), 0),
         coalesce(sum(coalesce(c.packing_material_g, 0)), 0),
         sum(c.weight_kg) * 1000,
         count(*)
    into v_cartons, v_real, v_boxes, v_material, v_measured, v_box_count
    from public.shipment_cartons c
   where c.shipment_plan_id = p_plan_id and c.status <> 'CANCELLED';

  select coalesce(jsonb_agg(jsonb_build_object(
           'carton_type_id', t.id, 'carton_type', t.name, 'quantity', pc.quantity,
           'empty_weight_g', coalesce(pc.empty_weight_g, t.empty_weight_g),
           'packing_material_g', coalesce(pc.packing_material_g, t.packing_material_g)) order by t.sort_order), '[]'::jsonb)
    into v_planned
    from public.shipment_planned_cartons pc
    join public.carton_types t on t.id = pc.carton_type_id
   where pc.shipment_plan_id = p_plan_id;

  if not v_real then
    select coalesce(sum(pc.quantity * coalesce(pc.empty_weight_g, t.empty_weight_g)), 0),
           coalesce(sum(pc.quantity * coalesce(pc.packing_material_g, t.packing_material_g)), 0),
           coalesce(sum(pc.quantity), 0)
      into v_boxes, v_material, v_box_count
      from public.shipment_planned_cartons pc
      join public.carton_types t on t.id = pc.carton_type_id
     where pc.shipment_plan_id = p_plan_id;
    v_measured := null;
  end if;

  -- How many of each box the goods would need by weight alone.
  select coalesce(jsonb_agg(jsonb_build_object(
           'carton_type_id', t.id, 'carton_type', t.name,
           'quantity', greatest(1, ceil(v_goods / (t.max_load_kg * 1000 - t.empty_weight_g - t.packing_material_g))))
           order by t.sort_order), '[]'::jsonb)
    into v_suggest
    from public.carton_types t
   where t.status = 'active' and t.max_load_kg is not null and v_goods > 0
     and t.max_load_kg * 1000 > t.empty_weight_g + t.packing_material_g;

  return jsonb_build_object(
    'shipment_plan_id', p_plan_id,
    'lines', v_lines,
    'goods_weight_g', v_goods,
    'missing_weights', v_missing,
    'cartons_from', case when v_real then 'cartons' else 'planned' end,
    'cartons', v_cartons,
    'planned', v_planned,
    'carton_count', v_box_count,
    'boxes_weight_g', v_boxes,
    'packing_material_g', v_material,
    'total_weight_g', v_goods + v_boxes + v_material,
    'measured_weight_g', v_measured,
    'suggested', v_suggest);
end;
$$;
