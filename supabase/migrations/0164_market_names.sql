-- 0164: a product's name as the market knows it, and removing products
-- left to the system administrator.
--
-- * A product registered from a file with no name has its 品番 for a name
--   (StockFileLine.registerName, price_book_to_products). Its name as shops
--   and its maker call it (エナージェル タイプA 0.5mm 黒) is looked up on the
--   web by the AI (import-plan lookup_names) and kept per JAN here, apart
--   from the products — like the AI's weights (0155).
-- * Taken onto a product only when the product has no name of its own: its
--   基本名 empty or the 品番 (or JAN), and not named by hand. A person's name
--   is never replaced. Taken as the 基本名, so the name is built by the
--   product's format as any other (0111); marked base_name_source = 'ai'.
-- * A product registered later with a JAN already looked up gets the name
--   at once (products_a_fill_jan_name, before the name is rendered).
-- * 価格台帳 lines whose name is only their 品番 take it too.
-- * product.delete: the system administrator's only (no longer the company
--   administrator's).

create table if not exists public.jan_name_lookups (
  jan text primary key check (jan ~ '^[0-9]{8,14}$'),
  name text,
  series text,
  maker text,
  source_url text,
  confidence numeric check (confidence is null or (confidence >= 0 and confidence <= 1)),
  note text,
  looked_at timestamptz not null default now(),
  looked_by uuid
);
alter table public.jan_name_lookups enable row level security;
create policy jan_name_lookups_read on public.jan_name_lookups
  for select to authenticated using (public.has_permission('product.view'));
grant select on public.jan_name_lookups to authenticated;

alter table public.products add column if not exists base_name_source text;
alter table public.products add column if not exists base_name_source_url text;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'products_base_name_source_check') then
    alter table public.products add constraint products_base_name_source_check
      check (base_name_source is null or base_name_source in ('ai'));
  end if;
end $$;

-- The name the web gave for a JAN, when it is one to take: found, and the
-- AI sure enough of it.
create or replace function public.jan_market_name(p_jan text)
returns table (name text, source_url text)
language sql stable security definer set search_path = '' as $$
  select l.name, l.source_url from public.jan_name_lookups l
   where l.jan = p_jan and nullif(btrim(l.name), '') is not null and coalesce(l.confidence, 0) >= 0.6;
$$;
revoke all on function public.jan_market_name(text) from public, anon;
grant execute on function public.jan_market_name(text) to authenticated, service_role;

-- A product whose only name is its 品番 (or JAN), not named by hand.
create or replace function public.product_lacks_name(
  p_name text, p_base text, p_sku text, p_jan text, p_manual boolean)
returns boolean
language sql immutable set search_path = '' as $$
  select not coalesce(p_manual, false) and (
    case when nullif(btrim(p_base), '') is not null
      then btrim(p_base) in (coalesce(btrim(p_sku), ''), coalesce(p_jan, ''))
      else nullif(btrim(p_name), '') is null or btrim(p_name) in (coalesce(btrim(p_sku), ''), coalesce(p_jan, ''))
    end);
$$;

-- The names found taken onto the products (and 価格台帳 lines) lacking one.
create or replace function public.apply_jan_names(p_jans text[] default null)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  n integer := 0;
  m integer := 0;
begin
  update public.products p
     set base_name = mn.name, base_name_source = 'ai', base_name_source_url = mn.source_url, updated_at = now()
    from public.jan_name_lookups l
    cross join lateral public.jan_market_name(l.jan) mn
   where p.jan_code = l.jan
     and (p_jans is null or l.jan = any (p_jans))
     and public.product_lacks_name(p.name, p.base_name, p.sku, p.jan_code, p.name_manual);
  get diagnostics n = row_count;
  update public.price_book_items i
     set name = mn.name
    from public.jan_name_lookups l
    cross join lateral public.jan_market_name(l.jan) mn
   where i.jan_code = l.jan
     and (p_jans is null or l.jan = any (p_jans))
     and (nullif(btrim(i.name), '') is null or btrim(i.name) in (coalesce(btrim(i.item_code), ''), i.jan_code));
  get diagnostics m = row_count;
  return n;
end;
$$;
revoke all on function public.apply_jan_names(text[]) from public, anon, authenticated;
grant execute on function public.apply_jan_names(text[]) to service_role;

