-- 0025 — Admin: list users with their roles (Step 3, completing 0024)
--
-- assign_user_role/revoke_user_role (0024) let an admin change a user's
-- roles, but nothing let them see WHO to assign roles to: app_users and
-- user_roles both carry a single RLS policy, "read own row only" — so even
-- an admin querying them directly via PostgREST sees just themselves. This
-- is the read-side companion those writes were missing: a SECURITY DEFINER
-- function returning every user who has ever signed in (i.e. has an
-- app_users row, created by bootstrap_first_admin on first login) together
-- with their current roles, gated by the same permission the writes already
-- require.
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
        ), '[]'::jsonb)
      ) order by u.created_at)
      from public.app_users u),
    '[]'::jsonb);
end;
$$;

revoke all on function public.list_app_users() from public, anon;
grant execute on function public.list_app_users() to authenticated, service_role;
