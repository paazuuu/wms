-- Reconcile RPC: assign a per-company reference number to the receipt and, on
-- completion, add the received quantities to the per-JAN total stock.
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
  v_supplier bigint;
  v_ref      text;
begin
  select supplier_id into v_supplier
    from public.delivery_plans where id = p_plan_id;
  v_ref := public.assign_reference(v_supplier);

  insert into public.delivery_reconciliations
    (delivery_plan_id, note_reference, status, supplier_id, reference_no)
  values
    (p_plan_id, p_note_reference,
     case when p_complete then 'completed' else 'reconciling' end,
     v_supplier, v_ref)
  returning id into v_recon_id;

  insert into public.reconciliation_lines
    (reconciliation_id, plan_line_id, jan_code, planned_quantity,
     actual_quantity, status, source)
  select
    v_recon_id, pl.id, (elem->>'jan_code'),
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
    on pl.delivery_plan_id = p_plan_id and pl.jan_code = (elem->>'jan_code');

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

    insert into public.stock_levels (jan_code, product_name, on_hand)
    select e->>'jan_code',
           coalesce(max(pl.product_name), ''),
           sum((e->>'actual_quantity')::int)
    from jsonb_array_elements(p_lines) e
    left join public.delivery_plan_lines pl
      on pl.delivery_plan_id = p_plan_id and pl.jan_code = (e->>'jan_code')
    where coalesce((e->>'actual_quantity')::int, 0) > 0
    group by e->>'jan_code'
    on conflict (jan_code) do update
      set on_hand = public.stock_levels.on_hand + excluded.on_hand,
          product_name = case
            when coalesce(public.stock_levels.product_name,'') = '' then excluded.product_name
            else public.stock_levels.product_name end,
          updated_at = now();
  end if;

  update public.delivery_plans
     set status = case when p_complete then 'completed' else 'reconciling' end
   where id = p_plan_id;

  return v_recon_id;
end;
$$;

grant execute on function public.reconcile_delivery_plan(bigint, boolean, text, jsonb) to authenticated;
