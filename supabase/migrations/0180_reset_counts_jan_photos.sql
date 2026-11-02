-- 0180: システムの初期化 counts the pictures kept per JAN (jan_photos, 0179)
-- with what the AI looked up: they go together when 「AIが調べた商品名・重量・
-- 写真」 is chosen (the system-reset function empties them and their files).

create or replace function public.system_reset_counts()
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'imports', (select count(*) from public.master_imports),
    'documents', (select count(*) from public.import_documents),
    'proofs', (select count(*) from public.payment_proofs),
    'deliveries', (select count(*) from public.delivery_plans),
    'inspections', (select count(*) from public.inspections),
    'orders', (select count(*) from public.purchase_orders) + (select count(*) from public.sales_orders)
              + (select count(*) from public.purchase_requests) + (select count(*) from public.shipment_plans),
    'stock_levels', (select count(*) from public.stock_levels),
    'movements', (select count(*) from public.stock_movements),
    'products', (select count(*) from public.products),
    'price_book', (select count(*) from public.price_book_items),
    'suppliers', (select count(*) from public.delivery_suppliers where code is distinct from 'UNKNOWN'),
    'learned', (select count(*) from public.column_aliases where partner_id is not null)
               + (select count(*) from public.notation_dialects),
    'lookups', (select count(*) from public.jan_name_lookups) + (select count(*) from public.jan_weight_lookups)
               + (select count(*) from public.jan_photos),
    'audit', (select count(*) from public.audit_log),
    'ai_calls', (select count(*) from public.ai_calls),
    'files', (select coalesce(jsonb_object_agg(b, n), '{}'::jsonb) from (
               select bucket_id b, count(*) n from storage.objects
                where bucket_id in ('import-documents', 'master-import-files', 'payment-proofs', 'product-images')
                group by bucket_id) f));
$$;
