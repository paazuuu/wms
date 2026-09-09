-- Step 10 (spec §46, §17, §40): stock adjustment and cycle count.
--
-- Both are corrections, so both go through the ledger rather than editing a
-- quantity: an adjustment posts one ADJUST movement, a completed count posts a
-- COUNT movement per line whose variance is non-zero. Nothing here bypasses
-- apply_stock_movement, so before + quantity = after still holds everywhere.
--
-- Works with or without locations: counts and adjustments are per warehouse,
-- which is the balance every warehouse has. Bin-level counting can layer on
-- later for warehouses that opted into locations.

-- ------------------------------------------------------------ adjustments
-- A reason-coded manual correction. The movement carries the arithmetic; this
-- table carries *why*, which is what a stock-take review actually reads.
create table if not exists public.stock_adjustments (
  id bigserial primary key,
  company_id bigint references public.companies (id) on delete set null,
  warehouse_id bigint not null references public.warehouses (id),
  jan_code text not null,
  product_name text,
  quantity_delta integer not null,
  reason text not null check (reason in (
    'DAMAGE',     -- broken / unsellable
    'LOSS',       -- missing, unexplained
    'FOUND',      -- turned up
    'CORRECTION', -- data entry fix
    'RETURN',     -- customer return back into stock
    'OTHER'
  )),
  note text,
  movement_id bigint references public.stock_movements (id) on delete set null,
  actor_user_id uuid,
  created_at timestamptz not null default now()
);

create index if not exists stock_adjustments_warehouse_idx
  on public.stock_adjustments (warehouse_id, created_at desc);

create or replace function public.adjust_stock(
  p_warehouse_id bigint,
  p_jan_code text,
  p_delta integer,
  p_reason text,
  p_note text default null,
  p_product_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_movement bigint;
  v_after    integer;
  v_id       bigint;
begin
  if coalesce(p_delta, 0) = 0 then
    raise exception 'adjust_stock: delta must not be zero';
  end if;
  if p_jan_code is null or p_jan_code = '' then
    raise exception 'adjust_stock: jan_code is required';
  end if;

  v_movement := public.apply_stock_movement(
    p_warehouse_id, p_jan_code, p_delta, 'ADJUST',
    'adjustment', p_reason, p_product_name, null, p_note);

  if v_movement is null then
    -- Nothing moved (e.g. a negative delta against a zero balance).
    raise exception 'adjust_stock: no change applied (balance would not move)';
  end if;

  select quantity_after into v_after
    from public.stock_movements where id = v_movement;

  insert into public.stock_adjustments
    (company_id, warehouse_id, jan_code, product_name, quantity_delta,
     reason, note, movement_id, actor_user_id)
  values
    ((select id from public.companies order by id limit 1),
     p_warehouse_id, p_jan_code, p_product_name, p_delta,
     p_reason, p_note, v_movement, auth.uid())
  returning id into v_id;

  perform public.log_audit(
    'inventory.adjusted', 'stock_adjustment', v_id::text, p_warehouse_id,
    jsonb_build_object('jan_code', p_jan_code, 'delta', p_delta,
                       'reason', p_reason, 'on_hand', v_after));

  return jsonb_build_object(
    'adjustment_id', v_id, 'movement_id', v_movement,
    'jan_code', p_jan_code, 'delta', p_delta, 'on_hand', v_after);
end;
$$;

-- ----------------------------------------------------------- cycle count
create table if not exists public.stock_counts (
  id bigserial primary key,
  company_id bigint references public.companies (id) on delete set null,
  warehouse_id bigint not null references public.warehouses (id),
  status text not null default 'COUNTING'
    check (status in ('COUNTING', 'COMPLETED', 'CANCELLED')),
  -- Blind count: the counter does not see the system quantity while counting,
  -- so the number they write down is their own (spec §40).
  is_blind boolean not null default true,
  note text,
  counted_by uuid,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create index if not exists stock_counts_warehouse_idx
  on public.stock_counts (warehouse_id, created_at desc);

create table if not exists public.stock_count_lines (
  id bigserial primary key,
  stock_count_id bigint not null references public.stock_counts (id) on delete cascade,
  jan_code text not null,
  product_name text,
  -- Frozen when the session opened, so a later receipt cannot silently rewrite
  -- what the counter was measured against.
  system_quantity integer not null default 0,
  counted_quantity integer,
  variance integer generated always as
    (coalesce(counted_quantity, 0) - system_quantity) stored,
  counted_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists stock_count_lines_count_idx
  on public.stock_count_lines (stock_count_id, id);

-- Opens a session and freezes the current balance into its lines.
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
declare
  v_id bigint;
begin
  if p_warehouse_id is null then
    raise exception 'start_stock_count: warehouse is required';
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

-- Records what was physically counted for one line.
create or replace function public.record_count_line(
  p_line_id bigint,
  p_counted integer
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_variance integer;
  v_status   text;
begin
  select c.status into v_status
    from public.stock_count_lines l
    join public.stock_counts c on c.id = l.stock_count_id
   where l.id = p_line_id;
  if v_status is null then
    raise exception 'count line % not found', p_line_id;
  end if;
  if v_status <> 'COUNTING' then
    raise exception 'stock count is % and can no longer be edited', v_status;
  end if;

  update public.stock_count_lines
     set counted_quantity = greatest(coalesce(p_counted, 0), 0),
         counted_at = now()
   where id = p_line_id
  returning variance into v_variance;

  return v_variance;
end;
$$;

-- Applies every non-zero variance as a COUNT movement and closes the session.
-- Uncounted lines are left alone: not counting something is not the same as
-- counting it as zero.
create or replace function public.complete_stock_count(
  p_count_id bigint,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_warehouse bigint;
  v_status    text;
  v_applied   int := 0;
  v_net       int := 0;
  v_uncounted int;
  r           record;
begin
  select warehouse_id, status into v_warehouse, v_status
    from public.stock_counts where id = p_count_id;
  if v_warehouse is null then
    raise exception 'stock count % not found', p_count_id;
  end if;
  if v_status <> 'COUNTING' then
    raise exception 'stock count % is already %', p_count_id, v_status;
  end if;

  select count(*) into v_uncounted
    from public.stock_count_lines
   where stock_count_id = p_count_id and counted_quantity is null;

  for r in
    select id, jan_code, product_name, variance
    from public.stock_count_lines
    where stock_count_id = p_count_id
      and counted_quantity is not null
      and variance <> 0
  loop
    perform public.apply_stock_movement(
      v_warehouse, r.jan_code, r.variance, 'COUNT',
      'stock_count', p_count_id::text, r.product_name, null,
      'cycle count variance');
    v_applied := v_applied + 1;
    v_net := v_net + r.variance;
  end loop;

  update public.stock_counts
     set status = 'COMPLETED',
         note = coalesce(p_note, note),
         completed_at = now()
   where id = p_count_id;

  perform public.log_audit(
    'count.completed', 'stock_count', p_count_id::text, v_warehouse,
    jsonb_build_object('adjusted_lines', v_applied, 'net_change', v_net,
                       'uncounted_lines', v_uncounted));

  return jsonb_build_object(
    'stock_count_id', p_count_id, 'adjusted_lines', v_applied,
    'net_change', v_net, 'uncounted_lines', v_uncounted);
end;
$$;

create or replace function public.cancel_stock_count(p_count_id bigint)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_warehouse bigint;
  v_status    text;
begin
  select warehouse_id, status into v_warehouse, v_status
    from public.stock_counts where id = p_count_id;
  if v_warehouse is null then
    raise exception 'stock count % not found', p_count_id;
  end if;
  if v_status = 'COMPLETED' then
    raise exception 'stock count % is completed and cannot be cancelled', p_count_id;
  end if;

  update public.stock_counts set status = 'CANCELLED' where id = p_count_id;
  perform public.log_audit(
    'count.cancelled', 'stock_count', p_count_id::text, v_warehouse, '{}'::jsonb);
  return p_count_id;
end;
$$;

-- One round trip for the count screen. While a blind count is still open the
-- system quantity and variance are withheld, so the counter cannot anchor on
-- them; both appear once the session is completed.
create or replace function public.stock_count_detail(p_count_id bigint)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', c.id,
    'warehouse_id', c.warehouse_id,
    'warehouse_name', w.name,
    'status', c.status,
    'is_blind', c.is_blind,
    'note', c.note,
    'created_at', c.created_at,
    'completed_at', c.completed_at,
    'hide_system', (c.is_blind and c.status = 'COUNTING'),
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', l.id,
        'jan_code', l.jan_code,
        'product_name', l.product_name,
        'system_quantity',
          case when c.is_blind and c.status = 'COUNTING' then null
               else l.system_quantity end,
        'counted_quantity', l.counted_quantity,
        'variance',
          case when c.is_blind and c.status = 'COUNTING' then null
               else l.variance end,
        'counted_at', l.counted_at
      ) order by l.id)
      from public.stock_count_lines l where l.stock_count_id = c.id
    ), '[]'::jsonb)
  )
  from public.stock_counts c
  left join public.warehouses w on w.id = c.warehouse_id
  where c.id = p_count_id;
