-- Delivery reconciliation (納品照合) schema.
-- Plans + expected lines are imported from a supplier's Excel on the back
-- office; a handheld reconciles them against what physically arrives.

create table if not exists public.delivery_plans (
  id                  bigint generated always as identity primary key,
  delivery_number     text not null,
  supplier_name       text,
  supplier_code       text,
  customer_code       text,
  delivery_date       text,
  registration_number text,
  status              text not null default 'open'
                        check (status in ('open','reconciling','completed')),
  created_at          timestamptz not null default now()
);

create table if not exists public.delivery_plan_lines (
  id               bigint generated always as identity primary key,
  delivery_plan_id bigint not null
                     references public.delivery_plans(id) on delete cascade,
  jan_code         text not null,
  product_code     text,
  product_name     text not null default '',
  spec             text,
  planned_quantity integer not null default 0,
  unit_price       integer,
  amount           integer,
  tax_rate         numeric
);
create index if not exists idx_plan_lines_plan on public.delivery_plan_lines(delivery_plan_id);
create index if not exists idx_plan_lines_jan  on public.delivery_plan_lines(jan_code);

create table if not exists public.delivery_reconciliations (
  id               bigint generated always as identity primary key,
  delivery_plan_id bigint not null
                     references public.delivery_plans(id) on delete cascade,
  operator_id      uuid default auth.uid(),
  note_reference   text,
  status           text not null default 'completed',
  created_at       timestamptz not null default now()
);
create index if not exists idx_recon_plan on public.delivery_reconciliations(delivery_plan_id);

create table if not exists public.reconciliation_lines (
  id                bigint generated always as identity primary key,
  reconciliation_id bigint not null
                      references public.delivery_reconciliations(id) on delete cascade,
  plan_line_id      bigint references public.delivery_plan_lines(id) on delete set null,
  jan_code          text not null,
  planned_quantity  integer not null default 0,
  actual_quantity   integer not null default 0,
  status            text not null
                      check (status in ('pending','matched','shortfall','over','unexpected')),
  source            text
);
create index if not exists idx_recon_lines_recon on public.reconciliation_lines(reconciliation_id);

-- Row Level Security: authenticated staff read plans and write reconciliations.
-- Excel imports (writes to plans) run with the service role, which bypasses RLS.
alter table public.delivery_plans           enable row level security;
alter table public.delivery_plan_lines      enable row level security;
alter table public.delivery_reconciliations enable row level security;
alter table public.reconciliation_lines     enable row level security;

create policy "read plans"         on public.delivery_plans
  for select to authenticated using (true);
create policy "update plan status" on public.delivery_plans
  for update to authenticated using (true) with check (true);
create policy "read plan lines"    on public.delivery_plan_lines
  for select to authenticated using (true);
create policy "read recons"        on public.delivery_reconciliations
  for select to authenticated using (true);
create policy "insert recons"      on public.delivery_reconciliations
  for insert to authenticated with check (true);
create policy "read recon lines"   on public.reconciliation_lines
  for select to authenticated using (true);
create policy "insert recon lines" on public.reconciliation_lines
  for insert to authenticated with check (true);
