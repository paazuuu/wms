-- 0074 — Phase C: §16's picking rule, and §15's pick detail
--
-- §15 says a pick task carries `stock/lot/serial` and a `source_bin`. Ours
-- carried a JAN and a quantity. So a picker was told "40 of this product" and
-- the ledger later decided for itself which lot left the building — FEFO, via
-- 0068's draw order. That is a good default and the wrong answer whenever
-- reality differs: if the front carton of the soonest-expiring lot is crushed
-- and the picker takes the next one, nothing recorded that, and the lot the
-- system believes it shipped is not the lot the customer received. For a recall
-- that distinction is the whole point of tracking lots at all.
--
-- §16 asks for FIFO / FEFO / LIFO / MANUAL per product and warehouse.
--
-- THE SHAPE, AND WHY IT MIRRORS RECEIVING
--
-- Phase B solved the same problem on the way in. A delivery line said "40" and
-- `receipt_items` (0067) recorded which parcels those 40 actually were. This is
-- that, outbound:
--
--     shipment_line  ->  pick_task   (how much to pick — the order)
--     receipt_items  ->  pick_items  (which parcels it actually was — the fact)
--
-- `pick_items` is optional detail on top of the task's total, exactly as parcels
-- are on a receipt: a picker who just keys 40 still closes the task, and one who
-- scans lots gets a traceable pick. `picked_quantity` stays the task's total, so
-- the generated `variance` and `status` columns from 0018 keep working and no
-- existing caller changes.
--
-- WHAT DELIBERATELY DOES NOT HAPPEN
--
-- **No stock moves here.** 0018 was right: picking is a state of the order, and
-- the building's stock is unchanged until it ships. `pick_items` records what
-- was taken off the shelf onto the cart; 0075 is where shipping starts drawing
-- the ledger against exactly those parcels instead of guessing.
--
-- **Suggestions are not stored.** `pick_candidates` is a read, the same way
-- `putaway_suggestions` (0069) is a read. A suggestion recorded on the row would
-- invite the question "was this what the system said or what the picker did",
-- and there is no good answer to that. Reality lives in the row; advice lives in
-- a function you can call again.

-- ---------------------------------------------------------------------------
-- 1. §16 — the rule, per product, overridable per warehouse
-- ---------------------------------------------------------------------------
--
-- Same three-part shape as 0068's `requires_inspection`: a product-level
-- default, a nullable per-warehouse override where null means "follow the
-- product", and one resolver everything else calls.
--
-- FEFO is the global default, not FIFO, for two reasons. §16 says food prefers
-- it, and — more importantly here — 0068's `apply_stock_unit_delta` already
-- draws expiry-first. Defaulting to FEFO means the advice a picker is given
-- matches what the ledger will do if nobody names a lot, which is the one
-- combination that cannot surprise anyone.

alter table public.products
  add column if not exists picking_rule text not null default 'FEFO';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'products_picking_rule_check') then
    alter table public.products
      add constraint products_picking_rule_check
      check (picking_rule in ('FIFO', 'FEFO', 'LIFO', 'MANUAL'));
  end if;
end $$;

alter table public.warehouse_products
  add column if not exists picking_rule text;

do $$
begin
  if not exists (select 1 from pg_constraint
                  where conname = 'warehouse_products_picking_rule_check') then
    alter table public.warehouse_products
      add constraint warehouse_products_picking_rule_check
      check (picking_rule is null or picking_rule in ('FIFO', 'FEFO', 'LIFO', 'MANUAL'));
  end if;
end $$;

create or replace function public.picking_rule_for(
  p_product_id bigint,
  p_warehouse_id bigint
) returns text
language sql
stable
security definer
set search_path to ''
as $$
  select coalesce(
    (select w.picking_rule
       from public.warehouse_products w
      where w.product_id = p_product_id and w.warehouse_id = p_warehouse_id),
    (select p.picking_rule from public.products p where p.id = p_product_id),
    'FEFO');
$$;

revoke all on function public.picking_rule_for(bigint, bigint) from public, anon;
grant execute on function public.picking_rule_for(bigint, bigint)
  to authenticated, service_role;

