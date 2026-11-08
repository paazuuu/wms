-- 0206: 入荷希望リストをファイルから (the customer's own wish list, an
-- Excel or CSV, read as the 出荷明細 is). The file is kept, as a shipping
-- list's is (0188), to look at again from the list:
-- * bucket 'wish-files' (<'wish'>/<time>-<name>); written by those who may
--   edit the lists, read by those who may see them.
-- * purchase_requests gets file_name, storage_path, file_size,
--   file_fingerprint, sheet_name, columns (what each column was read as).
-- * purchase_request_set_file(id, file): sets them (null: no file).
-- * purchase_requests_list also says the file's name.

insert into storage.buckets (id, name, public, file_size_limit)
values ('wish-files', 'wish-files', false, 52428800)
on conflict (id) do nothing;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'wish-files: editors upload') then
    create policy "wish-files: editors upload" on storage.objects
      for insert to authenticated
      with check (bucket_id = 'wish-files' and public.purchase_request_can_edit());
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'wish-files: viewers read') then
    create policy "wish-files: viewers read" on storage.objects
      for select to authenticated
      using (bucket_id = 'wish-files' and public.purchase_request_can_view());
  end if;
end $$;

alter table public.purchase_requests
  add column if not exists file_name text,
  add column if not exists storage_path text,
  add column if not exists file_size bigint,
  add column if not exists file_fingerprint text,
  add column if not exists sheet_name text,
  add column if not exists columns jsonb;

create or replace function public.purchase_request_set_file(p_id bigint, p_file jsonb)
returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not public.purchase_request_can_edit() then
    raise exception 'not permitted: purchase_order.manage required';
  end if;
  update public.purchase_requests set
    file_name = nullif(p_file->>'file_name', ''),
    storage_path = nullif(p_file->>'storage_path', ''),
    file_size = (p_file->>'file_size')::bigint,
    file_fingerprint = nullif(p_file->>'fingerprint', ''),
    sheet_name = nullif(p_file->>'sheet_name', ''),
    columns = case when jsonb_typeof(p_file->'columns') = 'object' then p_file->'columns' end,
    updated_at = now()
   where id = p_id and status <> 'removed';
  if not found then
    raise exception 'request % not found', p_id;
  end if;
  return true;
end;
$$;
revoke all on function public.purchase_request_set_file(bigint, jsonb) from public, anon;
grant execute on function public.purchase_request_set_file(bigint, jsonb) to authenticated;

do $$
declare
  d text;
  r text;
begin
  d := pg_get_functiondef('public.purchase_requests_list(integer)'::regprocedure);
  r := replace(d, 'r.wanted_by, r.status, r.created_at,', 'r.wanted_by, r.status, r.file_name, r.storage_path, r.created_at,');
  if r = d then
    raise exception 'purchase_requests_list: the text to change was not found';
  end if;
  execute r;
end;
$$;
