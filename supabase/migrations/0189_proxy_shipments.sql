-- 0189: 代理出荷 — a shipment kept as a record only.
--
-- Goods shipped on someone's behalf (or anything to be written down as
-- shipped) that are not in our stock: the rows are kept — from a file read
-- like 出荷リストで出庫, or typed in — with 依頼元 (principal), 出荷先, prices;
-- no stock is moved and the products need not be in the 商品ライブラリー.
-- * outbound_files.kind: 'stock' (0188, taken out of stock) or 'proxy'.
-- * proxy_shipment_post: as outbound_file_post, every row a record.
-- * outbound_files_list / outbound_file_detail give kind and principal.
-- * A 代理出荷's prices are not this business's 仕入れ値 (0187): left out.
-- * outbound_file_undo works for both (a proxy one has nothing to put back).

alter table public.outbound_files add column if not exists kind text not null default 'stock';
alter table public.outbound_files add column if not exists principal text;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'outbound_files_kind_check') then
    alter table public.outbound_files add constraint outbound_files_kind_check check (kind in ('stock', 'proxy'));
  end if;
end $$;

create or replace function public.proxy_shipment_post(
  p_warehouse_id bigint, p_shipped_on date, p_file_name text, p_lines jsonb,
  p_storage_path text default null, p_content_type text default null, p_byte_size integer default null,
  p_fingerprint text default null, p_sheet_name text default null, p_destination text default null,
  p_note text default null, p_columns jsonb default null, p_allow_duplicate boolean default false,
  p_principal text default null)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
  v_line jsonb;
  v_action text;
  v_pid bigint;
  v_p public.products;
  v_qty integer;
  v_before integer;
  v_ship integer;
  v_mid bigint;
  v_after integer;
  v_supplier text;
  v_sid bigint;
  v_unit numeric;
  v_unit_tax numeric;
  v_rate numeric;
