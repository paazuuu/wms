-- 0107 — supply chain profit & risk: the masters, the rules and the runs.
--
-- What it costs to get one of our products from a supplier to a customer —
-- not the purchase price alone but freight, insurance, duty, customs, port,
-- domestic delivery, storage, handling and labour — and what is left when it
-- sells. On top of that, "what if": another supplier, a different 掛率, sea
-- instead of air, dearer freight, a port closed for two weeks.
--
-- Nothing here touches stock or orders (rule 3). The calculation itself lives
-- in the `supply-chain` edge function (a pure, tested engine); this migration
-- holds what it reads and what it writes back:
--
--   masters   supply_chain_nodes / routes / route_edges / transport_modes,
--             supply_chain_supplier_products (our product from a supplier:
--             price, 掛率, currency, MOQ, lead time, default route),
--             supply_chain_product_profiles (sales price, volume, weight, HS…)
--   rules     supply_chain_cost_rules (warehouse, labour, packing, overhead…),
--             supply_chain_tariff_rules (duty and import tax, never hard-coded),
--             supply_chain_fx_rates, supply_chain_settings
--   risk      supply_chain_risk_events (known disruptions, price rises…)
--   runs      supply_chain_scenarios (saved what-ifs) and
--             supply_chain_scenario_results (every run kept as a snapshot)
--
-- Access: `supply_chain.view` reads and runs simulations, `supply_chain.manage`
-- edits masters and saves scenarios. Every write goes through a SECURITY
-- DEFINER RPC that checks the permission and writes the audit log.

-- ------------------------------------------------------------ permissions

insert into public.permissions (code, description) values
  ('supply_chain.view', 'See landed cost, profit, routes and risk; run simulations'),
  ('supply_chain.manage', 'Edit supply chain masters, cost rules and saved scenarios')
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
  from public.roles r, public.permissions p
 where (p.code = 'supply_chain.view'
        and r.code in ('system_admin', 'company_admin', 'warehouse_manager', 'purchasing', 'sales'))
    or (p.code = 'supply_chain.manage'
        and r.code in ('system_admin', 'company_admin', 'purchasing'))
on conflict do nothing;

create or replace function public.sc_can_view()
returns boolean language sql stable security definer set search_path = '' as $$
  select public.has_permission('supply_chain.view') or public.has_permission('supply_chain.manage');
$$;

create or replace function public.sc_can_manage()
returns boolean language sql stable security definer set search_path = '' as $$
  select public.has_permission('supply_chain.manage');
$$;

revoke all on function public.sc_can_view() from public, anon;
revoke all on function public.sc_can_manage() from public, anon;
grant execute on function public.sc_can_view() to authenticated, service_role;
grant execute on function public.sc_can_manage() to authenticated, service_role;

-- A few document dates are free text (2026-09-28, 2026/9/28): read them when
-- they look like dates, never fail on the rest.
create or replace function public.sc_try_date(p text)
returns date language plpgsql immutable set search_path = '' as $$
begin
  if p is null or p !~ '^\s*\d{4}[-/.]\d{1,2}[-/.]\d{1,2}' then return null; end if;
  return to_date(substring(p from '\d{4}[-/.]\d{1,2}[-/.]\d{1,2}'), 'YYYY-MM-DD');
exception when others then
  return null;
end;
$$;

-- ---------------------------------------------------------------- tables

create table if not exists public.supply_chain_settings (
  id smallint primary key default 1 check (id = 1),
  base_currency text not null default 'JPY',
  -- A purchase whose margin falls under this, or drops by more than the
  -- second, is warned about before it is placed (§30).
  margin_warn numeric not null default 0.15,
  margin_drop_warn numeric not null default 0.05,
  -- Loads over these are 混雑 / 超過 (§18).
  load_warn numeric not null default 0.8,
  load_exceeded numeric not null default 1.0,
  -- A lot is this many months of demand when no MOQ or lot says otherwise;
  -- per-shipment costs are spread over it.
  default_lot_months numeric not null default 1,
  updated_at timestamptz not null default now()
);
insert into public.supply_chain_settings (id) values (1) on conflict do nothing;

create table if not exists public.supply_chain_transport_modes (
  code text primary key,
  name_ja text not null,
  name_en text not null,
  sort smallint not null default 0
);
insert into public.supply_chain_transport_modes (code, name_ja, name_en, sort) values
  ('sea', '船便', 'Sea', 1),
  ('air', '航空便', 'Air', 2),
  ('truck', 'トラック', 'Truck', 3),
  ('rail', '鉄道', 'Rail', 4),
  ('courier', '宅配・クーリエ', 'Courier', 5),
  ('internal', '社内移動', 'Internal transfer', 6)
on conflict (code) do nothing;

