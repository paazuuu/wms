-- 0085 — "on order" means still to arrive.
--
-- 0084 counted a purchase-order link as on order for as long as the purchase
-- order stayed open, including after its goods had been received. Received
-- goods are free stock until fill_backorders promises them, so the order line
-- was counted twice over: once as on order, and again once promised. The next
-- purchase raised from demand then linked too little to that line.
--
-- Now a link counts only its share of what the purchase-order line has not
-- delivered yet. Receipts are consumed by the links in the order they were
-- made, so the order that was bought for first is the first one covered.
create or replace function public.sales_order_line_on_order(p_line_id bigint)
returns integer
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(greatest(0, least(x.quantity, x.cum - x.received))), 0)::integer
    from (
      select d.sales_order_line_id, d.quantity,
             sum(d.quantity) over (partition by d.purchase_order_line_id order by d.id) as cum,
             coalesce((select sum(dpl.received_quantity)
                         from public.delivery_plan_lines dpl
                         join public.delivery_plans dp on dp.id = dpl.delivery_plan_id
                        where dp.purchase_order_id = pl.purchase_order_id
                          and dpl.jan_code = pl.jan_code), 0) as received
        from public.purchase_order_line_demands d
        join public.purchase_order_lines pl on pl.id = d.purchase_order_line_id
        join public.purchase_orders po on po.id = pl.purchase_order_id
       where po.status in ('DRAFT', 'SUBMITTED', 'APPROVED')
         and d.purchase_order_line_id in (
           select d2.purchase_order_line_id from public.purchase_order_line_demands d2
            where d2.sales_order_line_id = p_line_id)
    ) x
   where x.sales_order_line_id = p_line_id;
$$;

revoke all on function public.sales_order_line_on_order(bigint) from public, anon, authenticated;
grant execute on function public.sales_order_line_on_order(bigint) to service_role;

-- A purchase raised from demand without explicit links is linked to the lines
-- it is really for: stock already free will fill the oldest waiting lines
-- first, so those are skipped before the purchase is spread over the rest.
create or replace function public.create_purchase_order_from_demand(
  p_supplier_name text,
  p_warehouse_id bigint,
  p_lines jsonb,
  p_supplier_id bigint default null,
  p_expected_date date default null,
  p_note text default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_po_id bigint;
  v_line jsonb;
  v_pl record;
  v_demand jsonb;
  v_so_line record;
  v_left integer;
  v_take integer;
  v_qty integer;
  v_links integer := 0;
  v_free integer;
  v_uncovered integer;
begin
  -- create_purchase_order does the permission, scope, supplier and line checks.
  if jsonb_typeof(p_lines) is distinct from 'array' then
    raise exception 'at least one line is required';
  end if;
  if (select count(*) from jsonb_array_elements(p_lines) e)
       <> (select count(distinct e->>'jan_code') from jsonb_array_elements(p_lines) e) then
    raise exception 'each product may appear only once on a purchase order raised from demand';
  end if;

  v_po_id := public.create_purchase_order(
    p_supplier_name, p_warehouse_id, p_lines, p_supplier_id, p_expected_date, p_note);

  for v_pl in
    select l.id, l.jan_code, l.quantity,
           coalesce(l.product_id, (select p.id from public.products p
                                    where p.jan_code = l.jan_code)) as product_id
      from public.purchase_order_lines l where l.purchase_order_id = v_po_id
     order by l.id
  loop
    select e into v_line from jsonb_array_elements(p_lines) e
     where e->>'jan_code' = v_pl.jan_code limit 1;

    if v_line ? 'demands' and jsonb_typeof(v_line->'demands') = 'array' then
      for v_demand in select * from jsonb_array_elements(v_line->'demands') loop
        v_qty := coalesce((v_demand->>'quantity')::int, 0);
        continue when v_qty <= 0;
        select l.id, l.quantity,
               coalesce(l.product_id, (select p.id from public.products p
                                        where p.jan_code = l.jan_code)) as product_id,
               o.status, o.warehouse_id
          into v_so_line
          from public.sales_order_lines l
          join public.sales_orders o on o.id = l.sales_order_id
         where l.id = (v_demand->>'sales_order_line_id')::bigint;
        if v_so_line.id is null then
          raise exception 'sales order line % not found', v_demand->>'sales_order_line_id';
        end if;
        if v_so_line.status <> 'APPROVED' or v_so_line.warehouse_id <> p_warehouse_id then
          raise exception 'sales order line % is not an approved order in this warehouse',
            v_so_line.id;
        end if;
        if v_so_line.product_id is distinct from v_pl.product_id then
          raise exception 'sales order line % is for a different product than %',
            v_so_line.id, v_pl.jan_code;
        end if;
        insert into public.purchase_order_line_demands
          (purchase_order_line_id, sales_order_line_id, quantity)
        values (v_pl.id, v_so_line.id, v_qty);
        v_links := v_links + 1;
      end loop;
      if (select coalesce(sum(d.quantity), 0) from public.purchase_order_line_demands d
           where d.purchase_order_line_id = v_pl.id) > v_pl.quantity then
        raise exception 'the orders linked to % add up to more than its quantity %',
          v_pl.jan_code, v_pl.quantity;
      end if;
    elsif v_pl.product_id is not null then
      v_left := v_pl.quantity;
      v_free := greatest(public.stock_available(v_pl.product_id, p_warehouse_id), 0);
      for v_so_line in
        select l.id,
               greatest(l.quantity - public.sales_order_line_promised(l.id)
                        - public.sales_order_line_on_order(l.id), 0) as uncovered
          from public.sales_order_lines l
          join public.sales_orders o on o.id = l.sales_order_id
         where o.status = 'APPROVED' and o.warehouse_id = p_warehouse_id
           and coalesce(l.product_id, (select p.id from public.products p
                                        where p.jan_code = l.jan_code)) = v_pl.product_id
         order by o.approved_at nulls last, o.id, l.id
      loop
        exit when v_left <= 0;
        -- Free stock will reach the oldest waiting lines first (fill_backorders
        -- walks them in this same order), so they are not what is being bought for.
        v_uncovered := v_so_line.uncovered - least(v_free, v_so_line.uncovered);
        v_free := v_free - least(v_free, v_so_line.uncovered);
        continue when v_uncovered <= 0;
        v_take := least(v_left, v_uncovered);
        insert into public.purchase_order_line_demands
          (purchase_order_line_id, sales_order_line_id, quantity)
        values (v_pl.id, v_so_line.id, v_take);
        v_left := v_left - v_take;
        v_links := v_links + 1;
      end loop;
    end if;
  end loop;

  perform public.log_audit('purchase_order.created_from_demand', 'purchase_order',
    v_po_id::text, p_warehouse_id, jsonb_build_object('links', v_links));

  return jsonb_build_object(
    'purchase_order_id', v_po_id,
    'lines', (select count(*) from public.purchase_order_lines where purchase_order_id = v_po_id),
    'links', v_links);
end;
$$;

revoke all on function public.create_purchase_order_from_demand(text, bigint, jsonb, bigint, date, text)
  from public, anon;
grant execute on function public.create_purchase_order_from_demand(text, bigint, jsonb, bigint, date, text)
  to authenticated, service_role;
