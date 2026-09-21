-- 0067_receipt_items.sql
-- Phase B, step 2: §12's Item level — what actually came off the pallet.
--
-- §12 asks for receiving at three levels: Receipt (the delivery), Receipt Line
-- (the ordered line it answers) and Receipt Item (the parcel). The first two
-- already existed as `delivery_reconciliations` and `reconciliation_lines`. The
-- third did not, and without it a line could only say "40 of this JAN arrived".
-- It could not say "20 on lot A expiring in March, 20 on lot B expiring in
-- June, both into RECV-01" — which is what a pallet actually is, and what every
-- later step needs: QC inspects a parcel, put-away moves a parcel, a recall
-- traces a parcel.
--
-- The thing to be careful about is §5's rule: do not count the same stock
-- twice. `receipt_items` is therefore *not* a fourth stock projection. It is a
-- document — the record of what the operator saw and keyed — and each row
-- carries `movement_id`, the ledger row it posted. The stock came from the
-- movement; the item says where that movement came from. Deleting every receipt
-- item would lose the provenance and change no balance.


-- ---------------------------------------------------------------------------
-- 1. A bin, like a location, is identified within its warehouse
-- ---------------------------------------------------------------------------
--
-- So that a receipt item's bin can be tied to the same warehouse as the item by
-- the schema rather than by a check in every function that writes one.

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'bins_warehouse_id_key') then
    alter table public.bins add constraint bins_warehouse_id_key unique (warehouse_id, id);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. The Item level
-- ---------------------------------------------------------------------------

create table if not exists public.receipt_items (
  id                     bigserial primary key,
  company_id             bigint not null references public.companies(id),
  reconciliation_id      bigint not null
                           references public.delivery_reconciliations(id) on delete cascade,
  reconciliation_line_id bigint references public.reconciliation_lines(id) on delete set null,
  warehouse_id           bigint not null references public.warehouses(id),
  product_id             bigint,
  jan_code               text not null,
  product_name           text,
  lot_id                 bigint,
  serial_id              bigint,
  -- What was read off the carton. It is kept beside lot_id on purpose: the lot
  -- record may be corrected later, and this is what the receiver saw at the
  -- time, which is the number an argument with a supplier turns on.
  expiry                 date,
  location_id            bigint,
  bin_id                 bigint,
  quantity               integer not null check (quantity > 0),
  status_id              bigint not null references public.stock_statuses(id),
  movement_id            bigint references public.stock_movements(id) on delete set null,
  note                   text,
  created_by             uuid,
  created_at             timestamptz not null default now(),

  constraint receipt_items_product_fk
    foreign key (company_id, product_id) references public.products(company_id, id)
    on delete restrict,
  constraint receipt_items_lot_fk
    foreign key (product_id, lot_id) references public.lots(product_id, id)
    on delete restrict,
  constraint receipt_items_serial_fk
    foreign key (product_id, serial_id) references public.serial_numbers(product_id, id)
    on delete restrict,
  constraint receipt_items_location_fk
    foreign key (warehouse_id, location_id) references public.locations(warehouse_id, id)
    on delete set null (location_id),
  constraint receipt_items_bin_fk
    foreign key (warehouse_id, bin_id) references public.bins(warehouse_id, id)
    on delete set null (bin_id),
  -- A serialised unit is one thing, so a parcel that names one is a parcel of
  -- one.
  constraint receipt_items_serial_quantity_check
    check (serial_id is null or quantity = 1)
);

comment on table public.receipt_items is
  '§12 Receipt Item: one parcel as received — lot, serial, expiry, location, quantity. A document, not a stock projection: movement_id points at the ledger row that moved the stock.';

create index if not exists receipt_items_reconciliation_idx
  on public.receipt_items (reconciliation_id, id);
create index if not exists receipt_items_line_idx
  on public.receipt_items (reconciliation_line_id) where reconciliation_line_id is not null;
create index if not exists receipt_items_product_idx
  on public.receipt_items (product_id, warehouse_id) where product_id is not null;
create index if not exists receipt_items_lot_idx
  on public.receipt_items (lot_id) where lot_id is not null;

alter table public.receipt_items enable row level security;

-- Readable by whoever may see receiving in that warehouse; written only through
-- the functions below, which is why there is no write policy at all.
drop policy if exists "read receipt items" on public.receipt_items;
create policy "read receipt items" on public.receipt_items
  for select using (
    (public.has_permission('receiving.view') or public.has_permission('inventory.view'))
    and public.can_access_warehouse(warehouse_id));

