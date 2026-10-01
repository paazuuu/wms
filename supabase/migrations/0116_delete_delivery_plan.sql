-- 0116 — taking back a delivery plan nobody has started on.
--
-- A plan imported too early (or by mistake) stayed in 納品照合 for good:
-- there was no way to remove it. `delete_delivery_plan` deletes one while
-- it is still open and nothing has been received against it; its lines go
-- with it (on delete cascade), and the inspections, invoices and AI notes
-- that named it keep their rows with the plan cleared (on delete set null).
-- A plan with a receipt is history and stays.

create or replace function public.delete_delivery_plan(p_id bigint)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_plan record;
  v_lines int;
begin
  if not public.has_permission('receiving.confirm') then
    raise exception 'not permitted: receiving.confirm required';
  end if;
  select id, delivery_number, supplier_name, status, warehouse_id into v_plan
    from public.delivery_plans where id = p_id;
  if v_plan.id is null then
    raise exception 'delivery plan % not found', p_id;
  end if;
  if v_plan.warehouse_id is not null and not public.can_access_warehouse(v_plan.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_plan.status <> 'open'
     or exists (select 1 from public.delivery_reconciliations r where r.delivery_plan_id = p_id) then
    raise exception 'delivery plan % has been received against and cannot be deleted', p_id;
  end if;
  select count(*) into v_lines from public.delivery_plan_lines where delivery_plan_id = p_id;
  delete from public.delivery_plans where id = p_id;
  perform public.log_audit('delivery_plan.deleted', 'delivery_plan', p_id::text, v_plan.warehouse_id,
    jsonb_build_object('delivery_number', v_plan.delivery_number,
                       'supplier_name', v_plan.supplier_name, 'lines', v_lines));
  return true;
end;
$$;

revoke all on function public.delete_delivery_plan(bigint) from public, anon;
grant execute on function public.delete_delivery_plan(bigint) to authenticated, service_role;
