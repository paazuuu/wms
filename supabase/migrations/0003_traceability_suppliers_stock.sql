-- Traceability + total stock.
-- Suppliers (companies) with a per-company reference counter, order dates on
-- plans/lines, reference numbers on plans and receipts, and a per-JAN stock total.

create table if not exists public.delivery_suppliers (
  id         bigint generated always as identity primary key,
  code       text unique,
  name       text not null,
  next_seq   int not null default 1,
  created_at timestamptz not null default now()
);

alter table public.delivery_plans
  add column if not exists supplier_id  bigint references public.delivery_suppliers(id),
  add column if not exists reference_no text,
  add column if not exists order_date   text,
  add column if not exists doc_type     text not null default 'plan';

alter table public.delivery_plan_lines
  add column if not exists order_date text;

alter table public.delivery_reconciliations
  add column if not exists supplier_id  bigint references public.delivery_suppliers(id),
  add column if not exists reference_no text;

create table if not exists public.stock_levels (
  jan_code     text primary key,
  product_name text default '',
  on_hand      int not null default 0,
  updated_at   timestamptz not null default now()
);

alter table public.delivery_suppliers enable row level security;
alter table public.stock_levels       enable row level security;
create policy "read suppliers" on public.delivery_suppliers
  for select to authenticated using (true);
create policy "read stock" on public.stock_levels
  for select to anon, authenticated using (true);

-- Per-company reference number, e.g. ABC-00001.
create or replace function public.assign_reference(p_supplier_id bigint)
returns text language plpgsql set search_path = '' as $$
declare v_code text; v_seq int;
begin
  if p_supplier_id is null then return null; end if;
  update public.delivery_suppliers
     set next_seq = next_seq + 1
   where id = p_supplier_id
   returning code, next_seq - 1 into v_code, v_seq;
  if v_code is null then v_code := 'C' || p_supplier_id; end if;
  return v_code || '-' || lpad(v_seq::text, 5, '0');
end; $$;
