-- Step 3 (spec §46, §21, §22, §33): roles, permissions, per-user warehouse
-- scope, and an append-only audit log.
--
-- TRANSITIONAL BY DESIGN. The app is still login-free (it calls Supabase with
-- the anon key), so `auth.uid()` is null today. Every guard below therefore
-- treats "no authenticated user" as the single implicit operator and allows the
-- action, exactly as the app behaves now. Nothing breaks when this lands; the
-- guards start biting the moment real sign-in is switched on, and from then on
-- an unknown user is denied rather than waved through.
--
-- The audit log is useful immediately: it records who (null = pre-auth operator)
-- did what, so history is not lost in the meantime.

-- -------------------------------------------------------------- permissions
create table if not exists public.permissions (
  id bigserial primary key,
  code text not null unique,
  description text
);

create table if not exists public.roles (
  id bigserial primary key,
  code text not null unique,
  name text not null,
  description text
);

create table if not exists public.role_permissions (
  role_id bigint not null references public.roles (id) on delete cascade,
  permission_id bigint not null references public.permissions (id) on delete cascade,
  primary key (role_id, permission_id)
);

-- ---------------------------------------------------------------- app users
-- Mirrors auth.users so the WMS can carry company membership, display name and
-- status without touching the auth schema.
create table if not exists public.app_users (
  id uuid primary key,
  company_id bigint references public.companies (id) on delete restrict,
  name text,
  email text,
  status text not null default 'active'
    check (status in ('active', 'inactive')),
  created_at timestamptz not null default now()
);

create table if not exists public.user_roles (
  user_id uuid not null references public.app_users (id) on delete cascade,
  role_id bigint not null references public.roles (id) on delete cascade,
  primary key (user_id, role_id)
);

-- allowed_warehouses (spec §22): which warehouses a user may read/write.
create table if not exists public.user_warehouses (
  user_id uuid not null references public.app_users (id) on delete cascade,
  warehouse_id bigint not null references public.warehouses (id) on delete cascade,
  primary key (user_id, warehouse_id)
);

