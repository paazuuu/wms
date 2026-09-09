-- Step 4 groundwork, part 2 (spec §17, §18, §41): route every stock change
-- through the ledger helper added in 0013.
--
-- Behaviour of each RPC is otherwise unchanged (same statuses, same clamping,
-- same return values); what is new is that stock now moves only via
-- apply_stock_movement, so each change leaves a movement row, and each
-- operation leaves an audit entry (spec §33).
--
-- Also closes a real hole: PostgreSQL grants function EXECUTE to PUBLIC by
-- default, so anon could call reconcile_delivery_plan / ship_plan directly and
-- fabricate stock. Mutating routines are revoked from PUBLIC/anon/authenticated
-- and granted only to service_role, which is what the edge functions use.
-- (This corrects the claim made in 0012 about log_audit.)

-- ------------------------------------------------- inbound: receive / cancel
create or replace function public.reconcile_delivery_plan(
  p_plan_id bigint,
  p_complete boolean default true,
  p_note_reference text default null,
  p_lines jsonb default '[]'::jsonb
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_recon_id    bigint;
  v_supplier    bigint;
  v_ref         text;
  v_outstanding int;
  v_status      text;
  v_warehouse   bigint;
  r             record;
begin
  select supplier_id, coalesce(warehouse_id, public.default_warehouse_id())
    into v_supplier, v_warehouse
    from public.delivery_plans where id = p_plan_id;
  v_ref := public.assign_reference(v_supplier);

  insert into public.delivery_reconciliations
    (delivery_plan_id, note_reference, status, supplier_id, reference_no)
  values
    (p_plan_id, p_note_reference, 'received', v_supplier, v_ref)
  returning id into v_recon_id;

  insert into public.reconciliation_lines
    (reconciliation_id, plan_line_id, jan_code, planned_quantity,
     actual_quantity, status, source)
  select
    v_recon_id, pl.id, (e->>'jan_code'),
    coalesce(pl.planned_quantity, 0),
    coalesce((e->>'actual_quantity')::int, 0),
    case
      when pl.id is null then 'unexpected'
      when coalesce((e->>'actual_quantity')::int, 0) = 0 then 'shortfall'
      when coalesce(pl.received_quantity, 0) + coalesce((e->>'actual_quantity')::int, 0)
           = pl.planned_quantity then 'matched'
      when coalesce(pl.received_quantity, 0) + coalesce((e->>'actual_quantity')::int, 0)
           < pl.planned_quantity then 'shortfall'
      else 'over'
    end,
    (e->>'source')
  from jsonb_array_elements(p_lines) as e
  left join public.delivery_plan_lines pl
    on pl.delivery_plan_id = p_plan_id and pl.jan_code = (e->>'jan_code');

  update public.delivery_plan_lines pl
     set received_quantity = coalesce(pl.received_quantity, 0) + agg.qty
  from (
    select (e->>'jan_code') as jan,
           sum(coalesce((e->>'actual_quantity')::int, 0)) as qty
    from jsonb_array_elements(p_lines) as e
    group by 1
  ) agg
  where pl.delivery_plan_id = p_plan_id and pl.jan_code = agg.jan;

  -- Stock: one RECEIPT movement per item, snapshot updated by the helper.
  for r in
    select (e->>'jan_code') as jan,
           sum(coalesce((e->>'actual_quantity')::int, 0))::int as qty,
           coalesce(max(pl.product_name), '') as pname
    from jsonb_array_elements(p_lines) as e
    left join public.delivery_plan_lines pl
      on pl.delivery_plan_id = p_plan_id and pl.jan_code = (e->>'jan_code')
    group by 1
    having sum(coalesce((e->>'actual_quantity')::int, 0)) > 0
  loop
    perform public.apply_stock_movement(
      v_warehouse, r.jan, r.qty, 'RECEIPT',
      'reconciliation', v_recon_id::text, r.pname);
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

create or replace function public.cancel_reconciliation(p_recon_id bigint)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_plan        bigint;
  v_status      text;
  v_received    int;
  v_outstanding int;
  v_warehouse   bigint;
  r             record;
begin
  select delivery_plan_id, status into v_plan, v_status
    from public.delivery_reconciliations where id = p_recon_id;
  if v_plan is null then
    raise exception 'reconciliation % not found', p_recon_id;
  end if;
  if v_status = 'cancelled' then
    return p_recon_id;
  end if;

  select coalesce(warehouse_id, public.default_warehouse_id()) into v_warehouse
    from public.delivery_plans where id = v_plan;

  update public.delivery_plan_lines pl
     set received_quantity = greatest(coalesce(pl.received_quantity, 0) - agg.qty, 0)
  from (
    select plan_line_id, sum(coalesce(actual_quantity, 0)) as qty
    from public.reconciliation_lines
    where reconciliation_id = p_recon_id and plan_line_id is not null
    group by plan_line_id
  ) agg
  where pl.id = agg.plan_line_id;

  -- Stock: reverse each received item as its own movement.
  for r in
    select jan_code as jan, sum(coalesce(actual_quantity, 0))::int as qty
    from public.reconciliation_lines
    where reconciliation_id = p_recon_id and coalesce(actual_quantity, 0) > 0
    group by 1
  loop
    perform public.apply_stock_movement(
      v_warehouse, r.jan, -r.qty, 'RECEIPT_CANCEL',
      'reconciliation', p_recon_id::text);
  end loop;

  update public.delivery_reconciliations set status = 'cancelled' where id = p_recon_id;

  select coalesce(sum(coalesce(received_quantity, 0)), 0),
         coalesce(sum(greatest(
           coalesce(planned_quantity, 0) - coalesce(received_quantity, 0), 0)), 0)
    into v_received, v_outstanding
  from public.delivery_plan_lines where delivery_plan_id = v_plan;

  update public.delivery_plans
     set status = case
       when v_received = 0 then 'open'
       when v_outstanding = 0 then 'completed'
       else 'partial' end
   where id = v_plan;

  perform public.log_audit(
    'receiving.cancelled', 'reconciliation', p_recon_id::text, v_warehouse,
    jsonb_build_object('plan_id', v_plan));

  return p_recon_id;
end;
$$;

-- ------------------------------------------------- outbound: ship / cancel
create or replace function public.ship_plan(p_plan_id bigint)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status    text;
  v_warehouse bigint;
  r           record;
begin
  select status, coalesce(warehouse_id, public.default_warehouse_id())
    into v_status, v_warehouse
    from public.shipment_plans where id = p_plan_id;
  if v_status is null then raise exception 'shipment % not found', p_plan_id; end if;
  if v_status = 'shipped' then return p_plan_id; end if;

  for r in
    select jan_code as jan,
           sum(coalesce(quantity, 0))::int as qty,
           coalesce(max(product_name), '') as pname
    from public.shipment_lines
    where shipment_plan_id = p_plan_id
    group by 1
    having sum(coalesce(quantity, 0)) > 0
  loop
    perform public.apply_stock_movement(
      v_warehouse, r.jan, -r.qty, 'SHIP',
      'shipment_plan', p_plan_id::text, r.pname);
  end loop;

  update public.shipment_plans
     set status = 'shipped', shipped_at = now()
   where id = p_plan_id;

  perform public.log_audit(
    'shipment.completed', 'shipment_plan', p_plan_id::text, v_warehouse, '{}'::jsonb);

  return p_plan_id;
end;
$$;

create or replace function public.cancel_shipment(p_plan_id bigint)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status    text;
  v_warehouse bigint;
  r           record;
begin
  select status, coalesce(warehouse_id, public.default_warehouse_id())
    into v_status, v_warehouse
    from public.shipment_plans where id = p_plan_id;
  if v_status is null then raise exception 'shipment % not found', p_plan_id; end if;

  if v_status = 'shipped' then
    for r in
      select jan_code as jan,
             sum(coalesce(quantity, 0))::int as qty,
             coalesce(max(product_name), '') as pname
      from public.shipment_lines
      where shipment_plan_id = p_plan_id
      group by 1
      having sum(coalesce(quantity, 0)) > 0
    loop
      perform public.apply_stock_movement(
        v_warehouse, r.jan, r.qty, 'SHIP_CANCEL',
        'shipment_plan', p_plan_id::text, r.pname);
    end loop;
  end if;

  update public.shipment_plans
     set status = 'open', shipped_at = null
   where id = p_plan_id;

  perform public.log_audit(
    'shipment.cancelled', 'shipment_plan', p_plan_id::text, v_warehouse,
    jsonb_build_object('was', v_status));

  return p_plan_id;
end;
$$;

-- --------------------------------------------------------- reading the ledger
-- "Why did stock change?" for one item, newest first (spec §18).
create or replace function public.stock_ledger(
  p_jan_code text default null,
  p_warehouse_id bigint default null,
  p_limit integer default 100
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(row_to_json(t) order by t.created_at desc, t.id desc), '[]'::jsonb)
  from (
    select m.id, m.created_at, m.warehouse_id, w.name as warehouse_name,
           m.bin_id, m.jan_code, m.product_name, m.movement_type,
           m.quantity, m.quantity_before, m.quantity_after,
           m.reference_type, m.reference_id, m.actor_user_id, m.note
    from public.stock_movements m
    left join public.warehouses w on w.id = m.warehouse_id
    where (p_jan_code is null or m.jan_code = p_jan_code)
      and (p_warehouse_id is null or m.warehouse_id = p_warehouse_id)
    order by m.created_at desc, m.id desc
    limit greatest(coalesce(p_limit, 100), 1)
  ) t;
$$;

-- ----------------------------------------------------------------------- RLS
alter table public.stock_movements enable row level security;

drop policy if exists "read stock movements" on public.stock_movements;
create policy "read stock movements" on public.stock_movements
  for select to anon, authenticated using (true);

-- ------------------------------------------------------------------- grants
-- Read-only helpers stay client-callable.
grant execute on function public.default_warehouse_id() to anon, authenticated;
grant execute on function public.stock_ledger(text, bigint, integer) to anon, authenticated;

-- Everything that changes stock or writes audit rows is service-role only.
-- PostgreSQL grants EXECUTE to PUBLIC by default, so these REVOKEs are what
-- actually close the door (a plain "no GRANT" would not).
revoke execute on function public.apply_stock_movement(bigint, text, integer, text, text, text, text, bigint, text) from public, anon, authenticated;
revoke execute on function public.reconcile_delivery_plan(bigint, boolean, text, jsonb) from public, anon, authenticated;
revoke execute on function public.cancel_reconciliation(bigint) from public, anon, authenticated;
revoke execute on function public.ship_plan(bigint) from public, anon, authenticated;
revoke execute on function public.cancel_shipment(bigint) from public, anon, authenticated;
revoke execute on function public.assign_reference(bigint) from public, anon, authenticated;
revoke execute on function public.log_audit(text, text, text, bigint, jsonb) from public, anon, authenticated;

grant execute on function public.apply_stock_movement(bigint, text, integer, text, text, text, text, bigint, text) to service_role;
grant execute on function public.reconcile_delivery_plan(bigint, boolean, text, jsonb) to service_role;
grant execute on function public.cancel_reconciliation(bigint) to service_role;
grant execute on function public.ship_plan(bigint) to service_role;
grant execute on function public.cancel_shipment(bigint) to service_role;
grant execute on function public.assign_reference(bigint) to service_role;
grant execute on function public.log_audit(text, text, text, bigint, jsonb) to service_role;
