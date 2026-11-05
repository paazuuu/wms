-- 0193: 表示設定 — which menus each kind of user sees.
--
-- Three kinds of user, from the roles they hold:
--   admin   (ADMIN)          system_admin, company_admin — sees everything;
--   manager (管理者ユーザー)  warehouse_manager, inventory_controller,
--                             purchasing, sales;
--   user    (通常ユーザー)    everyone else — the warehouse floor.
-- What a manager or a user sees is set here per menu entry (the app keeps
-- the defaults: a user the floor's work only). Only an ADMIN changes it.
-- This decides what is offered, not what is allowed: every RPC still checks
-- its own permission.

create or replace function public.is_app_admin()
returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.user_roles ur
      join public.roles r on r.id = ur.role_id
     where ur.user_id = auth.uid() and r.code in ('system_admin', 'company_admin'));
$$;
revoke all on function public.is_app_admin() from public, anon;
grant execute on function public.is_app_admin() to authenticated;

create table if not exists public.menu_visibility (
  feature_id text not null,
  tier text not null check (tier in ('manager', 'user')),
  visible boolean not null,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  primary key (feature_id, tier)
);
alter table public.menu_visibility enable row level security;

-- Every setting made: [{feature_id, tier, visible}].
create or replace function public.menu_visibility_list()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'sign in required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('feature_id', feature_id, 'tier', tier, 'visible', visible)
                     order by feature_id, tier)
      from public.menu_visibility), '[]'::jsonb);
end;
$$;
revoke all on function public.menu_visibility_list() from public, anon;
grant execute on function public.menu_visibility_list() to authenticated;

-- [p_rows]: [{feature_id, tier, visible}], written over what was there.
create or replace function public.menu_visibility_save(p_rows jsonb)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_row jsonb;
  v_n integer := 0;
begin
  if auth.uid() is null or not public.is_app_admin() then
    raise exception 'not permitted: ADMIN only';
  end if;
  for v_row in select * from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb)) loop
    if coalesce(btrim(v_row->>'feature_id'), '') = '' or (v_row->>'tier') not in ('manager', 'user') then
      continue;
    end if;
    insert into public.menu_visibility (feature_id, tier, visible, updated_at, updated_by)
    values (btrim(v_row->>'feature_id'), v_row->>'tier', coalesce((v_row->>'visible')::boolean, false), now(), auth.uid())
    on conflict (feature_id, tier) do update
      set visible = excluded.visible, updated_at = now(), updated_by = auth.uid();
    v_n := v_n + 1;
  end loop;
  perform public.log_audit('menu.visibility_saved', 'menu_visibility', null, null, jsonb_build_object('rows', v_n));
  return v_n;
end;
$$;
revoke all on function public.menu_visibility_save(jsonb) from public, anon;
grant execute on function public.menu_visibility_save(jsonb) to authenticated;
