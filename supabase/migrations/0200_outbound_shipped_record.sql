-- 0200: 出庫予定日を決めること と 実際に出庫したことの記録 を分ける.
--
-- Setting a day (outbound_file_reschedule) only puts a planned list on the
-- calendar. outbound_file_confirm is the record that the goods have left the
-- warehouse: stock goes down then. So:
-- * it may not be dated after today (Asia/Tokyo): what has not left yet
--   cannot have been shipped — 'outbound_ship_day_future';
-- * who recorded it and when is kept: outbound_files.shipped_by / shipped_at;
-- * outbound_file_detail gives shipped_by_name and shipped_at.

alter table public.outbound_files add column if not exists shipped_by uuid;
alter table public.outbound_files add column if not exists shipped_at timestamptz;

do $$
declare
  d text;
  r text;
begin
  d := pg_get_functiondef('public.outbound_file_confirm(bigint, date)'::regprocedure);
  if position('outbound_ship_day_future' in d) = 0 then
    r := replace(d, 'if v_f.status <> ''planned'' then
    raise exception ''outbound_not_planned'';
  end if;',
      'if v_f.status <> ''planned'' then
    raise exception ''outbound_not_planned'';
  end if;
  if p_shipped_on is not null and p_shipped_on > (now() at time zone ''Asia/Tokyo'')::date then
    raise exception ''outbound_ship_day_future'';
  end if;');
    r := replace(r, 'status = ''shipped'',
    shipped_on =',
      'status = ''shipped'', shipped_by = auth.uid(), shipped_at = now(),
    shipped_on =');
    if r = d or position('outbound_ship_day_future' in r) = 0 or position('shipped_by = auth.uid()' in r) = 0 then
      raise exception 'outbound_file_confirm: the text to change was not found';
    end if;
    execute r;
  end if;

  d := pg_get_functiondef('public.outbound_file_detail(bigint)'::regprocedure);
  if position('shipped_by_name' in d) = 0 then
    r := replace(d, '''undone_at'', v_f.undone_at, ''undone_by_name'', public.user_display_name(v_f.undone_by),',
                    '''undone_at'', v_f.undone_at, ''undone_by_name'', public.user_display_name(v_f.undone_by),'
                    || ' ''shipped_at'', v_f.shipped_at, ''shipped_by_name'', public.user_display_name(v_f.shipped_by),');
    if r = d then
      raise exception 'outbound_file_detail: the text to change was not found';
    end if;
    execute r;
  end if;
end;
$$;
