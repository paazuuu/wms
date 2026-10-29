-- 0166: the 商品名 (as shops call it) set by hand, and a picture from the web.
--
-- * set_product_market_name: the 商品名 (the 基本名 the 表示名 is built from,
--   0111) typed by a person — the AI's mark goes (0164). Empty: the product
--   has no 商品名 again (its 品番 stands in), so it can be looked up again.
-- * A product registered under the name the web gave (the stock import
--   takes it before registering, 0164) is marked 'ai' too.
-- * product_images.source_url: the page a picture was taken from, when it
--   came from the web (jan-catalog /photos), for a person to check.

create or replace function public.set_product_market_name(p_product_id bigint, p_name text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_name text := nullif(btrim(coalesce(p_name, '')), '');
  p record;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  select * into p from public.products where id = p_product_id;
  if not found then
    raise exception 'product % not found', p_product_id;
  end if;
  update public.products
     set base_name = coalesce(v_name, nullif(btrim(sku), ''), jan_code),
         base_name_source = null, base_name_source_url = null,
         -- The 表示名 is built from it again, unless typed by hand.
         updated_at = now()
   where id = p_product_id;
  perform public.log_audit('product.market_name_set', 'product', p_product_id::text,
    jsonb_build_object('base_name', p.base_name), jsonb_build_object('base_name', v_name));
  return (select jsonb_build_object('id', x.id, 'name', x.name, 'base_name', x.base_name)
            from public.products x where x.id = p_product_id);
end;
$$;
revoke all on function public.set_product_market_name(bigint, text) from public, anon;
grant execute on function public.set_product_market_name(bigint, text) to authenticated;

-- Registered under the web's name: marked as the AI's.
create or replace function public.products_fill_jan_name()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  mn record;
begin
  if new.jan_code is null then
    return new;
  end if;
  if tg_op = 'UPDATE' and new.jan_code is not distinct from old.jan_code then
    return new;
  end if;
  select * into mn from public.jan_market_name(new.jan_code);
  if mn.name is null then
    return new;
  end if;
  if public.product_lacks_name(new.name, new.base_name, new.sku, new.jan_code, new.name_manual) then
    new.base_name := mn.name;
    new.base_name_source := 'ai';
    new.base_name_source_url := mn.source_url;
  elsif tg_op = 'INSERT' and btrim(coalesce(new.base_name, new.name)) = btrim(mn.name) then
    new.base_name_source := 'ai';
    new.base_name_source_url := mn.source_url;
  end if;
  return new;
end;
$$;

-- The 7 products registered on 10-29 under the web's names: marked so.
update public.products p
   set base_name_source = 'ai', base_name_source_url = mn.source_url
  from public.jan_name_lookups l
  cross join lateral public.jan_market_name(l.jan) mn
 where p.jan_code = l.jan and p.base_name_source is null and not p.name_manual
   and btrim(coalesce(p.base_name, p.name)) = btrim(mn.name);

alter table public.product_images add column if not exists source_url text;

-- product_images_of with the page a picture came from.
create or replace function public.product_images_of(p_product_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $function$
begin
  if not public.can_view_product_images() then
    raise exception 'not permitted: product.view required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', id, 'product_id', product_id, 'storage_path', storage_path,
             'content_type', content_type, 'byte_size', byte_size, 'caption', caption,
             'source_url', source_url,
             'position', position, 'created_at', created_at) order by position, id)
      from public.product_images
     where product_id = p_product_id and withdrawn_at is null), '[]'::jsonb);
end;
$function$;

-- A picture found on the web (jan-catalog /photos): added as any other
-- (product.manage, as the person who asked), first when it is the only one,
-- with the page it came from.
create or replace function public.add_product_web_image(
  p_product_id bigint, p_storage_path text, p_content_type text, p_byte_size bigint, p_source_url text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform public.add_product_image(p_product_id, p_storage_path, p_content_type, p_byte_size, 'Web', false);
  update public.product_images set source_url = case when p_source_url ~ '^https?://' then p_source_url end
   where product_id = p_product_id and storage_path = p_storage_path;
  return public.product_images_of(p_product_id);
end;
$$;
revoke all on function public.add_product_web_image(bigint, text, text, bigint, text) from public, anon;
grant execute on function public.add_product_web_image(bigint, text, text, bigint, text) to authenticated;
