-- 0040 — Audit trail: who, not just a UUID (UI spec §29)
--
-- §29's whole ask is "誰が・いつ・何をしたか表示する" (show who, when, what).
-- `audit_log.actor_user_id` has been a bare uuid since 0012; both read RPCs
-- (`audit_log_query` 0020, `audit_log_for_entity` 0023) already select it but
-- nothing resolves it to a name, so every screen showing "who" was really
-- showing a UUID. `app_users` (0012) already mirrors `auth.users`' name/email
-- for exactly this — a left join, no new table, no touch to `auth.users`
-- itself.
--
-- A null actor stays null (some RPCs — bootstrap, cron-driven work, an
-- unauthenticated internal call — log with no actor on purpose); the client
-- already renders that as "system", not as a name.

create or replace function public.audit_log_query(
  p_warehouse_id bigint default null,
  p_entity_type text default null,
  p_event_type text default null,
  p_since timestamptz default null,
  p_until timestamptz default null,
  p_limit integer default 100
) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(row_to_json(t) order by t.created_at desc, t.id desc), '[]'::jsonb)
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
  ) t;
$$;

create or replace function public.audit_log_for_entity(
  p_entity_type text,
  p_entity_id text,
  p_limit integer default 50
) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(row_to_json(t) order by t.created_at desc, t.id desc), '[]'::jsonb)
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
  ) t;
$$;

-- Signatures are unchanged, so the existing grants already cover these —
-- re-stated for clarity, not because anything actually changed.
grant execute on function public.audit_log_query(bigint, text, text, timestamptz, timestamptz, integer)
  to anon, authenticated, service_role;
grant execute on function public.audit_log_for_entity(text, text, integer)
  to anon, authenticated, service_role;
