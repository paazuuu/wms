-- 0029 — Per-user warehouse scope management (spec §22, completing 0012/0024)
--
-- can_access_warehouse() (0012) has checked `user_warehouses` since real
-- sign-in went live, but nothing ever wrote to that table — there was no way
-- for an admin to actually restrict a non-admin user to specific warehouses.
-- assign_user_role/revoke_user_role (0024) covers roles; this is the same
-- pattern for warehouse scope.
create or replace function public.assign_user_warehouse(
  p_user_id uuid,
  p_warehouse_id bigint
) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_permission('user.manage') then
    raise exception 'not permitted: user.manage required';
  end if;
  if not exists (select 1 from public.app_users where id = p_user_id) then
    raise exception 'user % has not signed in yet', p_user_id;
  end if;
  if not exists (select 1 from public.warehouses where id = p_warehouse_id) then
    raise exception 'unknown warehouse %', p_warehouse_id;
  end if;

  insert into public.user_warehouses (user_id, warehouse_id)
  values (p_user_id, p_warehouse_id)
  on conflict do nothing;

  perform public.log_audit(
    'user.warehouse_assigned', 'app_user', p_user_id::text, p_warehouse_id, '{}'::jsonb);

  return true;
end;
$$;

create or replace function public.revoke_user_warehouse(
  p_user_id uuid,
  p_warehouse_id bigint
) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_permission('user.manage') then
    raise exception 'not permitted: user.manage required';
  end if;

  delete from public.user_warehouses
   where user_id = p_user_id and warehouse_id = p_warehouse_id;

  perform public.log_audit(
    'user.warehouse_revoked', 'app_user', p_user_id::text, p_warehouse_id, '{}'::jsonb);

  return true;
end;
$$;

-- Extends list_app_users' (0025) output with each user's warehouse_ids —
-- additive (a new jsonb key), not a signature change, so the existing
-- Flutter parser (which reads only what it knows about) keeps working
-- unchanged against the old shape too.
create or replace function public.list_app_users()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('user.manage') then
    raise exception 'not permitted: user.manage required';
  end if;

  return coalesce(
    (select jsonb_agg(jsonb_build_object(
        'id', u.id,
        'name', u.name,
        'email', u.email,
        'status', u.status,
        'created_at', u.created_at,
        'roles', coalesce((
          select jsonb_agg(jsonb_build_object('code', r.code, 'name', r.name) order by r.id)
            from public.user_roles ur
            join public.roles r on r.id = ur.role_id
           where ur.user_id = u.id
        ), '[]'::jsonb),
        'warehouse_ids', coalesce((
          select jsonb_agg(uw.warehouse_id order by uw.warehouse_id)
            from public.user_warehouses uw
           where uw.user_id = u.id
        ), '[]'::jsonb)
      ) order by u.created_at)
      from public.app_users u),
    '[]'::jsonb);
end;
$$;

revoke all on function public.assign_user_warehouse(uuid, bigint) from public, anon;
revoke all on function public.revoke_user_warehouse(uuid, bigint) from public, anon;
grant execute on function public.assign_user_warehouse(uuid, bigint) to authenticated, service_role;
grant execute on function public.revoke_user_warehouse(uuid, bigint) to authenticated, service_role;
