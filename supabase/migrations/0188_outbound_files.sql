-- 0188: 出荷リストで出庫 — the shipping list people already keep (an .xlsx
-- such as the 明细 sheet: 供货商, 品牌, 品番, ジャパンコード, 数量, 单价…),
-- read in whatever language its headings are, matched by JAN first, and
-- taken out of stock line by line; kept with its file, by day (出庫カレンダー).
--
-- * Bucket outbound-files (private): <warehouse id>/<file>, put in by whoever
--   may ship from that warehouse, read by whoever may see its shipments.
-- * outbound_files: one upload — the day shipped, the warehouse, the file,
--   which column meant what, the totals; undone_at when taken back.
-- * outbound_file_lines: each row — as read (JAN, 品番, maker, supplier,
--   quantity, 税抜/税込 price, amount, 注番, 到货时间, the row itself), how
--   its product was found (jan / barcode / code / picked), what was done
--   (ship: taken out of stock; record: kept with no stock moved; skip), how
--   many went out and how many were short (stock never goes below 0).
-- * outbound_match(lines, warehouse): for each row its product — by JAN or
--   another barcode, else by 品番 (the product's, a supplier's code for it,
--   the 価格台帳's) narrowed by maker — its stock there and last 仕入れ値.
-- * outbound_file_post / outbound_file_undo / outbound_files_list /
--   outbound_file_detail.
-- * A row's supplier and price are also 仕入れ値 points (0187, 'outbound').
-- * product_stock_history (0145) names the file of a shipment from one.

insert into storage.buckets (id, name, public, file_size_limit)
values ('outbound-files', 'outbound-files', false, 52428800)
on conflict (id) do nothing;

create or replace function public.can_post_outbound()
returns boolean
language sql stable security definer set search_path = '' as $$
  select public.has_permission('ship.complete') or public.has_permission('pack.complete')
      or public.has_permission('inventory.adjust');
$$;
grant execute on function public.can_post_outbound() to authenticated;

create or replace function public.can_view_outbound()
returns boolean
language sql stable security definer set search_path = '' as $$
  select public.can_post_outbound() or public.has_permission('inventory.view')
      or public.has_permission('report.view') or public.has_permission('sales_order.view');
$$;
grant execute on function public.can_view_outbound() to authenticated;

-- [p_name]: <warehouse id>/<file>.
create or replace function public.outbound_file_allowed(p_name text, p_write boolean)
returns boolean
language sql stable security definer set search_path = '' as $$
  select split_part(coalesce(p_name, ''), '/', 1) ~ '^[0-9]+$'
     and public.can_access_warehouse(split_part(p_name, '/', 1)::bigint)
     and case when p_write then public.can_post_outbound() else public.can_view_outbound() end;
$$;
grant execute on function public.outbound_file_allowed(text, boolean) to authenticated;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'outbound-files: shippers upload') then
    create policy "outbound-files: shippers upload" on storage.objects
      for insert to authenticated
      with check (bucket_id = 'outbound-files' and public.outbound_file_allowed(name, true));
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'outbound-files: viewers read') then
    create policy "outbound-files: viewers read" on storage.objects
      for select to authenticated
      using (bucket_id = 'outbound-files' and public.outbound_file_allowed(name, false));
  end if;
end $$;

create table if not exists public.outbound_files (
  id bigint generated always as identity primary key,
  warehouse_id bigint not null references public.warehouses(id),
  shipped_on date not null,
  file_name text not null,
  storage_path text unique,
  content_type text,
  byte_size integer,
  fingerprint text,
  sheet_name text,
  destination text,
  note text,
  columns jsonb not null default '{}'::jsonb,
  line_count integer not null default 0,
  quantity_total integer not null default 0,
  shipped_total integer not null default 0,
  short_total integer not null default 0,
  amount_total numeric(16, 2),
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  undone_at timestamptz,
  undone_by uuid
);
alter table public.outbound_files enable row level security;
create index if not exists outbound_files_day on public.outbound_files (warehouse_id, shipped_on);
create index if not exists outbound_files_fingerprint on public.outbound_files (fingerprint) where undone_at is null;

