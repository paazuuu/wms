-- 0113 — telling the reader when its warnings were right or wrong.
--
-- The reader warns about JANs now in more ways:
--   * jan_display_exponent — kept whole but shown as 4.90148E+12;
--   * jan_exponent — the digits are gone;
--   * jan_restored — gone, but restored from the 品番, whose product's JAN
--     starts with the digits that survived;
--   * jan_restore_mismatch — the 品番's product does not agree;
--   * jan_code_mismatch — the JAN and the 品番 name two products.
-- While these rules are new they will sometimes be wrong. Whoever reviews a
-- line can say so; the reports are counted per warning, with their notes,
-- so the rules can be tuned from what actually happened.

create table if not exists public.reader_warning_reports (
  id bigint generated always as identity primary key,
  partner_id bigint references public.delivery_suppliers(id) on delete set null,
  flag text not null,
  flag_kind text generated always as (split_part(flag, ':', 1)) stored,
  verdict text not null check (verdict in ('right', 'wrong')),
  line jsonb,
  note text,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);
create index if not exists reader_warning_reports_kind on public.reader_warning_reports (flag_kind, created_at desc);
alter table public.reader_warning_reports enable row level security;

create or replace function public.report_reader_warning(
  p_partner_id bigint, p_flag text, p_verdict text, p_line jsonb default null, p_note text default null)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare v_id bigint;
begin
  if not (public.has_permission('receiving.confirm') or public.has_permission('product.manage')
          or public.has_permission('pack.complete')) then
    raise exception 'not permitted: receiving.confirm required';
  end if;
  if nullif(btrim(coalesce(p_flag, '')), '') is null then
    raise exception 'a warning is required';
  end if;
  if p_verdict not in ('right', 'wrong') then
    raise exception 'verdict must be right or wrong';
  end if;
  insert into public.reader_warning_reports (partner_id, flag, verdict, line, note)
  values (p_partner_id, btrim(p_flag), p_verdict, p_line, public.tidy_text(p_note))
  returning id into v_id;
  perform public.log_audit('reader.warning_reported', 'reader_warning', v_id::text, null,
    jsonb_build_object('flag', p_flag, 'verdict', p_verdict, 'partner_id', p_partner_id));
  return v_id;
end;
$$;

-- Per warning: how often it was confirmed and how often it was wrong, with
-- the latest notes (newest first).
create or replace function public.reader_warning_stats()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('product.view') or public.has_permission('product.manage')
          or public.has_permission('receiving.view')) then
    raise exception 'not permitted: product.view required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'flag', k.flag_kind,
             'right', k.right_n,
             'wrong', k.wrong_n,
             'last_at', k.last_at,
             'notes', (select coalesce(jsonb_agg(jsonb_build_object(
                                'verdict', n.verdict, 'note', n.note, 'partner_name', s.name,
                                'created_at', n.created_at) order by n.created_at desc), '[]'::jsonb)
                         from (select * from public.reader_warning_reports r
                                where r.flag_kind = k.flag_kind and r.note is not null
                                order by r.created_at desc limit 5) n
                         left join public.delivery_suppliers s on s.id = n.partner_id))
           order by k.wrong_n desc, k.flag_kind)
      from (select flag_kind,
                   count(*) filter (where verdict = 'right') as right_n,
                   count(*) filter (where verdict = 'wrong') as wrong_n,
                   max(created_at) as last_at
              from public.reader_warning_reports
             group by flag_kind) k), '[]'::jsonb);
end;
$$;

revoke all on function public.report_reader_warning(bigint, text, text, jsonb, text) from public, anon;
revoke all on function public.reader_warning_stats() from public, anon;
grant execute on function public.report_reader_warning(bigint, text, text, jsonb, text) to authenticated, service_role;
grant execute on function public.reader_warning_stats() to authenticated, service_role;
