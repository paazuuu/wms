-- Records a reconciliation transactionally: header + one line per counted JAN,
-- with server-side status recomputed from planned vs actual. When p_complete is
-- true, planned JANs that were never counted are backfilled as shortfalls
-- (未入荷) and the plan is closed.
create or replace function public.reconcile_delivery_plan(
  p_plan_id        bigint,
  p_complete       boolean default true,
  p_note_reference text default null,
  p_lines          jsonb default '[]'::jsonb
) returns bigint
language plpgsql
set search_path = ''
as $$
declare
  v_recon_id bigint;
begin
  insert into public.delivery_reconciliations
    (delivery_plan_id, note_reference, status)
  values
    (p_plan_id, p_note_reference,
     case when p_complete then 'completed' else 'reconciling' end)
  returning id into v_recon_id;

  -- Counted lines (JAN is the reconciliation key; plan line resolved by JAN).
  insert into public.reconciliation_lines
    (reconciliation_id, plan_line_id, jan_code, planned_quantity,
     actual_quantity, status, source)
  select
    v_recon_id,
    pl.id,
    (elem->>'jan_code'),
    coalesce(pl.planned_quantity, 0),
    coalesce((elem->>'actual_quantity')::int, 0),
    case
      when pl.id is null then 'unexpected'
      when coalesce((elem->>'actual_quantity')::int, 0) = 0 then 'shortfall'
      when coalesce((elem->>'actual_quantity')::int, 0) = pl.planned_quantity then 'matched'
      when coalesce((elem->>'actual_quantity')::int, 0) < pl.planned_quantity then 'shortfall'
      else 'over'
    end,
    (elem->>'source')
  from jsonb_array_elements(p_lines) as elem
  left join public.delivery_plan_lines pl
    on pl.delivery_plan_id = p_plan_id
   and pl.jan_code = (elem->>'jan_code');

  -- On completion, record planned JANs that never arrived as shortfalls.
  if p_complete then
    insert into public.reconciliation_lines
      (reconciliation_id, plan_line_id, jan_code, planned_quantity,
       actual_quantity, status, source)
    select v_recon_id, pl.id, pl.jan_code, pl.planned_quantity, 0, 'shortfall', null
    from public.delivery_plan_lines pl
    where pl.delivery_plan_id = p_plan_id
      and not exists (
        select 1 from jsonb_array_elements(p_lines) e
        where (e->>'jan_code') = pl.jan_code
      );
  end if;

  update public.delivery_plans
     set status = case when p_complete then 'completed' else 'reconciling' end
   where id = p_plan_id;

  return v_recon_id;
end;
$$;

grant execute on function public.reconcile_delivery_plan(bigint, boolean, text, jsonb) to authenticated;
