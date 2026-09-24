-- 0079 — Phase C client follow-up: a safe way to rename a carton
--
-- 0076 gave cartons real identity on their contents (lot_id/serial_id on
-- `shipment_carton_items`) and a set of narrow, additive RPCs
-- (`pack_carton_item`/`remove_carton_item`) to change what is inside one
-- parcel at a time. The only way left to touch a carton's free-text `label`
-- (0008) is still the `shipments` edge function's `PUT .../cartons/:cid`,
-- which replaces the carton's *entire item list* — delete every row, reinsert
-- from what the caller sent, with no lot/serial columns in that payload at
-- all. Once a carton holds lot- or serial-identified parcels (0076's whole
-- point), calling that route to rename the box would silently discard the
-- identity `pack_carton_item` recorded — the exact traceability §17 exists
-- for. Renaming a box is not supposed to be able to do that.
--
-- A one-column RPC closes the gap cleanly: it touches `label` and nothing
-- else, guarded the same way `set_carton_measurements` already is.

create or replace function public.set_carton_label(
  p_carton_id bigint,
  p_label     text default null
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_warehouse bigint;
  v_status text;
begin
  if not public.has_permission('pack.complete') then
    raise exception 'not permitted: pack.complete required';
  end if;

  select p.warehouse_id, c.status into v_warehouse, v_status
    from public.shipment_cartons c
    join public.shipment_plans p on p.id = c.shipment_plan_id
   where c.id = p_carton_id;
  if v_status is null then raise exception 'carton % not found', p_carton_id; end if;
  if v_warehouse is not null and not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_status = 'CANCELLED' then
    raise exception 'carton % is cancelled', p_carton_id;
  end if;

  update public.shipment_cartons
     set label = nullif(btrim(coalesce(p_label, '')), '')
   where id = p_carton_id;

  perform public.log_audit('shipment.carton_labeled', 'shipment_carton',
    p_carton_id::text, v_warehouse, jsonb_build_object('label', p_label));

  return public.carton_detail(p_carton_id);
end;
$$;

revoke all on function public.set_carton_label(bigint, text) from public, anon;
grant execute on function public.set_carton_label(bigint, text)
  to authenticated, service_role;
