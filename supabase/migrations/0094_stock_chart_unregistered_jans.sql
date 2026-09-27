-- 0094 — the stock chart says what it leaves out.
--
-- dashboard_stock_chart (0089/0090) charts products, so stock received under
-- a JAN nobody has registered as a product yet (stock_levels.product_id is
-- null) is not in any bar. The warehouse overview counts it, so the chart and
-- the totals disagreed with nothing to say why. The chart now also returns
-- `unregistered`: how many such JANs hold stock in the charted country and
-- how many units, so the dashboard can say so and point to 未登録JAN, where
-- registering the product brings the stock into the chart.
--
-- Rewritten in place from the live definition; one key is added, nothing
-- else changes.

do $$
declare v_src text;
begin
  select pg_get_functiondef('public.dashboard_stock_chart(integer,text)'::regprocedure)
    into v_src;
  if position('''unregistered''' in v_src) = 0 then
    v_src := replace(v_src,
      '      ''product_count'', coalesce((select max(product_count) from ranked), 0),',
      '      ''unregistered'', (
        select jsonb_build_object(''jan_count'', count(distinct sl.jan_code),
                                  ''units'', coalesce(sum(sl.on_hand), 0))
          from public.stock_levels sl
         where sl.product_id is null and sl.on_hand > 0
           and sl.warehouse_id in (select id from real_wh)),
      ''product_count'', coalesce((select max(product_count) from ranked), 0),');
    if position('''unregistered''' in v_src) = 0 then
      raise exception 'dashboard_stock_chart did not have the expected shape';
    end if;
    execute v_src;
  end if;
end $$;
