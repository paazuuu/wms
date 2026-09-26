-- 0087 — warehouses in more than one country, each supplier's own name for a
-- product, and one naming on every slip that goes downstream.
--
-- 1. COUNTRIES. A warehouse now says which country it is in. The Japan
--    warehouse buys; it can ship straight to a customer anywhere (a normal
--    shipment — stock leaves, as it always did), or transfer to a warehouse in
--    another country. The rule for a transfer that crosses a border: once the
--    goods leave the country, this system no longer holds them. The source is
--    debited as for any transfer, and the transfer closes as EXPORTED at that
--    point — nothing is received, nothing is credited anywhere.
--
--    The one exception is opt-in per warehouse: `receives_cross_border`. A
--    foreign warehouse that sets it receives cross-border transfers like any
--    other transfer, holds the stock, and can ship it to its own customers.
--    That is the "later, a China warehouse serving individual customers" case,
--    built now so it is a switch rather than a project.
--
--    Warehouses are created and edited through the `warehouses` edge
--    function, which whitelists its fields; the country and the switch are set
--    through their own RPC instead, gated on warehouse.manage and scope.
--
-- 2. SUPPLIER NAMES. The same product is called something different by each
--    supplier, often with a code of their own. `supplier_product_names` keeps
--    one name (and optionally one code) per supplier per product. It is used
--    to find the product by the supplier's words (product search), to match a
--    supplier's delivery note to our products when a line has no usable JAN,
--    and to show the supplier's name beside our own on purchase orders.
--
-- 3. SLIPS. Every downstream slip — shipments however they were made, and now
--    transfers too — prints our product master's name. What the source
--    document called the item is kept, in `source_product_name`, never lost.

-- ---------------------------------------------------------------------------
-- 1. Countries
-- ---------------------------------------------------------------------------

alter table public.warehouses
  add column if not exists country_code text not null default 'JP',
  add column if not exists receives_cross_border boolean not null default false;

do $$ begin
  alter table public.warehouses
    add constraint warehouses_country_code_check check (country_code ~ '^[A-Z]{2}$');
exception when duplicate_object then null; end $$;

create or replace function public.set_warehouse_role(
  p_warehouse_id bigint,
  p_country_code text,
  p_receives_cross_border boolean default false
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_code text := upper(btrim(coalesce(p_country_code, '')));
  v_before record;
begin
  if not public.has_permission('warehouse.manage') then
    raise exception 'not permitted: warehouse.manage required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_code !~ '^[A-Z]{2}$' then
    raise exception 'country code must be two letters, e.g. JP or CN';
  end if;
  select country_code, receives_cross_border into v_before
    from public.warehouses where id = p_warehouse_id;
  if not found then
    raise exception 'warehouse % not found', p_warehouse_id;
  end if;

  update public.warehouses
     set country_code = v_code,
         receives_cross_border = coalesce(p_receives_cross_border, false),
         updated_at = now()
   where id = p_warehouse_id;

  perform public.log_audit('warehouse.role_changed', 'warehouse', p_warehouse_id::text,
    p_warehouse_id, jsonb_build_object(
      'country_code', jsonb_build_array(v_before.country_code, v_code),
      'receives_cross_border', jsonb_build_array(v_before.receives_cross_border,
                                                 coalesce(p_receives_cross_border, false))));

  return jsonb_build_object('warehouse_id', p_warehouse_id, 'country_code', v_code,
    'receives_cross_border', coalesce(p_receives_cross_border, false));
end;
$$;

revoke all on function public.set_warehouse_role(bigint, text, boolean) from public, anon;
grant execute on function public.set_warehouse_role(bigint, text, boolean) to authenticated, service_role;

-- Every warehouse's country and switch, for the forms that choose one.
create or replace function public.warehouse_roles()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('warehouse.view') and not public.has_permission('warehouse.manage')
     and not public.has_permission('transfer.create') then
    raise exception 'not permitted: warehouse.view required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', w.id, 'code', w.code, 'name', w.name,
             'country_code', w.country_code,
             'receives_cross_border', w.receives_cross_border) order by w.id)
      from public.warehouses w
     where public.can_access_warehouse(w.id) or public.has_permission('transfer.create')),
    '[]'::jsonb);
