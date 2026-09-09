-- 0019 — Inter-warehouse transfer (spec Step 11, §16)
--
-- "重要。2倉庫以上になったら必須機能。" — required once a second warehouse
-- exists. Follows the state machine the spec lays out verbatim:
--
--   DRAFT → PENDING_APPROVAL → APPROVED → PICKING → IN_TRANSIT → RECEIVING
--         → COMPLETED
--   (PENDING_APPROVAL can also go to REJECTED; DRAFT/PENDING_APPROVAL/
--    APPROVED/PICKING can go to CANCELLED — nothing has left the source yet
--    in any of those states)
--
-- Design notes, consistent with the rest of the ledger:
--   * Picking a transfer line and receiving one both use the same
--     nullable-quantity + generated-variance shape as pick_tasks (0018),
--     inspection items (0015) and count lines (0017): a short pick or a
--     transit loss is recorded as its own number, never silently corrected
--     to what was planned (spec §10).
--   * Stock only moves twice: TRANSFER_OUT at the source when picking is
--     completed (IN_TRANSIT begins), TRANSFER_IN at the destination when
--     receiving is completed. Both movement types already exist in
--     stock_movements' check constraint (added ahead of time in 0013).
--   * requested_by/approved_by are captured from auth.uid() inside the RPCs,
--     never taken as a parameter — the same rule apply_stock_movement and
--     log_audit already follow, so a caller can't forge who acted.
--   * Self-approval is refused once both sides are known. The app is still
--     login-free (auth.uid() is null), so this guard is inactive today —
--     same transitional gate documented in 0012's permission model — and
--     starts enforcing the moment sign-in ships.

create table if not exists public.transfer_orders (
  id                      bigint generated always as identity primary key,
  transfer_number         text,
  source_warehouse_id     bigint not null references public.warehouses(id),
  destination_warehouse_id bigint not null references public.warehouses(id),
  status                  text not null default 'DRAFT' check (status in (
                            'DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'PICKING',
                            'IN_TRANSIT', 'RECEIVING', 'COMPLETED', 'REJECTED',
                            'CANCELLED')),
  note                    text,
  requested_by            uuid,
  approved_by             uuid,
  approved_at             timestamptz,
  shipped_at              timestamptz,
  received_at             timestamptz,
  created_at              timestamptz not null default now(),
  constraint transfer_orders_distinct_warehouses
    check (source_warehouse_id <> destination_warehouse_id)
);

create unique index if not exists transfer_orders_number_idx
  on public.transfer_orders (transfer_number) where transfer_number is not null;
create index if not exists transfer_orders_source_idx
  on public.transfer_orders (source_warehouse_id, status);
create index if not exists transfer_orders_destination_idx
  on public.transfer_orders (destination_warehouse_id, status);

create table if not exists public.transfer_order_lines (
  id                  bigint generated always as identity primary key,
  transfer_order_id   bigint not null references public.transfer_orders(id) on delete cascade,
  jan_code            text not null,
  product_name        text default '',
  requested_quantity  integer not null check (requested_quantity > 0),
  picked_quantity     integer,
  received_quantity   integer,
  note                text,
  -- Signed, same shape as a pick task's or a count line's variance.
  pick_variance integer generated always as
    (picked_quantity - requested_quantity) stored,
  receive_variance integer generated always as
    (received_quantity - picked_quantity) stored
);

create index if not exists transfer_order_lines_order_idx
  on public.transfer_order_lines (transfer_order_id);
create index if not exists transfer_order_lines_jan_idx
  on public.transfer_order_lines (jan_code);

alter table public.transfer_orders enable row level security;
alter table public.transfer_order_lines enable row level security;

drop policy if exists transfer_orders_read on public.transfer_orders;
create policy transfer_orders_read on public.transfer_orders
  for select to anon, authenticated using (true);

drop policy if exists transfer_order_lines_read on public.transfer_order_lines;
create policy transfer_order_lines_read on public.transfer_order_lines
  for select to anon, authenticated using (true);

-- --------------------------------------------------------------------- RPCs