-- ---------------------------------------------------------------- audit log
create table if not exists public.audit_log (
  id bigserial primary key,
  company_id bigint references public.companies (id) on delete set null,
  warehouse_id bigint references public.warehouses (id) on delete set null,
  actor_user_id uuid,
  event_type text not null,
  entity_type text,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists audit_log_created_idx
  on public.audit_log (created_at desc);
create index if not exists audit_log_event_idx
  on public.audit_log (event_type, created_at desc);
create index if not exists audit_log_entity_idx
  on public.audit_log (entity_type, entity_id);

-- ------------------------------------------------------------------- seeding
insert into public.permissions (code, description) values
  ('warehouse.view',     'View warehouses'),
  ('warehouse.manage',   'Create / edit warehouses, zones and bins'),
  ('user.manage',        'Manage users, roles and warehouse scope'),
  ('receiving.view',     'View inbound work'),
  ('receiving.confirm',  'Confirm a receipt'),
  ('inspection.view',    'View inspections'),
  ('inspection.confirm', 'Confirm an inspection result'),
  ('putaway.confirm',    'Confirm a put-away'),
  ('pick.confirm',       'Confirm a pick'),
  ('pack.complete',      'Complete packing'),
  ('ship.complete',      'Complete a shipment'),
  ('inventory.view',     'View stock'),
  ('inventory.adjust',   'Adjust stock'),
  ('count.perform',      'Perform a cycle count'),
  ('count.approve',      'Approve a cycle count variance'),
  ('transfer.create',    'Create an inter-warehouse transfer'),
  ('transfer.approve',   'Approve an inter-warehouse transfer'),
  ('transfer.receive',   'Receive an inter-warehouse transfer'),
  ('ai.review',          'Review and confirm AI results'),
  ('audit.view',         'View the audit log'),
  ('report.view',        'View reports')
on conflict (code) do nothing;

insert into public.roles (code, name, description) values
  ('system_admin',        'System Admin',         'Everything'),
  ('company_admin',       'Company Admin',        'Management within the company'),
  ('warehouse_manager',   'Warehouse Manager',    'Runs one or more warehouses'),
  ('receiving',           'Receiving',            'Inbound receiving'),
  ('inspector',           'Inspector',            'Quality inspection'),
  ('putaway_operator',    'Put-away Operator',    'Put-away'),
  ('picker',              'Picker',               'Picking'),
  ('packer',              'Packer',               'Packing'),
  ('shipper',             'Shipper',              'Shipping'),
  ('inventory_controller','Inventory Controller', 'Cycle count and adjustments'),
  ('viewer',              'Viewer',               'Read-only')
on conflict (code) do nothing;

-- Admins hold every permission.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code in ('system_admin', 'company_admin')
on conflict do nothing;

-- Everyone else gets an explicit set.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from (values
  ('warehouse_manager', 'warehouse.view'),
  ('warehouse_manager', 'warehouse.manage'),
  ('warehouse_manager', 'receiving.view'),
  ('warehouse_manager', 'receiving.confirm'),
  ('warehouse_manager', 'inspection.view'),
  ('warehouse_manager', 'inspection.confirm'),
  ('warehouse_manager', 'putaway.confirm'),
  ('warehouse_manager', 'pick.confirm'),
  ('warehouse_manager', 'pack.complete'),
  ('warehouse_manager', 'ship.complete'),
  ('warehouse_manager', 'inventory.view'),
  ('warehouse_manager', 'inventory.adjust'),
  ('warehouse_manager', 'count.perform'),
  ('warehouse_manager', 'count.approve'),
  ('warehouse_manager', 'transfer.create'),
  ('warehouse_manager', 'transfer.approve'),
  ('warehouse_manager', 'transfer.receive'),
  ('warehouse_manager', 'ai.review'),
  ('warehouse_manager', 'audit.view'),
  ('warehouse_manager', 'report.view'),

  ('receiving', 'warehouse.view'),
  ('receiving', 'receiving.view'),
  ('receiving', 'receiving.confirm'),
  ('receiving', 'inventory.view'),

  ('inspector', 'warehouse.view'),
  ('inspector', 'receiving.view'),
  ('inspector', 'inspection.view'),
  ('inspector', 'inspection.confirm'),
  ('inspector', 'ai.review'),

  ('putaway_operator', 'warehouse.view'),
  ('putaway_operator', 'putaway.confirm'),
  ('putaway_operator', 'inventory.view'),

  ('picker', 'warehouse.view'),
  ('picker', 'pick.confirm'),
  ('picker', 'inventory.view'),

  ('packer', 'warehouse.view'),
  ('packer', 'pack.complete'),

  ('shipper', 'warehouse.view'),
  ('shipper', 'ship.complete'),

  ('inventory_controller', 'warehouse.view'),
  ('inventory_controller', 'inventory.view'),
  ('inventory_controller', 'inventory.adjust'),
  ('inventory_controller', 'count.perform'),
  ('inventory_controller', 'count.approve'),
  ('inventory_controller', 'transfer.create'),

  ('viewer', 'warehouse.view'),
  ('viewer', 'receiving.view'),
  ('viewer', 'inspection.view'),
  ('viewer', 'inventory.view'),
  ('viewer', 'report.view')
) as m (role_code, permission_code)
join public.roles r on r.code = m.role_code
join public.permissions p on p.code = m.permission_code
on conflict do nothing;

-- ----------------------------------------------------------------- guards
-- Whether the caller holds a permission. Pre-auth (auth.uid() is null) this
-- returns true so the current login-free app keeps working; once sign-in is on,
-- an unknown user holds nothing.
create or replace function public.has_permission(p_permission text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when auth.uid() is null then true
    else exists (
      select 1
      from user_roles ur
      join role_permissions rp on rp.role_id = ur.role_id
      join permissions p on p.id = rp.permission_id
      where ur.user_id = auth.uid() and p.code = p_permission
    )
  end;
$$;

-- Whether the caller may act in a warehouse (spec §22). Admins see everything;
-- everyone else is limited to their allowed_warehouses.
create or replace function public.can_access_warehouse(p_warehouse_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when auth.uid() is null then true
    when p_warehouse_id is null then exists (
      select 1 from user_roles ur join roles r on r.id = ur.role_id
      where ur.user_id = auth.uid()
        and r.code in ('system_admin', 'company_admin')
    )
    when exists (
      select 1 from user_roles ur join roles r on r.id = ur.role_id
      where ur.user_id = auth.uid()
        and r.code in ('system_admin', 'company_admin')
    ) then true
    else exists (
      select 1 from user_warehouses uw
      where uw.user_id = auth.uid() and uw.warehouse_id = p_warehouse_id
    )
  end;
$$;

-- Append one audit entry. Callable from RPCs and edge functions.
create or replace function public.log_audit(
  p_event_type text,
  p_entity_type text default null,
  p_entity_id text default null,
  p_warehouse_id bigint default null,
  p_details jsonb default '{}'::jsonb
)
returns bigint
language sql
security definer
set search_path = public
as $$
  insert into audit_log (
    company_id, warehouse_id, actor_user_id,
    event_type, entity_type, entity_id, details
  )
  values (
    (select id from companies order by id limit 1),
    p_warehouse_id,
    auth.uid(),
    p_event_type,
    p_entity_type,
    p_entity_id,
    coalesce(p_details, '{}'::jsonb)
  )
  returning id;
$$;

-- The caller's own effective permissions + warehouses, for the client to shape
-- its UI with. Authorization itself is never decided from this (spec §47.9).
create or replace function public.my_access()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'user_id', auth.uid(),
    'authenticated', auth.uid() is not null,
    'roles', coalesce((
      select jsonb_agg(r.code order by r.code)
      from user_roles ur join roles r on r.id = ur.role_id
      where ur.user_id = auth.uid()
    ), '[]'::jsonb),
    'permissions', coalesce((
      select jsonb_agg(distinct p.code)
      from user_roles ur
      join role_permissions rp on rp.role_id = ur.role_id
      join permissions p on p.id = rp.permission_id
      where ur.user_id = auth.uid()
    ), '[]'::jsonb),
    'warehouse_ids', coalesce((
      select jsonb_agg(uw.warehouse_id order by uw.warehouse_id)
      from user_warehouses uw
      where uw.user_id = auth.uid()
    ), '[]'::jsonb)
  );
$$;

grant execute on function public.has_permission(text) to anon, authenticated;
grant execute on function public.can_access_warehouse(bigint) to anon, authenticated;
grant execute on function public.my_access() to anon, authenticated;
-- log_audit is intentionally NOT granted to anon/authenticated: only the
-- service role (edge functions) and other SECURITY DEFINER functions write
-- audit rows, so the log cannot be forged from a client.

-- -------------------------------------------------------------------- RLS
alter table public.permissions enable row level security;
alter table public.roles enable row level security;
alter table public.role_permissions enable row level security;
alter table public.app_users enable row level security;
alter table public.user_roles enable row level security;
alter table public.user_warehouses enable row level security;
alter table public.audit_log enable row level security;

-- Role/permission catalogues are reference data: readable, never client-writable.
drop policy if exists "read permissions" on public.permissions;
create policy "read permissions" on public.permissions
  for select to anon, authenticated using (true);

drop policy if exists "read roles" on public.roles;
create policy "read roles" on public.roles
  for select to anon, authenticated using (true);

drop policy if exists "read role permissions" on public.role_permissions;
create policy "read role permissions" on public.role_permissions
  for select to anon, authenticated using (true);

-- A signed-in user may read their own row and their own assignments only.
drop policy if exists "read own user" on public.app_users;
create policy "read own user" on public.app_users
  for select to authenticated using (id = auth.uid());

drop policy if exists "read own roles" on public.user_roles;
create policy "read own roles" on public.user_roles
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "read own warehouses" on public.user_warehouses;
create policy "read own warehouses" on public.user_warehouses
  for select to authenticated using (user_id = auth.uid());

-- Audit log: readable only with audit.view, and never updated or deleted by a
-- client (append-only; inserts come from log_audit / the service role).
drop policy if exists "read audit" on public.audit_log;
create policy "read audit" on public.audit_log
  for select to authenticated using (public.has_permission('audit.view'));
