-- Phase A, step 10: warehouse-specific product settings (§22, §31).
--
-- §22's example is the whole feature: the same product lives at A-01 in Osaka,
-- B-03 in Kobe and C-10 in Tokyo, and "where does this go" has three different
-- right answers. Today there is nowhere to put any of them, so a put-away
-- decision has to be made from memory every time, and a reorder point cannot
-- exist at all because it would have to mean the same number in every building.
--
-- `warehouse_products` is that split: `products` keeps what is true of the goods
-- everywhere, and this keeps what is true of them *here*.
--
-- A row is optional. No row means no special settings, which is the honest
-- default — seeding one per product × warehouse would fill the table with
-- nulls and make "has anyone thought about this product here?" unanswerable.
--
-- WHY THE DEFAULT LOCATION POINTS AT `locations`
--
-- 0062 made `locations` canonical for structure, so a put-away target is named
-- there and not in `bins`. That also means the target can be a rack or a zone
-- rather than only a leaf bin, which is what a rule like "put this line in aisle
-- 3, anywhere" actually needs. The read hands back `default_bin_id` alongside it
-- (from `locations.bin_id`) so a caller that still works in bins — which every
-- put-away RPC does today — needs no translation layer.
--
-- WHAT §31 GETS FROM 0061
--
-- A reorder point compared against `on_hand` is the wrong comparison: stock that
-- is quarantined or damaged is on hand and cannot cover an order. 0061 made
-- `available` a real number, so `replenishment_suggestions()` compares against
-- *that*, and a warehouse holding 100 units of which 90 are blocked correctly
-- reads as needing to reorder. Without step 7 this read would have been
-- confidently wrong.
--
-- The suggestion is a read, not a row. It is computed from current numbers every
-- time it is asked for, so it cannot go stale, and nothing has to decide when to
-- invalidate it. Turning a suggestion into a purchase order is §31's next half
-- and belongs with the ordering flow, not here.

create table if not exists public.warehouse_products (
  warehouse_id bigint not null references public.warehouses (id) on delete cascade,
  product_id bigint not null,
  company_id bigint not null references public.companies (id),
  -- The put-away target. Nullable: most products do not have a fixed home.
  default_location_id bigint,
  min_stock integer,
  max_stock integer,
  reorder_point integer,
  -- Lower picks first. A number rather than a flag, because the real question on
  -- a pick list is ordering, not membership.
  pick_priority integer not null default 100,
  putaway_rule text not null default 'MANUAL',
  preferred_supplier_id bigint references public.delivery_suppliers (id),
  lead_time_days integer,
  note text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (warehouse_id, product_id),
  constraint warehouse_products_product_fk foreign key (company_id, product_id)
    references public.products (company_id, id) on delete cascade,
  -- Composite, so a warehouse cannot name a location belonging to another one.
  -- The column list on SET NULL matters: without it Postgres would null every
  -- referencing column when a location is deleted, and `warehouse_id` is part of
  -- the primary key — the delete would fail instead of clearing the setting.
  constraint warehouse_products_location_fk
    foreign key (warehouse_id, default_location_id)
    references public.locations (warehouse_id, id)
    on delete set null (default_location_id),
  constraint warehouse_products_levels_check check (
    coalesce(min_stock, 0) >= 0 and coalesce(max_stock, 0) >= 0
    and coalesce(reorder_point, 0) >= 0
    and (min_stock is null or max_stock is null or max_stock >= min_stock)
    and (reorder_point is null or max_stock is null or reorder_point <= max_stock)
    and (reorder_point is null or min_stock is null or reorder_point >= min_stock)),
  constraint warehouse_products_lead_time_check check (
    lead_time_days is null or lead_time_days >= 0),
  -- The rule records the *intent*. Acting on it — actually suggesting a bin — is
  -- Phase B's put-away suggestion, which needs the location tree's capacity and
  -- occupancy to do anything useful.
  constraint warehouse_products_putaway_rule_check check (
    putaway_rule in ('MANUAL', 'FIXED', 'CONSOLIDATE', 'NEAREST_EMPTY'))
);

create index if not exists warehouse_products_product_idx
  on public.warehouse_products (product_id);
create index if not exists warehouse_products_reorder_idx
  on public.warehouse_products (warehouse_id)
  where reorder_point is not null and is_active;

alter table public.warehouse_products enable row level security;

drop policy if exists "read warehouse products" on public.warehouse_products;
create policy "read warehouse products" on public.warehouse_products
  for select to authenticated
  using ((public.has_permission('inventory.view')
          or public.has_permission('product.view'))
         and public.can_access_warehouse(warehouse_id));

