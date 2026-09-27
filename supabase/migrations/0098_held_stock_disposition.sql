-- 0098 — held and failed stock can be dealt with, not only looked at.
--
-- Inspection sends goods to HOLD or DAMAGED (0068), a receiver can name
-- QUARANTINE/DAMAGED on arrival (0072), and nothing in the app could move them
-- on: `move_stock_status` exists but no screen calls it, and there was no way
-- at all to write goods off or send them back. They stayed on hand forever,
-- inflating on-hand and never shipping.
--
--   * `held_stock(warehouse, status?)` — every parcel in a status that does not
--     count as available (QC_PENDING, HOLD, QUARANTINE, DAMAGED, EXPIRED,
--     BLOCKED), one status or all, nearest expiry first;
--   * `dispose_held_stock(...)` — one decision on one bucket of held goods:
--       release    → OK (checked again and fine; usable at once, and promised
--                    to linked orders per 0092);
--       hold / quarantine / damaged → move to that status;
--       scrap      → written off (movement SCRAP), a reason required;
--       return     → sent back to the supplier (movement RETURN_TO_SUPPLIER),
--                    a reason / return number required.
--     Changing status needs inspection.confirm or inventory.adjust; writing
--     off or returning takes stock out of the books, so it needs
--     inventory.adjust. Only non-available stock can be disposed of here —
--     shippable stock is adjusted through the adjustment screen as before.

alter table public.stock_movements drop constraint if exists stock_movements_movement_type_check;
alter table public.stock_movements add constraint stock_movements_movement_type_check
  check (movement_type = any (array[
    'OPENING', 'RECEIPT', 'RECEIPT_CANCEL', 'PUTAWAY', 'PICK', 'SHIP', 'SHIP_CANCEL',
    'ADJUST', 'COUNT', 'TRANSFER_IN', 'TRANSFER_OUT', 'WORK_ORDER_CONSUME',
    'WORK_ORDER_PRODUCE', 'SCRAP', 'RETURN_TO_SUPPLIER']));

create or replace function public.held_stock(
  p_warehouse_id bigint default null, p_status text default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_status text := upper(nullif(btrim(coalesce(p_status, '')), ''));
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
      'status_name', st.name,
      'received_at', (select max(ri.created_at) from public.receipt_items ri
                       where ri.product_id = su.product_id
                         and ri.warehouse_id = su.warehouse_id
                         and (su.lot_id is null or ri.lot_id = su.lot_id))
    ) order by l.expiry_date asc nulls last, p.jan_code, st.code)
    from public.stock_units su
    join public.stock_statuses st on st.id = su.status_id
    join public.products p on p.id = su.product_id
    left join public.lots l on l.id = su.lot_id
    left join public.serial_numbers sn on sn.id = su.serial_id
   where not st.counts_available
     and (v_status is null or st.code = v_status)
     and su.quantity > 0
     and (p_warehouse_id is null or su.warehouse_id = p_warehouse_id)
     and public.can_access_warehouse(su.warehouse_id)), '[]'::jsonb);
end;
$$;

revoke all on function public.held_stock(bigint, text) from public, anon;
grant execute on function public.held_stock(bigint, text) to authenticated, service_role;

