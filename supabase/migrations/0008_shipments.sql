-- Outbound / shipping (出庫). Mirrors the inbound plan: a shipment list is
-- imported from a customer's Excel/PDF/image, then subdivided into cartons
-- (段ボール) for packing, and confirmed — which deducts the shipped quantities
-- from the per-JAN total stock. Reuses delivery_suppliers as the party table so
-- the per-company reference series (整理番号) is shared.

create table if not exists public.shipment_plans (
  id                  bigint generated always as identity primary key,
  shipment_number     text not null,
  party_id            bigint references public.delivery_suppliers(id),
  customer_name       text,
  customer_code       text,
  registration_number text,
  reference_no        text,
  doc_number          text,
  order_date          text,
  ship_date           text,
  needs_review        boolean not null default false,
  status              text not null default 'open'
                        check (status = any (array['open','packing','shipped','cancelled'])),
  shipped_at          timestamptz,
  created_at          timestamptz not null default now()
);

create table if not exists public.shipment_lines (
  id               bigint generated always as identity primary key,
  shipment_plan_id bigint not null references public.shipment_plans(id) on delete cascade,
  jan_code         text not null,
  product_code     text default '',
  product_name     text default '',
  spec             text,
  quantity         int not null default 0,
  unit_price       int,
  amount           int,
  tax_rate         numeric,
  order_date       text
);
create index if not exists shipment_lines_plan_idx
  on public.shipment_lines (shipment_plan_id);

-- One carton (段ボール / 小口) within a shipment, and its contents.
create table if not exists public.shipment_cartons (
  id               bigint generated always as identity primary key,
  shipment_plan_id bigint not null references public.shipment_plans(id) on delete cascade,
  carton_no        int not null,
  label            text,
  created_at       timestamptz not null default now()
);
create index if not exists shipment_cartons_plan_idx
  on public.shipment_cartons (shipment_plan_id);

create table if not exists public.shipment_carton_items (
  id               bigint generated always as identity primary key,
  carton_id        bigint not null references public.shipment_cartons(id) on delete cascade,
  shipment_line_id bigint references public.shipment_lines(id) on delete set null,
  jan_code         text not null,
  product_name     text default '',
  spec             text,
  quantity         int not null default 0
);
create index if not exists shipment_carton_items_carton_idx
  on public.shipment_carton_items (carton_id);

alter table public.shipment_plans        enable row level security;
alter table public.shipment_lines        enable row level security;
alter table public.shipment_cartons      enable row level security;
alter table public.shipment_carton_items enable row level security;
create policy "read shipments"       on public.shipment_plans        for select to anon, authenticated using (true);
create policy "read shipment lines"  on public.shipment_lines        for select to anon, authenticated using (true);
create policy "read cartons"         on public.shipment_cartons      for select to anon, authenticated using (true);
create policy "read carton items"    on public.shipment_carton_items for select to anon, authenticated using (true);

-- Confirm a shipment: deduct the shipped quantities from the per-JAN total
-- stock (floored at 0 so it never goes negative) and mark it shipped. Idempotent
-- — a second call on an already-shipped plan does nothing.
create or replace function public.ship_plan(p_plan_id bigint)
returns bigint language plpgsql set search_path = '' as $$
declare v_status text;
begin
  select status into v_status from public.shipment_plans where id = p_plan_id;
  if v_status is null then raise exception 'shipment % not found', p_plan_id; end if;
  if v_status = 'shipped' then return p_plan_id; end if;

  update public.stock_levels s
     set on_hand = greatest(coalesce(s.on_hand, 0) - agg.qty, 0),
         updated_at = now()
  from (
    select jan_code, sum(coalesce(quantity, 0)) as qty
    from public.shipment_lines where shipment_plan_id = p_plan_id
    group by jan_code
  ) agg
  where s.jan_code = agg.jan_code;

  update public.shipment_plans set status = 'shipped', shipped_at = now() where id = p_plan_id;
  return p_plan_id;
end $$;

-- Undo a shipment: if it was shipped, add the quantities back to stock; then
-- return it to 'open' so it can be corrected and re-shipped.
create or replace function public.cancel_shipment(p_plan_id bigint)
returns bigint language plpgsql set search_path = '' as $$
declare v_status text;
begin
  select status into v_status from public.shipment_plans where id = p_plan_id;
  if v_status is null then raise exception 'shipment % not found', p_plan_id; end if;

  if v_status = 'shipped' then
    insert into public.stock_levels (jan_code, product_name, on_hand)
    select sl.jan_code, coalesce(max(sl.product_name), ''), sum(coalesce(sl.quantity, 0))
    from public.shipment_lines sl where sl.shipment_plan_id = p_plan_id
    group by sl.jan_code
    on conflict (jan_code) do update
      set on_hand = public.stock_levels.on_hand + excluded.on_hand,
          updated_at = now();
  end if;

  update public.shipment_plans set status = 'open', shipped_at = null where id = p_plan_id;
  return p_plan_id;
end $$;

grant execute on function public.ship_plan(bigint) to authenticated;
grant execute on function public.cancel_shipment(bigint) to authenticated;