create table if not exists public.outbound_file_lines (
  id bigint generated always as identity primary key,
  file_id bigint not null references public.outbound_files(id),
  row_no integer not null,
  jan_code text,
  product_id bigint references public.products(id),
  product_name text,
  maker text,
  item_code text,
  supplier_name text,
  supplier_id bigint references public.delivery_suppliers(id),
  quantity integer not null default 0,
  shipped_quantity integer not null default 0,
  short_quantity integer not null default 0,
  unit_price numeric(14, 2),
  unit_price_tax numeric(14, 2),
  tax_rate numeric(5, 2),
  list_price numeric(14, 2),
  amount numeric(16, 2),
  order_number text,
  arrival text,
  order_date text,
  action text not null default 'ship' check (action in ('ship', 'record', 'skip')),
  matched_by text,
  on_hand_before integer,
  on_hand_after integer,
  movement_id bigint,
  raw jsonb
);
alter table public.outbound_file_lines enable row level security;
create index if not exists outbound_file_lines_file on public.outbound_file_lines (file_id, row_no);
create index if not exists outbound_file_lines_product on public.outbound_file_lines (product_id);

-- 品番 as compared: capitals, no spaces, hyphens, dots or slashes.
create or replace function public.item_code_key(p text)
returns text
language sql immutable set search_path = '' as $$
  select nullif(upper(regexp_replace(
    translate(coalesce(p, ''), 'ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ０１２３４５６７８９',
                                'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'),
    '[\s　\-－_‐・．\.／/]+', '', 'g')), '');
$$;

-- [p_lines]: [{jan, code, maker}], in the file's order. For each: the
-- product found and how, its stock in [p_warehouse_id], its weight and last
-- 仕入れ値; several candidates when a 品番 fits more than one.
create or replace function public.outbound_match(p_lines jsonb, p_warehouse_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_out jsonb := '[]'::jsonb;
  v_line jsonb;
  v_i integer := 0;
  v_jan text;
  v_code text;
  v_maker text;
  v_pid bigint;
  v_by text;
  v_ids bigint[];
  v_narrow bigint[];
  v_p public.products;
  v_on_hand integer;
  v_last numeric;
  v_last_day date;
  v_cands jsonb;
begin
  if auth.uid() is null then
    raise exception 'not permitted: sign in required';
  end if;
  if not public.can_view_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  if p_warehouse_id is not null and not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  for v_line in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_pid := null; v_by := 'none'; v_ids := null; v_cands := '[]'::jsonb;
    v_jan := nullif(regexp_replace(translate(coalesce(v_line->>'jan', ''), '０１２３４５６７８９', '0123456789'), '[^0-9]', '', 'g'), '');
    v_code := public.item_code_key(v_line->>'code');
    v_maker := nullif(btrim(coalesce(v_line->>'maker', '')), '');
    if v_jan is not null then
      select id into v_pid from public.products where jan_code = v_jan;
      if v_pid is not null then
        v_by := 'jan';
      else
        select product_id into v_pid from public.product_barcodes where barcode = v_jan order by is_primary desc nulls last limit 1;
        if v_pid is not null then v_by := 'barcode'; end if;
      end if;
    end if;
    if v_pid is null and v_code is not null then
      select array_agg(distinct x) into v_ids from (
        select id as x from public.products where public.item_code_key(sku) = v_code
        union select product_id from public.supplier_product_names
         where product_id is not null and coalesce(is_active, true)
           and (public.item_code_key(supplier_code) = v_code or public.item_code_key(supplier_model_number) = v_code)
        union select product_id from public.price_book_items
         where product_id is not null and public.item_code_key(item_code) = v_code) c;
      if coalesce(array_length(v_ids, 1), 0) > 1 and v_maker is not null then
        select array_agg(id) into v_narrow from public.products
         where id = any(v_ids) and maker is not null
           and (strpos(lower(maker), lower(v_maker)) > 0 or strpos(lower(v_maker), lower(maker)) > 0);
        if coalesce(array_length(v_narrow, 1), 0) >= 1 then v_ids := v_narrow; end if;
      end if;
      if coalesce(array_length(v_ids, 1), 0) = 1 then
        v_pid := v_ids[1]; v_by := 'code';
      elsif coalesce(array_length(v_ids, 1), 0) > 1 then
        select coalesce(jsonb_agg(jsonb_build_object('product_id', id, 'jan', jan_code, 'name', name,
                 'maker', maker, 'sku', sku) order by name), '[]'::jsonb)
          into v_cands from public.products where id = any(v_ids);
        v_by := 'several';
      end if;
    end if;
    v_on_hand := null; v_last := null; v_last_day := null;
    if v_pid is not null then
      select * into v_p from public.products where id = v_pid;
      select coalesce(sum(on_hand), 0)::integer into v_on_hand from public.stock_levels
       where warehouse_id = p_warehouse_id and (product_id = v_pid or jan_code = v_p.jan_code);
      if public.can_view_purchase_prices() then
        select x.unit_price, x.day into v_last, v_last_day
          from public.purchase_price_points(v_pid) x
         where x.source <> 'outbound' order by x.day desc, x.id desc limit 1;
      end if;
    end if;
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'i', v_i, 'matched_by', v_by, 'product_id', v_pid,
      'jan', case when v_pid is not null then v_p.jan_code end,
      'name', case when v_pid is not null then v_p.name end,
      'maker', case when v_pid is not null then v_p.maker end,
      'sku', case when v_pid is not null then v_p.sku end,
      'unit_weight_g', case when v_pid is not null then v_p.unit_weight_g end,
      'on_hand', v_on_hand, 'last_price', v_last, 'last_price_day', v_last_day,
      'candidates', v_cands));
    v_i := v_i + 1;
  end loop;
  return v_out;