end;
$$;

revoke all on function public.warehouse_roles() from public, anon;
grant execute on function public.warehouse_roles() to authenticated, service_role;

alter table public.transfer_orders
  add column if not exists cross_border boolean not null default false,
  add column if not exists exported_at timestamptz;

alter table public.transfer_orders drop constraint if exists transfer_orders_status_check;
alter table public.transfer_orders add constraint transfer_orders_status_check
  check (status = any (array['DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'PICKING', 'IN_TRANSIT',
                             'RECEIVING', 'COMPLETED', 'EXPORTED', 'REJECTED', 'CANCELLED']));

-- Whether a transfer leaves the system at the source: it crosses a border and
-- the destination has not opted in to receiving.
create or replace function public.transfer_exports(p_transfer_id bigint)
returns boolean
language sql stable security definer set search_path = '' as $$
  select sw.country_code <> dw.country_code and not dw.receives_cross_border
    from public.transfer_orders o
    join public.warehouses sw on sw.id = o.source_warehouse_id
    join public.warehouses dw on dw.id = o.destination_warehouse_id
   where o.id = p_transfer_id;
$$;

revoke all on function public.transfer_exports(bigint) from public, anon, authenticated;
grant execute on function public.transfer_exports(bigint) to service_role;

create or replace function public.complete_transfer_picking(p_transfer_id bigint)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_status  text;
  v_source  bigint;
  v_pending integer;
  v_cross   boolean;
  v_exports boolean;
  r         record;
begin
  select o.status, o.source_warehouse_id,
         sw.country_code <> dw.country_code
    into v_status, v_source, v_cross
    from public.transfer_orders o
    join public.warehouses sw on sw.id = o.source_warehouse_id
    join public.warehouses dw on dw.id = o.destination_warehouse_id
   where o.id = p_transfer_id;
  if v_status is null then raise exception 'transfer % not found', p_transfer_id; end if;
  if v_status <> 'PICKING' then
    raise exception 'transfer % is % and cannot complete picking', p_transfer_id, v_status;
  end if;

  select count(*) into v_pending from public.transfer_order_lines
   where transfer_order_id = p_transfer_id and picked_quantity is null;
  if v_pending > 0 then
    raise exception 'transfer % still has % unpicked line(s)', p_transfer_id, v_pending;
  end if;

  for r in
    select jan_code, sum(picked_quantity)::int as qty, max(product_name) as pname
      from public.transfer_order_lines
     where transfer_order_id = p_transfer_id and picked_quantity > 0
     group by jan_code
  loop
    perform public.apply_stock_movement(
      v_source, r.jan_code, -r.qty, 'TRANSFER_OUT',
      'transfer_order', p_transfer_id::text, r.pname);
  end loop;

  v_exports := public.transfer_exports(p_transfer_id);

  -- Across a border, the goods are gone from this system the moment they
  -- leave — unless the destination has chosen to receive them.
  update public.transfer_orders
     set status = case when v_exports then 'EXPORTED' else 'IN_TRANSIT' end,
         shipped_at = now(),
         exported_at = case when v_exports then now() end,
         cross_border = v_cross
   where id = p_transfer_id;

  perform public.log_audit(
    case when v_exports then 'transfer.exported' else 'transfer.shipped' end,
    'transfer_order', p_transfer_id::text, v_source,
    jsonb_build_object('cross_border', v_cross));
  return p_transfer_id;
end;
$$;

-- Read by the detail below, so added before it.
alter table public.shipment_lines add column if not exists source_product_name text;
alter table public.transfer_order_lines add column if not exists source_product_name text;

