-- 0078 — restore the guard 0074 clobbered on pick_list_detail
--
-- 0074 rewrote `pick_list_detail` to add each task's parcels and picking rule. It
-- did that by replacing the function wholesale — and that function was not the
-- reader. Since 0051 it has been a *guarded wrapper*:
--
--     pick_list_detail       has_permission('pick.confirm')
--                            + can_access_warehouse(the list's warehouse)
--                            -> pick_list_detail_impl   (the actual read)
--
-- Replacing it with a plain `language sql` body removed both checks while leaving
-- the grant to `authenticated` in place. The result was a read, callable straight
-- over PostgREST, that would hand any signed-in user any warehouse's pick list —
-- exactly the gap 0056 was written to close, reopened by a migration that was
-- thinking about JSON fields.
--
-- Caught by `verify_security.sql`, which is the whole reason that file exists:
-- invariant 3 counts wrappers whose body calls `has_permission` and invariant 8
-- counts wrappers carrying warehouse scope, and both dropped from 18/18 to 17/18
-- naming `pick_list_detail`. No test of picking behaviour would have noticed,
-- because the behaviour was right; only the reach was wrong.
--
-- The fix puts things back where they belong: 0074's enriched body becomes the
-- `_impl`, and the wrapper returns to exactly the shape 0056 gave it. Fixed
-- forward rather than by editing 0074, because a migration that has run is
-- history (§37-4's rule, applied to schema instead of stock).
--
-- The lesson for later migrations, stated so it is not re-learned: before
-- replacing a read function, check whether a `<name>_impl` exists. If it does,
-- the thing to edit is the `_impl`.

create or replace function public.pick_list_detail_impl(p_pick_list_id bigint)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', l.id,
    'shipment_plan_id', l.shipment_plan_id,
    'shipment_number', p.shipment_number,
    'customer_name', p.customer_name,
    'warehouse_id', l.warehouse_id,
    'warehouse_name', w.name,
    'uses_locations', w.uses_locations,
    'status', l.status,
    'note', l.note,
    'created_at', l.created_at,
    'completed_at', l.completed_at,
    -- 0077's wave, so a picker can see which sheet this list belongs to.
    'wave_id', l.wave_id,
    'wave_code', (select x.code from public.pick_waves x where x.id = l.wave_id),
    'tasks', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', t.id,
               'shipment_line_id', t.shipment_line_id,
               'jan_code', t.jan_code,
               'product_id', t.product_id,
               'product_name', t.product_name,
               'planned_quantity', t.planned_quantity,
               'picked_quantity', t.picked_quantity,
               'variance', t.variance,
               'status', t.status,
               'bin_id', t.bin_id,
               'bin_code', b.code,
               'note', t.note,
               'picked_at', t.picked_at,
               'picking_rule', case when t.product_id is null then null
                 else public.picking_rule_for(t.product_id, l.warehouse_id) end,
               'items', coalesce((
                 select jsonb_agg(jsonb_build_object(
                          'id', i.id,
                          'quantity', i.quantity,
                          'lot_id', i.lot_id,
                          'lot_code', lo.lot_code,
                          'expiry_date', lo.expiry_date,
                          'serial_id', i.serial_id,
                          'serial_number', sn.serial_number,
                          'bin_id', i.bin_id,
                          'bin_code', ib.code,
                          'stock_unit_id', i.stock_unit_id,
                          'note', i.note,
                          'created_at', i.created_at) order by i.id)
                   from public.pick_items i
                   left join public.lots lo on lo.id = i.lot_id
                   left join public.serial_numbers sn on sn.id = i.serial_id
                   left join public.bins ib on ib.id = i.bin_id
                  where i.pick_task_id = t.id), '[]'::jsonb)) order by t.id)
        from public.pick_tasks t
        left join public.bins b on b.id = t.bin_id
       where t.pick_list_id = l.id), '[]'::jsonb))
  from public.pick_lists l
  join public.shipment_plans p on p.id = l.shipment_plan_id
  left join public.warehouses w on w.id = l.warehouse_id
  where l.id = p_pick_list_id;
$$;

-- Unreachable by every client role: only the wrapper may call it (invariant 4).
revoke all on function public.pick_list_detail_impl(bigint)
  from public, anon, authenticated, service_role;

-- Verbatim 0056, restored.
create or replace function public.pick_list_detail(p_pick_list_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('pick.confirm')) then
    raise exception 'not permitted: pick.confirm required';
  end if;
  if not exists (
    select 1 from public.pick_lists l
     where l.id = p_pick_list_id
       and public.can_access_warehouse(l.warehouse_id)
  ) then
    return null;
  end if;
  return public.pick_list_detail_impl(p_pick_list_id);
end; $$;

revoke all on function public.pick_list_detail(bigint) from public, anon;
grant execute on function public.pick_list_detail(bigint) to authenticated, service_role;