-- Returns one object when a product is named, an array when it is not. Both
-- carry the live stock numbers beside the settings, because "the reorder point
-- is 50" is only useful next to what is actually there. Defined before the
-- writer below, which answers with it.
create or replace function public.warehouse_product_settings(
  p_warehouse_id bigint,
  p_product_id bigint default null
) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_rows jsonb;
begin
  if not (public.has_permission('inventory.view')
          or public.has_permission('product.view')) then
    raise exception 'not permitted: inventory.view required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'warehouse_id', wp.warehouse_id,
           'product_id', wp.product_id,
           'jan_code', p.jan_code,
           'sku', p.sku,
           'product_name', p.name,
           'default_location_id', wp.default_location_id,
           'default_location_code', l.code,
           -- The bin behind the location, for the put-away RPCs that still work
           -- in bins. Null when the target is a rack or a zone.
           'default_bin_id', l.bin_id,
           'min_stock', wp.min_stock,
           'max_stock', wp.max_stock,
           'reorder_point', wp.reorder_point,
           'pick_priority', wp.pick_priority,
           'putaway_rule', wp.putaway_rule,
           'preferred_supplier_id', wp.preferred_supplier_id,
           'preferred_supplier_name', s.name,
           'lead_time_days', wp.lead_time_days,
           'note', wp.note,
           'is_active', wp.is_active,
           'on_hand', public.stock_on_hand(wp.product_id, wp.warehouse_id),
           'available', public.stock_available(wp.product_id, wp.warehouse_id))
         order by p.name), '[]'::jsonb)
    into v_rows
    from public.warehouse_products wp
    join public.products p on p.id = wp.product_id
    left join public.locations l on l.id = wp.default_location_id
    left join public.delivery_suppliers s on s.id = wp.preferred_supplier_id
   where wp.warehouse_id = p_warehouse_id
     and (p_product_id is null or wp.product_id = p_product_id);

  if p_product_id is not null then
    -- A named product gets the object itself, or null when it has no settings.
    -- Not an empty array: the caller asked about one product, and "no row" is an
    -- answer about that product rather than an empty list of them.
    return v_rows->0;
  end if;
  return v_rows;
end;
$$;

revoke all on function public.warehouse_product_settings(bigint, bigint)
  from public, anon;
grant execute on function public.warehouse_product_settings(bigint, bigint)
  to authenticated, service_role;

