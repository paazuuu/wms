-- 0069_putaway.sql
-- Phase B, step 4: §14 — put-away, off the ledger, with a suggestion worth taking.
--
-- §14 is mostly a warning about what *not* to build:
--
--   「在庫との二重管理を避けるため、queueの数量を独立した在庫として持たない こと。」
--
-- and `putaway_tasks` only 「将来必要なら」. The existing `putaway_queue` obeyed
-- the letter of that: it computed pending as `stock_levels.on_hand` minus the sum
-- of `bin_stock`, so no second quantity was stored. But a subtraction of two
-- aggregates can only ever answer "how many", and by Phase B the question has
-- become "which parcel". A queue that cannot say "the forty on lot QC-L1 that
-- are still held for inspection" cannot route them anywhere sensible.
--
-- 0066 already made the answer available. A unit received at warehouse scope has
-- `bin_id` null, which *is* "arrived but not yet put away"; put-away is what
-- gives it a bin. So the queue stops subtracting and simply reads the parcels
-- that have no bin yet. That is a stronger form of §14's rule, not a weaker one:
-- the queue no longer holds a quantity at all, derived or otherwise — it is a
-- filter over the stock itself.

-- ---------------------------------------------------------------------------
-- 1. Put-away gives a parcel its bin
-- ---------------------------------------------------------------------------
--
-- `bin_stock` keeps being written exactly as before, so every existing reader
-- still works. What is added is that the parcel in `stock_units` moves too —
-- otherwise the queue, which now reads those units, would never empty.

create or replace function public.move_stock_unit_to_bin_impl(
  p_product_id   bigint,
  p_warehouse_id bigint,
  p_bin_id       bigint,
  p_quantity     integer,
  p_lot_id       bigint default null,
  p_serial_id    bigint default null,
  p_status_id    bigint default null,
  p_available_only boolean default false
) returns integer
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_company bigint;
  v_left    integer := coalesce(p_quantity, 0);
  v_take    integer;
  v_row     record;
begin
  if v_left <= 0 then
    return 0;
  end if;
  select company_id into v_company from public.products where id = p_product_id;
  if v_company is null then
    return 0;
  end if;

  -- Only parcels that have not been put away yet, nearest expiry first so the
  -- stock that has to move soonest goes to a bin first.
  for v_row in
    select su.id, su.quantity, su.lot_id, su.serial_id, su.status_id
      from public.stock_units su
      join public.stock_statuses st on st.id = su.status_id
      left join public.lots l on l.id = su.lot_id
     where su.product_id = p_product_id
       and su.warehouse_id = p_warehouse_id
       and su.bin_id is null
       and su.quantity > 0
       and (p_lot_id is null or su.lot_id = p_lot_id)
       and (p_serial_id is null or su.serial_id = p_serial_id)
       and (p_status_id is null or su.status_id = p_status_id)
       and (not p_available_only or st.counts_available)
     order by st.counts_available desc, l.expiry_date asc nulls last,
              st.sort_order, su.id
  loop
    exit when v_left <= 0;
    v_take := least(v_left, v_row.quantity);

    insert into public.stock_units as su
      (company_id, product_id, warehouse_id, bin_id, lot_id, serial_id,
       status_id, quantity)
    values (v_company, p_product_id, p_warehouse_id, p_bin_id,
            v_row.lot_id, v_row.serial_id, v_row.status_id, v_take)
    on conflict (product_id, warehouse_id, bin_id, lot_id, serial_id, status_id)
      do update set quantity = su.quantity + excluded.quantity, updated_at = now();

    update public.stock_units
       set quantity = quantity - v_take, updated_at = now()
     where id = v_row.id;
    v_left := v_left - v_take;
  end loop;

  delete from public.stock_units
   where product_id = p_product_id and warehouse_id = p_warehouse_id
     and quantity = 0 and serial_id is null;

  return coalesce(p_quantity, 0) - v_left;
end;
$$;

