-- 0115 — how much a shipment weighs, before anyone puts it on a scale.
--
-- What was there: a carton's measured weight (0076) and the plan's weight
-- (0039), both typed in after packing. Nothing knew what a product weighs, so
-- nothing could say beforehand what a shipment would.
--
--   * `products.unit_weight_g` — one base unit (one pen, one binder), entered
--     by hand or found on the web. Where it came from is kept beside it
--     (`weight_source`: manual / web / measured, with the page it came from),
--     so a figure from a maker's site can be told apart from one weighed
--     here, and replaced when it is.
--   * Pack sizes already exist (`product_uoms`, 0059: 1 DOZEN = 12, 1 CASE =
--     144). Each now carries the weight of its packaging (`package_weight_g`,
--     the empty inner box or case) and, when someone weighs a whole one,
--     `gross_weight_g`. A pack weighs its gross weight when known, else its
--     pieces plus its packaging.
--   * `carton_types` — the boxes we ship in: size, empty weight, the packing
--     material that usually goes in with it, and how much it takes.
--   * A carton (0076) can name its type; it then has an empty weight and
--     packing material of its own, copied from the type and changeable.
--   * Before packing, a shipment can say how many of which box it will need
--     (`shipment_planned_cartons`). `shipment_weight_estimate` adds up the
--     goods, the boxes and the packing material — from the real cartons once
--     there are any — and says which products have no weight yet.

-- ------------------------------------------------------------ product weight

alter table public.products add column if not exists unit_weight_g numeric(12, 3);
alter table public.products add column if not exists weight_source text;
alter table public.products add column if not exists weight_source_url text;
alter table public.products add column if not exists weight_note text;
alter table public.products add column if not exists weight_updated_at timestamptz;
alter table public.products add column if not exists weight_updated_by uuid;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'products_unit_weight_check') then
    alter table public.products add constraint products_unit_weight_check
      check (unit_weight_g is null or unit_weight_g >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'products_weight_source_check') then
    alter table public.products add constraint products_weight_source_check
      check (weight_source is null or weight_source in ('manual', 'web', 'measured'));
  end if;
end $$;

alter table public.product_uoms add column if not exists package_weight_g numeric(12, 3);
alter table public.product_uoms add column if not exists gross_weight_g numeric(12, 3);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'product_uoms_weights_check') then
    alter table public.product_uoms add constraint product_uoms_weights_check
      check (coalesce(package_weight_g, 0) >= 0 and coalesce(gross_weight_g, 0) >= 0);
  end if;
end $$;

-- What one of this pack weighs: weighed whole, or its pieces plus its box.
create or replace function public.pack_weight_g(p_product_id bigint, p_uom_id bigint)
returns numeric
language sql stable security definer set search_path = '' as $$
  select coalesce(pu.gross_weight_g,
                  case when p.unit_weight_g is not null
                       then p.unit_weight_g * pu.conversion_factor + coalesce(pu.package_weight_g, 0) end)
    from public.product_uoms pu
    join public.products p on p.id = pu.product_id
   where pu.product_id = p_product_id and pu.uom_id = p_uom_id;
$$;

