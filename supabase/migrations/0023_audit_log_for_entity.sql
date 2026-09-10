-- 0023 — Per-document activity timeline (spec Step 14, §40)
--
-- §40: "state machines... are surfaced so an operator sees where a job is."
-- audit_log_query (0020) can filter by entity_type/event_type but has no
-- entity_id filter, so nothing could show "everything that happened to
-- *this* transfer" on the transfer's own detail screen. A separate function
-- rather than adding a parameter to audit_log_query — that RPC already
-- shipped and is called from the Audit Log screen; a new function avoids
-- touching a working signature for an unrelated use case.

create or replace function public.audit_log_for_entity(
  p_entity_type text,
  p_entity_id text,
  p_limit integer default 50
) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(row_to_json(t) order by t.created_at desc, t.id desc), '[]'::jsonb)
  from (
    select a.id, a.created_at, a.warehouse_id, w.name as warehouse_name,
           a.actor_user_id, a.event_type, a.entity_type, a.entity_id, a.details
      from public.audit_log a
      left join public.warehouses w on w.id = a.warehouse_id
     where a.entity_type = p_entity_type
       and a.entity_id = p_entity_id
     order by a.created_at desc, a.id desc
     limit greatest(coalesce(p_limit, 50), 1)
  ) t;
$$;

grant execute on function public.audit_log_for_entity(text, text, integer)
  to anon, authenticated, service_role;
