-- 0147: a stock file cannot go in twice by mistake, and can be taken back.
--
-- Adding stock from a file is the one kind of import where doing it twice
-- is silently wrong: the same delivery note read again doubles the stock.
-- So each import keeps two fingerprints — of the file's bytes, and of what
-- went in (JAN and quantity, sorted) — and the app asks before putting in a
-- file, or a corrected copy of one, whose fingerprint an import already has.
-- And an import can be undone: every line's change is booked back, as long as
-- no product would be left below zero (stock since shipped is not undone).
--
-- Additive: four nullable columns and three functions; nothing removed.

alter table public.master_imports add column if not exists file_fingerprint text;
alter table public.master_imports add column if not exists lines_fingerprint text;
alter table public.master_imports add column if not exists undone_at timestamptz;
alter table public.master_imports add column if not exists undone_by uuid;
create index if not exists master_imports_file_fp_idx on public.master_imports (file_fingerprint);
create index if not exists master_imports_lines_fp_idx on public.master_imports (lines_fingerprint);

-- The two fingerprints, noted right after the import (as the reading is).
create or replace function public.stock_file_import_fingerprint(p_id bigint, p_file text, p_lines text)
returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_permission('inventory.adjust') then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  update public.master_imports set
    file_fingerprint = coalesce(file_fingerprint, nullif(btrim(coalesce(p_file, '')), '')),
    lines_fingerprint = coalesce(lines_fingerprint, nullif(btrim(coalesce(p_lines, '')), '')),
    updated_at = now()
   where id = p_id and source = 'stock_file';
  return found;
end;
$$;
revoke all on function public.stock_file_import_fingerprint(bigint, text, text) from public, anon;
grant execute on function public.stock_file_import_fingerprint(bigint, text, text) to authenticated, service_role;

-- Imports already in (not undone) with the same file or the same lines.
create or replace function public.stock_file_import_duplicates(p_file text, p_lines text)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when not public.master_import_viewer() then '[]'::jsonb else coalesce((
    select jsonb_agg(jsonb_build_object(
             'import_id', m.id, 'at', coalesce(m.stock_at, m.created_at), 'file_name', m.original_name,
             'warehouse_name', w.name, 'lines', m.stock_lines, 'change', m.stock_added,
             'same_file', m.file_fingerprint = p_file, 'same_lines', m.lines_fingerprint = p_lines)
           order by m.id desc)
      from public.master_imports m
      left join public.warehouses w on w.id = m.warehouse_id
     where m.source = 'stock_file' and m.status = 'stock_done' and m.undone_at is null
       and ((p_file is not null and m.file_fingerprint = p_file) or (p_lines is not null and m.lines_fingerprint = p_lines))
  ), '[]'::jsonb) end;
$$;
revoke all on function public.stock_file_import_duplicates(text, text) from public, anon;
grant execute on function public.stock_file_import_duplicates(text, text) to authenticated, service_role;

-- Takes a stock file back: each line's change booked the other way, in one
-- go. Refused when it would leave a product below zero in the warehouse.
create or replace function public.stock_file_import_undo(p_id bigint)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_imp public.master_imports;
  l record;
  v_now int;
  v_name text;
  v_lines int := 0;
  v_change int := 0;
begin
  if not public.has_permission('inventory.adjust') then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  select * into v_imp from public.master_imports where id = p_id for update;
  if v_imp.id is null or v_imp.source <> 'stock_file' then
    raise exception 'import % not found', p_id;
  end if;
  if v_imp.undone_at is not null then
    raise exception 'import % is already undone', p_id;
  end if;
  if v_imp.warehouse_id is null or not public.can_access_warehouse(v_imp.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  -- Every line first, so nothing is booked unless all of it can be.
  for l in select * from public.master_import_lines where import_id = p_id and coalesce(added, 0) <> 0 loop
    select coalesce(on_hand, 0) into v_now from public.stock_levels
     where warehouse_id = v_imp.warehouse_id and jan_code = l.jan_code for update;
    if coalesce(v_now, 0) - l.added < 0 then
      raise exception 'undo would leave % below zero (now %, the import added %)', l.jan_code, coalesce(v_now, 0), l.added;
    end if;
  end loop;
  for l in select * from public.master_import_lines where import_id = p_id and coalesce(added, 0) <> 0 order by line_no loop
    select name into v_name from public.products where id = l.product_id;
    perform public.master_import_post(v_imp.warehouse_id, l.jan_code, l.product_id, -l.added, 'CORRECTION',
      '在庫ファイル取込 #' || p_id || ' の取り消し', p_id::text, v_name);
    v_lines := v_lines + 1;
    v_change := v_change - l.added;
  end loop;
  update public.master_imports set undone_at = now(), undone_by = auth.uid(), status = 'cancelled', updated_at = now()
   where id = p_id;
  perform public.log_audit('inventory.stock_file_undone', 'master_import', p_id::text, v_imp.warehouse_id,
    jsonb_build_object('lines', v_lines, 'change', v_change));
  return jsonb_build_object('import_id', p_id, 'lines', v_lines, 'change', v_change);
end;
$$;
revoke all on function public.stock_file_import_undo(bigint) from public, anon;
grant execute on function public.stock_file_import_undo(bigint) to authenticated, service_role;
