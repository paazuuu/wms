-- 0144: stock from a file, on its own.
--
-- Products come in from files through 価格台帳 only (file → 価格台帳 →
-- 商品ライブラリーに登録). The stock is a separate, simpler file: a JAN and
-- a quantity a row, for one warehouse, read by the app without AI. It is
-- kept in master_imports like the 0138 imports (source 'stock_file'), so
-- every file that changed stock is in one history with its original.
--
-- Additive: no table, column or row is removed. The 0138 functions stay
-- for the imports already made.

-- One file's stock into one warehouse, in one go.
--   p_mode  'add' — each quantity is added to what is there;
--           'set' — the stock becomes each quantity.
--   p_lines [{line_no, jan_code, quantity}]
-- A JAN that no product in 商品ライブラリー has is not booked; it comes
-- back in "skipped" (the app stops before sending one, so this is a guard).
create or replace function public.stock_file_import(
  p_warehouse_id bigint, p_mode text, p_lines jsonb, p_file_name text default null, p_file_type text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
  e jsonb;
  v_no int := 0;
  v_jan text;
  v_qty int;
  v_product bigint;
  v_name text;
  v_before int;
  v_delta int;
  v_m bigint;
  v_lines int := 0;
  v_added int := 0;
  v_skipped jsonb := '[]'::jsonb;
  v_out jsonb := '[]'::jsonb;
begin
  if not public.has_permission('inventory.adjust') then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  if p_warehouse_id is null or not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if p_mode not in ('add', 'set') then
    raise exception 'unknown mode %', p_mode;
  end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'no lines to put in';
  end if;

  insert into public.master_imports (company_id, status, source, warehouse_id, original_name, original_type, line_count)
  values ((select id from public.companies order by id limit 1), 'stock_done', 'stock_file', p_warehouse_id,
          public.tidy_text(p_file_name), public.tidy_text(p_file_type), jsonb_array_length(p_lines))
  returning id into v_id;

  for e in select x.value from jsonb_array_elements(p_lines) as x(value) loop
    v_no := coalesce(nullif(btrim(coalesce(e->>'line_no', '')), '')::int, v_no + 1);
    v_jan := nullif(btrim(coalesce(e->>'jan_code', '')), '');
    v_qty := coalesce(nullif(btrim(coalesce(e->>'quantity', '')), '')::int, 0);
    if v_jan is null then
      raise exception 'line %: a JAN is required', v_no;
    end if;
    if v_qty < 0 then
      raise exception 'line %: a quantity cannot be negative', v_no;
    end if;
    select id, name into v_product, v_name from public.products where jan_code = v_jan order by id limit 1;
    if v_product is null then
      v_skipped := v_skipped || jsonb_build_object('line_no', v_no, 'jan_code', v_jan);
      continue;
    end if;
    select on_hand into v_before from public.stock_levels
     where warehouse_id = p_warehouse_id and jan_code = v_jan for update;
    v_before := coalesce(v_before, 0);
    v_delta := case when p_mode = 'set' then v_qty - v_before else v_qty end;
    v_m := public.master_import_post(p_warehouse_id, v_jan, v_product, v_delta,
      case when p_mode = 'set' then 'CORRECTION' else 'OTHER' end,
      case when p_mode = 'set' then '在庫ファイル取込 #' || v_id || ' で数を合わせた'
           else '在庫ファイル取込 #' || v_id || ' で追加' end,
      v_id::text, v_name);
    update public.stock_levels set product_name = coalesce(v_name, product_name), product_id = coalesce(product_id, v_product)
     where warehouse_id = p_warehouse_id and jan_code = v_jan;
    insert into public.master_import_lines
      (import_id, line_no, jan_code, product_id, quantity, on_hand_before, on_hand_set, added, on_hand_after, movement_ids)
    values (v_id, v_no, v_jan, v_product, v_qty, v_before,
            case when p_mode = 'set' then v_qty end, v_delta, v_before + v_delta,
            array_remove(array[v_m], null));
    v_lines := v_lines + 1;
    v_added := v_added + v_delta;
    v_out := v_out || jsonb_build_object('line_no', v_no, 'jan_code', v_jan, 'before', v_before,
                                         'change', v_delta, 'after', v_before + v_delta);
  end loop;

  update public.master_imports set
    stock_lines = v_lines, stock_added = v_added, stock_at = now(), stock_by = auth.uid(),
    issues = case when jsonb_array_length(v_skipped) > 0
                  then jsonb_build_array(jsonb_build_object('code', 'unknown_jan', 'lines', v_skipped))
                  else '[]'::jsonb end,
    updated_at = now()
   where id = v_id;
  perform public.log_audit('inventory.stock_file_imported', 'master_import', v_id::text, p_warehouse_id,
    jsonb_build_object('mode', p_mode, 'lines', v_lines, 'change', v_added, 'skipped', jsonb_array_length(v_skipped)));
  return jsonb_build_object('import_id', v_id, 'lines', v_lines, 'change', v_added, 'skipped', v_skipped, 'detail', v_out);
end;
$$;
revoke all on function public.stock_file_import(bigint, text, jsonb, text, text) from public, anon;
grant execute on function public.stock_file_import(bigint, text, jsonb, text, text) to authenticated, service_role;

-- The file a stock import was read from, kept with it — by whoever may
-- adjust stock, who need not manage products.
create or replace function public.stock_file_import_attach(p_id bigint, p_name text, p_path text)
returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_permission('inventory.adjust') then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  if p_path is null or p_path not like 'imports/' || p_id || '/%' then
    raise exception 'the file must be kept under imports/%/', p_id;
  end if;
  update public.master_imports set
    original_name = coalesce(public.tidy_text(p_name), original_name), original_path = p_path, updated_at = now()
   where id = p_id and source = 'stock_file' and original_path is null;
  return found;
end;
$$;
revoke all on function public.stock_file_import_attach(bigint, text, text) from public, anon;
grant execute on function public.stock_file_import_attach(bigint, text, text) to authenticated, service_role;

do $$
begin
  create policy "master-import-files: stock adjusters upload" on storage.objects
    for insert to authenticated
    with check (bucket_id = 'master-import-files' and public.has_permission('inventory.adjust'));
exception when duplicate_object then null;
end $$;

comment on function public.stock_file_import(bigint, text, jsonb, text, text) is
  'Stock from a file (0144): JAN and quantity a row into one warehouse, added or set, kept in master_imports as source stock_file.';
