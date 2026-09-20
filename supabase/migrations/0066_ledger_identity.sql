-- 0066_ledger_identity.sql
-- Phase B, step 1: the ledger records *what* moved, not only how much.
--
-- §5 made `stock_movements` the canonical source and `stock_levels` /
-- `bin_stock` / `stock_units` three projections of it. But the ledger row only
-- carried a quantity, so the projection had to guess the rest: every receipt
-- landed as (bin null, lot null, serial null, status OK), and every issue drew
-- from whatever parcel sorted first. That guess is exactly what Phase B cannot
-- live with:
--
--   * §12 wants a receipt recorded at parcel level — lot, serial, expiry,
--     location, quantity — and a parcel that arrives on lot L has to *be* on
--     lot L in stock, not be reconciled into it afterwards.
--   * §13 wants goods to land as QC_PENDING and become OK only when an
--     inspection says so. Posting a receipt that is not OK is impossible while
--     the projection hard-codes OK.
--
-- So the identity moves onto the ledger row, where the rest of the movement
-- already lives, and the projection stops guessing: it applies what the row
-- says. Nothing is added to the projections themselves — `stock_units` already
-- had these columns; they were simply unreachable from a movement.
--
-- Deliberately *not* included: the movement's `bin_id` still does not reach
-- `stock_units`. A warehouse-scope receipt leaves the unit with `bin_id` null,
-- which is what "arrived but not yet put away" means (§14's pending = on_hand −
-- binned), and `bin_stock` remains the bin-level projection. Put-away is what
-- gives a unit its bin, and that is step 0069.

begin;

-- ---------------------------------------------------------------------------
-- 1. Identity on the ledger row
-- ---------------------------------------------------------------------------

alter table public.stock_movements
  add column if not exists lot_id    bigint,
  add column if not exists serial_id bigint,
  add column if not exists status_id bigint;

comment on column public.stock_movements.lot_id is
  'Which lot moved. Null means the movement was recorded without lot detail, not that the product is untracked.';
comment on column public.stock_movements.serial_id is
  'Which serial moved. A serial movement is one unit at a time.';
comment on column public.stock_movements.status_id is
  'The stock status the quantity moved into (inbound) or out of (outbound). Null means OK for inbound and "any, available first" for outbound.';

do $$
begin
  -- Composite, so a lot can never be attached to the wrong product. MATCH
  -- SIMPLE: a null lot_id satisfies the constraint, which is what lets us add
  -- it to a table whose product_id is itself nullable.
  if not exists (select 1 from pg_constraint where conname = 'stock_movements_lot_fk') then
    alter table public.stock_movements
      add constraint stock_movements_lot_fk
      foreign key (product_id, lot_id) references public.lots(product_id, id)
      on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'stock_movements_serial_fk') then
    alter table public.stock_movements
      add constraint stock_movements_serial_fk
      foreign key (product_id, serial_id) references public.serial_numbers(product_id, id)
      on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'stock_movements_status_id_fkey') then
    alter table public.stock_movements
      add constraint stock_movements_status_id_fkey
      foreign key (status_id) references public.stock_statuses(id);
  end if;
  -- A serialised unit is one thing; a movement of it is one unit.
  if not exists (select 1 from pg_constraint where conname = 'stock_movements_serial_quantity_check') then
    alter table public.stock_movements
      add constraint stock_movements_serial_quantity_check
      check (serial_id is null or abs(quantity) <= 1);
  end if;
end $$;

create index if not exists stock_movements_lot_idx
  on public.stock_movements (lot_id) where lot_id is not null;
create index if not exists stock_movements_serial_idx
  on public.stock_movements (serial_id) where serial_id is not null;

-- ---------------------------------------------------------------------------
-- 2. The projection applies the identity instead of assuming one
-- ---------------------------------------------------------------------------
--
-- Every identity argument defaults to null, which reads as "leave that dimension
-- open": null on the way in means OK and no lot, null on the way out means
-- "any matching parcel, available first" — the behaviour every existing caller
-- already relies on.

