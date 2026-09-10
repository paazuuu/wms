-- 0024 — Auth bootstrap (spec Step 3 continued, §21/§22)
--
-- Closes the transitional gate 0012 documented: every permission check has
-- been running as `auth.uid() is null → true` because nothing ever signed
-- in through real Supabase Auth. The mobile app's login screen instead
-- called a separate, now-dead InventorOS server — a different identity
-- system that never touched `auth.uid()` at all, so RBAC/self-approval never
-- actually engaged even when someone was "logged in" there.
--
-- Chosen (asked explicitly): Supabase Auth replaces that InventorOS login
-- entirely; accounts are admin-created (no public sign-up), starting with
-- whoever signs in first.
--
-- The chicken-and-egg problem: once auth.uid() is non-null, has_permission()
-- requires a matching user_roles row — with none seeded yet, the very first
-- real login would be locked out of everything. bootstrap_first_admin()
-- solves this the standard way: if no admin has ever been assigned
-- (user_roles is genuinely empty — true today, nothing has signed in yet),
-- whoever calls this first becomes System Admin. Every later account still
-- needs an existing admin to assign it a role — see assign_user_role below.

create or replace function public.bootstrap_first_admin()
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid       uuid := auth.uid();
  v_email     text;
  v_company   bigint;
  v_admin_role bigint;
  v_became_admin boolean := false;
begin
  if v_uid is null then
    raise exception 'bootstrap_first_admin requires a signed-in user';
  end if;

  select email into v_email from auth.users where id = v_uid;
  select id into v_company from public.companies order by id limit 1;
  select id into v_admin_role from public.roles where code = 'system_admin';

  -- Ensure an app_users row exists for this person regardless of whether
  -- they end up admin — every authenticated user needs one to hold any role.
  insert into public.app_users (id, company_id, name, email, status)
  values (v_uid, v_company, coalesce(split_part(v_email, '@', 1), 'user'), v_email, 'active')
  on conflict (id) do nothing;

  if not exists (select 1 from public.user_roles) then
    insert into public.user_roles (user_id, role_id)
    values (v_uid, v_admin_role)
    on conflict do nothing;
    v_became_admin := true;
  end if;

  return jsonb_build_object(
    'user_id', v_uid,
    'became_admin', v_became_admin,
    'has_any_role', exists (select 1 from public.user_roles where user_id = v_uid));
end;
$$;

-- An existing admin assigns a role to an already-signed-in user (spec §21:
-- "権限は画面が見える だけではなく、API側でも強制する" — enforced here via
-- has_permission itself, not just checked client-side). p_user_id must
-- already have an app_users row, i.e. have signed in at least once.
create or replace function public.assign_user_role(
  p_user_id uuid,
  p_role_code text
) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_role_id bigint;
begin
  if not public.has_permission('user.manage') then
    raise exception 'not permitted: user.manage required';
  end if;
  if not exists (select 1 from public.app_users where id = p_user_id) then
    raise exception 'user % has not signed in yet', p_user_id;
  end if;

  select id into v_role_id from public.roles where code = p_role_code;
  if v_role_id is null then
    raise exception 'unknown role %', p_role_code;
  end if;

  insert into public.user_roles (user_id, role_id)
  values (p_user_id, v_role_id)
  on conflict do nothing;

  perform public.log_audit(
    'user.role_assigned', 'app_user', p_user_id::text, null,
    jsonb_build_object('role', p_role_code));

  return true;
end;
$$;

create or replace function public.revoke_user_role(
  p_user_id uuid,
  p_role_code text
) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_role_id bigint;
begin
  if not public.has_permission('user.manage') then
    raise exception 'not permitted: user.manage required';
  end if;

  select id into v_role_id from public.roles where code = p_role_code;
  if v_role_id is null then
    raise exception 'unknown role %', p_role_code;
  end if;

  delete from public.user_roles where user_id = p_user_id and role_id = v_role_id;

  perform public.log_audit(
    'user.role_revoked', 'app_user', p_user_id::text, null,
    jsonb_build_object('role', p_role_code));

  return true;
end;
$$;

-- What roles this signed-in user actually holds, for the client to show
-- ("you are: Warehouse Manager") without needing its own permissions table.
create or replace function public.my_roles()
returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('code', r.code, 'name', r.name) order by r.id), '[]'::jsonb)
    from public.user_roles ur
    join public.roles r on r.id = ur.role_id
   where ur.user_id = auth.uid();
$$;

revoke all on function public.bootstrap_first_admin() from public, anon;
revoke all on function public.assign_user_role(uuid, text) from public, anon;
revoke all on function public.revoke_user_role(uuid, text) from public, anon;

grant execute on function public.bootstrap_first_admin() to authenticated, service_role;
grant execute on function public.assign_user_role(uuid, text) to authenticated, service_role;
grant execute on function public.revoke_user_role(uuid, text) to authenticated, service_role;
grant execute on function public.my_roles() to authenticated, service_role;
