-- 0068_qc_gate.sql
-- Phase B, step 3: §13 — QC is a real gate, and the database is where it holds.
--
-- The spec does not leave this one to the interface:
--
--   「QC FAIL / HOLDの商品が誤って出荷されないことを、Flutter UIだけでなく
--     RPC/DB側でも保証する。」
--
-- Before this migration, QC was a document. `inspections` and `inspection_items`
-- recorded what an inspector found, and `complete_inspection` wrote a status onto
-- the inspection — and that was all it did. Receiving had already made the goods
-- available the moment they were counted, so a carton that failed inspection was
-- pickable, shippable and indistinguishable from good stock. Every guard was in
-- the UI, which means every guard was advisory.
--
-- Three changes make it real, and they have to be all three: holding goods on
-- arrival is pointless if nothing releases them, releasing them is pointless if
-- nothing was held, and both are pointless if shipping can reach into held stock
-- anyway.
--
--   1. Goods that need inspecting arrive as QC_PENDING, not OK.
--   2. Completing an inspection is what moves them: passed to OK, failed to
--      DAMAGED (or wherever the workflow says).
--   3. An outbound movement may only draw from parcels whose status counts as
--      available, and is refused — not clamped, not silently redirected — when
--      there are not enough.
--
-- Point 3 is the one the spec is really asking for, and the reason it lives in
-- `project_stock_movement` rather than in `ship_plan` is that the rule is then
-- derived from the ledger row itself. Any path that posts an outbound movement
-- is gated, including one written next year by someone who never read this file.

-- ---------------------------------------------------------------------------
-- 1. Which goods need inspecting
-- ---------------------------------------------------------------------------
--
-- Two levels, because the answer genuinely differs by both: a product may always
-- need checking (regulated goods), and a warehouse may check a product the
-- others take on trust (a site with no QC bench cannot hold stock it will never
-- inspect). Null at the warehouse level means "follow the product", which is the
-- same convention 0063 used for the rest of `warehouse_products`.

alter table public.products
  add column if not exists requires_inspection boolean not null default false;

comment on column public.products.requires_inspection is
  'True when goods of this product arrive held for QC (§13) rather than available.';

alter table public.warehouse_products
  add column if not exists requires_inspection boolean;

comment on column public.warehouse_products.requires_inspection is
  'Per-warehouse override of products.requires_inspection. Null means "follow the product".';

create or replace function public.receiving_status_for(
  p_product_id bigint,
  p_warehouse_id bigint
) returns text
language sql
stable
security definer
set search_path to ''
as $$
  select case
    when coalesce(
      (select w.requires_inspection
         from public.warehouse_products w
        where w.product_id = p_product_id and w.warehouse_id = p_warehouse_id),
      (select p.requires_inspection from public.products p where p.id = p_product_id),
      false)
    then 'QC_PENDING' else 'OK' end;
$$;

revoke all on function public.receiving_status_for(bigint, bigint) from public, anon;
grant execute on function public.receiving_status_for(bigint, bigint)
  to authenticated, service_role;

-- Setting the flag gets its own call rather than another optional parameter on
-- `set_warehouse_product`. There, null already means "leave this alone", and a
-- three-valued flag whose third value is *also* null ("follow the product")
-- cannot be expressed that way. Here the parameter is the whole point of the
-- call, so null is unambiguous.

