-- Step 6 (spec §7, §8, §12, §49): locations/bins as an OPT-IN capability.
--
-- The operator does not use shelf locations today, and may later. So bins are
-- off by default and nothing is auto-created:
--
--   * warehouses.uses_locations (default FALSE) is the switch. While it is off
--     the system behaves exactly as it does now — stock is a per-warehouse
--     balance and no bin is ever required.
--   * The four bins migration 0010 seeded (STAGE-01/QC-01/SHIP-01/A-01-01) are
--     removed for warehouses that have not opted in. Safe: nothing references
--     them. Spec §7 explicitly says not to force the hierarchy up front, and
--     §49 says auto-creation must be a toggle, not a default.
--   * bin_stock and put-away exist and are correct, but only ever engage for a
--     warehouse that has switched locations on.
--
-- Bin moves do not change the warehouse total, so stock_movements gains
-- balance_scope to say which balance a row's before/after refer to. Existing
-- rows are WAREHOUSE, so the ledger's meaning is unchanged.

alter table public.warehouses
  add column if not exists uses_locations boolean not null default false;

comment on column public.warehouses.uses_locations is
  'Opt-in: when false the warehouse keeps a single per-warehouse balance and '
  'bins/put-away are inactive. Turning it on enables bin_stock and put-away.';

-- Undo 0010''s auto-seeded bins for warehouses that have not opted in. Guarded
-- on the ledger so a bin that was ever used is never silently dropped.
delete from public.bins b
 where b.warehouse_id in (
         select id from public.warehouses where not uses_locations)
   and not exists (
         select 1 from public.stock_movements m where m.bin_id = b.id);

alter table public.stock_movements
  add column if not exists balance_scope text not null default 'WAREHOUSE';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.stock_movements'::regclass
      and conname = 'stock_movements_balance_scope_check'
  ) then
    alter table public.stock_movements
      add constraint stock_movements_balance_scope_check
      check (balance_scope in ('WAREHOUSE', 'BIN'));
  end if;
end $$;

-- --------------------------------------------------------- bin-level balance
create table if not exists public.bin_stock (
  bin_id bigint not null references public.bins (id) on delete cascade,
  jan_code text not null,
  product_name text,
  on_hand integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (bin_id, jan_code)
);

create index if not exists bin_stock_jan_idx on public.bin_stock (jan_code);

alter table public.bin_stock enable row level security;
drop policy if exists "read bin stock" on public.bin_stock;
create policy "read bin stock" on public.bin_stock
  for select to anon, authenticated using (true);

-- ------------------------------------------------------ does it use bins?
create or replace function public.warehouse_uses_locations(p_warehouse_id bigint)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select uses_locations from public.warehouses where id = p_warehouse_id),
    false);
$$;

-- The bin a warehouse receives into, if it has one. Null when locations are off
-- or no STAGING bin exists — callers treat that as "no bin tracking".
create or replace function public.default_staging_bin(p_warehouse_id bigint)
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select b.id
  from public.bins b
  join public.warehouses w on w.id = b.warehouse_id
  where b.warehouse_id = p_warehouse_id
    and w.uses_locations
    and b.bin_type = 'STAGING'
    and b.is_active
  order by b.id
  limit 1;
$$;

-- ------------------------------------------------- the one place bins move
-- Bin analogue of apply_stock_movement: locks the bin balance, computes the
-- effective delta, appends a BIN-scoped movement. The warehouse total is NOT
-- touched — a put-away redistributes stock, it does not create or destroy it.
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
  if p_quantity = 0 or p_bin_id is null
     or p_jan_code is null or p_jan_code = '' then
    return null;
  end if;

  select warehouse_id into v_warehouse from public.bins where id = p_bin_id;
  if v_warehouse is null then
    raise exception 'bin % not found', p_bin_id;
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