-- One product's weight, or clearing it (null). [p_source] manual / web /
-- measured; [p_url] the page a web figure came from.
create or replace function public.set_product_weight(
  p_product_id bigint, p_unit_weight_g numeric,
  p_source text default 'manual', p_url text default null, p_note text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_old numeric;
  v_source text := case when p_unit_weight_g is null then null else coalesce(nullif(btrim(p_source), ''), 'manual') end;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if p_unit_weight_g is not null and p_unit_weight_g < 0 then
    raise exception 'weight cannot be negative';
  end if;
  if v_source is not null and v_source not in ('manual', 'web', 'measured') then
    raise exception 'unknown weight source %', p_source;
  end if;
  select unit_weight_g into v_old from public.products where id = p_product_id;
  if not found then
    raise exception 'product % not found', p_product_id;
  end if;
  update public.products
     set unit_weight_g = p_unit_weight_g,
         weight_source = v_source,
         weight_source_url = case when p_unit_weight_g is null then null else nullif(btrim(coalesce(p_url, '')), '') end,
         weight_note = case when p_unit_weight_g is null then null else nullif(btrim(coalesce(p_note, '')), '') end,
         weight_updated_at = now(),
         weight_updated_by = auth.uid(),
         updated_at = now()
   where id = p_product_id;
  perform public.log_audit('product.weight_set', 'product', p_product_id::text, null,
    jsonb_build_object('from', v_old, 'to', p_unit_weight_g, 'source', v_source, 'url', p_url));
  return jsonb_build_object('product_id', p_product_id, 'unit_weight_g', p_unit_weight_g, 'weight_source', v_source);
end;
$$;

-- A pack size with its weights: [p_uom_code] DOZEN / CASE / BOX …, how many
-- base units it holds, the empty packaging, and (optional) the whole pack
-- weighed. Creates the pack size when it is new.
create or replace function public.set_product_pack(
  p_product_id bigint, p_uom_code text, p_conversion_factor numeric,
  p_package_weight_g numeric default null, p_gross_weight_g numeric default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uom bigint;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if coalesce(p_package_weight_g, 0) < 0 or coalesce(p_gross_weight_g, 0) < 0 then
    raise exception 'weight cannot be negative';
  end if;
  perform public.set_product_uom(p_product_id, p_uom_code, p_conversion_factor);
  select id into v_uom from public.uoms where code = upper(btrim(p_uom_code));
  update public.product_uoms
     set package_weight_g = p_package_weight_g, gross_weight_g = p_gross_weight_g
   where product_id = p_product_id and uom_id = v_uom;
  return jsonb_build_object('product_id', p_product_id, 'uom', upper(btrim(p_uom_code)),
    'conversion_factor', p_conversion_factor, 'package_weight_g', p_package_weight_g,
    'gross_weight_g', p_gross_weight_g, 'pack_weight_g', public.pack_weight_g(p_product_id, v_uom));
end;
$$;

-- A pack size taken off a product (not the base unit). The same as 0059's
-- remove_product_uom; kept because it was applied with this migration.
create or replace function public.remove_product_pack(p_product_id bigint, p_uom_code text)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_uom bigint;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  select id into v_uom from public.uoms where code = upper(btrim(coalesce(p_uom_code, '')));
  if v_uom is null then
    raise exception 'unknown unit %', p_uom_code;
  end if;
  if exists (select 1 from public.products where id = p_product_id and base_uom_id = v_uom) then
    raise exception 'the base unit cannot be removed';
  end if;
  if exists (select 1 from public.product_barcodes where product_id = p_product_id and uom_id = v_uom) then
    raise exception 'a barcode still names this unit; change the barcode first';
  end if;
  delete from public.product_uoms where product_id = p_product_id and uom_id = v_uom;
  return found;
end;
$$;

-- ------------------------------------------------------------ carton types

create table if not exists public.carton_types (
  id bigint generated always as identity primary key,
  name text not null check (btrim(name) <> ''),
  length_cm numeric(8, 1) check (length_cm is null or length_cm >= 0),
  width_cm numeric(8, 1) check (width_cm is null or width_cm >= 0),
  height_cm numeric(8, 1) check (height_cm is null or height_cm >= 0),
  empty_weight_g numeric(10, 1) not null default 0 check (empty_weight_g >= 0),
  packing_material_g numeric(10, 1) not null default 0 check (packing_material_g >= 0),
  max_load_kg numeric(8, 2) check (max_load_kg is null or max_load_kg > 0),
  is_default boolean not null default false,
  status text not null default 'active' check (status in ('active', 'inactive')),
  sort_order integer not null default 0,
  updated_at timestamptz not null default now()
);
create unique index if not exists carton_types_name_key on public.carton_types (lower(btrim(name)));
create unique index if not exists carton_types_one_default on public.carton_types (is_default) where is_default;
alter table public.carton_types enable row level security;
drop policy if exists "carton_types: signed-in can read" on public.carton_types;
create policy "carton_types: signed-in can read" on public.carton_types
  for select to authenticated using (true);

-- Common Japanese carton sizes, as a starting point to edit.
insert into public.carton_types (name, length_cm, width_cm, height_cm, empty_weight_g, packing_material_g, max_load_kg, is_default, sort_order)
values ('60サイズ', 25, 20, 15, 150, 30, 10, false, 60),
       ('80サイズ', 35, 25, 20, 250, 50, 15, false, 80),
       ('100サイズ', 40, 30, 30, 400, 80, 20, true, 100),
       ('120サイズ', 50, 40, 30, 550, 100, 25, false, 120),
       ('140サイズ', 55, 45, 40, 750, 150, 25, false, 140)
on conflict do nothing;

create or replace function public.list_carton_types(p_include_inactive boolean default false)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', t.id, 'name', t.name, 'length_cm', t.length_cm, 'width_cm', t.width_cm,
           'height_cm', t.height_cm, 'empty_weight_g', t.empty_weight_g,
           'packing_material_g', t.packing_material_g, 'max_load_kg', t.max_load_kg,
           'is_default', t.is_default, 'status', t.status, 'sort_order', t.sort_order)
         order by t.status, t.sort_order, t.name), '[]'::jsonb)
    from public.carton_types t
   where p_include_inactive or t.status = 'active';