create or replace function public.apply_stock_unit_delta(
  p_product_id   bigint,
  p_warehouse_id bigint,
  p_delta        integer,
  p_bin_id       bigint default null,
  p_lot_id       bigint default null,
  p_serial_id    bigint default null,
  p_status_id    bigint default null
) returns integer
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_company_id bigint;
  v_status_id  bigint;
  v_left       integer := abs(coalesce(p_delta, 0));
  v_take       integer;
  v_row        record;
  v_serial     text;
begin
  if coalesce(p_delta, 0) = 0 then
    return 0;
  end if;
  select company_id into v_company_id from public.products where id = p_product_id;
  if v_company_id is null then
    -- An unregistered JAN has no product to hang a unit on. The warehouse
    -- total still moved (stock_levels), so the whole delta is reported back as
    -- unprojected rather than silently dropped.
    return coalesce(p_delta, 0);
  end if;

  if p_delta > 0 then
    v_status_id := coalesce(p_status_id,
      (select id from public.stock_statuses where code = 'OK'));

    if p_serial_id is not null then
      -- Receiving the same serial twice is a data error worth naming, not a
      -- check-constraint violation.
      if exists (select 1 from public.stock_units
                  where serial_id = p_serial_id and quantity > 0) then
        select serial_number into v_serial
          from public.serial_numbers where id = p_serial_id;
        raise exception 'serial % is already in stock', coalesce(v_serial, p_serial_id::text);
      end if;
    end if;

    insert into public.stock_units as su
      (company_id, product_id, warehouse_id, bin_id, lot_id, serial_id,
       status_id, quantity)
    values (v_company_id, p_product_id, p_warehouse_id, p_bin_id, p_lot_id,
            p_serial_id, v_status_id, p_delta)
    on conflict (product_id, warehouse_id, bin_id, lot_id, serial_id, status_id)
      do update set quantity = su.quantity + excluded.quantity, updated_at = now();
    return 0;
  end if;

  -- Outbound. Each identity argument narrows which parcels may be drawn from;
  -- a null one leaves that dimension open.
  for v_row in
    select su.id, su.quantity
      from public.stock_units su
      join public.stock_statuses st on st.id = su.status_id
      left join public.lots l on l.id = su.lot_id
     where su.product_id = p_product_id
       and su.warehouse_id = p_warehouse_id
       and su.quantity > 0
       and (p_bin_id is null or su.bin_id = p_bin_id)
       and (p_lot_id is null or su.lot_id = p_lot_id)
       and (p_serial_id is null or su.serial_id = p_serial_id)
       and (p_status_id is null or su.status_id = p_status_id)
     order by st.counts_available desc, l.expiry_date asc nulls last,
              st.sort_order, su.id
  loop
    exit when v_left <= 0;
    v_take := least(v_left, v_row.quantity);
    update public.stock_units
       set quantity = quantity - v_take, updated_at = now()
     where id = v_row.id;
    v_left := v_left - v_take;
  end loop;

  delete from public.stock_units
   where product_id = p_product_id and warehouse_id = p_warehouse_id
     and quantity = 0 and serial_id is null;

  -- What could not be drawn from a matching parcel. The caller decides whether
  -- that is a warning or a refusal; §13 (0068) is where it becomes a refusal.
  return -v_left;
end;
$$;

revoke all on function public.apply_stock_unit_delta(bigint, bigint, integer, bigint, bigint, bigint, bigint)
  from public, anon, authenticated;
grant execute on function public.apply_stock_unit_delta(bigint, bigint, integer, bigint, bigint, bigint, bigint)
  to service_role;

-- The three-argument form is dropped rather than kept as a wrapper: leaving it
-- beside a version whose extra parameters all default would make every
-- three-argument call ambiguous. Dropping it costs nothing, because a
-- three-argument call now resolves to the function above with the identity left
-- open — which is exactly what the old one meant.
drop function if exists public.apply_stock_unit_delta(bigint, bigint, integer);

