-- 0092 — a parcel added by hand counts as received, and goods released from
-- inspection or hold go to the orders they were bought for straight away.
--
-- 1. `record_receipt_item` (a parcel added by hand to a receipt that already
--    exists) posted the stock and wrote the parcel, but told nobody upstream:
--    the receipt line's actual quantity, the delivery plan's received
--    quantity, and therefore the purchase order's received figure all stayed
--    where they were. The order kept showing the goods as still incoming, the
--    earmark trigger (0086, on `received_quantity`) never fired so the linked
--    sales orders were not promised the goods, and cancelling the receipt
--    later reversed only what the receipt line recorded — the hand-added
--    parcel stayed on the shelf. The public wrapper now does the same
--    bookkeeping `reconcile_delivery_plan` does for its own parcels: the
--    receipt line (created, if the JAN had none), the plan line, the plan's
--    status and the receipt's exceptions. The impl is unchanged, because
--    `reconcile_delivery_plan` calls it and already counts its parcels itself.
--    A cancelled receipt no longer takes parcels.
--
-- 2. Goods that land in inspection (QC_PENDING) or on hold are not usable, so
--    at receipt time there is nothing to promise; 0086 made up for it only at
--    the next approval or fill-from-stock, and in between anyone else's order
--    could be handed the goods first. `move_stock_status_impl` — the one path
--    both inspection completion and a manual status change go through — now
--    honours the purchase earmarks for that product as soon as stock moves
--    from a status that does not count as available into one that does.

create or replace function public.record_receipt_item(
  p_reconciliation_id bigint, p_jan_code text, p_quantity integer,
  p_lot_code text default null, p_expiry date default null,
  p_serial_number text default null, p_location_code text default null,
  p_status_code text default null, p_note text default null,
  p_line_id bigint default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_warehouse   bigint;
  v_plan        bigint;
  v_recon_state text;
  v_result      jsonb;
  v_jan         text;
  v_line        bigint;
  v_plan_line   public.delivery_plan_lines;
  v_outstanding integer;
begin
  if not public.has_permission('receiving.confirm') then
    raise exception 'not permitted: receiving.confirm required';
  end if;

  select coalesce(p.warehouse_id, public.default_warehouse_id()), p.id, r.status
    into v_warehouse, v_plan, v_recon_state
    from public.delivery_reconciliations r
    join public.delivery_plans p on p.id = r.delivery_plan_id
   where r.id = p_reconciliation_id;
  if v_warehouse is null then
    raise exception 'receipt % not found', p_reconciliation_id;
  end if;
  if not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_recon_state = 'cancelled' then
    raise exception 'receipt % is cancelled and cannot take more parcels', p_reconciliation_id;
  end if;

  v_result := public.record_receipt_item_impl(
    p_reconciliation_id, v_warehouse, p_line_id, p_jan_code, p_quantity,
    p_lot_code, p_expiry, p_serial_number, p_location_code, p_status_code, p_note);

  v_jan := v_result->>'jan_code';
  v_line := nullif(v_result->>'line_id', '')::bigint;

  select * into v_plan_line from public.delivery_plan_lines
   where delivery_plan_id = v_plan and jan_code = v_jan
   order by id limit 1;

  -- A JAN the receipt had no line for gets one, as reconcile would have made.
  if v_line is null then
    insert into public.reconciliation_lines
      (reconciliation_id, plan_line_id, jan_code, planned_quantity,
       actual_quantity, status, source)
    values
      (p_reconciliation_id, v_plan_line.id, v_jan,
       coalesce(v_plan_line.planned_quantity, 0), 0,
       case when v_plan_line.id is null then 'unexpected' else 'shortfall' end,
       'manual')
    returning id into v_line;
    update public.receipt_items set reconciliation_line_id = v_line
     where id = (v_result->>'receipt_item_id')::bigint;
    v_result := v_result || jsonb_build_object('line_id', v_line);
  end if;

  if v_plan_line.id is not null then
    update public.delivery_plan_lines
       set received_quantity = coalesce(received_quantity, 0) + p_quantity
     where id = v_plan_line.id
     returning * into v_plan_line;
  end if;

  update public.reconciliation_lines rl
     set actual_quantity = coalesce(rl.actual_quantity, 0) + p_quantity,
         status = case
           when rl.plan_line_id is null then 'unexpected'
           when v_plan_line.received_quantity = v_plan_line.planned_quantity then 'matched'
           when v_plan_line.received_quantity < v_plan_line.planned_quantity then 'shortfall'
           else 'over'
         end
   where rl.id = v_line;

  -- The plan is done once nothing is outstanding; otherwise it has started.
  select coalesce(sum(greatest(coalesce(planned_quantity, 0)
                               - coalesce(received_quantity, 0), 0)), 0)
    into v_outstanding
    from public.delivery_plan_lines where delivery_plan_id = v_plan;
  update public.delivery_plans
     set status = case when v_outstanding = 0 then 'completed' else 'partial' end
   where id = v_plan and status in ('open', 'partial', 'reconciling');
  if v_outstanding = 0 then
    update public.delivery_reconciliations set status = 'completed'
     where id = p_reconciliation_id and status = 'partial';
  end if;

  perform public.detect_receiving_exceptions(p_reconciliation_id);

  return v_result || jsonb_build_object(
    'plan_received', v_plan_line.received_quantity,
    'plan_outstanding', v_outstanding);
end;
$$;

revoke all on function public.record_receipt_item(
  bigint, text, integer, text, date, text, text, text, text, bigint) from public, anon;
grant execute on function public.record_receipt_item(
  bigint, text, integer, text, date, text, text, text, text, bigint) to authenticated, service_role;

-- 2. Released from inspection / hold → promised to the orders it was bought for.
do $$
declare v_src text;
begin
  select pg_get_functiondef(
    'public.move_stock_status_impl(bigint,bigint,integer,text,text,bigint,bigint,text)'::regprocedure)
    into v_src;
  if position('honor_purchase_earmarks' in v_src) = 0 then
    v_src := replace(v_src,
      '  return coalesce(p_quantity, 0) - v_left;
end;',
      '  -- Newly usable stock goes to the orders its purchase was linked to (0092).
  if coalesce(p_quantity, 0) - v_left > 0
     and not coalesce((select counts_available from public.stock_statuses where id = v_from_id), false)
     and coalesce((select counts_available from public.stock_statuses where id = v_to_id), false) then
    perform public.honor_purchase_earmarks(p_warehouse_id, p_product_id);
  end if;

  return coalesce(p_quantity, 0) - v_left;
end;');
    if position('honor_purchase_earmarks' in v_src) = 0 then
      raise exception 'move_stock_status_impl did not have the expected ending';
    end if;
    execute v_src;
  end if;
end $$;
