-- 0167: marks on products, shelf notes, and who entered a delivery plan.
--
-- * products.marks: ★ (star) and ⚠ (warning), with a note for the warning,
--   set by anyone who handles goods (product.manage, inspection, receiving,
--   putaway or stock adjustment) and seen by everyone — so an inspector sees
--   the warning a buyer left. list_products carries them.
-- * shelf_notes: free notes on where things were put (棚入れ) — a product
--   (kept by JAN too, should the product go), a place, and the note as
--   bullets — searched in the app. Written by those who put away or adjust
--   stock, or manage products; read by product.view.
-- * delivery_plans.created_by / created_by_name: who entered the plan (the
--   import passes the caller; plans made in the database take auth.uid()).

alter table public.products add column if not exists marks text[] not null default '{}';
alter table public.products add column if not exists mark_note text;
alter table public.products add column if not exists marks_updated_at timestamptz;
alter table public.products add column if not exists marks_updated_by uuid;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'products_marks_check') then
    alter table public.products add constraint products_marks_check check (marks <@ array['star', 'warning']::text[]);
  end if;
end $$;

create or replace function public.can_mark_products()
returns boolean
language sql stable security definer set search_path = '' as $$
  select public.has_permission('product.manage') or public.has_permission('inspection.confirm')
      or public.has_permission('receiving.confirm') or public.has_permission('putaway.confirm')
      or public.has_permission('inventory.adjust');
$$;
grant execute on function public.can_mark_products() to authenticated;

create or replace function public.set_product_marks(p_product_id bigint, p_marks text[], p_note text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_marks text[] := coalesce((select array_agg(distinct m order by m) from unnest(coalesce(p_marks, '{}')) m
                               where m in ('star', 'warning')), '{}');
begin
  if not public.can_mark_products() then
    raise exception 'not permitted: product.manage required';
  end if;
  update public.products
     set marks = v_marks,
         mark_note = case when 'warning' = any (v_marks) then nullif(btrim(coalesce(p_note, '')), '') end,
         marks_updated_at = now(), marks_updated_by = auth.uid()
   where id = p_product_id;
  if not found then
    raise exception 'product % not found', p_product_id;
  end if;
  return (select jsonb_build_object('id', id, 'marks', to_jsonb(marks), 'mark_note', mark_note)
            from public.products where id = p_product_id);
end;
$$;
revoke all on function public.set_product_marks(bigint, text[], text) from public, anon;
grant execute on function public.set_product_marks(bigint, text[], text) to authenticated;

create table if not exists public.shelf_notes (
  id bigint generated always as identity primary key,
  product_id bigint references public.products (id) on delete set null,
  jan_code text,
  location text,
  body text not null check (btrim(body) <> ''),
  created_at timestamptz not null default now(),
  created_by uuid,
  created_by_name text,
  updated_at timestamptz,
  updated_by_name text
);
create index if not exists shelf_notes_product on public.shelf_notes (product_id);
alter table public.shelf_notes enable row level security;
create policy shelf_notes_read on public.shelf_notes
  for select to authenticated using (public.has_permission('product.view'));
grant select on public.shelf_notes to authenticated;

create or replace function public.can_write_shelf_notes()
returns boolean
language sql stable security definer set search_path = '' as $$
  select public.has_permission('putaway.confirm') or public.has_permission('inventory.adjust')
      or public.has_permission('product.manage');
$$;
grant execute on function public.can_write_shelf_notes() to authenticated;

create or replace function public.user_display_name(p_user uuid)
returns text
language sql stable security definer set search_path = '' as $$
  select coalesce(nullif(u.name, ''), u.email) from public.app_users u where u.id = p_user;
$$;

-- [p]: {id?, product_id?, location?, body}. Returns the note.
create or replace function public.save_shelf_note(p jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint := nullif(p->>'id', '')::bigint;
  v_product bigint := nullif(p->>'product_id', '')::bigint;
  v_body text := nullif(btrim(coalesce(p->>'body', '')), '');
  v_row public.shelf_notes;
begin
  if not public.can_write_shelf_notes() then
    raise exception 'not permitted: putaway.confirm required';
  end if;
  if v_body is null then
    raise exception 'shelf_note_empty';
  end if;
  if v_id is null then
    insert into public.shelf_notes (product_id, jan_code, location, body, created_by, created_by_name)
    values (v_product, (select jan_code from public.products where id = v_product),
            nullif(btrim(coalesce(p->>'location', '')), ''), v_body, auth.uid(), public.user_display_name(auth.uid()))
    returning * into v_row;
  else
    update public.shelf_notes
       set product_id = v_product,
           jan_code = coalesce((select jan_code from public.products where id = v_product), case when v_product is null then null else jan_code end),
           location = nullif(btrim(coalesce(p->>'location', '')), ''), body = v_body,
           updated_at = now(), updated_by_name = public.user_display_name(auth.uid())
     where id = v_id
    returning * into v_row;
    if not found then
      raise exception 'shelf note % not found', v_id;
    end if;
  end if;
  return to_jsonb(v_row);
end;
$$;
revoke all on function public.save_shelf_note(jsonb) from public, anon;
grant execute on function public.save_shelf_note(jsonb) to authenticated;

create or replace function public.delete_shelf_note(p_id bigint)
returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not public.can_write_shelf_notes() then
    raise exception 'not permitted: putaway.confirm required';
  end if;
  delete from public.shelf_notes where id = p_id;
  return found;
end;
$$;
revoke all on function public.delete_shelf_note(bigint) from public, anon;
grant execute on function public.delete_shelf_note(bigint) to authenticated;

alter table public.delivery_plans add column if not exists created_by uuid;
alter table public.delivery_plans add column if not exists created_by_name text;
create or replace function public.delivery_plans_creator()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.created_by := coalesce(new.created_by, auth.uid());
  if new.created_by is not null and new.created_by_name is null then
    new.created_by_name := public.user_display_name(new.created_by);
  end if;
  return new;
end;
$$;
revoke all on function public.delivery_plans_creator() from public, anon, authenticated;
create or replace trigger delivery_plans_creator before insert on public.delivery_plans
  for each row execute function public.delivery_plans_creator();

-- The list carries the marks.
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
        'marks', to_jsonb(p.marks), 'mark_note', p.mark_note,
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
