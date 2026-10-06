-- 0137 — the Gemini API key chosen from the screen (管理 → AI設定).
--
-- Until now the key was the GEMINI_API_KEY secret of the edge functions,
-- which only someone with the Supabase dashboard could change. Keys are now
-- kept in Supabase Vault (encrypted at rest), several can be registered —
-- a free one and a paid one, say — and one is in use at a time. The edge
-- functions ask `ai_active_key()` for it and fall back to GEMINI_API_KEY
-- when none is chosen.
--
-- The key itself never leaves the database except to the service role: the
-- screen sees a label, the last four characters, the tier, the model and how
-- the last call with it went.

insert into public.permissions (code, description)
values ('ai.key_manage', 'Register, choose and retire the AI API keys')
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
  from public.roles r, public.permissions p
 where r.code in ('system_admin', 'company_admin') and p.code = 'ai.key_manage'
on conflict do nothing;

create table if not exists public.ai_api_keys (
  id bigint generated always as identity primary key,
  provider text not null default 'gemini' check (provider in ('gemini')),
  label text not null,
  vault_secret_id uuid,
  key_hint text,
  tier text not null default 'unknown' check (tier in ('free', 'paid', 'unknown')),
  model text,
  is_active boolean not null default false,
  status text not null default 'active' check (status in ('active', 'retired')),
  note text,
  last_used_at timestamptz,
  last_ok boolean,
  last_error_kind text,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists ai_api_keys_one_active
  on public.ai_api_keys (provider) where is_active;

alter table public.ai_api_keys enable row level security;
-- No policies: read and written only through the functions below.

comment on table public.ai_api_keys is
  'AI API keys chosen from the screen (0137). The key is in Supabase Vault; only its last four characters are here.';

alter table public.ai_calls
  add column if not exists key_id bigint;

create or replace function public.ai_keys_allowed()
returns boolean
language sql stable security definer set search_path = '' as $$
  select public.has_permission('ai.key_manage') or public.has_permission('user.manage');
$$;

-- What the screen shows: never the key.
create or replace function public.ai_keys_list()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.ai_keys_allowed() then
    raise exception 'not permitted: ai.key_manage required';
  end if;
  return jsonb_build_object(
    'keys', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', k.id, 'provider', k.provider, 'label', k.label, 'key_hint', k.key_hint,
               'tier', k.tier, 'model', k.model, 'is_active', k.is_active, 'note', k.note,
               'last_used_at', k.last_used_at, 'last_ok', k.last_ok, 'last_error_kind', k.last_error_kind,
               'created_at', k.created_at,
               'created_by_name', (select coalesce(u.name, u.email) from public.app_users u where u.id = k.created_by),
               'calls_24h', (select count(*) from public.ai_calls c
                              where c.key_id = k.id and c.called_at > now() - interval '24 hours'),
               'failed_24h', (select count(*) from public.ai_calls c
                               where c.key_id = k.id and not c.ok and c.called_at > now() - interval '24 hours'))
             order by k.is_active desc, k.created_at desc)
        from public.ai_api_keys k
       where k.status = 'active'), '[]'::jsonb),
    'using_server_key', not exists (select 1 from public.ai_api_keys where is_active and status = 'active'));
end;
$$;

create or replace function public.ai_key_add(
  p_label text, p_key text, p_tier text default 'unknown', p_model text default null,
  p_activate boolean default false, p_note text default null)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_key   text := btrim(coalesce(p_key, ''));
  v_label text := nullif(btrim(coalesce(p_label, '')), '');
  v_tier  text := coalesce(nullif(btrim(coalesce(p_tier, '')), ''), 'unknown');
  v_id    bigint;
  v_sec   uuid;
begin
  if not public.ai_keys_allowed() then
    raise exception 'not permitted: ai.key_manage required';
  end if;
  if v_label is null then
    raise exception 'a name for the key is required';
  end if;
  if length(v_key) < 20 or v_key ~ '\s' then
    raise exception 'this does not look like an API key';
  end if;
  if v_tier not in ('free', 'paid', 'unknown') then
    raise exception 'unknown tier %', p_tier;
  end if;

  insert into public.ai_api_keys (label, key_hint, tier, model, note)
  values (v_label, '…' || right(v_key, 4), v_tier,
          nullif(btrim(coalesce(p_model, '')), ''), nullif(btrim(coalesce(p_note, '')), ''))
  returning id into v_id;
  v_sec := vault.create_secret(v_key, 'ai_api_key_' || v_id, 'Gemini API key: ' || v_label);
  update public.ai_api_keys set vault_secret_id = v_sec where id = v_id;

  if coalesce(p_activate, false) then
    update public.ai_api_keys set is_active = false, updated_at = now() where is_active and id <> v_id;
    update public.ai_api_keys set is_active = true, updated_at = now() where id = v_id;
  end if;

  perform public.log_audit('ai.key_added', 'ai_api_key', v_id::text, null,
    jsonb_build_object('label', v_label, 'key_hint', '…' || right(v_key, 4), 'tier', v_tier,
                       'activated', coalesce(p_activate, false)));
  return v_id;
end;
$$;