-- Creates the order and its lines in one call — a transfer has no existing
-- order to snapshot from, so the caller supplies what to move directly.
create or replace function public.create_transfer_order(
  p_source_warehouse_id bigint,
  p_destination_warehouse_id bigint,
  p_lines jsonb,
  p_note text default null
) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
  v_line jsonb;
  v_qty integer;
begin
  if p_source_warehouse_id = p_destination_warehouse_id then
    raise exception 'source and destination must be different warehouses';
  end if;
  if not exists (select 1 from public.warehouses where id = p_source_warehouse_id) then
    raise exception 'source warehouse % not found', p_source_warehouse_id;
  end if;
  if not exists (select 1 from public.warehouses where id = p_destination_warehouse_id) then
    raise exception 'destination warehouse % not found', p_destination_warehouse_id;
  end if;
  if jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'at least one line is required';
  end if;

  insert into public.transfer_orders
    (source_warehouse_id, destination_warehouse_id, note, requested_by)
  values (p_source_warehouse_id, p_destination_warehouse_id, nullif(p_note, ''), auth.uid())
  returning id into v_id;

  update public.transfer_orders
     set transfer_number = 'TR-' || lpad(v_id::text, 6, '0')
   where id = v_id;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_qty := coalesce((v_line->>'quantity')::int, 0);
    if v_qty > 0 and coalesce(v_line->>'jan_code', '') <> '' then
      insert into public.transfer_order_lines
        (transfer_order_id, jan_code, product_name, requested_quantity)
      values (v_id, v_line->>'jan_code', coalesce(v_line->>'product_name', ''), v_qty);
    end if;
  end loop;

  if not exists (select 1 from public.transfer_order_lines where transfer_order_id = v_id) then
    raise exception 'at least one line with a positive quantity is required';
  end if;

  perform public.log_audit(
    'transfer.created', 'transfer_order', v_id::text, p_source_warehouse_id,
    jsonb_build_object('destination_warehouse_id', p_destination_warehouse_id));

  return v_id;
end;
$$;

create or replace function public.submit_transfer_order(p_transfer_id bigint)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_status text;
  v_source bigint;
begin
  select status, source_warehouse_id into v_status, v_source
    from public.transfer_orders where id = p_transfer_id;
  if v_status is null then raise exception 'transfer % not found', p_transfer_id; end if;
  if v_status <> 'DRAFT' then
    raise exception 'transfer % is % and cannot be submitted', p_transfer_id, v_status;
  end if;

  update public.transfer_orders set status = 'PENDING_APPROVAL' where id = p_transfer_id;
  perform public.log_audit(
    'transfer.submitted', 'transfer_order', p_transfer_id::text, v_source, '{}'::jsonb);
  return p_transfer_id;
end;
$$;

-- Self-approval is refused once both requester and approver are known
-- (spec §16: "自己承認禁止"). Inactive while the app has no sign-in, same
-- transitional gate as 0012's has_permission.
create or replace function public.approve_transfer_order(p_transfer_id bigint)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_status  text;
  v_source  bigint;
  v_by      uuid;
  v_approver uuid := auth.uid();
begin
  select status, source_warehouse_id, requested_by
    into v_status, v_source, v_by
    from public.transfer_orders where id = p_transfer_id;
  if v_status is null then raise exception 'transfer % not found', p_transfer_id; end if;
  if v_status <> 'PENDING_APPROVAL' then
    raise exception 'transfer % is % and cannot be approved', p_transfer_id, v_status;
  end if;
  if v_by is not null and v_approver is not null and v_by = v_approver then
    raise exception 'a transfer cannot be approved by the person who requested it';
  end if;

  update public.transfer_orders
     set status = 'APPROVED', approved_by = v_approver, approved_at = now()
   where id = p_transfer_id;
  perform public.log_audit(
    'transfer.approved', 'transfer_order', p_transfer_id::text, v_source, '{}'::jsonb);
  return p_transfer_id;
end;
$$;

create or replace function public.reject_transfer_order(
  p_transfer_id bigint, p_reason text default null
) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_status text;
  v_source bigint;
