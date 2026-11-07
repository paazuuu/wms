-- 0199: 出庫元の倉庫 changed after registration, and the shipment's gross
-- weight estimated before it is packed.
--
-- * outbound_file_set_warehouse(id, warehouse): a list not yet shipped (a
--   出庫予定, or a 在庫外出荷 not taken back) moved to another warehouse.
--   Nothing has left stock, so nothing moves; the warehouse confirming it
--   later takes from its own stock. Its packing lists follow it. The file
--   itself stays where it was put (its path keeps the first warehouse).
-- * outbound_files.pack_carton_count / pack_carton_kg / pack_material_kg:
--   how many cartons, what one empty carton weighs, and the packing
--   material in all — set by hand (null: 未定) for the estimate
--   商品の重量 + 箱の数 × 1箱の重さ + 梱包材 = 総重量. The real packing list
--   comes later as a file.
-- * outbound_file_set_pack_estimate(id, count, carton kg, material kg).
-- * outbound_file_detail gives the three.

alter table public.outbound_files add column if not exists pack_carton_count integer;
alter table public.outbound_files add column if not exists pack_carton_kg numeric(10, 3);
alter table public.outbound_files add column if not exists pack_material_kg numeric(10, 3);

create or replace function public.outbound_file_set_warehouse(p_id bigint, p_warehouse_id bigint)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_f public.outbound_files;
begin
  if auth.uid() is null or not public.can_post_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  select * into v_f from public.outbound_files where id = p_id for update;
  if v_f.id is null or not public.can_access_warehouse(v_f.warehouse_id) then
    raise exception 'outbound file % not found', p_id;
  end if;
  if p_warehouse_id is null or not public.can_access_warehouse(p_warehouse_id)
     or not exists (select 1 from public.warehouses where id = p_warehouse_id) then
    raise exception 'warehouse % not found', p_warehouse_id;
  end if;
  if v_f.undone_at is not null or (v_f.status <> 'planned' and v_f.kind <> 'proxy') then
    raise exception 'outbound file % has shipped: its warehouse stays', p_id;
  end if;
  if v_f.warehouse_id = p_warehouse_id then
    return false;
  end if;
  update public.outbound_files set warehouse_id = p_warehouse_id where id = p_id;
  update public.outbound_packing_lists set warehouse_id = p_warehouse_id
   where file_id = p_id and removed_at is null;
  perform public.log_audit('outbound.warehouse_changed', 'outbound_file', p_id::text, p_warehouse_id,
    jsonb_build_object('from', v_f.warehouse_id, 'to', p_warehouse_id));
  return true;
end;
$$;
revoke all on function public.outbound_file_set_warehouse(bigint, bigint) from public, anon;
grant execute on function public.outbound_file_set_warehouse(bigint, bigint) to authenticated;

create or replace function public.outbound_file_set_pack_estimate(
  p_id bigint, p_carton_count integer, p_carton_kg numeric, p_material_kg numeric)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_f public.outbound_files;
begin
  if auth.uid() is null or not public.can_post_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  select * into v_f from public.outbound_files where id = p_id for update;
  if v_f.id is null or not public.can_access_warehouse(v_f.warehouse_id) then
    raise exception 'outbound file % not found', p_id;
  end if;
  if coalesce(p_carton_count, 0) < 0 or coalesce(p_carton_kg, 0) < 0 or coalesce(p_material_kg, 0) < 0 then
    raise exception 'pack estimate: no value may be below 0';
  end if;
  update public.outbound_files
     set pack_carton_count = p_carton_count, pack_carton_kg = p_carton_kg, pack_material_kg = p_material_kg
   where id = p_id;
  perform public.log_audit('outbound.pack_estimate_set', 'outbound_file', p_id::text, v_f.warehouse_id,
    jsonb_build_object('cartons', p_carton_count, 'carton_kg', p_carton_kg, 'material_kg', p_material_kg));
  return true;
end;
$$;
revoke all on function public.outbound_file_set_pack_estimate(bigint, integer, numeric, numeric) from public, anon;
grant execute on function public.outbound_file_set_pack_estimate(bigint, integer, numeric, numeric) to authenticated;

do $$
declare
  d text;
  r text;
begin
  d := pg_get_functiondef('public.outbound_file_detail(bigint)'::regprocedure);
  if position('pack_carton_count' in d) = 0 then
    r := replace(d, '''undone_at'', v_f.undone_at, ''undone_by_name'', public.user_display_name(v_f.undone_by),',
                    '''undone_at'', v_f.undone_at, ''undone_by_name'', public.user_display_name(v_f.undone_by),'
                    || ' ''pack_carton_count'', v_f.pack_carton_count, ''pack_carton_kg'', v_f.pack_carton_kg,'
                    || ' ''pack_material_kg'', v_f.pack_material_kg,');
    if r = d then
      raise exception 'outbound_file_detail: the text to change was not found';
    end if;
    execute r;
  end if;
end;
$$;
