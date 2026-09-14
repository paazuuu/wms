-- §31 AI UI: show 納品書番号 on the AI review screen when the analysis call
-- was linked to a delivery plan. `ai_analysis.delivery_plan_id` has existed
-- since 0026 but was never populated by any caller and never joined back
-- out by list_ai_analysis — the client had no way to show it even for a
-- linked row. Companion to the ocr-delivery-note edge function change that
-- starts actually passing plan_id through.
--
-- Byte-for-byte the live definition (fetched before editing) plus one left
-- join and two new jsonb keys; signature unchanged so grants carry over.
create or replace function public.list_ai_analysis(
  p_status text default 'PENDING_REVIEW'::text, p_limit integer default 50
) returns jsonb
language plpgsql
stable security definer
set search_path to ''
as $function$
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
        'reviewed_at', a.reviewed_at,
        'delivery_plan_id', a.delivery_plan_id,
        'delivery_number', dp.delivery_number
      ) order by a.created_at desc)
      from (
        select *
          from public.ai_analysis
         where p_status is null or status = p_status
         order by created_at desc
         limit p_limit
      ) a
      left join public.delivery_plans dp on dp.id = a.delivery_plan_id
    ),
    '[]'::jsonb);
end;
$function$;
