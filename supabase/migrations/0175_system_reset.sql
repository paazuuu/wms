-- 0175: システムの初期化 — the environment emptied of what was done in it,
-- to test again from nothing (or before handing it over), as often as
-- needed. The system administrator's only (system.reset), after typing
-- 「初期化」. The files go too, through the system-reset function.
--
-- Always emptied — what was done:
--   the stock files and their readings, evidence and transfer proofs;
--   deliveries, receipts, inspections, invoices, orders, requests,
--   shipments, picking, transfers, counts; the stock itself and its
--   ledger (levels, movements, adjustments, units, lots, serials).
-- By choice:
--   products   — 商品ライブラリー and 価格台帳 with all that hangs on them
--                (names, barcodes, units, images, attributes, shelf notes,
--                what suppliers call them); on by default.
--   suppliers  — the suppliers (but the 未確認 placeholder), what was learned
--                of their files (their headings, writing, training) and
--                their 振込先; off by default.
--   lookups    — what the AI looked up per JAN (商品名, weight); off.
--   logs       — the audit log and the AI's call log; on. The reset itself
--                is then the first line of the new audit log.
-- Never touched: users, roles and permissions, warehouses and their
-- layout, the company, AI keys and settings, makers' catalogs and the
-- reference archive, the field library, units, name formats, print
-- settings, the common heading names. Numbers (取込 #…) start again at 1.
--
-- Every table is named: nothing is emptied by a cascade, so a table not in
-- these lists cannot be reached by it.

insert into public.permissions (code, description)
values ('system.reset', 'システムの初期化（データを空にする）')
on conflict (code) do nothing;
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r, public.permissions p
 where r.code = 'system_admin' and p.code = 'system.reset'
on conflict do nothing;

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
    'lookups', (select count(*) from public.jan_name_lookups) + (select count(*) from public.jan_weight_lookups),
    'audit', (select count(*) from public.audit_log),
    'ai_calls', (select count(*) from public.ai_calls),
    'files', (select coalesce(jsonb_object_agg(b, n), '{}'::jsonb) from (
               select bucket_id b, count(*) n from storage.objects
                where bucket_id in ('import-documents', 'master-import-files', 'payment-proofs', 'product-images')
                group by bucket_id) f));
$$;
revoke all on function public.system_reset_counts() from public, anon;

-- What would go, for the screen to show before anything is done.
create or replace function public.system_reset_preview()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('system.reset') then
    raise exception 'not permitted: system.reset required';
  end if;
  return public.system_reset_counts();
end;
$$;
revoke all on function public.system_reset_preview() from public, anon;
grant execute on function public.system_reset_preview() to authenticated;

-- [p_options]: {products, suppliers, lookups, logs} (booleans; defaults
-- true, false, false, true). [p_confirm] must be 「初期化」.
create or replace function public.system_reset(p_confirm text, p_options jsonb default '{}'::jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_products boolean := coalesce((p_options->>'products')::boolean, true);
  v_suppliers boolean := coalesce((p_options->>'suppliers')::boolean, false);
  v_lookups boolean := coalesce((p_options->>'lookups')::boolean, false);
  v_logs boolean := coalesce((p_options->>'logs')::boolean, true);
  v_before jsonb;
  v_who text := public.user_display_name(auth.uid());
  v_done text[] := array[
    'master_imports', 'master_import_lines', 'import_documents', 'inbound_plan_documents', 'payment_proofs',
    'delivery_plans', 'delivery_plan_lines', 'delivery_reconciliations', 'reconciliation_lines', 'receipt_items',
    'inspections', 'inspection_items', 'exceptions', 'supplier_invoices', 'supplier_invoice_lines',
    'purchase_orders', 'purchase_order_lines', 'purchase_order_line_demands', 'purchase_requests', 'purchase_request_lines',
    'sales_orders', 'sales_order_lines', 'shipment_plans', 'shipment_lines', 'shipment_cartons', 'shipment_carton_items',
    'shipment_planned_cartons', 'pick_waves', 'pick_lists', 'pick_tasks', 'pick_items', 'transfer_orders', 'transfer_order_lines',
    'stock_counts', 'stock_count_lines', 'stock_levels', 'stock_movements', 'stock_adjustments', 'stock_units',
    'stock_reservations', 'stock_allocations', 'bin_stock', 'lots', 'serial_numbers', 'putaway_confirmations',
    'virtual_stock_entries', 'work_orders', 'work_order_components', 'ai_analysis', 'connector_runs',
    'reader_warning_reports', 'product_import_alerts', 'attachments'];
  v_product_tables text[] := array[
    'products', 'product_barcodes', 'product_uoms', 'product_names', 'product_images', 'product_attribute_values',
    'price_book_items', 'price_book_terms', 'shelf_notes', 'supplier_product_names', 'supplier_product_attributes',
    'notation_dialects', 'warehouse_products', 'supply_chain_cost_rules', 'supply_chain_supplier_products',
    'supply_chain_product_profiles', 'supply_chain_tariff_rules'];
  v_list text[];
begin
  if not public.has_permission('system.reset') then
    raise exception 'not permitted: system.reset required';
  end if;
  if btrim(coalesce(p_confirm, '')) <> '初期化' then
    raise exception 'reset_not_confirmed';
  end if;
  v_before := public.system_reset_counts();

  -- What was done, and the products with it when asked: in one statement,
  -- every table named.
  v_list := v_done || case when v_products then v_product_tables else '{}'::text[] end;
  execute 'truncate table ' || (select string_agg(format('public.%I', t), ', ') from unnest(v_list) t) || ' restart identity';

  if v_suppliers then
    -- Row by row, so what hangs on a supplier goes with it (its headings,
    -- writing, codes) and the common heading names stay.
    -- A product kept keeps its warehouse settings, without the supplier.
    update public.warehouse_products set preferred_supplier_id = null where preferred_supplier_id is not null;
    delete from public.delivery_suppliers where code is distinct from 'UNKNOWN';
    truncate table public.notation_trainings, public.notation_library_versions restart identity;
  end if;
  if v_lookups then
    truncate table public.jan_name_lookups, public.jan_weight_lookups;
  end if;
  if v_logs then
    truncate table public.audit_log, public.ai_calls restart identity;
  end if;

  perform public.log_audit('system.reset', 'system', null, null, jsonb_build_object(
    'by', v_who, 'products', v_products, 'suppliers', v_suppliers, 'lookups', v_lookups, 'logs', v_logs,
    'before', v_before));
  return jsonb_build_object('before', v_before, 'after', public.system_reset_counts(),
    'options', jsonb_build_object('products', v_products, 'suppliers', v_suppliers, 'lookups', v_lookups, 'logs', v_logs));
end;
$$;
revoke all on function public.system_reset(text, jsonb) from public, anon;
grant execute on function public.system_reset(text, jsonb) to authenticated;