$$;

-- ---------------------------------------------------------------------- RLS
alter table public.stock_adjustments enable row level security;
alter table public.stock_counts enable row level security;
alter table public.stock_count_lines enable row level security;

drop policy if exists "read adjustments" on public.stock_adjustments;
create policy "read adjustments" on public.stock_adjustments
  for select to anon, authenticated using (true);

drop policy if exists "read counts" on public.stock_counts;
create policy "read counts" on public.stock_counts
  for select to anon, authenticated using (true);

-- Count lines are readable only through stock_count_detail, which is what
-- enforces the blind-count masking; a direct table read would leak the system
-- quantity the counter is not supposed to see.
drop policy if exists "read count lines" on public.stock_count_lines;

-- ------------------------------------------------------------------ grants
grant execute on function public.stock_count_detail(bigint) to anon, authenticated;

revoke execute on function public.adjust_stock(bigint, text, integer, text, text, text) from public, anon, authenticated;
revoke execute on function public.start_stock_count(bigint, boolean, text) from public, anon, authenticated;
revoke execute on function public.record_count_line(bigint, integer) from public, anon, authenticated;
revoke execute on function public.complete_stock_count(bigint, text) from public, anon, authenticated;
revoke execute on function public.cancel_stock_count(bigint) from public, anon, authenticated;

grant execute on function public.adjust_stock(bigint, text, integer, text, text, text) to service_role;
grant execute on function public.start_stock_count(bigint, boolean, text) to service_role;
grant execute on function public.record_count_line(bigint, integer) to service_role;
grant execute on function public.complete_stock_count(bigint, text) to service_role;
grant execute on function public.cancel_stock_count(bigint) to service_role;
