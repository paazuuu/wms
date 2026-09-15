-- 0044 — Enforce per-user warehouse scope, batch 1: the stock-moving core
-- + the warehouse picker's own feed (UI spec §37)
--
-- Auditing §37 found that `user_warehouses`/`can_access_warehouse()` (0012)
-- and the admin UI to assign them (0029) have existed since real sign-in
-- went live, but nothing ever actually calls can_access_warehouse() from
-- anywhere — not one RLS policy, not one RPC, not one edge function. A user
-- restricted to specific warehouses is not restricted at all today; every
-- warehouse-scoped RPC and edge function accepts whatever warehouse_id the
-- caller sends. RLS cannot fix this on its own even where it does apply:
-- every one of these tables is written and read through SECURITY DEFINER
-- functions, which bypass RLS by running as the function owner — the exact
-- same shape of gap as the audit_log RPCs fixed in 0043.
--
-- This is bigger than "narrow the warehouse picker's list" (the original
-- ask): most of these RPCs treat p_warehouse_id IS NULL as "every
-- warehouse," a deliberate feature for the admin/all-warehouses view, so a
-- bare `if not can_access_warehouse(p_warehouse_id)` guard would do nothing
-- for a restricted user who simply omits the filter. Fixing it for real
-- means each read RPC's query itself has to fall back to the caller's
-- scoped set rather than to everything, and each write RPC must check the
-- one warehouse it was actually given.
--
-- Splitting this into batches rather than one migration: this one covers
-- the two functions every stock-quantity change in the entire app funnels
-- through (apply_stock_movement for warehouse-level stock, apply_bin_movement
-- for bin-level stock) plus the direct-entry-point writes that don't route
-- through either (confirm_putaway, start_stock_count), plus
-- warehouse_overview() itself, which is what actually feeds the warehouse
-- picker. Every other transfer/pick/ship/receive/work-order RPC that moves
-- stock calls apply_stock_movement or apply_bin_movement internally
-- (SECURITY DEFINER doesn't reset auth.uid() across nested calls, so the
-- original caller's identity is still what's checked at the bottom), so
-- this one change reaches all of them at once. The remaining read-side
-- list/index RPCs and the edge functions' own warehouse_id filters are a
-- separate, following batch — flagged, not silently left out.

-- The caller's accessible warehouse ids, or null to mean "every warehouse"
-- (system_admin/company_admin, or a trusted server-side caller with no user
-- context — same null-auth.uid() convention as has_permission()). A
-- non-null array (possibly empty, meaning "none assigned yet") is the
-- caller's actual restriction; read RPCs fall back to this set instead of
-- to everything when no explicit warehouse_id filter was given.
create or replace function public.accessible_warehouse_ids()
returns bigint[]
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when auth.uid() is null then null
    when exists (
      select 1 from public.user_roles ur join public.roles r on r.id = ur.role_id
      where ur.user_id = auth.uid() and r.code in ('system_admin', 'company_admin')
    ) then null
    else coalesce((
      select array_agg(uw.warehouse_id) from public.user_warehouses uw
      where uw.user_id = auth.uid()
    ), array[]::bigint[])
  end;
$$;

revoke all on function public.accessible_warehouse_ids() from public, anon;
grant execute on function public.accessible_warehouse_ids() to authenticated, service_role;

-- warehouse_overview(): filter the list (and its totals) to the caller's
-- scope instead of every warehouse in the company. This is the RPC the
-- warehouse picker itself reads, so this one change is what actually
-- narrows the picker for a scoped user — doing it here, not client-side,
-- is what makes it a real restriction rather than a cosmetic one.
create or replace function public.warehouse_overview()
returns jsonb
language sql
security definer
set search_path = 'public'
as $$
  with scope as (select accessible_warehouse_ids() as ids),
  per as (
    select
      w.id, w.code, w.name, w.status, w.is_default, w.timezone,
      (select count(*) from stock_levels s
        where s.warehouse_id = w.id and s.on_hand > 0)::bigint as sku_count,
      (select coalesce(sum(s.on_hand),0) from stock_levels s
        where s.warehouse_id = w.id)::bigint as on_hand,
      (select count(*) from delivery_plans p
        where p.warehouse_id = w.id
          and p.status in ('open','reconciling','partial'))::bigint as inbound_open,
      (select count(*) from shipment_plans sp
        where sp.warehouse_id = w.id and sp.status = 'open')::bigint as outbound_open
    from warehouses w, scope
    where scope.ids is null or w.id = any(scope.ids)
    order by w.is_default desc, w.name
  )
  select jsonb_build_object(
    'warehouses', coalesce(jsonb_agg(jsonb_build_object(
      'id', id, 'code', code, 'name', name, 'status', status,
      'is_default', is_default, 'timezone', timezone,
      'sku_count', sku_count, 'on_hand', on_hand,
      'inbound_open', inbound_open, 'outbound_open', outbound_open
    )), '[]'::jsonb),
    'totals', jsonb_build_object(
      'warehouse_count', count(*),
      'sku_count', coalesce(sum(sku_count),0),
      'on_hand', coalesce(sum(on_hand),0),
      'inbound_open', coalesce(sum(inbound_open),0),
      'outbound_open', coalesce(sum(outbound_open),0)
    )
  )
  from per;