begin
  select status, source_warehouse_id into v_status, v_source
    from public.transfer_orders where id = p_transfer_id;
  if v_status is null then raise exception 'transfer % not found', p_transfer_id; end if;
  if v_status <> 'PENDING_APPROVAL' then
    raise exception 'transfer % is % and cannot be rejected', p_transfer_id, v_status;
  end if;

  update public.transfer_orders set status = 'REJECTED' where id = p_transfer_id;
  perform public.log_audit(
    'transfer.rejected', 'transfer_order', p_transfer_id::text, v_source,
    jsonb_build_object('reason', p_reason));
  return p_transfer_id;
end;
$$;

-- DRAFT, PENDING_APPROVAL, APPROVED and PICKING can all be cancelled — none
-- of them have moved any stock yet, so there is nothing to reverse.
create or replace function public.cancel_transfer_order(p_transfer_id bigint)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_status text;
  v_source bigint;
begin
  select status, source_warehouse_id into v_status, v_source
    from public.transfer_orders where id = p_transfer_id;
  if v_status is null then raise exception 'transfer % not found', p_transfer_id; end if;
  if v_status not in ('DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'PICKING') then
    raise exception 'transfer % is % and can no longer be cancelled', p_transfer_id, v_status;
  end if;

  update public.transfer_orders set status = 'CANCELLED' where id = p_transfer_id;
  perform public.log_audit(
    'transfer.cancelled', 'transfer_order', p_transfer_id::text, v_source,
    jsonb_build_object('was', v_status));
  return p_transfer_id;
end;
$$;

create or replace function public.start_transfer_picking(p_transfer_id bigint)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_status text;
  v_source bigint;
begin
  select status, source_warehouse_id into v_status, v_source
    from public.transfer_orders where id = p_transfer_id;
  if v_status is null then raise exception 'transfer % not found', p_transfer_id; end if;
  if v_status <> 'APPROVED' then
    raise exception 'transfer % is % and cannot start picking', p_transfer_id, v_status;
  end if;

  update public.transfer_orders set status = 'PICKING' where id = p_transfer_id;
  perform public.log_audit(
    'transfer.picking_started', 'transfer_order', p_transfer_id::text, v_source, '{}'::jsonb);
  return p_transfer_id;
end;
$$;

create or replace function public.record_transfer_pick(
  p_line_id bigint, p_quantity integer
) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_order  bigint;
  v_status text;
begin
  if p_quantity is null or p_quantity < 0 then
    raise exception 'picked quantity must be zero or more';
  end if;

  select l.transfer_order_id, o.status into v_order, v_status
    from public.transfer_order_lines l
    join public.transfer_orders o on o.id = l.transfer_order_id
   where l.id = p_line_id;
  if v_order is null then raise exception 'transfer line % not found', p_line_id; end if;
  if v_status <> 'PICKING' then
    raise exception 'transfer % is % and cannot record a pick', v_order, v_status;
  end if;

  update public.transfer_order_lines
     set picked_quantity = p_quantity where id = p_line_id;
  return v_order;
end;
$$;

-- Stock leaves the source here — the first of the two movements a transfer
-- makes. Uses what was actually picked, not what was requested (spec §10),
-- so a short pick ships short rather than forcing the full amount.
create or replace function public.complete_transfer_picking(p_transfer_id bigint)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_status  text;
  v_source  bigint;
  v_pending integer;
  r         record;
begin
  select status, source_warehouse_id into v_status, v_source
    from public.transfer_orders where id = p_transfer_id;
  if v_status is null then raise exception 'transfer % not found', p_transfer_id; end if;
  if v_status <> 'PICKING' then
    raise exception 'transfer % is % and cannot complete picking', p_transfer_id, v_status;
  end if;

  select count(*) into v_pending from public.transfer_order_lines
   where transfer_order_id = p_transfer_id and picked_quantity is null;
  if v_pending > 0 then
    raise exception 'transfer % still has % unpicked line(s)', p_transfer_id, v_pending;
  end if;

  for r in
    select jan_code, sum(picked_quantity)::int as qty, max(product_name) as pname
      from public.transfer_order_lines
     where transfer_order_id = p_transfer_id and picked_quantity > 0
     group by jan_code
  loop
    perform public.apply_stock_movement(
      v_source, r.jan_code, -r.qty, 'TRANSFER_OUT',
      'transfer_order', p_transfer_id::text, r.pname);
  end loop;

  update public.transfer_orders
     set status = 'IN_TRANSIT', shipped_at = now()
   where id = p_transfer_id;
  perform public.log_audit(
    'transfer.shipped', 'transfer_order', p_transfer_id::text, v_source, '{}'::jsonb);
  return p_transfer_id;
end;
$$;

create or replace function public.start_transfer_receiving(p_transfer_id bigint)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_status      text;
  v_destination bigint;
begin
  select status, destination_warehouse_id into v_status, v_destination
    from public.transfer_orders where id = p_transfer_id;
  if v_status is null then raise exception 'transfer % not found', p_transfer_id; end if;
  if v_status <> 'IN_TRANSIT' then
    raise exception 'transfer % is % and cannot start receiving', p_transfer_id, v_status;
  end if;

  update public.transfer_orders set status = 'RECEIVING' where id = p_transfer_id;
  perform public.log_audit(
    'transfer.receiving_started', 'transfer_order', p_transfer_id::text, v_destination, '{}'::jsonb);
  return p_transfer_id;
end;
$$;

create or replace function public.record_transfer_receipt(
  p_line_id bigint, p_quantity integer
) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_order  bigint;
  v_status text;
begin
  if p_quantity is null or p_quantity < 0 then
    raise exception 'received quantity must be zero or more';
  end if;

  select l.transfer_order_id, o.status into v_order, v_status
    from public.transfer_order_lines l
    join public.transfer_orders o on o.id = l.transfer_order_id
   where l.id = p_line_id;
  if v_order is null then raise exception 'transfer line % not found', p_line_id; end if;
  if v_status <> 'RECEIVING' then
    raise exception 'transfer % is % and cannot record a receipt', v_order, v_status;
  end if;

  update public.transfer_order_lines
     set received_quantity = p_quantity where id = p_line_id;
  return v_order;
end;
$$;

-- Stock lands at the destination here — the second and last movement. A
-- transit loss (received < picked) posts exactly the smaller number and
-- stays on the line as receive_variance; nothing here corrects it upward.
create or replace function public.complete_transfer_receiving(p_transfer_id bigint)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_status      text;
  v_destination bigint;
  v_pending     integer;
  v_summary     jsonb;
  r             record;
begin
  select status, destination_warehouse_id into v_status, v_destination
    from public.transfer_orders where id = p_transfer_id;
  if v_status is null then raise exception 'transfer % not found', p_transfer_id; end if;
  if v_status <> 'RECEIVING' then
    raise exception 'transfer % is % and cannot complete receiving', p_transfer_id, v_status;
  end if;

  select count(*) into v_pending from public.transfer_order_lines
   where transfer_order_id = p_transfer_id and received_quantity is null;
  if v_pending > 0 then
    raise exception 'transfer % still has % unreceived line(s)', p_transfer_id, v_pending;
  end if;

  for r in
    select jan_code, sum(received_quantity)::int as qty, max(product_name) as pname
      from public.transfer_order_lines
     where transfer_order_id = p_transfer_id and received_quantity > 0
     group by jan_code
  loop
    perform public.apply_stock_movement(
      v_destination, r.jan_code, r.qty, 'TRANSFER_IN',
      'transfer_order', p_transfer_id::text, r.pname);
  end loop;

  update public.transfer_orders
     set status = 'COMPLETED', received_at = now()
   where id = p_transfer_id;

  select jsonb_build_object(
           'transfer_order_id', p_transfer_id,
           'lines', count(*),
           'picked_units', coalesce(sum(picked_quantity), 0),
           'received_units', coalesce(sum(received_quantity), 0),
           'loss_lines', count(*) filter (where receive_variance < 0))
    into v_summary
    from public.transfer_order_lines where transfer_order_id = p_transfer_id;

  perform public.log_audit(
    'transfer.received', 'transfer_order', p_transfer_id::text, v_destination, v_summary);
  return v_summary;
end;
$$;

-- ------------------------------------------------------------------- reading

create or replace function public.transfer_order_detail(p_transfer_id bigint)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', o.id,
    'transfer_number', o.transfer_number,
    'source_warehouse_id', o.source_warehouse_id,
    'source_warehouse_name', sw.name,
    'destination_warehouse_id', o.destination_warehouse_id,
    'destination_warehouse_name', dw.name,
    'status', o.status,
    'note', o.note,
    'requested_by', o.requested_by,
    'approved_by', o.approved_by,
    'approved_at', o.approved_at,
    'shipped_at', o.shipped_at,
    'received_at', o.received_at,
    'created_at', o.created_at,
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', l.id,
               'jan_code', l.jan_code,
               'product_name', l.product_name,
               'requested_quantity', l.requested_quantity,
               'picked_quantity', l.picked_quantity,
               'pick_variance', l.pick_variance,
               'received_quantity', l.received_quantity,
               'receive_variance', l.receive_variance) order by l.id)
        from public.transfer_order_lines l
       where l.transfer_order_id = o.id), '[]'::jsonb))
  from public.transfer_orders o
  join public.warehouses sw on sw.id = o.source_warehouse_id
  join public.warehouses dw on dw.id = o.destination_warehouse_id
  where o.id = p_transfer_id;
