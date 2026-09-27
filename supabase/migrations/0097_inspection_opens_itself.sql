-- 0097 — goods that land in inspection open their own inspection.
--
-- Until now an inspection existed only once someone pressed 検品開始 on the
-- receipt. Goods sat in QC_PENDING — on hand, not shippable — with nothing in
-- the inspection list to say so, and the only trace was the held-stock list.
-- Now the moment a parcel is received into QC_PENDING, by whatever path
-- (reconcile, a parcel added by hand), its receipt's inspection exists and
-- carries a line for it:
--
--   * no inspection yet → one is opened (PENDING) for the receipt, with a line
--     for each receipt line that holds goods awaiting inspection — lines that
--     went straight to OK are not added, so nobody has to "check" them to
--     close it;
--   * an open inspection → the parcel's quantity is added to its line (or a
--     line is added). A line already judged goes back to 未チェック, because
--     the new goods have not been looked at;
--   * a closed inspection → refused: that inspection's moves are done, so
--     goods added to it now would never be released. Receive them as a new
--     receipt for the same delivery instead, which gets its own inspection.
--
-- 検品開始 still works as before (it opens the same inspection, or one for a
-- receipt with nothing in QC, covering every line).

create or replace function public.receipt_item_opens_inspection()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_code        text;
  v_inspection  bigint;
  v_state       text;
  v_item        bigint;
  v_plan        bigint;
  v_line        public.reconciliation_lines;
  v_name        text;
begin
  select code into v_code from public.stock_statuses where id = new.status_id;
  if v_code is distinct from 'QC_PENDING' or new.quantity <= 0 then
    return null;
  end if;

  select id, status into v_inspection, v_state
    from public.inspections where reconciliation_id = new.reconciliation_id
   for update;

  if v_inspection is null then
    select delivery_plan_id into v_plan
      from public.delivery_reconciliations where id = new.reconciliation_id;
    insert into public.inspections
      (company_id, warehouse_id, reconciliation_id, delivery_plan_id, status)
    values (new.company_id, new.warehouse_id, new.reconciliation_id, v_plan, 'PENDING')
    returning id, status into v_inspection, v_state;
    perform public.log_audit(
      'inspection.started', 'inspection', v_inspection::text, new.warehouse_id,
      jsonb_build_object('reconciliation_id', new.reconciliation_id,
                         'plan_id', v_plan, 'opened_by', 'receipt'));
  elsif v_state <> 'PENDING' then
    raise exception
      'the inspection of receipt % is closed; receive these goods as a new receipt for this delivery',
      new.reconciliation_id;
  end if;

  select * into v_line from public.reconciliation_lines where id = new.reconciliation_line_id;

  select id into v_item from public.inspection_items
   where inspection_id = v_inspection
     and ((v_line.id is not null and reconciliation_line_id = v_line.id)
          or (v_line.id is null and reconciliation_line_id is null and jan_code = new.jan_code))
   order by id limit 1;

  if v_item is null then
    v_name := coalesce(new.product_name,
                       (select pl.product_name from public.delivery_plan_lines pl
                         where pl.id = v_line.plan_line_id));
    insert into public.inspection_items
      (inspection_id, reconciliation_line_id, jan_code, product_name,
       expected_quantity, actual_quantity, product_id)
    values
      (v_inspection, v_line.id, new.jan_code, v_name,
       coalesce(v_line.planned_quantity, 0), new.quantity, new.product_id);
  else
    update public.inspection_items
       set actual_quantity = coalesce(actual_quantity, 0) + new.quantity,
           result = 'PENDING'
     where id = v_item;
  end if;

  return null;
end;
$$;

revoke all on function public.receipt_item_opens_inspection() from public, anon, authenticated;

drop trigger if exists receipt_items_open_inspection on public.receipt_items;
create trigger receipt_items_open_inspection
  after insert on public.receipt_items
  for each row execute function public.receipt_item_opens_inspection();

-- A parcel added by hand for a JAN the receipt had no line for (0092) made
-- the line after the parcel, so the inspection line opened above would not
-- know which receipt line it belongs to — and 0095 caps each inspection line
-- by its receipt line. The line is now made first, and the parcel recorded
-- against it.
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
  v_jan         text := nullif(btrim(coalesce(p_jan_code, '')), '');
  v_line        bigint := p_line_id;
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
  if v_jan is null then
    raise exception 'jan_code is required';
  end if;
  if coalesce(p_quantity, 0) <= 0 then
    raise exception 'quantity must be greater than zero';
  end if;

  select * into v_plan_line from public.delivery_plan_lines
   where delivery_plan_id = v_plan and jan_code = v_jan
   order by id limit 1;

  if v_line is null then
    select id into v_line from public.reconciliation_lines
     where reconciliation_id = p_reconciliation_id and jan_code = v_jan
     order by id limit 1;
  end if;
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
  end if;

  v_result := public.record_receipt_item_impl(
    p_reconciliation_id, v_warehouse, v_line, v_jan, p_quantity,
    p_lot_code, p_expiry, p_serial_number, p_location_code, p_status_code, p_note);

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
    'line_id', v_line,
    'plan_received', v_plan_line.received_quantity,
    'plan_outstanding', v_outstanding);
end;
$$;

revoke all on function public.record_receipt_item(
  bigint, text, integer, text, date, text, text, text, text, bigint) from public, anon;
grant execute on function public.record_receipt_item(
  bigint, text, integer, text, date, text, text, text, text, bigint) to authenticated, service_role;
