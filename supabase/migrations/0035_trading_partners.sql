-- 0035 — Supplier/customer CRM (spec §46 checklist item 8)
--
-- "Full supplier management (CRUD, contacts, terms)" and "Customer
-- management" were two separate checklist gaps, but this project already
-- has one table serving both roles: `delivery_suppliers` is referenced by
-- `delivery_plans.supplier_id` (inbound) *and* `shipment_plans.party_id`
-- (outbound) — a generic trading-partner reference in practice, just named
-- for its original inbound-only use. domain_model.md §2 already called for
-- "reconcile the current delivery_suppliers into a general supplier
-- master... keep delivery references working" — this does exactly that,
-- additively (new columns only), rather than introducing a second,
-- redundant `customers` table that would fork the two existing FKs apart.
--
-- `kind` lets a row be a supplier, a customer, or both (a single real-world
-- company can be either) — existing rows default to 'supplier' since that
-- was every one of them's only prior use.
alter table public.delivery_suppliers
  add column if not exists kind text not null default 'supplier'
    check (kind in ('supplier', 'customer', 'both')),
  add column if not exists contact_name text,
  add column if not exists phone text,
  add column if not exists email text,
  add column if not exists address text,
  add column if not exists payment_terms text,
  add column if not exists notes text,
  add column if not exists status text not null default 'active'
    check (status in ('active', 'inactive')),
  add column if not exists updated_at timestamptz not null default now();

insert into public.permissions (code, description)
values
  ('partner.view', 'View the supplier/customer directory'),
  ('partner.manage', 'Create, edit and (de)activate suppliers and customers');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
  from public.roles r, public.permissions p
 where p.code = 'partner.view'
   and r.code in ('system_admin', 'company_admin', 'warehouse_manager',
                   'inventory_controller', 'receiving', 'shipper', 'viewer');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
  from public.roles r, public.permissions p
 where p.code = 'partner.manage'
   and r.code in ('system_admin', 'company_admin', 'warehouse_manager',
                   'inventory_controller');

-- The existing "read suppliers" policy (0003, `using (true)`) stays as-is —
-- delivery-note import and shipment lookups still need it unconditionally.
-- The new CRUD surface (this migration) gates itself with `partner.view`/
-- `partner.manage` inside the RPCs below instead of tightening that policy,
-- so nothing that already reads `delivery_suppliers` breaks.

create or replace function public.list_trading_partners(
  p_kind text default null,
  p_search text default null,
  p_status text default 'active'
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('partner.view') then
    raise exception 'not permitted: partner.view required';
  end if;

  return coalesce(
    (select jsonb_agg(jsonb_build_object(
        'id', s.id, 'code', s.code, 'name', s.name, 'kind', s.kind,
        'contact_name', s.contact_name, 'phone', s.phone, 'email', s.email,
        'address', s.address, 'payment_terms', s.payment_terms, 'notes', s.notes,
        'status', s.status, 'created_at', s.created_at, 'updated_at', s.updated_at
      ) order by s.name)
      from public.delivery_suppliers s
     where (p_status is null or s.status = p_status)
       and (p_kind is null or s.kind = p_kind or s.kind = 'both')
       and (p_search is null or p_search = '' or
            s.name ilike '%' || p_search || '%' or
            coalesce(s.code, '') ilike '%' || p_search || '%')),
    '[]'::jsonb);
end;
$$;

create or replace function public.create_trading_partner(
  p_name text,
  p_kind text default 'supplier',
  p_code text default null,
  p_contact_name text default null,
  p_phone text default null,
  p_email text default null,
  p_address text default null,
  p_payment_terms text default null,
  p_notes text default null
) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
begin
  if not public.has_permission('partner.manage') then
    raise exception 'not permitted: partner.manage required';
  end if;
  if p_name is null or p_name = '' then
    raise exception 'name is required';
  end if;
  if p_kind not in ('supplier', 'customer', 'both') then
    raise exception 'invalid kind %', p_kind;
  end if;

  insert into public.delivery_suppliers (
    name, kind, code, contact_name, phone, email, address, payment_terms, notes)
  values (
    p_name, p_kind, nullif(p_code, ''), p_contact_name, p_phone, p_email,
    p_address, p_payment_terms, p_notes)
  returning id into v_id;

  perform public.log_audit('partner.created', 'trading_partner', v_id::text, null,
    jsonb_build_object('name', p_name, 'kind', p_kind));

  return v_id;
end;
$$;

create or replace function public.update_trading_partner(
  p_id bigint,
  p_name text,
  p_kind text default 'supplier',
  p_contact_name text default null,
  p_phone text default null,
  p_email text default null,
  p_address text default null,
  p_payment_terms text default null,
  p_notes text default null
) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_permission('partner.manage') then
    raise exception 'not permitted: partner.manage required';
  end if;
  if p_name is null or p_name = '' then
    raise exception 'name is required';
  end if;
  if p_kind not in ('supplier', 'customer', 'both') then
    raise exception 'invalid kind %', p_kind;
  end if;

  update public.delivery_suppliers
     set name = p_name, kind = p_kind, contact_name = p_contact_name,
         phone = p_phone, email = p_email, address = p_address,
         payment_terms = p_payment_terms, notes = p_notes, updated_at = now()
   where id = p_id;

  if not found then
    raise exception 'trading partner % not found', p_id;
  end if;

  perform public.log_audit('partner.updated', 'trading_partner', p_id::text, null,
    jsonb_build_object('name', p_name, 'kind', p_kind));

  return true;
end;
$$;

create or replace function public.set_trading_partner_status(
  p_id bigint,
  p_status text
) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_permission('partner.manage') then
    raise exception 'not permitted: partner.manage required';
  end if;
  if p_status not in ('active', 'inactive') then
    raise exception 'invalid status %', p_status;
  end if;

  update public.delivery_suppliers
     set status = p_status, updated_at = now()
   where id = p_id;

  if not found then
    raise exception 'trading partner % not found', p_id;
  end if;

  perform public.log_audit(
    case when p_status = 'active' then 'partner.activated' else 'partner.deactivated' end,
    'trading_partner', p_id::text, null, '{}'::jsonb);

  return true;
end;
$$;

revoke all on function public.list_trading_partners(text, text, text) from public, anon;
revoke all on function public.create_trading_partner(text, text, text, text, text, text, text, text, text) from public, anon;
revoke all on function public.update_trading_partner(bigint, text, text, text, text, text, text, text, text) from public, anon;
revoke all on function public.set_trading_partner_status(bigint, text) from public, anon;

grant execute on function public.list_trading_partners(text, text, text) to authenticated, service_role;
grant execute on function public.create_trading_partner(text, text, text, text, text, text, text, text, text) to authenticated, service_role;
grant execute on function public.update_trading_partner(bigint, text, text, text, text, text, text, text, text) to authenticated, service_role;
grant execute on function public.set_trading_partner_status(bigint, text) to authenticated, service_role;
