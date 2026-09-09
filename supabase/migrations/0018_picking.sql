-- 0018 — Picking (spec Step 7, §14)
--
-- Picking is a *state of the order*, not a stock movement: nothing leaves the
-- warehouse until it ships. So this migration adds no ledger entries of its own.
-- What it does add is the record of what was actually taken off the shelf, and
-- from 0018 on that record — not the order line — decides what ships.
--
-- Design notes:
--   * A short pick is recorded, never silently rounded up to plan (spec §10).
--     `variance` is a generated column so it cannot drift from the two numbers
--     it is derived from, the same way inspection discrepancy works.
--   * `bin_id` stays null unless the warehouse actually uses locations (0016).
--     Picking works fine without them; a bin is extra precision, not a
--     requirement.
--   * `ship_plan` and `cancel_shipment` are rewritten here. Shipping now
--     prefers picked quantities, and cancelling reverses what the ledger says
--     actually left rather than recomputing from the order lines — a plan whose
--     lines changed after shipping would otherwise reverse the wrong amount.

-- ---------------------------------------------------------------- pick lists

create table if not exists public.pick_lists (
  id                bigint generated always as identity primary key,
  shipment_plan_id  bigint not null references public.shipment_plans(id) on delete cascade,
  warehouse_id      bigint not null references public.warehouses(id),
  status            text not null default 'PICKING'
                      check (status in ('PICKING', 'PICKED', 'CANCELLED')),
  note              text,
  created_at        timestamptz not null default now(),
  completed_at      timestamptz
);

create index if not exists pick_lists_plan_idx
  on public.pick_lists (shipment_plan_id);
create index if not exists pick_lists_warehouse_idx
  on public.pick_lists (warehouse_id, status);

-- One open list per shipment plan: two pickers must not both be told to pick
-- the same order.
create unique index if not exists pick_lists_one_open_per_plan
  on public.pick_lists (shipment_plan_id)
  where status = 'PICKING';

create table if not exists public.pick_tasks (
  id                bigint generated always as identity primary key,
  pick_list_id      bigint not null references public.pick_lists(id) on delete cascade,
  shipment_line_id  bigint references public.shipment_lines(id) on delete set null,
  jan_code          text not null,
  product_name      text default '',
  planned_quantity  integer not null default 0,
  picked_quantity   integer,
  bin_id            bigint references public.bins(id),
  picked_at         timestamptz,
  note              text,
  -- Signed, like a count variance: negative is a short pick.
  variance integer generated always as
    (coalesce(picked_quantity, 0) - planned_quantity) stored,
  status text generated always as (
    case
      when picked_quantity is null then 'PENDING'
      when picked_quantity = planned_quantity then 'PICKED'
      when picked_quantity < planned_quantity then 'SHORT'
      else 'OVER'
    end) stored
);

create index if not exists pick_tasks_list_idx on public.pick_tasks (pick_list_id);
create index if not exists pick_tasks_jan_idx on public.pick_tasks (jan_code);

alter table public.pick_lists enable row level security;
alter table public.pick_tasks enable row level security;

drop policy if exists pick_lists_read on public.pick_lists;
create policy pick_lists_read on public.pick_lists
  for select to anon, authenticated using (true);

drop policy if exists pick_tasks_read on public.pick_tasks;
create policy pick_tasks_read on public.pick_tasks
  for select to anon, authenticated using (true);

-- --------------------------------------------------------------------- RPCs

-- Opens (or returns) the pick list for one shipment plan, seeding a task per
-- order line. Idempotent: calling it twice hands back the same open list rather
-- than duplicating the work.
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
    (pick_list_id, shipment_line_id, jan_code, product_name, planned_quantity)
  select v_id, l.id, l.jan_code, coalesce(l.product_name, ''),
         coalesce(l.quantity, 0)
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

-- Records what one task actually yielded. A bin is accepted only where the
-- warehouse uses locations and the bin belongs to it.
create or replace function public.record_pick(
  p_task_id bigint,
  p_quantity integer,
  p_bin_id bigint default null,
  p_note text default null
) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_list      bigint;
  v_status    text;
  v_warehouse bigint;
  v_uses_loc  boolean;
  v_bin_wh    bigint;