-- ---------------------------------------------------------------------------
-- 3. Recording one parcel
-- ---------------------------------------------------------------------------
--
-- The operator keys what is printed: a lot code, an expiry, a serial, a
-- location code. Resolving those into ids is this function's job, not the
-- client's — the client has a scanner, not a database.
--
-- The work lives in an _impl with no permission check, because two callers
-- reach it through different gates: an operator adding a parcel by hand comes
-- through `record_receipt_item`, which checks `receiving.confirm`; receiving
-- itself comes through `reconcile_delivery_plan`, which the edge function has
-- already gated and which therefore must not re-check inside the database.

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
  v_status_code text := upper(btrim(coalesce(nullif(btrim(coalesce(p_status_code, '')), ''), 'OK')));
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

  -- A parcel may only claim a line of its own receipt.
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

  -- Lot and serial arrive as text and are created on first sight: a lot is born
  -- when goods bearing it arrive, which is here.
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

  -- §12 wants a location on the item. It arrives as the code printed on the
  -- rack, because that is what the operator is standing in front of.
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

  -- The stock moves once, on the ledger, carrying the identity of the parcel.
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

create or replace function public.record_receipt_item(
  p_reconciliation_id bigint,
  p_jan_code          text,
  p_quantity          integer,
  p_lot_code          text default null,
  p_expiry            date default null,
  p_serial_number     text default null,
  p_location_code     text default null,
  p_status_code       text default null,
  p_note              text default null,
  p_line_id           bigint default null
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_warehouse bigint;
begin
  if not public.has_permission('receiving.confirm') then
    raise exception 'not permitted: receiving.confirm required';
  end if;

  select coalesce(p.warehouse_id, public.default_warehouse_id()) into v_warehouse
    from public.delivery_reconciliations r
    join public.delivery_plans p on p.id = r.delivery_plan_id
   where r.id = p_reconciliation_id;
  if v_warehouse is null then
    raise exception 'receipt % not found', p_reconciliation_id;
  end if;
  if not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  return public.record_receipt_item_impl(
    p_reconciliation_id, v_warehouse, p_line_id, p_jan_code, p_quantity,
    p_lot_code, p_expiry, p_serial_number, p_location_code, p_status_code, p_note);
end;
$$;

revoke all on function public.record_receipt_item(bigint, text, integer, text, date, text, text, text, text, bigint)
  from public, anon;
grant execute on function public.record_receipt_item(bigint, text, integer, text, date, text, text, text, text, bigint)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. Receiving records its items as it goes
-- ---------------------------------------------------------------------------
--
-- `reconcile_delivery_plan` gains an optional `items` array per line. A caller
-- that sends none still gets an item level: one implicit parcel covering the
-- whole line. That matters because every later step — QC, put-away, traceback —
-- reads the item level, and a receipt with no items would be invisible to them.
--
-- The lines are now created one at a time inside the loop rather than by one
-- set-based insert. That is not a style choice: each entry's parcels have to be
-- attached to *that* entry's line, and pairing a line row back to the array
-- element it came from afterwards depends on an insert order nothing promises.
-- Creating the line and its parcels together removes the question.
--
-- Stock is likewise posted per line rather than aggregated by JAN across the
-- delivery. A ledger row per received line is what §12's Line level means, and
-- it is what makes a movement's reference specific enough to trace back to.

create or replace function public.reconcile_delivery_plan(
  p_plan_id bigint,
  p_complete boolean default true,
  p_note_reference text default null,
  p_lines jsonb default '[]'::jsonb
) returns bigint
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_recon_id    bigint;
  v_supplier    bigint;
  v_ref         text;
  v_outstanding int;
  v_status      text;
  v_warehouse   bigint;
  v_company     bigint;
  v_status_id   bigint;
  e             jsonb;
  it            jsonb;
  v_jan         text;
  v_qty         int;
  v_plan_line   public.delivery_plan_lines;
  v_line_id     bigint;
  v_line_status text;
  v_item_total  int;
  v_movement    bigint;
  v_product     bigint;
  v_name        text;
begin
  select supplier_id, coalesce(warehouse_id, public.default_warehouse_id())
    into v_supplier, v_warehouse
    from public.delivery_plans where id = p_plan_id;
  v_ref := public.assign_reference(v_supplier);
  select id into v_company from public.companies order by id limit 1;
  select id into v_status_id from public.stock_statuses where code = 'OK';

  insert into public.delivery_reconciliations
    (delivery_plan_id, note_reference, status, supplier_id, reference_no)
  values
    (p_plan_id, p_note_reference, 'received', v_supplier, v_ref)
  returning id into v_recon_id;

  for e in select * from jsonb_array_elements(p_lines) loop
    v_jan := e->>'jan_code';
    v_qty := coalesce((e->>'actual_quantity')::int, 0);

    select * into v_plan_line from public.delivery_plan_lines
     where delivery_plan_id = p_plan_id and jan_code = v_jan
     order by id limit 1;

    v_line_status := case
      when v_plan_line.id is null then 'unexpected'
      when v_qty = 0 then 'shortfall'
      when coalesce(v_plan_line.received_quantity, 0) + v_qty
           = v_plan_line.planned_quantity then 'matched'
      when coalesce(v_plan_line.received_quantity, 0) + v_qty
           < v_plan_line.planned_quantity then 'shortfall'
      else 'over'
    end;

    insert into public.reconciliation_lines
      (reconciliation_id, plan_line_id, jan_code, planned_quantity,
       actual_quantity, status, source)
    values
      (v_recon_id, v_plan_line.id, v_jan,
       coalesce(v_plan_line.planned_quantity, 0), v_qty, v_line_status,
       e->>'source')
    returning id into v_line_id;

    if v_plan_line.id is not null then
      update public.delivery_plan_lines
         set received_quantity = coalesce(received_quantity, 0) + v_qty
       where id = v_plan_line.id;
    end if;

    if v_qty <= 0 then
      continue;
    end if;

    select id, name into v_product, v_name from public.products where jan_code = v_jan;

    v_item_total := 0;
    if jsonb_typeof(e->'items') = 'array' then
      for it in select * from jsonb_array_elements(e->'items') loop
        perform public.record_receipt_item_impl(
          v_recon_id, v_warehouse, v_line_id, v_jan,
          coalesce((it->>'quantity')::int, 0),
          it->>'lot_code',
          nullif(btrim(coalesce(it->>'expiry', '')), '')::date,
          it->>'serial_number',
          it->>'location_code',
          it->>'status',
          it->>'note');
        v_item_total := v_item_total + coalesce((it->>'quantity')::int, 0);
      end loop;
    end if;

    if v_item_total > v_qty then
      raise exception 'line % reported % but its parcels add up to %',
        v_jan, v_qty, v_item_total;
    end if;

    -- Whatever the parcels did not account for is still stock that arrived, so
    -- it is posted as one unspecified parcel rather than quietly dropped. A
    -- line with no items at all takes this path whole, which is how every
    -- existing caller keeps working.
    if v_item_total < v_qty then
      v_movement := public.apply_stock_movement_detail(
        v_warehouse, v_jan, v_qty - v_item_total, 'RECEIPT',
        'reconciliation', v_recon_id::text, v_name,
        null, null, null, null, null, v_product);

      insert into public.receipt_items (
        company_id, reconciliation_id, reconciliation_line_id, warehouse_id,
        product_id, jan_code, product_name, quantity, status_id, movement_id,
        created_by)
      values (
        v_company, v_recon_id, v_line_id, v_warehouse,
        v_product, v_jan, v_name, v_qty - v_item_total, v_status_id, v_movement,
        auth.uid());
    end if;
  end loop;

  select coalesce(sum(greatest(
           coalesce(planned_quantity, 0) - coalesce(received_quantity, 0), 0)), 0)
    into v_outstanding
  from public.delivery_plan_lines
  where delivery_plan_id = p_plan_id;

  v_status := case
    when v_outstanding = 0 then 'completed'
    when p_complete then 'completed'
    else 'partial'
  end;

  update public.delivery_plans set status = v_status where id = p_plan_id;
  update public.delivery_reconciliations
     set status = case when v_status = 'completed' then 'completed' else 'partial' end
   where id = v_recon_id;

  perform public.log_audit(
    'receiving.confirmed', 'reconciliation', v_recon_id::text, v_warehouse,
    jsonb_build_object('plan_id', p_plan_id, 'status', v_status,
                       'outstanding', v_outstanding));

  return v_recon_id;
end;
$$;

revoke all on function public.reconcile_delivery_plan(bigint, boolean, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.reconcile_delivery_plan(bigint, boolean, text, jsonb)
  to service_role;

-- ---------------------------------------------------------------------------
-- 5. Reading a receipt back
-- ---------------------------------------------------------------------------

create or replace function public.receipt_detail_impl(p_reconciliation_id bigint)
returns jsonb
language sql
stable
security definer
set search_path to ''
as $$
  select jsonb_build_object(
    'reconciliation_id', r.id,
    'delivery_plan_id', r.delivery_plan_id,
    'delivery_number', p.delivery_number,
    'warehouse_id', p.warehouse_id,
    'supplier_id', r.supplier_id,
    'supplier_name', p.supplier_name,
    'reference_no', r.reference_no,
    'note_reference', r.note_reference,
    'status', r.status,
    'created_at', r.created_at,
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
        'line_id', rl.id,
        'jan_code', rl.jan_code,
        'product_id', rl.product_id,
        'product_name', pl.product_name,
        'planned_quantity', rl.planned_quantity,
        'actual_quantity', rl.actual_quantity,
        'status', rl.status,
        'items', coalesce((
          select jsonb_agg(jsonb_build_object(
            'receipt_item_id', ri.id,
            'quantity', ri.quantity,
            'lot_id', ri.lot_id,
            'lot_code', l.lot_code,
            'expiry', coalesce(ri.expiry, l.expiry_date),
            'serial_id', ri.serial_id,
            'serial_number', sn.serial_number,
            'location_id', ri.location_id,
            'location_code', lo.code,
            'bin_id', ri.bin_id,
            'status_code', st.code,
            'status_name', st.name,
            'counts_available', st.counts_available,
            'movement_id', ri.movement_id,
            'note', ri.note,
            'created_at', ri.created_at) order by ri.id)
          from public.receipt_items ri
          left join public.lots l on l.id = ri.lot_id
          left join public.serial_numbers sn on sn.id = ri.serial_id
          left join public.locations lo on lo.id = ri.location_id
          join public.stock_statuses st on st.id = ri.status_id
         where ri.reconciliation_line_id = rl.id), '[]'::jsonb)
      ) order by rl.id)
      from public.reconciliation_lines rl
      left join public.delivery_plan_lines pl on pl.id = rl.plan_line_id
     where rl.reconciliation_id = r.id), '[]'::jsonb),
    -- Parcels that could not be tied to a line (an unexpected JAN, say) would
    -- otherwise vanish from this read entirely.
    'unlinked_items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'receipt_item_id', ri.id, 'jan_code', ri.jan_code,
        'product_name', ri.product_name, 'quantity', ri.quantity,
        'status_code', st.code) order by ri.id)
      from public.receipt_items ri
      join public.stock_statuses st on st.id = ri.status_id
     where ri.reconciliation_id = r.id and ri.reconciliation_line_id is null), '[]'::jsonb))
  from public.delivery_reconciliations r
  join public.delivery_plans p on p.id = r.delivery_plan_id
 where r.id = p_reconciliation_id
   and public.can_access_warehouse(coalesce(p.warehouse_id, public.default_warehouse_id()));