begin
  if auth.uid() is null then
    raise exception 'not permitted: sign in required';
  end if;
  if not public.can_post_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  if p_warehouse_id is null or not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'outbound_no_lines';
  end if;
  if p_storage_path is not null and p_storage_path not like p_warehouse_id::text || '/%' then
    raise exception 'outbound_file_path';
  end if;
  if not coalesce(p_allow_duplicate, false) and p_fingerprint is not null and exists (
       select 1 from public.outbound_files where fingerprint = p_fingerprint and undone_at is null and kind = 'proxy') then
    raise exception 'outbound_duplicate';
  end if;

  insert into public.outbound_files (warehouse_id, shipped_on, file_name, storage_path, content_type, byte_size,
                                     fingerprint, sheet_name, destination, note, columns, kind, principal)
  values (p_warehouse_id, coalesce(p_shipped_on, (now() at time zone 'Asia/Tokyo')::date),
          coalesce(nullif(btrim(coalesce(p_file_name, '')), ''), 'file'), p_storage_path, p_content_type, p_byte_size,
          p_fingerprint, p_sheet_name, nullif(btrim(coalesce(p_destination, '')), ''),
          nullif(btrim(coalesce(p_note, '')), ''), coalesce(p_columns, '{}'::jsonb), 'proxy',
          nullif(btrim(coalesce(p_principal, '')), ''))
  returning id into v_id;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_action := coalesce(nullif(v_line->>'action', ''), 'ship');
    if v_action not in ('ship', 'record', 'skip') then
      raise exception 'outbound_action %', v_action;
    end if;
    v_pid := nullif(v_line->>'product_id', '')::bigint;
    v_p := null;
    if v_pid is not null then
      select * into v_p from public.products where id = v_pid;
      if v_p.id is null then
        raise exception 'product % not found', v_pid;
      end if;
    end if;
    -- 代理出荷: kept as a record, never taken out of stock.
    if v_action = 'ship' then
      v_action := 'record';
    end if;
    v_qty := greatest(coalesce(public.price_num(v_line->>'quantity'), 0), 0)::integer;
    v_supplier := nullif(btrim(coalesce(v_line->>'supplier', '')), '');
    v_sid := null;
    if v_supplier is not null then
      select id into v_sid from public.delivery_suppliers
       where lower(btrim(name)) = lower(v_supplier) or lower(btrim(coalesce(code, ''))) = lower(v_supplier)
       order by id limit 1;
    end if;
    v_rate := coalesce(public.price_num(v_line->>'tax_rate'), 10);
    v_unit := public.price_num(v_line->>'unit_price');
    v_unit_tax := public.price_num(v_line->>'unit_price_tax');
    if v_unit is null and v_unit_tax is not null then v_unit := round(v_unit_tax / (1 + v_rate / 100), 2); end if;
    if v_unit_tax is null and v_unit is not null then v_unit_tax := round(v_unit * (1 + v_rate / 100), 2); end if;

    v_before := null; v_ship := 0; v_mid := null; v_after := null;
    if v_action = 'ship' and v_qty > 0 then
      select coalesce(sum(on_hand), 0)::integer into v_before from public.stock_levels
       where warehouse_id = p_warehouse_id and jan_code = v_p.jan_code;
      v_ship := least(v_qty, greatest(v_before, 0));
      if v_ship > 0 then
        v_mid := public.apply_stock_movement_detail(p_warehouse_id, v_p.jan_code, -v_ship, 'SHIP',
                   'outbound_file', v_id::text, v_p.name, null,
                   'row ' || coalesce(v_line->>'row_no', '?'), null, null, null, v_pid);
      end if;
      v_after := v_before - v_ship;
    end if;

    insert into public.outbound_file_lines (
      file_id, row_no, jan_code, product_id, product_name, maker, item_code, supplier_name, supplier_id,
      quantity, shipped_quantity, short_quantity, unit_price, unit_price_tax, tax_rate, list_price, amount,
      order_number, arrival, order_date, action, matched_by, on_hand_before, on_hand_after, movement_id, raw)
    values (
      v_id, coalesce(nullif(v_line->>'row_no', '')::integer, 0),
      coalesce(v_p.jan_code, nullif(btrim(coalesce(v_line->>'jan', '')), '')), v_pid,
      coalesce(v_p.name, nullif(btrim(coalesce(v_line->>'product_name', '')), '')),
      nullif(btrim(coalesce(v_line->>'maker', '')), ''), nullif(btrim(coalesce(v_line->>'code', '')), ''),
      v_supplier, v_sid, v_qty, v_ship,
      case when v_action = 'ship' then v_qty - v_ship else 0 end,
      v_unit, v_unit_tax, v_rate, public.price_num(v_line->>'list_price'), public.price_num(v_line->>'amount'),
      nullif(btrim(coalesce(v_line->>'order_number', '')), ''), nullif(btrim(coalesce(v_line->>'arrival', '')), ''),
      nullif(btrim(coalesce(v_line->>'order_date', '')), ''), v_action, nullif(v_line->>'matched_by', ''),
      v_before, v_after, v_mid, v_line->'raw');
  end loop;

  update public.outbound_files f set
    line_count = x.n, quantity_total = x.q, shipped_total = x.s, short_total = x.sh, amount_total = x.a
    from (select count(*) filter (where action <> 'skip') as n,
                 coalesce(sum(quantity) filter (where action <> 'skip'), 0) as q,
                 coalesce(sum(shipped_quantity), 0) as s, coalesce(sum(short_quantity), 0) as sh,
                 sum(coalesce(amount, quantity * unit_price_tax)) filter (where action <> 'skip') as a
            from public.outbound_file_lines where file_id = v_id) x
   where f.id = v_id;

  perform public.log_audit('outbound.proxy_posted', 'outbound_file', v_id::text, p_warehouse_id,
    jsonb_build_object('file', p_file_name, 'shipped_on', p_shipped_on, 'lines', jsonb_array_length(p_lines)));
  return v_id;
end;
$$;
revoke all on function public.proxy_shipment_post(bigint, date, text, jsonb, text, text, integer, text, text, text, text, jsonb, boolean, text) from public, anon;
grant execute on function public.proxy_shipment_post(bigint, date, text, jsonb, text, text, integer, text, text, text, text, jsonb, boolean, text) to authenticated;

