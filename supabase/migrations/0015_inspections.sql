-- Step 5 (spec §46, §10, §11, §40): inbound inspection (検品).
--
-- An inspection hangs off a receipt (delivery_reconciliation) and records what
-- QC actually found. Two rules from the spec drive the shape:
--
--   * "勝手に在庫を100にしない" (§10) — the discrepancy is *stored*, never
--     silently corrected. expected vs actual is a generated column so it can
--     never drift from its inputs.
--   * A line can be partly good: 50 received, 47 pass, 3 fail (§38 Scenario B),
--     so pass/fail are separate quantities rather than one verdict.
--
-- Stock is deliberately NOT moved here. Receiving already recorded the units via
-- the ledger; segregating failed units into a QC_HOLD bin needs bin-level
-- balances, which arrive with put-away (0016). Until then the QC result is
-- recorded and audited, and the failed quantity is the input put-away will use.

create table if not exists public.inspections (
  id bigserial primary key,
  company_id bigint references public.companies (id) on delete set null,
  warehouse_id bigint not null references public.warehouses (id),
  reconciliation_id bigint references public.delivery_reconciliations (id) on delete cascade,
  delivery_plan_id bigint references public.delivery_plans (id) on delete set null,
  status text not null default 'PENDING'
    check (status in ('PENDING', 'PASS', 'FAIL', 'PARTIAL', 'HOLD')),
  inspector_user_id uuid,
  note text,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

-- One inspection per receipt keeps start_inspection idempotent.
create unique index if not exists inspections_one_per_reconciliation
  on public.inspections (reconciliation_id)
  where reconciliation_id is not null;

create index if not exists inspections_status_idx
  on public.inspections (status, created_at desc);
create index if not exists inspections_warehouse_idx
  on public.inspections (warehouse_id, created_at desc);

create table if not exists public.inspection_items (
  id bigserial primary key,
  inspection_id bigint not null references public.inspections (id) on delete cascade,
  reconciliation_line_id bigint references public.reconciliation_lines (id) on delete set null,
  jan_code text not null,
  product_name text,
  expected_quantity integer not null default 0,
  actual_quantity integer not null default 0,
  -- A line can be partly good; these two must sum to actual_quantity.
  passed_quantity integer not null default 0,
  failed_quantity integer not null default 0,
  -- Stored, never corrected away (spec §10).
  discrepancy integer generated always as (actual_quantity - expected_quantity) stored,
  lot text,
  serial text,
  expiry date,
  packaging_condition text,
  product_condition text,
  label_ok boolean,
  result text not null default 'PENDING'
    check (result in ('PENDING', 'PASS', 'FAIL', 'PARTIAL', 'HOLD')),
  note text,
  created_at timestamptz not null default now(),
  constraint inspection_items_split_nonneg
    check (passed_quantity >= 0 and failed_quantity >= 0)
);

create index if not exists inspection_items_inspection_idx
  on public.inspection_items (inspection_id, id);

-- ------------------------------------------------------------------ start
-- Opens (or returns) the inspection for a receipt, seeding one item per counted
-- line with what receiving actually recorded.
create or replace function public.start_inspection(p_reconciliation_id bigint)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id        bigint;
  v_plan      bigint;
  v_warehouse bigint;
begin
  select id into v_id from public.inspections
   where reconciliation_id = p_reconciliation_id;
  if v_id is not null then
    return v_id;
  end if;

  select r.delivery_plan_id,
         coalesce(p.warehouse_id, public.default_warehouse_id())
    into v_plan, v_warehouse
    from public.delivery_reconciliations r
    join public.delivery_plans p on p.id = r.delivery_plan_id
   where r.id = p_reconciliation_id;

  if v_plan is null then
    raise exception 'reconciliation % not found', p_reconciliation_id;
  end if;

  insert into public.inspections
    (company_id, warehouse_id, reconciliation_id, delivery_plan_id,
     status, inspector_user_id)
  values
    ((select id from public.companies order by id limit 1),
     v_warehouse, p_reconciliation_id, v_plan, 'PENDING', auth.uid())
  returning id into v_id;

  insert into public.inspection_items
    (inspection_id, reconciliation_line_id, jan_code, product_name,
     expected_quantity, actual_quantity)
  select v_id, rl.id, rl.jan_code, pl.product_name,
         coalesce(rl.planned_quantity, 0), coalesce(rl.actual_quantity, 0)
  from public.reconciliation_lines rl
  left join public.delivery_plan_lines pl on pl.id = rl.plan_line_id
  where rl.reconciliation_id = p_reconciliation_id;

  perform public.log_audit(
    'inspection.started', 'inspection', v_id::text, v_warehouse,
    jsonb_build_object('reconciliation_id', p_reconciliation_id,
                       'plan_id', v_plan));

  return v_id;
end;
$$;

-- ------------------------------------------------------------------- save
-- Records one item's findings. The pass/fail split is authoritative: the item
-- result is derived from it so the two can never disagree.
create or replace function public.save_inspection_item(
  p_item_id bigint,
  p_passed integer,
  p_failed integer,
  p_lot text default null,
  p_serial text default null,
  p_expiry date default null,
  p_packaging_condition text default null,
  p_product_condition text default null,
  p_label_ok boolean default null,
  p_note text default null,
  p_hold boolean default false
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_passed integer := greatest(coalesce(p_passed, 0), 0);
  v_failed integer := greatest(coalesce(p_failed, 0), 0);
  v_result text;
begin
  v_result := case
    when p_hold then 'HOLD'
    when v_passed = 0 and v_failed = 0 then 'PENDING'
    when v_failed = 0 then 'PASS'
    when v_passed = 0 then 'FAIL'
    else 'PARTIAL'
  end;

  update public.inspection_items
     set passed_quantity = v_passed,
         failed_quantity = v_failed,
         actual_quantity = v_passed + v_failed,
         lot = p_lot,
         serial = p_serial,
         expiry = p_expiry,
         packaging_condition = p_packaging_condition,
         product_condition = p_product_condition,
         label_ok = p_label_ok,
         note = p_note,
         result = v_result
   where id = p_item_id;

  if not found then
    raise exception 'inspection item % not found', p_item_id;
  end if;

  return v_result;
end;
$$;

-- --------------------------------------------------------------- complete
-- Rolls the item results up into the inspection verdict (spec §10):
--   any HOLD -> HOLD; all PASS -> PASS; all FAIL -> FAIL; otherwise PARTIAL.
create or replace function public.complete_inspection(
  p_inspection_id bigint,
  p_note text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_total     int;
  v_hold      int;
  v_pass      int;
  v_fail      int;
  v_pending   int;
  v_status    text;
  v_warehouse bigint;
  v_failed_q  int;
begin
  select warehouse_id into v_warehouse
    from public.inspections where id = p_inspection_id;
  if v_warehouse is null then
    raise exception 'inspection % not found', p_inspection_id;
  end if;

  select count(*),
         count(*) filter (where result = 'HOLD'),
         count(*) filter (where result = 'PASS'),
         count(*) filter (where result = 'FAIL'),
         count(*) filter (where result = 'PENDING'),
         coalesce(sum(failed_quantity), 0)
    into v_total, v_hold, v_pass, v_fail, v_pending, v_failed_q
  from public.inspection_items
  where inspection_id = p_inspection_id;

  if v_total = 0 then
    raise exception 'inspection % has no items', p_inspection_id;
  end if;
  if v_pending > 0 then
    raise exception 'inspection % still has % unchecked item(s)',
      p_inspection_id, v_pending;
  end if;

  v_status := case
    when v_hold > 0 then 'HOLD'
    when v_pass = v_total then 'PASS'
    when v_fail = v_total then 'FAIL'
    else 'PARTIAL'
  end;

  update public.inspections
     set status = v_status,
         note = coalesce(p_note, note),
         inspector_user_id = coalesce(inspector_user_id, auth.uid()),
         completed_at = now()
   where id = p_inspection_id;

  perform public.log_audit(
    'inspection.confirmed', 'inspection', p_inspection_id::text, v_warehouse,
    jsonb_build_object('status', v_status, 'items', v_total,
                       'failed_quantity', v_failed_q));

  return v_status;
end;
$$;

-- ----------------------------------------------------------------- reading
create or replace function public.inspection_detail(p_inspection_id bigint)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', i.id,
    'status', i.status,
    'warehouse_id', i.warehouse_id,
    'reconciliation_id', i.reconciliation_id,
    'delivery_plan_id', i.delivery_plan_id,
    'delivery_number', p.delivery_number,
    'supplier_name', p.supplier_name,
    'note', i.note,
    'created_at', i.created_at,
    'completed_at', i.completed_at,
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', it.id,
        'jan_code', it.jan_code,
        'product_name', it.product_name,
        'expected_quantity', it.expected_quantity,
        'actual_quantity', it.actual_quantity,
        'passed_quantity', it.passed_quantity,
        'failed_quantity', it.failed_quantity,
        'discrepancy', it.discrepancy,
        'lot', it.lot,
        'serial', it.serial,
        'expiry', it.expiry,
        'packaging_condition', it.packaging_condition,
        'product_condition', it.product_condition,
        'label_ok', it.label_ok,
        'result', it.result,
        'note', it.note
      ) order by it.id)
      from public.inspection_items it where it.inspection_id = i.id
    ), '[]'::jsonb)
  )
  from public.inspections i
  left join public.delivery_plans p on p.id = i.delivery_plan_id
  where i.id = p_inspection_id;
$$;

-- ---------------------------------------------------------------------- RLS
alter table public.inspections enable row level security;
alter table public.inspection_items enable row level security;

drop policy if exists "read inspections" on public.inspections;
create policy "read inspections" on public.inspections
  for select to anon, authenticated using (true);

drop policy if exists "read inspection items" on public.inspection_items;
create policy "read inspection items" on public.inspection_items
  for select to anon, authenticated using (true);

-- ------------------------------------------------------------------ grants
-- Reads are open to the client; every mutation goes through the edge function
-- (service role), same posture as receiving and shipping.
grant execute on function public.inspection_detail(bigint) to anon, authenticated;

revoke execute on function public.start_inspection(bigint) from public, anon, authenticated;
revoke execute on function public.save_inspection_item(bigint, integer, integer, text, text, date, text, text, boolean, text, boolean) from public, anon, authenticated;
revoke execute on function public.complete_inspection(bigint, text) from public, anon, authenticated;

grant execute on function public.start_inspection(bigint) to service_role;
grant execute on function public.save_inspection_item(bigint, integer, integer, text, text, date, text, text, boolean, text, boolean) to service_role;
grant execute on function public.complete_inspection(bigint, text) to service_role;
