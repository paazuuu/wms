-- Step 1 (spec §46): multi-warehouse foundation.
--
-- Additive and non-breaking: new tenancy/warehouse tables, one seeded default
-- company + warehouse, and a nullable warehouse_id on the existing operational
-- tables backfilled to that default. Every current flow (delivery
-- reconciliation, shipment, stock, dashboard) keeps working untouched.
--
-- Deliberately deferred:
--   * stock_levels keeps its jan_code key; the move to a per-warehouse/bin
--     `inventory` table + stock_movements ledger is migration 0013.
--   * Role/permission/warehouse-scope enforcement is migration 0012 (Step 3).
--     Until then these tables are read-only to the client and all writes go
--     through the `warehouses` edge function (service role), matching the
--     existing delivery-plans / shipments pattern.

-- ---------------------------------------------------------------- companies
create table if not exists public.companies (
  id bigserial primary key,
  code text not null,
  name text not null,
  status text not null default 'active'
    check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint companies_code_key unique (code)
);

-- --------------------------------------------------------------- warehouses
create table if not exists public.warehouses (
  id bigserial primary key,
  company_id bigint not null references public.companies (id) on delete restrict,
  code text not null,
  name text not null,
  description text,
  address text,
  phone text,
  timezone text not null default 'Asia/Tokyo',
  status text not null default 'active'
    check (status in ('active', 'inactive')),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- code is unique within a company, not globally (spec §6)
  constraint warehouses_company_code_key unique (company_id, code)
);

-- At most one default warehouse per company.
create unique index if not exists warehouses_one_default_per_company
  on public.warehouses (company_id)
  where is_default;

-- -------------------------------------------------------------------- zones
-- Optional layer: warehouse → bin is the practical base, zones/aisles/racks are
-- additive rather than a forced 4-level hierarchy (spec §7).
create table if not exists public.zones (
  id bigserial primary key,
  warehouse_id bigint not null references public.warehouses (id) on delete cascade,
  code text not null,
  name text,
  created_at timestamptz not null default now(),
  constraint zones_warehouse_code_key unique (warehouse_id, code)
);

-- --------------------------------------------------------------------- bins
create table if not exists public.bins (
  id bigserial primary key,
  warehouse_id bigint not null references public.warehouses (id) on delete cascade,
  zone_id bigint references public.zones (id) on delete set null,
  code text not null,
  -- Bin types follow spec §8; STAGING/QC_HOLD are not normally allocatable.
  bin_type text not null default 'PICKABLE'
    check (bin_type in ('STAGING', 'PICKABLE', 'PICKABLE_STAGING', 'QC_HOLD',
                        'SHIPPING', 'RETURNS', 'DAMAGED', 'VIRTUAL')),
  is_active boolean not null default true,
  -- aisle / rack / temperature / capacity live here until they earn a column.
  attributes jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint bins_warehouse_code_key unique (warehouse_id, code)
);

create index if not exists bins_warehouse_type_idx
  on public.bins (warehouse_id, bin_type);

-- ------------------------------------------------------- seed default tenant
-- Idempotent: only seeds when the tables are still empty, so re-running the
-- migration never duplicates or renames the operator's own data.
do $$
declare
  v_company_id bigint;
  v_warehouse_id bigint;
begin
  select id into v_company_id from public.companies order by id limit 1;
  if v_company_id is null then
    insert into public.companies (code, name)
    values ('DEFAULT', '自社')
    returning id into v_company_id;
  end if;

  select id into v_warehouse_id
  from public.warehouses
  where company_id = v_company_id
  order by id
  limit 1;

  if v_warehouse_id is null then
    insert into public.warehouses (company_id, code, name, is_default)
    values (v_company_id, 'MAIN', 'メイン倉庫', true)
    returning id into v_warehouse_id;
  end if;

  -- A minimal working bin set for the seeded warehouse so the later staged
  -- flows (staging → QC hold → put-away → shipping) have somewhere to land.
  -- For warehouses created later this is a toggle on the wizard (spec §49).
  insert into public.bins (warehouse_id, code, bin_type)
  select v_warehouse_id, b.code, b.bin_type
  from (values
    ('STAGE-01', 'STAGING'),
    ('QC-01', 'QC_HOLD'),
    ('SHIP-01', 'SHIPPING'),
    ('A-01-01', 'PICKABLE')
  ) as b (code, bin_type)
  where not exists (
    select 1 from public.bins x
    where x.warehouse_id = v_warehouse_id and x.code = b.code
  );
end $$;

-- ------------------------------------- attach existing data to that warehouse
alter table public.stock_levels
  add column if not exists warehouse_id bigint references public.warehouses (id);
alter table public.delivery_plans
  add column if not exists warehouse_id bigint references public.warehouses (id);
alter table public.shipment_plans
  add column if not exists warehouse_id bigint references public.warehouses (id);

update public.stock_levels s
set warehouse_id = w.id
from public.warehouses w
where w.is_default and s.warehouse_id is null;

update public.delivery_plans p
set warehouse_id = w.id
from public.warehouses w
where w.is_default and p.warehouse_id is null;

update public.shipment_plans p
set warehouse_id = w.id
from public.warehouses w
where w.is_default and p.warehouse_id is null;

create index if not exists stock_levels_warehouse_idx
  on public.stock_levels (warehouse_id);
create index if not exists delivery_plans_warehouse_idx
  on public.delivery_plans (warehouse_id);
create index if not exists shipment_plans_warehouse_idx
  on public.shipment_plans (warehouse_id);

-- ----------------------------------------------------------------------- RLS
-- Same posture as the existing tables: readable by the client, writes only via
-- edge functions running with the service role. Real per-user warehouse scope
-- arrives in 0012 (Step 3).
alter table public.companies enable row level security;
alter table public.warehouses enable row level security;
alter table public.zones enable row level security;
alter table public.bins enable row level security;

drop policy if exists "read companies" on public.companies;
create policy "read companies" on public.companies
  for select to anon, authenticated using (true);

drop policy if exists "read warehouses" on public.warehouses;
create policy "read warehouses" on public.warehouses
  for select to anon, authenticated using (true);

drop policy if exists "read zones" on public.zones;
create policy "read zones" on public.zones
  for select to anon, authenticated using (true);

drop policy if exists "read bins" on public.bins;
create policy "read bins" on public.bins
  for select to anon, authenticated using (true);
