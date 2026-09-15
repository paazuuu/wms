-- 0043 — Enforce audit.view on the audit-log read RPCs
--
-- Found while auditing the edge functions for the same missing-permission
-- pattern as stock-ops (see docs/migration_plan.md): audit_log_query,
-- audit_log_for_entity, and audit_event_types are SECURITY DEFINER
-- functions with no has_permission() check at all, and were additionally
-- granted to `anon` — so any signed-in user, and in fact any unauthenticated
-- caller with only the anon key, could read the entire audit trail
-- (including actor names/emails) regardless of the audit.view permission
-- that 0012's RLS policy on audit_log itself already requires. RLS never
-- runs for these calls: SECURITY DEFINER executes as the function owner,
-- bypassing the table's own policy entirely, which is exactly why every
-- other read RPC in this app (list_ai_analysis, list_app_users, ...)
-- re-checks has_permission() itself rather than relying on the table.
--
-- Revoking the anon grant matters on its own: has_permission() treats a
-- null auth.uid() as "allow" (by design, for trusted server-side calls with
-- no user context at all — see supabase/functions/_shared/require_permission.ts),
-- and an anon-key call has a null auth.uid() same as a trusted server call
-- does. Adding the has_permission() check alone would not have closed the
-- anon hole; only revoking anon's execute grant does, matching the grant
-- shape every other read RPC in this app already uses.
create or replace function public.audit_log_query(
  p_warehouse_id bigint default null,
  p_entity_type text default null,
  p_event_type text default null,
  p_since timestamptz default null,
  p_until timestamptz default null,
  p_limit int default 100
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('audit.view') then
    raise exception 'not permitted: audit.view required';
  end if;

  return coalesce(
    (select jsonb_agg(row_to_json(t) order by t.created_at desc, t.id desc)
       from (
         select a.id, a.created_at, a.warehouse_id, w.name as warehouse_name,
                a.actor_user_id, u.name as actor_name, u.email as actor_email,
                a.event_type, a.entity_type, a.entity_id, a.details
           from public.audit_log a
           left join public.warehouses w on w.id = a.warehouse_id
           left join public.app_users u on u.id = a.actor_user_id
          where (p_warehouse_id is null or a.warehouse_id = p_warehouse_id)
            and (p_entity_type is null or a.entity_type = p_entity_type)
            and (p_event_type is null or a.event_type = p_event_type)
            and (p_since is null or a.created_at >= p_since)
            and (p_until is null or a.created_at <= p_until)
          order by a.created_at desc, a.id desc
          limit greatest(coalesce(p_limit, 100), 1)
       ) t),
    '[]'::jsonb);
end;
$$;

revoke all on function public.audit_log_query(bigint, text, text, timestamptz, timestamptz, int) from public, anon;
grant execute on function public.audit_log_query(bigint, text, text, timestamptz, timestamptz, int) to authenticated, service_role;

create or replace function public.audit_log_for_entity(
  p_entity_type text,
  p_entity_id text,
  p_limit int default 50
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('audit.view') then
    raise exception 'not permitted: audit.view required';
  end if;

  return coalesce(
    (select jsonb_agg(row_to_json(t) order by t.created_at desc, t.id desc)
       from (
         select a.id, a.created_at, a.warehouse_id, w.name as warehouse_name,
                a.actor_user_id, u.name as actor_name, u.email as actor_email,
                a.event_type, a.entity_type, a.entity_id, a.details
           from public.audit_log a
           left join public.warehouses w on w.id = a.warehouse_id
           left join public.app_users u on u.id = a.actor_user_id
          where a.entity_type = p_entity_type
            and a.entity_id = p_entity_id
          order by a.created_at desc, a.id desc
          limit greatest(coalesce(p_limit, 50), 1)
       ) t),
    '[]'::jsonb);
end;
$$;

revoke all on function public.audit_log_for_entity(text, text, int) from public, anon;
grant execute on function public.audit_log_for_entity(text, text, int) to authenticated, service_role;

create or replace function public.audit_event_types()
returns text[]
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('audit.view') then
    raise exception 'not permitted: audit.view required';
  end if;

  return coalesce(
    (select array_agg(distinct event_type order by event_type) from public.audit_log),
    array[]::text[]);
end;
$$;

revoke all on function public.audit_event_types() from public, anon;
grant execute on function public.audit_event_types() to authenticated, service_role;