-- Its own call rather than another optional argument on `set_warehouse_product`,
-- for the same reason 0068 gave: there null already means "leave this alone",
-- and a rule whose "follow the product" value is *also* null cannot be said.
create or replace function public.set_picking_rule(
  p_product_id   bigint,
  p_warehouse_id bigint default null,
  p_rule         text default null
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_rule text := nullif(upper(btrim(coalesce(p_rule, ''))), '');
  v_company_id bigint;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if v_rule is not null and v_rule not in ('FIFO', 'FEFO', 'LIFO', 'MANUAL') then
    raise exception 'unknown picking rule % (FIFO, FEFO, LIFO or MANUAL)', p_rule;
  end if;

  select company_id into v_company_id from public.products where id = p_product_id;
  if v_company_id is null then
    raise exception 'product % not found', p_product_id;
  end if;

  if p_warehouse_id is null then
    -- The product's own default. Null would mean "no default", which the column
    -- does not allow, so clearing it means going back to FEFO.
    update public.products set picking_rule = coalesce(v_rule, 'FEFO'), updated_at = now()
     where id = p_product_id;
  else
    if not public.can_access_warehouse(p_warehouse_id) then
      raise exception 'not permitted: warehouse.scope required';
    end if;
    insert into public.warehouse_products (warehouse_id, product_id, company_id, picking_rule)
    values (p_warehouse_id, p_product_id, v_company_id, v_rule)
    on conflict (warehouse_id, product_id) do update
       set picking_rule = v_rule, updated_at = now();
  end if;

  perform public.log_audit('product.picking_rule_set', 'product', p_product_id::text,
    p_warehouse_id, jsonb_build_object('rule', v_rule, 'scope',
      case when p_warehouse_id is null then 'product' else 'warehouse' end));

  return jsonb_build_object(
    'product_id', p_product_id,
    'warehouse_id', p_warehouse_id,
    'rule', v_rule,
    'effective', public.picking_rule_for(p_product_id, p_warehouse_id));
end;
$$;

revoke all on function public.set_picking_rule(bigint, bigint, text) from public, anon;
grant execute on function public.set_picking_rule(bigint, bigint, text)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. Which parcels to take, in the order the rule says
-- ---------------------------------------------------------------------------
--
-- Only parcels in a status that counts as available: shipping held or failed
-- stock to a customer is what 0068 exists to prevent, and offering it here
-- would be advice the ledger then refuses.
--
-- `free` subtracts what other reservations have already been allocated from the
-- parcel, so two pickers are not sent to the same box. `take` is the running
-- suggestion — how much of this parcel to take to satisfy the quantity asked
-- for — which is what turns a list of parcels into instructions.

create or replace function public.pick_candidates(
  p_product_id   bigint,
  p_warehouse_id bigint,
  p_quantity     integer default null
) returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
declare
  v_rule text;
  v_left integer := greatest(coalesce(p_quantity, 0), 0);
  v_take integer;
  v_rows jsonb := '[]'::jsonb;
  r record;
begin
  if not public.has_permission('inventory.view') then
    raise exception 'not permitted: inventory.view required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  v_rule := public.picking_rule_for(p_product_id, p_warehouse_id);

  for r in
    select su.id as stock_unit_id,
           su.quantity,
           su.quantity - coalesce((
             select sum(a.quantity) from public.stock_allocations a
              where a.stock_unit_id = su.id), 0) as free,
           su.lot_id, l.lot_code, l.expiry_date, l.received_at,
           su.serial_id, sn.serial_number,
           su.bin_id, b.code as bin_code,
           st.code as status_code,
           su.created_at
      from public.stock_units su
      join public.stock_statuses st on st.id = su.status_id
      left join public.lots l on l.id = su.lot_id
      left join public.serial_numbers sn on sn.id = su.serial_id
      left join public.bins b on b.id = su.bin_id
     where su.product_id = p_product_id
       and su.warehouse_id = p_warehouse_id
       and su.quantity > 0
       and st.counts_available
     order by
       case v_rule
         when 'FEFO' then 0 when 'FIFO' then 1 when 'LIFO' then 2 else 3 end,
       -- Only the clause matching the rule does any work; the others are
       -- constant for every row and so cannot reorder anything.
       case when v_rule = 'FEFO' then l.expiry_date end asc nulls last,
       case when v_rule = 'FIFO' then coalesce(l.received_at, su.created_at) end asc,
       case when v_rule = 'LIFO' then coalesce(l.received_at, su.created_at) end desc,
       case when v_rule = 'MANUAL' then b.code end asc nulls last,
       su.id
  loop
    continue when r.free <= 0;
    v_take := case when v_left > 0 then least(v_left, r.free) else 0 end;
    v_left := greatest(v_left - v_take, 0);

    v_rows := v_rows || jsonb_build_object(
      'stock_unit_id', r.stock_unit_id,
      'quantity', r.quantity,
      'free', r.free,
      'take', v_take,
      'lot_id', r.lot_id,
      'lot_code', r.lot_code,
      'expiry_date', r.expiry_date,
      'serial_id', r.serial_id,
      'serial_number', r.serial_number,
      'bin_id', r.bin_id,
      'bin_code', r.bin_code,
      'status_code', r.status_code,
      'reason', case v_rule
        when 'FEFO' then case when r.expiry_date is not null
               then '期限が近い順（FEFO）: ' || to_char(r.expiry_date, 'YYYY-MM-DD')
               else '期限なし（FEFO）' end
        when 'FIFO' then '先に入った順（FIFO）'
        when 'LIFO' then '後に入った順（LIFO）'
        else '手動選択（MANUAL）' end);
  end loop;

  return jsonb_build_object(
    'product_id', p_product_id,
    'warehouse_id', p_warehouse_id,
    'rule', v_rule,
    'requested', coalesce(p_quantity, 0),
    -- What the rule could not cover from shippable stock. Reported rather than
    -- raised: a picker can act on "I can only find 30 of the 40".
    'short', v_left,
    'candidates', v_rows);
end;
$$;

revoke all on function public.pick_candidates(bigint, bigint, integer) from public, anon;
grant execute on function public.pick_candidates(bigint, bigint, integer)
  to authenticated, service_role;

-- The same read, addressed the way a picker's screen actually holds it: by the
-- task in front of them. Asks for what is still outstanding on the task, not the
-- whole planned quantity, so re-opening a part-picked task advises the rest.
create or replace function public.pick_task_candidates(p_task_id bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
declare
  v_product bigint;
  v_warehouse bigint;
  v_outstanding integer;
begin
  select coalesce(t.product_id, public.product_for_jan(t.jan_code)),
         l.warehouse_id,
         greatest(t.planned_quantity - coalesce(t.picked_quantity, 0), 0)
    into v_product, v_warehouse, v_outstanding
    from public.pick_tasks t
    join public.pick_lists l on l.id = t.pick_list_id
   where t.id = p_task_id;

  if v_warehouse is null then
    raise exception 'pick task % not found', p_task_id;
  end if;
  if v_product is null then
    -- An unregistered JAN has no parcels to advise on. Says so rather than
    -- returning an empty list that reads as "nothing in stock".
    raise exception 'pick task % has no registered product; link its JAN first', p_task_id;
  end if;

  return public.pick_candidates(v_product, v_warehouse, v_outstanding);
end;
$$;

revoke all on function public.pick_task_candidates(bigint) from public, anon;
grant execute on function public.pick_task_candidates(bigint)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. §15's detail: which parcels the picker actually took
-- ---------------------------------------------------------------------------

alter table public.pick_tasks
  add column if not exists picked_by uuid references public.app_users(id);

create table if not exists public.pick_items (
  id bigint generated by default as identity primary key,
  pick_task_id bigint not null references public.pick_tasks (id) on delete cascade,
  company_id bigint not null references public.companies (id),
  product_id bigint not null,
  -- The parcel this came out of, when the picker scanned one. Nullable: a pick
  -- can name a lot without naming which of its parcels, and set null rather
  -- than cascade, because a parcel emptied and cleaned up later must not take
  -- the record of the pick with it.
  stock_unit_id bigint references public.stock_units (id) on delete set null,
  lot_id bigint,
  serial_id bigint,
  bin_id bigint,
  quantity integer not null,
  note text,
  picked_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  constraint pick_items_quantity_check check (quantity > 0),
  -- A serialised pick is one unit, the same rule `receipt_items` carries.
  constraint pick_items_serial_quantity_check check (serial_id is null or quantity = 1),
  constraint pick_items_product_fk foreign key (company_id, product_id)
    references public.products (company_id, id) on delete restrict,
  constraint pick_items_lot_fk foreign key (product_id, lot_id)
    references public.lots (product_id, id) on delete restrict,
  constraint pick_items_serial_fk foreign key (product_id, serial_id)
    references public.serial_numbers (product_id, id) on delete restrict,
  constraint pick_items_bin_fk foreign key (bin_id)
    references public.bins (id) on delete set null
);

create index if not exists pick_items_task_idx on public.pick_items (pick_task_id);
create index if not exists pick_items_lot_idx on public.pick_items (lot_id)
  where lot_id is not null;

alter table public.pick_items enable row level security;

-- Scoped by warehouse through the parent and nothing else, which is exactly
-- what `pick_tasks_read` does. There is no `pick.view` permission — picking is
-- gated on doing, not looking — and requiring `inventory.view` here would let a
-- shipper (who has neither) see the task but not which lots it took.
drop policy if exists "read pick items" on public.pick_items;
create policy "read pick items" on public.pick_items
  for select to authenticated
  using (exists (select 1 from public.pick_tasks t
                  join public.pick_lists l on l.id = t.pick_list_id
                 where t.id = pick_items.pick_task_id
                   and public.can_access_warehouse(l.warehouse_id)));

-- Recording one parcel of a pick. Guarded in the function and granted to
-- `authenticated`, following 0067's `record_receipt_item` and 0069's
-- `confirm_putaway` rather than 0018's edge-gated pick RPCs: a floor mutation
-- written now carries its own permission and warehouse check.
create or replace function public.record_pick_item(
  p_task_id     bigint,
  p_quantity    integer,
  p_lot_code    text default null,
  p_serial_number text default null,
  p_bin_id      bigint default null,
  p_stock_unit_id bigint default null,
  p_note        text default null
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_task record;
  v_list_status text;
  v_warehouse bigint;
  v_product bigint;
  v_company bigint;
  v_lot bigint;
  v_serial bigint;
  v_bin bigint := p_bin_id;
  v_unit record;
  v_free integer;
  v_item bigint;
  v_total integer;
begin
  if not public.has_permission('pick.confirm') then
    raise exception 'not permitted: pick.confirm required';
  end if;
  if coalesce(p_quantity, 0) <= 0 then
    raise exception 'quantity must be greater than zero';
  end if;

  -- Aliased: `t.*` already carries a generated `status` column of its own, and
  -- two fields of that name in one record is a trap for whoever reads this next.
  select t.*, l.status as list_status, l.warehouse_id as list_warehouse_id
    into v_task
    from public.pick_tasks t
    join public.pick_lists l on l.id = t.pick_list_id
   where t.id = p_task_id;
  if v_task.id is null then
    raise exception 'pick task % not found', p_task_id;
  end if;
  v_list_status := v_task.list_status;
  v_warehouse := v_task.list_warehouse_id;
  if not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_list_status <> 'PICKING' then
    raise exception 'pick list % is %', v_task.pick_list_id, v_list_status;
  end if;

  v_product := coalesce(v_task.product_id, public.product_for_jan(v_task.jan_code));
  if v_product is null then
    raise exception 'pick task % has no registered product; link its JAN first', p_task_id;
  end if;
  select company_id into v_company from public.products where id = v_product;

  -- A named lot or serial has to already exist: picking is taking something off
  -- a shelf, so inventing identity here would mean inventing stock.
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

  if p_stock_unit_id is not null then
    select su.*, st.counts_available
      into v_unit
      from public.stock_units su
      join public.stock_statuses st on st.id = su.status_id
     where su.id = p_stock_unit_id;
    if v_unit.id is null then
      raise exception 'stock unit % not found', p_stock_unit_id;
    end if;
    if v_unit.product_id <> v_product or v_unit.warehouse_id <> v_warehouse then
      raise exception 'stock unit % is not this product in this warehouse', p_stock_unit_id;
    end if;
    if not v_unit.counts_available then
      raise exception 'stock unit % is not in a shippable condition', p_stock_unit_id;
    end if;
    -- What is left on the parcel after everything already picked from it on any
    -- open task. The ledger is not touched until shipping, so this is the only
    -- thing standing between two tasks and the same box.
    select v_unit.quantity - coalesce(sum(i.quantity), 0) into v_free
      from public.pick_items i
      join public.pick_tasks t on t.id = i.pick_task_id
      join public.pick_lists l on l.id = t.pick_list_id
     where i.stock_unit_id = p_stock_unit_id and l.status = 'PICKING';
    if v_free < p_quantity then
      raise exception 'stock unit % has % left to pick, cannot take %',
        p_stock_unit_id, v_free, p_quantity;
    end if;
    -- The parcel knows its own identity better than the caller does.
    v_lot := coalesce(v_lot, v_unit.lot_id);
    v_serial := coalesce(v_serial, v_unit.serial_id);
    v_bin := coalesce(v_bin, v_unit.bin_id);
  end if;

  if v_bin is not null and not exists (
    select 1 from public.bins where id = v_bin and warehouse_id = v_warehouse) then
    raise exception 'bin % belongs to another warehouse', v_bin;
  end if;

  insert into public.pick_items (
    pick_task_id, company_id, product_id, stock_unit_id, lot_id, serial_id,
    bin_id, quantity, note)
  values (p_task_id, v_company, v_product, p_stock_unit_id, v_lot, v_serial,
          v_bin, p_quantity, nullif(btrim(coalesce(p_note, '')), ''))
  returning id into v_item;

  -- The task's total is the sum of its parcels, so `variance` and `status`
  -- (generated, 0018) stay derived from one number that cannot drift.
  select coalesce(sum(quantity), 0)::int into v_total
    from public.pick_items where pick_task_id = p_task_id;

  update public.pick_tasks
     set picked_quantity = v_total,
         bin_id = coalesce(v_bin, bin_id),
         picked_at = now(),
         picked_by = coalesce(auth.uid(), picked_by)
   where id = p_task_id;

  perform public.log_audit('pick.item_recorded', 'pick_task', p_task_id::text,
    v_warehouse, jsonb_build_object(
      'pick_item_id', v_item, 'quantity', p_quantity, 'lot_id', v_lot,
      'serial_id', v_serial, 'bin_id', v_bin, 'stock_unit_id', p_stock_unit_id,
      'picked_total', v_total));

  return jsonb_build_object(
    'pick_item_id', v_item,
    'pick_task_id', p_task_id,
    'product_id', v_product,
    'quantity', p_quantity,
    'lot_id', v_lot,
    'serial_id', v_serial,
    'bin_id', v_bin,
    'picked_quantity', v_total,
    'planned_quantity', v_task.planned_quantity,
    'outstanding', greatest(v_task.planned_quantity - v_total, 0));
end;
$$;

revoke all on function public.record_pick_item(bigint, integer, text, text, bigint, bigint, text)
  from public, anon;
grant execute on function public.record_pick_item(bigint, integer, text, text, bigint, bigint, text)
  to authenticated, service_role;

-- Taking one back. Deleted rather than reversed: unlike a movement, a pick item
-- is not history — nothing has left the building yet — and a mis-keyed lot on a
-- cart is corrected by fixing it, not by recording an equal and opposite pick
-- that would have to be explained later.
create or replace function public.remove_pick_item(p_item_id bigint)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_task bigint;
  v_warehouse bigint;
  v_list_status text;
  v_total integer;
begin
  if not public.has_permission('pick.confirm') then
    raise exception 'not permitted: pick.confirm required';
  end if;

  select i.pick_task_id, l.warehouse_id, l.status
    into v_task, v_warehouse, v_list_status
    from public.pick_items i
    join public.pick_tasks t on t.id = i.pick_task_id
    join public.pick_lists l on l.id = t.pick_list_id
   where i.id = p_item_id;
  if v_task is null then
    raise exception 'pick item % not found', p_item_id;
  end if;
  if not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_list_status <> 'PICKING' then
    raise exception 'pick list is % and can no longer be edited', v_list_status;
  end if;

  delete from public.pick_items where id = p_item_id;

  select coalesce(sum(quantity), 0)::int into v_total
    from public.pick_items where pick_task_id = v_task;

  -- Back to untouched when the last parcel goes: "not picked yet" and "picked
  -- zero" are different states, and 0018's status column reads null as the
  -- former. A task that never had parcels is left exactly as it was.
  update public.pick_tasks
     set picked_quantity = case when v_total = 0 then null else v_total end,
         picked_at = case when v_total = 0 then null else picked_at end
   where id = v_task;

  perform public.log_audit('pick.item_removed', 'pick_task', v_task::text,
    v_warehouse, jsonb_build_object('pick_item_id', p_item_id, 'picked_total', v_total));

  return jsonb_build_object(
    'pick_task_id', v_task, 'picked_quantity', v_total);
end;
$$;

revoke all on function public.remove_pick_item(bigint) from public, anon;
grant execute on function public.remove_pick_item(bigint) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. Reading a pick list with its parcels
-- ---------------------------------------------------------------------------
--
-- Rewritten wholesale rather than by splice: every field 0018 returned is still
-- here, with `items` and `picking_rule` added per task.

create or replace function public.pick_list_detail(p_pick_list_id bigint)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', l.id,
    'shipment_plan_id', l.shipment_plan_id,
    'shipment_number', p.shipment_number,
    'customer_name', p.customer_name,
    'warehouse_id', l.warehouse_id,
    'warehouse_name', w.name,
    'uses_locations', w.uses_locations,
    'status', l.status,
    'note', l.note,
    'created_at', l.created_at,
    'completed_at', l.completed_at,
    'tasks', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', t.id,
               'shipment_line_id', t.shipment_line_id,
               'jan_code', t.jan_code,
               'product_id', t.product_id,
               'product_name', t.product_name,
               'planned_quantity', t.planned_quantity,
               'picked_quantity', t.picked_quantity,
               'variance', t.variance,
               'status', t.status,
               'bin_id', t.bin_id,
               'bin_code', b.code,
               'note', t.note,
               'picked_at', t.picked_at,
               -- §16's rule for this product here, so the screen can say why it
               -- is suggesting what it suggests.
               'picking_rule', case when t.product_id is null then null
                 else public.picking_rule_for(t.product_id, l.warehouse_id) end,
               'items', coalesce((
                 select jsonb_agg(jsonb_build_object(
                          'id', i.id,
                          'quantity', i.quantity,
                          'lot_id', i.lot_id,
                          'lot_code', lo.lot_code,
                          'expiry_date', lo.expiry_date,
                          'serial_id', i.serial_id,
                          'serial_number', sn.serial_number,
                          'bin_id', i.bin_id,
                          'bin_code', ib.code,
                          'stock_unit_id', i.stock_unit_id,
                          'note', i.note,
                          'created_at', i.created_at) order by i.id)
                   from public.pick_items i
                   left join public.lots lo on lo.id = i.lot_id
                   left join public.serial_numbers sn on sn.id = i.serial_id
                   left join public.bins ib on ib.id = i.bin_id
                  where i.pick_task_id = t.id), '[]'::jsonb)) order by t.id)
        from public.pick_tasks t
        left join public.bins b on b.id = t.bin_id
       where t.pick_list_id = l.id), '[]'::jsonb))
  from public.pick_lists l
  join public.shipment_plans p on p.id = l.shipment_plan_id
  left join public.warehouses w on w.id = l.warehouse_id
  where l.id = p_pick_list_id;