-- What the AI found, kept (each JAN once, the latest answer), and taken onto
-- the products lacking a name. [p]: [{jan, name, series, maker, source_url,
-- confidence, note}]; an answer without a name is kept too, so the JAN is
-- not asked again and again.
create or replace function public.jan_name_save(p jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_jans text[];
  v_applied integer;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  insert into public.jan_name_lookups (jan, name, series, maker, source_url, confidence, note, looked_at, looked_by)
  select x.jan, nullif(btrim(x.name), ''), nullif(btrim(x.series), ''), nullif(btrim(x.maker), ''),
         case when x.source_url ~ '^https?://' then x.source_url end,
         case when x.confidence between 0 and 1 then x.confidence end,
         nullif(btrim(x.note), ''), now(), auth.uid()
    from jsonb_to_recordset(coalesce(p, '[]'::jsonb))
         as x(jan text, name text, series text, maker text, source_url text, confidence numeric, note text)
   where x.jan ~ '^[0-9]{8,14}$'
  on conflict (jan) do update
     set name = excluded.name, series = excluded.series, maker = excluded.maker,
         source_url = excluded.source_url, confidence = excluded.confidence, note = excluded.note,
         looked_at = excluded.looked_at, looked_by = excluded.looked_by;
  select array_agg(distinct x.jan) into v_jans
    from jsonb_to_recordset(coalesce(p, '[]'::jsonb)) as x(jan text)
   where x.jan ~ '^[0-9]{8,14}$';
  v_applied := public.apply_jan_names(coalesce(v_jans, '{}'));
  return jsonb_build_object('saved', coalesce(array_length(v_jans, 1), 0), 'applied', v_applied);
end;
$$;
revoke all on function public.jan_name_save(jsonb) from public, anon;
grant execute on function public.jan_name_save(jsonb) to authenticated;

-- A product registered with a JAN already looked up: the name at once, before
-- products_b_render_name builds the name from it.
create or replace function public.products_fill_jan_name()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  mn record;
begin
  if new.jan_code is null or not public.product_lacks_name(new.name, new.base_name, new.sku, new.jan_code, new.name_manual) then
    return new;
  end if;
  if tg_op = 'UPDATE' and new.jan_code is not distinct from old.jan_code then
    return new;
  end if;
  select * into mn from public.jan_market_name(new.jan_code);
  if mn.name is not null then
    new.base_name := mn.name;
    new.base_name_source := 'ai';
    new.base_name_source_url := mn.source_url;
  end if;
  return new;
end;
$$;
revoke all on function public.products_fill_jan_name() from public, anon, authenticated;
create or replace trigger products_a_fill_jan_name before insert or update of jan_code on public.products
  for each row execute function public.products_fill_jan_name();

-- A name a person gives is theirs: the 'ai' mark goes.
create or replace function public.products_name_source_by_hand()
returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.base_name_source = 'ai' and new.base_name is distinct from old.base_name
     and old.base_name_source is not distinct from new.base_name_source then
    new.base_name_source := null;
    new.base_name_source_url := null;
  end if;
  if new.name_manual and not coalesce(old.name_manual, false) then
    new.base_name_source := null;
    new.base_name_source_url := null;
  end if;
  return new;
end;
$$;
create or replace trigger products_a_name_source_by_hand before update on public.products
  for each row execute function public.products_name_source_by_hand();

-- The list carries where the name came from.
create or replace function public.list_products(p_search text default null, p_status text default 'active')
returns jsonb
language plpgsql stable security definer set search_path = '' as $function$
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
        'base_name_source', p.base_name_source, 'base_name_source_url', p.base_name_source_url,
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
                            or n.supplier_code ilike '%' || p_search || '%'
                            or n.supplier_jan_code ilike '%' || p_search || '%'
                            or n.supplier_maker ilike '%' || p_search || '%')) or
            exists (select 1 from public.notation_dialects d
                     where d.product_id = p.id
                       and array_to_string(d.raw_values, ' ') ilike '%' || p_search || '%'))),
    '[]'::jsonb);
end;
$function$;

-- Removing products for good: the system administrator only.
do $$
begin
  delete from public.role_permissions rp
   using public.roles r, public.permissions pm
   where rp.role_id = r.id and rp.permission_id = pm.id
     and pm.code = 'product.delete' and r.code <> 'system_admin';
end $$;