begin
  if p_quantity is null or p_quantity < 0 then
    raise exception 'picked quantity must be zero or more';
  end if;

  select t.pick_list_id, l.status, l.warehouse_id
    into v_list, v_status, v_warehouse
    from public.pick_tasks t
    join public.pick_lists l on l.id = t.pick_list_id
   where t.id = p_task_id;
  if v_list is null then raise exception 'pick task % not found', p_task_id; end if;
  if v_status <> 'PICKING' then
    raise exception 'pick list % is %', v_list, v_status;
  end if;

  if p_bin_id is not null then
    select w.uses_locations, b.warehouse_id into v_uses_loc, v_bin_wh
      from public.bins b join public.warehouses w on w.id = b.warehouse_id
     where b.id = p_bin_id;
    if v_bin_wh is null then raise exception 'bin % not found', p_bin_id; end if;
    if not v_uses_loc then
      raise exception 'warehouse % does not use locations', v_bin_wh;
    end if;
    if v_bin_wh <> v_warehouse then
      raise exception 'bin % belongs to another warehouse', p_bin_id;
    end if;
  end if;

  update public.pick_tasks
     set picked_quantity = p_quantity,
         bin_id = p_bin_id,
         note = nullif(p_note, ''),
         picked_at = now()
   where id = p_task_id;

  return p_task_id;
end;
$$;

-- Closes the list. Refuses while any task is untouched: an unpicked line is not
-- the same as a line picked as zero, and only the picker can say which it is.
create or replace function public.complete_pick_list(p_pick_list_id bigint)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_status    text;
  v_warehouse bigint;
  v_plan      bigint;
  v_pending   integer;
  v_summary   jsonb;
begin
  select status, warehouse_id, shipment_plan_id
    into v_status, v_warehouse, v_plan
    from public.pick_lists where id = p_pick_list_id;
  if v_status is null then
    raise exception 'pick list % not found', p_pick_list_id;
  end if;
  if v_status <> 'PICKING' then
    raise exception 'pick list % is already %', p_pick_list_id, v_status;
  end if;

  select count(*) into v_pending from public.pick_tasks
   where pick_list_id = p_pick_list_id and picked_quantity is null;
  if v_pending > 0 then
    raise exception 'pick list % still has % unpicked line(s)', p_pick_list_id, v_pending;
  end if;

  update public.pick_lists
     set status = 'PICKED', completed_at = now()
   where id = p_pick_list_id;

  -- The order moves on to packing. Shipping stays a separate, explicit act.
  update public.shipment_plans
     set status = 'packing'
   where id = v_plan and status = 'open';

  select jsonb_build_object(
           'pick_list_id', p_pick_list_id,
           'shipment_plan_id', v_plan,
           'tasks', count(*),
           'picked_units', coalesce(sum(picked_quantity), 0),
           'planned_units', coalesce(sum(planned_quantity), 0),
           'short_lines', count(*) filter (where status = 'SHORT'),
           'over_lines', count(*) filter (where status = 'OVER'))
    into v_summary
    from public.pick_tasks where pick_list_id = p_pick_list_id;

  perform public.log_audit(
    'pick_list.completed', 'pick_list', p_pick_list_id::text, v_warehouse, v_summary);

  return v_summary;
end;
$$;

-- Release: throws the picking away and puts the order back where it was. No
-- stock moved, so there is nothing to reverse.
create or replace function public.cancel_pick_list(p_pick_list_id bigint)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_status    text;
  v_warehouse bigint;
  v_plan      bigint;
begin
  select status, warehouse_id, shipment_plan_id
    into v_status, v_warehouse, v_plan
    from public.pick_lists where id = p_pick_list_id;
  if v_status is null then
    raise exception 'pick list % not found', p_pick_list_id;
  end if;
  if v_status = 'CANCELLED' then return p_pick_list_id; end if;

  update public.pick_lists set status = 'CANCELLED' where id = p_pick_list_id;

  -- Only fall back to 'open' when nothing else already picked this order.
  update public.shipment_plans p
     set status = 'open'
   where p.id = v_plan
     and p.status = 'packing'
     and not exists (select 1 from public.pick_lists x
                      where x.shipment_plan_id = v_plan and x.status = 'PICKED');

  perform public.log_audit(
    'pick_list.cancelled', 'pick_list', p_pick_list_id::text, v_warehouse,
    jsonb_build_object('was', v_status));

  return p_pick_list_id;
end;
$$;

