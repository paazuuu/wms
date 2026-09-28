-- 0106 — teach the dictionary before the goods arrive.
--
-- A trading company's sample file (Excel, CSV, PDF or a photo) is read the way
-- a real import would read it — columns mapped, read twice by the AI, name and
-- 品番 split, every line resolved to our product — but nothing is booked.
-- The run is kept (`notation_trainings`) with what went wrong, so the errors a
-- company's documents cause are known ahead of time; once someone has checked
-- and corrected it, what it taught (dialects and column headings) is learned.
--
--   * `record_notation_training` — the importer stores one read, with counts
--     of lines, lines matched to our products, and each kind of problem.
--   * `finish_notation_training` — marks it learned with what was learned.
--   * `list_notation_trainings` / `notation_training` / `discard_notation_training`.
--   * `notation_training_stats` — per company: runs, lines, how often each
--     problem came up.

create table if not exists public.notation_trainings (
  id bigint generated always as identity primary key,
  partner_id bigint references public.delivery_suppliers(id) on delete set null,
  file_name text,
  source text,
  verified boolean not null default true,
  line_count integer not null default 0,
  resolved_count integer not null default 0,
  flag_counts jsonb not null default '{}'::jsonb,
  columns jsonb not null default '[]'::jsonb,
  lines jsonb not null default '[]'::jsonb,
  status text not null default 'read' check (status in ('read', 'learned', 'discarded')),
  learned jsonb,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  learned_at timestamptz
);
create index if not exists notation_trainings_partner on public.notation_trainings (partner_id, created_at desc);
alter table public.notation_trainings enable row level security;
drop policy if exists "notation_trainings: signed-in can read" on public.notation_trainings;
create policy "notation_trainings: signed-in can read" on public.notation_trainings
  for select to authenticated using (true);

create or replace function public.notation_training_allowed()
returns boolean
language sql stable security definer set search_path = '' as $$
  select public.has_permission('product.manage') or public.has_permission('receiving.confirm');
$$;

revoke all on function public.notation_training_allowed() from public, anon;
grant execute on function public.notation_training_allowed() to authenticated, service_role;

create or replace function public.record_notation_training(
  p_partner_id bigint, p_file_name text, p_source text, p_verified boolean,
  p_columns jsonb, p_lines jsonb)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
  v_flags jsonb;
begin
  if not public.notation_training_allowed() then
    raise exception 'not permitted: product.manage required';
  end if;
  select coalesce(jsonb_object_agg(f, n), '{}'::jsonb) into v_flags
    from (select split_part(f, ':', 1) as f, count(*) as n
            from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) l,
                 jsonb_array_elements_text(coalesce(l->'flags', '[]'::jsonb)) f
           group by 1) q;
  insert into public.notation_trainings
    (partner_id, file_name, source, verified, line_count, resolved_count, flag_counts, columns, lines)
  values (p_partner_id, p_file_name, p_source, coalesce(p_verified, true),
          jsonb_array_length(coalesce(p_lines, '[]'::jsonb)),
          (select count(*) from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) l
            where jsonb_typeof(l->'product') = 'object'),
          v_flags, coalesce(p_columns, '[]'::jsonb), coalesce(p_lines, '[]'::jsonb))
  returning id into v_id;
  perform public.log_audit('notation.training_read', 'notation_training', v_id::text, null,
    jsonb_build_object('partner_id', p_partner_id, 'file', p_file_name, 'flags', v_flags));
  return v_id;
end;
$$;

revoke all on function public.record_notation_training(bigint, text, text, boolean, jsonb, jsonb) from public, anon;
grant execute on function public.record_notation_training(bigint, text, text, boolean, jsonb, jsonb)
  to authenticated, service_role;

create or replace function public.finish_notation_training(
  p_id bigint, p_partner_id bigint, p_learned jsonb)
returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not public.notation_training_allowed() then
    raise exception 'not permitted: product.manage required';
  end if;
  update public.notation_trainings
     set status = 'learned', learned = p_learned, learned_at = now(),
         partner_id = coalesce(p_partner_id, partner_id)
   where id = p_id;
  return found;
