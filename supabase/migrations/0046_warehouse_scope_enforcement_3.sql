-- 0046 — Per-user warehouse scope, batch 3: the order-creation entry points
-- (UI spec §37, continuing 0044/0045)
--
-- 0044 covered the stock-moving core, 0045 the list/index reads. These three
-- are the remaining *writes* that name a warehouse: creating a purchase,
-- sales or work order files a record against that warehouse's books. None
-- of them moves stock (completing a work order does, and that already goes
-- through apply_stock_movement from 0044), so they slot in after the core —
-- but a scope-restricted user should not be able to open orders in a
-- warehouse they cannot act in.
--
-- Each already validates that the warehouse *exists*; the added check is
-- whether this caller may use it. Placed directly after the existing
-- has_permission() guard, so the two authorization questions — "may you do
-- this kind of thing" and "may you do it here" — read together.
create or replace function public.create_purchase_order(
  p_supplier_name text,
  p_warehouse_id bigint,
  p_lines jsonb,
  p_supplier_id bigint default null,
  p_expected_date date default null,
  p_note text default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_id bigint;
  v_company_id bigint;
  v_line jsonb;
  v_qty integer;
begin
  if not public.has_permission('purchase_order.manage') then
    raise exception 'not permitted: purchase_order.manage required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if p_supplier_name is null or p_supplier_name = '' then
    raise exception 'supplier_name is required';
  end if;
  if not exists (select 1 from public.warehouses where id = p_warehouse_id) then
    raise exception 'warehouse % not found', p_warehouse_id;
  end if;
  if jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'at least one line is required';
  end if;

  select id into v_company_id from public.companies order by id limit 1;

  insert into public.purchase_orders
    (company_id, supplier_id, supplier_name, warehouse_id, expected_date, note, requested_by)
  values
    (v_company_id, p_supplier_id, p_supplier_name, p_warehouse_id, p_expected_date,
     nullif(p_note, ''), auth.uid())
  returning id into v_id;

  update public.purchase_orders
     set po_number = 'PO-' || lpad(v_id::text, 6, '0')
   where id = v_id;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_qty := coalesce((v_line->>'quantity')::int, 0);
    if v_qty > 0 and coalesce(v_line->>'jan_code', '') <> '' then
      insert into public.purchase_order_lines
        (purchase_order_id, jan_code, product_name, quantity, unit_price)
      values (
        v_id, v_line->>'jan_code', coalesce(v_line->>'product_name', ''), v_qty,
        nullif(v_line->>'unit_price', '')::numeric);
    end if;
  end loop;

  if not exists (select 1 from public.purchase_order_lines where purchase_order_id = v_id) then
    raise exception 'at least one line with a positive quantity is required';
  end if;

  perform public.log_audit('purchase_order.created', 'purchase_order', v_id::text,
    p_warehouse_id, jsonb_build_object('supplier_name', p_supplier_name));

  return v_id;
end;
$function$;

create or replace function public.create_sales_order(
  p_customer_name text,
  p_warehouse_id bigint,
  p_lines jsonb,
  p_customer_id bigint default null,
  p_requested_ship_date date default null,
  p_note text default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_id bigint;
  v_company_id bigint;
  v_line jsonb;
  v_qty integer;
begin
  if not public.has_permission('sales_order.manage') then
    raise exception 'not permitted: sales_order.manage required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if p_customer_name is null or p_customer_name = '' then
    raise exception 'customer_name is required';
  end if;
  if not exists (select 1 from public.warehouses where id = p_warehouse_id) then
    raise exception 'warehouse % not found', p_warehouse_id;
  end if;
  if jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'at least one line is required';
  end if;

  select id into v_company_id from public.companies order by id limit 1;

  insert into public.sales_orders
    (company_id, customer_id, customer_name, warehouse_id, requested_ship_date, note, requested_by)
  values
    (v_company_id, p_customer_id, p_customer_name, p_warehouse_id, p_requested_ship_date,
     nullif(p_note, ''), auth.uid())
  returning id into v_id;

  update public.sales_orders
     set so_number = 'SO-' || lpad(v_id::text, 6, '0')
   where id = v_id;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_qty := coalesce((v_line->>'quantity')::int, 0);
    if v_qty > 0 and coalesce(v_line->>'jan_code', '') <> '' then
      insert into public.sales_order_lines
        (sales_order_id, jan_code, product_name, quantity, unit_price)
      values (
        v_id, v_line->>'jan_code', coalesce(v_line->>'product_name', ''), v_qty,
        nullif(v_line->>'unit_price', '')::numeric);
    end if;
  end loop;

  if not exists (select 1 from public.sales_order_lines where sales_order_id = v_id) then
    raise exception 'at least one line with a positive quantity is required';
  end if;

  perform public.log_audit('sales_order.created', 'sales_order', v_id::text,
    p_warehouse_id, jsonb_build_object('customer_name', p_customer_name));

  return v_id;
end;
$function$;

create or replace function public.create_work_order(
  p_warehouse_id bigint,
  p_output_jan_code text,
  p_output_quantity integer,
  p_components jsonb,
  p_output_product_name text default ''::text,
  p_note text default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_id bigint;
  v_company_id bigint;
  v_component jsonb;
  v_qty integer;
begin
  if not public.has_permission('work_order.manage') then
    raise exception 'not permitted: work_order.manage required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if not exists (select 1 from public.warehouses where id = p_warehouse_id) then
    raise exception 'warehouse % not found', p_warehouse_id;
  end if;
  if p_output_jan_code is null or p_output_jan_code = '' then
    raise exception 'output_jan_code is required';
  end if;
  if p_output_quantity is null or p_output_quantity <= 0 then
    raise exception 'output_quantity must be positive';
  end if;
  if jsonb_typeof(p_components) is distinct from 'array' or jsonb_array_length(p_components) = 0 then
    raise exception 'at least one component is required';
  end if;

  select id into v_company_id from public.companies order by id limit 1;

  insert into public.work_orders
    (company_id, warehouse_id, output_jan_code, output_product_name, output_quantity,
     note, created_by)
  values
    (v_company_id, p_warehouse_id, p_output_jan_code, coalesce(p_output_product_name, ''),
     p_output_quantity, nullif(p_note, ''), auth.uid())
  returning id into v_id;

  update public.work_orders
     set wo_number = 'WO-' || lpad(v_id::text, 6, '0')
   where id = v_id;

  for v_component in select * from jsonb_array_elements(p_components) loop
    v_qty := coalesce((v_component->>'quantity_required')::int, 0);
    if v_qty > 0 and coalesce(v_component->>'jan_code', '') <> '' then
      insert into public.work_order_components
        (work_order_id, jan_code, product_name, quantity_required)
      values (
        v_id, v_component->>'jan_code', coalesce(v_component->>'product_name', ''), v_qty);
    end if;
  end loop;

  if not exists (select 1 from public.work_order_components where work_order_id = v_id) then
    raise exception 'at least one component with a positive quantity is required';
  end if;

  perform public.log_audit('work_order.created', 'work_order', v_id::text, p_warehouse_id,
    jsonb_build_object('output_jan_code', p_output_jan_code, 'output_quantity', p_output_quantity));

  return v_id;
end;
$function$;
