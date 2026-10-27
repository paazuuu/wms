-- 0151: which model reads what, and how much the AI may be used a day.
--
-- A PDF or a picture is read by a model strong enough to find a JAN printed
-- in a 備考 column or under a name; the lightest model missed them. A sheet's
-- headings, name splits and the rest are easy, and stay on the light one.
-- Both are chosen here, with two daily limits so a bill cannot run away:
-- every AI call, and documents read (one per PDF or picture; its checking
-- second read is not counted). A day is a day in Japan. Null: no limit.

alter table public.ai_settings
  add column if not exists document_model text not null default 'gemini-3.8-flash',
  add column if not exists light_model text not null default 'gemini-3.1-flash-lite',
  add column if not exists daily_limit integer default 300 check (daily_limit is null or daily_limit >= 0),
  add column if not exists daily_document_limit integer default 50
    check (daily_document_limit is null or daily_document_limit >= 0);

-- Today's use: calls that reached Google (a refused or keyless one is not).
create or replace function public.ai_usage_today()
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'calls', count(*) filter (where coalesce(error_kind, '') not in ('limit', 'no_key')),
    'documents', count(*) filter (where task = 'extract' and coalesce(error_kind, '') not in ('limit', 'no_key'))
  )
    from public.ai_calls
   where called_at >= ((now() at time zone 'Asia/Tokyo')::date::timestamp at time zone 'Asia/Tokyo');
$$;
revoke all on function public.ai_usage_today() from public, anon;
grant execute on function public.ai_usage_today() to authenticated, service_role;

-- What the edge functions ask before each call: the models and what is left.
create or replace function public.ai_policy()
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'document_model', s.document_model, 'light_model', s.light_model,
    'daily_limit', s.daily_limit, 'daily_document_limit', s.daily_document_limit
  ) || public.ai_usage_today()
    from public.ai_settings s where s.id = 1;
$$;
revoke all on function public.ai_policy() from public, anon, authenticated;
grant execute on function public.ai_policy() to service_role;

create or replace function public.get_ai_settings()
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('auto_threshold', auto_threshold, 'review_threshold', review_threshold,
                            'document_model', document_model, 'light_model', light_model,
                            'daily_limit', daily_limit, 'daily_document_limit', daily_document_limit,
                            'today', public.ai_usage_today(),
                            'updated_at', updated_at)
    from public.ai_settings where id = 1;
$$;

-- The models and the limits, by whoever may set the AI's thresholds.
create or replace function public.set_ai_limits(
  p_document_model text, p_light_model text, p_daily_limit integer, p_daily_document_limit integer)
returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not (public.has_permission('ai.review') or public.has_permission('user.manage')) then
    raise exception 'not permitted: ai.review required';
  end if;
  if coalesce(btrim(p_document_model), '') !~ '^gemini-[a-z0-9.\-]+$'
     or coalesce(btrim(p_light_model), '') !~ '^gemini-[a-z0-9.\-]+$' then
    raise exception 'a model is named gemini-…';
  end if;
  if coalesce(p_daily_limit, 0) < 0 or coalesce(p_daily_document_limit, 0) < 0 then
    raise exception 'a limit is 0 or more';
  end if;
  update public.ai_settings set
    document_model = btrim(p_document_model), light_model = btrim(p_light_model),
    daily_limit = p_daily_limit, daily_document_limit = p_daily_document_limit,
    updated_at = now(), updated_by = auth.uid()
   where id = 1;
  perform public.log_audit('ai.limits', 'ai_settings', '1', null, jsonb_build_object(
    'document_model', p_document_model, 'light_model', p_light_model,
    'daily_limit', p_daily_limit, 'daily_document_limit', p_daily_document_limit));
  return public.get_ai_settings();
end;
$$;
revoke all on function public.set_ai_limits(text, text, integer, integer) from public, anon;
grant execute on function public.set_ai_limits(text, text, integer, integer) to authenticated;
