-- Cards managed by whom (0228).
-- * 取引先 / 価格台帳の仕入先カード: made, changed, switched on and off, and
--   erased by the system administrator only (partner_can_manage). Their
--   reading notes and the code numbering stay with partner.manage.
-- * 国外の仮想在庫の出荷先カード: added, changed, put away, made the default
--   and erased by the system administrator and the 管理者 tier
--   (overseas_can_manage). Reading counts in stays with overseas_can_edit.
-- Erasing is the card-erase function's (service role); here is what it asks
-- first: whether the card may go, and what goes with it.

create or replace function public.is_manager_or_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.user_roles ur join public.roles r on r.id = ur.role_id
                  where ur.user_id = auth.uid()
                    and r.code in ('system_admin', 'company_admin', 'warehouse_manager', 'inventory_controller',
                                   'purchasing', 'sales'));
$$;
grant execute on function public.is_manager_or_admin() to authenticated, service_role;
revoke execute on function public.is_manager_or_admin() from public, anon;

create or replace function public.partner_can_manage()
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_system_admin();
$$;
grant execute on function public.partner_can_manage() to authenticated, service_role;
revoke execute on function public.partner_can_manage() from public, anon;

create or replace function public.overseas_can_manage()
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_manager_or_admin();
$$;
grant execute on function public.overseas_can_manage() to authenticated, service_role;
revoke execute on function public.overseas_can_manage() from public, anon;

-- The card functions ask the new checks, each change checked.
do $$
declare
  f text;
  d text;
  n text;
begin
  foreach f in array array[
    'public.create_trading_partner(text,text,text,text,text,text,text,text,text)',
    'public.update_trading_partner(bigint,text,text,text,text,text,text,text,text)',
    'public.set_trading_partner_status(bigint,text)',
    'public.set_trading_partner_country(bigint,text)',
    'public.set_partner_codes(bigint,text,text)'] loop
    d := pg_get_functiondef(f::regprocedure);
    n := replace(d, $q$public.has_permission('partner.manage')$q$, 'public.partner_can_manage()');
    if n = d then raise exception '%: partner.manage not found', f; end if;
    n := replace(n, 'partner.manage required', 'system administrator required');
    execute n;
  end loop;
  foreach f in array array[
    'public.overseas_site_save(jsonb)',
    'public.overseas_site_archive(bigint,boolean)',
    'public.overseas_site_for_card(bigint)'] loop
    d := pg_get_functiondef(f::regprocedure);
    n := replace(d, 'public.overseas_can_edit()', 'public.overseas_can_manage()');
    if n = d then raise exception '%: overseas_can_edit not found', f; end if;
    execute n;
  end loop;
end $$;

-- The default card: one at most, chosen here (or none).
create or replace function public.overseas_site_set_default(p_id bigint, p_default boolean default true)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if not public.overseas_can_manage() then
    raise exception 'not permitted';
  end if;
  if not exists (select 1 from public.overseas_sites where id = p_id) then
    raise exception 'overseas site % not found', p_id;
  end if;
  if p_default then
    update public.overseas_sites set is_default = (id = p_id), updated_at = now()
     where is_default or id = p_id;
  else
    update public.overseas_sites set is_default = false, updated_at = now() where id = p_id;
  end if;
  return true;
end;
$$;
grant execute on function public.overseas_site_set_default(bigint, boolean) to authenticated, service_role;
revoke execute on function public.overseas_site_set_default(bigint, boolean) from public, anon;

