-- Step 4 groundwork, part 1 (spec §17, §18, §41): the stock ledger.
--
-- Replaces "mutate a quantity" with "append a movement, then update the
-- snapshot", both inside one transaction, so every change answers
--   before → change → after, why, against what, by whom
-- and the current balance is always reconstructable (spec §18).
--
-- This migration puts the machinery in place:
--   1. default_warehouse_id() + triggers, so a plan/shipment inserted without a
--      warehouse (the import-plan function predates multi-warehouse) still lands
--      in a real warehouse instead of a null scope.
--   2. stock_levels is re-keyed to (warehouse_id, jan_code). Until now the key
--      was jan_code alone, so per-warehouse stock was structurally impossible
--      even after 0010 added the column. The table is empty, so this is a clean
--      re-key with no data migration.
--   3. stock_movements: the ledger itself.
--   4. apply_stock_movement: the single place the invariant lives.
--
-- Migration 0014 then routes the four stock-mutating RPCs through it.

-- ------------------------------------------------------- default warehouse
create or replace function public.default_warehouse_id()
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select id from public.warehouses where is_default order by id limit 1),
    (select id from public.warehouses order by id limit 1)
  );
$$;

-- Any client that inserts a plan/shipment without a warehouse (the import-plan
-- function predates multi-warehouse) lands in the default warehouse rather than
-- with a null scope. Explicit values are left untouched.
create or replace function public.fill_default_warehouse()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.warehouse_id is null then
    new.warehouse_id := public.default_warehouse_id();
  end if;
  return new;
end;
$$;

drop trigger if exists delivery_plans_default_warehouse on public.delivery_plans;
create trigger delivery_plans_default_warehouse
  before insert on public.delivery_plans
  for each row execute function public.fill_default_warehouse();

drop trigger if exists shipment_plans_default_warehouse on public.shipment_plans;
create trigger shipment_plans_default_warehouse
  before insert on public.shipment_plans
  for each row execute function public.fill_default_warehouse();

-- --------------------------------------------------------- re-key the snapshot
update public.stock_levels
   set warehouse_id = public.default_warehouse_id()
 where warehouse_id is null;

alter table public.stock_levels alter column warehouse_id set not null;
alter table public.stock_levels drop constraint if exists stock_levels_pkey;
alter table public.stock_levels
  add constraint stock_levels_pkey primary key (warehouse_id, jan_code);

-- ------------------------------------------------------------ the ledger
create table if not exists public.stock_movements (
  id bigserial primary key,
  company_id bigint references public.companies (id) on delete set null,
  warehouse_id bigint not null references public.warehouses (id),
  -- Where inside the warehouse. Recorded from put-away (Step 6) onward; the
  -- balance itself is per warehouse until bin-level balances are needed.
  bin_id bigint references public.bins (id) on delete set null,
  jan_code text not null,
  product_name text,
  movement_type text not null check (movement_type in (
    'OPENING',        -- balance carried in when the ledger started
    'RECEIPT',        -- inbound received
    'RECEIPT_CANCEL', -- a receipt reversed (訂正/取消)
    'PUTAWAY',        -- staging → pickable
    'PICK',           -- picked for an order
    'SHIP',           -- shipped out
    'SHIP_CANCEL',    -- a shipment reversed
    'ADJUST',         -- manual correction
    'COUNT',          -- cycle-count variance
    'TRANSFER_IN',    -- arrived from another warehouse
    'TRANSFER_OUT'    -- sent to another warehouse
  )),
  -- Signed effective delta. before + quantity = after, always.
  quantity integer not null,
  quantity_before integer not null,
  quantity_after integer not null,
  reference_type text,
  reference_id text,
  actor_user_id uuid,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists stock_movements_item_idx
  on public.stock_movements (warehouse_id, jan_code, created_at desc);
create index if not exists stock_movements_reference_idx
  on public.stock_movements (reference_type, reference_id);
create index if not exists stock_movements_created_idx
  on public.stock_movements (created_at desc);

-- -------------------------------------------------- the one place stock moves
-- Locks the snapshot row, computes the effective delta (balances never go
-- negative, matching existing behaviour), writes the movement, updates the
-- snapshot. Returns the movement id, or null when nothing changed.
create or replace function public.apply_stock_movement(
  p_warehouse_id bigint,
  p_jan_code text,
  p_quantity integer,
  p_movement_type text,
  p_reference_type text default null,
  p_reference_id text default null,
  p_product_name text default null,
  p_bin_id bigint default null,
  p_note text default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_before    integer;
  v_after     integer;
  v_effective integer;
  v_id        bigint;
begin
  if p_quantity = 0 or p_jan_code is null or p_jan_code = '' then
    return null;
  end if;
  if p_warehouse_id is null then
    raise exception 'apply_stock_movement: warehouse is required';
  end if;

  -- Ensure a snapshot row exists, then lock it so concurrent movements against
  -- the same item serialise instead of racing.
  insert into public.stock_levels (warehouse_id, jan_code, product_name, on_hand)
  values (p_warehouse_id, p_jan_code, coalesce(p_product_name, ''), 0)
  on conflict (warehouse_id, jan_code) do nothing;

  select on_hand into v_before
    from public.stock_levels
   where warehouse_id = p_warehouse_id and jan_code = p_jan_code
     for update;

  v_after := greatest(coalesce(v_before, 0) + p_quantity, 0);
  v_effective := v_after - coalesce(v_before, 0);

  if v_effective = 0 then
    return null;
  end if;

  update public.stock_levels
     set on_hand = v_after,
         product_name = case
           when coalesce(product_name, '') = '' then coalesce(p_product_name, '')
           else product_name
         end,
         updated_at = now()
   where warehouse_id = p_warehouse_id and jan_code = p_jan_code;

  insert into public.stock_movements (
    company_id, warehouse_id, bin_id, jan_code, product_name,
    movement_type, quantity, quantity_before, quantity_after,
    reference_type, reference_id, actor_user_id, note
  )
  values (
    (select id from public.companies order by id limit 1),
    p_warehouse_id, p_bin_id, p_jan_code, p_product_name,
    p_movement_type, v_effective, coalesce(v_before, 0), v_after,
    p_reference_type, p_reference_id, auth.uid(), p_note
  )
  returning id into v_id;

  return v_id;
end;
$$;

-- The four stock-mutating RPCs are rewritten in 0014 to go through
-- apply_stock_movement; this migration only puts the ledger in place.
