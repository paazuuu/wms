-- 在庫外出荷 (代理出荷, 0189) may have no day yet, like a planned list (0197):
-- registered 未定 by default, kept off the calendar's days and listed with the
-- other 未定 lists until a day is set. Nothing moves in stock either way.
--   outbound_file_mark_undecided / outbound_file_reschedule: a 代理出荷 too
--     (its planned_on is left as it was: it is not a plan);
--   outbound_files_undecided: lists 代理出荷 with no day too.

do $$
declare
  d text;
  r text;
begin
  d := pg_get_functiondef('public.outbound_file_mark_undecided(bigint)'::regprocedure);
  if position('v_f.kind <> ''proxy''' in d) = 0 then
    r := replace(d, 'if v_f.status <> ''planned'' or v_f.undone_at is not null then',
                    'if (v_f.status <> ''planned'' and v_f.kind <> ''proxy'') or v_f.undone_at is not null then');
    r := replace(r, 'set date_undecided = true, planned_on = null where id = p_id;',
                    'set date_undecided = true, planned_on = case when v_f.kind = ''proxy'' then v_f.planned_on end where id = p_id;');
    if r = d or position('v_f.kind <> ''proxy''' in r) = 0 or position('case when v_f.kind = ''proxy''' in r) = 0 then
      raise exception 'outbound_file_mark_undecided: the text to change was not found';
    end if;
    execute r;
  end if;

  d := pg_get_functiondef('public.outbound_file_reschedule(bigint, date)'::regprocedure);
  if position('v_f.kind <> ''proxy''' in d) = 0 then
    r := replace(d, 'if v_f.status <> ''planned'' or v_f.undone_at is not null then',
                    'if (v_f.status <> ''planned'' and v_f.kind <> ''proxy'') or v_f.undone_at is not null then');
    r := replace(r, 'set shipped_on = p_day, planned_on = p_day, date_undecided = false where id = p_id;',
                    'set shipped_on = p_day, planned_on = case when v_f.kind = ''proxy'' then v_f.planned_on else p_day end, '
                    || 'date_undecided = false where id = p_id;');
    if r = d or position('v_f.kind <> ''proxy''' in r) = 0 or position('case when v_f.kind = ''proxy''' in r) = 0 then
      raise exception 'outbound_file_reschedule: the text to change was not found';
    end if;
    execute r;
  end if;

  d := pg_get_functiondef('public.outbound_files_undecided(bigint)'::regprocedure);
  if position('f.kind = ''proxy''' in d) = 0 then
    r := replace(d, 'where f.date_undecided and f.status = ''planned'' and f.undone_at is null',
                    'where f.date_undecided and (f.status = ''planned'' or f.kind = ''proxy'') and f.undone_at is null');
    if r = d then
      raise exception 'outbound_files_undecided: the text to change was not found';
    end if;
    execute r;
  end if;
end;
$$;