-- `set_warehouse_product` takes a location *code*, not an id: the operator
-- setting this up is reading the rack label, and the code is what is printed on
-- it. Passing an empty string clears the setting, which a null cannot do —
-- null means "leave this field alone" for every field here, so that one flag can
-- be changed without restating the row.
create or replace function public.set_warehouse_product(
  p_warehouse_id bigint,
  p_product_id bigint,
  p_default_location_code text default null,
  p_min_stock integer default null,
  p_max_stock integer default null,
  p_reorder_point integer default null,
  p_pick_priority integer default null,
  p_putaway_rule text default null,
  p_preferred_supplier_id bigint default null,
  p_lead_time_days integer default null,
  p_note text default null
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_company_id bigint;
  v_location_id bigint;
  v_clear_location boolean := p_default_location_code = '';
  v_rule text;
begin
  if not (public.has_permission('product.manage')
          or public.has_permission('warehouse.manage')) then
    raise exception 'not permitted: product.manage required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  select company_id into v_company_id from public.products where id = p_product_id;
  if v_company_id is null then
    raise exception 'product % not found', p_product_id;
  end if;

  if nullif(btrim(coalesce(p_default_location_code, '')), '') is not null then
    select id into v_location_id from public.locations
     where warehouse_id = p_warehouse_id
       and code = btrim(p_default_location_code);
    if v_location_id is null then
      raise exception 'location % not found in this warehouse',
        p_default_location_code;
    end if;
  end if;

  if nullif(btrim(coalesce(p_putaway_rule, '')), '') is not null then
    v_rule := upper(btrim(p_putaway_rule));
    if v_rule not in ('MANUAL', 'FIXED', 'CONSOLIDATE', 'NEAREST_EMPTY') then
      raise exception 'unknown putaway_rule %', p_putaway_rule;
    end if;
  end if;

  insert into public.warehouse_products as wp (
    warehouse_id, product_id, company_id, default_location_id,
    min_stock, max_stock, reorder_point, pick_priority, putaway_rule,
    preferred_supplier_id, lead_time_days, note)
  values (
    p_warehouse_id, p_product_id, v_company_id, v_location_id,
    p_min_stock, p_max_stock, p_reorder_point, coalesce(p_pick_priority, 100),
    coalesce(v_rule, 'MANUAL'), p_preferred_supplier_id, p_lead_time_days,
    nullif(btrim(coalesce(p_note, '')), ''))
  on conflict (warehouse_id, product_id) do update set
    default_location_id = case when v_clear_location then null
                          else coalesce(v_location_id, wp.default_location_id) end,
    min_stock = coalesce(p_min_stock, wp.min_stock),
    max_stock = coalesce(p_max_stock, wp.max_stock),
    reorder_point = coalesce(p_reorder_point, wp.reorder_point),
    pick_priority = coalesce(p_pick_priority, wp.pick_priority),
    putaway_rule = coalesce(v_rule, wp.putaway_rule),
    preferred_supplier_id = coalesce(p_preferred_supplier_id, wp.preferred_supplier_id),
    lead_time_days = coalesce(p_lead_time_days, wp.lead_time_days),
    note = coalesce(nullif(btrim(coalesce(p_note, '')), ''), wp.note),
    updated_at = now();

  perform public.log_audit('inventory.warehouse_product_set', 'product',
    p_product_id::text, p_warehouse_id,
    jsonb_build_object('default_location', p_default_location_code,
                       'min_stock', p_min_stock, 'max_stock', p_max_stock,
                       'reorder_point', p_reorder_point,
                       'putaway_rule', v_rule));

  return public.warehouse_product_settings(p_warehouse_id, p_product_id);
end;
$$;

revoke all on function public.set_warehouse_product(
  bigint, bigint, text, integer, integer, integer, integer, text, bigint,
  integer, text) from public, anon;
grant execute on function public.set_warehouse_product(
  bigint, bigint, text, integer, integer, integer, integer, text, bigint,
  integer, text) to authenticated, service_role;

create or replace function public.clear_warehouse_product(
  p_warehouse_id bigint,
  p_product_id bigint
) returns boolean
language plpgsql security definer set search_path = ''
as $$
begin
  if not (public.has_permission('product.manage')
          or public.has_permission('warehouse.manage')) then
    raise exception 'not permitted: product.manage required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  delete from public.warehouse_products
   where warehouse_id = p_warehouse_id and product_id = p_product_id;
  if not found then
    return false;
  end if;
  perform public.log_audit('inventory.warehouse_product_cleared', 'product',
    p_product_id::text, p_warehouse_id, '{}'::jsonb);
  return true;
end;
$$;

revoke all on function public.clear_warehouse_product(bigint, bigint)
  from public, anon;
grant execute on function public.clear_warehouse_product(bigint, bigint)
  to authenticated, service_role;

-- §31. Compared against `available`, not `on_hand`: quarantined or damaged stock
-- is on hand and cannot cover an order, so a warehouse holding 100 units of
-- which 90 are blocked does need to reorder. Ordering by how far under the line
-- each product is, because that is the order someone would work the list in.
create or replace function public.replenishment_suggestions(
  p_warehouse_id bigint default null
) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.has_permission('inventory.view') then
    raise exception 'not permitted: inventory.view required';
  end if;
  if p_warehouse_id is not null and not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  return coalesce((
    select jsonb_agg(row_to_json(t)::jsonb order by t.shortfall desc, t.product_name)
      from (
        select wp.warehouse_id,
               w.name as warehouse_name,
               wp.product_id,
               p.jan_code,
               p.sku,
               p.name as product_name,
               wp.reorder_point,
               wp.max_stock,
               wp.min_stock,
               public.stock_on_hand(wp.product_id, wp.warehouse_id) as on_hand,
               public.stock_available(wp.product_id, wp.warehouse_id) as available,
               wp.reorder_point
                 - public.stock_available(wp.product_id, wp.warehouse_id) as shortfall,
               -- Order up to max_stock when one is set, otherwise just back over
               -- the line. Ordering exactly to the reorder point would put the
               -- product straight back on this list.
               coalesce(wp.max_stock, wp.reorder_point)
                 - public.stock_available(wp.product_id, wp.warehouse_id)
                 as suggested_quantity,
               wp.preferred_supplier_id,
               s.name as preferred_supplier_name,
               wp.lead_time_days,
               (select u.code from public.uoms u where u.id = p.base_uom_id) as base_uom
          from public.warehouse_products wp
          join public.products p on p.id = wp.product_id
          join public.warehouses w on w.id = wp.warehouse_id
          left join public.delivery_suppliers s on s.id = wp.preferred_supplier_id
         where wp.is_active
           and wp.reorder_point is not null
           and (p_warehouse_id is null or wp.warehouse_id = p_warehouse_id)
           and public.can_access_warehouse(wp.warehouse_id)
           and p.status = 'active'
           and public.stock_available(wp.product_id, wp.warehouse_id) < wp.reorder_point
      ) t), '[]'::jsonb);
end;
$$;

revoke all on function public.replenishment_suggestions(bigint) from public, anon;
grant execute on function public.replenishment_suggestions(bigint)
  to authenticated, service_role;
