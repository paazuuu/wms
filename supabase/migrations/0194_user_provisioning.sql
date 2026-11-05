-- 0194: ADMIN adds users from the app (ユーザー管理 → ユーザーを追加).
--
-- The account itself is made by the user-admin edge function with the
-- service role (Supabase Auth's admin API, email confirmed, a temporary
-- password shown once to the ADMIN — no mail is sent). This function then
-- gives it its place here: an app_users row, its roles and the warehouses it
-- works in. Only the service role calls it; the edge function checks first
-- that the caller is an ADMIN (is_app_admin, 0193).

create or replace function public.admin_provision_user(
  p_user_id uuid, p_email text, p_name text, p_roles text[], p_warehouse_ids bigint[] default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_company bigint;
  v_roles text[];
  v_whs bigint[];
begin
  if p_user_id is null then
    raise exception 'user id required';
  end if;
  select id into v_company from public.companies order by id limit 1;
  insert into public.app_users (id, company_id, name, email, status)
  values (p_user_id, v_company, coalesce(nullif(btrim(p_name), ''), split_part(p_email, '@', 1)), p_email, 'active')
  on conflict (id) do update
    set name = coalesce(nullif(btrim(p_name), ''), public.app_users.name), email = excluded.email, status = 'active';

  insert into public.user_roles (user_id, role_id)
  select p_user_id, r.id from public.roles r where r.code = any (coalesce(p_roles, '{}'))
  on conflict do nothing;
  select coalesce(array_agg(r.code order by r.id), '{}') into v_roles
    from public.user_roles ur join public.roles r on r.id = ur.role_id where ur.user_id = p_user_id;

  -- Every warehouse in use unless some were named.
  insert into public.user_warehouses (user_id, warehouse_id)
  select p_user_id, w.id from public.warehouses w
   where w.status = 'active'
     and (p_warehouse_ids is null or cardinality(p_warehouse_ids) = 0 or w.id = any (p_warehouse_ids))
  on conflict do nothing;
  select coalesce(array_agg(warehouse_id order by warehouse_id), '{}') into v_whs
    from public.user_warehouses where user_id = p_user_id;

  perform public.log_audit('user.provisioned', 'app_user', p_user_id::text, null,
    jsonb_build_object('email', p_email, 'roles', v_roles, 'warehouses', v_whs));
  return jsonb_build_object('user_id', p_user_id, 'roles', v_roles, 'warehouses', v_whs);
end;
$$;
revoke all on function public.admin_provision_user(uuid, text, text, text[], bigint[]) from public, anon, authenticated;
grant execute on function public.admin_provision_user(uuid, text, text, text[], bigint[]) to service_role;