create or replace function public.project_stock_movement()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_delta integer;
begin
  if coalesce(new.balance_scope, 'WAREHOUSE') <> 'WAREHOUSE' then
    return null;
  end if;
  if new.product_id is null then
    return null;
  end if;

  v_delta := new.quantity_after - new.quantity_before;
  -- bin_id is deliberately not passed: at warehouse scope the unit is "in the
  -- building", and put-away is what gives it a bin.
  perform public.apply_stock_unit_delta(
    new.product_id, new.warehouse_id, v_delta,
    null, new.lot_id, new.serial_id, new.status_id);
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Posting a movement with identity
-- ---------------------------------------------------------------------------
--
-- One implementation, two doors. `apply_stock_movement_detail` is the whole
-- posting path; `apply_stock_movement` keeps its old signature and delegates,
-- so every existing caller is untouched.

create or replace function public.apply_stock_movement_detail(
  p_warehouse_id  bigint,
  p_jan_code      text,
  p_quantity      integer,
  p_movement_type text,
  p_reference_type text default null,
  p_reference_id   text default null,
  p_product_name   text default null,
  p_bin_id         bigint default null,
  p_note           text default null,
  p_lot_id         bigint default null,
  p_serial_id      bigint default null,
  p_status_code    text default null,
  p_product_id     bigint default null
) returns bigint
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_before     integer;
  v_after      integer;
  v_effective  integer;
  v_id         bigint;
  v_jan        text := nullif(btrim(coalesce(p_jan_code, '')), '');
  v_product_id bigint := p_product_id;
  v_status_id  bigint;
  v_lot_owner  bigint;
