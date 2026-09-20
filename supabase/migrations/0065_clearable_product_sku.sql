-- `set_product_identity`: let an empty string clear the SKU.
--
-- 0057 wrote it with `coalesce(v_sku, sku)` so that passing one field would
-- leave the other alone — which is right, and is what every partial-update RPC
-- here does. The cost was that a SKU could be set and then never removed: null
-- means "leave it", and there was no way to say "make it empty".
--
-- 0063 had already settled the convention for exactly this case: null leaves a
-- field alone, an empty string clears it. This brings `set_product_identity`
-- into line with it, and with the client, which now offers a SKU field an
-- operator can empty — a field that silently refuses to clear reads as a bug,
-- and is one.
--
-- `nullif(btrim(...), '')` in the original turned '' into null before it reached
-- the coalesce, so the two cases were indistinguishable by the time the update
-- ran. They are separated here before that happens.
create or replace function public.set_product_identity(
  p_id bigint,
  p_sku text default null,
  p_tracking_mode text default null
) returns boolean
language plpgsql security definer set search_path = ''
as $$
declare
  -- Distinguishing "not supplied" from "supplied as empty" is the whole change,
  -- so the raw parameter is kept and only trimmed for storage.
  v_clear_sku boolean := p_sku is not null and btrim(p_sku) = '';
  v_sku text := nullif(btrim(coalesce(p_sku, '')), '');
  v_mode text := nullif(btrim(upper(coalesce(p_tracking_mode, ''))), '');
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if v_mode is not null and v_mode not in
     ('UNTRACKED', 'LOT', 'SERIAL', 'LOT_AND_SERIAL', 'EXPIRY') then
    raise exception 'unknown tracking_mode %', v_mode;
  end if;

  update public.products
     set sku = case when v_clear_sku then null else coalesce(v_sku, sku) end,
         tracking_mode = coalesce(v_mode, tracking_mode),
         updated_at = now()
   where id = p_id;
  if not found then
    raise exception 'product % not found', p_id;
  end if;

  perform public.log_audit('product.identity_updated', 'product', p_id::text,
    null, jsonb_build_object('sku', v_sku, 'sku_cleared', v_clear_sku,
                             'tracking_mode', v_mode));
  return true;
end;
$$;

-- `create or replace` keeps the ACL 0057 set, so the grants are not restated —
-- but the revoke is, because a future reader should not have to check whether a
-- replace could have re-opened the PUBLIC default.
revoke all on function public.set_product_identity(bigint, text, text)
  from public, anon;
grant execute on function public.set_product_identity(bigint, text, text)
  to authenticated, service_role;