-- 出荷リストで出庫 (0188): a file seen before as a 代理出荷 is not a repeat.
create or replace function public.outbound_file_post(
  p_warehouse_id bigint, p_shipped_on date, p_file_name text, p_lines jsonb,
  p_storage_path text default null, p_content_type text default null, p_byte_size integer default null,
  p_fingerprint text default null, p_sheet_name text default null, p_destination text default null,
  p_note text default null, p_columns jsonb default null, p_allow_duplicate boolean default false)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
  v_line jsonb;
  v_action text;
  v_pid bigint;
  v_p public.products;
  v_qty integer;
  v_before integer;
  v_ship integer;
  v_mid bigint;
  v_after integer;
  v_supplier text;
  v_sid bigint;
  v_unit numeric;
  v_unit_tax numeric;
  v_rate numeric;
begin
  if auth.uid() is null then
    raise exception 'not permitted: sign in required';
  end if;
  if not public.can_post_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  if p_warehouse_id is null or not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'outbound_no_lines';
  end if;
  if p_storage_path is not null and p_storage_path not like p_warehouse_id::text || '/%' then
    raise exception 'outbound_file_path';
  end if;
  if not coalesce(p_allow_duplicate, false) and p_fingerprint is not null and exists (
       select 1 from public.outbound_files where fingerprint = p_fingerprint and undone_at is null and kind = 'stock') then
    raise exception 'outbound_duplicate';
  end if;

  insert into public.outbound_files (warehouse_id, shipped_on, file_name, storage_path, content_type, byte_size,
                                     fingerprint, sheet_name, destination, note, columns)
  values (p_warehouse_id, coalesce(p_shipped_on, (now() at time zone 'Asia/Tokyo')::date),
          coalesce(nullif(btrim(coalesce(p_file_name, '')), ''), 'file'), p_storage_path, p_content_type, p_byte_size,
          p_fingerprint, p_sheet_name, nullif(btrim(coalesce(p_destination, '')), ''),
          nullif(btrim(coalesce(p_note, '')), ''), coalesce(p_columns, '{}'::jsonb))
  returning id into v_id;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_action := coalesce(nullif(v_line->>'action', ''), 'ship');
    if v_action not in ('ship', 'record', 'skip') then
      raise exception 'outbound_action %', v_action;
    end if;
    v_pid := nullif(v_line->>'product_id', '')::bigint;
    v_p := null;
    if v_pid is not null then
      select * into v_p from public.products where id = v_pid;
      if v_p.id is null then
        raise exception 'product % not found', v_pid;
      end if;
    end if;
    if v_action = 'ship' and v_pid is null then
      v_action := 'record';
    end if;
    v_qty := greatest(coalesce(public.price_num(v_line->>'quantity'), 0), 0)::integer;
    v_supplier := nullif(btrim(coalesce(v_line->>'supplier', '')), '');
    v_sid := null;
    if v_supplier is not null then
      select id into v_sid from public.delivery_suppliers
       where lower(btrim(name)) = lower(v_supplier) or lower(btrim(coalesce(code, ''))) = lower(v_supplier)
       order by id limit 1;
    end if;
    v_rate := coalesce(public.price_num(v_line->>'tax_rate'), 10);
    v_unit := public.price_num(v_line->>'unit_price');
    v_unit_tax := public.price_num(v_line->>'unit_price_tax');
    if v_unit is null and v_unit_tax is not null then v_unit := round(v_unit_tax / (1 + v_rate / 100), 2); end if;
    if v_unit_tax is null and v_unit is not null then v_unit_tax := round(v_unit * (1 + v_rate / 100), 2); end if;

    v_before := null; v_ship := 0; v_mid := null; v_after := null;
    if v_action = 'ship' and v_qty > 0 then
      select coalesce(sum(on_hand), 0)::integer into v_before from public.stock_levels
       where warehouse_id = p_warehouse_id and jan_code = v_p.jan_code;
      v_ship := least(v_qty, greatest(v_before, 0));
      if v_ship > 0 then
        v_mid := public.apply_stock_movement_detail(p_warehouse_id, v_p.jan_code, -v_ship, 'SHIP',
                   'outbound_file', v_id::text, v_p.name, null,
                   'row ' || coalesce(v_line->>'row_no', '?'), null, null, null, v_pid);
      end if;
      v_after := v_before - v_ship;
    end if;

    insert into public.outbound_file_lines (
      file_id, row_no, jan_code, product_id, product_name, maker, item_code, supplier_name, supplier_id,
      quantity, shipped_quantity, short_quantity, unit_price, unit_price_tax, tax_rate, list_price, amount,
      order_number, arrival, order_date, action, matched_by, on_hand_before, on_hand_after, movement_id, raw)
    values (
      v_id, coalesce(nullif(v_line->>'row_no', '')::integer, 0),
      coalesce(v_p.jan_code, nullif(btrim(coalesce(v_line->>'jan', '')), '')), v_pid,
      coalesce(v_p.name, nullif(btrim(coalesce(v_line->>'product_name', '')), '')),
      nullif(btrim(coalesce(v_line->>'maker', '')), ''), nullif(btrim(coalesce(v_line->>'code', '')), ''),
      v_supplier, v_sid, v_qty, v_ship,
      case when v_action = 'ship' then v_qty - v_ship else 0 end,
      v_unit, v_unit_tax, v_rate, public.price_num(v_line->>'list_price'), public.price_num(v_line->>'amount'),
      nullif(btrim(coalesce(v_line->>'order_number', '')), ''), nullif(btrim(coalesce(v_line->>'arrival', '')), ''),
      nullif(btrim(coalesce(v_line->>'order_date', '')), ''), v_action, nullif(v_line->>'matched_by', ''),
      v_before, v_after, v_mid, v_line->'raw');
  end loop;

  update public.outbound_files f set
    line_count = x.n, quantity_total = x.q, shipped_total = x.s, short_total = x.sh, amount_total = x.a
    from (select count(*) filter (where action <> 'skip') as n,
                 coalesce(sum(quantity) filter (where action <> 'skip'), 0) as q,
                 coalesce(sum(shipped_quantity), 0) as s, coalesce(sum(short_quantity), 0) as sh,
                 sum(coalesce(amount, quantity * unit_price_tax)) filter (where action <> 'skip') as a
            from public.outbound_file_lines where file_id = v_id) x
   where f.id = v_id;

  perform public.log_audit('outbound.file_posted', 'outbound_file', v_id::text, p_warehouse_id,
    jsonb_build_object('file', p_file_name, 'shipped_on', p_shipped_on, 'lines', jsonb_array_length(p_lines)));
  return v_id;
