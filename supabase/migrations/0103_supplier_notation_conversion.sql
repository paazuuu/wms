-- 0103 — what the supplier wrote becomes what we call it.
--
-- Suppliers name the same product each in their own way: a JAN with a
-- hyphen or in full-width digits, a case code (GTIN-14) instead of the JAN,
-- the maker spelled differently, the name abbreviated, their own 品番 (some
-- call it 項目名). Whatever arrives from a supplier is booked under our own
-- JAN, maker, name and 品番; what the supplier wrote is kept beside it so the
-- inspector can check the two against each other.
--
--   * `products.maker` — our maker name (品番 is `products.sku`).
--   * `supplier_product_names` learns the supplier's JAN and maker too.
--   * `normalize_jan` — digits only, full width folded; UPC-A gains its 0;
--     a case code loses its indicator digit and gets the JAN's check digit.
--   * `normalize_product_text` — NFKC (full/half width, half-width kana),
--     lower case, no spaces, dots, dashes or brackets.
--   * `resolve_supplier_product(supplier, jan, code, name, maker)` — our
--     product for a supplier's line: by JAN or a registered barcode, by the
--     JAN / 品番 / name the supplier is known to use, by our own 品番, then
--     by our own name when only one product has it.
--   * Receiving converts: the stock lands under our JAN, the receipt line
--     keeps the JAN that was scanned (`src_jan_code`, `converted_by`).
--   * Inspection lines keep the supplier's JAN, 品番, name and maker
--     (`src_*`), and show ours.
--   * `convert_inspection_item(item, product, remember)` — a line nothing
--     matched is pointed at our product by hand; the stock waiting for
--     inspection moves to it (movement RELABEL), and the supplier's writing is
--     remembered so next time it converts by itself.
--   * An inspection cannot pass a line that is not converted: finalize
--     refuses it, bulk pass skips it, completion says how many are left.

alter table public.products add column if not exists maker text;

alter table public.supplier_product_names add column if not exists supplier_jan_code text;
alter table public.supplier_product_names add column if not exists supplier_maker text;

alter table public.delivery_plan_lines add column if not exists maker text;

alter table public.receipt_items add column if not exists src_jan_code text;
alter table public.receipt_items add column if not exists converted_by text;

alter table public.inspection_items add column if not exists src_jan_code text;
alter table public.inspection_items add column if not exists src_product_code text;
alter table public.inspection_items add column if not exists src_product_name text;
alter table public.inspection_items add column if not exists src_maker text;
alter table public.inspection_items add column if not exists converted_by text;

alter table public.stock_movements drop constraint if exists stock_movements_movement_type_check;
alter table public.stock_movements add constraint stock_movements_movement_type_check
  check (movement_type = any (array['OPENING', 'RECEIPT', 'RECEIPT_CANCEL', 'PUTAWAY', 'PICK',
    'SHIP', 'SHIP_CANCEL', 'ADJUST', 'COUNT', 'TRANSFER_IN', 'TRANSFER_OUT',
    'WORK_ORDER_CONSUME', 'WORK_ORDER_PRODUCE', 'SCRAP', 'RETURN_TO_SUPPLIER', 'RELABEL']));

-- ---------------------------------------------------------------------------
-- Normalizing
-- ---------------------------------------------------------------------------

create or replace function public.normalize_product_text(p text)
returns text
language sql immutable set search_path = '' as $$
  select lower(regexp_replace(normalize(coalesce(p, ''), NFKC),
                              '[[:space:]・\-‐‑‒–—―−_()\[\]「」【】『』〔〕]', '', 'g'));
$$;

create or replace function public.normalize_jan(p text)
returns text
language plpgsql immutable set search_path = '' as $$
declare
  d text := regexp_replace(normalize(coalesce(p, ''), NFKC), '[^0-9]', '', 'g');
  s int := 0;
  i int;
begin
  if d = '' then
    return null;
  end if;
  if length(d) = 12 then
    return '0' || d;                       -- UPC-A is a JAN with a leading 0
  end if;
  if length(d) = 14 then
    if left(d, 1) = '0' then
      return substr(d, 2);
    end if;
    -- A case code: the indicator digit goes and the check digit is the JAN's.
    d := substr(d, 2, 12);
    for i in 1..12 loop
      s := s + substr(d, i, 1)::int * case when i % 2 = 0 then 3 else 1 end;
    end loop;
    return d || ((10 - s % 10) % 10)::text;
  end if;
  return d;
end;
$$;

