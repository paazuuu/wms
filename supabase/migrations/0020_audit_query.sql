-- 0020 — Audit trail surfacing (spec Step 12, §33)
--
-- The stock ledger already answers "why did this JAN's quantity change"
-- (0013/0014's `stock_ledger`, callable with jan_code=null for a whole
-- warehouse). What is still missing is "who did what, beyond just stock" —
-- approvals, rejections, cancellations, count/inspection completions — all
-- of which 0012 already writes to `audit_log` via `log_audit`, but nothing
-- has ever read it back.
--
-- `audit_log` has RLS with a read policy for `authenticated` only (0012).
-- The app is still login-free, so every request today runs as `anon` and
-- that policy never applies — direct REST reads return nothing. This RPC is
-- the read surface, same shape as the `stock_count_lines` masking pattern:
-- SECURITY DEFINER bypasses RLS deliberately, PostgREST direct access stays
-- closed.

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
           a.actor_user_id, a.event_type, a.entity_type, a.entity_id, a.details
      from public.audit_log a
      left join public.warehouses w on w.id = a.warehouse_id
     where (p_warehouse_id is null or a.warehouse_id = p_warehouse_id)
       and (p_entity_type is null or a.entity_type = p_entity_type)
       and (p_event_type is null or a.event_type = p_event_type)
       and (p_since is null or a.created_at >= p_since)
       and (p_until is null or a.created_at <= p_until)
     order by a.created_at desc, a.id desc
     limit greatest(coalesce(p_limit, 100), 1)
  ) t;
$$;

-- Distinct event types seen so far, for a filter chip row that never shows a
-- choice nothing has actually logged.
create or replace function public.audit_event_types()
returns text[]
language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(distinct event_type order by event_type), array[]::text[])
    from public.audit_log;
$$;

grant execute on function public.audit_log_query(bigint, text, text, timestamptz, timestamptz, integer)
  to anon, authenticated, service_role;
grant execute on function public.audit_event_types() to anon, authenticated, service_role;
