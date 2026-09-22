-- 0076 — Phase C: §17's cartons, weight, dimensions and label
--
-- §17 asks for "どの商品がどの箱に入ったか" — which product went into which box —
-- and lists what a carton should carry:
--
--     cartons      id, shipment_id, carton_number, carton_type, weight,
--                  length, width, height, tracking_number, status
--     carton_items carton_id, product_id, lot_id, serial_id, quantity
--
-- What existed: `shipment_cartons` (0008) held a number and a free-text label;
-- `shipment_carton_items` held a JAN and a quantity. Weight, carrier and tracking
-- lived on the *plan* (0039), which is fine for a single-box shipment and wrong
-- for three — a carrier prices each box, so weight and dimensions belong on the
-- box. And a carton item with no lot cannot answer §17's question at all: a
-- recall needs "lot L-B went to this customer in carton 2", not "something went
-- in carton 2".
--
-- DESIGN
--
--   * **Carton status is a lifecycle, and the plan drives its end.** OPEN while
--     being filled, PACKED when the packer closes it, SHIPPED once the plan
--     ships. That last transition is a trigger on `shipment_plans.status` rather
--     than a line in `ship_plan`, because shipping is reached from more than one
--     place (the edge function updates the plan, `ship_plan` updates the plan)
--     and a rule that lives on the column cannot be bypassed by whichever path
--     is taken next year. Un-shipping puts SHIPPED cartons back to PACKED.
--
--   * **You cannot pack more of a product than was picked.** The ceiling is per
--     product, not per (product, lot): a picker who keys a bare quantity records
--     no parcels at all (0074 keeps that path deliberately), and capping per
--     identity would refuse a perfectly ordinary pack of a lot that was picked
--     without being scanned. Per product is the check that is always meaningful
--     — nothing goes in a box that did not come off a shelf — and the plan's own
--     lines stand in when a shipment never went through picking.
--
--   * **Measurements are set, not accumulated.** `set_carton_measurements`
--     replaces what it is given and treats null as "clear this", the same
--     decision 0039 made for the plan's logistics fields, so a mistyped weight
--     can be taken back out rather than only overwritten.
--
--   * **The label is a read, not a stored document.** `carton_label` returns
--     everything a label needs — who it is going to, carton n of m, tracking,
--     weight, and what is inside — and the client renders it. A label stored at
--     pack time would be a copy that silently goes stale the moment a tracking
--     number is corrected.

-- ---------------------------------------------------------------------------
-- 1. The carton, grown up
-- ---------------------------------------------------------------------------

alter table public.shipment_cartons
  add column if not exists carton_type     text,
  add column if not exists weight_kg       numeric(10,3),
  add column if not exists length_cm       numeric(8,1),
  add column if not exists width_cm        numeric(8,1),
  add column if not exists height_cm       numeric(8,1),
  add column if not exists tracking_number text,
  add column if not exists status          text not null default 'OPEN',
  add column if not exists note            text,
  add column if not exists packed_at       timestamptz,
  add column if not exists packed_by       uuid references public.app_users(id);

do $$
begin
  if not exists (select 1 from pg_constraint
                  where conname = 'shipment_cartons_status_check') then
    alter table public.shipment_cartons
      add constraint shipment_cartons_status_check
      check (status in ('OPEN', 'PACKED', 'SHIPPED', 'CANCELLED'));
  end if;
  if not exists (select 1 from pg_constraint
                  where conname = 'shipment_cartons_measurements_check') then
    alter table public.shipment_cartons
      add constraint shipment_cartons_measurements_check
      check (coalesce(weight_kg, 0) >= 0 and coalesce(length_cm, 0) >= 0
             and coalesce(width_cm, 0) >= 0 and coalesce(height_cm, 0) >= 0);
  end if;
end $$;

-- Two cartons numbered 2 in one shipment is a packing slip nobody can reconcile.
create unique index if not exists shipment_cartons_plan_no_key
  on public.shipment_cartons (shipment_plan_id, carton_no);

create index if not exists shipment_cartons_status_idx
  on public.shipment_cartons (shipment_plan_id, status);

