-- §37 warehouse scope for the audit trail.
--
-- `audit_log` has a row policy, but it reads `has_permission('audit.view')`
-- and nothing about warehouses — and it never applied anyway, because both
-- reader RPCs are SECURITY DEFINER and so run past RLS as their owner. So
-- until now anyone holding `audit.view` could read every warehouse's audit
-- entries, including the actor's name and email and the `details` payload of
-- every operation. That is the most revealing read in the system, and it was
-- the least scoped.
--
-- Fixed where it belongs: in the two RPCs. An edge function cannot gate a
-- list row by row, and these are the only two ways the trail is read.
--
-- `can_access_warehouse(a.warehouse_id)` is exactly the rule wanted, because
-- of the order of its branches: an admin short-circuits to true before the
-- null check, so admins keep seeing entries with no warehouse (global events
-- such as a role change), while a scoped operator gets false for those and
-- sees only their own warehouses' entries.
--
-- Bodies are otherwise unchanged from what `pg_get_functiondef` returned
-- before this migration; the only difference is the added predicate and, in
-- audit_event_types, the WHERE clause that did not exist.

create or replace function public.audit_log_query(
  p_warehouse_id bigint default null,
  p_entity_type text default null,
  p_event_type text default null,
  p_since timestamptz default null,
  p_until timestamptz default null,
  p_limit integer default 100
) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
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
          where public.can_access_warehouse(a.warehouse_id)
            and (p_warehouse_id is null or a.warehouse_id = p_warehouse_id)
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

-- The picker for the event-type filter: listing a type that only ever occurred
-- in another warehouse tells the operator it happened, so scope it the same
-- way rather than leaving a narrow side channel open.
create or replace function public.audit_event_types()
returns text[]
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.has_permission('audit.view') then
    raise exception 'not permitted: audit.view required';
  end if;

  return coalesce(
    (select array_agg(distinct event_type order by event_type)
       from public.audit_log a
      where public.can_access_warehouse(a.warehouse_id)),
    array[]::text[]);
end;
$$;

-- Unlike the bare `create function` in 0051, `create or replace` keeps the
-- existing ACL, so no PUBLIC grant is reintroduced here. Restated anyway, so
-- the intended end state is visible in the file rather than having to be
-- inferred from what an earlier migration left behind.
revoke all on function public.audit_log_query(bigint, text, text, timestamptz, timestamptz, integer)
  from public, anon;
grant execute on function public.audit_log_query(bigint, text, text, timestamptz, timestamptz, integer)
  to authenticated, service_role;
revoke all on function public.audit_event_types() from public, anon;
grant execute on function public.audit_event_types() to authenticated, service_role;
