-- 0203: a list taken back while it had no day (出庫予定日 未定) was on no
-- list at all: the calendar holds days set, the 未定 list leaves taken-back
-- ones out. outbound_files_cancelled_undated(warehouse) lists them, so the
-- 出庫 tab can show them as 取り消し. The copies kept by a replacement
-- (0202, replaced_by) stay out: they are records, not lists taken back.
-- outbound_files_list also says when a list was taken back (undone_at is
-- there already) — and the calendar marks it with ✕.

do $$
declare
  d text;
  r text;
begin
  d := pg_get_functiondef('public.outbound_files_undecided(bigint)'::regprocedure);
  r := replace(d, 'public.outbound_files_undecided(', 'public.outbound_files_cancelled_undated(');
  r := replace(r, '''date_undecided'', true,', '''date_undecided'', true, ''undone_at'', f.undone_at,');
  r := replace(r, 'where f.date_undecided and (f.status = ''planned'' or f.kind = ''proxy'') and f.undone_at is null',
                  'where f.date_undecided and f.undone_at is not null and f.replaced_by is null');
  r := replace(r, 'order by f.created_at, f.id)', 'order by f.undone_at desc, f.id)');
  if position('outbound_files_cancelled_undated' in r) = 0 or position('f.replaced_by is null' in r) = 0
     or position('''undone_at'', f.undone_at' in r) = 0 then
    raise exception 'outbound_files_cancelled_undated: the text to change was not found';
  end if;
  execute r;
end;
$$;
revoke all on function public.outbound_files_cancelled_undated(bigint) from public, anon;
grant execute on function public.outbound_files_cancelled_undated(bigint) to authenticated;