create or replace function public.set_inspection_requirement(
  p_product_id         bigint,
  p_requires_inspection boolean,
  p_warehouse_id       bigint default null
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_company bigint;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  select company_id into v_company from public.products where id = p_product_id;
  if v_company is null then
    raise exception 'product % not found', p_product_id;
  end if;

  if p_warehouse_id is null then
    -- The product-level answer, which every warehouse follows unless it says
    -- otherwise. A null here would mean nothing, so it is read as false.
    update public.products
       set requires_inspection = coalesce(p_requires_inspection, false),
           updated_at = now()
     where id = p_product_id;
  else
    if not public.can_access_warehouse(p_warehouse_id) then
      raise exception 'not permitted: warehouse.scope required';
    end if;
    insert into public.warehouse_products
      (company_id, warehouse_id, product_id, requires_inspection)
    values (v_company, p_warehouse_id, p_product_id, p_requires_inspection)
    on conflict (warehouse_id, product_id)
      do update set requires_inspection = excluded.requires_inspection,
                    updated_at = now();
  end if;

  perform public.log_audit('product.inspection_requirement', 'product',
    p_product_id::text, p_warehouse_id,
    jsonb_build_object('requires_inspection', p_requires_inspection,
                       'scope', case when p_warehouse_id is null then 'product' else 'warehouse' end));

  return jsonb_build_object(
    'product_id', p_product_id,
    'warehouse_id', p_warehouse_id,
    'requires_inspection', p_requires_inspection,
    'receiving_status', public.receiving_status_for(
      p_product_id, coalesce(p_warehouse_id, public.default_warehouse_id())));
end;
$$;

revoke all on function public.set_inspection_requirement(bigint, boolean, bigint) from public, anon;
grant execute on function public.set_inspection_requirement(bigint, boolean, bigint)
  to authenticated, service_role;

create or replace function public.record_receipt_item_impl(
  p_reconciliation_id bigint,
  p_warehouse_id      bigint,
  p_line_id           bigint,
  p_jan_code          text,
  p_quantity          integer,
  p_lot_code          text default null,
  p_expiry            date default null,
  p_serial_number     text default null,
  p_location_code     text default null,
  p_status_code       text default null,
  p_note              text default null
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_company     bigint;
  v_product     bigint;
  v_name        text;
  v_jan         text := nullif(btrim(coalesce(p_jan_code, '')), '');
  v_lot         bigint;
  v_serial      bigint;
  v_location    bigint;
  v_bin         bigint;
  v_status      bigint;
  v_status_code text;
  v_line        bigint := p_line_id;
  v_movement    bigint;
  v_item        bigint;
begin
  if coalesce(p_quantity, 0) <= 0 then
    raise exception 'quantity must be greater than zero';
  end if;
  if v_jan is null then
    raise exception 'jan_code is required';
  end if;

  select id into v_company from public.companies order by id limit 1;
  select id, name into v_product, v_name from public.products where jan_code = v_jan;

  -- Named status wins; otherwise the product and warehouse decide whether these
  -- goods are available on arrival or held for QC.
  v_status_code := upper(btrim(coalesce(
    nullif(btrim(coalesce(p_status_code, '')), ''),
    public.receiving_status_for(v_product, p_warehouse_id),
    'OK')));

  if v_line is not null then
    if not exists (select 1 from public.reconciliation_lines
                    where id = v_line and reconciliation_id = p_reconciliation_id) then
      raise exception 'line % does not belong to receipt %', v_line, p_reconciliation_id;
    end if;
  else
    select id into v_line from public.reconciliation_lines
     where reconciliation_id = p_reconciliation_id and jan_code = v_jan
     order by id limit 1;
  end if;

  if nullif(btrim(coalesce(p_lot_code, '')), '') is not null then
    if v_product is null then
      raise exception 'a lot cannot be recorded for an unregistered product %', v_jan;
    end if;
    v_lot := public.upsert_lot(v_product, btrim(p_lot_code), p_expiry, null, null, now(), null);
  end if;
  if nullif(btrim(coalesce(p_serial_number, '')), '') is not null then
    if v_product is null then
      raise exception 'a serial cannot be recorded for an unregistered product %', v_jan;
    end if;
    if p_quantity <> 1 then
      raise exception 'a serial is one unit, but % were given', p_quantity;
    end if;
    v_serial := public.upsert_serial(v_product, btrim(p_serial_number), v_lot, 'IN_STOCK', null);
  end if;

  if nullif(btrim(coalesce(p_location_code, '')), '') is not null then
    select l.id, l.bin_id into v_location, v_bin
      from public.locations l
     where l.warehouse_id = p_warehouse_id and l.code = btrim(p_location_code) and l.is_active;
    if v_location is null then
      raise exception 'location % not found in this warehouse', btrim(p_location_code);
    end if;
  end if;

  select id into v_status from public.stock_statuses
   where code = v_status_code and is_active;
  if v_status is null then
    raise exception 'unknown stock status %', v_status_code;
  end if;

  v_movement := public.apply_stock_movement_detail(
    p_warehouse_id, v_jan, p_quantity, 'RECEIPT',
    'receipt_item', p_reconciliation_id::text, v_name,
    null, p_note, v_lot, v_serial, v_status_code, v_product);

  insert into public.receipt_items (
    company_id, reconciliation_id, reconciliation_line_id, warehouse_id,
    product_id, jan_code, product_name, lot_id, serial_id, expiry,
    location_id, bin_id, quantity, status_id, movement_id, note, created_by)
  values (
    v_company, p_reconciliation_id, v_line, p_warehouse_id,
    v_product, v_jan, v_name, v_lot, v_serial, p_expiry,
    v_location, v_bin, p_quantity, v_status, v_movement, p_note, auth.uid())
  returning id into v_item;

  perform public.log_audit(
    'receiving.item_recorded', 'reconciliation', p_reconciliation_id::text, p_warehouse_id,
    jsonb_build_object('jan_code', v_jan, 'quantity', p_quantity,
                       'lot', nullif(btrim(coalesce(p_lot_code, '')), ''),
                       'serial', nullif(btrim(coalesce(p_serial_number, '')), ''),
                       'status', v_status_code,
                       'location', nullif(btrim(coalesce(p_location_code, '')), '')));

  return jsonb_build_object(
    'receipt_item_id', v_item,
    'reconciliation_id', p_reconciliation_id,
    'line_id', v_line,
    'jan_code', v_jan,
    'product_id', v_product,
    'quantity', p_quantity,
    'lot_id', v_lot,
    'serial_id', v_serial,
    'location_id', v_location,
    'status', v_status_code,
    'movement_id', v_movement,
    'on_hand', public.stock_on_hand(v_product, p_warehouse_id),
    'available', public.stock_available(v_product, p_warehouse_id));
end;
$$;

revoke all on function public.record_receipt_item_impl(bigint, bigint, bigint, text, integer, text, date, text, text, text, text)
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. The gate itself
-- ---------------------------------------------------------------------------
--
-- Which movement types take stock out of the building on their way to a
-- customer, a sister site or a work order. ADJUST, COUNT and RECEIPT_CANCEL are
-- deliberately absent: writing off damaged stock, correcting a count and undoing
-- a receipt all *need* to reach non-available parcels, and refusing them would
-- leave held stock impossible to dispose of.

create or replace function public.is_outbound_movement(p_movement_type text)
returns boolean
language sql
immutable
set search_path to ''
as $$
  select upper(coalesce(p_movement_type, '')) in
    ('SHIP', 'TRANSFER_OUT', 'WORK_ORDER_CONSUME');
$$;

revoke all on function public.is_outbound_movement(text) from public, anon;
grant execute on function public.is_outbound_movement(text) to authenticated, service_role;

create or replace function public.apply_stock_unit_delta(
  p_product_id     bigint,
  p_warehouse_id   bigint,
  p_delta          integer,
  p_bin_id         bigint default null,
  p_lot_id         bigint default null,
  p_serial_id      bigint default null,
  p_status_id      bigint default null,
  p_available_only boolean default false
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
  v_have       integer;
  v_jan        text;
begin
  if coalesce(p_delta, 0) = 0 then
    return 0;
  end if;
  select company_id into v_company_id from public.products where id = p_product_id;
  if v_company_id is null then
    return coalesce(p_delta, 0);
  end if;

  if p_delta > 0 then
    v_status_id := coalesce(p_status_id,
      (select id from public.stock_statuses where code = 'OK'));

    if p_serial_id is not null then
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

  -- §13's refusal. It is checked before anything is drawn, so a shipment that
  -- cannot be satisfied from shippable stock leaves the stock exactly as it was
  -- rather than half-picked.
  if p_available_only then
    select coalesce(sum(su.quantity), 0)::int into v_have
      from public.stock_units su
      join public.stock_statuses st on st.id = su.status_id
     where su.product_id = p_product_id
       and su.warehouse_id = p_warehouse_id
       and st.counts_available
       and (p_bin_id is null or su.bin_id = p_bin_id)
       and (p_lot_id is null or su.lot_id = p_lot_id)
       and (p_serial_id is null or su.serial_id = p_serial_id);
    if v_have < v_left then
      select jan_code into v_jan from public.products where id = p_product_id;
      raise exception
        'only % of % can be shipped (% on hand, the rest is held or failed), cannot take %',
        v_have, coalesce(v_jan, p_product_id::text),
        public.stock_on_hand(p_product_id, p_warehouse_id), v_left;
    end if;
  end if;

  for v_row in
    select su.id, su.quantity
      from public.stock_units su
      join public.stock_statuses st on st.id = su.status_id
      left join public.lots l on l.id = su.lot_id
     where su.product_id = p_product_id
       and su.warehouse_id = p_warehouse_id
       and su.quantity > 0
       and (not p_available_only or st.counts_available)
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

  return -v_left;
end;
$$;

revoke all on function public.apply_stock_unit_delta(bigint, bigint, integer, bigint, bigint, bigint, bigint, boolean)
  from public, anon, authenticated;
grant execute on function public.apply_stock_unit_delta(bigint, bigint, integer, bigint, bigint, bigint, bigint, boolean)
  to service_role;

-- Same reason as in 0066: a seven-argument version left standing beside one whose
-- eighth argument defaults would make every seven-argument call ambiguous.
drop function if exists public.apply_stock_unit_delta(
  bigint, bigint, integer, bigint, bigint, bigint, bigint);

-- The gate is derived from the ledger row, not passed in by the caller. That is
-- deliberate: the rule then covers every path that posts an outbound movement,
-- including ones written later by someone who never read this file.
--
-- A movement that names a status is exempt, because naming QUARANTINE means "I
-- am moving the quarantined stock on purpose" — that is how disposal works.

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
  perform public.apply_stock_unit_delta(
    new.product_id, new.warehouse_id, v_delta,
    null, new.lot_id, new.serial_id, new.status_id,
    v_delta < 0
      and new.status_id is null
      and public.is_outbound_movement(new.movement_type));
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. A status change that can name a parcel
-- ---------------------------------------------------------------------------
--
-- The work moves into an _impl that returns how much it managed to move rather
-- than raising, because its two callers want different things from a shortfall.
-- An operator moving 50 by hand should be told there are not 50. An inspection
-- being closed should not be blocked by a bookkeeping gap it cannot fix from the
-- QC bench — it moves what is there and reports the rest.

create or replace function public.move_stock_status_impl(
  p_product_id   bigint,
  p_warehouse_id bigint,
  p_quantity     integer,
  p_to_status    text,
  p_from_status  text default 'OK',
  p_lot_id       bigint default null,
  p_serial_id    bigint default null,
  p_note         text default null
) returns integer
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_company_id bigint;
  v_from_id    bigint;
  v_to_id      bigint;
  v_left       integer := coalesce(p_quantity, 0);
  v_take       integer;
  v_row        record;
begin
  if v_left <= 0 then
    return 0;
  end if;

  select id into v_from_id from public.stock_statuses
   where code = upper(btrim(coalesce(p_from_status, 'OK')));
  select id into v_to_id from public.stock_statuses
   where code = upper(btrim(coalesce(p_to_status, ''))) and is_active;
  if v_from_id is null then
    raise exception 'unknown stock status %', p_from_status;
  end if;
  if v_to_id is null then
    raise exception 'unknown stock status %', p_to_status;
  end if;
  if v_from_id = v_to_id then
    raise exception 'the stock is already %', upper(btrim(p_to_status));
  end if;

  select company_id into v_company_id from public.products where id = p_product_id;
  if v_company_id is null then
    raise exception 'product % not found', p_product_id;
  end if;

  for v_row in
    select su.id, su.quantity, su.lot_id, su.serial_id, su.bin_id
      from public.stock_units su
      left join public.lots l on l.id = su.lot_id
     where su.product_id = p_product_id and su.warehouse_id = p_warehouse_id
       and su.status_id = v_from_id and su.quantity > 0
       and (p_lot_id is null or su.lot_id = p_lot_id)
       and (p_serial_id is null or su.serial_id = p_serial_id)
     order by l.expiry_date asc nulls last, su.id
  loop
    exit when v_left <= 0;
    v_take := least(v_left, v_row.quantity);

    insert into public.stock_units as su
      (company_id, product_id, warehouse_id, bin_id, lot_id, serial_id,
       status_id, quantity)
    values (v_company_id, p_product_id, p_warehouse_id, v_row.bin_id,
            v_row.lot_id, v_row.serial_id, v_to_id, v_take)
    on conflict (product_id, warehouse_id, bin_id, lot_id, serial_id, status_id)
      do update set quantity = su.quantity + excluded.quantity, updated_at = now();

    update public.stock_units
       set quantity = quantity - v_take, updated_at = now()
     where id = v_row.id;
    v_left := v_left - v_take;
  end loop;

  delete from public.stock_units
   where product_id = p_product_id and warehouse_id = p_warehouse_id
     and quantity = 0 and serial_id is null;

  -- A status change conserves the total, so nothing is posted to the ledger: no
  -- quantity left or entered the warehouse. The audit trail is what records it.
  perform public.log_audit('inventory.status_moved', 'product',
    p_product_id::text, p_warehouse_id,
    jsonb_build_object('quantity', coalesce(p_quantity, 0) - v_left,
                       'requested', p_quantity,
                       'from', upper(btrim(coalesce(p_from_status, 'OK'))),
                       'to', upper(btrim(p_to_status)),
                       'lot_id', p_lot_id, 'serial_id', p_serial_id,
                       'note', p_note));

  return coalesce(p_quantity, 0) - v_left;
end;
$$;

revoke all on function public.move_stock_status_impl(bigint, bigint, integer, text, text, bigint, bigint, text)
  from public, anon, authenticated, service_role;

create or replace function public.move_stock_status(
  p_product_id bigint,
  p_warehouse_id bigint,
  p_quantity integer,
  p_to_status text,
  p_from_status text default 'OK',
  p_note text default null
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_available integer;
  v_moved     integer;
begin
  if not public.has_permission('inventory.adjust') then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if coalesce(p_quantity, 0) <= 0 then
    raise exception 'quantity must be greater than zero';
  end if;

  select coalesce(sum(su.quantity), 0)::int into v_available
    from public.stock_units su
    join public.stock_statuses st on st.id = su.status_id
   where su.product_id = p_product_id and su.warehouse_id = p_warehouse_id
     and st.code = upper(btrim(coalesce(p_from_status, 'OK')));
  if v_available < p_quantity then
    raise exception 'only % in %, cannot move %',
      v_available, upper(btrim(coalesce(p_from_status, 'OK'))), p_quantity;
  end if;

  v_moved := public.move_stock_status_impl(
    p_product_id, p_warehouse_id, p_quantity, p_to_status, p_from_status,
    null, null, p_note);

  return jsonb_build_object(
    'product_id', p_product_id, 'warehouse_id', p_warehouse_id,
    'moved', v_moved,
    'available', public.stock_available(p_product_id, p_warehouse_id));
end;
$$;

revoke all on function public.move_stock_status(bigint, bigint, integer, text, text, text)
  from public, anon;
grant execute on function public.move_stock_status(bigint, bigint, integer, text, text, text)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. Completing an inspection is what releases the stock
-- ---------------------------------------------------------------------------
--
-- The return type changes from the old status text to a report of what actually
-- moved, because "PARTIAL" on its own does not tell an inspector whether the
-- thirty they passed are now sellable. The edge function re-reads the inspection
-- afterwards and never looked at this value, so nothing downstream breaks.

drop function if exists public.complete_inspection(bigint, text);

create or replace function public.complete_inspection(
  p_inspection_id bigint,
  p_note          text default null,
  p_fail_status   text default 'DAMAGED'
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_total     int;
  v_hold      int;
  v_pass      int;
  v_fail      int;
  v_pending   int;
  v_status    text;
  v_warehouse bigint;
  v_to_ok     int := 0;
  v_to_fail   int := 0;
  v_unheld    int := 0;
  v_held      int;
  v_want_ok   int;
  v_want_fail int;
  v_moved     int;
  v_fail_code text := upper(btrim(coalesce(nullif(btrim(coalesce(p_fail_status, '')), ''), 'DAMAGED')));
  it          record;
begin
  select warehouse_id into v_warehouse
    from public.inspections where id = p_inspection_id;
  if v_warehouse is null then
    raise exception 'inspection % not found', p_inspection_id;
  end if;

  select count(*),
         count(*) filter (where result = 'HOLD'),
         count(*) filter (where result = 'PASS'),
         count(*) filter (where result = 'FAIL'),
         count(*) filter (where result = 'PENDING')
    into v_total, v_hold, v_pass, v_fail, v_pending
  from public.inspection_items
  where inspection_id = p_inspection_id;

  if v_total = 0 then
    raise exception 'inspection % has no items', p_inspection_id;
  end if;
  if v_pending > 0 then
    raise exception 'inspection % still has % unchecked item(s)', p_inspection_id, v_pending;
  end if;

  v_status := case
    when v_hold > 0 then 'HOLD'
    when v_pass = v_total then 'PASS'
    when v_fail = v_total then 'FAIL'
    else 'PARTIAL'
  end;

  -- The stock half. Each item names a product and, since 0060, the lot or serial
  -- the inspector was holding, so the release lands on the parcel that was
  -- actually checked rather than on whatever sorts first.
  for it in
    select i.id, i.product_id, i.lot_id, i.serial_id, i.result,
           i.actual_quantity, i.passed_quantity, i.failed_quantity
      from public.inspection_items i
     where i.inspection_id = p_inspection_id
       and i.product_id is not null
     order by i.id
  loop
    -- A client that records only a result and a count, without splitting it,
    -- still means something unambiguous: all of it passed, or all of it failed.
    v_want_ok := it.passed_quantity;
    v_want_fail := it.failed_quantity;
    if v_want_ok = 0 and v_want_fail = 0 then
      if it.result = 'PASS' then
        v_want_ok := it.actual_quantity;
      elsif it.result in ('FAIL', 'HOLD') then
        v_want_fail := it.actual_quantity;
      end if;
    end if;

    select coalesce(sum(su.quantity), 0)::int into v_held
      from public.stock_units su
      join public.stock_statuses st on st.id = su.status_id
     where su.product_id = it.product_id
       and su.warehouse_id = v_warehouse
       and st.code = 'QC_PENDING'
       and (it.lot_id is null or su.lot_id = it.lot_id)
       and (it.serial_id is null or su.serial_id = it.serial_id);

    -- Nothing was held for this item — the product does not require inspection,
    -- or someone released it already. Inspecting stock that was never held is a
    -- legitimate thing to do, so it is reported, not refused.
    if v_held = 0 then
      v_unheld := v_unheld + v_want_ok + v_want_fail;
      continue;
    end if;

    if v_want_ok > 0 then
      v_moved := public.move_stock_status_impl(
        it.product_id, v_warehouse, least(v_want_ok, v_held), 'OK', 'QC_PENDING',
        it.lot_id, it.serial_id,
        format('inspection %s passed', p_inspection_id));
      v_to_ok := v_to_ok + v_moved;
      v_held := v_held - v_moved;
      v_unheld := v_unheld + (v_want_ok - v_moved);
    end if;

    if v_want_fail > 0 then
      v_moved := public.move_stock_status_impl(
        it.product_id, v_warehouse, least(v_want_fail, v_held),
        case when it.result = 'HOLD' then 'HOLD' else v_fail_code end,
        'QC_PENDING', it.lot_id, it.serial_id,
        format('inspection %s failed', p_inspection_id));
      v_to_fail := v_to_fail + v_moved;
      v_unheld := v_unheld + (v_want_fail - v_moved);

      -- A serial that failed is one physical thing that must not ship, and its
      -- own record says so too.
      if it.serial_id is not null and v_moved > 0 then
        update public.serial_numbers set status = 'HOLD', updated_at = now()
         where id = it.serial_id;
      end if;
    end if;
  end loop;

  update public.inspections
     set status = v_status,
         note = coalesce(p_note, note),
         inspector_user_id = coalesce(inspector_user_id, auth.uid()),
         completed_at = now()
   where id = p_inspection_id;

  perform public.log_audit(
    'inspection.confirmed', 'inspection', p_inspection_id::text, v_warehouse,
    jsonb_build_object('status', v_status, 'items', v_total,
                       'released_to_ok', v_to_ok,
                       'held_as', v_fail_code, 'held_quantity', v_to_fail,
                       'not_in_qc_pending', v_unheld));

  return jsonb_build_object(
    'inspection_id', p_inspection_id,
    'status', v_status,
    'items', v_total,
    'released_to_ok', v_to_ok,
    'failed_to', v_fail_code,
    'failed_quantity', v_to_fail,
    -- Quantity the inspection judged that was not sitting in QC_PENDING to be
    -- moved. Non-zero is not an error; it means those goods were never held.
    'not_in_qc_pending', v_unheld);
end;
$$;

revoke all on function public.complete_inspection(bigint, text, text)
  from public, anon, authenticated;
grant execute on function public.complete_inspection(bigint, text, text) to service_role;

-- ---------------------------------------------------------------------------
-- 6. What is waiting for QC
-- ---------------------------------------------------------------------------

create or replace function public.qc_pending_stock(p_warehouse_id bigint default null)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
begin
  if not (public.has_permission('inspection.view') or public.has_permission('inventory.view')) then
    raise exception 'not permitted: inspection.view required';
  end if;
  if p_warehouse_id is not null and not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'product_id', su.product_id,
      'jan_code', p.jan_code,
      'product_name', p.name,
      'warehouse_id', su.warehouse_id,
      'lot_id', su.lot_id,
      'lot_code', l.lot_code,
      'expiry', l.expiry_date,
      'serial_id', su.serial_id,
      'serial_number', sn.serial_number,
      'quantity', su.quantity,
      'status_code', st.code,
      -- So the floor can go from "this is held" to "who sent it" in one tap.
      'received_at', (select max(ri.created_at) from public.receipt_items ri
                       where ri.product_id = su.product_id
                         and ri.warehouse_id = su.warehouse_id
                         and (su.lot_id is null or ri.lot_id = su.lot_id))
    ) order by l.expiry_date asc nulls last, p.jan_code)
    from public.stock_units su
    join public.stock_statuses st on st.id = su.status_id
    join public.products p on p.id = su.product_id
    left join public.lots l on l.id = su.lot_id
    left join public.serial_numbers sn on sn.id = su.serial_id
   where st.code = 'QC_PENDING'
     and su.quantity > 0
     and (p_warehouse_id is null or su.warehouse_id = p_warehouse_id)
     and public.can_access_warehouse(su.warehouse_id)), '[]'::jsonb);
end;
$$;

revoke all on function public.qc_pending_stock(bigint) from public, anon;
grant execute on function public.qc_pending_stock(bigint) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 7. Housekeeping
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