-- §17's identity on the contents. Composite FKs, so a lot or serial named here
-- has to belong to the product on the same row — the same shape 0067 used for
-- receipt items and 0074 for pick items.
alter table public.shipment_carton_items
  add column if not exists lot_id        bigint,
  add column if not exists serial_id     bigint,
  add column if not exists stock_unit_id bigint references public.stock_units(id)
                                           on delete set null,
  add column if not exists note          text;

do $$
begin
  if not exists (select 1 from pg_constraint
                  where conname = 'shipment_carton_items_lot_fk') then
    alter table public.shipment_carton_items
      add constraint shipment_carton_items_lot_fk
      foreign key (product_id, lot_id)
      references public.lots (product_id, id) on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint
                  where conname = 'shipment_carton_items_serial_fk') then
    alter table public.shipment_carton_items
      add constraint shipment_carton_items_serial_fk
      foreign key (product_id, serial_id)
      references public.serial_numbers (product_id, id) on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint
                  where conname = 'shipment_carton_items_serial_quantity_check') then
    alter table public.shipment_carton_items
      add constraint shipment_carton_items_serial_quantity_check
      check (serial_id is null or quantity = 1);
  end if;
end $$;

create index if not exists shipment_carton_items_lot_idx
  on public.shipment_carton_items (lot_id) where lot_id is not null;

-- ---------------------------------------------------------------------------
-- 2. The plan's status drives the carton's last transition
-- ---------------------------------------------------------------------------

create or replace function public.sync_carton_status_with_plan()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
begin
  if new.status = 'shipped' and coalesce(old.status, '') <> 'shipped' then
    update public.shipment_cartons
       set status = 'SHIPPED'
     where shipment_plan_id = new.id and status in ('OPEN', 'PACKED');
  elsif old.status = 'shipped' and new.status <> 'shipped' then
    -- Un-shipped: a box that was closed is closed again, not re-opened. Whoever
    -- needs to change its contents says so explicitly.
    update public.shipment_cartons
       set status = 'PACKED'
     where shipment_plan_id = new.id and status = 'SHIPPED';
  end if;
  return null;
end;
$$;

revoke all on function public.sync_carton_status_with_plan()
  from public, anon, authenticated;

drop trigger if exists shipment_plans_sync_cartons on public.shipment_plans;
create trigger shipment_plans_sync_cartons
  after update of status on public.shipment_plans
  for each row execute function public.sync_carton_status_with_plan();

-- ---------------------------------------------------------------------------
-- 3. Packing
-- ---------------------------------------------------------------------------

-- How much of one product this shipment may put in boxes: what was picked when
-- it went through picking, otherwise what was ordered. See the header for why
-- this is per product rather than per lot.
--
-- Note the consequence of preferring the pick list: once picking has *started*,
-- a task with nothing picked yet contributes zero, so packing that product is
-- refused until the pick is recorded. That is the intended reading of "nothing
-- goes in a box that did not come off a shelf" — the alternative is packing
-- against an order line while the shelf it came from is still undecided.
create or replace function public.packable_quantity(
  p_plan_id bigint,
  p_product_id bigint
) returns integer
language sql
stable
security definer
set search_path to ''
as $$
  select coalesce(
    (select sum(coalesce(t.picked_quantity, 0))::int
       from public.pick_tasks t
       join public.pick_lists l on l.id = t.pick_list_id
      where l.shipment_plan_id = p_plan_id
        and l.status <> 'CANCELLED'
        and coalesce(t.product_id, public.product_for_jan(t.jan_code)) = p_product_id
      having count(*) > 0),
    (select sum(coalesce(sl.quantity, 0))::int
       from public.shipment_lines sl
      where sl.shipment_plan_id = p_plan_id
        and coalesce(sl.product_id, public.product_for_jan(sl.jan_code)) = p_product_id),
    0);
$$;

revoke all on function public.packable_quantity(bigint, bigint) from public, anon;
grant execute on function public.packable_quantity(bigint, bigint)
  to authenticated, service_role;