create or replace function public.dispose_held_stock(
  p_warehouse_id bigint,
  p_product_id bigint,
  p_from_status text,
  p_action text,
  p_quantity integer,
  p_lot_id bigint default null,
  p_serial_id bigint default null,
  p_note text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_from      text := upper(btrim(coalesce(p_from_status, '')));
  v_action    text := lower(btrim(coalesce(p_action, '')));
  v_note      text := nullif(btrim(coalesce(p_note, '')), '');
  v_from_ok   boolean;
  v_in_bucket integer;
  v_to        text;
  v_done      integer := 0;
  v_left      integer;
  v_take      integer;
  v_jan       text;
  v_name      text;
  r           record;
begin
  if v_action not in ('release', 'hold', 'quarantine', 'damaged', 'scrap', 'return') then
    raise exception 'unknown action %', p_action;
  end if;
  if v_action in ('scrap', 'return') then
    if not public.has_permission('inventory.adjust') then
      raise exception 'not permitted: inventory.adjust required';
    end if;
    if v_note is null then
      raise exception 'a reason is required to write off or return goods';
    end if;
  elsif not (public.has_permission('inspection.confirm') or public.has_permission('inventory.adjust')) then
    raise exception 'not permitted: inspection.confirm required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if coalesce(p_quantity, 0) <= 0 then
    raise exception 'quantity must be greater than zero';
  end if;

  select counts_available into v_from_ok from public.stock_statuses where code = v_from;
  if v_from_ok is null then
    raise exception 'unknown stock status %', p_from_status;
  end if;
  if v_from_ok then
    raise exception 'only held stock can be disposed of here; % is shippable stock', v_from;
  end if;

  select coalesce(sum(su.quantity), 0)::int into v_in_bucket
    from public.stock_units su
    join public.stock_statuses st on st.id = su.status_id
   where su.product_id = p_product_id and su.warehouse_id = p_warehouse_id
     and st.code = v_from
     and (p_lot_id is null or su.lot_id = p_lot_id)
     and (p_serial_id is null or su.serial_id = p_serial_id);
  if v_in_bucket < p_quantity then
    raise exception 'only % in %, cannot dispose of %', v_in_bucket, v_from, p_quantity;
  end if;

  if v_action in ('release', 'hold', 'quarantine', 'damaged') then
    v_to := case v_action when 'release' then 'OK' else upper(v_action) end;
    if v_to = v_from then
      raise exception 'the stock is already %', v_from;
    end if;
    v_done := public.move_stock_status_impl(
      p_product_id, p_warehouse_id, p_quantity, v_to, v_from, p_lot_id, p_serial_id,
      coalesce(v_note, 'disposition: ' || v_action));
    if p_serial_id is not null then
      update public.serial_numbers
         set status = case when v_to = 'OK' then 'IN_STOCK' else 'HOLD' end, updated_at = now()
       where id = p_serial_id;
    end if;
  else
    -- Out of the books, parcel by parcel from the bucket, nearest expiry first.
    select jan_code, name into v_jan, v_name from public.products where id = p_product_id;
    v_left := p_quantity;
    for r in
      select su.quantity, su.lot_id, su.serial_id, su.bin_id
        from public.stock_units su
        join public.stock_statuses st on st.id = su.status_id
        left join public.lots l on l.id = su.lot_id
       where su.product_id = p_product_id and su.warehouse_id = p_warehouse_id
         and st.code = v_from and su.quantity > 0
         and (p_lot_id is null or su.lot_id = p_lot_id)
         and (p_serial_id is null or su.serial_id = p_serial_id)
       order by l.expiry_date asc nulls last, su.id
    loop
      exit when v_left <= 0;
      v_take := least(v_left, r.quantity);
      perform public.apply_stock_movement_detail(
        p_warehouse_id, v_jan, -v_take,
        case v_action when 'scrap' then 'SCRAP' else 'RETURN_TO_SUPPLIER' end,
        'disposition', null, v_name, r.bin_id, v_note, r.lot_id, r.serial_id, v_from, p_product_id);
      if r.serial_id is not null then
        update public.serial_numbers
           set status = case v_action when 'scrap' then 'SCRAPPED' else 'RETURNED' end,
               updated_at = now()
         where id = r.serial_id;
      end if;
      v_done := v_done + v_take;
      v_left := v_left - v_take;
    end loop;
  end if;

  perform public.log_audit('inventory.disposition', 'product', p_product_id::text, p_warehouse_id,
    jsonb_build_object('action', v_action, 'from', v_from, 'to', v_to,
                       'quantity', v_done, 'lot_id', p_lot_id, 'serial_id', p_serial_id,
                       'note', v_note));

  return jsonb_build_object(
    'product_id', p_product_id, 'warehouse_id', p_warehouse_id,
    'action', v_action, 'from', v_from, 'to', v_to, 'quantity', v_done,
    'on_hand', public.stock_on_hand(p_product_id, p_warehouse_id),
    'available', public.stock_available(p_product_id, p_warehouse_id));
end;
$$;

revoke all on function public.dispose_held_stock(bigint, bigint, text, text, integer, bigint, bigint, text)
  from public, anon;
grant execute on function public.dispose_held_stock(bigint, bigint, text, text, integer, bigint, bigint, text)
  to authenticated, service_role;
