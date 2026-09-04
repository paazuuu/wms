-- Split-delivery accumulation: an order can arrive across several deliveries.
-- Track the running received quantity per plan line so the outstanding (未納)
-- amount survives between sessions, and only close the plan once every line is
-- fully received (or the operator explicitly finalizes it short).
alter table public.delivery_plan_lines
  add column if not exists received_quantity int not null default 0;

-- Allow the new 'partial' lifecycle state.
alter table public.delivery_plans drop constraint if exists delivery_plans_status_check;
alter table public.delivery_plans add constraint delivery_plans_status_check
  check (status = any (array['open','reconciling','partial','completed']));

-- Reconcile RPC v5:
--   * each call is one physical receipt — it adds its counts to the plan lines'
--     running received_quantity and to the per-JAN total stock;
--   * the plan is marked 'completed' when nothing is outstanding, or when the
--     operator finalizes it (p_complete=true) even though some remains short;
--   * otherwise it stays 'partial' and keeps its outstanding lines for the next
--     delivery.
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
  v_recon_id    bigint;
  v_supplier    bigint;
  v_ref         text;
  v_outstanding int;
  v_status      text;
begin
  select supplier_id into v_supplier
    from public.delivery_plans where id = p_plan_id;
  v_ref := public.assign_reference(v_supplier);

  insert into public.delivery_reconciliations
    (delivery_plan_id, note_reference, status, supplier_id, reference_no)
  values
    (p_plan_id, p_note_reference, 'received', v_supplier, v_ref)
  returning id into v_recon_id;

  -- Audit: one row per counted JAN for THIS receipt, judged on the cumulative
  -- received (before this receipt) plus what arrived now.
  insert into public.reconciliation_lines
    (reconciliation_id, plan_line_id, jan_code, planned_quantity,
     actual_quantity, status, source)
  select
    v_recon_id, pl.id, (e->>'jan_code'),
    coalesce(pl.planned_quantity, 0),
    coalesce((e->>'actual_quantity')::int, 0),
    case
      when pl.id is null then 'unexpected'
      when coalesce((e->>'actual_quantity')::int, 0) = 0 then 'shortfall'
      when coalesce(pl.received_quantity, 0) + coalesce((e->>'actual_quantity')::int, 0)
           = pl.planned_quantity then 'matched'
      when coalesce(pl.received_quantity, 0) + coalesce((e->>'actual_quantity')::int, 0)
           < pl.planned_quantity then 'shortfall'
      else 'over'
    end,
    (e->>'source')
  from jsonb_array_elements(p_lines) as e
  left join public.delivery_plan_lines pl
    on pl.delivery_plan_id = p_plan_id and pl.jan_code = (e->>'jan_code');

  -- Accumulate the received quantities onto the plan lines.
  update public.delivery_plan_lines pl
     set received_quantity = coalesce(pl.received_quantity, 0) + agg.qty
  from (
    select (e->>'jan_code') as jan,
           sum(coalesce((e->>'actual_quantity')::int, 0)) as qty
    from jsonb_array_elements(p_lines) as e
    group by 1
  ) agg
  where pl.delivery_plan_id = p_plan_id and pl.jan_code = agg.jan;

  -- Physical goods arrived now, so add them to the per-JAN total stock.
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

  -- Outstanding across the whole plan after this receipt.
  select coalesce(sum(greatest(
           coalesce(planned_quantity, 0) - coalesce(received_quantity, 0), 0)), 0)
    into v_outstanding
  from public.delivery_plan_lines
  where delivery_plan_id = p_plan_id;

  v_status := case
    when v_outstanding = 0 then 'completed'
    when p_complete then 'completed'
    else 'partial'
  end;

  update public.delivery_plans set status = v_status where id = p_plan_id;
  update public.delivery_reconciliations
     set status = case when v_status = 'completed' then 'completed' else 'partial' end
   where id = v_recon_id;

  return v_recon_id;
end;
$$;

grant execute on function public.reconcile_delivery_plan(bigint, boolean, text, jsonb) to authenticated;