end;
$$;

create or replace function public.outbound_files_list(
  p_from date, p_to date, p_warehouse_id bigint default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.can_view_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  if p_warehouse_id is not null and not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', f.id, 'warehouse_id', f.warehouse_id, 'warehouse_name', w.name, 'shipped_on', f.shipped_on,
             'kind', f.kind, 'principal', f.principal,
             'file_name', f.file_name, 'storage_path', f.storage_path, 'content_type', f.content_type,
             'byte_size', f.byte_size, 'sheet_name', f.sheet_name, 'destination', f.destination, 'note', f.note,
             'line_count', f.line_count, 'quantity_total', f.quantity_total, 'shipped_total', f.shipped_total,
             'short_total', f.short_total, 'amount_total', f.amount_total,
             'weight_g', (select sum(l.shipped_quantity * p.unit_weight_g) from public.outbound_file_lines l
                            join public.products p on p.id = l.product_id where l.file_id = f.id),
             'created_at', f.created_at, 'created_by_name', public.user_display_name(f.created_by),
             'undone_at', f.undone_at) order by f.shipped_on, f.id)
      from public.outbound_files f
      join public.warehouses w on w.id = f.warehouse_id
     where f.shipped_on between coalesce(p_from, '1900-01-01') and coalesce(p_to, '2999-12-31')
       and public.can_access_warehouse(f.warehouse_id)
       and (p_warehouse_id is null or f.warehouse_id = p_warehouse_id)), '[]'::jsonb);
end;
$$;

