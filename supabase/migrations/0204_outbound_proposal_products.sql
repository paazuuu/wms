-- 0204: 出荷の提案 picks from the product library, as 入荷希望リスト does:
-- every active product, with what the warehouse holds of it, what is kept
-- (出庫予定 already registered, 0201, and orders) and what is free to ship.
-- What is proposed is registered as a 出庫予定 (outbound_file_plan), so it
-- keeps, sits on the 出庫カレンダー and is packed like any shipping list.
create or replace function public.outbound_proposal_products(p_warehouse_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.can_view_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  if p_warehouse_id is null or not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(x) order by x.on_hand = 0, x.name, x.jan_code)
      from (
        select p.jan_code, p.id as product_id, coalesce(nullif(p.name, ''), p.jan_code) as name,
               p.name_en, p.maker, p.sku, p.unit, p.unit_weight_g,
               s.on_hand,
               k.kept as reserved,
               0 as in_open,
               greatest(s.on_hand - k.kept, 0) as free,
               public.product_cost(p.id) as cost_price,
               p.list_price,
               p.price as sell_price
          from public.products p
          cross join lateral (
            select coalesce(sum(l.on_hand), 0)::integer as on_hand from public.stock_levels l
             where l.warehouse_id = p_warehouse_id and (l.product_id = p.id or l.jan_code = p.jan_code)
          ) s
          cross join lateral (
            select (coalesce(public.stock_reserved(p.id, p_warehouse_id), 0)
                    + public.outbound_kept_qty(p.id, p_warehouse_id))::integer as kept
          ) k
         where p.status = 'active'
      ) x), '[]'::jsonb);
end;
$$;
revoke all on function public.outbound_proposal_products(bigint) from public, anon;
grant execute on function public.outbound_proposal_products(bigint) to authenticated;