-- ------------------------------------------------------------- put-away
-- Move stock from one bin to another inside the same warehouse (spec §12).
-- Refuses when the warehouse has not opted into locations, when the bins are in
-- different warehouses, or when the source does not hold enough.
create or replace function public.putaway(
  p_from_bin bigint,
  p_to_bin bigint,
  p_jan_code text,
  p_quantity integer,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_from_wh integer;
  v_to_wh   integer;
  v_have    integer;
begin
  if coalesce(p_quantity, 0) <= 0 then
    raise exception 'putaway: quantity must be positive';
  end if;
  if p_from_bin = p_to_bin then
    raise exception 'putaway: source and destination are the same bin';
  end if;

  select warehouse_id into v_from_wh from public.bins where id = p_from_bin;
  select warehouse_id into v_to_wh from public.bins where id = p_to_bin;
  if v_from_wh is null or v_to_wh is null then
    raise exception 'putaway: bin not found';
  end if;
  if v_from_wh <> v_to_wh then
    raise exception 'putaway: bins belong to different warehouses';
  end if;
  if not public.warehouse_uses_locations(v_from_wh) then
    raise exception 'putaway: warehouse % does not use locations', v_from_wh;
  end if;

  select coalesce(on_hand, 0) into v_have
    from public.bin_stock
   where bin_id = p_from_bin and jan_code = p_jan_code;
  if coalesce(v_have, 0) < p_quantity then
    raise exception 'putaway: bin holds % of %, cannot move %',
      coalesce(v_have, 0), p_jan_code, p_quantity;
  end if;

  perform public.apply_bin_movement(
    p_from_bin, p_jan_code, -p_quantity, 'PUTAWAY',
    'putaway', p_to_bin::text, null, p_note);
  perform public.apply_bin_movement(
    p_to_bin, p_jan_code, p_quantity, 'PUTAWAY',
    'putaway', p_from_bin::text, null, p_note);

  perform public.log_audit(
    'putaway.confirmed', 'bin', p_to_bin::text, v_from_wh,
    jsonb_build_object('from_bin', p_from_bin, 'to_bin', p_to_bin,
                       'jan_code', p_jan_code, 'quantity', p_quantity));

  return jsonb_build_object(
    'from_bin', p_from_bin, 'to_bin', p_to_bin,
    'jan_code', p_jan_code, 'quantity', p_quantity,
    'from_on_hand', (select on_hand from public.bin_stock
                      where bin_id = p_from_bin and jan_code = p_jan_code),
    'to_on_hand', (select on_hand from public.bin_stock
                    where bin_id = p_to_bin and jan_code = p_jan_code)
  );
end;
$$;

-- ------------------------------------------------------------- reading
-- What each bin of a warehouse holds. Empty for warehouses not using locations.
create or replace function public.bin_stock_overview(p_warehouse_id bigint)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'bin_id', b.id,
    'bin_code', b.code,
    'bin_type', b.bin_type,
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
        'jan_code', s.jan_code,
        'product_name', s.product_name,
        'on_hand', s.on_hand) order by s.on_hand desc)
      from public.bin_stock s
      where s.bin_id = b.id and s.on_hand > 0
    ), '[]'::jsonb)
  ) order by b.code), '[]'::jsonb)
  from public.bins b
  join public.warehouses w on w.id = b.warehouse_id
  where b.warehouse_id = p_warehouse_id and w.uses_locations;
$$;

-- stock_ledger now says which balance each row describes, and defaults to the
-- warehouse ledger so existing callers see exactly what they saw before.
-- The 3-argument version must go: keeping both would make the client's
-- 3-named-argument call ambiguous ("function is not unique"), since the new
-- fourth argument is defaulted.
drop function if exists public.stock_ledger(text, bigint, integer);

create or replace function public.stock_ledger(
  p_jan_code text default null,
  p_warehouse_id bigint default null,
  p_limit integer default 100,
  p_scope text default 'WAREHOUSE'
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
           m.bin_id, b.code as bin_code, m.jan_code, m.product_name,
           m.movement_type, m.balance_scope,
           m.quantity, m.quantity_before, m.quantity_after,
           m.reference_type, m.reference_id, m.actor_user_id, m.note
    from public.stock_movements m
    left join public.warehouses w on w.id = m.warehouse_id
    left join public.bins b on b.id = m.bin_id
    where (p_jan_code is null or m.jan_code = p_jan_code)
      and (p_warehouse_id is null or m.warehouse_id = p_warehouse_id)
      and (p_scope is null or p_scope = 'ALL' or m.balance_scope = p_scope)
    order by m.created_at desc, m.id desc
    limit greatest(coalesce(p_limit, 100), 1)
  ) t;
$$;

-- ------------------------------------------------------------------ grants
grant execute on function public.warehouse_uses_locations(bigint) to anon, authenticated;
grant execute on function public.default_staging_bin(bigint) to anon, authenticated;
grant execute on function public.bin_stock_overview(bigint) to anon, authenticated;
grant execute on function public.stock_ledger(text, bigint, integer, text) to anon, authenticated;

revoke execute on function public.apply_bin_movement(bigint, text, integer, text, text, text, text, text) from public, anon, authenticated;
revoke execute on function public.putaway(bigint, bigint, text, integer, text) from public, anon, authenticated;

grant execute on function public.apply_bin_movement(bigint, text, integer, text, text, text, text, text) to service_role;
grant execute on function public.putaway(bigint, bigint, text, integer, text) to service_role;