end;
$$;

revoke all on function public.finish_notation_training(bigint, bigint, jsonb) from public, anon;
grant execute on function public.finish_notation_training(bigint, bigint, jsonb) to authenticated, service_role;

create or replace function public.discard_notation_training(p_id bigint)
returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not public.notation_training_allowed() then
    raise exception 'not permitted: product.manage required';
  end if;
  update public.notation_trainings set status = 'discarded' where id = p_id and status = 'read';
  return found;
end;
$$;

revoke all on function public.discard_notation_training(bigint) from public, anon;
grant execute on function public.discard_notation_training(bigint) to authenticated, service_role;

create or replace function public.list_notation_trainings(
  p_partner_id bigint default null, p_limit integer default 50)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('product.view') or public.notation_training_allowed()) then
    raise exception 'not permitted: product.view required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', t.id, 'partner_id', t.partner_id, 'partner_name', s.name,
             'file_name', t.file_name, 'source', t.source, 'verified', t.verified,
             'line_count', t.line_count, 'resolved_count', t.resolved_count,
             'flag_counts', t.flag_counts, 'status', t.status, 'learned', t.learned,
             'created_at', t.created_at, 'learned_at', t.learned_at)
           order by t.created_at desc)
      from (select * from public.notation_trainings
             where p_partner_id is null or partner_id = p_partner_id
             order by created_at desc
             limit greatest(1, least(coalesce(p_limit, 50), 200))) t
      left join public.delivery_suppliers s on s.id = t.partner_id
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.list_notation_trainings(bigint, integer) from public, anon;
grant execute on function public.list_notation_trainings(bigint, integer) to authenticated, service_role;

create or replace function public.notation_training(p_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('product.view') or public.notation_training_allowed()) then
    raise exception 'not permitted: product.view required';
  end if;
  return (
    select jsonb_build_object(
             'id', t.id, 'partner_id', t.partner_id, 'partner_name', s.name,
             'file_name', t.file_name, 'source', t.source, 'verified', t.verified,
             'line_count', t.line_count, 'resolved_count', t.resolved_count,
             'flag_counts', t.flag_counts, 'status', t.status, 'learned', t.learned,
             'columns', t.columns, 'lines', t.lines,
             'created_at', t.created_at, 'learned_at', t.learned_at)
      from public.notation_trainings t
      left join public.delivery_suppliers s on s.id = t.partner_id
     where t.id = p_id);
end;
$$;

revoke all on function public.notation_training(bigint) from public, anon;
grant execute on function public.notation_training(bigint) to authenticated, service_role;

-- Per company: what its documents tend to get wrong.
create or replace function public.notation_training_stats()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('product.view') or public.notation_training_allowed()) then
    raise exception 'not permitted: product.view required';
  end if;
  return coalesce((
    select jsonb_agg(row order by (row->>'runs')::int desc)
      from (
        select jsonb_build_object(
                 'partner_id', t.partner_id, 'partner_name', s.name,
                 'runs', count(*), 'lines', sum(t.line_count),
                 'resolved', sum(t.resolved_count),
                 'learned_runs', count(*) filter (where t.status = 'learned'),
                 'dialects', (select count(*) from public.notation_dialects d
                               where d.partner_id = t.partner_id),
                 'columns', (select count(*) from public.column_aliases a
                              where a.partner_id = t.partner_id),
                 'flags', (select coalesce(jsonb_object_agg(k, n), '{}'::jsonb)
                             from (select e.key as k, sum(e.value::int) as n
                                     from public.notation_trainings t2,
                                          jsonb_each_text(t2.flag_counts) e
                                    where t2.partner_id is not distinct from t.partner_id
                                      and t2.status <> 'discarded'
                                    group by e.key) f),
                 'last_at', max(t.created_at)) as row
          from public.notation_trainings t
          left join public.delivery_suppliers s on s.id = t.partner_id
         where t.status <> 'discarded'
         group by t.partner_id, s.name
      ) q), '[]'::jsonb);
end;
$$;

revoke all on function public.notation_training_stats() from public, anon;
grant execute on function public.notation_training_stats() to authenticated, service_role;