create or replace function public.transfer_order_detail_impl(p_transfer_id bigint)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', o.id,
    'transfer_number', o.transfer_number,
    'source_warehouse_id', o.source_warehouse_id,
    'source_warehouse_name', sw.name,
    'source_country_code', sw.country_code,
    'destination_warehouse_id', o.destination_warehouse_id,
    'destination_warehouse_name', dw.name,
    'destination_country_code', dw.country_code,
    'destination_address', dw.address,
    'destination_phone', dw.phone,
    'cross_border', sw.country_code <> dw.country_code,
    'exports', sw.country_code <> dw.country_code and not dw.receives_cross_border,
    'status', o.status,
    'note', o.note,
    'requested_by', o.requested_by,
    'approved_by', o.approved_by,
    'approved_at', o.approved_at,
    'shipped_at', o.shipped_at,
    'exported_at', o.exported_at,
    'received_at', o.received_at,
    'created_at', o.created_at,
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', l.id,
               'jan_code', l.jan_code,
               'product_name', l.product_name,
               'source_product_name', l.source_product_name,
               'requested_quantity', l.requested_quantity,
               'picked_quantity', l.picked_quantity,
               'pick_variance', l.pick_variance,
               'received_quantity', l.received_quantity,
               'receive_variance', l.receive_variance) order by l.id)
        from public.transfer_order_lines l
       where l.transfer_order_id = o.id), '[]'::jsonb))
  from public.transfer_orders o
  join public.warehouses sw on sw.id = o.source_warehouse_id
  join public.warehouses dw on dw.id = o.destination_warehouse_id
  where o.id = p_transfer_id;
$$;

create or replace function public.transfer_order_index_impl(
  p_warehouse_id bigint default null, p_status text default null, p_limit integer default 50)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(row_to_json(x)::jsonb order by x.id desc), '[]'::jsonb)
  from (
    select o.id,
           o.transfer_number,
           o.source_warehouse_id,
           sw.name as source_warehouse_name,
           sw.country_code as source_country_code,
           o.destination_warehouse_id,
           dw.name as destination_warehouse_name,
           dw.country_code as destination_country_code,
           sw.country_code <> dw.country_code as cross_border,
           sw.country_code <> dw.country_code and not dw.receives_cross_border as exports,
           o.status,
           o.created_at,
           o.shipped_at,
           o.received_at,
           (select count(*) from public.transfer_order_lines l
             where l.transfer_order_id = o.id) as line_count
      from public.transfer_orders o
      join public.warehouses sw on sw.id = o.source_warehouse_id
      join public.warehouses dw on dw.id = o.destination_warehouse_id
     where (p_warehouse_id is null
            or o.source_warehouse_id = p_warehouse_id
            or o.destination_warehouse_id = p_warehouse_id)
       and (public.accessible_warehouse_ids() is null
            or o.source_warehouse_id = any(public.accessible_warehouse_ids())
            or o.destination_warehouse_id = any(public.accessible_warehouse_ids()))
       and (p_status is null or o.status = p_status)
     order by o.id desc
     limit greatest(1, least(coalesce(p_limit, 50), 200))
  ) x;
$$;

-- ---------------------------------------------------------------------------
-- 2. Each supplier's name for a product
-- ---------------------------------------------------------------------------

create table if not exists public.supplier_product_names (
  id bigint generated by default as identity primary key,
  supplier_id bigint not null references public.delivery_suppliers (id) on delete cascade,
  product_id bigint not null references public.products (id) on delete cascade,
  supplier_code text,
  supplier_name text not null,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint supplier_product_names_one_per_product unique (supplier_id, product_id),
  constraint supplier_product_names_name_check check (btrim(supplier_name) <> '')
);

create unique index if not exists supplier_product_names_code_key
  on public.supplier_product_names (supplier_id, supplier_code)
  where supplier_code is not null;
create index if not exists supplier_product_names_product_idx
  on public.supplier_product_names (product_id);

alter table public.supplier_product_names enable row level security;
drop policy if exists "read supplier product names" on public.supplier_product_names;
create policy "read supplier product names" on public.supplier_product_names
  for select to authenticated
  using (public.has_permission('product.view') or public.has_permission('purchase_order.view'));

