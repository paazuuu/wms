-- 0210: a stock list becomes 出庫済み only with a 出荷先カード.
--
-- Where it went is part of shipping it: 国外の仮想在庫 (0209) counts by card,
-- the packing list and the export papers read it. So:
--   * outbound_card_required: a deferred constraint trigger on
--     outbound_files. When a stock list turns 'shipped' (an insert by
--     outbound_file_post, or the update by outbound_file_confirm), it must
--     have a card by the end of that transaction, or the whole step is
--     refused with 'outbound_card_required'. Lists already shipped are left
--     as they are; 在庫外出荷 (kind 'proxy') is not touched.
--   * outbound_file_post_to: outbound_file_post and the card in one step,
--     for 出庫 straight from the import screen.
--   * outbound_auto_ship: the night run leaves a list without a card
--     planned (it waits like a short one) instead of failing the run.

create or replace function public.outbound_card_check()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_f public.outbound_files;
begin
  -- Deferred: read the row as it is at the end of the transaction.
  select * into v_f from public.outbound_files where id = new.id;
  if v_f.id is null then
    return null;
  end if;
  if v_f.kind = 'stock' and v_f.status = 'shipped' and v_f.undone_at is null and v_f.destination_id is null then
    raise exception 'outbound_card_required';
  end if;
  return null;
end;
$$;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'outbound_card_required'
                   and tgrelid = 'public.outbound_files'::regclass) then
    create constraint trigger outbound_card_required
      after insert or update of status on public.outbound_files
      deferrable initially deferred
      for each row
      when (new.kind = 'stock' and new.status = 'shipped')
      execute function public.outbound_card_check();
  end if;
end $$;

-- 出庫 now from the import screen, with its card, in one transaction.
create or replace function public.outbound_file_post_to(
  p_destination_id bigint,
  p_warehouse_id bigint,
  p_shipped_on date,
  p_file_name text,
  p_lines jsonb,
  p_storage_path text default null,
  p_content_type text default null,
  p_byte_size integer default null,
  p_fingerprint text default null,
  p_sheet_name text default null,
  p_destination text default null,
  p_note text default null,
  p_columns jsonb default null,
  p_allow_duplicate boolean default false)
returns bigint
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_id bigint;
begin
  if p_destination_id is null then
    raise exception 'outbound_card_required';
  end if;
  v_id := public.outbound_file_post(p_warehouse_id, p_shipped_on, p_file_name, p_lines, p_storage_path,
            p_content_type, p_byte_size, p_fingerprint, p_sheet_name, p_destination, p_note, p_columns,
            p_allow_duplicate);
  perform public.outbound_file_set_destination(v_id, p_destination_id);
  return v_id;
end;
$$;

revoke all on function public.outbound_file_post_to(bigint, bigint, date, text, jsonb, text, text, integer, text, text, text, text, jsonb, boolean) from public, anon;
grant execute on function public.outbound_file_post_to(bigint, bigint, date, text, jsonb, text, text, integer, text, text, text, text, jsonb, boolean) to authenticated;

-- The night run passes over a list without a card.
do $$
declare
  v_def text;
  v_new text;
begin
  select pg_get_functiondef('public.outbound_auto_ship(date)'::regprocedure) into v_def;
  v_new := replace(v_def,
    'and not date_undecided and shipped_on < v_today',
    'and not date_undecided and shipped_on < v_today
                and destination_id is not null');
  if v_new = v_def then
    raise exception 'outbound_auto_ship: pattern not found';
  end if;
  execute v_new;
end $$;
