-- 0022 — Global search (spec Step 14, §23)
--
-- "Global search over items/bins/POs/SOs/customers" — of those, only items
-- (stock_levels), inbound plans (delivery_plans, this app's stand-in for a
-- PO) and outbound plans (shipment_plans, its stand-in for an SO) actually
-- live in Supabase; purchase/sales orders, suppliers and customers are still
-- InventorOS records (a future Connector, per architecture_target.md) and
-- aren't searchable from here. Picking and transfer are added too, since
-- both now have their own numbers worth finding directly.
--
-- Read-only, PostgREST-callable directly like dashboard_metrics/stock_ledger
-- — no edge function needed for a read anon is already granted.

create or replace function public.global_search(
  p_query text,
  p_warehouse_id bigint default null,
  p_limit integer default 8
) returns jsonb
language sql stable security definer set search_path = '' as $$
  with q as (select '%' || trim(p_query) || '%' as pat)
  select case when trim(coalesce(p_query, '')) = '' then '[]'::jsonb else (
    select coalesce(jsonb_agg(row_to_json(x)::jsonb), '[]'::jsonb)
    from (
      (
        select 'stock' as kind, s.jan_code as id, s.jan_code,
               coalesce(nullif(s.product_name, ''), s.jan_code) as title,
               w.name as subtitle, s.on_hand as extra, s.warehouse_id
          from public.stock_levels s
          join public.warehouses w on w.id = s.warehouse_id
         where (p_warehouse_id is null or s.warehouse_id = p_warehouse_id)
           and (s.jan_code ilike (select pat from q)
                or s.product_name ilike (select pat from q))
         order by s.product_name nulls last, s.jan_code
         limit greatest(1, least(coalesce(p_limit, 8), 50))
      )
      union all
      (
        select 'delivery', p.id::text, null, p.delivery_number,
               coalesce(p.supplier_name, '') || ' · ' || p.status,
               null, p.warehouse_id
          from public.delivery_plans p
         where (p_warehouse_id is null or p.warehouse_id = p_warehouse_id)
           and (p.delivery_number ilike (select pat from q)
                or p.supplier_name ilike (select pat from q))
         order by p.id desc
         limit greatest(1, least(coalesce(p_limit, 8), 50))
      )
      union all
      (
        select 'shipment', s.id::text, null, s.shipment_number,
               coalesce(s.customer_name, '') || ' · ' || s.status,
               null, s.warehouse_id
          from public.shipment_plans s
         where (p_warehouse_id is null or s.warehouse_id = p_warehouse_id)
           and (s.shipment_number ilike (select pat from q)
                or s.customer_name ilike (select pat from q))
         order by s.id desc
         limit greatest(1, least(coalesce(p_limit, 8), 50))
      )
      union all
      (
        select 'pick_list', l.id::text, null,
               coalesce(sp.shipment_number, '#' || l.id),
               l.status, null, l.warehouse_id
          from public.pick_lists l
          join public.shipment_plans sp on sp.id = l.shipment_plan_id
         where (p_warehouse_id is null or l.warehouse_id = p_warehouse_id)
           and sp.shipment_number ilike (select pat from q)
         order by l.id desc
         limit greatest(1, least(coalesce(p_limit, 8), 50))
      )
      union all
      (
        select 'transfer', t.id::text, null, t.transfer_number,
               sw.name || ' → ' || dw.name || ' · ' || t.status,
               null, t.source_warehouse_id
          from public.transfer_orders t
          join public.warehouses sw on sw.id = t.source_warehouse_id
          join public.warehouses dw on dw.id = t.destination_warehouse_id
         where (p_warehouse_id is null
                or t.source_warehouse_id = p_warehouse_id
                or t.destination_warehouse_id = p_warehouse_id)
           and t.transfer_number ilike (select pat from q)
         order by t.id desc
         limit greatest(1, least(coalesce(p_limit, 8), 50))
      )
    ) x
  ) end;
$$;

grant execute on function public.global_search(text, bigint, integer)
  to anon, authenticated, service_role;