$$;

-- apply_stock_movement(): the single choke point for every warehouse-level
-- stock quantity change in the app (adjustments, counts, transfers,
-- shipments, receiving, work orders). One check here reaches all of them.
create or replace function public.apply_stock_movement(
  p_warehouse_id bigint,
  p_jan_code text,
  p_quantity integer,
  p_movement_type text,
  p_reference_type text default null,
  p_reference_id text default null,
  p_product_name text default null,
  p_bin_id bigint default null,
  p_note text default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_before    integer;
  v_after     integer;
  v_effective integer;
  v_id        bigint;
begin
  if p_quantity = 0 or p_jan_code is null or p_jan_code = '' then
    return null;
  end if;
  if p_warehouse_id is null then
    raise exception 'apply_stock_movement: warehouse is required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  insert into public.stock_levels (warehouse_id, jan_code, product_name, on_hand)
  values (p_warehouse_id, p_jan_code, coalesce(p_product_name, ''), 0)
  on conflict (warehouse_id, jan_code) do nothing;

  select on_hand into v_before
    from public.stock_levels
   where warehouse_id = p_warehouse_id and jan_code = p_jan_code
     for update;

  v_after := greatest(coalesce(v_before, 0) + p_quantity, 0);
  v_effective := v_after - coalesce(v_before, 0);

  if v_effective = 0 then
    return null;
  end if;

  update public.stock_levels
     set on_hand = v_after,
         product_name = case
           when coalesce(product_name, '') = '' then coalesce(p_product_name, '')
           else product_name
         end,
         updated_at = now()
   where warehouse_id = p_warehouse_id and jan_code = p_jan_code;

  insert into public.stock_movements (
    company_id, warehouse_id, bin_id, jan_code, product_name,
    movement_type, quantity, quantity_before, quantity_after,
    reference_type, reference_id, actor_user_id, note
  )
  values (
    (select id from public.companies order by id limit 1),
    p_warehouse_id, p_bin_id, p_jan_code, p_product_name,
    p_movement_type, v_effective, coalesce(v_before, 0), v_after,
    p_reference_type, p_reference_id, auth.uid(), p_note
  )
  returning id into v_id;

  return v_id;
end;
$$;

-- apply_bin_movement(): the equivalent choke point for bin-level stock
-- (put-away, and any bin-scoped picking/receiving). The warehouse is
-- derived from the bin itself, not a caller-supplied parameter, so this
-- can't be bypassed by lying about which warehouse a bin is in.
create or replace function public.apply_bin_movement(
  p_bin_id bigint,
  p_jan_code text,
  p_quantity integer,
  p_movement_type text,
  p_reference_type text default null,
  p_reference_id text default null,
  p_product_name text default null,
  p_note text default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_warehouse integer;
  v_before    integer;
  v_after     integer;
  v_effective integer;
  v_id        bigint;
begin
  if p_quantity = 0 or p_bin_id is null or p_jan_code is null or p_jan_code = '' then
    return null;
  end if;

  select warehouse_id into v_warehouse from public.bins where id = p_bin_id;
  if v_warehouse is null then
    raise exception 'bin % not found', p_bin_id;
  end if;
  if not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  insert into public.bin_stock (bin_id, jan_code, product_name, on_hand)
  values (p_bin_id, p_jan_code, coalesce(p_product_name, ''), 0)
  on conflict (bin_id, jan_code) do nothing;

  select on_hand into v_before
    from public.bin_stock
   where bin_id = p_bin_id and jan_code = p_jan_code
     for update;

  v_after := greatest(coalesce(v_before, 0) + p_quantity, 0);
  v_effective := v_after - coalesce(v_before, 0);
  if v_effective = 0 then
    return null;
  end if;

  update public.bin_stock
     set on_hand = v_after,
         product_name = case
           when coalesce(product_name, '') = '' then coalesce(p_product_name, '')
           else product_name
         end,
         updated_at = now()
   where bin_id = p_bin_id and jan_code = p_jan_code;

  insert into public.stock_movements (
    company_id, warehouse_id, bin_id, jan_code, product_name,
    movement_type, quantity, quantity_before, quantity_after,
    balance_scope, reference_type, reference_id, actor_user_id, note
  )
  values (
    (select id from public.companies order by id limit 1),
    v_warehouse, p_bin_id, p_jan_code, p_product_name,
    p_movement_type, v_effective, coalesce(v_before, 0), v_after,
    'BIN', p_reference_type, p_reference_id, auth.uid(), p_note
  )
  returning id into v_id;

  return v_id;
end;
$$;

-- confirm_putaway(): doesn't route through apply_stock_movement (put-away
-- moves stock between "unbinned" and "binned" within the same warehouse, so
-- on_hand never changes) and calls apply_bin_movement with a bin already
-- validated against p_warehouse_id, so the apply_bin_movement check above
-- would catch a mismatched bin — but a caller could still name a
-- p_warehouse_id/bin pair that's consistent with each other yet outside
-- their own scope entirely. Check explicitly, right after the existing
-- putaway.confirm permission check.
create or replace function public.confirm_putaway(
  p_warehouse_id bigint,
  p_jan_code text,
  p_bin_id bigint,
  p_quantity integer,
  p_idempotency_key text default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id bigint;
  v_bin record;
  v_on_hand integer;
  v_binned integer;
  v_pending integer;
  v_product_name text;
  v_existing public.putaway_confirmations;
  v_id bigint;
begin
  if not public.has_permission('putaway.confirm') then
    raise exception 'not permitted: putaway.confirm required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if coalesce(p_quantity, 0) <= 0 then
    raise exception 'quantity must be positive';
  end if;
  if p_jan_code is null or p_jan_code = '' then
    raise exception 'jan_code is required';
  end if;

  -- Idempotent replay: same key, same answer, nothing posted twice.
  if p_idempotency_key is not null and p_idempotency_key <> '' then
    select * into v_existing
      from public.putaway_confirmations
     where idempotency_key = p_idempotency_key;
    if v_existing.id is not null then
      return jsonb_build_object(
        'putaway_id', v_existing.id,
        'jan_code', v_existing.jan_code,
        'bin_id', v_existing.bin_id,
        'quantity', v_existing.quantity,
        'replayed', true);
    end if;
  end if;

  if not public.warehouse_uses_locations(p_warehouse_id) then
    raise exception 'warehouse % does not use locations', p_warehouse_id;
  end if;

  select b.id, b.code, b.warehouse_id, b.is_active
    into v_bin
    from public.bins b where b.id = p_bin_id;
  if v_bin.id is null then
    raise exception 'bin % not found', p_bin_id;
  end if;
  if v_bin.warehouse_id <> p_warehouse_id then
    raise exception 'bin % belongs to another warehouse', p_bin_id;
  end if;
  if not v_bin.is_active then
    raise exception 'bin % is inactive', v_bin.code;
  end if;

  select s.on_hand, s.product_name into v_on_hand, v_product_name
    from public.stock_levels s
   where s.warehouse_id = p_warehouse_id and s.jan_code = p_jan_code;
  if v_on_hand is null then
    raise exception '% is not in stock in this warehouse', p_jan_code;
  end if;

  select coalesce(sum(bs.on_hand), 0)::int into v_binned
    from public.bin_stock bs
    join public.bins bn on bn.id = bs.bin_id
   where bn.warehouse_id = p_warehouse_id and bs.jan_code = p_jan_code;

  v_pending := v_on_hand - v_binned;
  if p_quantity > v_pending then
    raise exception 'only % of % awaits put-away, cannot put away %',
      v_pending, p_jan_code, p_quantity;
  end if;

  perform public.apply_bin_movement(
    p_bin_id, p_jan_code, p_quantity, 'PUTAWAY',
    'putaway_queue', p_warehouse_id::text, v_product_name, p_note);

  select id into v_company_id from public.companies order by id limit 1;

  insert into public.putaway_confirmations (
    company_id, warehouse_id, bin_id, jan_code, quantity, idempotency_key, confirmed_by)
  values (
    v_company_id, p_warehouse_id, p_bin_id, p_jan_code, p_quantity,
    nullif(p_idempotency_key, ''), auth.uid())
  returning id into v_id;

  perform public.log_audit(
    'putaway.confirmed', 'bin', p_bin_id::text, p_warehouse_id,
    jsonb_build_object('jan_code', p_jan_code, 'quantity', p_quantity,
                       'bin_code', v_bin.code));

  return jsonb_build_object(
    'putaway_id', v_id,
    'jan_code', p_jan_code,
    'bin_id', p_bin_id,
    'bin_code', v_bin.code,
    'quantity', p_quantity,
    'bin_on_hand', (select on_hand from public.bin_stock
                     where bin_id = p_bin_id and jan_code = p_jan_code),
    'pending_after', v_pending - p_quantity,
    'replayed', false);
end;
$$;

-- start_stock_count(): creates a new count session scoped to a warehouse;
-- doesn't route through apply_stock_movement (a count only posts
-- adjustments on completion, via adjust_stock -> apply_stock_movement,
-- already covered above), so this entry point needs its own check.
create or replace function public.start_stock_count(
  p_warehouse_id bigint,
  p_blind boolean default true,
  p_note text default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare v_id bigint;
begin
  if p_warehouse_id is null then
    raise exception 'start_stock_count: warehouse is required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  insert into public.stock_counts
    (company_id, warehouse_id, is_blind, note, counted_by)
  values
    ((select id from public.companies order by id limit 1),
     p_warehouse_id, coalesce(p_blind, true), p_note, auth.uid())
  returning id into v_id;

  insert into public.stock_count_lines
    (stock_count_id, jan_code, product_name, system_quantity)
  select v_id, s.jan_code, s.product_name, coalesce(s.on_hand, 0)
  from public.stock_levels s
  where s.warehouse_id = p_warehouse_id;

  perform public.log_audit(
    'count.started', 'stock_count', v_id::text, p_warehouse_id,
    jsonb_build_object('blind', coalesce(p_blind, true)));

  return v_id;
end;
$$;