$$;

-- A warehouse's transfers include both what it is sending and what it is
-- receiving — an operator cares about both directions.
create or replace function public.transfer_order_index(
  p_warehouse_id bigint default null,
  p_status text default null,
  p_limit integer default 50
) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(row_to_json(x)::jsonb order by x.id desc), '[]'::jsonb)
  from (
    select o.id,
           o.transfer_number,
           o.source_warehouse_id,
           sw.name as source_warehouse_name,
           o.destination_warehouse_id,
           dw.name as destination_warehouse_name,
           o.status,
           o.created_at,
           o.shipped_at,
           o.received_at,
           (select count(*) from public.transfer_order_lines l
             where l.transfer_order_id = o.id) as line_count
      from public.transfer_orders o
      join public.warehouses sw on sw.id = o.source_warehouse_id
      join public.warehouses dw on dw.id = o.destination_warehouse_id
     where (p_warehouse_id is null
            or o.source_warehouse_id = p_warehouse_id
            or o.destination_warehouse_id = p_warehouse_id)
       and (p_status is null or o.status = p_status)
     order by o.id desc
     limit greatest(1, least(coalesce(p_limit, 50), 200))
  ) x;
$$;

-- -------------------------------------------------------------------- grants

revoke all on function public.create_transfer_order(bigint, bigint, jsonb, text) from public, anon, authenticated;
revoke all on function public.submit_transfer_order(bigint) from public, anon, authenticated;
revoke all on function public.approve_transfer_order(bigint) from public, anon, authenticated;
revoke all on function public.reject_transfer_order(bigint, text) from public, anon, authenticated;
revoke all on function public.cancel_transfer_order(bigint) from public, anon, authenticated;
revoke all on function public.start_transfer_picking(bigint) from public, anon, authenticated;
revoke all on function public.record_transfer_pick(bigint, integer) from public, anon, authenticated;
revoke all on function public.complete_transfer_picking(bigint) from public, anon, authenticated;
revoke all on function public.start_transfer_receiving(bigint) from public, anon, authenticated;
revoke all on function public.record_transfer_receipt(bigint, integer) from public, anon, authenticated;
revoke all on function public.complete_transfer_receiving(bigint) from public, anon, authenticated;

grant execute on function public.create_transfer_order(bigint, bigint, jsonb, text) to service_role;
grant execute on function public.submit_transfer_order(bigint) to service_role;
grant execute on function public.approve_transfer_order(bigint) to service_role;
grant execute on function public.reject_transfer_order(bigint, text) to service_role;
grant execute on function public.cancel_transfer_order(bigint) to service_role;
grant execute on function public.start_transfer_picking(bigint) to service_role;
grant execute on function public.record_transfer_pick(bigint, integer) to service_role;
grant execute on function public.complete_transfer_picking(bigint) to service_role;
grant execute on function public.start_transfer_receiving(bigint) to service_role;
grant execute on function public.record_transfer_receipt(bigint, integer) to service_role;
grant execute on function public.complete_transfer_receiving(bigint) to service_role;

grant execute on function public.transfer_order_detail(bigint) to anon, authenticated, service_role;
grant execute on function public.transfer_order_index(bigint, text, integer) to anon, authenticated, service_role;
