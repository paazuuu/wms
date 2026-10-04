-- 0126 — removing products from 商品マスタ for good, from the list.
--
-- `delete_product` (0119) never reached the live database: a function
-- holding a delete statement waits for a confirmation there (see 0118).
-- Removing is a row removal under policies instead, as 0124 does for the
-- library:
--
--   * products: a row may be removed by whoever holds `product.delete`
--     (system_admin, company_admin). Its own names, codes, units, supplier
--     names and attributes go with it (their keys cascade).
--   * Anything booked against the product — stock, movements, receipts,
--     orders, shipments, counts — refuses (those keys restrict), so a
--     product that was ever used cannot vanish and its stock stays as it
--     is; the app reports it and leaves it archived.
--   * product_images: the same holders may remove a product's picture rows
--     first (the key from pictures has no action, so it would refuse too).
--     Stored files stay, so a library item that copied a picture (0125)
--     keeps showing it.
--   * 商品ライブラリー is not touched: an item linked to the product only
--     loses the link (0124), and finds it again by JAN if the product
--     comes back (0125).
--   * Each removal is written to the audit log with what the product was.
--
-- Also: headings 寸法 / dimensions / 外寸 now mean the outer size
-- (attribute `dimensions`, 0125) rather than サイズ.

do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'products'
                  and policyname = 'products: product.delete can remove') then
    create policy "products: product.delete can remove" on public.products
      for delete to authenticated using (public.has_permission('product.delete'));
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'product_images'
                  and policyname = 'product_images: product.delete can remove') then
    create policy "product_images: product.delete can remove" on public.product_images
      for delete to authenticated using (public.has_permission('product.delete'));
  end if;
end $$;
grant delete on public.products, public.product_images to authenticated;

create or replace function public.products_log_removed()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform public.log_audit('product.deleted', 'product', old.id::text, null,
    jsonb_build_object('jan_code', old.jan_code, 'name', old.name, 'maker', old.maker, 'sku', old.sku,
                       'lifecycle', old.lifecycle));
  return old;
end;
$$;
revoke all on function public.products_log_removed() from public, anon, authenticated;
create or replace trigger products_z_log_removed
  after delete on public.products
  for each row execute function public.products_log_removed();

update public.column_aliases
   set attribute_id = (select id from public.product_attributes where key = 'dimensions')
 where partner_id is null and field = 'attr' and header_key in ('寸法', 'dimensions');
insert into public.column_aliases (partner_id, header_raw, header_key, field, attribute_id, source)
select null, h, h, 'attr', (select id from public.product_attributes where key = 'dimensions'), 'seed'
  from unnest(array['外寸', '外形寸法', '本体寸法', '商品寸法']) h
 where not exists (select 1 from public.column_aliases c where c.partner_id is null and c.header_key = h);

-- Which of [p_ids] something booked still points at (every key into
-- products that restricts, pictures aside) — read before removing, so a
-- product in use keeps its pictures too.
create or replace function public.products_in_use(p_ids bigint[])
returns bigint[]
language plpgsql stable security definer set search_path = '' as $$
declare
  r record;
  v_found bigint[];
  v_all bigint[] := '{}';
  v_id_att smallint := (select attnum from pg_attribute where attrelid = 'public.products'::regclass and attname = 'id');
begin
  if not public.has_permission('product.view') then
    raise exception 'not permitted: product.view required';
  end if;
  for r in
    select c.conrelid::regclass::text as tbl, a.attname as col
      from pg_constraint c
      join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[array_position(c.confkey, v_id_att)]
     where c.contype = 'f' and c.confrelid = 'public.products'::regclass
       and c.confdeltype in ('r', 'a') and c.conrelid <> 'public.product_images'::regclass
  loop
    execute format('select coalesce(array_agg(distinct %I), ''{}'') from %s where %I = any($1)', r.col, r.tbl, r.col)
      into v_found using coalesce(p_ids, '{}');
    v_all := v_all || v_found;
  end loop;
  return (select coalesce(array_agg(distinct x order by x), '{}') from unnest(v_all) x);
end;
$$;
revoke all on function public.products_in_use(bigint[]) from public, anon;
grant execute on function public.products_in_use(bigint[]) to authenticated, service_role;
