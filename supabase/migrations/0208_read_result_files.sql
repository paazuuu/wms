-- 0208: the reading kept as Excel beside the file read. Every file read in —
-- a shipping list (出庫), a customer's wish list, a site's stock abroad —
-- may be an Excel, a CSV, a PDF or a photo; what was read from it (the rows
-- as checked) is saved as an Excel in the same bucket as the file, to
-- download again with it.
-- * read_path on outbound_files, purchase_requests, overseas_stock_imports.
-- * outbound_file_set_read_path(id, path), overseas_stock_set_read_path(id,
--   path); purchase_request_set_file takes 'read_path'.
-- * outbound_files_list / outbound_file_detail / overseas_stock_imports say
--   it (purchase_request_get and overseas_stock_lines give the whole row).

alter table public.outbound_files add column if not exists read_path text;
alter table public.purchase_requests add column if not exists read_path text;
alter table public.overseas_stock_imports add column if not exists read_path text;

create or replace function public.outbound_file_set_read_path(p_id bigint, p_path text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_wh bigint;
begin
  select warehouse_id into v_wh from public.outbound_files where id = p_id;
  if v_wh is null then
    raise exception 'outbound file % not found', p_id;
  end if;
  if not (public.can_post_outbound() and public.can_access_warehouse(v_wh)) then
    raise exception 'not permitted';
  end if;
  update public.outbound_files set read_path = nullif(p_path, '') where id = p_id;
  return true;
end;
$$;
revoke all on function public.outbound_file_set_read_path(bigint, text) from public, anon;
grant execute on function public.outbound_file_set_read_path(bigint, text) to authenticated;

create or replace function public.overseas_stock_set_read_path(p_id bigint, p_path text)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if not public.overseas_can_edit() then
    raise exception 'not permitted';
  end if;
  update public.overseas_stock_imports set read_path = nullif(p_path, '') where id = p_id;
  return found;
end;
$$;
revoke all on function public.overseas_stock_set_read_path(bigint, text) from public, anon;
grant execute on function public.overseas_stock_set_read_path(bigint, text) to authenticated;

do $$
declare
  d text;
  r text;
begin
  d := pg_get_functiondef('public.purchase_request_set_file(bigint, jsonb)'::regprocedure);
  r := replace(d, '    columns = case', '    read_path = nullif(p_file->>''read_path'', ''''),' || chr(10) || '    columns = case');
  if r = d then
    raise exception 'purchase_request_set_file: the text to change was not found';
  end if;
  execute r;

  d := pg_get_functiondef('public.outbound_file_detail(bigint)'::regprocedure);
  r := replace(d, '''storage_path'', v_f.storage_path,', '''storage_path'', v_f.storage_path, ''read_path'', v_f.read_path,');
  if r = d then
    raise exception 'outbound_file_detail: the text to change was not found';
  end if;
  execute r;

  d := pg_get_functiondef('public.outbound_files_list(date, date, bigint)'::regprocedure);
  r := replace(d, '''storage_path'', f.storage_path,', '''storage_path'', f.storage_path, ''read_path'', f.read_path,');
  if r = d then
    raise exception 'outbound_files_list: the text to change was not found';
  end if;
  execute r;

  d := pg_get_functiondef('public.overseas_stock_imports(bigint)'::regprocedure);
  r := replace(d, '''storage_path'', i.storage_path,', '''storage_path'', i.storage_path, ''read_path'', i.read_path,');
  if r = d then
    raise exception 'overseas_stock_imports: the text to change was not found';
  end if;
  execute r;
end;
$$;