revoke all on function public.move_stock_unit_to_bin_impl(bigint, bigint, bigint, integer, bigint, bigint, bigint, boolean)
  from public, anon, authenticated, service_role;

-- Which bins may hold stock that is not shippable. §13 put a gate in front of
-- shipping; this is the same idea one step earlier — held goods in a pickable
-- bin are held goods a picker will eventually pick.

create or replace function public.bin_accepts_status(
  p_bin_type text,
  p_counts_available boolean
) returns boolean
language sql
immutable
set search_path to ''
as $$
  select case
    when coalesce(p_counts_available, true) then
      upper(coalesce(p_bin_type, '')) in
        ('PICKABLE', 'PICKABLE_STAGING', 'STAGING', 'SHIPPING')
    else
      upper(coalesce(p_bin_type, '')) in
        ('QC_HOLD', 'DAMAGED', 'RETURNS', 'STAGING', 'VIRTUAL')
  end;
$$;

revoke all on function public.bin_accepts_status(text, boolean) from public, anon;
grant execute on function public.bin_accepts_status(text, boolean)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. Confirming a put-away
-- ---------------------------------------------------------------------------

create or replace function public.confirm_putaway(
  p_warehouse_id    bigint,
  p_jan_code        text,
  p_bin_id          bigint,
  p_quantity        integer,
  p_idempotency_key text default null,
  p_note            text default null,
  p_lot_code        text default null,
  p_status_code     text default null
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_company_id bigint;
  v_bin record;
  v_pending integer;
  v_product bigint;
  v_product_name text;
  v_lot bigint;
  v_status bigint;
  v_available boolean;
  v_existing public.putaway_confirmations;
  v_moved integer;
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

  select b.id, b.code, b.warehouse_id, b.is_active, b.bin_type
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

  select id, name into v_product, v_product_name
    from public.products where jan_code = p_jan_code;
  if v_product is null then
    raise exception '% is not a registered product', p_jan_code;
  end if;

  if nullif(btrim(coalesce(p_lot_code, '')), '') is not null then
    select id into v_lot from public.lots
     where product_id = v_product and lot_code = btrim(p_lot_code);
    if v_lot is null then
      raise exception 'lot % not found for %', btrim(p_lot_code), p_jan_code;
    end if;
  end if;
  if nullif(btrim(coalesce(p_status_code, '')), '') is not null then
    select id, counts_available into v_status, v_available
      from public.stock_statuses where code = upper(btrim(p_status_code));
    if v_status is null then
      raise exception 'unknown stock status %', p_status_code;
    end if;
  end if;

  -- What is actually waiting: parcels of this product with no bin yet, narrowed
  -- by whatever the operator named. No stored quantity, derived or otherwise.
  --
  -- With no status named this counts only the shippable parcels, and held stock
  -- has to be named to be put away. That is deliberate: a dock holding thirty
  -- good cartons and ten failed ones has two destinations, not one, and picking
  -- the stricter of the two for all forty would strand the good stock while
  -- picking the looser would strand the bad. Naming it makes the operator say
  -- which pile is in their hands.
  select coalesce(sum(su.quantity), 0)::int
    into v_pending
    from public.stock_units su
    join public.stock_statuses st on st.id = su.status_id
   where su.product_id = v_product
     and su.warehouse_id = p_warehouse_id
     and su.bin_id is null
     and su.quantity > 0
     and (v_lot is null or su.lot_id = v_lot)
     and (case when v_status is null then st.counts_available
               else su.status_id = v_status end);
  if v_status is null then
    v_available := true;
  end if;

  if v_pending < p_quantity then
    raise exception 'only % of % awaits put-away, cannot put away %',
      v_pending, p_jan_code, p_quantity;
  end if;

  -- §13 one step earlier: goods that may not ship must not be put where they
  -- would be picked.
  if not public.bin_accepts_status(v_bin.bin_type, v_available) then
    raise exception
      'bin % is a % bin and cannot hold this stock (it is %)',
      v_bin.code, v_bin.bin_type,
      case when v_available then 'shippable' else 'held or failed' end;
  end if;

  perform public.apply_bin_movement(
    p_bin_id, p_jan_code, p_quantity, 'PUTAWAY',
    'putaway_queue', p_warehouse_id::text, v_product_name, p_note);

  v_moved := public.move_stock_unit_to_bin_impl(
    v_product, p_warehouse_id, p_bin_id, p_quantity, v_lot, null, v_status,
    v_status is null);

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
                       'bin_code', v_bin.code, 'lot', nullif(btrim(coalesce(p_lot_code, '')), ''),
                       'status', nullif(btrim(coalesce(p_status_code, '')), '')));

  return jsonb_build_object(
    'putaway_id', v_id,
    'jan_code', p_jan_code,
    'product_id', v_product,
    'bin_id', p_bin_id,
    'bin_code', v_bin.code,
    'quantity', p_quantity,
    'moved', v_moved,
    'bin_on_hand', (select on_hand from public.bin_stock
                     where bin_id = p_bin_id and jan_code = p_jan_code),
    'pending_after', v_pending - p_quantity,
    'replayed', false);