$$;

-- Creates (no id) or changes a carton type.
create or replace function public.save_carton_type(p jsonb)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint := nullif(p->>'id', '')::bigint;
  v_default boolean := coalesce((p->>'is_default')::boolean, false);
begin
  if not (public.has_permission('pack.complete') or public.has_permission('product.manage')) then
    raise exception 'not permitted: pack.complete required';
  end if;
  if public.tidy_text(p->>'name') is null then
    raise exception 'name is required';
  end if;
  if v_default then
    update public.carton_types set is_default = false where is_default and id is distinct from v_id;
  end if;
  if v_id is null then
    insert into public.carton_types (name, length_cm, width_cm, height_cm, empty_weight_g,
                                     packing_material_g, max_load_kg, is_default, sort_order)
    values (public.tidy_text(p->>'name'), nullif(p->>'length_cm', '')::numeric,
            nullif(p->>'width_cm', '')::numeric, nullif(p->>'height_cm', '')::numeric,
            coalesce(nullif(p->>'empty_weight_g', '')::numeric, 0),
            coalesce(nullif(p->>'packing_material_g', '')::numeric, 0),
            nullif(p->>'max_load_kg', '')::numeric, v_default,
            coalesce(nullif(p->>'sort_order', '')::int, 0))
    returning id into v_id;
  else
    update public.carton_types
       set name = public.tidy_text(p->>'name'),
           length_cm = nullif(p->>'length_cm', '')::numeric,
           width_cm = nullif(p->>'width_cm', '')::numeric,
           height_cm = nullif(p->>'height_cm', '')::numeric,
           empty_weight_g = coalesce(nullif(p->>'empty_weight_g', '')::numeric, 0),
           packing_material_g = coalesce(nullif(p->>'packing_material_g', '')::numeric, 0),
           max_load_kg = nullif(p->>'max_load_kg', '')::numeric,
           is_default = v_default,
           status = case when p->>'status' in ('active', 'inactive') then p->>'status' else status end,
           sort_order = coalesce(nullif(p->>'sort_order', '')::int, sort_order),
           updated_at = now()
     where id = v_id;
    if not found then
      raise exception 'carton type % not found', v_id;
    end if;
  end if;
  perform public.log_audit('carton_type.saved', 'carton_type', v_id::text, null, p);
  return v_id;
end;
$$;

-- ------------------------------------------------------------ cartons and plans

alter table public.shipment_cartons add column if not exists carton_type_id bigint
  references public.carton_types(id) on delete set null;
alter table public.shipment_cartons add column if not exists empty_weight_g numeric(10, 1);
alter table public.shipment_cartons add column if not exists packing_material_g numeric(10, 1);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'shipment_cartons_tare_check') then
    alter table public.shipment_cartons add constraint shipment_cartons_tare_check
      check (coalesce(empty_weight_g, 0) >= 0 and coalesce(packing_material_g, 0) >= 0);
  end if;
end $$;