revoke all on function public.normalize_jan(text) from public, anon;
grant execute on function public.normalize_jan(text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Resolving a supplier's line to our product
-- ---------------------------------------------------------------------------

create or replace function public.resolve_supplier_product(
  p_supplier_id bigint, p_jan text, p_code text default null,
  p_name text default null, p_maker text default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_jan   text := public.normalize_jan(p_jan);
  v_code  text := nullif(public.normalize_product_text(p_code), '');
  v_name  text := nullif(public.normalize_product_text(p_name), '');
  v_maker text := nullif(public.normalize_product_text(p_maker), '');
  v_id    bigint;
  v_n     int;
begin
  -- 1. The JAN, or any barcode registered to one of our products.
  if v_jan is not null then
    v_id := coalesce(public.product_for_jan(p_jan), public.product_for_jan(v_jan));
    if v_id is null then
      select p.id into v_id from public.products p
       where public.normalize_jan(p.jan_code) = v_jan limit 1;
    end if;
    if v_id is not null then
      return jsonb_build_object('product_id', v_id, 'matched_by', 'jan');
    end if;
  end if;

  -- 2. How this supplier is known to write it.
  if p_supplier_id is not null then
    if v_jan is not null then
      select n.product_id into v_id from public.supplier_product_names n
       where n.supplier_id = p_supplier_id
         and public.normalize_jan(n.supplier_jan_code) = v_jan
       limit 1;
      if v_id is not null then
        return jsonb_build_object('product_id', v_id, 'matched_by', 'supplier_jan');
      end if;
    end if;
    if v_code is not null then
      select n.product_id into v_id from public.supplier_product_names n
       where n.supplier_id = p_supplier_id
         and public.normalize_product_text(n.supplier_code) = v_code
       limit 1;
      if v_id is not null then
        return jsonb_build_object('product_id', v_id, 'matched_by', 'supplier_code');
      end if;
    end if;
    if v_name is not null then
      select n.product_id into v_id from public.supplier_product_names n
       where n.supplier_id = p_supplier_id
         and public.normalize_product_text(n.supplier_name) = v_name
         and (v_maker is null or n.supplier_maker is null
              or public.normalize_product_text(n.supplier_maker) = v_maker)
       limit 1;
      if v_id is not null then
        return jsonb_build_object('product_id', v_id, 'matched_by', 'supplier_name');
      end if;
    end if;
  end if;

  -- 3. Our own 品番, when only one product has it.
  if v_code is not null then
    select count(*), min(p.id) into v_n, v_id from public.products p
     where public.normalize_product_text(p.sku) = v_code and p.status = 'active';
    if v_n = 1 then
      return jsonb_build_object('product_id', v_id, 'matched_by', 'sku');
    end if;
  end if;

  -- 4. Our own name (and maker, when both are known), when only one has it.
  if v_name is not null then
    select count(*), min(p.id) into v_n, v_id from public.products p
     where public.normalize_product_text(p.name) = v_name and p.status = 'active'
       and (v_maker is null or p.maker is null
            or public.normalize_product_text(p.maker) = v_maker);
    if v_n = 1 then
      return jsonb_build_object('product_id', v_id, 'matched_by', 'name');
    end if;
  end if;

  return jsonb_build_object('product_id', null, 'matched_by', null);
end;
$$;

revoke all on function public.resolve_supplier_product(bigint, text, text, text, text) from public, anon;
grant execute on function public.resolve_supplier_product(bigint, text, text, text, text)
  to authenticated, service_role;

-- The supplier a receipt came from.
create or replace function public.receipt_supplier_id(p_reconciliation_id bigint)
returns bigint
language sql stable security definer set search_path = '' as $$
  select coalesce(r.supplier_id, p.supplier_id, po.supplier_id)
    from public.delivery_reconciliations r
    join public.delivery_plans p on p.id = r.delivery_plan_id
    left join public.purchase_orders po on po.id = p.purchase_order_id
   where r.id = p_reconciliation_id;
$$;

revoke all on function public.receipt_supplier_id(bigint) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Receiving books under our JAN
-- ---------------------------------------------------------------------------

create or replace function public.record_receipt_item_impl(
  p_reconciliation_id bigint, p_warehouse_id bigint, p_line_id bigint, p_jan_code text,
  p_quantity integer, p_lot_code text default null, p_expiry date default null,
  p_serial_number text default null, p_location_code text default null,
  p_status_code text default null, p_note text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_company     bigint;
  v_product     bigint;
  v_name        text;
  v_jan         text := nullif(btrim(coalesce(p_jan_code, '')), '');
  v_src_jan     text;
  v_own_jan     text;
  v_by          text;
  v_resolved    jsonb;
  v_pl          record;
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

  -- Our product (0103): the scanned code, the line's product, then how the
  -- supplier wrote the line.
  v_product := public.product_for_jan(v_jan);
  if v_product is not null then
    v_by := 'jan';
  else
    select coalesce(rl.product_id, pl.product_id) as product_id, pl.jan_code,
           pl.product_code, pl.product_name, pl.maker
      into v_pl
      from public.reconciliation_lines rl
      left join public.delivery_plan_lines pl on pl.id = rl.plan_line_id
     where rl.id = v_line;
    if v_pl.product_id is not null then
      v_product := v_pl.product_id;
      v_by := 'plan';
    else
      v_resolved := public.resolve_supplier_product(
        public.receipt_supplier_id(p_reconciliation_id),
        v_jan, v_pl.product_code, v_pl.product_name, v_pl.maker);
      v_product := (v_resolved->>'product_id')::bigint;
      v_by := v_resolved->>'matched_by';
      if v_product is null and v_pl.jan_code is not null and v_pl.jan_code <> v_jan then
        v_resolved := public.resolve_supplier_product(
          public.receipt_supplier_id(p_reconciliation_id),
          v_pl.jan_code, v_pl.product_code, v_pl.product_name, v_pl.maker);
        v_product := (v_resolved->>'product_id')::bigint;
        v_by := v_resolved->>'matched_by';
      end if;
    end if;
  end if;

  if v_product is not null then
    select coalesce(nullif(btrim(jan_code), ''), v_jan), name into v_own_jan, v_name
      from public.products where id = v_product;
    if v_own_jan <> v_jan then
      -- Booked under our JAN; the scanned one is kept on the receipt line.
      v_src_jan := v_jan;
      v_jan := v_own_jan;
    end if;
  end if;

  v_required := public.receiving_status_for(v_product, p_warehouse_id);
  v_status_code := upper(btrim(coalesce(v_named, v_required, 'OK')));

  -- S13's guarantee, made un-opt-out-able: a named status may only be more
  -- restrictive than the product's requirement, never less.
  if v_named is not null and v_required = 'QC_PENDING' then
    select counts_available into v_available
      from public.stock_statuses where code = v_status_code;
    if coalesce(v_available, false) then
      raise exception
        '% must be inspected, so it cannot be received as % - record it as QC_PENDING, or as DAMAGED/HOLD if it arrived bad',
        v_jan, v_status_code;
    end if;
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
    location_id, bin_id, quantity, status_id, movement_id, note, created_by,
    src_jan_code, converted_by)
  values (
    v_company, p_reconciliation_id, v_line, p_warehouse_id,
    v_product, v_jan, v_name, v_lot, v_serial, p_expiry,
    v_location, v_bin, p_quantity, v_status, v_movement, p_note, auth.uid(),
    v_src_jan, v_by)
  returning id into v_item;

  if v_product is not null and v_line is not null then
    update public.reconciliation_lines set product_id = v_product
     where id = v_line and product_id is null;
  end if;

  perform public.log_audit(
    'receiving.item_recorded', 'reconciliation', p_reconciliation_id::text, p_warehouse_id,
    jsonb_build_object('jan_code', v_jan, 'scanned_jan', v_src_jan, 'converted_by', v_by,
                       'quantity', p_quantity,
                       'lot', nullif(btrim(coalesce(p_lot_code, '')), ''),
                       'serial', nullif(btrim(coalesce(p_serial_number, '')), ''),
                       'status', v_status_code,
                       'location', nullif(btrim(coalesce(p_location_code, '')), '')));

  return jsonb_build_object(
    'receipt_item_id', v_item,
    'reconciliation_id', p_reconciliation_id,
    'line_id', v_line,
    'jan_code', v_jan,
    'scanned_jan', v_src_jan,
    'converted_by', v_by,
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

revoke all on function public.record_receipt_item_impl(bigint, bigint, bigint, text, integer, text,
  date, text, text, text, text) from public, anon, authenticated;

-- A scan finds its planned line even when the supplier's list wrote the JAN
-- differently, or listed a code that converts to the same product.
do $$
declare v_src text;
begin
  select pg_get_functiondef(
    'public.record_receipt_item(bigint,text,integer,text,date,text,text,text,text,bigint)'::regprocedure)
    into v_src;
  if position('normalize_jan' in v_src) = 0 then
    v_src := replace(v_src,
'  select * into v_plan_line from public.delivery_plan_lines
   where delivery_plan_id = v_plan and jan_code = v_jan
   order by id limit 1;
',
'  select * into v_plan_line from public.delivery_plan_lines
   where delivery_plan_id = v_plan and jan_code = v_jan
   order by id limit 1;
  if v_plan_line.id is null then
    select * into v_plan_line from public.delivery_plan_lines pl
     where pl.delivery_plan_id = v_plan
       and (public.normalize_jan(pl.jan_code) = public.normalize_jan(v_jan)
            or (pl.product_id is not null and pl.product_id = public.product_for_jan(v_jan)))
     order by pl.id limit 1;
  end if;
  if v_line is null and v_plan_line.id is not null then
    select id into v_line from public.reconciliation_lines
     where reconciliation_id = p_reconciliation_id and plan_line_id = v_plan_line.id
     order by id limit 1;
  end if;
');
    if position('normalize_jan' in v_src) = 0 then
      raise exception 'record_receipt_item did not have the expected shape';
    end if;
    execute v_src;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Inspection lines: ours in front, theirs kept
-- ---------------------------------------------------------------------------

create or replace function public.inspection_item_convert()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_pl       record;
  v_resolved jsonb;
  v_supplier bigint;
  v_own      record;
begin
  select coalesce(rl.product_id, pl.product_id) as product_id, pl.jan_code,
         pl.product_code, pl.product_name, pl.maker
    into v_pl
    from public.reconciliation_lines rl
    left join public.delivery_plan_lines pl on pl.id = rl.plan_line_id
   where rl.id = new.reconciliation_line_id;

  -- What the supplier wrote: their list first, else what was scanned.
  new.src_jan_code := coalesce(v_pl.jan_code, new.src_jan_code, new.jan_code);
  new.src_product_code := coalesce(new.src_product_code, v_pl.product_code);
  new.src_product_name := coalesce(new.src_product_name, v_pl.product_name, new.product_name);
  new.src_maker := coalesce(new.src_maker, v_pl.maker);

  if new.product_id is null then
    new.product_id := public.product_for_jan(new.jan_code);
    if new.product_id is not null then
      new.converted_by := coalesce(new.converted_by, 'jan');
    elsif v_pl.product_id is not null then
      new.product_id := v_pl.product_id;
      new.converted_by := 'plan';
    else
      select ins.reconciliation_id into v_supplier
        from public.inspections ins where ins.id = new.inspection_id;
      v_supplier := public.receipt_supplier_id(v_supplier);
      v_resolved := public.resolve_supplier_product(
        v_supplier, new.src_jan_code, new.src_product_code, new.src_product_name, new.src_maker);
      new.product_id := (v_resolved->>'product_id')::bigint;
      new.converted_by := v_resolved->>'matched_by';
    end if;
  else
    new.converted_by := coalesce(new.converted_by, 'jan');
  end if;

  if new.product_id is not null then
    select jan_code, name into v_own from public.products where id = new.product_id;
    new.jan_code := coalesce(nullif(btrim(v_own.jan_code), ''), new.jan_code);
    new.product_name := coalesce(v_own.name, new.product_name);
  end if;
  return new;
end;
$$;

revoke all on function public.inspection_item_convert() from public, anon, authenticated;

drop trigger if exists inspection_items_a_convert on public.inspection_items;
create trigger inspection_items_a_convert
  before insert on public.inspection_items
  for each row execute function public.inspection_item_convert();

-- The receipt passes on what was scanned and how it converted.
do $$
declare v_src text;
begin
  select pg_get_functiondef('public.receipt_item_opens_inspection()'::regprocedure) into v_src;
  if position('src_jan_code' in v_src) = 0 then
    v_src := replace(v_src,
'      (inspection_id, reconciliation_line_id, jan_code, product_name,
       expected_quantity, actual_quantity, product_id)
    values
      (v_inspection, v_line.id, new.jan_code, v_name,
       coalesce(v_line.planned_quantity, 0), new.quantity, new.product_id);',
'      (inspection_id, reconciliation_line_id, jan_code, product_name,
       expected_quantity, actual_quantity, product_id, src_jan_code, converted_by)
    values
      (v_inspection, v_line.id, new.jan_code, v_name,
       coalesce(v_line.planned_quantity, 0), new.quantity, new.product_id,
       new.src_jan_code, new.converted_by);');
    if position('src_jan_code' in v_src) = 0 then
      raise exception 'receipt_item_opens_inspection did not have the expected shape';
    end if;
    execute v_src;
  end if;
end $$;

-- Lines already open get the supplier's writing filled in.
update public.inspection_items it
   set src_jan_code = coalesce(pl.jan_code, it.jan_code),
       src_product_code = pl.product_code,
       src_product_name = coalesce(pl.product_name, it.product_name),
       converted_by = case when it.product_id is not null then 'jan' end
  from public.reconciliation_lines rl
  left join public.delivery_plan_lines pl on pl.id = rl.plan_line_id
 where rl.id = it.reconciliation_line_id and it.src_jan_code is null;

-- ---------------------------------------------------------------------------
-- Converting a line by hand
-- ---------------------------------------------------------------------------

create or replace function public.convert_inspection_item(
  p_item_id bigint, p_product_id bigint, p_remember boolean default true)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  it          record;
  v_new       record;
  v_qty       int;
  v_supplier  bigint;
  v_code      text;
  v_remember  boolean := false;
begin
  if not public.has_permission('inspection.confirm') then
    raise exception 'not permitted: inspection.confirm required';
  end if;

  select i.*, ins.warehouse_id, ins.reconciliation_id, ins.status as inspection_status
    into it
    from public.inspection_items i
    join public.inspections ins on ins.id = i.inspection_id
   where i.id = p_item_id
   for update of i;
  if it.id is null then
    raise exception 'inspection item % not found', p_item_id;
  end if;
  if not public.can_access_warehouse(it.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if it.inspection_status <> 'PENDING' or it.finalized_at is not null then
    raise exception 'inspection item % is already completed and can no longer change', p_item_id;
  end if;
  if it.serial_id is not null then
    raise exception 'a serial-numbered line cannot be converted; cancel the receipt and receive it again';
  end if;

  select id, jan_code, name into v_new from public.products where id = p_product_id;
  if v_new.id is null then
    raise exception 'product % not found', p_product_id;
  end if;
  if nullif(btrim(coalesce(v_new.jan_code, '')), '') is null then
    raise exception 'product % has no JAN to book the goods under', p_product_id;
  end if;

  if it.product_id is distinct from p_product_id then
    -- What this line put into inspection, as it was booked.
    select coalesce(sum(ri.quantity), 0)::int into v_qty
      from public.receipt_items ri
      join public.stock_statuses st on st.id = ri.status_id
     where ri.reconciliation_id = it.reconciliation_id
       and st.code = 'QC_PENDING'
       and ((it.reconciliation_line_id is not null
             and ri.reconciliation_line_id = it.reconciliation_line_id)
            or (it.reconciliation_line_id is null and ri.jan_code = it.jan_code));
    v_qty := least(v_qty, coalesce(it.actual_quantity, v_qty));

    if v_qty > 0 then
      perform public.apply_stock_movement_detail(
        it.warehouse_id, it.jan_code, -v_qty, 'RELABEL', 'inspection_item', p_item_id::text,
        it.product_name, null, format('converted to %s', v_new.jan_code),
        it.lot_id, null, 'QC_PENDING', it.product_id);
      perform public.apply_stock_movement_detail(
        it.warehouse_id, v_new.jan_code, v_qty, 'RELABEL', 'inspection_item', p_item_id::text,
        v_new.name, null, format('converted from %s', coalesce(it.src_jan_code, it.jan_code)),
        null, null, 'QC_PENDING', p_product_id);
    end if;

    update public.receipt_items ri
       set product_id = p_product_id,
           jan_code = v_new.jan_code,
           product_name = v_new.name,
           src_jan_code = coalesce(ri.src_jan_code, ri.jan_code),
           converted_by = 'manual',
           lot_id = null
     where ri.reconciliation_id = it.reconciliation_id
       and ((it.reconciliation_line_id is not null
             and ri.reconciliation_line_id = it.reconciliation_line_id)
            or (it.reconciliation_line_id is null and ri.jan_code = it.jan_code));

    if it.reconciliation_line_id is not null then
      update public.reconciliation_lines set product_id = p_product_id
       where id = it.reconciliation_line_id;
      update public.delivery_plan_lines pl set product_id = p_product_id
        from public.reconciliation_lines rl
       where rl.id = it.reconciliation_line_id and pl.id = rl.plan_line_id;
    end if;

    update public.inspection_items
       set product_id = p_product_id,
           jan_code = v_new.jan_code,
           product_name = v_new.name,
           src_jan_code = coalesce(src_jan_code, it.jan_code),
           converted_by = 'manual',
           lot_id = null
     where id = p_item_id;
  end if;

  -- Remembered, so this supplier's writing converts by itself next time.
  v_supplier := public.receipt_supplier_id(it.reconciliation_id);
  if coalesce(p_remember, true) and v_supplier is not null then
    v_code := nullif(btrim(coalesce(it.src_product_code, '')), '');
    if v_code is not null and exists (
         select 1 from public.supplier_product_names
          where supplier_id = v_supplier and supplier_code = v_code
            and product_id <> p_product_id) then
      v_code := null;
    end if;
    insert into public.supplier_product_names
      (supplier_id, product_id, supplier_code, supplier_name, supplier_jan_code, supplier_maker)
    values (v_supplier, p_product_id, v_code,
            coalesce(nullif(btrim(coalesce(it.src_product_name, '')), ''), v_new.name),
            case when public.normalize_jan(it.src_jan_code) is distinct from v_new.jan_code
                 then it.src_jan_code end,
            nullif(btrim(coalesce(it.src_maker, '')), ''))
    on conflict (supplier_id, product_id) do update
       set supplier_code = coalesce(excluded.supplier_code, supplier_product_names.supplier_code),
           supplier_name = coalesce(nullif(btrim(coalesce(it.src_product_name, '')), ''),
                                    supplier_product_names.supplier_name),
           supplier_jan_code = coalesce(excluded.supplier_jan_code,
                                        supplier_product_names.supplier_jan_code),
           supplier_maker = coalesce(excluded.supplier_maker, supplier_product_names.supplier_maker),
           updated_at = now();
    v_remember := true;
  end if;

  perform public.log_audit('inspection.item_converted', 'inspection', it.inspection_id::text,
    it.warehouse_id, jsonb_build_object('item_id', p_item_id, 'from_product', it.product_id,
      'from_jan', it.jan_code, 'to_product', p_product_id, 'to_jan', v_new.jan_code,
      'quantity', v_qty, 'remembered', v_remember));

  return jsonb_build_object('item_id', p_item_id, 'product_id', p_product_id,
    'jan_code', v_new.jan_code, 'product_name', v_new.name,
    'moved', coalesce(v_qty, 0), 'remembered', v_remember);
end;
$$;

revoke all on function public.convert_inspection_item(bigint, bigint, boolean) from public, anon;
grant execute on function public.convert_inspection_item(bigint, bigint, boolean)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Nothing unconverted passes
-- ---------------------------------------------------------------------------

do $$
declare v_src text;
begin
  select pg_get_functiondef('public.finalize_inspection_item_impl(bigint,text)'::regprocedure)
    into v_src;
  if position('not converted' in v_src) = 0 then
    v_src := replace(v_src,
'  if it.result = ''PENDING'' then',
'  if it.product_id is null and it.result not in (''FAIL'', ''HOLD'') then
    raise exception ''inspection item % is not converted to one of your products'', p_item_id;
  end if;
  if it.result = ''PENDING'' then');
    if position('not converted' in v_src) = 0 then
      raise exception 'finalize_inspection_item_impl did not have the expected shape';
    end if;
    execute v_src;
  end if;

  select pg_get_functiondef('public.complete_inspection(bigint,text,text)'::regprocedure)
    into v_src;
  if position('not converted' in v_src) = 0 then
    v_src := replace(v_src,
'  -- A line nobody judged is good by default (0100).',
'  select count(*) into v_pending from public.inspection_items
   where inspection_id = p_inspection_id and finalized_at is null
     and product_id is null and result not in (''FAIL'', ''HOLD'');
  if v_pending > 0 then
    raise exception ''inspection % has % lines not converted to your products'', p_inspection_id, v_pending;
  end if;
  -- A line nobody judged is good by default (0100).');
    if position('not converted' in v_src) = 0 then
      raise exception 'complete_inspection did not have the expected shape';
    end if;
    execute v_src;
  end if;

  select pg_get_functiondef('public.pass_inspection_items(bigint[],text)'::regprocedure)
    into v_src;
  if position('v_unconverted' in v_src) = 0 then
    v_src := replace(v_src, '  v_id       bigint;
begin', '  v_id       bigint;
  v_unconverted int := 0;
begin');
    v_src := replace(v_src,
'    select it.id, it.inspection_id, it.actual_quantity, it.finalized_at,',
'    select it.id, it.inspection_id, it.actual_quantity, it.finalized_at, it.product_id,');
    v_src := replace(v_src,
'    continue when r.finalized_at is not null or r.inspection_status <> ''PENDING'';',
'    continue when r.finalized_at is not null or r.inspection_status <> ''PENDING'';
    if r.product_id is null then
      v_unconverted := v_unconverted + 1;
      continue;
    end if;');
    v_src := replace(v_src,
'                            ''closed_inspections'', v_closed);',
'                            ''closed_inspections'', v_closed,
                            ''unconverted'', v_unconverted);');
    if position('''unconverted'', v_unconverted' in v_src) = 0
       or position('it.finalized_at, it.product_id' in v_src) = 0 then
      raise exception 'pass_inspection_items did not have the expected shape';
    end if;
    execute v_src;
  end if;

  select pg_get_functiondef('public.open_inspection_lines(bigint)'::regprocedure) into v_src;
  if position('src_jan_code' in v_src) = 0 then
    v_src := replace(v_src,
'      ''product_id'', it.product_id,',
'      ''product_id'', it.product_id,
      ''src_jan_code'', it.src_jan_code,
      ''src_product_name'', it.src_product_name,');
    if position('src_jan_code' in v_src) = 0 then
      raise exception 'open_inspection_lines did not have the expected shape';
    end if;
    execute v_src;
  end if;

  select pg_get_functiondef('public.list_products(text,text)'::regprocedure) into v_src;
  if position('p.maker' in v_src) = 0 then
    v_src := replace(v_src, '''sku'', p.sku, ''tracking_mode''',
                            '''sku'', p.sku, ''maker'', p.maker, ''tracking_mode''');
    v_src := replace(v_src, '            p.sku ilike ''%'' || p_search || ''%'' or',
                            '            p.sku ilike ''%'' || p_search || ''%'' or
            p.maker ilike ''%'' || p_search || ''%'' or');
    v_src := replace(v_src,
'                   ''supplier_code'', n.supplier_code, ''supplier_name'', n.supplier_name)',
'                   ''supplier_code'', n.supplier_code, ''supplier_name'', n.supplier_name,
                   ''supplier_jan_code'', n.supplier_jan_code, ''supplier_maker'', n.supplier_maker)');
    if position('p.maker ilike' in v_src) = 0 or position('supplier_maker' in v_src) = 0 then
      raise exception 'list_products did not have the expected shape';
    end if;
    execute v_src;
  end if;
end $$;

-- The inspection detail: our identity, the supplier's beside it.
create or replace function public.inspection_detail_impl(p_inspection_id bigint)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', i.id,
    'status', i.status,
    'warehouse_id', i.warehouse_id,
    'reconciliation_id', i.reconciliation_id,
    'delivery_plan_id', i.delivery_plan_id,
    'delivery_number', p.delivery_number,
    'supplier_name', p.supplier_name,
    'note', i.note,
    'created_at', i.created_at,
    'completed_at', i.completed_at,
    'arrived_on', (select r.arrived_on from public.delivery_reconciliations r
                     where r.id = i.reconciliation_id),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', it.id,
        'jan_code', it.jan_code,
        'product_id', it.product_id,
        'product_name', coalesce(pr.name, it.product_name),
        'product_sku', pr.sku,
        'product_maker', pr.maker,
        'src_jan_code', it.src_jan_code,
        'src_product_code', it.src_product_code,
        'src_product_name', it.src_product_name,
        'src_maker', it.src_maker,
        'converted_by', it.converted_by,
        'expected_quantity', it.expected_quantity,
        'actual_quantity', it.actual_quantity,
        'passed_quantity', it.passed_quantity,
        'failed_quantity', it.failed_quantity,
        'discrepancy', it.discrepancy,
        'lot', it.lot,
        'serial', it.serial,
        'expiry', it.expiry,
        'lot_id', it.lot_id,
        'serial_id', it.serial_id,
        'lot_code', (select l.lot_code from public.lots l where l.id = it.lot_id),
        'lot_expiry_date',
          (select l.expiry_date from public.lots l where l.id = it.lot_id),
        'serial_status',
          (select s.status from public.serial_numbers s where s.id = it.serial_id),
        'packaging_condition', it.packaging_condition,
        'product_condition', it.product_condition,
        'label_ok', it.label_ok,
        'result', it.result,
        'note', it.note,
        'finalized_at', it.finalized_at,
        'counted_quantity', it.counted_quantity,
        'note_quantity', it.note_quantity,
        'note_product_name', it.note_product_name
      ) order by it.id)
      from public.inspection_items it
      left join public.products pr on pr.id = it.product_id
      where it.inspection_id = i.id
    ), '[]'::jsonb)
  )
  from public.inspections i
  left join public.delivery_plans p on p.id = i.delivery_plan_id
  where i.id = p_inspection_id;
$$;

-- ---------------------------------------------------------------------------
-- Maker and the supplier's JAN/maker on the master screens
-- ---------------------------------------------------------------------------

drop function if exists public.set_product_identity(bigint, text, text);
create or replace function public.set_product_identity(
  p_id bigint, p_sku text default null, p_tracking_mode text default null,
  p_maker text default null)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_clear_sku boolean := p_sku is not null and btrim(p_sku) = '';
  v_sku text := nullif(btrim(coalesce(p_sku, '')), '');
  v_clear_maker boolean := p_maker is not null and btrim(p_maker) = '';
  v_maker text := nullif(btrim(coalesce(p_maker, '')), '');
  v_mode text := nullif(btrim(upper(coalesce(p_tracking_mode, ''))), '');
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if v_mode is not null and v_mode not in
     ('UNTRACKED', 'LOT', 'SERIAL', 'LOT_AND_SERIAL', 'EXPIRY') then
    raise exception 'unknown tracking_mode %', v_mode;
  end if;

  update public.products
     set sku = case when v_clear_sku then null else coalesce(v_sku, sku) end,
         maker = case when v_clear_maker then null else coalesce(v_maker, maker) end,
         tracking_mode = coalesce(v_mode, tracking_mode),
         updated_at = now()
   where id = p_id;
  if not found then
    raise exception 'product % not found', p_id;
  end if;

  perform public.log_audit('product.identity_updated', 'product', p_id::text,
    null, jsonb_build_object('sku', v_sku, 'sku_cleared', v_clear_sku,
                             'maker', v_maker, 'maker_cleared', v_clear_maker,
                             'tracking_mode', v_mode));
  return true;
end;
$$;

revoke all on function public.set_product_identity(bigint, text, text, text) from public, anon;
grant execute on function public.set_product_identity(bigint, text, text, text)
  to authenticated, service_role;

drop function if exists public.set_supplier_product_name(bigint, bigint, text, text, text);
create or replace function public.set_supplier_product_name(
  p_supplier_id bigint, p_product_id bigint, p_supplier_name text,
  p_supplier_code text default null, p_note text default null,
  p_supplier_jan_code text default null, p_supplier_maker text default null)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
  v_code text := nullif(btrim(coalesce(p_supplier_code, '')), '');
  v_jan text := nullif(btrim(coalesce(p_supplier_jan_code, '')), '');
  v_maker text := nullif(btrim(coalesce(p_supplier_maker, '')), '');
begin
  if not (public.has_permission('product.manage') or public.has_permission('purchase_order.manage')) then
    raise exception 'not permitted: product.manage required';
  end if;
  if nullif(btrim(coalesce(p_supplier_name, '')), '') is null then
    raise exception 'the supplier''s name for the product is required';
  end if;
  if not exists (select 1 from public.delivery_suppliers where id = p_supplier_id) then
    raise exception 'supplier % not found', p_supplier_id;
  end if;
  if not exists (select 1 from public.products where id = p_product_id) then
    raise exception 'product % not found', p_product_id;
  end if;
  if v_code is not null and exists (
       select 1 from public.supplier_product_names
        where supplier_id = p_supplier_id and supplier_code = v_code
          and product_id <> p_product_id) then
    raise exception 'this supplier already uses code % for another product', v_code;
  end if;

  insert into public.supplier_product_names
    (supplier_id, product_id, supplier_code, supplier_name, note, supplier_jan_code, supplier_maker)
  values (p_supplier_id, p_product_id, v_code, btrim(p_supplier_name),
          nullif(btrim(coalesce(p_note, '')), ''), v_jan, v_maker)
  on conflict (supplier_id, product_id) do update
     set supplier_code = excluded.supplier_code,
         supplier_name = excluded.supplier_name,
         note = excluded.note,
         supplier_jan_code = excluded.supplier_jan_code,
         supplier_maker = excluded.supplier_maker,
         updated_at = now()
  returning id into v_id;

  perform public.log_audit('product.supplier_name_set', 'product', p_product_id::text, null,
    jsonb_build_object('supplier_id', p_supplier_id, 'supplier_code', v_code,
                       'supplier_name', btrim(p_supplier_name),
                       'supplier_jan_code', v_jan, 'supplier_maker', v_maker));
  return v_id;
end;
$$;

revoke all on function public.set_supplier_product_name(bigint, bigint, text, text, text, text, text)
  from public, anon;
grant execute on function public.set_supplier_product_name(bigint, bigint, text, text, text, text, text)
  to authenticated, service_role;

create or replace function public.list_supplier_product_names(
  p_product_id bigint default null, p_supplier_id bigint default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('product.view') or public.has_permission('purchase_order.view')) then
    raise exception 'not permitted: product.view required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', n.id, 'supplier_id', n.supplier_id, 'supplier_display_name', s.name,
             'product_id', n.product_id, 'jan_code', p.jan_code, 'product_name', p.name,
             'supplier_code', n.supplier_code, 'supplier_name', n.supplier_name,
             'supplier_jan_code', n.supplier_jan_code, 'supplier_maker', n.supplier_maker,
             'note', n.note) order by s.name, p.name)
      from public.supplier_product_names n
      join public.delivery_suppliers s on s.id = n.supplier_id
      join public.products p on p.id = n.product_id
     where (p_product_id is null or n.product_id = p_product_id)
       and (p_supplier_id is null or n.supplier_id = p_supplier_id)), '[]'::jsonb);
end;
$$;

-- ---------------------------------------------------------------------------
-- The delivery note matches the supplier's writing as well as ours
-- ---------------------------------------------------------------------------

create or replace function public.apply_delivery_note(p_inspection_id bigint, p_lines jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_warehouse bigint;
  v_state     text;
  v_supplier  bigint;
  e           jsonb;
  v_idx       int := 0;
  v_jan       text;
  v_code      text;
  v_name      text;
  v_ncode     text;
  v_nname     text;
  v_qty       int;
  v_item      bigint;
  v_by        text;
  v_matched   jsonb := '[]'::jsonb;
  v_unmatched jsonb := '[]'::jsonb;
  v_touched   bigint[] := array[]::bigint[];
begin
  if not public.has_permission('inspection.confirm') then
    raise exception 'not permitted: inspection.confirm required';
  end if;
  select ins.warehouse_id, ins.status, public.receipt_supplier_id(ins.reconciliation_id)
    into v_warehouse, v_state, v_supplier
    from public.inspections ins
   where ins.id = p_inspection_id;
  if v_warehouse is null then
    raise exception 'inspection % not found', p_inspection_id;
  end if;
  if not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_state <> 'PENDING' then
    raise exception 'inspection % is already completed', p_inspection_id;
  end if;
  if jsonb_typeof(p_lines) is distinct from 'array' then
    raise exception 'lines must be a list';
  end if;

  for e in select * from jsonb_array_elements(p_lines) loop
    v_idx := v_idx + 1;
    v_jan := public.normalize_jan(e->>'jan_code');
    v_code := nullif(btrim(coalesce(e->>'product_code', '')), '');
    v_name := nullif(btrim(coalesce(e->>'product_name', '')), '');
    v_ncode := nullif(public.normalize_product_text(v_code), '');
    v_nname := nullif(public.normalize_product_text(v_name), '');
    v_qty := nullif(regexp_replace(coalesce(e->>'quantity', ''), '\D', '', 'g'), '')::int;
    v_item := null;
    v_by := null;

    -- 1. The JAN, ours or as the supplier wrote it.
    if v_jan is not null then
      select it.id into v_item from public.inspection_items it
       where it.inspection_id = p_inspection_id and it.finalized_at is null
         and (public.normalize_jan(it.jan_code) = v_jan
              or public.normalize_jan(it.src_jan_code) = v_jan)
       order by it.id limit 1;
      if v_item is null then
        select it.id into v_item from public.inspection_items it
         where it.inspection_id = p_inspection_id and it.finalized_at is null
           and it.product_id is not null
           and it.product_id = (public.resolve_supplier_product(v_supplier, v_jan)->>'product_id')::bigint
         order by it.id limit 1;
      end if;
      if v_item is not null then v_by := 'jan'; end if;
    end if;

    -- 2. A 品番: the supplier's on this delivery, the one they are known to
    --    use (0087), or ours.
    if v_item is null and v_ncode is not null then
      select it.id into v_item
        from public.inspection_items it
        left join public.products pr on pr.id = it.product_id
       where it.inspection_id = p_inspection_id and it.finalized_at is null
         and (public.normalize_product_text(it.src_product_code) = v_ncode
              or public.normalize_product_text(pr.sku) = v_ncode
              or exists (select 1 from public.supplier_product_names s
                          where s.product_id = it.product_id and s.supplier_id = v_supplier
                            and public.normalize_product_text(s.supplier_code) = v_ncode))
       order by it.id limit 1;
      if v_item is not null then v_by := 'supplier_name'; end if;
    end if;

    -- 3. A name, the same three ways.
    if v_item is null and v_nname is not null then
      select it.id into v_item
        from public.inspection_items it
        left join public.products pr on pr.id = it.product_id
       where it.inspection_id = p_inspection_id and it.finalized_at is null
         and (v_nname in (public.normalize_product_text(it.product_name),
                          public.normalize_product_text(it.src_product_name),
                          public.normalize_product_text(pr.name))
              or exists (select 1 from public.supplier_product_names s
                          where s.product_id = it.product_id and s.supplier_id = v_supplier
                            and public.normalize_product_text(s.supplier_name) = v_nname))
       order by it.id limit 1;
      if v_item is not null then v_by := 'name'; end if;
    end if;

    if v_item is not null then
      -- One photo replaces what an earlier read said for the lines it names
      -- (a retake), and adds up a product the note lists more than once.
      update public.inspection_items
         set note_quantity = case
               when v_qty is null then note_quantity
               when v_item = any(v_touched) then coalesce(note_quantity, 0) + v_qty
               else v_qty end,
             note_product_name = coalesce(v_name, note_product_name),
             src_product_code = coalesce(src_product_code, v_code)
       where id = v_item;
      v_touched := v_touched || v_item;
      v_matched := v_matched || jsonb_build_object(
        'line', v_idx, 'item_id', v_item, 'matched_by', v_by,
        'jan_code', v_jan, 'product_code', v_code, 'product_name', v_name, 'quantity', v_qty);
    else
      v_unmatched := v_unmatched || jsonb_build_object(
        'line', v_idx, 'jan_code', v_jan, 'product_code', v_code,
        'product_name', v_name, 'quantity', v_qty);
    end if;
  end loop;

  perform public.log_audit('inspection.delivery_note_applied', 'inspection',
    p_inspection_id::text, v_warehouse,
    jsonb_build_object('matched', jsonb_array_length(v_matched),
                       'unmatched', jsonb_array_length(v_unmatched)));

  return jsonb_build_object('matched', v_matched, 'unmatched', v_unmatched);
end;
$$;

revoke all on function public.apply_delivery_note(bigint, jsonb) from public, anon;
grant execute on function public.apply_delivery_note(bigint, jsonb) to authenticated, service_role;