create or replace function public.create_carton(
  p_plan_id     bigint,
  p_carton_type text default null,
  p_note        text default null
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_status text;
  v_warehouse bigint;
  v_no int;
  v_id bigint;
begin
  if not public.has_permission('pack.complete') then
    raise exception 'not permitted: pack.complete required';
  end if;

  select status, warehouse_id into v_status, v_warehouse
    from public.shipment_plans where id = p_plan_id;
  if v_status is null then raise exception 'shipment % not found', p_plan_id; end if;
  if v_warehouse is not null and not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_status not in ('open', 'packing') then
    raise exception 'shipment % is % and cannot be packed', p_plan_id, v_status;
  end if;

  select coalesce(max(carton_no), 0) + 1 into v_no
    from public.shipment_cartons where shipment_plan_id = p_plan_id;

  insert into public.shipment_cartons (shipment_plan_id, carton_no, carton_type, note)
  values (p_plan_id, v_no, nullif(btrim(coalesce(p_carton_type, '')), ''),
          nullif(btrim(coalesce(p_note, '')), ''))
  returning id into v_id;

  update public.shipment_plans set status = 'packing'
   where id = p_plan_id and status = 'open';

  perform public.log_audit('shipment.carton_created', 'shipment_carton', v_id::text,
    v_warehouse, jsonb_build_object('shipment_plan_id', p_plan_id, 'carton_no', v_no));

  return jsonb_build_object('carton_id', v_id, 'carton_no', v_no,
                            'shipment_plan_id', p_plan_id, 'status', 'OPEN');
end;
$$;

revoke all on function public.create_carton(bigint, text, text) from public, anon;
grant execute on function public.create_carton(bigint, text, text)
  to authenticated, service_role;

-- Putting something in a box, with the identity that makes §17's question
-- answerable. A `stock_unit_id` fills the lot, serial and product from the parcel
-- itself, the same courtesy `record_pick_item` does.
create or replace function public.pack_carton_item(
  p_carton_id     bigint,
  p_quantity      integer,
  p_jan_code      text default null,
  p_lot_code      text default null,
  p_serial_number text default null,
  p_stock_unit_id bigint default null,
  p_note          text default null
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_plan bigint;
  v_carton_status text;
  v_plan_status text;
  v_warehouse bigint;
  v_product bigint;
  v_jan text := nullif(btrim(coalesce(p_jan_code, '')), '');
  v_name text;
  v_lot bigint;
  v_serial bigint;
  v_unit record;
  v_line bigint;
  v_packable integer;
  v_packed integer;
  v_id bigint;
begin
  if not public.has_permission('pack.complete') then
    raise exception 'not permitted: pack.complete required';
  end if;
  if coalesce(p_quantity, 0) <= 0 then
    raise exception 'quantity must be greater than zero';
  end if;

  select c.shipment_plan_id, c.status, p.status, p.warehouse_id
    into v_plan, v_carton_status, v_plan_status, v_warehouse
    from public.shipment_cartons c
    join public.shipment_plans p on p.id = c.shipment_plan_id
   where c.id = p_carton_id;
  if v_plan is null then raise exception 'carton % not found', p_carton_id; end if;
  if v_warehouse is not null and not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_carton_status <> 'OPEN' then
    raise exception 'carton % is % — reopen it before changing what is inside',
      p_carton_id, v_carton_status;
  end if;
  if v_plan_status not in ('open', 'packing') then
    raise exception 'shipment % is % and cannot be packed', v_plan, v_plan_status;
  end if;

  if p_stock_unit_id is not null then
    select * into v_unit from public.stock_units where id = p_stock_unit_id;
    if v_unit.id is null then
      raise exception 'stock unit % not found', p_stock_unit_id;
    end if;
    v_product := v_unit.product_id;
    v_lot := v_unit.lot_id;
    v_serial := v_unit.serial_id;
  end if;

  if v_product is null then
    if v_jan is null then
      raise exception 'a JAN or a stock unit is required';
    end if;
    v_product := public.product_for_jan(v_jan);
    if v_product is null then
      raise exception 'no product is registered for JAN %', v_jan;
    end if;
  end if;

  select jan_code, name into v_jan, v_name from public.products where id = v_product;

  if nullif(btrim(coalesce(p_lot_code, '')), '') is not null then
    select id into v_lot from public.lots
     where product_id = v_product and lot_code = btrim(p_lot_code);
    if v_lot is null then
      raise exception 'lot % is not a lot of this product', p_lot_code;
    end if;
  end if;
  if nullif(btrim(coalesce(p_serial_number, '')), '') is not null then
    select id into v_serial from public.serial_numbers
     where product_id = v_product and serial_number = btrim(p_serial_number);
    if v_serial is null then
      raise exception 'serial % is not a serial of this product', p_serial_number;
    end if;
  end if;

  -- Nothing goes in a box that did not come off a shelf.
  v_packable := public.packable_quantity(v_plan, v_product);
  select coalesce(sum(i.quantity), 0)::int into v_packed
    from public.shipment_carton_items i
    join public.shipment_cartons c on c.id = i.carton_id
   where c.shipment_plan_id = v_plan
     and c.status <> 'CANCELLED'
     and coalesce(i.product_id, public.product_for_jan(i.jan_code)) = v_product;
  if v_packed + p_quantity > v_packable then
    raise exception
      '% was picked for % and % is already packed; cannot pack % more',
      v_packable, coalesce(v_jan, v_product::text), v_packed, p_quantity;
  end if;

  -- Keep the line reference the old reads rely on when one is obvious.
  select id into v_line from public.shipment_lines
   where shipment_plan_id = v_plan
     and coalesce(product_id, public.product_for_jan(jan_code)) = v_product
   order by id limit 1;

  insert into public.shipment_carton_items (
    carton_id, shipment_line_id, jan_code, product_name, quantity,
    product_id, lot_id, serial_id, stock_unit_id, note)
  values (p_carton_id, v_line, v_jan, coalesce(v_name, ''), p_quantity,
          v_product, v_lot, v_serial, p_stock_unit_id,
          nullif(btrim(coalesce(p_note, '')), ''))
  returning id into v_id;

  perform public.log_audit('shipment.carton_packed', 'shipment_carton',
    p_carton_id::text, v_warehouse, jsonb_build_object(
      'carton_item_id', v_id, 'product_id', v_product, 'quantity', p_quantity,
      'lot_id', v_lot, 'serial_id', v_serial));

  return jsonb_build_object(
    'carton_item_id', v_id,
    'carton_id', p_carton_id,
    'product_id', v_product,
    'jan_code', v_jan,
    'lot_id', v_lot,
    'serial_id', v_serial,
    'quantity', p_quantity,
    'packed_total', v_packed + p_quantity,
    'packable', v_packable,
    'unpacked', v_packable - (v_packed + p_quantity));
end;
$$;

revoke all on function public.pack_carton_item(bigint, integer, text, text, text, bigint, text)
  from public, anon;
grant execute on function public.pack_carton_item(bigint, integer, text, text, text, bigint, text)
  to authenticated, service_role;

create or replace function public.remove_carton_item(p_item_id bigint)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_carton bigint;
  v_carton_status text;
  v_warehouse bigint;
begin
  if not public.has_permission('pack.complete') then
    raise exception 'not permitted: pack.complete required';
  end if;

  select i.carton_id, c.status, p.warehouse_id
    into v_carton, v_carton_status, v_warehouse
    from public.shipment_carton_items i
    join public.shipment_cartons c on c.id = i.carton_id
    join public.shipment_plans p on p.id = c.shipment_plan_id
   where i.id = p_item_id;
  if v_carton is null then raise exception 'carton item % not found', p_item_id; end if;
  if v_warehouse is not null and not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_carton_status <> 'OPEN' then
    raise exception 'carton % is % — reopen it before changing what is inside',
      v_carton, v_carton_status;
  end if;

  delete from public.shipment_carton_items where id = p_item_id;

  perform public.log_audit('shipment.carton_item_removed', 'shipment_carton',
    v_carton::text, v_warehouse, jsonb_build_object('carton_item_id', p_item_id));

  return jsonb_build_object('carton_id', v_carton, 'carton_item_id', p_item_id);
end;
$$;

revoke all on function public.remove_carton_item(bigint) from public, anon;
grant execute on function public.remove_carton_item(bigint) to authenticated, service_role;

-- Weight, dimensions, type and tracking — per box, because that is what a
-- carrier prices. Null clears a field, so a mistyped weight can be taken back
-- out (0039's own decision for the plan-level fields).
create or replace function public.set_carton_measurements(
  p_carton_id       bigint,
  p_weight_kg       numeric default null,
  p_length_cm       numeric default null,
  p_width_cm        numeric default null,
  p_height_cm       numeric default null,
  p_carton_type     text default null,
  p_tracking_number text default null
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_warehouse bigint;
  v_status text;
begin
  if not public.has_permission('pack.complete') then
    raise exception 'not permitted: pack.complete required';
  end if;

  select p.warehouse_id, c.status into v_warehouse, v_status
    from public.shipment_cartons c
    join public.shipment_plans p on p.id = c.shipment_plan_id
   where c.id = p_carton_id;
  if v_status is null then raise exception 'carton % not found', p_carton_id; end if;
  if v_warehouse is not null and not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_status = 'CANCELLED' then
    raise exception 'carton % is cancelled', p_carton_id;
  end if;
  if coalesce(p_weight_kg, 0) < 0 then
    raise exception 'weight cannot be negative';
  end if;

  -- A closed or shipped box can still have its weight and tracking corrected:
  -- those are facts about the box, not about what is inside it.
  update public.shipment_cartons
     set weight_kg       = p_weight_kg,
         length_cm       = p_length_cm,
         width_cm        = p_width_cm,
         height_cm       = p_height_cm,
         carton_type     = nullif(btrim(coalesce(p_carton_type, '')), ''),
         tracking_number = nullif(btrim(coalesce(p_tracking_number, '')), '')
   where id = p_carton_id;

  perform public.log_audit('shipment.carton_measured', 'shipment_carton',
    p_carton_id::text, v_warehouse, jsonb_build_object(
      'weight_kg', p_weight_kg, 'length_cm', p_length_cm, 'width_cm', p_width_cm,
      'height_cm', p_height_cm, 'carton_type', p_carton_type,
      'tracking_number', p_tracking_number));

  return public.carton_detail(p_carton_id);
end;
$$;

revoke all on function public.set_carton_measurements(
  bigint, numeric, numeric, numeric, numeric, text, text) from public, anon;
grant execute on function public.set_carton_measurements(
  bigint, numeric, numeric, numeric, numeric, text, text) to authenticated, service_role;

create or replace function public.close_carton(p_carton_id bigint)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_warehouse bigint;
  v_status text;
  v_items integer;
begin
  if not public.has_permission('pack.complete') then
    raise exception 'not permitted: pack.complete required';
  end if;

  select p.warehouse_id, c.status into v_warehouse, v_status
    from public.shipment_cartons c
    join public.shipment_plans p on p.id = c.shipment_plan_id
   where c.id = p_carton_id;
  if v_status is null then raise exception 'carton % not found', p_carton_id; end if;
  if v_warehouse is not null and not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_status <> 'OPEN' then
    raise exception 'carton % is already %', p_carton_id, v_status;
  end if;

  select count(*) into v_items from public.shipment_carton_items
   where carton_id = p_carton_id;
  -- An empty closed box would appear on the packing slip and in the carton
  -- count, and there is nothing in it.
  if v_items = 0 then
    raise exception 'carton % is empty; put something in it or delete it', p_carton_id;
  end if;

  update public.shipment_cartons
     set status = 'PACKED', packed_at = now(), packed_by = auth.uid()
   where id = p_carton_id;

  perform public.log_audit('shipment.carton_closed', 'shipment_carton',
    p_carton_id::text, v_warehouse, jsonb_build_object('items', v_items));

  return public.carton_detail(p_carton_id);
end;
$$;

revoke all on function public.close_carton(bigint) from public, anon;
grant execute on function public.close_carton(bigint) to authenticated, service_role;

create or replace function public.reopen_carton(p_carton_id bigint)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_warehouse bigint;
  v_status text;
  v_plan_status text;
begin
  if not public.has_permission('pack.complete') then
    raise exception 'not permitted: pack.complete required';
  end if;

  select p.warehouse_id, c.status, p.status
    into v_warehouse, v_status, v_plan_status
    from public.shipment_cartons c
    join public.shipment_plans p on p.id = c.shipment_plan_id
   where c.id = p_carton_id;
  if v_status is null then raise exception 'carton % not found', p_carton_id; end if;
  if v_warehouse is not null and not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_plan_status = 'shipped' then
    raise exception
      'this shipment has already shipped; cancel the shipment before reopening a box';
  end if;
  if v_status = 'CANCELLED' then
    raise exception 'carton % is cancelled', p_carton_id;
  end if;

  update public.shipment_cartons
     set status = 'OPEN', packed_at = null, packed_by = null
   where id = p_carton_id;

  perform public.log_audit('shipment.carton_reopened', 'shipment_carton',
    p_carton_id::text, v_warehouse, jsonb_build_object('was', v_status));

  return public.carton_detail(p_carton_id);
end;
$$;

revoke all on function public.reopen_carton(bigint) from public, anon;
grant execute on function public.reopen_carton(bigint) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. Reading it
-- ---------------------------------------------------------------------------

create or replace function public.carton_detail(p_carton_id bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
declare
  v_warehouse bigint;
begin
  select p.warehouse_id into v_warehouse
    from public.shipment_cartons c
    join public.shipment_plans p on p.id = c.shipment_plan_id
   where c.id = p_carton_id;
  if not found then raise exception 'carton % not found', p_carton_id; end if;
  if v_warehouse is not null and not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  return (
    select jsonb_build_object(
      'id', c.id,
      'shipment_plan_id', c.shipment_plan_id,
      'carton_no', c.carton_no,
      'carton_type', c.carton_type,
      'status', c.status,
      'weight_kg', c.weight_kg,
      'length_cm', c.length_cm,
      'width_cm', c.width_cm,
      'height_cm', c.height_cm,
      'tracking_number', c.tracking_number,
      'label', c.label,
      'note', c.note,
      'packed_at', c.packed_at,
      'created_at', c.created_at,
      'total_units', coalesce((select sum(i.quantity) from public.shipment_carton_items i
                                where i.carton_id = c.id), 0),
      'items', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'id', i.id,
                 'jan_code', i.jan_code,
                 'product_id', i.product_id,
                 'product_name', i.product_name,
                 'quantity', i.quantity,
                 'lot_id', i.lot_id,
                 'lot_code', l.lot_code,
                 'expiry_date', l.expiry_date,
                 'serial_id', i.serial_id,
                 'serial_number', sn.serial_number,
                 'note', i.note) order by i.id)
          from public.shipment_carton_items i
          left join public.lots l on l.id = i.lot_id
          left join public.serial_numbers sn on sn.id = i.serial_id
         where i.carton_id = c.id), '[]'::jsonb))
    from public.shipment_cartons c
   where c.id = p_carton_id);
end;
$$;

revoke all on function public.carton_detail(bigint) from public, anon;
grant execute on function public.carton_detail(bigint) to authenticated, service_role;

-- What the packing screen needs: how much of each product is still waiting for a
-- box, and the boxes so far. `unpacked` is the number that decides whether
-- packing is finished, so it is stated per product rather than left to be
-- derived from two lists.
create or replace function public.shipment_packing(p_plan_id bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
declare
  v_warehouse bigint;
  v_found boolean;
begin
  select warehouse_id, true into v_warehouse, v_found
    from public.shipment_plans where id = p_plan_id;
  if not coalesce(v_found, false) then
    raise exception 'shipment % not found', p_plan_id;
  end if;
  if v_warehouse is not null and not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  return jsonb_build_object(
    'shipment_plan_id', p_plan_id,
    'lines', coalesce((
      select jsonb_agg(x order by x->>'jan_code')
        from (
          select jsonb_build_object(
                   'product_id', q.product_id,
                   'jan_code', q.jan_code,
                   'product_name', q.product_name,
                   'packable', public.packable_quantity(p_plan_id, q.product_id),
                   'packed', q.packed,
                   'unpacked', public.packable_quantity(p_plan_id, q.product_id) - q.packed) as x
            from (
              select sl.product_id,
                     max(sl.jan_code) as jan_code,
                     coalesce(max(nullif(sl.product_name, '')), '') as product_name,
                     coalesce((
                       select sum(i.quantity)::int
                         from public.shipment_carton_items i
                         join public.shipment_cartons c on c.id = i.carton_id
                        where c.shipment_plan_id = p_plan_id
                          and c.status <> 'CANCELLED'
                          and i.product_id = sl.product_id), 0) as packed
                from public.shipment_lines sl
               where sl.shipment_plan_id = p_plan_id and sl.product_id is not null
               group by sl.product_id
            ) q
        ) y), '[]'::jsonb),
    'cartons', coalesce((
      select jsonb_agg(public.carton_detail(c.id) order by c.carton_no)
        from public.shipment_cartons c
       where c.shipment_plan_id = p_plan_id), '[]'::jsonb));
end;
$$;

revoke all on function public.shipment_packing(bigint) from public, anon;
grant execute on function public.shipment_packing(bigint) to authenticated, service_role;

-- Everything a label needs, in one read. Not stored at pack time: a stored label
-- is a copy that goes stale the moment a tracking number is corrected.
create or replace function public.carton_label(p_carton_id bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
declare
  v_warehouse bigint;
  v_plan bigint;
begin
  select p.warehouse_id, p.id into v_warehouse, v_plan
    from public.shipment_cartons c
    join public.shipment_plans p on p.id = c.shipment_plan_id
   where c.id = p_carton_id;
  if v_plan is null then raise exception 'carton % not found', p_carton_id; end if;
  if v_warehouse is not null and not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  return (
    select jsonb_build_object(
      'carton_id', c.id,
      'carton_no', c.carton_no,
      -- "2 / 5" on the box, which is the whole reason a packer counts boxes.
      'carton_count', (select count(*) from public.shipment_cartons x
                        where x.shipment_plan_id = c.shipment_plan_id
                          and x.status <> 'CANCELLED'),
      'shipment_plan_id', p.id,
      'shipment_number', p.shipment_number,
      'customer_name', p.customer_name,
      'customer_code', p.customer_code,
      'ship_date', p.ship_date,
      'warehouse_name', w.name,
      'carrier', p.carrier,
      -- The box's own tracking number where it has one, the plan's otherwise:
      -- a single-parcel shipment usually carries it on the plan (0039).
      'tracking_number', coalesce(c.tracking_number, p.tracking_number),
      'carton_type', c.carton_type,
      'weight_kg', c.weight_kg,
      'length_cm', c.length_cm,
      'width_cm', c.width_cm,
      'height_cm', c.height_cm,
      'status', c.status,
      'total_units', coalesce((select sum(i.quantity) from public.shipment_carton_items i
                                where i.carton_id = c.id), 0),
      'contents', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'jan_code', i.jan_code,
                 'product_name', i.product_name,
                 'quantity', i.quantity,
                 'lot_code', l.lot_code,
                 'serial_number', sn.serial_number) order by i.id)
          from public.shipment_carton_items i
          left join public.lots l on l.id = i.lot_id
          left join public.serial_numbers sn on sn.id = i.serial_id
         where i.carton_id = c.id), '[]'::jsonb))
    from public.shipment_cartons c
    join public.shipment_plans p on p.id = c.shipment_plan_id
    left join public.warehouses w on w.id = p.warehouse_id
   where c.id = p_carton_id);
