-- 0145: how the stock came to be — for the product library's charts.
--
-- Every change of stock is already a row in stock_movements (warehouse
-- scope), with what kind of change it was and what it came from. These two
-- read-only functions group them by *method* — a file (and which file), a
-- receipt, a hand correction or count, a shipment — so the app can draw
-- when, how and from which file stock was added.
--
-- Methods:
--   file_stock   ファイルから在庫登録 (0144)
--   file_master  ファイルから商品・在庫登録 (0138)
--   receipt      入荷・検品 (RECEIPT, RECEIPT_CANCEL)
--   adjust       手動修正・棚卸・初期在庫 (ADJUST, COUNT, OPENING, SCRAP, RELABEL)
--   ship         出荷・ピッキング (PICK, SHIP, SHIP_CANCEL, RETURN_TO_SUPPLIER)
--   transfer     倉庫間移動 (TRANSFER_IN, TRANSFER_OUT)
--   other        anything else (work orders)
-- Nothing is written; no table changes.

create or replace function public.stock_movement_method(p_type text, p_ref_type text, p_import_source text)
returns text language sql immutable set search_path = '' as $$
  select case
    when p_ref_type = 'master_import' then case when p_import_source = 'stock_file' then 'file_stock' else 'file_master' end
    when p_type in ('RECEIPT', 'RECEIPT_CANCEL') then 'receipt'
    when p_type in ('ADJUST', 'COUNT', 'OPENING', 'SCRAP', 'RELABEL') then 'adjust'
    when p_type in ('PICK', 'SHIP', 'SHIP_CANCEL', 'RETURN_TO_SUPPLIER') then 'ship'
    when p_type in ('TRANSFER_IN', 'TRANSFER_OUT') then 'transfer'
    else 'other'
  end;
$$;

