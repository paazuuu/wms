-- 0089 — two dashboard reads: stock per product as a stacked bar, and the
-- latest purchase orders with the warehouse each is bound for.
--
-- The stock read returns both breakdowns a stacked bar can show, so the
-- client toggles between them without a second round trip:
--   * by warehouse — each real warehouse's on-hand, plus each warehouse
--     abroad's virtual figure (0088), kept visibly separate as virtual;
--   * by state — free to promise, reserved, not usable (held / in QC), and the
--     virtual figure abroad.
-- Free is clamped at zero: an over-committed product (available < 0, 0064)
-- shows as fully reserved rather than as a negative bar segment.

create or replace function public.dashboard_stock_chart(p_limit integer default 10)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 10), 30));
begin
  if not public.has_permission('inventory.view') then
    raise exception 'not permitted: inventory.view required';
  end if;

  return (
    with real_wh as (
      select w.id, w.name, w.country_code
        from public.warehouses w
       where w.status = 'active' and public.can_access_warehouse(w.id)
    ),
    virtual_wh as (
      select w.id, w.name, w.country_code
        from public.warehouses w
       where public.can_access_warehouse(w.id)
         and exists (select 1 from public.virtual_stock_entries e where e.warehouse_id = w.id)
    ),
    real_cells as (
      select x.product_id, x.warehouse_id,
             public.stock_on_hand(x.product_id, x.warehouse_id) as on_hand,
             public.stock_reserved(x.product_id, x.warehouse_id) as reserved,
             public.stock_available(x.product_id, x.warehouse_id) as available
        from (select distinct sl.product_id, sl.warehouse_id
                from public.stock_levels sl
               where sl.product_id is not null and sl.on_hand <> 0
                 and sl.warehouse_id in (select id from real_wh)) x
    ),
    virtual_cells as (
      select x.product_id, x.warehouse_id,
             greatest(public.virtual_balance(x.warehouse_id, x.product_id,
                                             public.warehouse_today(x.warehouse_id)), 0) as quantity
        from (select distinct e.product_id, e.warehouse_id
                from public.virtual_stock_entries e
               where e.warehouse_id in (select id from virtual_wh)) x
    ),
    per_product as (
      select p.id as product_id, p.jan_code, p.name as product_name,
             coalesce((select sum(greatest(c.on_hand, 0)) from real_cells c where c.product_id = p.id), 0)::int as on_hand,
             coalesce((select sum(greatest(least(c.available, c.on_hand), 0)) from real_cells c where c.product_id = p.id), 0)::int as free,
             coalesce((select sum(greatest(least(c.available + c.reserved, c.on_hand) - greatest(c.available, 0), 0))
                         from real_cells c where c.product_id = p.id), 0)::int as reserved,
             coalesce((select sum(greatest(c.on_hand - greatest(c.available + c.reserved, 0), 0))
                         from real_cells c where c.product_id = p.id), 0)::int as unusable,
             coalesce((select sum(v.quantity) from virtual_cells v where v.product_id = p.id), 0)::int as virtual_abroad,
             coalesce((select jsonb_agg(jsonb_build_object('warehouse_id', c.warehouse_id,
                                                           'quantity', greatest(c.on_hand, 0))
                                        order by c.warehouse_id)
                         from real_cells c where c.product_id = p.id and c.on_hand > 0), '[]'::jsonb)
             || coalesce((select jsonb_agg(jsonb_build_object('warehouse_id', v.warehouse_id,
                                                              'quantity', v.quantity, 'virtual', true)
                                           order by v.warehouse_id)
                            from virtual_cells v where v.product_id = p.id and v.quantity > 0), '[]'::jsonb)
               as by_warehouse
        from public.products p
       where p.id in (select product_id from real_cells union select product_id from virtual_cells)
    ),
    ranked as (
      select *, on_hand + virtual_abroad as total,
             row_number() over (order by on_hand + virtual_abroad desc, product_name) as rn,
             count(*) over () as product_count
        from per_product
       where on_hand + virtual_abroad > 0
    )
    select jsonb_build_object(
      'warehouses',
        coalesce((select jsonb_agg(jsonb_build_object('id', id, 'name', name,
                                                      'country_code', country_code,
                                                      'virtual', false) order by id)
                    from real_wh), '[]'::jsonb)
        || coalesce((select jsonb_agg(jsonb_build_object('id', id, 'name', name,
                                                         'country_code', country_code,
                                                         'virtual', true) order by id)
                       from virtual_wh), '[]'::jsonb),
      'product_count', coalesce((select max(product_count) from ranked), 0),
      'products', coalesce((select jsonb_agg(jsonb_build_object(
                     'product_id', product_id, 'jan_code', jan_code,
                     'product_name', product_name, 'total', total, 'on_hand', on_hand,
                     'free', free, 'reserved', reserved, 'unusable', unusable,
                     'virtual_abroad', virtual_abroad, 'by_warehouse', by_warehouse)
                     order by rn)
                     from ranked where rn <= v_limit), '[]'::jsonb)));
end;
$$;

revoke all on function public.dashboard_stock_chart(integer) from public, anon;
grant execute on function public.dashboard_stock_chart(integer) to authenticated, service_role;

-- The latest purchase orders, each with the warehouse it is bound for and how
-- far its receiving has got.
create or replace function public.dashboard_recent_purchase_orders(p_limit integer default 8)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('purchase_order.view') then
    raise exception 'not permitted: purchase_order.view required';
  end if;

  return coalesce((
    select jsonb_agg(row_to_json(x)::jsonb order by x.created_at desc, x.id desc)
      from (
        select o.id, o.po_number, o.supplier_name, o.status,
               o.order_date, o.expected_date, o.created_at,
               o.warehouse_id, w.name as warehouse_name, w.country_code,
               (select count(*) from public.purchase_order_lines l
                 where l.purchase_order_id = o.id) as line_count,
               coalesce((select sum(l.quantity) from public.purchase_order_lines l
                          where l.purchase_order_id = o.id), 0)::int as ordered_units,
               coalesce((select sum(public.purchase_order_line_received(l.id))
                           from public.purchase_order_lines l
                          where l.purchase_order_id = o.id), 0)::int as received_units,
               coalesce((select sum(l.quantity * coalesce(l.unit_price, 0))
                           from public.purchase_order_lines l
                          where l.purchase_order_id = o.id), 0) as total_amount
          from public.purchase_orders o
          join public.warehouses w on w.id = o.warehouse_id
         where public.can_access_warehouse(o.warehouse_id)
         order by o.created_at desc, o.id desc
         limit greatest(1, least(coalesce(p_limit, 8), 30))
      ) x), '[]'::jsonb);
end;
$$;

revoke all on function public.dashboard_recent_purchase_orders(integer) from public, anon;
grant execute on function public.dashboard_recent_purchase_orders(integer) to authenticated, service_role;
