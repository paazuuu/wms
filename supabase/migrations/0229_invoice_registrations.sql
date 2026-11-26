-- 登録番号の確認 (0229): an invoice's 登録番号 (T + 13 digits) checked against
-- 国税庁の適格請求書発行事業者公表システム (Web-API): whether it is registered
-- and in force, and the name it is registered under — to set beside the name
-- the invoice prints. The invoice-check function asks the Web-API and keeps
-- each answer here (for a week, so the same number is not asked again and
-- again). Its own tables, joined to nothing.
--
-- * integration_keys: keys of outside services the functions use — here the
--   Web-API's アプリケーションID (service 'nta_invoice'). Written by the
--   system administrator (integration_key_set), read only by the functions
--   (service role); nobody reads a key back.
-- * invoice_registrations: the last answer for each number.

create table if not exists public.integration_keys (
  service text primary key,
  secret text not null,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
alter table public.integration_keys enable row level security;

create table if not exists public.invoice_registrations (
  number text primary key check (number ~ '^T[0-9]{13}$'),
  status text not null check (status in ('valid', 'not_found', 'revoked', 'expired')),
  name text,
  kana text,
  trade_name text,
  address text,
  kind text,
  registration_date date,
  disposal_date date,
  expire_date date,
  update_date date,
  raw jsonb,
  checked_at timestamptz not null default now(),
  checked_by uuid
);
alter table public.invoice_registrations enable row level security;

-- Set (or clear, with an empty value) a key. The system administrator's.
create or replace function public.integration_key_set(p_service text, p_secret text)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_system_admin() then
    raise exception 'not permitted: system administrator required';
  end if;
  if p_service not in ('nta_invoice') then
    raise exception 'integration_key_service';
  end if;
  if nullif(btrim(coalesce(p_secret, '')), '') is null then
    update public.integration_keys set secret = '', updated_at = now(), updated_by = auth.uid()
     where service = p_service;
  else
    insert into public.integration_keys (service, secret, updated_at, updated_by)
    values (p_service, btrim(p_secret), now(), auth.uid())
    on conflict (service) do update set secret = excluded.secret, updated_at = now(), updated_by = auth.uid();
  end if;
  perform public.log_audit('integration_key.set', 'integration_key', p_service, null,
    jsonb_build_object('by', public.user_display_name(auth.uid()), 'cleared', nullif(btrim(coalesce(p_secret, '')), '') is null));
  return true;
end;
$$;
grant execute on function public.integration_key_set(text, text) to authenticated, service_role;
revoke execute on function public.integration_key_set(text, text) from public, anon;

-- Which keys are set (never the keys themselves).
create or replace function public.integration_keys_status()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('service', s.service,
           'set', coalesce(k.secret, '') <> '', 'updated_at', k.updated_at,
           'updated_by_name', (select coalesce(u.name, u.email) from public.app_users u where u.id = k.updated_by))), '[]'::jsonb)
    from (values ('nta_invoice')) s(service)
    left join public.integration_keys k on k.service = s.service
   where auth.uid() is not null;
$$;
grant execute on function public.integration_keys_status() to authenticated, service_role;
revoke execute on function public.integration_keys_status() from public, anon;

-- The answers kept for [p_numbers] (T + 13 digits), for whoever is signed in.
create or replace function public.invoice_registrations_get(p_numbers text[])
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(to_jsonb(r) - 'raw' - 'checked_by'), '[]'::jsonb)
    from public.invoice_registrations r
   where r.number = any(coalesce(p_numbers, '{}')) and auth.uid() is not null;
$$;
grant execute on function public.invoice_registrations_get(text[]) to authenticated, service_role;
revoke execute on function public.invoice_registrations_get(text[]) from public, anon;