create table if not exists public.supply_chain_nodes (
  id bigint generated always as identity primary key,
  code text not null unique,
  name text not null,
  kind text not null check (kind in
    ('supplier', 'port', 'airport', 'customs', 'warehouse', 'dc', 'customer', 'hub')),
  partner_id bigint references public.delivery_suppliers(id) on delete set null,
  warehouse_id bigint references public.warehouses(id) on delete set null,
  country_code text,
  capacity_units_month numeric check (capacity_units_month is null or capacity_units_month >= 0),
  capacity_kg_month numeric check (capacity_kg_month is null or capacity_kg_month >= 0),
  dwell_days numeric not null default 0 check (dwell_days >= 0),
  handling_cost_per_unit numeric not null default 0,
  handling_cost_per_shipment numeric not null default 0,
  risk_level text not null default 'low' check (risk_level in ('low', 'medium', 'high', 'critical')),
  risk_note text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists supply_chain_nodes_warehouse
  on public.supply_chain_nodes (warehouse_id) where kind = 'warehouse' and warehouse_id is not null;
create unique index if not exists supply_chain_nodes_supplier
  on public.supply_chain_nodes (partner_id) where kind = 'supplier' and partner_id is not null;

create table if not exists public.supply_chain_routes (
  id bigint generated always as identity primary key,
  code text not null unique,
  name text not null,
  origin_node_id bigint not null references public.supply_chain_nodes(id) on delete restrict,
  destination_node_id bigint not null references public.supply_chain_nodes(id) on delete restrict,
  note text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.supply_chain_route_edges (
  id bigint generated always as identity primary key,
  route_id bigint not null references public.supply_chain_routes(id) on delete cascade,
  seq smallint not null,
  from_node_id bigint not null references public.supply_chain_nodes(id) on delete restrict,
  to_node_id bigint not null references public.supply_chain_nodes(id) on delete restrict,
  transport_mode text not null references public.supply_chain_transport_modes(code),
  -- International legs are ocean/air freight; domestic ones are 国内配送.
  -- Null: decided by the two nodes' countries.
  leg_scope text check (leg_scope in ('international', 'domestic')),
  currency text,
  distance_km numeric,
  lead_time_days numeric not null default 0 check (lead_time_days >= 0),
  base_cost numeric not null default 0,           -- per shipment
  cost_per_kg numeric not null default 0,
  cost_per_unit numeric not null default 0,
  fuel_surcharge_rate numeric not null default 0, -- on the freight above
  insurance_rate numeric not null default 0,      -- on the goods' value
  capacity_kg_month numeric,
  capacity_units_month numeric,
  -- The leg where the goods clear import customs: duty and import tax are
  -- charged here, with this broker fee per shipment.
  customs_clearance boolean not null default false,
  customs_cost numeric not null default 0,        -- per shipment
  tariff_rate numeric,                            -- overrides the tariff rules
  handling_cost numeric not null default 0,       -- per shipment (port / airport)
  handling_cost_per_unit numeric not null default 0,
  risk_level text not null default 'low' check (risk_level in ('low', 'medium', 'high', 'critical')),
  note text,
  unique (route_id, seq)
);

create table if not exists public.supply_chain_supplier_products (
  id bigint generated always as identity primary key,
  partner_id bigint not null references public.delivery_suppliers(id) on delete cascade,
  product_id bigint not null references public.products(id) on delete cascade,
  supplier_sku text,
  list_price numeric check (list_price is null or list_price >= 0),     -- 定価 / 上代
  discount_rate numeric check (discount_rate is null or discount_rate between 0 and 2), -- 掛率 0.70
  unit_price numeric check (unit_price is null or unit_price >= 0),     -- 仕入単価 (wins over list×rate)
  currency text,                                                        -- null = base currency
  moq integer check (moq is null or moq > 0),
  order_lot integer check (order_lot is null or order_lot > 0),
  lead_time_days numeric check (lead_time_days is null or lead_time_days >= 0),
  payment_terms text,
  default_route_id bigint references public.supply_chain_routes(id) on delete set null,
  is_primary boolean not null default false,
  source text not null default 'manual' check (source in ('manual', 'purchase_order', 'document')),
  active boolean not null default true,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (partner_id, product_id)
);
create index if not exists supply_chain_supplier_products_product
  on public.supply_chain_supplier_products (product_id) where active;

create table if not exists public.supply_chain_product_profiles (
  product_id bigint primary key references public.products(id) on delete cascade,
  sales_price numeric check (sales_price is null or sales_price >= 0),  -- null: products.price
  annual_volume numeric check (annual_volume is null or annual_volume >= 0), -- null: last 12 months shipped
  unit_weight_kg numeric check (unit_weight_kg is null or unit_weight_kg >= 0),
  units_per_carton integer check (units_per_carton is null or units_per_carton > 0),
  units_per_line numeric check (units_per_line is null or units_per_line > 0),
  units_per_order numeric check (units_per_order is null or units_per_order > 0),
  storage_days numeric check (storage_days is null or storage_days >= 0),
  hs_code text,
  origin_country text,
  destination_country text,
  note text,
  updated_at timestamptz not null default now()
);

create table if not exists public.supply_chain_cost_rules (
  id bigint generated always as identity primary key,
  name text not null,
  category text not null check (category in (
    'storage', 'receiving', 'inspection', 'packing', 'picking', 'shipping', 'labor',
    'overhead', 'domestic_freight', 'sales_related', 'other')),
  basis text not null check (basis in (
    'per_unit', 'per_unit_month', 'per_carton', 'per_line', 'per_order', 'per_hour',
    'percent_of_revenue', 'percent_of_purchase', 'fixed_monthly')),
  -- ¥ per basis, or the rate for the percent bases (0.03 = 3%).
  amount numeric not null default 0,
  -- per_hour: units handled in one hour; per_carton / per_line / per_order:
  -- units in one (overrides the product profile); fixed_monthly: the monthly
  -- volume the cost is spread over (null: the warehouse's modelled volume).
  units_per_basis numeric check (units_per_basis is null or units_per_basis > 0),
  currency text,
  warehouse_id bigint references public.warehouses(id) on delete cascade,
  product_id bigint references public.products(id) on delete cascade,
  partner_id bigint references public.delivery_suppliers(id) on delete cascade,
  -- False: a cost that is recovered (deducted / refunded), shown but not
  -- counted in the landed cost.
  expensed boolean not null default true,
  effective_from date,
  effective_to date,
  active boolean not null default true,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.supply_chain_tariff_rules (
  id bigint generated always as identity primary key,
  name text,
  product_id bigint references public.products(id) on delete cascade,
  hs_code_prefix text,
  origin_country text,
  destination_country text,
  tariff_rate numeric not null default 0,
  -- Import consumption tax and the like. Recoverable ones (仕入税額控除)
  -- are shown but not counted as cost.
  import_tax_rate numeric not null default 0,
  import_tax_recoverable boolean not null default true,
  other_rate numeric not null default 0,
  valuation text not null default 'CIF' check (valuation in ('CIF', 'FOB')),
  active boolean not null default true,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.supply_chain_fx_rates (
  currency text primary key,
  rate_to_base numeric not null check (rate_to_base > 0),
  as_of date not null default current_date,
  note text,
  updated_at timestamptz not null default now()
);
insert into public.supply_chain_fx_rates (currency, rate_to_base, note)
values ('JPY', 1, 'base') on conflict do nothing;

create table if not exists public.supply_chain_risk_events (
  id bigint generated always as identity primary key,
  title text not null,
  kind text not null check (kind in (
    'supplier_stop', 'supplier_price', 'supplier_delay', 'route_stop', 'mode_stop',
    'port_stop', 'airport_stop', 'customs_delay', 'warehouse_capacity', 'warehouse_stop',
    'domestic_stop', 'staff_shortage', 'cost_spike')),
  severity text not null default 'medium' check (severity in ('low', 'medium', 'high', 'critical')),
  node_id bigint references public.supply_chain_nodes(id) on delete cascade,
  route_id bigint references public.supply_chain_routes(id) on delete cascade,
  partner_id bigint references public.delivery_suppliers(id) on delete cascade,
  transport_mode text references public.supply_chain_transport_modes(code),
  starts_on date,
  ends_on date,
  price_multiplier numeric,
  cost_multiplier numeric,
  capacity_multiplier numeric,
  delay_days numeric,
  active boolean not null default true,
  note text,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);

create table if not exists public.supply_chain_scenarios (
  id bigint generated always as identity primary key,
  name text not null,
  description text,
  warehouse_id bigint references public.warehouses(id) on delete set null,
  params jsonb not null default '{}'::jsonb,
  archived boolean not null default false,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.supply_chain_scenario_results (
  id bigint generated always as identity primary key,
  scenario_id bigint references public.supply_chain_scenarios(id) on delete set null,
  kind text not null check (kind in
    ('baseline', 'scenario', 'compare', 'disruption', 'product', 'purchase_check')),
  name text,
  warehouse_id bigint references public.warehouses(id) on delete set null,
  params jsonb not null default '{}'::jsonb,
  summary jsonb not null default '{}'::jsonb,
  result jsonb not null default '{}'::jsonb,
  revenue numeric,
  landed_cost numeric,
  profit numeric,
  margin numeric,
  baseline_profit numeric,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);
create index if not exists supply_chain_scenario_results_recent
  on public.supply_chain_scenario_results (created_at desc);

-- Reads are for those who may see the numbers; writes only through the RPCs.
do $$
declare t text;
begin
  foreach t in array array[
    'supply_chain_settings', 'supply_chain_transport_modes', 'supply_chain_nodes',
    'supply_chain_routes', 'supply_chain_route_edges', 'supply_chain_supplier_products',
    'supply_chain_product_profiles', 'supply_chain_cost_rules', 'supply_chain_tariff_rules',
    'supply_chain_fx_rates', 'supply_chain_risk_events', 'supply_chain_scenarios',
    'supply_chain_scenario_results']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "%s: supply_chain.view" on public.%I', t, t);
    execute format('create policy "%s: supply_chain.view" on public.%I for select to authenticated using (public.sc_can_view())', t, t);
  end loop;
end $$;

-- ------------------------------------------------------------ helpers

create or replace function public.sc_require_view()
returns void language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.sc_can_view() then
    raise exception 'not permitted: supply_chain.view required';
  end if;
end;
$$;

create or replace function public.sc_require_manage()
returns void language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.sc_can_manage() then
    raise exception 'not permitted: supply_chain.manage required';
  end if;
end;
$$;

-- Nodes for what already exists: one per warehouse, one per supplier that has
-- a supply term. Idempotent.
create or replace function public.sc_sync_nodes_impl()
returns integer language plpgsql security definer set search_path = '' as $$
declare v_n integer := 0; v_add integer;
begin
  insert into public.supply_chain_nodes (code, name, kind, warehouse_id, country_code)
  select 'WH-' || coalesce(w.code, w.id::text), w.name, 'warehouse', w.id, w.country_code
    from public.warehouses w
   where not exists (select 1 from public.supply_chain_nodes n
                      where n.kind = 'warehouse' and n.warehouse_id = w.id)
     and not exists (select 1 from public.supply_chain_nodes n
                      where n.code = 'WH-' || coalesce(w.code, w.id::text));
  get diagnostics v_add = row_count; v_n := v_n + v_add;

  insert into public.supply_chain_nodes (code, name, kind, partner_id, country_code)
  select 'SUP-' || coalesce(d.code, d.id::text), d.name, 'supplier', d.id, d.country_code
    from public.delivery_suppliers d
   where exists (select 1 from public.supply_chain_supplier_products sp where sp.partner_id = d.id)
     and not exists (select 1 from public.supply_chain_nodes n
                      where n.kind = 'supplier' and n.partner_id = d.id)
     and not exists (select 1 from public.supply_chain_nodes n
                      where n.code = 'SUP-' || coalesce(d.code, d.id::text));
  get diagnostics v_add = row_count; v_n := v_n + v_add;
  return v_n;
end;
$$;
revoke all on function public.sc_sync_nodes_impl() from public, anon, authenticated;

-- Supply terms from what was actually bought: the latest price each supplier
-- charged for each product on a purchase order, or on its delivery note /
-- invoice as read by the document reader. Terms already there are kept.
create or replace function public.sc_seed_from_history()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_po integer; v_doc integer; v_nodes integer;
begin
  perform public.sc_require_manage();

  insert into public.supply_chain_supplier_products (partner_id, product_id, unit_price, source)
  select distinct on (po.supplier_id, pl.product_id)
         po.supplier_id, pl.product_id, pl.unit_price, 'purchase_order'
    from public.purchase_order_lines pl
    join public.purchase_orders po on po.id = pl.purchase_order_id
   where po.supplier_id is not null and pl.product_id is not null
     and pl.unit_price is not null and po.status not in ('CANCELLED', 'REJECTED')
   order by po.supplier_id, pl.product_id, po.created_at desc
  on conflict (partner_id, product_id) do nothing;
  get diagnostics v_po = row_count;

  insert into public.supply_chain_supplier_products (partner_id, product_id, unit_price, source)
  select distinct on (dp.supplier_id, l.product_id)
         dp.supplier_id, l.product_id, l.unit_price, 'document'
    from public.delivery_plan_lines l
    join public.delivery_plans dp on dp.id = l.delivery_plan_id
   where dp.supplier_id is not null and l.product_id is not null and l.unit_price is not null
   order by dp.supplier_id, l.product_id, dp.created_at desc
  on conflict (partner_id, product_id) do nothing;
  get diagnostics v_doc = row_count;

  -- One primary per product where none is set: the first supplier found.
  update public.supply_chain_supplier_products sp set is_primary = true
   where sp.id in (select distinct on (product_id) id from public.supply_chain_supplier_products
                    where active order by product_id, id)
     and not exists (select 1 from public.supply_chain_supplier_products o
                      where o.product_id = sp.product_id and o.is_primary);

  v_nodes := public.sc_sync_nodes_impl();
  perform public.log_audit('supply_chain.seed', 'supply_chain', null, null,
    jsonb_build_object('from_purchase_orders', v_po, 'from_documents', v_doc, 'nodes', v_nodes));
  return jsonb_build_object('from_purchase_orders', v_po, 'from_documents', v_doc, 'nodes', v_nodes);
end;
$$;

-- ------------------------------------------------------------ the model

-- Everything the engine needs, in one read, scoped to what the caller may see.
-- p_warehouse_id narrows stock and history to one warehouse; p_product_ids to
-- some products (null: every product that has a supply term).
create or replace function public.sc_model(
  p_warehouse_id bigint default null,
  p_product_ids bigint[] default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_products bigint[];
  v jsonb;
begin
  perform public.sc_require_view();
  if p_warehouse_id is not null and not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  select coalesce(array_agg(distinct x), '{}') into v_products from (
    select unnest(p_product_ids) x
    union
    select sp.product_id from public.supply_chain_supplier_products sp
     where sp.active and p_product_ids is null) q;

  select jsonb_build_object(
    'as_of', current_date,
    'warehouse_id', p_warehouse_id,
    'settings', (select to_jsonb(s) - 'id' from public.supply_chain_settings s where s.id = 1),
    'modes', coalesce((select jsonb_agg(to_jsonb(m) order by m.sort) from public.supply_chain_transport_modes m), '[]'),
    'fx', coalesce((select jsonb_object_agg(f.currency, f.rate_to_base) from public.supply_chain_fx_rates f), '{}'),
    'nodes', coalesce((select jsonb_agg(to_jsonb(n) order by n.id) from public.supply_chain_nodes n where n.active), '[]'),
    'routes', coalesce((
      select jsonb_agg(to_jsonb(r) || jsonb_build_object('edges', coalesce((
               select jsonb_agg(to_jsonb(e) order by e.seq)
                 from public.supply_chain_route_edges e where e.route_id = r.id), '[]'))
             order by r.id)
        from public.supply_chain_routes r where r.active), '[]'),
    'partners', coalesce((
      select jsonb_agg(jsonb_build_object('id', d.id, 'name', d.name, 'code', d.code,
                                          'country_code', d.country_code))
        from public.delivery_suppliers d
       where d.id in (select sp.partner_id from public.supply_chain_supplier_products sp)), '[]'),
    'supplier_products', coalesce((
      select jsonb_agg(to_jsonb(sp) order by sp.product_id, sp.id)
        from public.supply_chain_supplier_products sp
       where sp.active and sp.product_id = any(v_products)), '[]'),
    'products', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', p.id, 'jan_code', p.jan_code, 'name', p.name, 'sku', p.sku,
               'maker', p.maker, 'price', p.price, 'category', p.category,
               'profile', (select to_jsonb(pp) - 'product_id' from public.supply_chain_product_profiles pp
                            where pp.product_id = p.id),
               'on_hand', coalesce((select sum(sl.on_hand) from public.stock_levels sl
                                     where sl.product_id = p.id
                                       and (p_warehouse_id is null or sl.warehouse_id = p_warehouse_id)
                                       and public.can_access_warehouse(sl.warehouse_id)), 0),
               'shipped_12m', coalesce((select sum(l.quantity) from public.shipment_lines l
                                          join public.shipment_plans s on s.id = l.shipment_plan_id
                                         where l.product_id = p.id and s.shipped_at >= now() - interval '365 days'
                                           and (p_warehouse_id is null or s.warehouse_id = p_warehouse_id)
                                           and (s.warehouse_id is null or public.can_access_warehouse(s.warehouse_id))), 0),
               'sold_price_avg', (select round(sum(l.unit_price::numeric * l.quantity) / nullif(sum(l.quantity), 0), 2)
                                    from public.shipment_lines l
                                    join public.shipment_plans s on s.id = l.shipment_plan_id
                                   where l.product_id = p.id and l.unit_price is not null
                                     and s.shipped_at >= now() - interval '365 days')
             ) order by p.id)
        from public.products p where p.id = any(v_products)), '[]'),
    'cost_rules', coalesce((
      select jsonb_agg(to_jsonb(c) order by c.id) from public.supply_chain_cost_rules c
       where c.active
         and (c.effective_from is null or c.effective_from <= current_date)
         and (c.effective_to is null or c.effective_to >= current_date)), '[]'),
    'tariff_rules', coalesce((
      select jsonb_agg(to_jsonb(t) order by t.id) from public.supply_chain_tariff_rules t where t.active), '[]'),
    'risk_events', coalesce((
      select jsonb_agg(to_jsonb(r) order by r.id) from public.supply_chain_risk_events r
       where r.active and (r.ends_on is null or r.ends_on >= current_date)), '[]')
  ) into v;
  return v;
end;
$$;

-- ------------------------------------------------------------ settings

create or replace function public.sc_set_settings(p jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v jsonb;
begin
  perform public.sc_require_manage();
  update public.supply_chain_settings s set
    base_currency = coalesce(nullif(btrim(p->>'base_currency'), ''), s.base_currency),
    margin_warn = coalesce((p->>'margin_warn')::numeric, s.margin_warn),
    margin_drop_warn = coalesce((p->>'margin_drop_warn')::numeric, s.margin_drop_warn),
    load_warn = coalesce((p->>'load_warn')::numeric, s.load_warn),
    load_exceeded = coalesce((p->>'load_exceeded')::numeric, s.load_exceeded),
    default_lot_months = coalesce((p->>'default_lot_months')::numeric, s.default_lot_months),
    updated_at = now()
   where s.id = 1
  returning to_jsonb(s) - 'id' into v;
  perform public.log_audit('supply_chain.settings', 'supply_chain_settings', '1', null, v);
  return v;
end;
$$;

-- ------------------------------------------------------------ master writes
--
-- Each takes the row as jsonb (id present: update; absent: insert) and
-- returns its id, so the screens can grow fields without new signatures.

create or replace function public.sc_num(p jsonb, k text)
returns numeric language sql immutable set search_path = '' as $$
  select case when p ? k and jsonb_typeof(p->k) in ('number', 'string') and nullif(btrim(p->>k), '') is not null
              then (p->>k)::numeric end;
$$;

create or replace function public.sc_txt(p jsonb, k text)
returns text language sql immutable set search_path = '' as $$
  select nullif(btrim(p->>k), '');
$$;

create or replace function public.sc_save_node(p jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_id bigint := (p->>'id')::bigint;
begin
  perform public.sc_require_manage();
  if public.sc_txt(p, 'name') is null then raise exception 'name is required'; end if;
  if v_id is null then
    insert into public.supply_chain_nodes (code, name, kind, partner_id, warehouse_id, country_code,
      capacity_units_month, capacity_kg_month, dwell_days, handling_cost_per_unit,
      handling_cost_per_shipment, risk_level, risk_note)
    values (coalesce(public.sc_txt(p, 'code'), 'N-' || substr(md5(random()::text), 1, 8)),
      public.sc_txt(p, 'name'), coalesce(public.sc_txt(p, 'kind'), 'hub'),
      (p->>'partner_id')::bigint, (p->>'warehouse_id')::bigint, upper(public.sc_txt(p, 'country_code')),
      public.sc_num(p, 'capacity_units_month'), public.sc_num(p, 'capacity_kg_month'),
      coalesce(public.sc_num(p, 'dwell_days'), 0), coalesce(public.sc_num(p, 'handling_cost_per_unit'), 0),
      coalesce(public.sc_num(p, 'handling_cost_per_shipment'), 0),
      coalesce(public.sc_txt(p, 'risk_level'), 'low'), public.sc_txt(p, 'risk_note'))
    returning id into v_id;
  else
    update public.supply_chain_nodes set
      code = coalesce(public.sc_txt(p, 'code'), code), name = public.sc_txt(p, 'name'),
      kind = coalesce(public.sc_txt(p, 'kind'), kind),
      partner_id = (p->>'partner_id')::bigint, warehouse_id = (p->>'warehouse_id')::bigint,
      country_code = upper(public.sc_txt(p, 'country_code')),
      capacity_units_month = public.sc_num(p, 'capacity_units_month'),
      capacity_kg_month = public.sc_num(p, 'capacity_kg_month'),
      dwell_days = coalesce(public.sc_num(p, 'dwell_days'), 0),
      handling_cost_per_unit = coalesce(public.sc_num(p, 'handling_cost_per_unit'), 0),
      handling_cost_per_shipment = coalesce(public.sc_num(p, 'handling_cost_per_shipment'), 0),
      risk_level = coalesce(public.sc_txt(p, 'risk_level'), risk_level),
      risk_note = public.sc_txt(p, 'risk_note'),
      active = coalesce((p->>'active')::boolean, active),
      updated_at = now()
     where id = v_id;
    if not found then raise exception 'node % not found', v_id; end if;
  end if;
  perform public.log_audit('supply_chain.node_saved', 'supply_chain_node', v_id::text, null, p);
  return v_id;
end;
$$;

-- A route and its legs, in order. The legs are replaced as a whole.
create or replace function public.sc_save_route(p jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint := (p->>'id')::bigint;
  v_edges jsonb := coalesce(p->'edges', '[]'::jsonb);
  v_origin bigint; v_dest bigint;
  e jsonb; i integer := 0; v_prev bigint;
begin
  perform public.sc_require_manage();
  if public.sc_txt(p, 'name') is null then raise exception 'name is required'; end if;
  if jsonb_array_length(v_edges) = 0 then raise exception 'a route needs at least one leg'; end if;
  v_origin := (v_edges->0->>'from_node_id')::bigint;
  v_dest := (v_edges->(jsonb_array_length(v_edges) - 1)->>'to_node_id')::bigint;
  -- The legs must join up: each starts where the last one ended.
  for e in select * from jsonb_array_elements(v_edges) loop
    if v_prev is not null and (e->>'from_node_id')::bigint <> v_prev then
      raise exception 'leg % does not start where leg % ends', i + 1, i;
    end if;
    v_prev := (e->>'to_node_id')::bigint;
    i := i + 1;
  end loop;

  if v_id is null then
    insert into public.supply_chain_routes (code, name, origin_node_id, destination_node_id, note)
    values (coalesce(public.sc_txt(p, 'code'), 'R-' || substr(md5(random()::text), 1, 8)),
            public.sc_txt(p, 'name'), v_origin, v_dest, public.sc_txt(p, 'note'))
    returning id into v_id;
  else
    update public.supply_chain_routes set
      code = coalesce(public.sc_txt(p, 'code'), code), name = public.sc_txt(p, 'name'),
      origin_node_id = v_origin, destination_node_id = v_dest, note = public.sc_txt(p, 'note'),
      active = coalesce((p->>'active')::boolean, active), updated_at = now()
     where id = v_id;
    if not found then raise exception 'route % not found', v_id; end if;
    delete from public.supply_chain_route_edges where route_id = v_id;
  end if;

  i := 0;
  for e in select * from jsonb_array_elements(v_edges) loop
    i := i + 1;
    insert into public.supply_chain_route_edges (route_id, seq, from_node_id, to_node_id,
      transport_mode, leg_scope, currency, distance_km, lead_time_days, base_cost, cost_per_kg,
      cost_per_unit, fuel_surcharge_rate, insurance_rate, capacity_kg_month, capacity_units_month,
      customs_clearance, customs_cost, tariff_rate, handling_cost, handling_cost_per_unit,
      risk_level, note)
    values (v_id, i, (e->>'from_node_id')::bigint, (e->>'to_node_id')::bigint,
      coalesce(public.sc_txt(e, 'transport_mode'), 'truck'), public.sc_txt(e, 'leg_scope'),
      upper(public.sc_txt(e, 'currency')), public.sc_num(e, 'distance_km'),
      coalesce(public.sc_num(e, 'lead_time_days'), 0), coalesce(public.sc_num(e, 'base_cost'), 0),
      coalesce(public.sc_num(e, 'cost_per_kg'), 0), coalesce(public.sc_num(e, 'cost_per_unit'), 0),
      coalesce(public.sc_num(e, 'fuel_surcharge_rate'), 0), coalesce(public.sc_num(e, 'insurance_rate'), 0),
      public.sc_num(e, 'capacity_kg_month'), public.sc_num(e, 'capacity_units_month'),
      coalesce((e->>'customs_clearance')::boolean, false), coalesce(public.sc_num(e, 'customs_cost'), 0),
      public.sc_num(e, 'tariff_rate'), coalesce(public.sc_num(e, 'handling_cost'), 0),
      coalesce(public.sc_num(e, 'handling_cost_per_unit'), 0),
      coalesce(public.sc_txt(e, 'risk_level'), 'low'), public.sc_txt(e, 'note'));
  end loop;

  perform public.log_audit('supply_chain.route_saved', 'supply_chain_route', v_id::text, null, p);
  return v_id;
end;
$$;

create or replace function public.sc_save_supplier_product(p jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint := (p->>'id')::bigint;
  v_partner bigint := (p->>'partner_id')::bigint;
  v_product bigint := (p->>'product_id')::bigint;
begin
  perform public.sc_require_manage();
  if v_id is null and (v_partner is null or v_product is null) then
    raise exception 'partner_id and product_id are required';
  end if;
  if v_id is null then
    insert into public.supply_chain_supplier_products (partner_id, product_id) values (v_partner, v_product)
    on conflict (partner_id, product_id) do update set active = true
    returning id into v_id;
  end if;
  update public.supply_chain_supplier_products set
    supplier_sku = public.sc_txt(p, 'supplier_sku'),
    list_price = public.sc_num(p, 'list_price'),
    discount_rate = public.sc_num(p, 'discount_rate'),
    unit_price = public.sc_num(p, 'unit_price'),
    currency = upper(public.sc_txt(p, 'currency')),
    moq = public.sc_num(p, 'moq')::integer,
    order_lot = public.sc_num(p, 'order_lot')::integer,
    lead_time_days = public.sc_num(p, 'lead_time_days'),
    payment_terms = public.sc_txt(p, 'payment_terms'),
    default_route_id = (p->>'default_route_id')::bigint,
    is_primary = coalesce((p->>'is_primary')::boolean, is_primary),
    active = coalesce((p->>'active')::boolean, active),
    note = public.sc_txt(p, 'note'),
    source = case when source = 'manual' then source else 'manual' end,
    updated_at = now()
   where id = v_id
  returning product_id into v_product;
  if v_product is null then raise exception 'supply term % not found', v_id; end if;
  -- One primary supplier per product.
  if coalesce((p->>'is_primary')::boolean, false) then
    update public.supply_chain_supplier_products set is_primary = false
     where product_id = v_product and id <> v_id and is_primary;
  end if;
  perform public.sc_sync_nodes_impl();
  perform public.log_audit('supply_chain.supply_term_saved', 'supply_chain_supplier_product', v_id::text, null, p);
  return v_id;
end;
$$;

create or replace function public.sc_save_product_profile(p jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_product bigint := (p->>'product_id')::bigint;
begin
  perform public.sc_require_manage();
  if v_product is null then raise exception 'product_id is required'; end if;
  insert into public.supply_chain_product_profiles (product_id) values (v_product)
  on conflict (product_id) do nothing;
  update public.supply_chain_product_profiles set
    sales_price = public.sc_num(p, 'sales_price'),
    annual_volume = public.sc_num(p, 'annual_volume'),
    unit_weight_kg = public.sc_num(p, 'unit_weight_kg'),
    units_per_carton = public.sc_num(p, 'units_per_carton')::integer,
    units_per_line = public.sc_num(p, 'units_per_line'),
    units_per_order = public.sc_num(p, 'units_per_order'),
    storage_days = public.sc_num(p, 'storage_days'),
    hs_code = public.sc_txt(p, 'hs_code'),
    origin_country = upper(public.sc_txt(p, 'origin_country')),
    destination_country = upper(public.sc_txt(p, 'destination_country')),
    note = public.sc_txt(p, 'note'),
    updated_at = now()
   where product_id = v_product;
  perform public.log_audit('supply_chain.profile_saved', 'product', v_product::text, null, p);
  return v_product;
end;
$$;

create or replace function public.sc_save_cost_rule(p jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_id bigint := (p->>'id')::bigint;
begin
  perform public.sc_require_manage();
  if public.sc_txt(p, 'name') is null then raise exception 'name is required'; end if;
  if v_id is null then
    insert into public.supply_chain_cost_rules (name, category, basis)
    values (public.sc_txt(p, 'name'), coalesce(public.sc_txt(p, 'category'), 'other'),
            coalesce(public.sc_txt(p, 'basis'), 'per_unit'))
    returning id into v_id;
  end if;
  update public.supply_chain_cost_rules set
    name = public.sc_txt(p, 'name'),
    category = coalesce(public.sc_txt(p, 'category'), category),
    basis = coalesce(public.sc_txt(p, 'basis'), basis),
    amount = coalesce(public.sc_num(p, 'amount'), 0),
    units_per_basis = public.sc_num(p, 'units_per_basis'),
    currency = upper(public.sc_txt(p, 'currency')),
    warehouse_id = (p->>'warehouse_id')::bigint,
    product_id = (p->>'product_id')::bigint,
    partner_id = (p->>'partner_id')::bigint,
    expensed = coalesce((p->>'expensed')::boolean, true),
    effective_from = (p->>'effective_from')::date,
    effective_to = (p->>'effective_to')::date,
    active = coalesce((p->>'active')::boolean, active),
    note = public.sc_txt(p, 'note'),
    updated_at = now()
   where id = v_id;
  if not found then raise exception 'cost rule % not found', v_id; end if;
  perform public.log_audit('supply_chain.cost_rule_saved', 'supply_chain_cost_rule', v_id::text, null, p);
  return v_id;
end;
$$;

create or replace function public.sc_save_tariff_rule(p jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_id bigint := (p->>'id')::bigint;
begin
  perform public.sc_require_manage();
  if v_id is null then
    insert into public.supply_chain_tariff_rules (name) values (public.sc_txt(p, 'name'))
    returning id into v_id;
  end if;
  update public.supply_chain_tariff_rules set
    name = public.sc_txt(p, 'name'),
    product_id = (p->>'product_id')::bigint,
    hs_code_prefix = public.sc_txt(p, 'hs_code_prefix'),
    origin_country = upper(public.sc_txt(p, 'origin_country')),
    destination_country = upper(public.sc_txt(p, 'destination_country')),
    tariff_rate = coalesce(public.sc_num(p, 'tariff_rate'), 0),
    import_tax_rate = coalesce(public.sc_num(p, 'import_tax_rate'), 0),
    import_tax_recoverable = coalesce((p->>'import_tax_recoverable')::boolean, true),
    other_rate = coalesce(public.sc_num(p, 'other_rate'), 0),
    valuation = coalesce(public.sc_txt(p, 'valuation'), 'CIF'),
    active = coalesce((p->>'active')::boolean, active),
    note = public.sc_txt(p, 'note'),
    updated_at = now()
   where id = v_id;
  if not found then raise exception 'tariff rule % not found', v_id; end if;
  perform public.log_audit('supply_chain.tariff_rule_saved', 'supply_chain_tariff_rule', v_id::text, null, p);
  return v_id;
end;
$$;

create or replace function public.sc_save_fx_rate(p_currency text, p_rate numeric, p_as_of date default null, p_note text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare v_cur text := upper(btrim(p_currency));
begin
  perform public.sc_require_manage();
  if v_cur is null or v_cur = '' then raise exception 'currency is required'; end if;
  if p_rate is null or p_rate <= 0 then raise exception 'rate must be positive'; end if;
  insert into public.supply_chain_fx_rates (currency, rate_to_base, as_of, note)
  values (v_cur, p_rate, coalesce(p_as_of, current_date), p_note)
  on conflict (currency) do update set rate_to_base = excluded.rate_to_base,
    as_of = excluded.as_of, note = excluded.note, updated_at = now();
  perform public.log_audit('supply_chain.fx_saved', 'supply_chain_fx_rate', v_cur, null,
    jsonb_build_object('rate', p_rate, 'as_of', p_as_of));
end;
$$;

create or replace function public.sc_save_risk_event(p jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_id bigint := (p->>'id')::bigint;
begin
  perform public.sc_require_manage();
  if public.sc_txt(p, 'title') is null then raise exception 'title is required'; end if;
  if v_id is null then
    insert into public.supply_chain_risk_events (title, kind)
    values (public.sc_txt(p, 'title'), coalesce(public.sc_txt(p, 'kind'), 'cost_spike'))
    returning id into v_id;
  end if;
  update public.supply_chain_risk_events set
    title = public.sc_txt(p, 'title'),
    kind = coalesce(public.sc_txt(p, 'kind'), kind),
    severity = coalesce(public.sc_txt(p, 'severity'), severity),
    node_id = (p->>'node_id')::bigint,
    route_id = (p->>'route_id')::bigint,
    partner_id = (p->>'partner_id')::bigint,
    transport_mode = public.sc_txt(p, 'transport_mode'),
    starts_on = (p->>'starts_on')::date,
    ends_on = (p->>'ends_on')::date,
    price_multiplier = public.sc_num(p, 'price_multiplier'),
    cost_multiplier = public.sc_num(p, 'cost_multiplier'),
    capacity_multiplier = public.sc_num(p, 'capacity_multiplier'),
    delay_days = public.sc_num(p, 'delay_days'),
    active = coalesce((p->>'active')::boolean, active),
    note = public.sc_txt(p, 'note')
   where id = v_id;
  if not found then raise exception 'risk event % not found', v_id; end if;
  perform public.log_audit('supply_chain.risk_event_saved', 'supply_chain_risk_event', v_id::text, null, p);
  return v_id;
end;
$$;

-- Masters are retired, not deleted, so past runs still read.
create or replace function public.sc_archive(p_kind text, p_id bigint)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform public.sc_require_manage();
  case p_kind
    when 'node' then update public.supply_chain_nodes set active = false, updated_at = now() where id = p_id;
    when 'route' then update public.supply_chain_routes set active = false, updated_at = now() where id = p_id;
    when 'supplier_product' then update public.supply_chain_supplier_products set active = false, is_primary = false, updated_at = now() where id = p_id;
    when 'cost_rule' then update public.supply_chain_cost_rules set active = false, updated_at = now() where id = p_id;
    when 'tariff_rule' then update public.supply_chain_tariff_rules set active = false, updated_at = now() where id = p_id;
    when 'risk_event' then update public.supply_chain_risk_events set active = false where id = p_id;
    when 'scenario' then update public.supply_chain_scenarios set archived = true, updated_at = now() where id = p_id;
    else raise exception 'unknown kind %', p_kind;
  end case;
  if not found then raise exception '% % not found', p_kind, p_id; end if;
  perform public.log_audit('supply_chain.archived', 'supply_chain_' || p_kind, p_id::text, null, null);
end;
$$;

-- ------------------------------------------------------------ scenarios & runs

create or replace function public.sc_save_scenario(
  p_id bigint, p_name text, p_description text, p_warehouse_id bigint, p_params jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_id bigint := p_id;
begin
  perform public.sc_require_manage();
  if nullif(btrim(p_name), '') is null then raise exception 'name is required'; end if;
  if v_id is null then
    insert into public.supply_chain_scenarios (name, description, warehouse_id, params)
    values (btrim(p_name), p_description, p_warehouse_id, coalesce(p_params, '{}'))
    returning id into v_id;
  else
    update public.supply_chain_scenarios set name = btrim(p_name), description = p_description,
      warehouse_id = p_warehouse_id, params = coalesce(p_params, '{}'), updated_at = now()
     where id = v_id;
    if not found then raise exception 'scenario % not found', v_id; end if;
  end if;
  perform public.log_audit('supply_chain.scenario_saved', 'supply_chain_scenario', v_id::text, null,
    jsonb_build_object('name', p_name, 'params', p_params));
  return v_id;
end;
$$;

create or replace function public.sc_list_scenarios()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.sc_require_view();
  return coalesce((
    select jsonb_agg(to_jsonb(s) || jsonb_build_object(
             'last_run', (select jsonb_build_object('id', r.id, 'profit', r.profit, 'margin', r.margin,
                                                    'baseline_profit', r.baseline_profit, 'created_at', r.created_at)
                            from public.supply_chain_scenario_results r
                           where r.scenario_id = s.id order by r.created_at desc limit 1))
           order by s.updated_at desc)
      from public.supply_chain_scenarios s where not s.archived), '[]');
end;
$$;

-- Every run is kept as a snapshot (rule 4). Running is a read, so it needs
-- only supply_chain.view.
create or replace function public.sc_record_result(
  p_kind text, p_scenario_id bigint, p_name text, p_warehouse_id bigint,
  p_params jsonb, p_summary jsonb, p_result jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_id bigint;
begin
  perform public.sc_require_view();
  insert into public.supply_chain_scenario_results (scenario_id, kind, name, warehouse_id, params,
    summary, result, revenue, landed_cost, profit, margin, baseline_profit)
  values (p_scenario_id, p_kind, p_name, p_warehouse_id, coalesce(p_params, '{}'),
    coalesce(p_summary, '{}'), coalesce(p_result, '{}'),
    public.sc_num(p_summary, 'revenue'), public.sc_num(p_summary, 'landed_cost'),
    public.sc_num(p_summary, 'profit'), public.sc_num(p_summary, 'margin'),
    public.sc_num(p_summary, 'baseline_profit'))
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.sc_list_results(p_limit integer default 50, p_kind text default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.sc_require_view();
  return coalesce((
    select jsonb_agg(to_jsonb(r) - 'result' || jsonb_build_object(
             'scenario_name', (select s.name from public.supply_chain_scenarios s where s.id = r.scenario_id),
             'created_by_name', (select u.name from public.app_users u where u.id = r.created_by))
           order by r.created_at desc)
      from (select * from public.supply_chain_scenario_results
             where (p_kind is null or kind = p_kind)
             order by created_at desc limit greatest(1, least(coalesce(p_limit, 50), 200))) r), '[]');
end;
$$;

create or replace function public.sc_result(p_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v jsonb;
begin
  perform public.sc_require_view();
  select to_jsonb(r) into v from public.supply_chain_scenario_results r where r.id = p_id;
  if v is null then raise exception 'result % not found', p_id; end if;
  return v;
end;
$$;

-- ------------------------------------------------------------ supplier record

-- What each supplier has actually been like (§28): prices paid, lead time
-- and lateness from its delivery notes against the purchase order, damage
-- from inspections, and how many of its products have another supplier.
create or replace function public.sc_supplier_stats(p_partner_id bigint default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.sc_require_view();
  return coalesce((
    select jsonb_agg(row order by row->>'name')
      from (
        select jsonb_build_object(
          'partner_id', d.id, 'name', d.name, 'country_code', d.country_code,
          'products', (select count(*) from public.supply_chain_supplier_products sp
                        where sp.partner_id = d.id and sp.active),
          'sole_source_products', (select count(*) from public.supply_chain_supplier_products sp
                        where sp.partner_id = d.id and sp.active
                          and not exists (select 1 from public.supply_chain_supplier_products o
                                           where o.product_id = sp.product_id and o.active and o.partner_id <> d.id)),
          'purchase_orders', (select count(*) from public.purchase_orders po where po.supplier_id = d.id),
          'purchased_amount', (select coalesce(sum(pl.quantity * pl.unit_price), 0)
                                 from public.purchase_order_lines pl
                                 join public.purchase_orders po on po.id = pl.purchase_order_id
                                where po.supplier_id = d.id and pl.unit_price is not null),
          'avg_lead_time_days', (select round(avg(public.sc_try_date(dp.delivery_date) - po.order_date), 1)
                                   from public.delivery_plans dp
                                   join public.purchase_orders po on po.id = dp.purchase_order_id
                                  where po.supplier_id = d.id and po.order_date is not null
                                    and public.sc_try_date(dp.delivery_date) is not null),
          'late_rate', (select round(avg(case when public.sc_try_date(dp.delivery_date) > po.expected_date then 1.0 else 0 end), 4)
                          from public.delivery_plans dp
                          join public.purchase_orders po on po.id = dp.purchase_order_id
                         where po.supplier_id = d.id and po.expected_date is not null
                           and public.sc_try_date(dp.delivery_date) is not null),
          'defect_rate', (select round(sum(coalesce(ii.failed_quantity, 0))::numeric
                                        / nullif(sum(coalesce(ii.passed_quantity, 0) + coalesce(ii.failed_quantity, 0)), 0), 4)
                            from public.inspection_items ii
                            join public.inspections i on i.id = ii.inspection_id
                            join public.delivery_plans dp on dp.id = i.delivery_plan_id
                           where dp.supplier_id = d.id),
          'inspected_units', (select coalesce(sum(coalesce(ii.passed_quantity, 0) + coalesce(ii.failed_quantity, 0)), 0)
                                from public.inspection_items ii
                                join public.inspections i on i.id = ii.inspection_id
                                join public.delivery_plans dp on dp.id = i.delivery_plan_id
                               where dp.supplier_id = d.id)
        ) as row
          from public.delivery_suppliers d
         where (p_partner_id is null or d.id = p_partner_id)
           and (p_partner_id is not null
                or exists (select 1 from public.supply_chain_supplier_products sp where sp.partner_id = d.id)
                or exists (select 1 from public.purchase_orders po where po.supplier_id = d.id))
      ) q), '[]');
end;
$$;

-- ------------------------------------------------------------ grants

do $$
declare f text;
begin
  foreach f in array array[
    'sc_require_view()', 'sc_require_manage()', 'sc_seed_from_history()',
    'sc_model(bigint, bigint[])', 'sc_set_settings(jsonb)',
    'sc_save_node(jsonb)', 'sc_save_route(jsonb)', 'sc_save_supplier_product(jsonb)',
    'sc_save_product_profile(jsonb)', 'sc_save_cost_rule(jsonb)', 'sc_save_tariff_rule(jsonb)',
    'sc_save_fx_rate(text, numeric, date, text)', 'sc_save_risk_event(jsonb)', 'sc_archive(text, bigint)',
    'sc_save_scenario(bigint, text, text, bigint, jsonb)', 'sc_list_scenarios()',
    'sc_record_result(text, bigint, text, bigint, jsonb, jsonb, jsonb)',
    'sc_list_results(integer, text)', 'sc_result(bigint)', 'sc_supplier_stats(bigint)']
  loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated, service_role', f);
  end loop;
end $$;

select public.sc_sync_nodes_impl();