create or replace function public.outbound_file_detail(p_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_f public.outbound_files;
begin
  if auth.uid() is null or not public.can_view_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  select * into v_f from public.outbound_files where id = p_id;
  if v_f.id is null or not public.can_access_warehouse(v_f.warehouse_id) then
    raise exception 'outbound file % not found', p_id;
  end if;
  return (select jsonb_build_object(
    'id', v_f.id, 'warehouse_id', v_f.warehouse_id, 'warehouse_name', w.name, 'shipped_on', v_f.shipped_on,
    'kind', v_f.kind, 'principal', v_f.principal,
    'file_name', v_f.file_name, 'storage_path', v_f.storage_path, 'content_type', v_f.content_type,
    'byte_size', v_f.byte_size, 'sheet_name', v_f.sheet_name, 'destination', v_f.destination, 'note', v_f.note,
    'columns', v_f.columns, 'line_count', v_f.line_count, 'quantity_total', v_f.quantity_total,
    'shipped_total', v_f.shipped_total, 'short_total', v_f.short_total, 'amount_total', v_f.amount_total,
    'created_at', v_f.created_at, 'created_by_name', public.user_display_name(v_f.created_by),
    'undone_at', v_f.undone_at, 'undone_by_name', public.user_display_name(v_f.undone_by),
    'lines', coalesce((select jsonb_agg(jsonb_build_object(
        'id', l.id, 'row_no', l.row_no, 'jan', l.jan_code, 'product_id', l.product_id,
        'product_name', coalesce(p.name, l.product_name), 'maker', coalesce(l.maker, p.maker),
        'code', coalesce(l.item_code, p.sku), 'supplier', l.supplier_name, 'quantity', l.quantity,
        'shipped_quantity', l.shipped_quantity, 'short_quantity', l.short_quantity,
        'unit_price', l.unit_price, 'unit_price_tax', l.unit_price_tax, 'tax_rate', l.tax_rate,
        'list_price', l.list_price, 'amount', l.amount, 'order_number', l.order_number,
        'arrival', l.arrival, 'order_date', l.order_date, 'action', l.action, 'matched_by', l.matched_by,
        'on_hand_before', l.on_hand_before, 'on_hand_after', l.on_hand_after,
        'unit_weight_g', p.unit_weight_g) order by l.row_no, l.id)
      from public.outbound_file_lines l
      left join public.products p on p.id = l.product_id
     where l.file_id = v_f.id), '[]'::jsonb))
    from public.warehouses w where w.id = v_f.warehouse_id);
end;
$$;

-- 仕入れ値 points (0187/0188) without the 代理出荷's.
create or replace function public.purchase_price_points(p_product_id bigint)
returns table (id text, source text, day date, supplier_id bigint, supplier_name text, unit_price numeric,
               tax_rate numeric, quantity integer, import_id bigint, file_id bigint, line_no integer,
               file_name text, kind text, note text, entry_id bigint)
language sql stable security definer set search_path = '' as $$
  select r.id, 'receipt', r.day, r.supplier_id, r.supplier_name, r.unit_price, r.tax_rate, r.quantity,
         r.import_id, null::bigint, r.line_no, r.file_name, r.kind, null::text, null::bigint
    from public.receipt_price_points(p_product_id) r
  union all
  select 'm' || e.id, 'manual', e.priced_on, e.supplier_id,
         coalesce(nullif(btrim(s.name), ''), nullif(btrim(e.supplier_name), '')),
         e.unit_price, e.tax_rate, e.quantity, null, null, null, null, null, e.note, e.id
    from public.purchase_price_entries e
    left join public.delivery_suppliers s on s.id = e.supplier_id
   where e.product_id = p_product_id and e.removed_at is null
  union all
  select 'o' || l.id, 'outbound', f.shipped_on, l.supplier_id,
         coalesce(nullif(btrim(s.name), ''), nullif(btrim(l.supplier_name), '')),
         l.unit_price, coalesce(l.tax_rate, 10), l.quantity, null, f.id, l.row_no, f.file_name, null, null, null
    from public.outbound_file_lines l
    join public.outbound_files f on f.id = l.file_id
    left join public.delivery_suppliers s on s.id = l.supplier_id
   where l.product_id = p_product_id and f.undone_at is null and l.action <> 'skip' and f.kind = 'stock'
     and l.unit_price > 0 and public.can_access_warehouse(f.warehouse_id);
$$;