end;
$$;

revoke all on function public.confirm_putaway(bigint, text, bigint, integer, text, text, text, text)
  from public, anon;
grant execute on function public.confirm_putaway(bigint, text, bigint, integer, text, text, text, text)
  to authenticated, service_role;

-- The six-argument form is dropped: left standing beside one whose extra
-- arguments default, every six-argument call would be ambiguous.
drop function if exists public.confirm_putaway(bigint, text, bigint, integer, text, text);

-- ---------------------------------------------------------------------------
-- 3. Where should it go — §14's ranking, made explicit
-- ---------------------------------------------------------------------------
--
-- The spec orders the criteria: 同一商品が存在するBin → 同一Zone → 空き容量 →
-- 保管条件 → 回転率. Two of those are hard constraints rather than preferences,
-- and the difference matters:
--
--   * 保管条件 is a constraint. A bin that cannot hold this stock is not a worse
--     answer, it is not an answer — so it is filtered out, not down-ranked.
--   * 空き容量 is a constraint when a capacity is recorded and the parcel does
--     not fit, and a preference otherwise. Most bins have no capacity recorded,
--     and a suggestion engine that refuses to suggest anything until someone
--     measures every shelf is a suggestion engine nobody switches on.
--
-- The rest are weighted preferences, in the spec's order, so a bin that already
-- holds this lot outranks one that merely holds the product, which outranks one
-- that is merely in the right zone.

create or replace function public.putaway_suggestions(
  p_warehouse_id bigint,
  p_product_id   bigint,
  p_quantity     integer default 1,
  p_status_code  text default null,
  p_lot_id       bigint default null,
  p_limit        integer default 5
) returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
declare
  v_available boolean := true;
  v_home_zone bigint;
  v_jan       text;
  v_turnover  int;