end;
$$;

revoke all on function public.carton_label(bigint) from public, anon;
grant execute on function public.carton_label(bigint) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. Autopack, now from what was picked
-- ---------------------------------------------------------------------------
--
-- 0039 split the *order lines* into boxes. Once the picker has recorded parcels,
-- the order lines are the wrong source: they cannot say which lot went in which
-- box, which is §17's whole question. So this fills from `pick_items` when a
-- pick list has them, and falls back to the lines exactly as before when it does
-- not — the same two-source rule `ship_plan` follows.

create or replace function public.autopack_shipment(
  p_plan_id          bigint,
  p_units_per_carton int
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_status      text;
  v_warehouse   bigint;
  v_total       int := 0;
  v_carton_id   bigint;
  v_carton_no   int := 0;
  v_room        int := 0;
  v_take        int;
  v_remaining   int;
  v_from_picks  boolean;
  r             record;
begin
  if not public.has_permission('pack.complete') then
    raise exception 'permission denied: pack.complete';
  end if;
  if p_units_per_carton is null or p_units_per_carton <= 0 then
    raise exception 'units per carton must be at least 1';
  end if;

  select status, warehouse_id into v_status, v_warehouse
    from public.shipment_plans where id = p_plan_id;
  if v_status is null then
    raise exception 'shipment % not found', p_plan_id;
  end if;
  if v_warehouse is not null and not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_status not in ('open', 'packing') then
    raise exception 'shipment % is % and cannot be packed', p_plan_id, v_status;
  end if;
  -- Refuses rather than merging: re-packing a half-packed shipment silently is
  -- the kind of quiet data change the packer should be the one to decide about.
  if exists (select 1 from public.shipment_cartons
              where shipment_plan_id = p_plan_id) then
    raise exception 'shipment % already has cartons; delete them first', p_plan_id;
  end if;

  v_from_picks := exists (
    select 1 from public.pick_items i
      join public.pick_tasks t on t.id = i.pick_task_id
      join public.pick_lists l on l.id = t.pick_list_id
     where l.shipment_plan_id = p_plan_id and l.status <> 'CANCELLED');

  for r in
    select * from (
      -- Picked parcels, so each box records the lot it holds.
      select i.product_id, i.jan_code, i.product_name, i.spec,
             i.lot_id, i.serial_id, i.stock_unit_id, i.quantity, i.sort
        from (
          select pi.product_id,
                 coalesce(pr.jan_code, t.jan_code) as jan_code,
                 coalesce(nullif(t.product_name, ''), pr.name, '') as product_name,
                 null::text as spec,
                 pi.lot_id, pi.serial_id,
                 min(pi.stock_unit_id) as stock_unit_id,
                 sum(pi.quantity)::int as quantity,
                 min(t.id) as sort
            from public.pick_items pi
            join public.pick_tasks t on t.id = pi.pick_task_id
            join public.pick_lists l on l.id = t.pick_list_id
            left join public.products pr on pr.id = pi.product_id
           where v_from_picks and l.shipment_plan_id = p_plan_id
             and l.status <> 'CANCELLED'
           group by pi.product_id, coalesce(pr.jan_code, t.jan_code),
                    coalesce(nullif(t.product_name, ''), pr.name, ''),
                    pi.lot_id, pi.serial_id
        ) i
      union all
      select sl.product_id, sl.jan_code, coalesce(sl.product_name, ''), sl.spec,
             null::bigint, null::bigint, null::bigint, sl.quantity, sl.id
        from public.shipment_lines sl
       where not v_from_picks and sl.shipment_plan_id = p_plan_id
         and coalesce(sl.quantity, 0) > 0
    ) q
    where q.quantity > 0
    order by q.sort, q.jan_code, q.lot_id
  loop
    v_remaining := r.quantity;
    v_total := v_total + r.quantity;
    while v_remaining > 0 loop
      if v_room <= 0 then
        v_carton_no := v_carton_no + 1;
        insert into public.shipment_cartons (shipment_plan_id, carton_no)
        values (p_plan_id, v_carton_no)
        returning id into v_carton_id;
        v_room := p_units_per_carton;
      end if;
      v_take := least(v_room, v_remaining);
      insert into public.shipment_carton_items
        (carton_id, jan_code, product_name, spec, quantity,
         product_id, lot_id, serial_id, stock_unit_id, shipment_line_id)
      values (v_carton_id, r.jan_code, r.product_name, r.spec, v_take,
              r.product_id, r.lot_id, r.serial_id, r.stock_unit_id,
              (select id from public.shipment_lines sl
                where sl.shipment_plan_id = p_plan_id
                  and coalesce(sl.product_id, public.product_for_jan(sl.jan_code))
                      = r.product_id
                order by sl.id limit 1));
      v_room := v_room - v_take;
      v_remaining := v_remaining - v_take;
    end loop;
  end loop;

  if v_total = 0 then
    raise exception 'shipment % has nothing to pack', p_plan_id;
  end if;

  update public.shipment_plans set status = 'packing'
   where id = p_plan_id and status = 'open';

  perform public.log_audit('shipment.autopacked', 'shipment_plan',
    p_plan_id::text, v_warehouse,
    jsonb_build_object('cartons', v_carton_no,
                       'units_per_carton', p_units_per_carton,
                       'total_units', v_total,
                       'from_picked_parcels', v_from_picks));

  return jsonb_build_object(
    'shipment_plan_id', p_plan_id,
    'carton_count', v_carton_no,
    'units_per_carton', p_units_per_carton,
    'total_units', v_total,
    -- Says which source it used, because "why does my carton have no lot on it"
    -- is otherwise a mystery from the outside.
    'from_picked_parcels', v_from_picks);
end;
$$;

revoke all on function public.autopack_shipment(bigint, int) from public, anon;
grant execute on function public.autopack_shipment(bigint, int) to authenticated, service_role;
