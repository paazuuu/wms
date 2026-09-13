-- 0039 — Packing: auto carton split + shipping logistics fields
--
-- UI spec §18 ("箱数自動計算 … 手計算を要求しない") and §21's Shipping UI, which
-- wants weight / carrier / tracking beside the carton list.
--
-- `pack.complete` has existed since 0012 (granted to warehouse_manager and
-- packer) with nothing implementing it — the same dormant-permission pattern as
-- `report.view` in 0037 and `putaway.confirm` in 0038. Both RPCs here are gated
-- on it.
--
-- Neither RPC moves stock: cartons record *how* the already-picked quantity is
-- boxed, and ship_plan (0008/0014) remains the only thing that deducts it.

-- §21: the logistics the shipping desk fills in before confirming.
alter table public.shipment_plans
  add column if not exists weight_kg       numeric(10,2),
  add column if not exists carrier         text,
  add column if not exists tracking_number text;

-- ---------------------------------------------------------------------------
-- §18 — split a shipment into cartons of at most p_units_per_carton pieces.
--
-- Fills sequentially: a carton takes as much of the current line as fits, then
-- the next line continues in the same carton. That matches how a packer
-- actually works (fill the box, start another), and for the spec's own example
-- (one SKU, 237 @ 24) it produces exactly 10 boxes with 21 in the last.
--
-- Refuses when cartons already exist rather than merging into them: re-packing
-- a half-packed shipment silently would be the kind of quiet data change §48
-- warns about. The packer deletes the cartons they do not want first.
create or replace function public.autopack_shipment(
  p_plan_id          bigint,
  p_units_per_carton int
) returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_status      text;
  v_total       int;
  v_carton_id   bigint;
  v_carton_no   int := 0;
  v_room        int := 0;
  v_take        int;
  v_remaining   int;
  v_warehouse   bigint;
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
  if v_status not in ('open', 'packing') then
    raise exception 'shipment % is % and cannot be packed', p_plan_id, v_status;
  end if;
  if exists (select 1 from public.shipment_cartons
              where shipment_plan_id = p_plan_id) then
    raise exception 'shipment % already has cartons; delete them first',
      p_plan_id;
  end if;

  select coalesce(sum(quantity), 0) into v_total
    from public.shipment_lines where shipment_plan_id = p_plan_id;
  if v_total <= 0 then
    raise exception 'shipment % has nothing to pack', p_plan_id;
  end if;

  for r in
    select id, jan_code, product_name, spec, quantity
      from public.shipment_lines
     where shipment_plan_id = p_plan_id and quantity > 0
     order by id
  loop
    v_remaining := r.quantity;
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
        (carton_id, shipment_line_id, jan_code, product_name, spec, quantity)
      values (v_carton_id, r.id, r.jan_code,
              coalesce(r.product_name, ''), r.spec, v_take);
      v_room := v_room - v_take;
      v_remaining := v_remaining - v_take;
    end loop;
  end loop;

  -- Packing has begun, so the order is out of the untouched 'open' state. Not
  -- 'shipped': confirming a shipment stays a separate, explicit act (§21).
  update public.shipment_plans set status = 'packing'
   where id = p_plan_id and status = 'open';

  perform public.log_audit('shipment.autopacked', 'shipment_plan',
    p_plan_id::text, v_warehouse,
    jsonb_build_object('cartons', v_carton_no,
                       'units_per_carton', p_units_per_carton,
                       'total_units', v_total));

  return jsonb_build_object(
    'shipment_plan_id', p_plan_id,
    'carton_count', v_carton_no,
    'units_per_carton', p_units_per_carton,
    'total_units', v_total
  );
end $function$;

revoke all on function public.autopack_shipment(bigint, int) from public, anon;
grant execute on function public.autopack_shipment(bigint, int) to authenticated;

-- ---------------------------------------------------------------------------
-- §21 — weight / carrier / tracking. Nulls clear a field, so a mistyped
-- tracking number can be taken back out rather than only overwritten.
create or replace function public.set_shipment_logistics(
  p_plan_id         bigint,
  p_weight_kg       numeric default null,
  p_carrier         text    default null,
  p_tracking_number text    default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_status    text;
  v_warehouse bigint;
begin
  if not public.has_permission('pack.complete') then
    raise exception 'permission denied: pack.complete';
  end if;

  select status, warehouse_id into v_status, v_warehouse
    from public.shipment_plans where id = p_plan_id;
  if v_status is null then
    raise exception 'shipment % not found', p_plan_id;
  end if;
  if v_status = 'cancelled' then
    raise exception 'shipment % is cancelled', p_plan_id;
  end if;
  if p_weight_kg is not null and p_weight_kg < 0 then
    raise exception 'weight cannot be negative';
  end if;

  update public.shipment_plans
     set weight_kg       = p_weight_kg,
         carrier         = nullif(btrim(coalesce(p_carrier, '')), ''),
         tracking_number = nullif(btrim(coalesce(p_tracking_number, '')), '')
   where id = p_plan_id;

  perform public.log_audit('shipment.logistics_set', 'shipment_plan',
    p_plan_id::text, v_warehouse,
    jsonb_build_object('weight_kg', p_weight_kg,
                       'carrier', p_carrier,
                       'tracking_number', p_tracking_number));

  return jsonb_build_object(
    'shipment_plan_id', p_plan_id,
    'weight_kg', p_weight_kg,
    'carrier', nullif(btrim(coalesce(p_carrier, '')), ''),
    'tracking_number', nullif(btrim(coalesce(p_tracking_number, '')), '')
  );
end $function$;

revoke all on function public.set_shipment_logistics(bigint, numeric, text, text) from public, anon;
grant execute on function public.set_shipment_logistics(bigint, numeric, text, text) to authenticated;