begin
  if not public.has_permission('inventory.view') then
    raise exception 'not permitted: inventory.view required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  if nullif(btrim(coalesce(p_status_code, '')), '') is not null then
    select counts_available into v_available from public.stock_statuses
     where code = upper(btrim(p_status_code));
    if v_available is null then
      raise exception 'unknown stock status %', p_status_code;
    end if;
  end if;

  select jan_code into v_jan from public.products where id = p_product_id;

  -- The product's home, if someone has set one (§31's per-warehouse settings).
  select coalesce(b.zone_id, l.zone_id) into v_home_zone
    from public.warehouse_products wp
    left join public.locations l on l.id = wp.default_location_id
    left join public.bins b on b.id = l.bin_id
   where wp.warehouse_id = p_warehouse_id and wp.product_id = p_product_id;

  -- 回転率: how much this product has moved lately. A fast mover wants to be
  -- near where picking happens; a slow one is better off out of the way.
  select count(*)::int into v_turnover
    from public.stock_movements m
   where m.product_id = p_product_id
     and m.warehouse_id = p_warehouse_id
     and m.created_at > now() - interval '30 days'
     and m.movement_type in ('SHIP', 'PICK', 'TRANSFER_OUT');

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'bin_id', s.bin_id,
      'bin_code', s.bin_code,
      'bin_type', s.bin_type,
      'zone_id', s.zone_id,
      'on_hand', s.bin_on_hand,
      'same_lot', s.same_lot,
      'capacity', s.capacity,
      'free_capacity', s.free_capacity,
      'score', s.score,
      -- So the screen can say why, which is the difference between a
      -- suggestion an operator follows and one they tap past.
      'reason', s.reason) order by s.score desc, s.bin_code)
    from (
      select b.id as bin_id, b.code as bin_code, b.bin_type, b.zone_id,
             coalesce(bs.on_hand, 0) as bin_on_hand,
             (p_lot_id is not null and exists (
                select 1 from public.stock_units su
                 where su.bin_id = b.id and su.lot_id = p_lot_id
                   and su.quantity > 0)) as same_lot,
             cap.capacity,
             case when cap.capacity is null then null
                  else cap.capacity - coalesce(tot.total, 0) end as free_capacity,
             (
               case when coalesce(bs.on_hand, 0) > 0 then 100 else 0 end
             + case when p_lot_id is not null and exists (
                 select 1 from public.stock_units su
                  where su.bin_id = b.id and su.lot_id = p_lot_id and su.quantity > 0)
                 then 40 else 0 end
             + case when v_home_zone is not null and b.zone_id = v_home_zone
                 then 50 else 0 end
             + case when cap.capacity is null then 0
                    when cap.capacity - coalesce(tot.total, 0) >= greatest(coalesce(p_quantity, 1), 1) * 2
                      then 20
                    else 5 end
             + case when v_turnover >= 10 and b.bin_type = 'PICKABLE' then 15
                    when v_turnover < 10 and b.bin_type in ('STAGING', 'PICKABLE_STAGING') then 5
                    else 0 end
             ) as score,
             concat_ws(' / ',
               case when coalesce(bs.on_hand, 0) > 0 then '同一商品あり' end,
               case when p_lot_id is not null and exists (
                 select 1 from public.stock_units su
                  where su.bin_id = b.id and su.lot_id = p_lot_id and su.quantity > 0)
                 then '同一ロット' end,
               case when v_home_zone is not null and b.zone_id = v_home_zone
                 then '定位置ゾーン' end,
               case when cap.capacity is not null
                 then '空き' || (cap.capacity - coalesce(tot.total, 0))::text end,
               case when v_turnover >= 10 and b.bin_type = 'PICKABLE' then '回転が速い' end
             ) as reason
        from public.bins b
        left join public.bin_stock bs on bs.bin_id = b.id and bs.jan_code = v_jan
        left join lateral (
          select nullif(b.attributes ->> 'capacity', '')::int as capacity) cap on true
        left join lateral (
          select sum(x.on_hand)::int as total from public.bin_stock x where x.bin_id = b.id) tot on true
       where b.warehouse_id = p_warehouse_id
         and b.is_active
         -- 保管条件: a hard constraint, not a preference.
         and public.bin_accepts_status(b.bin_type, v_available)
         -- 空き容量: a constraint only where a capacity is actually recorded.
         and (cap.capacity is null
              or cap.capacity - coalesce(tot.total, 0) >= greatest(coalesce(p_quantity, 1), 1))
       order by score desc, b.code
       limit greatest(coalesce(p_limit, 5), 1)
    ) s), '[]'::jsonb);
end;
$$;

revoke all on function public.putaway_suggestions(bigint, bigint, integer, text, bigint, integer)
  from public, anon;
grant execute on function public.putaway_suggestions(bigint, bigint, integer, text, bigint, integer)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. The queue is a filter over the stock, not a copy of it
-- ---------------------------------------------------------------------------