$$;

-- `start_pick_list` (0018) seeds tasks from the shipment lines and did not fill
-- `product_id`, which every read above needs. Filling it at seeding time rather
-- than leaning on 0058's backfill means a task knows its product from the
-- moment it exists.
create or replace function public.start_pick_list(
  p_shipment_plan_id bigint,
  p_note text default null
) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_status    text;
  v_warehouse bigint;
  v_id        bigint;
begin
  select status, coalesce(warehouse_id, public.default_warehouse_id())
    into v_status, v_warehouse
    from public.shipment_plans where id = p_shipment_plan_id;
  if v_status is null then
    raise exception 'shipment % not found', p_shipment_plan_id;
  end if;
  if v_status in ('shipped', 'cancelled') then
    raise exception 'shipment % is % and cannot be picked', p_shipment_plan_id, v_status;
  end if;

  select id into v_id from public.pick_lists
   where shipment_plan_id = p_shipment_plan_id and status = 'PICKING';
  if v_id is not null then return v_id; end if;

  insert into public.pick_lists (shipment_plan_id, warehouse_id, note)
  values (p_shipment_plan_id, v_warehouse, nullif(p_note, ''))
  returning id into v_id;

  insert into public.pick_tasks
    (pick_list_id, shipment_line_id, jan_code, product_name, planned_quantity,
     product_id)
  select v_id, l.id, l.jan_code, coalesce(l.product_name, ''),
         coalesce(l.quantity, 0),
         coalesce(l.product_id, public.product_for_jan(l.jan_code))
    from public.shipment_lines l
   where l.shipment_plan_id = p_shipment_plan_id
     and coalesce(l.quantity, 0) > 0
   order by l.id;

  perform public.log_audit(
    'pick_list.started', 'pick_list', v_id::text, v_warehouse,
    jsonb_build_object('shipment_plan_id', p_shipment_plan_id));

  return v_id;
end;
$$;