$$;

revoke all on function public.receipt_detail_impl(bigint)
  from public, anon, authenticated, service_role;

create or replace function public.receipt_detail(p_reconciliation_id bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
declare
  v_warehouse bigint;
begin
  if not (public.has_permission('receiving.view') or public.has_permission('inventory.view')) then
    raise exception 'not permitted: receiving.view required';
  end if;
  select coalesce(p.warehouse_id, public.default_warehouse_id()) into v_warehouse
    from public.delivery_reconciliations r
    join public.delivery_plans p on p.id = r.delivery_plan_id
   where r.id = p_reconciliation_id;
  if v_warehouse is null then
    raise exception 'receipt % not found', p_reconciliation_id;
  end if;
  if not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  return coalesce(public.receipt_detail_impl(p_reconciliation_id), '{}'::jsonb);
end;
$$;

revoke all on function public.receipt_detail(bigint) from public, anon;
grant execute on function public.receipt_detail(bigint) to authenticated, service_role;

-- A parcel-level view of what is in the building and where it came from. This
-- is the read §12's "traceability" line is about: given a lot, which delivery
-- brought it in.
create or replace function public.lot_provenance(
  p_product_id bigint,
  p_lot_code   text default null
) returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
begin
  if not (public.has_permission('inventory.view') or public.has_permission('receiving.view')) then
    raise exception 'not permitted: inventory.view required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'receipt_item_id', ri.id,
      'received_at', ri.created_at,
      'reconciliation_id', ri.reconciliation_id,
      'reference_no', r.reference_no,
      'delivery_number', dp.delivery_number,
      'supplier_name', dp.supplier_name,
      'warehouse_id', ri.warehouse_id,
      'quantity', ri.quantity,
      'lot_id', ri.lot_id,
      'lot_code', l.lot_code,
      'expiry', coalesce(ri.expiry, l.expiry_date),
      'serial_number', sn.serial_number,
      'location_code', lo.code,
      'status_code', st.code) order by ri.created_at desc, ri.id desc)
    from public.receipt_items ri
    join public.stock_statuses st on st.id = ri.status_id
    left join public.lots l on l.id = ri.lot_id
    left join public.serial_numbers sn on sn.id = ri.serial_id
    left join public.locations lo on lo.id = ri.location_id
    left join public.delivery_reconciliations r on r.id = ri.reconciliation_id
    left join public.delivery_plans dp on dp.id = r.delivery_plan_id
   where ri.product_id = p_product_id
     and public.can_access_warehouse(ri.warehouse_id)
     and (nullif(btrim(coalesce(p_lot_code, '')), '') is null
          or l.lot_code = btrim(p_lot_code))), '[]'::jsonb);
end;
$$;

revoke all on function public.lot_provenance(bigint, text) from public, anon;
grant execute on function public.lot_provenance(bigint, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 6. Housekeeping
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