-- ------------------------------------------------------------------- reading

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
               'product_name', t.product_name,
               'planned_quantity', t.planned_quantity,
               'picked_quantity', t.picked_quantity,
               'variance', t.variance,
               'status', t.status,
               'bin_id', t.bin_id,
               'bin_code', b.code,
               'note', t.note,
               'picked_at', t.picked_at) order by t.id)
        from public.pick_tasks t
        left join public.bins b on b.id = t.bin_id
       where t.pick_list_id = l.id), '[]'::jsonb))
  from public.pick_lists l
  join public.shipment_plans p on p.id = l.shipment_plan_id
  left join public.warehouses w on w.id = l.warehouse_id
  where l.id = p_pick_list_id;
$$;

create or replace function public.pick_list_index(
  p_warehouse_id bigint default null,
  p_status text default null,
  p_limit integer default 50
) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(row_to_json(x)::jsonb order by x.id desc), '[]'::jsonb)
  from (
    select l.id,
           l.shipment_plan_id,
           p.shipment_number,
           p.customer_name,
           l.warehouse_id,
           w.name as warehouse_name,
           l.status,
           l.created_at,
           l.completed_at,
           (select count(*) from public.pick_tasks t where t.pick_list_id = l.id)
             as task_count,
           (select count(*) from public.pick_tasks t
             where t.pick_list_id = l.id and t.picked_quantity is not null)
             as picked_count,
           (select count(*) from public.pick_tasks t
             where t.pick_list_id = l.id and t.status = 'SHORT')
             as short_count
      from public.pick_lists l
      join public.shipment_plans p on p.id = l.shipment_plan_id
      left join public.warehouses w on w.id = l.warehouse_id
     where (p_warehouse_id is null or l.warehouse_id = p_warehouse_id)
       and (p_status is null or l.status = p_status)
     order by l.id desc
     limit greatest(1, least(coalesce(p_limit, 50), 200))
  ) x;
$$;

-- What a picker can actually promise: on hand, minus everything already
-- committed to an open pick list but not yet taken off the shelf.
create or replace function public.stock_availability(
  p_warehouse_id bigint default null,
  p_jan_code text default null
) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(row_to_json(x)::jsonb order by x.available, x.jan_code), '[]'::jsonb)
  from (
    select s.warehouse_id,
           s.jan_code,
           s.product_name,
           s.on_hand,
           coalesce(r.reserved, 0) as reserved,
           s.on_hand - coalesce(r.reserved, 0) as available
      from public.stock_levels s
      left join (
        select l.warehouse_id, t.jan_code,
               sum(greatest(t.planned_quantity - coalesce(t.picked_quantity, 0), 0))
                 as reserved
          from public.pick_tasks t
          join public.pick_lists l on l.id = t.pick_list_id
         where l.status = 'PICKING'
         group by 1, 2
      ) r on r.warehouse_id = s.warehouse_id and r.jan_code = s.jan_code
     where (p_warehouse_id is null or s.warehouse_id = p_warehouse_id)
       and (p_jan_code is null or s.jan_code = p_jan_code)
  ) x;
$$;

-- ------------------------------------------------- shipping on picked figures

-- What this plan has actually taken out of stock so far, per JAN. Reading the
-- ledger rather than the order lines means a cancel reverses exactly what a
-- ship applied, even if the lines were edited in between.
create or replace function public.shipped_net(p_plan_id bigint)
returns table (jan_code text, quantity integer, product_name text)
language sql stable security definer set search_path = '' as $$
  select m.jan_code,
         sum(m.quantity)::int,
         coalesce(max(m.product_name), '')
    from public.stock_movements m
   where m.reference_type = 'shipment_plan'
     and m.reference_id = p_plan_id::text
     and m.movement_type in ('SHIP', 'SHIP_CANCEL')
     and m.balance_scope = 'WAREHOUSE'
   group by m.jan_code
  having sum(m.quantity) <> 0;
$$;

create or replace function public.ship_plan(p_plan_id bigint)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_status    text;
  v_warehouse bigint;
  v_picked    bigint;
  r           record;
