-- 0142 — prices on a shipment: what it cost us, what it lists at, what we
-- sell it for, and the price it goes out at, set in bulk.
--
--   * `product_cost(product)`: 原価 — the unit price of the supplier term in
--     force (価格台帳: valid now, newest first; a list price × rate when only
--     those are given), else the last purchase order price.
--   * `outbound_stock` also gives each product's 原価, 定価 (list_price) and
--     販売価格 (price), so the screen can work prices out from them.
--   * A shipment line keeps the price it goes out at (`unit_price`, `amount`)
--     and the three it was worked out from as they were then
--     (`price_snapshot`); the shipment keeps which prices its sheet shows
--     (`proposal.price_columns`).
--   * `outbound_sheet` gives them back for the sheet.

alter table public.shipment_lines
  add column if not exists price_snapshot jsonb;

comment on column public.shipment_lines.price_snapshot is
  'The prices a shipment price was worked out from, as they were (0142): {cost, list, sell}.';

-- 原価 of a product: the supplier term in force, else the last purchase.
create or replace function public.product_cost(p_product_id bigint)
returns numeric
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select coalesce(t.unit_price, case when t.list_price is not null and t.discount_rate is not null
                                        then round(t.list_price * t.discount_rate, 2) end)
       from public.price_book_terms t
       join public.price_book_items i on i.id = t.item_id
       join public.products p on p.id = p_product_id
      where (i.product_id = p.id or (i.product_id is null and i.jan_code = p.jan_code))
        and (t.valid_from is null or t.valid_from <= current_date)
        and (t.valid_to is null or t.valid_to >= current_date)
        and coalesce(t.unit_price, t.list_price * t.discount_rate) is not null
      order by t.valid_from desc nulls last, t.created_at desc
      limit 1),
    (select l.unit_price
       from public.purchase_order_lines l
       join public.purchase_orders o on o.id = l.purchase_order_id
      where l.product_id = p_product_id and l.unit_price is not null
      order by o.created_at desc, l.id desc
      limit 1));
$$;
revoke all on function public.product_cost(bigint) from public, anon;
grant execute on function public.product_cost(bigint) to authenticated, service_role;

create or replace function public.outbound_stock(p_warehouse_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.outbound_can_view() then
    raise exception 'not permitted: inventory.view required';
  end if;
  if p_warehouse_id is null or not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(x) order by x.name, x.jan_code)
      from (
        select s.jan_code, p.id as product_id,
               coalesce(nullif(p.name, ''), nullif(s.product_name, ''), s.jan_code) as name,
               p.name_en, p.maker, p.sku, p.unit,
               s.on_hand,
               r.reserved,
               o.in_open,
               greatest(s.on_hand - r.reserved - o.in_open, 0) as free,
               case when p.id is null then null else public.product_cost(p.id) end as cost_price,
               p.list_price,
               p.price as sell_price
          from public.stock_levels s
          left join public.products p on p.id = coalesce(s.product_id,
                    (select pp.id from public.products pp where pp.jan_code = s.jan_code limit 1))
          cross join lateral (
            select case when p.id is null then 0 else coalesce(public.stock_reserved(p.id, p_warehouse_id), 0) end as reserved
          ) r
          cross join lateral (
            select coalesce(sum(l.quantity), 0)::int as in_open
              from public.shipment_lines l
              join public.shipment_plans sp on sp.id = l.shipment_plan_id
             where sp.warehouse_id = p_warehouse_id and sp.status not in ('shipped', 'cancelled')
               and l.jan_code = s.jan_code
          ) o
         where s.warehouse_id = p_warehouse_id and s.on_hand > 0
      ) x), '[]'::jsonb);
end;
$$;

