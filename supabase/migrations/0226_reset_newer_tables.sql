-- システムの初期化 (0226): the tables added since 0175 emptied with the rest,
-- so emptying 商品ライブラリー no longer fails on those that point at a
-- product ("a table referenced in a foreign key constraint").
-- * これまでの作業 adds 出庫ファイル (outbound_files and its lines, packages,
--   packing lists, freight cost files), 国外の仮想在庫's stock files and
--   shipments, and 仕入先回答 — the work of 0188–0218.
-- * 商品ライブラリー adds 入数 (product_case_packs), the purchase prices kept
--   per product (purchase_price_entries) and the categories (0218).
-- * AIが調べた adds the JANs found by 品番 (code_jan_lookups, 0223).
-- Notes on 国外の拠点 (record_notes) and the sites themselves stay. The
-- counts shown before the reset count them too. Both functions are patched
-- in place, each change checked.
do $$
declare
  d text;
  n text;
begin
  d := pg_get_functiondef('public.system_reset(text,jsonb)'::regprocedure);
  n := replace(d,
    $a$'reader_warning_reports', 'product_import_alerts', 'attachments'];$a$,
    $b$'reader_warning_reports', 'product_import_alerts', 'attachments',
    'outbound_files', 'outbound_file_lines', 'outbound_packages', 'outbound_package_lines', 'outbound_packing_lists',
    'outbound_cost_files', 'overseas_stock_imports', 'overseas_stock_lines', 'overseas_shipments',
    'overseas_shipment_lines', 'supplier_answers', 'supplier_answer_files'];$b$);
  if n = d then raise exception 'system_reset: work list not found'; end if;
  d := n;
  n := replace(d,
    $a$'supply_chain_product_profiles', 'supply_chain_tariff_rules'];$a$,
    $b$'supply_chain_product_profiles', 'supply_chain_tariff_rules', 'product_case_packs', 'purchase_price_entries',
    'product_categories'];$b$);
  if n = d then raise exception 'system_reset: product list not found'; end if;
  d := n;
  n := replace(d, 'public.jan_name_lookups, public.jan_weight_lookups;',
                  'public.jan_name_lookups, public.jan_weight_lookups, public.code_jan_lookups;');
  if n = d then raise exception 'system_reset: lookups not found'; end if;
  execute n;

  d := pg_get_functiondef('public.system_reset_counts()'::regprocedure);
  n := replace(d, '+ (select count(*) from public.purchase_requests) + (select count(*) from public.shipment_plans),',
                  '+ (select count(*) from public.purchase_requests) + (select count(*) from public.shipment_plans)
              + (select count(*) from public.outbound_files) + (select count(*) from public.overseas_stock_imports)
              + (select count(*) from public.overseas_shipments) + (select count(*) from public.supplier_answers),');
  if n = d then raise exception 'system_reset_counts: orders not found'; end if;
  d := n;
  n := replace(d, '+ (select count(*) from public.jan_photos),',
                  '+ (select count(*) from public.jan_photos) + (select count(*) from public.code_jan_lookups),');
  if n = d then raise exception 'system_reset_counts: lookups not found'; end if;
  d := n;
  n := replace(d, $a$where bucket_id in ('import-documents', 'master-import-files', 'payment-proofs', 'product-images')$a$,
                  $b$where bucket_id in ('import-documents', 'master-import-files', 'payment-proofs', 'product-images',
                                    'outbound-files', 'cost-evidence', 'overseas-files', 'wish-files', 'supplier-answers')$b$);
  if n = d then raise exception 'system_reset_counts: buckets not found'; end if;
  execute n;
end $$;