-- Choose the key in use; null goes back to the server's GEMINI_API_KEY.
create or replace function public.ai_key_activate(p_id bigint)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_label text;
begin
  if not public.ai_keys_allowed() then
    raise exception 'not permitted: ai.key_manage required';
  end if;
  if p_id is not null then
    select label into v_label from public.ai_api_keys where id = p_id and status = 'active';
    if v_label is null then
      raise exception 'key % not found', p_id;
    end if;
  end if;
  update public.ai_api_keys set is_active = false, updated_at = now()
   where is_active and id is distinct from p_id;
  if p_id is not null then
    update public.ai_api_keys set is_active = true, updated_at = now() where id = p_id;
  end if;
  perform public.log_audit('ai.key_activated', 'ai_api_key', coalesce(p_id::text, 'server'), null,
    jsonb_build_object('label', coalesce(v_label, 'GEMINI_API_KEY')));
  return true;
end;
$$;

create or replace function public.ai_key_update(
  p_id bigint, p_label text default null, p_tier text default null, p_model text default null,
  p_note text default null, p_new_key text default null)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_row public.ai_api_keys;
  v_key text := nullif(btrim(coalesce(p_new_key, '')), '');
begin
  if not public.ai_keys_allowed() then
    raise exception 'not permitted: ai.key_manage required';
  end if;
  select * into v_row from public.ai_api_keys where id = p_id and status = 'active' for update;
  if v_row.id is null then
    raise exception 'key % not found', p_id;
  end if;
  if p_tier is not null and p_tier not in ('free', 'paid', 'unknown') then
    raise exception 'unknown tier %', p_tier;
  end if;
  if v_key is not null and (length(v_key) < 20 or v_key ~ '\s') then
    raise exception 'this does not look like an API key';
  end if;
  if v_key is not null then
    perform vault.update_secret(v_row.vault_secret_id, v_key, null, null, null);
  end if;
  update public.ai_api_keys set
    label = coalesce(nullif(btrim(coalesce(p_label, '')), ''), label),
    tier = coalesce(p_tier, tier),
    model = case when p_model is null then model else nullif(btrim(p_model), '') end,
    note = case when p_note is null then note else nullif(btrim(p_note), '') end,
    key_hint = case when v_key is null then key_hint else '…' || right(v_key, 4) end,
    last_ok = case when v_key is null then last_ok end,
    last_error_kind = case when v_key is null then last_error_kind end,
    updated_at = now()
   where id = p_id;
  perform public.log_audit('ai.key_updated', 'ai_api_key', p_id::text, null,
    jsonb_build_object('label', coalesce(p_label, v_row.label), 'tier', coalesce(p_tier, v_row.tier),
                       'model', p_model, 'key_replaced', v_key is not null));
  return true;
end;
$$;

-- Retire a key: it stops being used and its secret is blanked in the vault.
create or replace function public.ai_key_retire(p_id bigint)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_row public.ai_api_keys;
begin
  if not public.ai_keys_allowed() then
    raise exception 'not permitted: ai.key_manage required';
  end if;
  select * into v_row from public.ai_api_keys where id = p_id and status = 'active' for update;
  if v_row.id is null then
    raise exception 'key % not found', p_id;
  end if;
  if v_row.vault_secret_id is not null then
    perform vault.update_secret(v_row.vault_secret_id, '', null, null, null);
  end if;
  update public.ai_api_keys set status = 'retired', is_active = false, updated_at = now() where id = p_id;
  perform public.log_audit('ai.key_retired', 'ai_api_key', p_id::text, null,
    jsonb_build_object('label', v_row.label, 'key_hint', v_row.key_hint));
  return true;
end;
$$;

-- For the edge functions only (service role): the key in use, or one key
-- by id for a connection test. Null when nothing is chosen.
create or replace function public.ai_active_key(p_id bigint default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_row public.ai_api_keys;
  v_key text;
begin
  select * into v_row from public.ai_api_keys
   where status = 'active' and (case when p_id is null then is_active else id = p_id end)
   limit 1;
  if v_row.id is null or v_row.vault_secret_id is null then
    return null;
  end if;
  select decrypted_secret into v_key from vault.decrypted_secrets where id = v_row.vault_secret_id;
  if nullif(v_key, '') is null then
    return null;
  end if;
  return jsonb_build_object('key_id', v_row.id, 'key', v_key, 'model', v_row.model, 'tier', v_row.tier,
                            'label', v_row.label);
end;
$$;

-- How the last call with a key went, so the screen can say "credits used
-- up" next to the key that ran out.
create or replace function public.ai_key_note_result()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.key_id is not null then
    update public.ai_api_keys
       set last_used_at = new.called_at, last_ok = new.ok,
           last_error_kind = case when new.ok then null else new.error_kind end
     where id = new.key_id;
  end if;
  return null;
end;
$$;

create or replace trigger ai_call_notes_key
  after insert on public.ai_calls
  for each row execute function public.ai_key_note_result();

revoke all on function public.ai_keys_allowed() from public, anon;
revoke all on function public.ai_keys_list() from public, anon;
revoke all on function public.ai_key_add(text, text, text, text, boolean, text) from public, anon;
revoke all on function public.ai_key_activate(bigint) from public, anon;
revoke all on function public.ai_key_update(bigint, text, text, text, text, text) from public, anon;
revoke all on function public.ai_key_retire(bigint) from public, anon;
revoke all on function public.ai_active_key(bigint) from public, anon, authenticated;
grant execute on function public.ai_keys_allowed() to authenticated, service_role;
grant execute on function public.ai_keys_list() to authenticated, service_role;
grant execute on function public.ai_key_add(text, text, text, text, boolean, text) to authenticated, service_role;
grant execute on function public.ai_key_activate(bigint) to authenticated, service_role;
grant execute on function public.ai_key_update(bigint, text, text, text, text, text) to authenticated, service_role;
grant execute on function public.ai_key_retire(bigint) to authenticated, service_role;
grant execute on function public.ai_active_key(bigint) to service_role;
