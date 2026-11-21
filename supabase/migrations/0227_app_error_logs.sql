-- エラーログ (0227): errors the app ran into — a request the server refused
-- or failed, a screen that could not be drawn, an error nothing caught — kept
-- for the system administrator to look into. Its own table, joined to
-- nothing; written by whoever met the error (through app_error_log only),
-- read by those who see the audit log. The same error from the same person
-- within ten minutes is counted on one row, not repeated; at most 300 rows
-- an hour per person. Removal is the app-error-log function's.

create table if not exists public.app_error_logs (
  id bigint generated always as identity primary key,
  first_at timestamptz not null default now(),
  last_at timestamptz not null default now(),
  times integer not null default 1,
  user_id uuid default auth.uid(),
  kind text not null check (kind in ('api', 'flutter', 'uncaught')),
  message text not null,
  detail text,
  place text,
  request text,
  status integer,
  client text
);
create index if not exists app_error_logs_last on public.app_error_logs (last_at desc);
create index if not exists app_error_logs_same on public.app_error_logs (user_id, kind, last_at desc);
alter table public.app_error_logs enable row level security;

create or replace function public.app_error_log_can_view()
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_system_admin() or public.has_permission('audit.view') or public.has_permission('user.manage');
$$;
grant execute on function public.app_error_log_can_view() to authenticated, service_role;
revoke execute on function public.app_error_log_can_view() from public, anon;

-- p: {kind, message, detail?, place?, request?, status?, client?}. True when
-- kept (or counted on the same error).
create or replace function public.app_error_log(p jsonb)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_kind text := coalesce(p->>'kind', '');
  v_message text := left(btrim(coalesce(p->>'message', '')), 2000);
  v_request text := nullif(left(btrim(coalesce(p->>'request', '')), 300), '');
  v_status integer := case when coalesce(p->>'status', '') ~ '^\d{1,3}$' then (p->>'status')::integer end;
  v_id bigint;
begin
  if auth.uid() is null or v_kind not in ('api', 'flutter', 'uncaught') or v_message = '' then
    return false;
  end if;
  select id into v_id from public.app_error_logs
   where user_id = auth.uid() and kind = v_kind and message = v_message
     and request is not distinct from v_request and status is not distinct from v_status
     and last_at > now() - interval '10 minutes'
   order by last_at desc limit 1;
  if v_id is not null then
    update public.app_error_logs set times = times + 1, last_at = now() where id = v_id;
    return true;
  end if;
  if (select count(*) from public.app_error_logs where user_id = auth.uid() and first_at > now() - interval '1 hour') >= 300 then
    return false;
  end if;
  insert into public.app_error_logs (kind, message, detail, place, request, status, client, user_id)
  values (v_kind, v_message, nullif(left(coalesce(p->>'detail', ''), 8000), ''),
          nullif(left(btrim(coalesce(p->>'place', '')), 300), ''), v_request, v_status,
          nullif(left(btrim(coalesce(p->>'client', '')), 300), ''), auth.uid());
  return true;
end;
$$;
grant execute on function public.app_error_log(jsonb) to authenticated, service_role;
revoke execute on function public.app_error_log(jsonb) from public, anon;

-- The errors kept, newest first; [p_days] back (null: all).
create or replace function public.app_error_logs_list(p_days integer default null, p_limit integer default 1000)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.app_error_log_can_view() then
    raise exception 'not permitted: audit.view required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', e.id, 'first_at', e.first_at, 'last_at', e.last_at, 'times', e.times, 'kind', e.kind,
             'message', e.message, 'detail', e.detail, 'place', e.place, 'request', e.request,
             'status', e.status, 'client', e.client,
             'user_name', (select coalesce(u.name, u.email) from public.app_users u where u.id = e.user_id))
           order by e.last_at desc, e.id desc)
      from (select * from public.app_error_logs
             where p_days is null or last_at > now() - make_interval(days => greatest(p_days, 1))
             order by last_at desc, id desc
             limit least(greatest(coalesce(p_limit, 1000), 1), 5000)) e), '[]'::jsonb);
end;
$$;
grant execute on function public.app_error_logs_list(integer, integer) to authenticated, service_role;
revoke execute on function public.app_error_logs_list(integer, integer) from public, anon;
