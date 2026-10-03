-- 0119 — deleting a product, and a supplier's quotation as prices.
--
--   * `product.delete` is its own permission (admins), apart from
--     `product.manage`: adding and editing is everyday work, deleting is not.
--   * `delete_product` removes a product that was registered by mistake and
--     never used. One that stock, an order, a receipt, a shipment or an
--     invoice has named is refused — it is deactivated instead, so its
--     history still reads.
--   * `save_supplier_quote` keeps what a quotation (見積書) says a supplier
--     charges for each of our products — unit price, list price and rate,
--     their code, the case quantity — in `supply_chain_supplier_products`
--     (0107), and learns their writing for each product (0110), as a
--     delivery note does.
--
-- No `drop` here: on this project a migration with one waits for a
-- confirmation and times out (see 0118).

insert into public.permissions (code, description)
values ('product.delete', 'Delete products that were never used')
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
  from public.roles r, public.permissions p
 where r.code in ('system_admin', 'company_admin') and p.code = 'product.delete'
on conflict do nothing;

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
  -- An invoice line only loses its link when its product goes (set null),
  -- so it is checked here: a product on an invoice has been bought.
  if exists (select 1 from public.supplier_invoice_lines where product_id = p_id) then
    raise exception 'product is in use; deactivate it instead';
  end if;
  begin
    -- Its pictures go with it. The files stay in storage, as a withdrawn
    -- picture's do (0109).
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

-- A quotation's lines, read like a delivery note's (import-plan, dry run)
-- and tied to our products: [{product_id, unit_price, list_price,
-- discount_rate, case_quantity, supplier_code, product_code, product_name,
-- maker, jan_code, ...}]. Lines with no product are skipped.
create or replace function public.save_supplier_quote(p_partner_id bigint, p_lines jsonb, p_note text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  e jsonb;
  v_pid bigint;
  v_prices int := 0;
  v_skipped int := 0;
  v_unit numeric;
  v_list numeric;
  v_rate numeric;
  v_lot int;
  v_sku text;
  v_note text := public.tidy_text(p_note);
  learn jsonb := '[]'::jsonb;
  learned jsonb;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if not exists (select 1 from public.delivery_suppliers where id = p_partner_id) then
    raise exception 'partner % not found', p_partner_id;
  end if;
  for e in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_pid := nullif(e->>'product_id', '')::bigint;
    if v_pid is null or not exists (select 1 from public.products where id = v_pid) then
      v_skipped := v_skipped + 1;
      continue;
    end if;
    v_unit := nullif(e->>'unit_price', '')::numeric;
    v_list := nullif(e->>'list_price', '')::numeric;
    v_rate := nullif(e->>'discount_rate', '')::numeric;
    v_lot := nullif(e->>'case_quantity', '')::numeric::int;
    v_sku := coalesce(public.tidy_text(e->>'supplier_code'), public.tidy_text(e->>'product_code'));
    if v_unit is null and v_list is not null and v_rate is not null then
      v_unit := round(v_list * v_rate, 2);
    end if;
    if v_unit is not null or v_list is not null then
      insert into public.supply_chain_supplier_products
        (partner_id, product_id, supplier_sku, list_price, discount_rate, unit_price, order_lot, source, note)
      values (p_partner_id, v_pid, v_sku,
              case when v_list >= 0 then v_list end,
              case when v_rate between 0 and 2 then v_rate end,
              case when v_unit >= 0 then v_unit end,
              case when v_lot > 0 then v_lot end,
              'document', v_note)
      on conflict (partner_id, product_id) do update
         set supplier_sku = coalesce(excluded.supplier_sku, supply_chain_supplier_products.supplier_sku),
             list_price = coalesce(excluded.list_price, supply_chain_supplier_products.list_price),
             discount_rate = coalesce(excluded.discount_rate, supply_chain_supplier_products.discount_rate),
             unit_price = coalesce(excluded.unit_price, supply_chain_supplier_products.unit_price),
             order_lot = coalesce(excluded.order_lot, supply_chain_supplier_products.order_lot),
             source = 'document',
             note = coalesce(excluded.note, supply_chain_supplier_products.note),
             active = true,
             updated_at = now();
      v_prices := v_prices + 1;
    end if;
    learn := learn || jsonb_build_array(e);
  end loop;
  if jsonb_array_length(learn) > 0 then
    learned := public.learn_notation_lines(p_partner_id, learn, 'import', true);
  end if;
  perform public.log_audit('supplier.quote_saved', 'partner', p_partner_id::text, null,
    jsonb_build_object('prices', v_prices, 'lines', jsonb_array_length(learn), 'note', v_note));
  return jsonb_build_object('prices', v_prices, 'products', jsonb_array_length(learn),
                            'skipped', v_skipped, 'learned', coalesce(learned, '{}'::jsonb));
end;
$$;

revoke all on function public.delete_product(bigint) from public, anon;
revoke all on function public.save_supplier_quote(bigint, jsonb, text) from public, anon;
grant execute on function public.delete_product(bigint) to authenticated, service_role;
grant execute on function public.save_supplier_quote(bigint, jsonb, text) to authenticated, service_role;