begin
  if coalesce(p_quantity, 0) = 0 then
    return null;
  end if;
  if p_warehouse_id is null then
    raise exception 'apply_stock_movement: warehouse is required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  -- Either handle identifies the product; the other is filled in from it, so a
  -- caller holding a product_id never has to look a barcode up to post.
  if v_product_id is null and v_jan is not null then
    select id into v_product_id from public.products where jan_code = v_jan;
  end if;
  if v_jan is null and v_product_id is not null then
    select jan_code into v_jan from public.products where id = v_product_id;
  end if;
  if v_jan is null then
    return null;
  end if;

  -- Identity has to belong to the product being moved; the composite foreign
  -- keys would catch it, but a named error is what an operator can act on.
  if p_lot_id is not null then
    if v_product_id is null then
      raise exception 'a lot cannot be recorded for an unregistered product %', v_jan;
    end if;
    select product_id into v_lot_owner from public.lots where id = p_lot_id;
    if v_lot_owner is distinct from v_product_id then
      raise exception 'lot % does not belong to product %', p_lot_id, v_jan;
    end if;
  end if;
  if p_serial_id is not null then
    if v_product_id is null then
      raise exception 'a serial cannot be recorded for an unregistered product %', v_jan;
    end if;
    select product_id into v_lot_owner from public.serial_numbers where id = p_serial_id;
    if v_lot_owner is distinct from v_product_id then
      raise exception 'serial % does not belong to product %', p_serial_id, v_jan;
    end if;
  end if;

  if p_status_code is not null and btrim(p_status_code) <> '' then
    select id into v_status_id from public.stock_statuses
     where code = upper(btrim(p_status_code)) and is_active;
    if v_status_id is null then
      raise exception 'unknown stock status %', p_status_code;
    end if;
  end if;

  insert into public.stock_levels (warehouse_id, jan_code, product_name, on_hand)
  values (p_warehouse_id, v_jan, coalesce(p_product_name, ''), 0)
  on conflict (warehouse_id, jan_code) do nothing;

  select on_hand into v_before
    from public.stock_levels
   where warehouse_id = p_warehouse_id and jan_code = v_jan
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
   where warehouse_id = p_warehouse_id and jan_code = v_jan;

  insert into public.stock_movements (
    company_id, warehouse_id, bin_id, jan_code, product_name,
    movement_type, quantity, quantity_before, quantity_after,
    reference_type, reference_id, actor_user_id, note,
    lot_id, serial_id, status_id
  )
  values (
    (select id from public.companies order by id limit 1),
    p_warehouse_id, p_bin_id, v_jan, p_product_name,
    p_movement_type, v_effective, coalesce(v_before, 0), v_after,
    p_reference_type, p_reference_id, auth.uid(), p_note,
    p_lot_id, p_serial_id, v_status_id
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.apply_stock_movement_detail(bigint, text, integer, text, text, text, text, bigint, text, bigint, bigint, text, bigint)
  from public, anon, authenticated;
grant execute on function public.apply_stock_movement_detail(bigint, text, integer, text, text, text, text, bigint, text, bigint, bigint, text, bigint)
  to service_role;

create or replace function public.apply_stock_movement(
  p_warehouse_id   bigint,
  p_jan_code       text,
  p_quantity       integer,
  p_movement_type  text,
  p_reference_type text default null,
  p_reference_id   text default null,
  p_product_name   text default null,
  p_bin_id         bigint default null,
  p_note           text default null
) returns bigint
language sql
security definer
set search_path to ''
as $$
  select public.apply_stock_movement_detail(
    p_warehouse_id, p_jan_code, p_quantity, p_movement_type,
    p_reference_type, p_reference_id, p_product_name, p_bin_id, p_note);
$$;

revoke all on function public.apply_stock_movement(bigint, text, integer, text, text, text, text, bigint, text)
  from public, anon, authenticated;
grant execute on function public.apply_stock_movement(bigint, text, integer, text, text, text, text, bigint, text)
  to service_role;

-- ---------------------------------------------------------------------------
-- 4. The ledger read shows what the ledger now records
-- ---------------------------------------------------------------------------

create or replace function public.stock_ledger_impl(
  p_jan_code text default null,
  p_warehouse_id bigint default null,
  p_limit integer default 100,
  p_scope text default 'WAREHOUSE'
) returns jsonb
language sql
stable
security definer
set search_path to ''
as $$
  select coalesce(jsonb_agg(row_to_json(t) order by t.created_at desc, t.id desc), '[]'::jsonb)
  from (
    select m.id, m.created_at, m.warehouse_id, w.name as warehouse_name,
           m.bin_id, b.code as bin_code, m.jan_code, m.product_name,
           m.movement_type, m.balance_scope,
           m.quantity, m.quantity_before, m.quantity_after,
           m.reference_type, m.reference_id, m.actor_user_id, m.note,
           m.product_id,
           m.lot_id, l.lot_code, l.expiry_date,
           m.serial_id, sn.serial_number,
           m.status_id, st.code as status_code, st.name as status_name
    from public.stock_movements m
    left join public.warehouses w on w.id = m.warehouse_id
    left join public.bins b on b.id = m.bin_id
    left join public.lots l on l.id = m.lot_id
    left join public.serial_numbers sn on sn.id = m.serial_id
    left join public.stock_statuses st on st.id = m.status_id
    where (p_jan_code is null or m.jan_code = p_jan_code)
      and (p_warehouse_id is null or m.warehouse_id = p_warehouse_id)
      and public.can_access_warehouse(m.warehouse_id)
      and (p_scope is null or p_scope = 'ALL' or m.balance_scope = p_scope)
    order by m.created_at desc, m.id desc
    limit greatest(coalesce(p_limit, 100), 1)
  ) t;
$$;

-- An _impl stays unreachable by every client role, service_role included: only
-- the guarded wrapper above it may call it (invariant 4).
revoke all on function public.stock_ledger_impl(text, bigint, integer, text)
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. Housekeeping
-- ---------------------------------------------------------------------------

do $tighten$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prorettype = 'trigger'::regtype
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
  end loop;
end $tighten$;

commit;