-- Before a supplier / partner card is erased: what still uses it (work
-- records: it cannot go while they do), what loses its link to it, and what
-- goes with it.
create or replace function public.partner_erase_check(p_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v public.delivery_suppliers;
  c jsonb;
begin
  if not public.partner_can_manage() then
    raise exception 'not permitted: system administrator required';
  end if;
  select * into v from public.delivery_suppliers where id = p_id;
  if v.id is null then
    raise exception 'partner % not found', p_id;
  end if;
  c := jsonb_build_object(
    'blockers', jsonb_strip_nulls(jsonb_build_object(
      'delivery_plans', nullif((select count(*) from public.delivery_plans where supplier_id = p_id), 0),
      'delivery_reconciliations', nullif((select count(*) from public.delivery_reconciliations where supplier_id = p_id), 0),
      'shipment_plans', nullif((select count(*) from public.shipment_plans where party_id = p_id), 0),
      'purchase_orders', nullif((select count(*) from public.purchase_orders where supplier_id = p_id), 0),
      'sales_orders', nullif((select count(*) from public.sales_orders where customer_id = p_id), 0),
      'lots', nullif((select count(*) from public.lots where supplier_id = p_id), 0),
      'supplier_invoices', nullif((select count(*) from public.supplier_invoices where partner_id = p_id), 0))),
    'detached', jsonb_strip_nulls(jsonb_build_object(
      'master_imports', nullif((select count(*) from public.master_imports where supplier_id = p_id), 0),
      'import_documents', nullif((select count(*) from public.import_documents where supplier_id = p_id), 0),
      'purchase_requests', nullif((select count(*) from public.purchase_requests where supplier_id = p_id), 0),
      'ship_destinations', nullif((select count(*) from public.ship_destinations where party_id = p_id), 0),
      'outbound_file_lines', nullif((select count(*) from public.outbound_file_lines where supplier_id = p_id), 0),
      'warehouse_products', nullif((select count(*) from public.warehouse_products where preferred_supplier_id = p_id), 0))),
    'erased', jsonb_strip_nulls(jsonb_build_object(
      'supplier_product_names', nullif((select count(*) from public.supplier_product_names where supplier_id = p_id), 0),
      'price_book_terms', nullif((select count(*) from public.price_book_terms where partner_id = p_id), 0),
      'purchase_price_entries', nullif((select count(*) from public.purchase_price_entries where supplier_id = p_id), 0),
      'column_aliases', nullif((select count(*) from public.column_aliases where partner_id = p_id), 0),
      'notation_dialects', nullif((select count(*) from public.notation_dialects where partner_id = p_id), 0),
      'partner_vendor_codes', nullif((select count(*) from public.partner_vendor_codes where partner_id = p_id), 0))));
  return jsonb_build_object('id', v.id, 'name', v.name, 'code', v.code,
                            'placeholder', v.code is not distinct from 'UNKNOWN') || c;
end;
$$;
grant execute on function public.partner_erase_check(bigint) to authenticated, service_role;
revoke execute on function public.partner_erase_check(bigint) from public, anon;

-- Before an 国外の仮想在庫 card is erased: its stock counts (and their
-- files), its shipments and its notes (and their files) go with it. The
-- 出荷先カード it summarises stays; a list shipped to it again makes a new one.
create or replace function public.overseas_site_erase_check(p_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v public.overseas_sites;
begin
  if not public.overseas_can_manage() then
    raise exception 'not permitted';
  end if;
  select * into v from public.overseas_sites where id = p_id;
  if v.id is null then
    raise exception 'overseas site % not found', p_id;
  end if;
  return jsonb_build_object(
    'id', v.id, 'name', v.name, 'is_default', v.is_default,
    'import_ids', coalesce((select jsonb_agg(id) from public.overseas_stock_imports where site_id = p_id), '[]'::jsonb),
    'shipment_ids', coalesce((select jsonb_agg(id) from public.overseas_shipments where site_id = p_id), '[]'::jsonb),
    'note_ids', coalesce((select jsonb_agg(id) from public.record_notes
                           where subject_kind = 'overseas_site' and subject_id = p_id), '[]'::jsonb),
    'note_files', coalesce((select jsonb_agg(f.storage_path) from public.record_note_files f
                             join public.record_notes n on n.id = f.note_id
                            where n.subject_kind = 'overseas_site' and n.subject_id = p_id
                              and f.storage_path is not null), '[]'::jsonb));
end;
$$;
grant execute on function public.overseas_site_erase_check(bigint) to authenticated, service_role;
revoke execute on function public.overseas_site_erase_check(bigint) from public, anon;

-- The erasing, on the audit log under the person's name.
create or replace function public.card_erased_note(p_kind text, p_id bigint, p_name text, p_detail jsonb)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if not ((p_kind = 'partner' and public.partner_can_manage())
          or (p_kind = 'overseas_site' and public.overseas_can_manage())) then
    raise exception 'not permitted';
  end if;
  perform public.log_audit(p_kind || '.erase', p_kind, p_id::text, null,
    jsonb_build_object('name', p_name, 'by', public.user_display_name(auth.uid())) || coalesce(p_detail, '{}'::jsonb));
  return true;
end;
$$;
grant execute on function public.card_erased_note(text, bigint, text, jsonb) to authenticated, service_role;
revoke execute on function public.card_erased_note(text, bigint, text, jsonb) from public, anon;