end;
$$;
revoke all on function public.outbound_match(jsonb, bigint) from public, anon;
grant execute on function public.outbound_match(jsonb, bigint) to authenticated;

-- One upload, posted. [p_lines]: [{row_no, jan, product_id, product_name,
-- maker, code, supplier, quantity, unit_price, unit_price_tax, tax_rate,
-- list_price, amount, order_number, arrival, order_date, action, matched_by,
-- raw}]. A 'ship' line takes out what there is, up to its quantity; the
-- rest is its short. The same file twice raises outbound_duplicate unless
-- [p_allow_duplicate].
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
       select 1 from public.outbound_files where fingerprint = p_fingerprint and undone_at is null) then
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
revoke all on function public.outbound_file_post(bigint, date, text, jsonb, text, text, integer, text, text, text, text, jsonb, boolean) from public, anon;
grant execute on function public.outbound_file_post(bigint, date, text, jsonb, text, text, integer, text, text, text, text, jsonb, boolean) to authenticated;

-- Taken back: what went out comes back in (SHIP_CANCEL); the file and its
-- lines stay, marked undone.
create or replace function public.outbound_file_undo(p_id bigint)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_f public.outbound_files;
  v_l public.outbound_file_lines;
  v_n integer := 0;
begin
  if auth.uid() is null or not public.can_post_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  select * into v_f from public.outbound_files where id = p_id for update;
  if v_f.id is null or not public.can_access_warehouse(v_f.warehouse_id) then
    raise exception 'outbound file % not found', p_id;
  end if;
  if v_f.undone_at is not null then
    raise exception 'outbound_already_undone';
  end if;
  for v_l in select * from public.outbound_file_lines where file_id = p_id and shipped_quantity > 0 loop
    perform public.apply_stock_movement_detail(v_f.warehouse_id, v_l.jan_code, v_l.shipped_quantity, 'SHIP_CANCEL',
              'outbound_file', p_id::text, v_l.product_name, null, 'undo row ' || v_l.row_no,
              null, null, null, v_l.product_id);
    v_n := v_n + v_l.shipped_quantity;
  end loop;
  update public.outbound_files set undone_at = now(), undone_by = auth.uid() where id = p_id;
  perform public.log_audit('outbound.file_undone', 'outbound_file', p_id::text, v_f.warehouse_id,
    jsonb_build_object('file', v_f.file_name, 'returned', v_n));
  return v_n;
end;
$$;
revoke all on function public.outbound_file_undo(bigint) from public, anon;
grant execute on function public.outbound_file_undo(bigint) to authenticated;

-- 出庫カレンダー: the uploads shipped between two days (undone ones too,
-- marked), the earliest first.
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
revoke all on function public.outbound_files_list(date, date, bigint) from public, anon;
grant execute on function public.outbound_files_list(date, date, bigint) to authenticated;

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
revoke all on function public.outbound_file_detail(bigint) from public, anon;
grant execute on function public.outbound_file_detail(bigint) to authenticated;

-- 仕入れ値 points (0187) with the 出荷リスト's.
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
   where l.product_id = p_product_id and f.undone_at is null and l.action <> 'skip'
     and l.unit_price > 0 and public.can_access_warehouse(f.warehouse_id);
$$;
revoke all on function public.purchase_price_points(bigint) from public, anon, authenticated;

-- 0145's product history, naming the 出荷リスト a shipment came from.
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
           m.reference_type, m.reference_id, m.note, mi.id as import_id, coalesce(mi.original_name, ob.file_name) as file_name, mi.source,
           public.stock_movement_method(m.movement_type, m.reference_type, mi.source) as method
      from public.stock_movements m
      left join public.warehouses w on w.id = m.warehouse_id
      left join public.master_imports mi
        on m.reference_type = 'master_import' and mi.id::text = m.reference_id
      left join public.outbound_files ob
        on m.reference_type = 'outbound_file' and ob.id::text = m.reference_id
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
