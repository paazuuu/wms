-- 0102 — a dashboard per job: inspection, purchasing, and orders from China.
--
-- One dashboard served everyone. The user asked for one per role, switchable
-- by hand:
--   * whoever inspects needs what is coming in and when — and, when a supplier
--     sends no shipping list, a way to write the list themselves;
--   * whoever buys needs stock as it really stands (awaiting inspection and
--     inspected alike) next to what is already on its way;
--   * whoever takes orders from China needs the year's orders, month by month
--     against last year, and what those orders still need bought.
--
--   * `delivery_suppliers.country_code` (default JP) — which country a
--     customer (or supplier) is in, so "orders from China" is a question the
--     data can answer; `set_trading_partner_country`, and the partner list
--     returns it.
--   * `create_manual_delivery_plan` — an inbound list written by hand (supplier,
--     expected date, products and quantities). It is an ordinary delivery plan
--     (number MN-…), so receiving, inspection and bulk inspection all work on
--     it unchanged.
--   * `dashboard_inbound_schedule(warehouse)` — open deliveries with their
--     expected date (the plan's, else its purchase order's) and what is still
--     to come, approved purchase orders nobody has planned a delivery for yet,
--     and how much is waiting for inspection.
--   * `dashboard_stock_position(country, search)` — per product in one
--     country: usable, awaiting inspection, held, reserved, available,
--     incoming on open purchase orders with the next expected date, and what
--     approved orders still wait for.
--   * `dashboard_sales_cycle(country, months)` — orders from customers in one
--     country: units and orders per month for the last twelve months against
--     the same month a year before, the products ordered most, and what those
--     orders still wait for after what is already incoming.

-- ---------------------------------------------------------------------------
-- A partner's country
-- ---------------------------------------------------------------------------

alter table public.delivery_suppliers
  add column if not exists country_code text not null default 'JP'
  check (country_code ~ '^[A-Z]{2}$');

