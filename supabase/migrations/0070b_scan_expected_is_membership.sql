-- 0070b_scan_expected_is_membership.sql
-- A correction to 0070, caught by its own functional test.
--
-- 0070 computed `expected` as "is this the *first* kind the context wants",
-- which made a product scan during receiving read as unexpected — and receiving
-- is a step that very much expects product scans. The context's array is a
-- priority order for resolving ambiguity, not a list with one legal answer.
--
-- So `expected` becomes membership, and `expected_rank` carries the ordering
-- instead, which is what lets a screen tell "exactly what I asked for" from
-- "fair enough, carry on".

create or replace function public.resolve_barcode(
  p_barcode      text,
  p_context      text default null,
  p_product_id   bigint default null,
  p_warehouse_id bigint default null
) returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
declare
  v_code    text;
  v_raw     text := nullif(upper(btrim(coalesce(p_barcode, ''))), '');
  v_ctx     text := nullif(upper(btrim(coalesce(p_context, ''))), '');
  v_expects text[];
  v_kind    text;
  v_result  jsonb;
  v_hit     jsonb;
  v_num     bigint;
  v_n       int;
  v_rank    int;
begin
  if not (public.has_permission('product.view')
          or public.has_permission('inventory.view')) then
    raise exception 'not permitted: product.view required';
  end if;

  v_code := public.normalize_barcode(p_barcode);
  if v_code is null and v_raw is null then
    return jsonb_build_object('kind', 'unknown', 'barcode', p_barcode,
                              'context', v_ctx, 'expected', false);
  end if;

  select expects into v_expects from public.scan_contexts
   where code = v_ctx and is_active;
  if v_expects is null then
    -- No context, or one this database does not know: try everything, in the
    -- order a person browsing would expect.
    v_expects := array['product','serial','lot','location','receipt','delivery','shipment','task'];
  end if;

  foreach v_kind in array v_expects loop
    v_hit := null;

    if v_kind = 'product' then
      select jsonb_build_object(
               'kind', 'product',
               'barcode', b.barcode,
               'barcode_type', b.barcode_type,
               'quantity_per_scan', b.quantity_per_scan,
               'uom', (select u.code from public.uoms u where u.id = b.uom_id),
               'base_uom', (select u.code from public.uoms u where u.id = p.base_uom_id),
               'is_primary', b.is_primary,
               'product_id', p.id, 'jan_code', p.jan_code, 'sku', p.sku,
               'name', p.name, 'category', p.category,
               'tracking_mode', p.tracking_mode, 'status', p.status,
               'requires_inspection', p.requires_inspection)
        into v_hit
        from public.product_barcodes b
        join public.products p on p.id = b.product_id
       where b.barcode = v_code;

    elsif v_kind = 'serial' then
      select jsonb_build_object(
               'kind', 'serial',
               'barcode', sn.serial_number,
               'serial_id', sn.id, 'serial_number', sn.serial_number,
               'serial_status', sn.status,
               'lot_id', sn.lot_id,
               'lot_code', (select l.lot_code from public.lots l where l.id = sn.lot_id),
               'expiry_date', (select l.expiry_date from public.lots l where l.id = sn.lot_id),
               'quantity_per_scan', 1,
               'base_uom', (select u.code from public.uoms u where u.id = p.base_uom_id),
               'product_id', p.id, 'jan_code', p.jan_code, 'sku', p.sku,
               'name', p.name, 'category', p.category,
               'tracking_mode', p.tracking_mode, 'status', p.status)
        into v_hit
        from public.serial_numbers sn
        join public.products p on p.id = sn.product_id
       where sn.serial_number in (v_raw, v_code)
       order by case when sn.serial_number = v_raw then 0 else 1 end
       limit 1;

    elsif v_kind = 'lot' then
      -- A lot code is unique only within its product. With a product in hand
      -- this is exact; without one it is a guess, so it is only answered when
      -- exactly one lot in the company matches — and when several do, the
      -- candidates are handed back rather than one of them being picked.
      if p_product_id is not null then
        select jsonb_build_object(
                 'kind', 'lot', 'barcode', l.lot_code,
                 'lot_id', l.id, 'lot_code', l.lot_code,
                 'expiry_date', l.expiry_date,
                 'manufacture_date', l.manufacture_date,
                 'is_expired', l.expiry_date is not null and l.expiry_date < current_date,
                 'quantity_per_scan', 1,
                 'product_id', p.id, 'jan_code', p.jan_code, 'name', p.name,
                 'tracking_mode', p.tracking_mode)
          into v_hit
          from public.lots l join public.products p on p.id = l.product_id
         where l.product_id = p_product_id and upper(l.lot_code) in (v_raw, v_code);
      else
        select count(*) into v_n from public.lots l
         where upper(l.lot_code) in (v_raw, v_code);
        if v_n = 1 then
          select jsonb_build_object(
                   'kind', 'lot', 'barcode', l.lot_code,
                   'lot_id', l.id, 'lot_code', l.lot_code,
                   'expiry_date', l.expiry_date,
                   'manufacture_date', l.manufacture_date,
                   'is_expired', l.expiry_date is not null and l.expiry_date < current_date,
                   'quantity_per_scan', 1,
                   'product_id', p.id, 'jan_code', p.jan_code, 'name', p.name,
                   'tracking_mode', p.tracking_mode)
            into v_hit
            from public.lots l join public.products p on p.id = l.product_id
           where upper(l.lot_code) in (v_raw, v_code);
        elsif v_n > 1 then
          select jsonb_build_object(
                   'kind', 'ambiguous', 'barcode', coalesce(v_raw, v_code),
                   'would_be', 'lot',
                   'reason', 'a lot code identifies a lot only within its product',
                   'candidates', jsonb_agg(jsonb_build_object(
                     'lot_id', l.id, 'lot_code', l.lot_code,
                     'product_id', p.id, 'jan_code', p.jan_code, 'name', p.name,
                     'expiry_date', l.expiry_date) order by l.id))
            into v_hit
            from public.lots l join public.products p on p.id = l.product_id
           where upper(l.lot_code) in (v_raw, v_code);
        end if;
      end if;

    elsif v_kind = 'location' then
      select jsonb_build_object(
               'kind', 'location',
               'barcode', coalesce(l.barcode, l.code),
               'location_id', l.id, 'code', l.code, 'name', l.name,
               'location_type', l.location_type,
               'warehouse_id', l.warehouse_id, 'bin_id', l.bin_id,
               'zone_id', l.zone_id, 'is_active', l.is_active,
               'pickable', l.pickable, 'receivable', l.receivable,
               'quarantine', l.quarantine, 'is_virtual', l.is_virtual)
        into v_hit
        from public.locations l
       where (l.barcode = v_code or upper(l.code) in (v_raw, v_code))
         and public.can_access_warehouse(l.warehouse_id)
         and (p_warehouse_id is null or l.warehouse_id = p_warehouse_id)
       order by case when l.barcode = v_code then 0 else 1 end, l.id
       limit 1;

    elsif v_kind = 'receipt' then
      select jsonb_build_object(
               'kind', 'receipt', 'barcode', r.reference_no,
               'reconciliation_id', r.id, 'reference_no', r.reference_no,
               'status', r.status, 'delivery_plan_id', r.delivery_plan_id,
               'delivery_number', dp.delivery_number,
               'supplier_name', dp.supplier_name,
               'warehouse_id', dp.warehouse_id)
        into v_hit
        from public.delivery_reconciliations r
        join public.delivery_plans dp on dp.id = r.delivery_plan_id
       where upper(r.reference_no) in (v_raw, v_code)
         and public.can_access_warehouse(
               coalesce(dp.warehouse_id, public.default_warehouse_id()))
       limit 1;

    elsif v_kind = 'delivery' then
      select jsonb_build_object(
               'kind', 'delivery', 'barcode', dp.delivery_number,
               'delivery_plan_id', dp.id, 'delivery_number', dp.delivery_number,
               'supplier_name', dp.supplier_name, 'status', dp.status,
               'warehouse_id', dp.warehouse_id)
        into v_hit
        from public.delivery_plans dp
       where upper(dp.delivery_number) in (v_raw, v_code)
         and public.can_access_warehouse(
               coalesce(dp.warehouse_id, public.default_warehouse_id()))
       limit 1;

    elsif v_kind = 'shipment' then
      select jsonb_build_object(
               'kind', 'shipment', 'barcode', sp.shipment_number,
               'shipment_plan_id', sp.id, 'shipment_number', sp.shipment_number,
               'customer_name', sp.customer_name, 'status', sp.status,
               'carrier', sp.carrier, 'tracking_number', sp.tracking_number,
               'warehouse_id', sp.warehouse_id)
        into v_hit
        from public.shipment_plans sp
       where (upper(sp.shipment_number) in (v_raw, v_code)
              or upper(coalesce(sp.tracking_number, '')) in (v_raw, v_code))
         and public.can_access_warehouse(
               coalesce(sp.warehouse_id, public.default_warehouse_id()))
       limit 1;

    elsif v_kind = 'task' or v_kind = 'inspection' then
      -- The printed-label convention: a prefix, a dash, the id.
      -- The pattern is checked before the cast, not after: 'ABC123' is a
      -- perfectly ordinary barcode and must not raise here.
      if v_raw ~ '^(PICK|QC|COUNT|TO)-[0-9]+$' then
        v_num := regexp_replace(v_raw, '^(PICK|QC|COUNT|TO)-', '')::bigint;
      else
        v_num := null;
      end if;
      if v_num is not null then
        if v_raw like 'PICK-%' and v_kind = 'task' then
          select jsonb_build_object('kind', 'task', 'task_type', 'pick_list',
                   'barcode', v_raw, 'pick_list_id', pl.id, 'status', pl.status,
                   'warehouse_id', pl.warehouse_id,
                   'shipment_plan_id', pl.shipment_plan_id)
            into v_hit from public.pick_lists pl
           where pl.id = v_num and public.can_access_warehouse(pl.warehouse_id);
        elsif v_raw like 'QC-%' then
          select jsonb_build_object('kind',
                   case when v_kind = 'inspection' then 'inspection' else 'task' end,
                   'task_type', 'inspection',
                   'barcode', v_raw, 'inspection_id', i.id, 'status', i.status,
                   'warehouse_id', i.warehouse_id,
                   'reconciliation_id', i.reconciliation_id)
            into v_hit from public.inspections i
           where i.id = v_num and public.can_access_warehouse(i.warehouse_id);
        elsif v_raw like 'COUNT-%' and v_kind = 'task' then
          select jsonb_build_object('kind', 'task', 'task_type', 'stock_count',
                   'barcode', v_raw, 'stock_count_id', c.id, 'status', c.status,
                   'warehouse_id', c.warehouse_id)
            into v_hit from public.stock_counts c
           where c.id = v_num and public.can_access_warehouse(c.warehouse_id);
        elsif v_raw like 'TO-%' and v_kind = 'task' then
          select jsonb_build_object('kind', 'task', 'task_type', 'transfer_order',
                   'barcode', v_raw, 'transfer_order_id', t.id, 'status', t.status,
                   'transfer_number', t.transfer_number,
                   'source_warehouse_id', t.source_warehouse_id,
                   'destination_warehouse_id', t.destination_warehouse_id)
            into v_hit from public.transfer_orders t
           where t.id = v_num
             and (public.can_access_warehouse(t.source_warehouse_id)
                  or public.can_access_warehouse(t.destination_warehouse_id));
        end if;
      end if;
      if v_hit is null and v_kind = 'task' then
        select jsonb_build_object('kind', 'task', 'task_type', 'transfer_order',
                 'barcode', t.transfer_number, 'transfer_order_id', t.id,
                 'status', t.status, 'transfer_number', t.transfer_number)
          into v_hit from public.transfer_orders t
         where upper(t.transfer_number) in (v_raw, v_code)
           and (public.can_access_warehouse(t.source_warehouse_id)
                or public.can_access_warehouse(t.destination_warehouse_id))
         limit 1;
      end if;
    end if;

    if v_hit is not null then
      v_result := v_hit;
      exit;
    end if;
  end loop;

  if v_result is null then
    return jsonb_build_object('kind', 'unknown',
                              'barcode', coalesce(v_code, v_raw),
                              'context', v_ctx,
                              'expected', false);
  end if;

  -- `expected` is membership, not first place. A receiving step expects a
  -- product scan as well as a receipt; what it does not expect is a shipment
  -- number. The array's order still decides which branch wins a tie, and
  -- `expected_rank` hands that ordering to the screen so it can tell "exactly
  -- what I asked for" from "fair enough, carry on".
  select coalesce(array_position(v_expects, v_result ->> 'kind'), 0) into v_rank;

  return v_result
       || jsonb_build_object(
            'context', v_ctx,
            'expected', v_rank > 0,
            'expected_rank', nullif(v_rank, 0),
            'context_expects', to_jsonb(v_expects));
end;
$$;

revoke all on function public.resolve_barcode(text, text, bigint, bigint) from public, anon;
grant execute on function public.resolve_barcode(text, text, bigint, bigint)
  to authenticated, service_role;

-- Same reason as 0066 and 0068: the one-argument form beside one whose extra
-- arguments default would make every one-argument call ambiguous. Callers that
-- pass only a barcode keep working, and now get a context-free resolution.
revoke all on function public.resolve_barcode(text, text, bigint, bigint) from public, anon;
grant execute on function public.resolve_barcode(text, text, bigint, bigint)
  to authenticated, service_role;
