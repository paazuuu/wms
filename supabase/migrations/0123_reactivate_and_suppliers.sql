-- 0123 — bringing products back from a file, and every supplier of a
-- product with its terms.
--
--   * `reactivate_products(ids[])` makes the given products active again —
--     what a file listing them asks for. Waking a dormant product needs
--     `product.manage` (it was only paused); bringing back an archived or
--     discontinued one needs `product.lifecycle`, as putting it there did.
--     Products the caller may not bring back are left as they are and
--     counted, never an error, so the rest of the file still goes through.
--   * The same rule now holds for the old on/off switch: setting `status`
--     back to active on an archived or discontinued product needs
--     `product.lifecycle` (before, `set_product_status` could undo an
--     archive with only `product.manage`).
--   * `product_suppliers_json` lists every supplier of a product with what
--     it calls the product, its code, and its terms — unit price, list
--     price and rate, order lot, when last updated — cheapest first.

create or replace function public.products_sync_lifecycle()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if new.lifecycle <> 'active' then
      new.status := 'inactive';
    elsif new.status = 'inactive' then
      new.lifecycle := 'dormant';
    end if;
    return new;
  end if;
  if new.lifecycle is distinct from old.lifecycle then
    new.status := case when new.lifecycle = 'active' then 'active' else 'inactive' end;
  elsif new.status is distinct from old.status then
    if new.status = 'active' then
      if old.lifecycle in ('archived', 'discontinued') and not public.has_permission('product.lifecycle') then
        raise exception 'not permitted: product.lifecycle required';
      end if;
      new.lifecycle := 'active';
    elsif old.lifecycle = 'active' then
      new.lifecycle := 'dormant';
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.reactivate_products(p_ids bigint[], p_reason text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_manage boolean := public.has_permission('product.manage');
  v_lifecycle boolean := public.has_permission('product.lifecycle');
  v_changed bigint[];
  v_skipped bigint[];
begin
  if not (v_manage or v_lifecycle) then
    raise exception 'not permitted: product.manage required';
  end if;
  select coalesce(array_agg(id) filter (where lifecycle = 'dormant' or v_lifecycle), '{}'),
         coalesce(array_agg(id) filter (where lifecycle <> 'dormant' and not v_lifecycle), '{}')
    into v_changed, v_skipped
    from public.products
   where id = any(coalesce(p_ids, '{}')) and lifecycle <> 'active';
  if array_length(v_changed, 1) > 0 then
    update public.products
       set lifecycle = 'active', lifecycle_reason = null,
           lifecycle_changed_at = now(), lifecycle_changed_by = auth.uid(), updated_at = now()
     where id = any(v_changed);
    perform public.log_audit('product.lifecycle_set', 'product', array_to_string(v_changed, ','), null,
      jsonb_build_object('lifecycle', 'active', 'reason', coalesce(public.tidy_text(p_reason), 'file'),
                         'count', array_length(v_changed, 1)));
  end if;
  return jsonb_build_object('changed', coalesce(array_length(v_changed, 1), 0), 'skipped', to_jsonb(v_skipped));
end;
$$;

create or replace function public.product_suppliers_json(p_product_id bigint)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', s.id, 'name', s.name,
           'their_name', n.supplier_name, 'their_code', coalesce(sp.supplier_sku, n.supplier_code),
           'unit_price', sp.unit_price, 'list_price', sp.list_price, 'discount_rate', sp.discount_rate,
           'order_lot', sp.order_lot, 'currency', sp.currency, 'is_primary', coalesce(sp.is_primary, false),
           'source', sp.source, 'updated_at', coalesce(sp.updated_at, n.updated_at))
         order by sp.unit_price nulls last, s.name), '[]'::jsonb)
    from public.delivery_suppliers s
    left join public.supplier_product_names n on n.supplier_id = s.id and n.product_id = p_product_id
    left join public.supply_chain_supplier_products sp
      on sp.partner_id = s.id and sp.product_id = p_product_id and sp.active
   where n.id is not null or sp.id is not null;
$$;

revoke all on function public.reactivate_products(bigint[], text) from public, anon;
grant execute on function public.reactivate_products(bigint[], text) to authenticated, service_role;