-- One product's stock over the last p_days: each change with its method,
-- file and warehouse, and the stock before the first of them (so a line
-- drawn from it ends at today's stock). A warehouse narrows it; without
-- one, every warehouse the caller may see.
create or replace function public.product_stock_history(
  p_product_id bigint, p_warehouse_id bigint default null, p_days integer default 90)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_jan text;
  v_since timestamptz := now() - make_interval(days => greatest(1, least(coalesce(p_days, 90), 3650)));
  v_current int;
  v_window int;
  v_events jsonb;
begin
  if not (public.has_permission('inventory.view') or public.has_permission('product.view')
          or public.has_permission('product.manage')) then
    raise exception 'not permitted: inventory.view required';
  end if;
  if p_warehouse_id is not null and not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  select jan_code into v_jan from public.products where id = p_product_id;
  if v_jan is null then
    raise exception 'product % not found', p_product_id;
  end if;

  select coalesce(sum(s.on_hand), 0)::int into v_current
    from public.stock_levels s
   where (s.product_id = p_product_id or s.jan_code = v_jan)
     and (case when p_warehouse_id is not null then s.warehouse_id = p_warehouse_id
               else public.can_access_warehouse(s.warehouse_id) end);

  with mv as (
    select m.id, m.created_at, m.warehouse_id, w.name as warehouse_name, m.movement_type, m.quantity,
           m.reference_type, m.reference_id, m.note, mi.id as import_id, mi.original_name as file_name, mi.source,
           public.stock_movement_method(m.movement_type, m.reference_type, mi.source) as method
      from public.stock_movements m
      left join public.warehouses w on w.id = m.warehouse_id
      left join public.master_imports mi
        on m.reference_type = 'master_import' and mi.id::text = m.reference_id
     where m.balance_scope = 'WAREHOUSE'
       and (m.product_id = p_product_id or m.jan_code = v_jan)
       and m.created_at >= v_since
       and (case when p_warehouse_id is not null then m.warehouse_id = p_warehouse_id
                 else public.can_access_warehouse(m.warehouse_id) end)
  )
  select coalesce(sum(quantity), 0)::int,
         coalesce(jsonb_agg(jsonb_build_object(
           'id', id, 'at', created_at, 'warehouse_id', warehouse_id, 'warehouse_name', warehouse_name,
           'type', movement_type, 'method', method, 'quantity', quantity,
           'reference_type', reference_type, 'reference_id', reference_id, 'note', note,
           'import_id', import_id, 'file_name', file_name) order by created_at, id), '[]'::jsonb)
    into v_window, v_events
    from mv;

  return jsonb_build_object('product_id', p_product_id, 'jan_code', v_jan, 'since', v_since,
                            'current', v_current, 'start', v_current - v_window, 'events', v_events);
end;
$$;
revoke all on function public.product_stock_history(bigint, bigint, integer) from public, anon;
grant execute on function public.product_stock_history(bigint, bigint, integer) to authenticated, service_role;

-- The whole library over the last p_days: units added and taken out per
-- day and method, and each file that changed stock (when, which file, how,
-- how many products and units).
create or replace function public.library_stock_inflow(p_warehouse_id bigint default null, p_days integer default 90)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_since timestamptz := now() - make_interval(days => greatest(1, least(coalesce(p_days, 90), 3650)));
  v_days jsonb;
  v_files jsonb;
begin
  if not (public.has_permission('inventory.view') or public.has_permission('product.view')
          or public.has_permission('product.manage')) then
    raise exception 'not permitted: inventory.view required';
  end if;
  if p_warehouse_id is not null and not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  with mv as (
    select (m.created_at at time zone 'Asia/Tokyo')::date as day, m.quantity, m.reference_type, m.reference_id,
           m.jan_code, m.warehouse_id,
           public.stock_movement_method(m.movement_type, m.reference_type, mi.source) as method
      from public.stock_movements m
      left join public.master_imports mi
        on m.reference_type = 'master_import' and mi.id::text = m.reference_id
     where m.balance_scope = 'WAREHOUSE'
       and m.created_at >= v_since
       and (case when p_warehouse_id is not null then m.warehouse_id = p_warehouse_id
                 else public.can_access_warehouse(m.warehouse_id) end)
  )
  select coalesce(jsonb_agg(jsonb_build_object('day', day, 'method', method, 'units_in', units_in,
                                               'units_out', units_out, 'products', products)
                            order by day, method), '[]'::jsonb)
    into v_days
    from (select day, method,
                 coalesce(sum(quantity) filter (where quantity > 0), 0)::int as units_in,
                 coalesce(-sum(quantity) filter (where quantity < 0), 0)::int as units_out,
                 count(distinct jan_code)::int as products
            from mv group by day, method) d;

  select coalesce(jsonb_agg(f order by f->>'at' desc), '[]'::jsonb) into v_files
    from (
      select jsonb_build_object(
               'import_id', mi.id, 'at', coalesce(mi.stock_at, mi.master_at, mi.created_at),
               'file_name', mi.original_name, 'method', case when mi.source = 'stock_file' then 'file_stock' else 'file_master' end,
               'warehouse_id', mi.warehouse_id, 'warehouse_name', w.name,
               'products', (select count(distinct m.jan_code) from public.stock_movements m
                             where m.reference_type = 'master_import' and m.reference_id = mi.id::text
                               and m.balance_scope = 'WAREHOUSE'),
               'units', (select coalesce(sum(m.quantity), 0) from public.stock_movements m
                          where m.reference_type = 'master_import' and m.reference_id = mi.id::text
                            and m.balance_scope = 'WAREHOUSE'),
               'by', (select coalesce(u.name, u.email) from public.app_users u where u.id = coalesce(mi.stock_by, mi.created_by))) as f
        from public.master_imports mi
        left join public.warehouses w on w.id = mi.warehouse_id
       where mi.status = 'stock_done'
         and coalesce(mi.stock_at, mi.created_at) >= v_since
         and (case when p_warehouse_id is not null then mi.warehouse_id = p_warehouse_id
                   else mi.warehouse_id is null or public.can_access_warehouse(mi.warehouse_id) end)
    ) x;

  return jsonb_build_object('since', v_since, 'days', v_days, 'files', v_files);
end;
$$;
revoke all on function public.library_stock_inflow(bigint, integer) from public, anon;
grant execute on function public.library_stock_inflow(bigint, integer) to authenticated, service_role;