-- How many of which box a shipment is expected to need, before packing.
create table if not exists public.shipment_planned_cartons (
  shipment_plan_id bigint not null references public.shipment_plans(id) on delete cascade,
  carton_type_id bigint not null references public.carton_types(id) on delete cascade,
  quantity integer not null check (quantity > 0),
  empty_weight_g numeric(10, 1) check (empty_weight_g is null or empty_weight_g >= 0),
  packing_material_g numeric(10, 1) check (packing_material_g is null or packing_material_g >= 0),
  primary key (shipment_plan_id, carton_type_id)
);
alter table public.shipment_planned_cartons enable row level security;
drop policy if exists "shipment_planned_cartons: signed-in can read" on public.shipment_planned_cartons;
create policy "shipment_planned_cartons: signed-in can read" on public.shipment_planned_cartons
  for select to authenticated using (true);

-- A carton's type, empty weight and packing material. The type fills the two
-- weights it is not given.
create or replace function public.set_carton_packaging(
  p_carton_id bigint, p_carton_type_id bigint,
  p_empty_weight_g numeric default null, p_packing_material_g numeric default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_warehouse bigint;
  v_found boolean;
  t record;
begin
  if not public.has_permission('pack.complete') then
    raise exception 'not permitted: pack.complete required';
  end if;
  select p.warehouse_id, true into v_warehouse, v_found
    from public.shipment_cartons c join public.shipment_plans p on p.id = c.shipment_plan_id
   where c.id = p_carton_id;
  if not coalesce(v_found, false) then
    raise exception 'carton % not found', p_carton_id;
  end if;
  if v_warehouse is not null and not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if coalesce(p_empty_weight_g, 0) < 0 or coalesce(p_packing_material_g, 0) < 0 then
    raise exception 'weight cannot be negative';
  end if;
  select * into t from public.carton_types where id = p_carton_type_id;
  update public.shipment_cartons
     set carton_type_id = p_carton_type_id,
         carton_type = coalesce(t.name, carton_type),
         length_cm = coalesce(length_cm, t.length_cm),
         width_cm = coalesce(width_cm, t.width_cm),
         height_cm = coalesce(height_cm, t.height_cm),
         empty_weight_g = coalesce(p_empty_weight_g, t.empty_weight_g),
         packing_material_g = coalesce(p_packing_material_g, t.packing_material_g)
   where id = p_carton_id;
  perform public.log_audit('shipment.carton_packaging', 'shipment_carton', p_carton_id::text, v_warehouse,
    jsonb_build_object('carton_type_id', p_carton_type_id, 'empty_weight_g', p_empty_weight_g,
                       'packing_material_g', p_packing_material_g));
  return public.carton_detail(p_carton_id);
end;
$$;

-- Replaces the planned boxes of a shipment: [{carton_type_id, quantity,
-- empty_weight_g?, packing_material_g?}]. An empty list clears them.
create or replace function public.set_shipment_planned_cartons(p_plan_id bigint, p_items jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_warehouse bigint;
  v_found boolean;
  e jsonb;
begin
  if not public.has_permission('pack.complete') then
    raise exception 'not permitted: pack.complete required';
  end if;
  select warehouse_id, true into v_warehouse, v_found from public.shipment_plans where id = p_plan_id;
  if not coalesce(v_found, false) then
    raise exception 'shipment % not found', p_plan_id;
  end if;
  if v_warehouse is not null and not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  delete from public.shipment_planned_cartons where shipment_plan_id = p_plan_id;
  for e in select * from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) loop
    continue when coalesce((e->>'quantity')::int, 0) <= 0;
    insert into public.shipment_planned_cartons (shipment_plan_id, carton_type_id, quantity, empty_weight_g, packing_material_g)
    values (p_plan_id, (e->>'carton_type_id')::bigint, (e->>'quantity')::int,
            nullif(e->>'empty_weight_g', '')::numeric, nullif(e->>'packing_material_g', '')::numeric)
    on conflict (shipment_plan_id, carton_type_id) do update
       set quantity = shipment_planned_cartons.quantity + excluded.quantity;
  end loop;
  perform public.log_audit('shipment.cartons_planned', 'shipment_plan', p_plan_id::text, v_warehouse,
    jsonb_build_object('items', p_items));
  return public.shipment_weight_estimate(p_plan_id);
end;
$$;

-- What the shipment should weigh. Goods from the plan's lines at each
-- product's unit weight; boxes from the real cartons once there are any,
-- else from the planned ones. Weights in grams.
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
           'weight_source', x.weight_source, 'line_weight_g', x.line_weight_g)
           order by x.product_name), '[]'::jsonb),
         coalesce(sum(x.line_weight_g), 0),
         count(*) filter (where x.unit_weight_g is null)
    into v_lines, v_goods, v_missing
    from (select sl.product_id, max(sl.jan_code) as jan_code,
                 coalesce(max(p.name), max(sl.product_name)) as product_name,
                 sum(sl.quantity)::int as quantity,
                 max(p.unit_weight_g) as unit_weight_g, max(p.weight_source) as weight_source,
                 max(p.unit_weight_g) * sum(sl.quantity) as line_weight_g
            from public.shipment_lines sl
            left join public.products p on p.id = sl.product_id
           where sl.shipment_plan_id = p_plan_id
           group by sl.product_id, coalesce(sl.product_id::text, sl.jan_code)) x;

  select coalesce(jsonb_agg(jsonb_build_object(
           'carton_id', c.id, 'carton_no', c.carton_no, 'carton_type_id', c.carton_type_id,
           'carton_type', c.carton_type, 'status', c.status,
           'empty_weight_g', c.empty_weight_g, 'packing_material_g', c.packing_material_g,
           'contents_weight_g', (select sum(i.quantity * p.unit_weight_g) from public.shipment_carton_items i
                                   join public.products p on p.id = i.product_id where i.carton_id = c.id),
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

-- ------------------------------------------------------------ products list

create or replace function public.list_products(p_search text default null, p_status text default 'active')
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('product.view') then
    raise exception 'not permitted: product.view required';
  end if;

  return coalesce(
    (select jsonb_agg(jsonb_build_object(
        'id', p.id, 'jan_code', p.jan_code, 'name', p.name,
        'category', p.category, 'price', p.price, 'status', p.status,
        'sku', p.sku, 'tracking_mode', p.tracking_mode,
        'picking_rule', p.picking_rule,
        'requires_inspection', p.requires_inspection,
        'maker', p.maker,
        'unit_weight_g', p.unit_weight_g, 'weight_source', p.weight_source,
        'weight_source_url', p.weight_source_url, 'weight_note', p.weight_note,
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

revoke all on function public.pack_weight_g(bigint, bigint) from public, anon;
revoke all on function public.set_product_weight(bigint, numeric, text, text, text) from public, anon;
revoke all on function public.set_product_pack(bigint, text, numeric, numeric, numeric) from public, anon;
revoke all on function public.remove_product_pack(bigint, text) from public, anon;
revoke all on function public.list_carton_types(boolean) from public, anon;
revoke all on function public.save_carton_type(jsonb) from public, anon;
revoke all on function public.set_carton_packaging(bigint, bigint, numeric, numeric) from public, anon;
revoke all on function public.set_shipment_planned_cartons(bigint, jsonb) from public, anon;
revoke all on function public.shipment_weight_estimate(bigint) from public, anon;
grant execute on function public.pack_weight_g(bigint, bigint) to authenticated, service_role;
grant execute on function public.set_product_weight(bigint, numeric, text, text, text) to authenticated, service_role;
grant execute on function public.set_product_pack(bigint, text, numeric, numeric, numeric) to authenticated, service_role;
grant execute on function public.remove_product_pack(bigint, text) to authenticated, service_role;
grant execute on function public.list_carton_types(boolean) to authenticated, service_role;
grant execute on function public.save_carton_type(jsonb) to authenticated, service_role;
grant execute on function public.set_carton_packaging(bigint, bigint, numeric, numeric) to authenticated, service_role;
grant execute on function public.set_shipment_planned_cartons(bigint, jsonb) to authenticated, service_role;
grant execute on function public.shipment_weight_estimate(bigint) to authenticated, service_role;
grant execute on function public.list_products(text, text) to authenticated, service_role;
