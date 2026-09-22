-- 0072_qc_status_cannot_be_downgraded.sql
-- A hole in 0068, found while wiring the receiving client.
--
-- 0068 made `record_receipt_item_impl` fall back to `receiving_status_for()` when
-- no status was named, and let a named status win when one was. The reasoning was
-- sound: a receiver who can see the carton is wet knows more than a flag does.
--
-- But "a named status wins" is too broad in one direction. The receiving path
-- runs through `reconcile_delivery_plan`, whose `p_lines` payload the edge
-- function passes through verbatim — so a client could send
-- `{"quantity": 40, "status": "OK"}` for a product whose flag says QC_PENDING and
-- receive it straight into shippable stock. That is exactly the thing §13 asks
-- the database to prevent:
--
--   「QC FAIL / HOLDの商品が誤って出荷されないことを、Flutter UIだけでなく
--     RPC/DB側でも保証する。」
--
-- A guarantee that a `receiving.confirm` holder can opt out of by naming a
-- status is a UI convention with extra steps.
--
-- The rule that keeps the useful half and closes the hole: **a named status may
-- only make a parcel more restricted, never less.** If the product requires
-- inspection, the receiver may name QC_PENDING, HOLD, DAMAGED or QUARANTINE —
-- anything that does not count as available — and is refused if they name one
-- that does. Nothing is lost: the wet-carton case names DAMAGED, which is more
-- restrictive, not less.

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
  v_named       text := nullif(btrim(coalesce(p_status_code, '')), '');
  v_required    text;
  v_available   boolean;
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

  v_required := public.receiving_status_for(v_product, p_warehouse_id);
  v_status_code := upper(btrim(coalesce(v_named, v_required, 'OK')));

  -- §13's guarantee, made un-opt-out-able. A named status may only be more
  -- restrictive than the product's requirement, never less: the wet-carton case
  -- names DAMAGED and still works, while naming OK for goods that must be
  -- inspected is refused rather than quietly honoured.
  if v_named is not null and v_required = 'QC_PENDING' then
    select counts_available into v_available
      from public.stock_statuses where code = v_status_code;
    if coalesce(v_available, false) then
      raise exception
        '% must be inspected, so it cannot be received as % — record it as QC_PENDING, or as DAMAGED/HOLD if it arrived bad',
        v_jan, v_status_code;
    end if;
  end if;

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
