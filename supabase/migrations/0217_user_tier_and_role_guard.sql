-- 0217: users change by their 区分 (tier), as they are added (0194):
-- 通常 = floor_staff, 管理者 = warehouse_manager, ADMIN = system_admin.
--
--   * set_user_tier: a user's roles become the tier's one role — the system
--     administrator's to do. Nobody demotes themselves, and the last system
--     administrator stays one.
--   * revoke_user_role: the same two guards, so no one is locked out of
--     user management by taking a role off.
--   * normalize_barcode: its search path fixed (the advisor's warning);
--     it only uses built-ins, so it reads codes as before.

alter function public.normalize_barcode(text) set search_path = '';

create or replace function public.tier_role(p_tier text)
returns text language sql immutable set search_path = '' as $$
  select case p_tier when 'admin' then 'system_admin' when 'manager' then 'warehouse_manager'
                     when 'user' then 'floor_staff' end;
$$;

-- How many system administrators there are.
create or replace function public.system_admin_count()
returns integer language sql stable security definer set search_path = '' as $$
  select count(distinct ur.user_id)::integer
    from public.user_roles ur join public.roles r on r.id = ur.role_id
   where r.code = 'system_admin';
$$;
revoke all on function public.system_admin_count() from public, anon;
grant execute on function public.system_admin_count() to authenticated, service_role;

-- The guards before a role is taken off.
do $$
declare
  v_def text;
  v_new text;
begin
  select pg_get_functiondef('public.revoke_user_role(uuid, text)'::regprocedure) into v_def;
  v_new := replace(v_def,
    $r$  if v_role_id is null then
    raise exception 'unknown role %', p_role_code;
  end if;
$r$,
    $r$  if v_role_id is null then
    raise exception 'unknown role %', p_role_code;
  end if;
  if p_role_code = 'system_admin' and exists (
       select 1 from public.user_roles where user_id = p_user_id and role_id = v_role_id) then
    if p_user_id = auth.uid() then
      raise exception 'user_role_self_admin';
    end if;
    if public.system_admin_count() <= 1 then
      raise exception 'user_role_last_admin';
    end if;
  end if;
$r$);
  if v_new = v_def then
    raise exception 'revoke_user_role: pattern not found';
  end if;
  execute v_new;
end $$;

create or replace function public.set_user_tier(p_user_id uuid, p_tier text)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_role text := public.tier_role(p_tier);
  v_code text;
  v_before text;
begin
  if auth.uid() is null or not public.is_system_admin() then
    raise exception 'not permitted: system_admin required';
  end if;
  if v_role is null then
    raise exception 'user_tier_unknown %', p_tier;
  end if;
  if p_user_id = auth.uid() and p_tier <> 'admin' then
    raise exception 'user_role_self_admin';
  end if;
  select string_agg(r.code, ',' order by r.code) into v_before
    from public.user_roles ur join public.roles r on r.id = ur.role_id where ur.user_id = p_user_id;
  -- The new role first, then the others off: never a moment with none.
  perform public.assign_user_role(p_user_id, v_role);
  for v_code in
    select r.code from public.user_roles ur join public.roles r on r.id = ur.role_id
     where ur.user_id = p_user_id and r.code <> v_role
  loop
    perform public.revoke_user_role(p_user_id, v_code);
  end loop;
  perform public.log_audit('user.tier_set', 'app_user', p_user_id::text, null,
    jsonb_build_object('tier', p_tier, 'role', v_role, 'before', v_before));
  return true;
end;
$$;
revoke all on function public.set_user_tier(uuid, text) from public, anon;
grant execute on function public.set_user_tier(uuid, text) to authenticated;