-- Lines may carry {unit_price, price_snapshot}; the rest as 0139.
create or replace function public.outbound_create(
  p_warehouse_id bigint,
  p_lines jsonb,
  p_destination_id bigint default null,
  p_ship_to jsonb default null,
  p_ship_date text default null,
  p_note text default null,
  p_proposal jsonb default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_dest public.ship_destinations;
  v_to jsonb;
  v_id bigint;
  v_no text;
  e jsonb;
  v_jan text;
  v_qty int;
  v_free int;
  v_pid bigint;
  v_name text;
  v_sku text;
  v_maker text;
  v_price numeric;
  v_count int := 0;
  v_units int := 0;
  v_total numeric := 0;
  v_seen text[] := '{}';
begin
  if not public.outbound_can_edit() then
    raise exception 'not permitted: pack.complete required';
  end if;
  if p_warehouse_id is null or not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if p_destination_id is not null then
    select * into v_dest from public.ship_destinations where id = p_destination_id and status = 'active';
    if v_dest.id is null then
      raise exception 'destination % not found', p_destination_id;
    end if;
  end if;
  v_to := jsonb_strip_nulls(jsonb_build_object(
            'name', v_dest.name, 'department', v_dest.department, 'contact_name', v_dest.contact_name,
            'postal_code', v_dest.postal_code, 'address1', v_dest.address1, 'address2', v_dest.address2,
            'phone', v_dest.phone, 'email', v_dest.email, 'country_code', v_dest.country_code))
          || jsonb_strip_nulls(coalesce(case when jsonb_typeof(p_ship_to) = 'object' then p_ship_to end, '{}'::jsonb));
  if public.tidy_text(v_to->>'name') is null then
    raise exception 'a destination (company name) is required';
  end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'no lines to ship';
  end if;

  insert into public.shipment_plans
    (shipment_number, party_id, customer_name, warehouse_id, ship_date, status, destination_id, ship_to, proposal, note)
  values ('', v_dest.party_id, v_to->>'name', p_warehouse_id, public.tidy_text(p_ship_date), 'open',
          v_dest.id, v_to, case when jsonb_typeof(p_proposal) = 'object' then p_proposal end, public.tidy_text(p_note))
  returning id into v_id;
  v_no := 'OUT-' || lpad(v_id::text, 6, '0');
  update public.shipment_plans set shipment_number = v_no where id = v_id;

  for e in select * from jsonb_array_elements(p_lines) loop
    v_jan := public.normalize_jan(public.tidy_text(e->>'jan_code'));
    v_qty := coalesce(nullif(btrim(coalesce(e->>'quantity', '')), '')::int, 0);
    continue when v_qty = 0;
    if v_qty < 0 then
      raise exception 'a quantity cannot be negative (%)', v_jan;
    end if;
    if v_jan is null or v_jan = any(v_seen) then
      raise exception 'line_jan:%', coalesce(v_jan, '');
    end if;
    v_seen := v_seen || v_jan;
    v_price := nullif(btrim(coalesce(e->>'unit_price', '')), '')::numeric;
    if v_price < 0 then
      raise exception 'a price cannot be negative (%)', v_jan;
    end if;
    select pp.id, coalesce(nullif(pp.name, ''), nullif(sl.product_name, ''), v_jan), pp.sku, pp.maker,
           greatest(coalesce(sl.on_hand, 0)
                    - case when pp.id is null then 0 else coalesce(public.stock_reserved(pp.id, p_warehouse_id), 0) end
                    - coalesce((select sum(l.quantity) from public.shipment_lines l
                                  join public.shipment_plans sp on sp.id = l.shipment_plan_id
                                 where sp.warehouse_id = p_warehouse_id and sp.status not in ('shipped', 'cancelled')
                                   and sp.id <> v_id and l.jan_code = v_jan), 0), 0)
      into v_pid, v_name, v_sku, v_maker, v_free
      from (select 1) one
      left join public.stock_levels sl on sl.warehouse_id = p_warehouse_id and sl.jan_code = v_jan
      left join public.products pp on pp.id = coalesce(sl.product_id,
                (select x.id from public.products x where x.jan_code = v_jan limit 1));
    if v_qty > v_free then
      raise exception 'over_free:%:%', v_jan, v_free;
    end if;
    insert into public.shipment_lines
      (shipment_plan_id, jan_code, product_id, product_name, product_code, maker, quantity, unit_price, amount,
       price_snapshot)
    values (v_id, v_jan, v_pid, coalesce(v_name, v_jan), v_sku, v_maker, v_qty, v_price,
            case when v_price is null then null else round(v_price * v_qty)::int end,
            case when jsonb_typeof(e->'price_snapshot') = 'object' then e->'price_snapshot' end);
    v_count := v_count + 1;
    v_units := v_units + v_qty;
    v_total := v_total + coalesce(v_price * v_qty, 0);
  end loop;
  if v_count = 0 then
    raise exception 'no lines to ship';
  end if;

  if v_dest.id is not null then
    update public.ship_destinations set use_count = use_count + 1, last_used_at = now() where id = v_dest.id;
  end if;
  perform public.log_audit('shipment.proposed', 'shipment_plan', v_id::text, p_warehouse_id,
    jsonb_build_object('number', v_no, 'lines', v_count, 'units', v_units, 'destination', v_to->>'name',
                       'total', v_total, 'proposal', p_proposal));
  return jsonb_build_object('id', v_id, 'shipment_number', v_no, 'lines', v_count, 'units', v_units,
                            'total', v_total);
end;
$$;

create or replace function public.outbound_sheet(p_shipment_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_plan public.shipment_plans;
  v_s public.delivery_suppliers;
begin
  if not public.outbound_can_view() then
    raise exception 'not permitted: pack.complete required';
  end if;
  select * into v_plan from public.shipment_plans where id = p_shipment_id;
  if v_plan.id is null then
    raise exception 'shipment % not found', p_shipment_id;
  end if;
  if not public.can_access_warehouse(v_plan.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  select * into v_s from public.delivery_suppliers where id = v_plan.party_id;
  return jsonb_build_object(
    'id', v_plan.id, 'shipment_number', v_plan.shipment_number, 'status', v_plan.status,
    'ship_date', v_plan.ship_date, 'order_date', v_plan.order_date, 'doc_number', v_plan.doc_number,
    'note', v_plan.note, 'created_at', v_plan.created_at, 'shipped_at', v_plan.shipped_at,
    'carrier', v_plan.carrier, 'tracking_number', v_plan.tracking_number,
    'price_columns', v_plan.proposal->'price_columns',
    'warehouse_name', (select w.name from public.warehouses w where w.id = v_plan.warehouse_id),
    'ship_to', coalesce(v_plan.ship_to, jsonb_strip_nulls(jsonb_build_object(
        'name', coalesce(v_plan.customer_name, v_s.name), 'address1', v_s.address, 'phone', v_s.phone,
        'email', v_s.email, 'contact_name', v_s.contact_name, 'country_code', v_s.country_code))),
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
               'jan_code', l.jan_code, 'name', coalesce(p.name, l.product_name), 'name_en', p.name_en,
               'maker', coalesce(l.maker, p.maker), 'product_code', coalesce(l.product_code, p.sku),
               'unit', p.unit, 'quantity', l.quantity, 'unit_price', l.unit_price, 'amount', l.amount,
               'cost_price', coalesce((l.price_snapshot->>'cost')::numeric,
                                      case when p.id is null then null else public.product_cost(p.id) end),
               'list_price', coalesce((l.price_snapshot->>'list')::numeric, p.list_price),
               'sell_price', coalesce((l.price_snapshot->>'sell')::numeric, p.price))
             order by l.id)
        from public.shipment_lines l
        left join public.products p on p.id = coalesce(l.product_id,
                  (select pp.id from public.products pp where pp.jan_code = l.jan_code limit 1))
       where l.shipment_plan_id = v_plan.id), '[]'::jsonb));
end;
$$;