create or replace function public.list_supplier_product_names(
  p_product_id bigint default null, p_supplier_id bigint default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('product.view') or public.has_permission('purchase_order.view')) then
    raise exception 'not permitted: product.view required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', n.id, 'supplier_id', n.supplier_id, 'supplier_display_name', s.name,
             'product_id', n.product_id, 'jan_code', p.jan_code, 'product_name', p.name,
             'supplier_code', n.supplier_code, 'supplier_name', n.supplier_name,
             'note', n.note) order by s.name, p.name)
      from public.supplier_product_names n
      join public.delivery_suppliers s on s.id = n.supplier_id
      join public.products p on p.id = n.product_id
     where (p_product_id is null or n.product_id = p_product_id)
       and (p_supplier_id is null or n.supplier_id = p_supplier_id)), '[]'::jsonb);
end;
$$;

create or replace function public.set_supplier_product_name(
  p_supplier_id bigint,
  p_product_id bigint,
  p_supplier_name text,
  p_supplier_code text default null,
  p_note text default null
) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
  v_code text := nullif(btrim(coalesce(p_supplier_code, '')), '');
begin
  if not (public.has_permission('product.manage') or public.has_permission('purchase_order.manage')) then
    raise exception 'not permitted: product.manage required';
  end if;
  if nullif(btrim(coalesce(p_supplier_name, '')), '') is null then
    raise exception 'the supplier''s name for the product is required';
  end if;
  if not exists (select 1 from public.delivery_suppliers where id = p_supplier_id) then
    raise exception 'supplier % not found', p_supplier_id;
  end if;
  if not exists (select 1 from public.products where id = p_product_id) then
    raise exception 'product % not found', p_product_id;
  end if;
  if v_code is not null and exists (
       select 1 from public.supplier_product_names
        where supplier_id = p_supplier_id and supplier_code = v_code
          and product_id <> p_product_id) then
    raise exception 'this supplier already uses code % for another product', v_code;
  end if;

  insert into public.supplier_product_names
    (supplier_id, product_id, supplier_code, supplier_name, note)
  values (p_supplier_id, p_product_id, v_code, btrim(p_supplier_name), nullif(btrim(coalesce(p_note, '')), ''))
  on conflict (supplier_id, product_id) do update
     set supplier_code = excluded.supplier_code,
         supplier_name = excluded.supplier_name,
         note = excluded.note,
         updated_at = now()
  returning id into v_id;

  perform public.log_audit('product.supplier_name_set', 'product', p_product_id::text, null,
    jsonb_build_object('supplier_id', p_supplier_id, 'supplier_code', v_code,
                       'supplier_name', btrim(p_supplier_name)));
  return v_id;
end;
$$;

create or replace function public.remove_supplier_product_name(p_id bigint)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_row record;
begin
  if not (public.has_permission('product.manage') or public.has_permission('purchase_order.manage')) then
    raise exception 'not permitted: product.manage required';
  end if;
  delete from public.supplier_product_names where id = p_id
  returning product_id, supplier_id into v_row;
  if not found then return false; end if;
  perform public.log_audit('product.supplier_name_removed', 'product', v_row.product_id::text,
    null, jsonb_build_object('supplier_id', v_row.supplier_id));
  return true;
end;
$$;

revoke all on function public.list_supplier_product_names(bigint, bigint) from public, anon;
revoke all on function public.set_supplier_product_name(bigint, bigint, text, text, text) from public, anon;
revoke all on function public.remove_supplier_product_name(bigint) from public, anon;
grant execute on function public.list_supplier_product_names(bigint, bigint) to authenticated, service_role;
grant execute on function public.set_supplier_product_name(bigint, bigint, text, text, text) to authenticated, service_role;
grant execute on function public.remove_supplier_product_name(bigint) to authenticated, service_role;

-- A supplier's own code or name for one of our products, if it knows it.
create or replace function public.product_for_supplier_item(
  p_supplier_id bigint, p_code text, p_name text)
returns bigint
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select n.product_id from public.supplier_product_names n
      where n.supplier_id = p_supplier_id
        and n.supplier_code = nullif(btrim(coalesce(p_code, '')), '') limit 1),
    (select n.product_id from public.supplier_product_names n
      where n.supplier_id = p_supplier_id
        and lower(n.supplier_name) = lower(nullif(btrim(coalesce(p_name, '')), '')) limit 1));
