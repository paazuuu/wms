-- 0220: 入出庫履歴 says each product's 品番, and names what moved stock in
-- plain terms: stock a 発注 file brought in (booked as ADJUST with the
-- import as its reference) is "入荷（ファイル取込）", and an import taken
-- back or set lower is "取込の取消・修正" — not 在庫調整, which stays for
-- corrections made by hand.
do $$
declare
  v_def text := pg_get_functiondef('public.run_report(text, jsonb, integer)'::regprocedure);
  v_new text := v_def;
begin
  v_new := replace(v_new,
    $a$               m.product_name, m.movement_type, m.quantity, m.quantity_before,
               m.quantity_after,
               to_char(m.created_at at time zone 'Asia/Tokyo', 'YYYY-MM-DD') as movement_date,$a$,
    $a$               m.product_name, pr.sku as product_code,
               case when m.movement_type = 'ADJUST' and m.reference_type = 'master_import'
                    then case when m.quantity >= 0 then 'IMPORT_IN' else 'IMPORT_FIX' end
                    else m.movement_type end as movement_type,
               m.quantity, m.quantity_before,
               m.quantity_after,
               to_char(m.created_at at time zone 'Asia/Tokyo', 'YYYY-MM-DD') as movement_date,$a$);
  v_new := replace(v_new,
    $a$          left join public.warehouses w on w.id = m.warehouse_id
          left join lateral ($a$,
    $a$          left join public.warehouses w on w.id = m.warehouse_id
          left join public.products pr on pr.id = m.product_id
          left join lateral ($a$);
  if v_new = v_def or strpos(v_new, 'IMPORT_IN') = 0 or strpos(v_new, 'public.products pr') = 0 then
    raise exception '0220: run_report did not change as expected';
  end if;
  execute v_new;
end $$;