create or replace function public.putaway_queue(p_warehouse_id bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
begin
  if not public.has_permission('inventory.view') then
    raise exception 'not permitted: inventory.view required';
  end if;
  if p_warehouse_id is null then
    raise exception 'warehouse is required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if not public.warehouse_uses_locations(p_warehouse_id) then
    return '[]'::jsonb;
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'product_id', q.product_id,
      'jan_code', q.jan_code,
      'product_name', q.product_name,
      'lot_id', q.lot_id,
      'lot_code', q.lot_code,
      'expiry', q.expiry_date,
      'serial_id', q.serial_id,
      'serial_number', q.serial_number,
      'status_code', q.status_code,
      'status_name', q.status_name,
      'counts_available', q.counts_available,
      'pending_quantity', q.pending,
      'warehouse_on_hand', public.stock_on_hand(q.product_id, p_warehouse_id),
      'suggestions', public.putaway_suggestions(
        p_warehouse_id, q.product_id, q.pending, q.status_code, q.lot_id, 3))
      -- Held stock first: it is the stock that should not be sitting on the
      -- dock, and the stock a picker must not stumble into.
      order by q.counts_available, q.expiry_date asc nulls last, q.jan_code)
    from (
      select su.product_id, p.jan_code, p.name as product_name,
             su.lot_id, l.lot_code, l.expiry_date,
             su.serial_id, sn.serial_number,
             st.code as status_code, st.name as status_name,
             st.counts_available,
             sum(su.quantity)::int as pending
        from public.stock_units su
        join public.products p on p.id = su.product_id
        join public.stock_statuses st on st.id = su.status_id
        left join public.lots l on l.id = su.lot_id
        left join public.serial_numbers sn on sn.id = su.serial_id
       where su.warehouse_id = p_warehouse_id
         and su.bin_id is null
         and su.quantity > 0
       group by su.product_id, p.jan_code, p.name, su.lot_id, l.lot_code,
                l.expiry_date, su.serial_id, sn.serial_number,
                st.code, st.name, st.counts_available
    ) q), '[]'::jsonb);
end;
$$;

revoke all on function public.putaway_queue(bigint) from public, anon;
grant execute on function public.putaway_queue(bigint) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. Bringing the two projections into step
-- ---------------------------------------------------------------------------
--
-- Any stock already sitting in a bin before this migration is recorded in
-- `bin_stock` but has `bin_id` null on its unit, which the new queue would read
-- as "still waiting". This walks each bin_stock row and moves the matching
-- parcels across. It is safe to re-run: it only ever moves units that have no
-- bin yet, and only up to what `bin_stock` already says is in the bin.

create or replace function public.backfill_stock_unit_bins(p_warehouse_id bigint default null)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_rows int := 0;
  v_moved int := 0;
  v_take int;
  r record;
begin
  for r in
    select bs.bin_id, bs.jan_code, bs.on_hand, b.warehouse_id, p.id as product_id
      from public.bin_stock bs
      join public.bins b on b.id = bs.bin_id
      join public.products p on p.jan_code = bs.jan_code
     where bs.on_hand > 0
       and (p_warehouse_id is null or b.warehouse_id = p_warehouse_id)
  loop
    v_take := public.move_stock_unit_to_bin_impl(
      r.product_id, r.warehouse_id, r.bin_id,
      least(r.on_hand, coalesce((
        select sum(su.quantity)::int from public.stock_units su
         where su.product_id = r.product_id and su.warehouse_id = r.warehouse_id
           and su.bin_id is null and su.quantity > 0), 0)));
    v_rows := v_rows + 1;
    v_moved := v_moved + v_take;
  end loop;
  return jsonb_build_object('bin_stock_rows', v_rows, 'units_moved', v_moved);
end;
$$;

revoke all on function public.backfill_stock_unit_bins(bigint) from public, anon, authenticated;
grant execute on function public.backfill_stock_unit_bins(bigint) to service_role;

select public.backfill_stock_unit_bins();

-- ---------------------------------------------------------------------------
-- 6. Housekeeping
-- ---------------------------------------------------------------------------

do $tighten$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prorettype = 'trigger'::regtype
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
  end loop;
end $tighten$;