begin
  select status, coalesce(warehouse_id, public.default_warehouse_id())
    into v_status, v_warehouse
    from public.shipment_plans where id = p_plan_id;
  if v_status is null then raise exception 'shipment % not found', p_plan_id; end if;
  if v_status = 'shipped' then return p_plan_id; end if;

  -- A completed pick list is the truth about what is on the cart. Without one
  -- the order lines still stand in, so plans that never went through picking
  -- ship exactly as they did before.
  select id into v_picked from public.pick_lists
   where shipment_plan_id = p_plan_id and status = 'PICKED'
   order by id desc limit 1;

  for r in
    select q.jan, q.qty, q.pname from (
      select t.jan_code as jan,
             sum(coalesce(t.picked_quantity, 0))::int as qty,
             coalesce(max(t.product_name), '') as pname
        from public.pick_tasks t
       where v_picked is not null and t.pick_list_id = v_picked
       group by t.jan_code
      union all
      select l.jan_code,
             sum(coalesce(l.quantity, 0))::int,
             coalesce(max(l.product_name), '')
        from public.shipment_lines l
       where v_picked is null and l.shipment_plan_id = p_plan_id
       group by l.jan_code
    ) q
    where q.qty > 0
  loop
    perform public.apply_stock_movement(
      v_warehouse, r.jan, -r.qty, 'SHIP',
      'shipment_plan', p_plan_id::text, r.pname);
  end loop;

  update public.shipment_plans
     set status = 'shipped', shipped_at = now()
   where id = p_plan_id;

  perform public.log_audit(
    'shipment.completed', 'shipment_plan', p_plan_id::text, v_warehouse,
    jsonb_build_object('pick_list_id', v_picked));

  return p_plan_id;
end;
$$;

create or replace function public.cancel_shipment(p_plan_id bigint)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_status    text;
  v_warehouse bigint;
  v_back_to   text;
  r           record;
begin
  select status, coalesce(warehouse_id, public.default_warehouse_id())
    into v_status, v_warehouse
    from public.shipment_plans where id = p_plan_id;
  if v_status is null then raise exception 'shipment % not found', p_plan_id; end if;

  if v_status = 'shipped' then
    -- Reverse the ledger's own net, so this puts back exactly what went out.
    for r in select * from public.shipped_net(p_plan_id) loop
      perform public.apply_stock_movement(
        v_warehouse, r.jan_code, -r.quantity, 'SHIP_CANCEL',
        'shipment_plan', p_plan_id::text, r.product_name);
    end loop;
  end if;

  -- Back to packing when the picking still stands, otherwise back to open.
  select case when exists (
           select 1 from public.pick_lists
            where shipment_plan_id = p_plan_id and status = 'PICKED')
         then 'packing' else 'open' end
    into v_back_to;

  update public.shipment_plans
     set status = v_back_to, shipped_at = null
   where id = p_plan_id;

  perform public.log_audit(
    'shipment.cancelled', 'shipment_plan', p_plan_id::text, v_warehouse,
    jsonb_build_object('was', v_status, 'now', v_back_to));

  return p_plan_id;
end;
$$;

-- -------------------------------------------------------------------- grants
--
-- Postgres grants EXECUTE to PUBLIC by default, so every mutating routine has
-- to be taken away explicitly or anon could pick and ship straight from the
-- browser key.

revoke all on function public.start_pick_list(bigint, text) from public, anon, authenticated;
revoke all on function public.record_pick(bigint, integer, bigint, text) from public, anon, authenticated;
revoke all on function public.complete_pick_list(bigint) from public, anon, authenticated;
revoke all on function public.cancel_pick_list(bigint) from public, anon, authenticated;
revoke all on function public.ship_plan(bigint) from public, anon, authenticated;
revoke all on function public.cancel_shipment(bigint) from public, anon, authenticated;
-- Internal helper for cancel_shipment, not part of the read surface.
revoke all on function public.shipped_net(bigint) from public, anon, authenticated;

grant execute on function public.start_pick_list(bigint, text) to service_role;
grant execute on function public.record_pick(bigint, integer, bigint, text) to service_role;
grant execute on function public.complete_pick_list(bigint) to service_role;
grant execute on function public.cancel_pick_list(bigint) to service_role;
grant execute on function public.ship_plan(bigint) to service_role;
grant execute on function public.cancel_shipment(bigint) to service_role;

grant execute on function public.pick_list_detail(bigint) to anon, authenticated, service_role;
grant execute on function public.pick_list_index(bigint, text, integer) to anon, authenticated, service_role;
grant execute on function public.stock_availability(bigint, text) to anon, authenticated, service_role;
grant execute on function public.shipped_net(bigint) to service_role;
