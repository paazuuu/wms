-- 0131 — our own company (自社情報), so a document can tell us from the
-- company that sent it.
--
-- A delivery note or invoice names two companies: the one that issued it
-- (the supplier) and us (宛先, 〇〇御中). Knowing our own name, its other
-- spellings and our 登録番号, the reader keeps ours out of the supplier
-- fields and takes the other company as the supplier.
--
--   * `companies` gains name_kana, name_en, aliases (略称・旧社名・支店名 …),
--     registration_number (T + 13 digits), postal_code, address, phone,
--     fax, email.
--   * `company_profile()` reads ours (anyone signed in);
--     `set_company_profile(p)` sets it (user.manage: company and system
--     administrators). Only the keys given change.

alter table public.companies add column if not exists name_kana text;
alter table public.companies add column if not exists name_en text;
alter table public.companies add column if not exists aliases text[] not null default '{}';
alter table public.companies add column if not exists registration_number text;
alter table public.companies add column if not exists postal_code text;
alter table public.companies add column if not exists address text;
alter table public.companies add column if not exists phone text;
alter table public.companies add column if not exists fax text;
alter table public.companies add column if not exists email text;

create or replace function public.company_profile()
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
           'id', c.id, 'code', c.code, 'name', c.name, 'name_kana', c.name_kana, 'name_en', c.name_en,
           'aliases', to_jsonb(c.aliases), 'registration_number', c.registration_number,
           'postal_code', c.postal_code, 'address', c.address, 'phone', c.phone, 'fax', c.fax,
           'email', c.email, 'updated_at', c.updated_at)
    from public.companies c
   where auth.uid() is not null or auth.role() = 'service_role'
   order by c.id limit 1;
$$;

-- A 登録番号 as T + 13 digits, whatever spacing or width it was typed in.
create or replace function public.normalize_registration_number(p text)
returns text
language sql immutable set search_path = '' as $$
  select case when length(regexp_replace(normalize(coalesce(p, ''), NFKC), '[^0-9]', '', 'g')) = 13
              then 'T' || regexp_replace(normalize(p, NFKC), '[^0-9]', '', 'g')
              else public.tidy_text(p) end;
$$;

create or replace function public.set_company_profile(p jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
begin
  if not public.has_permission('user.manage') then
    raise exception 'not permitted: user.manage required';
  end if;
  if p ? 'name' and public.tidy_text(p->>'name') is null then
    raise exception 'name is required';
  end if;
  select id into v_id from public.companies order by id limit 1;
  update public.companies set
    name = case when p ? 'name' then public.tidy_text(p->>'name') else name end,
    name_kana = case when p ? 'name_kana' then public.tidy_text(p->>'name_kana') else name_kana end,
    name_en = case when p ? 'name_en' then public.tidy_text(p->>'name_en') else name_en end,
    aliases = case when p ? 'aliases' then coalesce((
                select array_agg(distinct public.tidy_text(a)) from jsonb_array_elements_text(p->'aliases') a
                 where public.tidy_text(a) is not null), '{}') else aliases end,
    registration_number = case when p ? 'registration_number'
                               then public.normalize_registration_number(p->>'registration_number') else registration_number end,
    postal_code = case when p ? 'postal_code' then public.tidy_text(p->>'postal_code') else postal_code end,
    address = case when p ? 'address' then public.tidy_text(p->>'address') else address end,
    phone = case when p ? 'phone' then public.tidy_text(p->>'phone') else phone end,
    fax = case when p ? 'fax' then public.tidy_text(p->>'fax') else fax end,
    email = case when p ? 'email' then public.tidy_text(p->>'email') else email end,
    updated_at = now()
  where id = v_id;
  perform public.log_audit('company.profile_set', 'company', v_id::text, null, p);
  return public.company_profile();
end;
$$;

revoke all on function public.company_profile() from public, anon;
revoke all on function public.set_company_profile(jsonb) from public, anon;
grant execute on function public.company_profile() to authenticated, service_role;
grant execute on function public.set_company_profile(jsonb) to authenticated, service_role;
grant execute on function public.normalize_registration_number(text) to authenticated, service_role;