$$;

revoke all on function public.product_for_supplier_item(bigint, text, text) from public, anon, authenticated;
grant execute on function public.product_for_supplier_item(bigint, text, text) to service_role;

-- A supplier's delivery note often carries its own code and name and a JAN
-- that is missing or not ours. When the JAN does not resolve, the supplier's
-- code or name is tried before the line is left unmatched. Named to sort
-- before `delivery_plan_lines_fill_product_id`, which then fills product_id.
create or replace function public.delivery_plan_line_resolve_supplier_name()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_supplier bigint;
  v_product bigint;
begin
  if new.product_id is not null
     or (new.jan_code is not null and public.product_for_jan(new.jan_code) is not null) then
    return new;
  end if;
  select supplier_id into v_supplier from public.delivery_plans where id = new.delivery_plan_id;
  if v_supplier is null then return new; end if;
  v_product := public.product_for_supplier_item(v_supplier, new.product_code, new.product_name);
  if v_product is not null then
    new.product_id := v_product;
    new.jan_code := (select jan_code from public.products where id = v_product);
  end if;
  return new;
end;
$$;

revoke all on function public.delivery_plan_line_resolve_supplier_name() from public, anon, authenticated;

drop trigger if exists delivery_plan_lines_a_supplier_name on public.delivery_plan_lines;
create trigger delivery_plan_lines_a_supplier_name
  before insert on public.delivery_plan_lines
  for each row execute function public.delivery_plan_line_resolve_supplier_name();

-- Our products, found by any supplier's name or code too.
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
        'created_at', p.created_at, 'updated_at', p.updated_at,
        'base_uom', (select jsonb_build_object('id', u.id, 'code', u.code, 'name', u.name)
                       from public.uoms u where u.id = p.base_uom_id),
        'uoms', coalesce((
          select jsonb_agg(jsonb_build_object(
                   'code', u.code, 'name', u.name,
                   'conversion_factor', pu.conversion_factor,
                   'is_base', pu.uom_id = p.base_uom_id)
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

-- ---------------------------------------------------------------------------
-- 3. One name on every downstream slip
-- ---------------------------------------------------------------------------

-- A line that names a product we know prints our name for it. The words the
-- order, the customer's sheet or the supplier used stay in
-- source_product_name. Runs after fill_product_id (name order), so product_id
-- is already resolved from the JAN.
create or replace function public.outbound_line_master_name()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_name text;
begin
  if new.product_id is null then return new; end if;
  select name into v_name from public.products where id = new.product_id;
  if v_name is null or btrim(v_name) = '' then return new; end if;
  if tg_op = 'UPDATE' then
    if new.product_id is not distinct from old.product_id then return new; end if;
  end if;
  if coalesce(new.product_name, '') <> v_name then
    new.source_product_name := coalesce(new.source_product_name, nullif(new.product_name, ''));
    new.product_name := v_name;
  end if;
  return new;
end;
$$;

revoke all on function public.outbound_line_master_name() from public, anon, authenticated;

drop trigger if exists shipment_lines_master_name on public.shipment_lines;
create trigger shipment_lines_master_name
  before insert or update of product_id on public.shipment_lines
  for each row execute function public.outbound_line_master_name();

drop trigger if exists transfer_order_lines_master_name on public.transfer_order_lines;
create trigger transfer_order_lines_master_name
  before insert or update of product_id on public.transfer_order_lines
  for each row execute function public.outbound_line_master_name();

-- Existing lines, the same way.
update public.shipment_lines l
   set source_product_name = coalesce(l.source_product_name, nullif(l.product_name, '')),
       product_name = p.name
  from public.products p
 where p.id = l.product_id and btrim(coalesce(p.name, '')) <> ''
   and coalesce(l.product_name, '') <> p.name;

update public.transfer_order_lines l
   set source_product_name = coalesce(l.source_product_name, nullif(l.product_name, '')),
       product_name = p.name
  from public.products p
 where p.id = l.product_id and btrim(coalesce(p.name, '')) <> ''
   and coalesce(l.product_name, '') <> p.name;
