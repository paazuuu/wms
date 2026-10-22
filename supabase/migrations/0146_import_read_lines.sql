-- 0146: what a file was read as, kept with its import.
--
-- A stock file (0144) is read in the app (a sheet) or by the AI (a PDF, a
-- scan, a photo). What it was read as — every row with the file's own JAN,
-- name and quantity, and what the AI was unsure of — was not kept, so the
-- import could show what went in but not what the file said. It is kept now,
-- so the import can be opened beside its original and the two compared.
--
-- Additive: two nullable columns, and a function that notes the reading on
-- an import right after stock_file_import made it (as the original file is
-- attached by stock_file_import_attach). stock_file_import is unchanged.

alter table public.master_imports add column if not exists read_lines jsonb;
alter table public.master_imports add column if not exists read_by text;
comment on column public.master_imports.read_lines is
  'What the file was read as (0146): a row each, with the file''s JAN, name and quantity and the reader''s doubts.';
comment on column public.master_imports.read_by is
  '0146: ai (PDF, scan, photo, read by the AI) or sheet (Excel/CSV read cell by cell).';

-- Once per import: a reading already noted is not replaced.
create or replace function public.stock_file_import_note(p_id bigint, p_read jsonb, p_read_by text default null, p_document_id bigint default null)
returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_permission('inventory.adjust') then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  update public.master_imports set
    read_lines = case when jsonb_typeof(p_read) = 'array' then p_read else read_lines end,
    read_by = case when p_read_by in ('ai', 'sheet') then p_read_by else read_by end,
    document_id = coalesce(p_document_id, document_id),
    updated_at = now()
   where id = p_id and source = 'stock_file' and read_lines is null;
  return found;
end;
$$;
revoke all on function public.stock_file_import_note(bigint, jsonb, text, bigint) from public, anon;
grant execute on function public.stock_file_import_note(bigint, jsonb, text, bigint) to authenticated, service_role;
