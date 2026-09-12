-- 0030 — List AI analyses for human review (spec §31, completing 0026)
--
-- confirm_ai_analysis/reject_ai_analysis (0026) let an ai.review holder act
-- on one result, but nothing let them see which results are waiting —
-- ai_analysis's own RLS policy only allows a bare SELECT to ai.review
-- holders, which a client could call directly over PostgREST, but a
-- dedicated RPC keeps this consistent with list_app_users/list_connectors
-- (a single call shaped for the screen, rather than the client composing
-- its own PostgREST filter/order/limit query).
create or replace function public.list_ai_analysis(
  p_status text default 'PENDING_REVIEW',
  p_limit int default 50
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('ai.review') then
    raise exception 'not permitted: ai.review required';
  end if;

  return coalesce(
    (select jsonb_agg(jsonb_build_object(
        'id', a.id,
        'task_type', a.task_type,
        'provider', a.provider,
        'model', a.model,
        'output_json', a.output_json,
        'confidence', a.confidence,
        'status', a.status,
        'created_at', a.created_at,
        'reviewed_by', a.reviewed_by,
        'reviewed_at', a.reviewed_at
      ) order by a.created_at desc)
      from (
        select *
          from public.ai_analysis
         where p_status is null or status = p_status
         order by created_at desc
         limit p_limit
      ) a),
    '[]'::jsonb);
end;
$$;

revoke all on function public.list_ai_analysis(text, int) from public, anon;
grant execute on function public.list_ai_analysis(text, int) to authenticated, service_role;
