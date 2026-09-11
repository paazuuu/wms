-- 0027 — record_ai_analysis: default to the single seeded company when the
-- caller doesn't know one (spec Steps 15–16, follow-up to 0026)
--
-- The OCR edge function calling this doesn't have a company/warehouse
-- context today (the client never sends a plan_id to the OCR endpoint —
-- OCR runs before a plan necessarily exists). Rather than push that
-- resolution into the edge function's TypeScript, coalesce here to the
-- one seeded default company (spec's "single implicit warehouse" backfill
-- from 0010) — the same fallback bootstrap_first_admin already uses.
create or replace function public.record_ai_analysis(
  p_company_id bigint,
  p_warehouse_id bigint,
  p_delivery_plan_id bigint,
  p_inspection_id bigint,
  p_provider text,
  p_model text,
  p_task_type text,
  p_input_hash text,
  p_output_json jsonb,
  p_confidence numeric
) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
  v_company_id bigint := coalesce(p_company_id, (select id from public.companies order by id limit 1));
begin
  insert into public.ai_analysis (
    company_id, warehouse_id, delivery_plan_id, inspection_id,
    provider, model, task_type, input_hash, output_json, confidence)
  values (
    v_company_id, p_warehouse_id, p_delivery_plan_id, p_inspection_id,
    p_provider, p_model, p_task_type, p_input_hash, p_output_json, p_confidence)
  returning id into v_id;

  perform public.log_audit('ai.analysis_completed', 'ai_analysis', v_id::text, p_warehouse_id,
    jsonb_build_object('task_type', p_task_type, 'provider', p_provider));

  return v_id;
end;
$$;

revoke all on function public.record_ai_analysis(
  bigint, bigint, bigint, bigint, text, text, text, text, jsonb, numeric)
  from public, anon, authenticated;
grant execute on function public.record_ai_analysis(
  bigint, bigint, bigint, bigint, text, text, text, text, jsonb, numeric)
  to service_role;
