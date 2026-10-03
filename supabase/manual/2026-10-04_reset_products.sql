-- Start the product data over (2026-10-04).
--
-- Run this in the Supabase dashboard: SQL Editor → paste → Run.
-- (The deletes cannot run from the assistant: a statement that deletes rows
-- waits there for a confirmation that cannot be given.)
--
-- What goes: every product in the master (商品マスタ), and with it, by
-- cascade, its names by language, supplier names and codes, supplier prices,
-- learned spellings tied to it, attributes, units and barcodes.
-- What stays: suppliers, makers, warehouses, users, settings, and the
-- product library (商品ライブラリー, catalog_items), which is empty today.
-- Nothing booked (stock, orders, receipts, shipments) refers to these
-- products today, so nothing else is touched.
--
-- A copy of everything removed is kept in the backup_20261004_* tables:
--   backup_20261004_products, backup_20261004_product_names,
--   backup_20261004_supplier_product_names, backup_20261004_supplier_prices,
--   backup_20261004_notation_dialects

begin;
delete from public.products;
select count(*) as products_left from public.products;
commit;

-- Optional: lets 商品マスタ's 削除 button delete a product that was never
-- used (0119). Same reason it could not be applied from here.
create or replace function public.delete_product(p_id bigint)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v record;
  v_images int;
begin
  if not public.has_permission('product.delete') then
    raise exception 'not permitted: product.delete required';
  end if;
  select id, jan_code, name, maker, sku into v from public.products where id = p_id;
  if v.id is null then
    raise exception 'product % not found', p_id;
  end if;
  if exists (select 1 from public.supplier_invoice_lines where product_id = p_id) then
    raise exception 'product is in use; deactivate it instead';
  end if;
  begin
    delete from public.product_images where product_id = p_id;
    get diagnostics v_images = row_count;
    delete from public.products where id = p_id;
  exception when foreign_key_violation then
    raise exception 'product is in use; deactivate it instead';
  end;
  perform public.log_audit('product.deleted', 'product', p_id::text,
    jsonb_build_object('jan_code', v.jan_code, 'name', v.name, 'maker', v.maker, 'sku', v.sku), null);
  return jsonb_build_object('id', p_id, 'jan_code', v.jan_code, 'name', v.name, 'images', v_images);
end;
$$;
revoke all on function public.delete_product(bigint) from public, anon;
grant execute on function public.delete_product(bigint) to authenticated, service_role;
