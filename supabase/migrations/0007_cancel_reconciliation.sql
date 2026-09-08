-- Correction / cancel: void a reconciliation receipt. Reverses the received
-- quantities it added to the plan lines and to the per-JAN stock, marks the
-- receipt 'cancelled', and recomputes the plan status from what remains — so a
-- mistaken receipt (or a re-scan of the same delivery) can be undone instead of
-- being corrected by hand.
create or replace function public.cancel_reconciliation(p_recon_id bigint)
returns bigint
language plpgsql
set search_path = ''
as $$
declare
  v_plan        bigint;
  v_status      text;
  v_received    int;
  v_outstanding int;
begin
  select delivery_plan_id, status into v_plan, v_status
    from public.delivery_reconciliations where id = p_recon_id;
  if v_plan is null then
    raise exception 'reconciliation % not found', p_recon_id;
  end if;
  if v_status = 'cancelled' then
    return p_recon_id; -- already cancelled: idempotent
  end if;

  -- Reverse the received quantities on the plan lines.
  update public.delivery_plan_lines pl
     set received_quantity = greatest(coalesce(pl.received_quantity, 0) - agg.qty, 0)
  from (
    select plan_line_id, sum(coalesce(actual_quantity, 0)) as qty
    from public.reconciliation_lines
    where reconciliation_id = p_recon_id and plan_line_id is not null
    group by plan_line_id
  ) agg
  where pl.id = agg.plan_line_id;

  -- Reverse the stock this receipt added.
  update public.stock_levels s
     set on_hand = greatest(coalesce(s.on_hand, 0) - agg.qty, 0),
         updated_at = now()
  from (
    select jan_code, sum(coalesce(actual_quantity, 0)) as qty
    from public.reconciliation_lines
    where reconciliation_id = p_recon_id and coalesce(actual_quantity, 0) > 0
    group by jan_code
  ) agg
  where s.jan_code = agg.jan_code;

  update public.delivery_reconciliations set status = 'cancelled' where id = p_recon_id;

  -- Recompute the plan status from what is still received.
  select coalesce(sum(coalesce(received_quantity, 0)), 0),
         coalesce(sum(greatest(
           coalesce(planned_quantity, 0) - coalesce(received_quantity, 0), 0)), 0)
    into v_received, v_outstanding
  from public.delivery_plan_lines where delivery_plan_id = v_plan;

  update public.delivery_plans
     set status = case
       when v_received = 0 then 'open'
       when v_outstanding = 0 then 'completed'
       else 'partial' end
   where id = v_plan;

  return p_recon_id;
end $$;

grant execute on function public.cancel_reconciliation(bigint) to authenticated;