create or replace function public.set_trading_partner_country(p_id bigint, p_country_code text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_code text := upper(btrim(coalesce(p_country_code, '')));
begin
  if not public.has_permission('partner.manage') then
    raise exception 'not permitted: partner.manage required';
  end if;
  if v_code !~ '^[A-Z]{2}$' then
    raise exception 'country code must be two letters, got %', p_country_code;
  end if;
  update public.delivery_suppliers set country_code = v_code, updated_at = now()
   where id = p_id;
  if not found then
    raise exception 'trading partner % not found', p_id;
  end if;
  perform public.log_audit('partner.country_set', 'trading_partner', p_id::text, null,
    jsonb_build_object('country_code', v_code));
  return jsonb_build_object('id', p_id, 'country_code', v_code);
end;
$$;

revoke all on function public.set_trading_partner_country(bigint, text) from public, anon;
grant execute on function public.set_trading_partner_country(bigint, text) to authenticated, service_role;

do $$
declare v_src text;
begin
  select pg_get_functiondef('public.list_trading_partners(text,text,text)'::regprocedure) into v_src;
  if position('country_code' in v_src) = 0 then
    v_src := replace(v_src, '''status'', s.status,', '''status'', s.status, ''country_code'', s.country_code,');
    if position('country_code' in v_src) = 0 then
      raise exception 'list_trading_partners did not have the expected shape';
    end if;
    execute v_src;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- An inbound list written by hand
-- ---------------------------------------------------------------------------

create or replace function public.create_manual_delivery_plan(
  p_warehouse_id bigint,
  p_lines jsonb,
  p_supplier_id bigint default null,
  p_supplier_name text default null,
  p_expected_on date default null,
  p_note text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_plan    bigint;
  v_name    text;
  e         jsonb;
  v_jan     text;
  v_qty     int;
  v_product record;
  v_lines   int := 0;
  v_units   int := 0;
begin
  if not (public.has_permission('receiving.confirm') or public.has_permission('inspection.confirm')) then
    raise exception 'not permitted: receiving.confirm required';
  end if;
  if p_warehouse_id is null or not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'a list needs at least one product';
  end if;

  v_name := coalesce(nullif(btrim(coalesce(p_supplier_name, '')), ''),
                     (select s.name from public.delivery_suppliers s where s.id = p_supplier_id));

  insert into public.delivery_plans (
    delivery_number, supplier_id, supplier_name, warehouse_id, delivery_date, status, doc_type)
  values ('', p_supplier_id, v_name, p_warehouse_id,
          case when p_expected_on is null then null else p_expected_on::text end, 'open', 'plan')
  returning id into v_plan;
  update public.delivery_plans set delivery_number = 'MN-' || lpad(v_plan::text, 6, '0')
   where id = v_plan;

  for e in select * from jsonb_array_elements(p_lines) loop
    v_jan := nullif(regexp_replace(coalesce(e->>'jan_code', ''), '\D', '', 'g'), '');
    v_qty := coalesce(nullif(e->>'quantity', '')::int, 0);
    continue when v_jan is null or v_qty <= 0;
    select id, name into v_product from public.products where jan_code = v_jan;
    insert into public.delivery_plan_lines (
      delivery_plan_id, jan_code, product_name, planned_quantity, product_id)
    values (v_plan, v_jan,
            coalesce(v_product.name, nullif(btrim(coalesce(e->>'product_name', '')), ''), ''),
            v_qty, v_product.id);
    v_lines := v_lines + 1;
    v_units := v_units + v_qty;
  end loop;

  if v_lines = 0 then
    raise exception 'a list needs at least one product with a JAN and a quantity';
  end if;

  perform public.log_audit('delivery_plan.created_by_hand', 'delivery_plan', v_plan::text,
    p_warehouse_id, jsonb_build_object('lines', v_lines, 'units', v_units,
                                       'expected_on', p_expected_on, 'note', p_note));
  return jsonb_build_object('delivery_plan_id', v_plan,
                            'delivery_number', 'MN-' || lpad(v_plan::text, 6, '0'),
                            'lines', v_lines, 'units', v_units);
end;
$$;

revoke all on function public.create_manual_delivery_plan(bigint, jsonb, bigint, text, date, text) from public, anon;
grant execute on function public.create_manual_delivery_plan(bigint, jsonb, bigint, text, date, text)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Inspection: what is coming, and when
-- ---------------------------------------------------------------------------

create or replace function public.dashboard_inbound_schedule(p_warehouse_id bigint default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('receiving.view') or public.has_permission('inspection.view')
          or public.has_permission('purchase_order.view')) then
    raise exception 'not permitted: receiving.view required';
  end if;
  if p_warehouse_id is not null and not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  return jsonb_build_object(
    'today', public.warehouse_today(coalesce(p_warehouse_id, public.default_warehouse_id())),
    'plans', coalesce((
      select jsonb_agg(row_to_json(x)::jsonb order by x.expected_on nulls last, x.id)
        from (
          select p.id, p.delivery_number, p.status, p.warehouse_id, w.name as warehouse_name,
                 coalesce(po.supplier_name, p.supplier_name) as supplier_name,
                 po.po_number,
                 coalesce(case when p.delivery_date ~ '^\d{4}-\d{2}-\d{2}'
                               then left(p.delivery_date, 10)::date end,
                          po.expected_date) as expected_on,
                 p.delivery_number like 'MN-%' as manual,
                 (select count(*) from public.delivery_plan_lines l where l.delivery_plan_id = p.id) as line_count,
                 (select coalesce(sum(l.planned_quantity), 0) from public.delivery_plan_lines l
                   where l.delivery_plan_id = p.id)::int as planned_units,
                 (select coalesce(sum(greatest(l.planned_quantity - l.received_quantity, 0)), 0)
                    from public.delivery_plan_lines l where l.delivery_plan_id = p.id)::int as outstanding_units,
                 coalesce((select jsonb_agg(jsonb_build_object(
                             'jan_code', l.jan_code,
                             'product_name', coalesce(pr.name, l.product_name),
                             'outstanding', greatest(l.planned_quantity - l.received_quantity, 0))
                             order by l.id)
                             from (select * from public.delivery_plan_lines l0
                                    where l0.delivery_plan_id = p.id
                                      and l0.planned_quantity > l0.received_quantity
                                    order by l0.id limit 6) l
                             left join public.products pr on pr.id = l.product_id), '[]'::jsonb) as preview
            from public.delivery_plans p
            join public.warehouses w on w.id = p.warehouse_id
            left join public.purchase_orders po on po.id = p.purchase_order_id
           where p.status in ('open', 'partial', 'reconciling')
             and coalesce(p.doc_type, 'plan') = 'plan'
             and (p_warehouse_id is null or p.warehouse_id = p_warehouse_id)
             and public.can_access_warehouse(p.warehouse_id)
             and exists (select 1 from public.delivery_plan_lines l
                          where l.delivery_plan_id = p.id and l.planned_quantity > l.received_quantity)
        ) x), '[]'::jsonb),
    -- Ordered and approved, but no delivery written up for it yet.
    'unplanned_orders', coalesce((
      select jsonb_agg(row_to_json(x)::jsonb order by x.expected_date nulls last, x.id)
        from (
          select po.id, po.po_number, po.supplier_name, po.expected_date, po.warehouse_id,
                 w.name as warehouse_name,
                 (select count(*) from public.purchase_order_lines l where l.purchase_order_id = po.id) as line_count,
                 (select coalesce(sum(greatest(l.quantity - public.purchase_order_line_received(l.id), 0)), 0)
                    from public.purchase_order_lines l where l.purchase_order_id = po.id)::int as outstanding_units
            from public.purchase_orders po
            join public.warehouses w on w.id = po.warehouse_id
           where po.status = 'APPROVED'
             and (p_warehouse_id is null or po.warehouse_id = p_warehouse_id)
             and public.can_access_warehouse(po.warehouse_id)
             and not exists (select 1 from public.delivery_plans dp
                              where dp.purchase_order_id = po.id
                                and dp.status in ('open', 'partial', 'reconciling'))
             and exists (select 1 from public.purchase_order_lines l
                          where l.purchase_order_id = po.id
                            and l.quantity > public.purchase_order_line_received(l.id))
        ) x), '[]'::jsonb),
    'awaiting_inspection', (
      select jsonb_build_object('inspections', count(distinct ins.id),
                                'lines', count(it.id),
                                'units', coalesce(sum(it.actual_quantity), 0))
        from public.inspections ins
        join public.inspection_items it on it.inspection_id = ins.id and it.finalized_at is null
       where ins.status = 'PENDING'
         and (p_warehouse_id is null or ins.warehouse_id = p_warehouse_id)
         and public.can_access_warehouse(ins.warehouse_id)));
end;
$$;

revoke all on function public.dashboard_inbound_schedule(bigint) from public, anon;
grant execute on function public.dashboard_inbound_schedule(bigint) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Purchasing: stock as it stands, and what is on its way
-- ---------------------------------------------------------------------------

create or replace function public.dashboard_stock_position(
  p_country_code text default null, p_search text default null, p_limit integer default 100)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_country text := upper(coalesce(nullif(btrim(p_country_code), ''), public.home_country_code()));
  v_search  text := nullif(btrim(coalesce(p_search, '')), '');
  v_limit   integer := greatest(1, least(coalesce(p_limit, 100), 500));
begin
  if not (public.has_permission('inventory.view') or public.has_permission('purchase_order.view')) then
    raise exception 'not permitted: inventory.view required';
  end if;

  return (
    with wh as (
      select w.id from public.warehouses w
       where w.country_code = v_country and public.can_access_warehouse(w.id)
    ),
    units as (
      select su.product_id,
             sum(su.quantity) filter (where st.counts_available)::int as usable,
             sum(su.quantity) filter (where st.code = 'QC_PENDING')::int as qc_pending,
             sum(su.quantity) filter (where not st.counts_available and st.code <> 'QC_PENDING')::int as held
        from public.stock_units su
        join public.stock_statuses st on st.id = su.status_id
       where su.warehouse_id in (select id from wh) and su.quantity > 0
       group by su.product_id
    ),
    incoming as (
      select coalesce(l.product_id, (select pp.id from public.products pp where pp.jan_code = l.jan_code)) as product_id,
             sum(greatest(l.quantity - public.purchase_order_line_received(l.id), 0))::int as incoming,
             min(po.expected_date) filter (where l.quantity > public.purchase_order_line_received(l.id)) as next_expected
        from public.purchase_order_lines l
        join public.purchase_orders po on po.id = l.purchase_order_id
       where po.status in ('SUBMITTED', 'APPROVED')
         and po.warehouse_id in (select id from wh)
       group by 1
    ),
    demand as (
      select coalesce(l.product_id, (select pp.id from public.products pp where pp.jan_code = l.jan_code)) as product_id,
             sum(greatest(l.quantity - public.sales_order_line_promised(l.id), 0))::int as backordered
        from public.sales_order_lines l
        join public.sales_orders o on o.id = l.sales_order_id
       where o.status = 'APPROVED' and o.warehouse_id in (select id from wh)
       group by 1
    ),
    prod_rows as (
      select p.id as product_id, p.jan_code, p.name as product_name,
             coalesce(u.usable, 0) as usable,
             coalesce(u.qc_pending, 0) as qc_pending,
             coalesce(u.held, 0) as held,
             coalesce((select sum(public.stock_reserved(p.id, w.id)) from wh w), 0)::int as reserved,
             coalesce(i.incoming, 0) as incoming,
             i.next_expected,
             coalesce(d.backordered, 0) as backordered
        from public.products p
        left join units u on u.product_id = p.id
        left join incoming i on i.product_id = p.id
        left join demand d on d.product_id = p.id
       where (u.product_id is not null or coalesce(i.incoming, 0) > 0 or coalesce(d.backordered, 0) > 0)
         and (v_search is null or p.name ilike '%' || v_search || '%' or p.jan_code like v_search || '%')
    )
    select jsonb_build_object(
      'country_code', v_country,
      'products', coalesce((
        select jsonb_agg(jsonb_build_object(
          'product_id', r.product_id, 'jan_code', r.jan_code, 'product_name', r.product_name,
          'usable', r.usable, 'qc_pending', r.qc_pending, 'held', r.held,
          'on_hand', r.usable + r.qc_pending + r.held,
          'reserved', r.reserved, 'available', r.usable - r.reserved,
          'incoming', r.incoming, 'next_expected', r.next_expected,
          'backordered', r.backordered,
          -- What orders still need after stock and what is already coming.
          'shortfall', greatest(r.backordered - greatest(r.usable - r.reserved, 0) - r.incoming, 0))
          order by greatest(r.backordered - greatest(r.usable - r.reserved, 0) - r.incoming, 0) desc,
                   r.product_name)
          from (select * from prod_rows
                 order by greatest(backordered - greatest(usable - reserved, 0) - incoming, 0) desc,
                          product_name
                 limit v_limit) r), '[]'::jsonb),
      'totals', (select jsonb_build_object(
                   'usable', coalesce(sum(usable), 0), 'qc_pending', coalesce(sum(qc_pending), 0),
                   'held', coalesce(sum(held), 0), 'incoming', coalesce(sum(incoming), 0),
                   'products', count(*))
                   from prod_rows)));
end;
$$;

revoke all on function public.dashboard_stock_position(text, text, integer) from public, anon;
grant execute on function public.dashboard_stock_position(text, text, integer) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Orders from one country, a year at a time
-- ---------------------------------------------------------------------------

create or replace function public.dashboard_sales_cycle(
  p_country_code text default 'CN', p_months integer default 12)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_country text := upper(nullif(btrim(coalesce(p_country_code, '')), ''));
  v_months  integer := greatest(1, least(coalesce(p_months, 12), 24));
  v_today   date := public.warehouse_today(public.default_warehouse_id());
  v_from    date;
begin
  if not public.has_permission('sales_order.view') then
    raise exception 'not permitted: sales_order.view required';
  end if;
  v_from := (date_trunc('month', v_today) - make_interval(months => v_months - 1))::date;

  return (
    with lines as (
      select o.id as so_id, o.status, o.warehouse_id,
             coalesce(o.order_date, o.created_at::date) as ordered_on,
             coalesce(l.product_id, (select pp.id from public.products pp where pp.jan_code = l.jan_code)) as product_id,
             l.jan_code, l.id as line_id, l.quantity
        from public.sales_orders o
        join public.sales_order_lines l on l.sales_order_id = o.id
        left join public.delivery_suppliers c on c.id = o.customer_id
       where o.status not in ('DRAFT', 'CANCELLED', 'REJECTED')
         and public.can_access_warehouse(o.warehouse_id)
         and (v_country is null or coalesce(c.country_code, 'JP') = v_country)
         and coalesce(o.order_date, o.created_at::date) >= (v_from - interval '1 year')::date
    ),
    months as (
      select (v_from + make_interval(months => g))::date as m
        from generate_series(0, v_months - 1) g
    )
    select jsonb_build_object(
      'country_code', v_country,
      'months', (
        select jsonb_agg(jsonb_build_object(
                 'month', to_char(mo.m, 'YYYY-MM'),
                 'orders', (select count(distinct so_id) from lines
                             where date_trunc('month', ordered_on) = mo.m),
                 'units', (select coalesce(sum(quantity), 0) from lines
                            where date_trunc('month', ordered_on) = mo.m),
                 'prev_units', (select coalesce(sum(quantity), 0) from lines
                                 where date_trunc('month', ordered_on) = (mo.m - interval '1 year')))
                 order by mo.m)
          from months mo),
      'total_units', (select coalesce(sum(quantity), 0) from lines where ordered_on >= v_from),
      'prev_total_units', (select coalesce(sum(quantity), 0) from lines
                            where ordered_on < v_from and ordered_on >= (v_from - interval '1 year')::date),
      'total_orders', (select count(distinct so_id) from lines where ordered_on >= v_from),
      'top_products', coalesce((
        select jsonb_agg(row_to_json(t)::jsonb order by t.units desc)
          from (select l.product_id, max(p.name) as product_name, max(l.jan_code) as jan_code,
                       sum(l.quantity)::int as units, count(distinct l.so_id) as orders
                  from lines l left join public.products p on p.id = l.product_id
                 where l.ordered_on >= v_from
                 group by l.product_id
                 order by sum(l.quantity) desc limit 10) t), '[]'::jsonb),
      -- Approved orders still waiting, less what is already on its way.
      'to_purchase', coalesce((
        select jsonb_agg(row_to_json(t)::jsonb order by t.shortfall desc, t.backordered desc)
          from (
            select d.product_id, p.name as product_name, p.jan_code, d.backordered,
                   coalesce(i.incoming, 0) as incoming,
                   greatest(d.backordered - coalesce(i.incoming, 0), 0) as shortfall
              from (select product_id,
                           sum(greatest(quantity - public.sales_order_line_promised(line_id), 0))::int as backordered
                      from lines where status = 'APPROVED' and product_id is not null
                     group by product_id) d
              join public.products p on p.id = d.product_id
              left join lateral (
                select sum(greatest(pl.quantity - public.purchase_order_line_received(pl.id), 0))::int as incoming
                  from public.purchase_order_lines pl
                  join public.purchase_orders po on po.id = pl.purchase_order_id
                 where po.status in ('SUBMITTED', 'APPROVED')
                   and public.can_access_warehouse(po.warehouse_id)
                   and coalesce(pl.product_id, (select pp.id from public.products pp
                                                 where pp.jan_code = pl.jan_code)) = d.product_id) i on true
             where d.backordered > 0
             limit 50) t), '[]'::jsonb)));
end;
$$;

revoke all on function public.dashboard_sales_cycle(text, integer) from public, anon;
grant execute on function public.dashboard_sales_cycle(text, integer) to authenticated, service_role;
