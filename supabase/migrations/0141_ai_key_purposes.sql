-- 0141 — Gemini keys by use: one for reading documents (as 0137), and one
-- for looking up a product's size and weight on the web.
--
-- Looking a product up goes through Google Search in Gemini, which counts
-- against a key's quota (and, on a paid key, costs) apart from reading
-- files. So the screen now chooses a key for each use:
--   * reading  — `is_active` (0137): files, names, the connection test;
--   * lookup   — `spec_active`: サイズ・重量を調べる.
-- Any registered key can be chosen for either, or for both. With no key
-- chosen for the lookup, it uses the reading key; with none of those either,
-- the server's GEMINI_SPEC_API_KEY, then GEMINI_API_KEY.
-- `purpose` says what a key was registered for, so "use it now" at
-- registration knows which use it means.

alter table public.ai_api_keys
  add column if not exists purpose text not null default 'general';
do $$
begin
  alter table public.ai_api_keys add constraint ai_api_keys_purpose_check
    check (purpose in ('general', 'spec_lookup'));
exception when duplicate_object then null;
end $$;
-- Applied while purpose was meant to split is_active; with every key
-- 'general' it says what ai_api_keys_one_active says, and is harmless.
create unique index if not exists ai_api_keys_one_active_per_purpose
  on public.ai_api_keys (provider, purpose) where is_active;

alter table public.ai_api_keys
  add column if not exists spec_active boolean not null default false;
create unique index if not exists ai_api_keys_one_spec_active
  on public.ai_api_keys (provider) where spec_active;

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
               'id', k.id, 'provider', k.provider, 'purpose', k.purpose, 'label', k.label, 'key_hint', k.key_hint,
               'tier', k.tier, 'model', k.model, 'is_active', k.is_active, 'spec_active', k.spec_active,
               'note', k.note, 'last_used_at', k.last_used_at, 'last_ok', k.last_ok,
               'last_error_kind', k.last_error_kind, 'created_at', k.created_at,
               'created_by_name', (select coalesce(u.name, u.email) from public.app_users u where u.id = k.created_by),
               'calls_24h', (select count(*) from public.ai_calls c
                              where c.key_id = k.id and c.called_at > now() - interval '24 hours'),
               'failed_24h', (select count(*) from public.ai_calls c
                               where c.key_id = k.id and not c.ok and c.called_at > now() - interval '24 hours'),
               'lookups_24h', (select count(*) from public.ai_calls c
                                where c.key_id = k.id and c.task = 'spec_lookup'
                                  and c.called_at > now() - interval '24 hours'))
             order by k.is_active desc, k.spec_active desc, k.created_at desc)
        from public.ai_api_keys k
       where k.status = 'active'), '[]'::jsonb),
    'using_server_key', not exists (select 1 from public.ai_api_keys where is_active and status = 'active'),
    'spec_uses_general', not exists (select 1 from public.ai_api_keys where spec_active and status = 'active'));
end;
$$;

-- Register a key for a use; "activate" puts it to that use at once.
create or replace function public.ai_key_add_for(
  p_purpose text, p_label text, p_key text, p_tier text default 'unknown', p_model text default null,
  p_activate boolean default false, p_note text default null)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_purpose text := coalesce(nullif(btrim(coalesce(p_purpose, '')), ''), 'general');
  v_id bigint;
begin
  if v_purpose not in ('general', 'spec_lookup') then
    raise exception 'unknown purpose %', p_purpose;
  end if;
  -- 0137's checks, vault and audit; activation is done below, per use.
  v_id := public.ai_key_add(p_label, p_key, p_tier, p_model, false, p_note);
  update public.ai_api_keys set purpose = v_purpose where id = v_id;
  if coalesce(p_activate, false) then
    perform public.ai_key_use(v_purpose, v_id);
  end if;
  return v_id;
end;
$$;

-- Choose the key for a use; null goes back to the fallback (the server's
-- key for reading, the reading key for the lookup).
create or replace function public.ai_key_use(p_purpose text, p_id bigint)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_label text;
  v_purpose text := coalesce(nullif(btrim(coalesce(p_purpose, '')), ''), 'general');
begin
  if not public.ai_keys_allowed() then
    raise exception 'not permitted: ai.key_manage required';
  end if;
  if v_purpose = 'general' then
    return public.ai_key_activate(p_id);
  end if;
  if v_purpose <> 'spec_lookup' then
    raise exception 'unknown purpose %', p_purpose;
  end if;
  if p_id is not null then
    select label into v_label from public.ai_api_keys where id = p_id and status = 'active';
    if v_label is null then
      raise exception 'key % not found', p_id;
    end if;
  end if;
  update public.ai_api_keys set spec_active = false, updated_at = now()
   where spec_active and id is distinct from p_id;
  if p_id is not null then
    update public.ai_api_keys set spec_active = true, updated_at = now() where id = p_id;
  end if;
  perform public.log_audit('ai.key_activated', 'ai_api_key', coalesce(p_id::text, 'general'), null,
    jsonb_build_object('label', coalesce(v_label, 'reading key'), 'purpose', 'spec_lookup'));
  return true;
end;
$$;

-- Retiring a key takes it off both uses.
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
  update public.ai_api_keys set status = 'retired', is_active = false, spec_active = false, updated_at = now()
   where id = p_id;
  perform public.log_audit('ai.key_retired', 'ai_api_key', p_id::text, null,
    jsonb_build_object('label', v_row.label, 'key_hint', v_row.key_hint));
  return true;
end;
$$;

-- For the edge functions only: the key for a use (or one key by id). The
-- lookup with no key of its own takes the reading key; `fallback` says so.
create or replace function public.ai_active_key_for(p_purpose text, p_id bigint default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_row public.ai_api_keys;
  v_key text;
  v_fallback boolean := false;
begin
  if p_id is not null then
    select * into v_row from public.ai_api_keys where id = p_id and status = 'active';
  elsif coalesce(p_purpose, 'general') = 'spec_lookup' then
    select * into v_row from public.ai_api_keys where status = 'active' and spec_active limit 1;
    if v_row.id is null then
      select * into v_row from public.ai_api_keys where status = 'active' and is_active limit 1;
      v_fallback := true;
    end if;
  else
    select * into v_row from public.ai_api_keys where status = 'active' and is_active limit 1;
  end if;
  if v_row.id is null or v_row.vault_secret_id is null then
    return null;
  end if;
  select decrypted_secret into v_key from vault.decrypted_secrets where id = v_row.vault_secret_id;
  if nullif(v_key, '') is null then
    return null;
  end if;
  return jsonb_build_object('key_id', v_row.id, 'key', v_key, 'model', v_row.model, 'tier', v_row.tier,
                            'label', v_row.label, 'fallback', v_fallback);
end;
$$;

revoke all on function public.ai_key_add_for(text, text, text, text, text, boolean, text) from public, anon;
revoke all on function public.ai_key_use(text, bigint) from public, anon;
revoke all on function public.ai_active_key_for(text, bigint) from public, anon, authenticated;
grant execute on function public.ai_key_add_for(text, text, text, text, text, boolean, text) to authenticated, service_role;
grant execute on function public.ai_key_use(text, bigint) to authenticated, service_role;
grant execute on function public.ai_active_key_for(text, bigint) to service_role;
