-- 0190: 出荷先カード — what an export needs, kept with each destination.
--
-- * ship_destinations (0139) gains: the company and address in English (for
--   the invoice), more phone numbers ({label, number}: 会社・担当者の携帯…),
--   a tax number with its kind (統一社会信用コード / VAT / EORI …), the port
--   or airport goods go to, the trade term (FOB / CIF / DAP …), how they go
--   (sea / air / courier / truck / other), a Notify Party when it is not the
--   consignee itself, the forwarder (通関業者) and who to reach there, and a
--   note of the documents needed.
-- * ship_destination_save keeps them; ship_destinations_list finds by them.
-- * outbound_files (0188/0189) remember the card a list went to: its id and
--   the card as it was then (ship_to), so a card changed later does not
--   change where goods went. outbound_file_set_destination sets (or clears)
--   it after posting; outbound_files_list / outbound_file_detail give it.

alter table public.ship_destinations add column if not exists name_en text;
alter table public.ship_destinations add column if not exists address_en text;
alter table public.ship_destinations add column if not exists phones jsonb not null default '[]'::jsonb;
alter table public.ship_destinations add column if not exists tax_id_kind text;
alter table public.ship_destinations add column if not exists tax_id text;
alter table public.ship_destinations add column if not exists port text;
alter table public.ship_destinations add column if not exists incoterms text;
alter table public.ship_destinations add column if not exists transport text;
alter table public.ship_destinations add column if not exists notify_same boolean not null default true;
alter table public.ship_destinations add column if not exists notify_name text;
alter table public.ship_destinations add column if not exists notify_address text;
alter table public.ship_destinations add column if not exists notify_contact text;
alter table public.ship_destinations add column if not exists notify_phone text;
alter table public.ship_destinations add column if not exists forwarder_name text;
alter table public.ship_destinations add column if not exists forwarder_contact text;
alter table public.ship_destinations add column if not exists forwarder_phone text;
alter table public.ship_destinations add column if not exists forwarder_email text;
alter table public.ship_destinations add column if not exists documents_note text;

alter table public.outbound_files add column if not exists destination_id bigint references public.ship_destinations (id);
alter table public.outbound_files add column if not exists ship_to jsonb;

-- [{label, number}], blanks left out.
create or replace function public.tidy_phones(p jsonb)
returns jsonb
language sql immutable set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('label', public.tidy_text(e->>'label'), 'number', public.tidy_text(e->>'number'))),
                  '[]'::jsonb)
    from jsonb_array_elements(case when jsonb_typeof(p) = 'array' then p else '[]'::jsonb end) e
   where public.tidy_text(e->>'number') is not null;
$$;

create or replace function public.ship_destinations_list(p_search text default null)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when not public.outbound_can_view() then '[]'::jsonb else coalesce((
    select jsonb_agg(to_jsonb(d) - 'company_id' order by d.last_used_at desc nulls last, d.use_count desc, d.name)
      from public.ship_destinations d
     where d.status = 'active'
       and (nullif(btrim(coalesce(p_search, '')), '') is null
            or concat_ws(' ', d.name, d.name_en, d.department, d.contact_name, d.postal_code, d.address1, d.address2,
                         d.address_en, d.phone, d.phones::text, d.tax_id, d.port, d.country_code, d.forwarder_name)
               ilike '%' || btrim(p_search) || '%')), '[]'::jsonb) end;
$$;

-- Saves one: a new one without an id, else changes the one with it.
create or replace function public.ship_destination_save(p jsonb)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint := nullif(p->>'id', '')::bigint;
  v_name text := public.tidy_text(p->>'name');
  v_same boolean := coalesce((p->>'notify_same')::boolean, true);
begin
  if not public.outbound_can_edit() then
    raise exception 'not permitted: pack.complete required';
  end if;
  if v_name is null then
    raise exception 'a company name is required';
  end if;
  if v_id is null then
    insert into public.ship_destinations (company_id, name) values ((select id from public.companies order by id limit 1), v_name)
    returning id into v_id;
    perform public.log_audit('ship_destination.created', 'ship_destination', v_id::text, null,
      jsonb_build_object('name', v_name));
  else
    perform 1 from public.ship_destinations where id = v_id and status = 'active';
    if not found then
      raise exception 'destination % not found', v_id;
    end if;
    perform public.log_audit('ship_destination.updated', 'ship_destination', v_id::text, null,
      jsonb_build_object('name', v_name));
  end if;
  update public.ship_destinations set
    party_id = nullif(p->>'party_id', '')::bigint,
    name = v_name,
    name_en = public.tidy_text(p->>'name_en'),
    department = public.tidy_text(p->>'department'),
    contact_name = public.tidy_text(p->>'contact_name'),
    postal_code = public.tidy_text(p->>'postal_code'),
    address1 = public.tidy_text(p->>'address1'),
    address2 = public.tidy_text(p->>'address2'),
    address_en = nullif(btrim(coalesce(p->>'address_en', '')), ''),
    phone = public.tidy_text(p->>'phone'),
    phones = public.tidy_phones(p->'phones'),
    email = public.tidy_text(p->>'email'),
    country_code = upper(public.tidy_text(p->>'country_code')),
    tax_id_kind = public.tidy_text(p->>'tax_id_kind'),
    tax_id = public.tidy_text(p->>'tax_id'),
    port = public.tidy_text(p->>'port'),
    incoterms = upper(public.tidy_text(p->>'incoterms')),
    transport = public.tidy_text(p->>'transport'),
    notify_same = v_same,
    notify_name = case when v_same then null else public.tidy_text(p->>'notify_name') end,
    notify_address = case when v_same then null else nullif(btrim(coalesce(p->>'notify_address', '')), '') end,
    notify_contact = case when v_same then null else public.tidy_text(p->>'notify_contact') end,
    notify_phone = case when v_same then null else public.tidy_text(p->>'notify_phone') end,
    forwarder_name = public.tidy_text(p->>'forwarder_name'),
    forwarder_contact = public.tidy_text(p->>'forwarder_contact'),
    forwarder_phone = public.tidy_text(p->>'forwarder_phone'),
    forwarder_email = public.tidy_text(p->>'forwarder_email'),
    documents_note = nullif(btrim(coalesce(p->>'documents_note', '')), ''),
    note = public.tidy_text(p->>'note'),
    updated_at = now()
   where id = v_id;
  return v_id;
end;
$$;

-- The card a posted list went to ([p_destination_id] null: none): kept as
-- it is now, the card counted as used.
create or replace function public.outbound_file_set_destination(p_id bigint, p_destination_id bigint)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_f public.outbound_files;
  v_d public.ship_destinations;
begin
  if auth.uid() is null or not public.can_post_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  select * into v_f from public.outbound_files where id = p_id for update;
  if v_f.id is null or not public.can_access_warehouse(v_f.warehouse_id) then
    raise exception 'outbound file % not found', p_id;
  end if;
  if p_destination_id is null then
    update public.outbound_files set destination_id = null, ship_to = null where id = p_id;
  else
    select * into v_d from public.ship_destinations where id = p_destination_id and status = 'active';
    if v_d.id is null then
      raise exception 'destination % not found', p_destination_id;
    end if;
    update public.outbound_files set
      destination_id = v_d.id,
      ship_to = to_jsonb(v_d) - 'company_id' - 'use_count' - 'last_used_at' - 'created_by' - 'status',
      destination = coalesce(destination, v_d.name)
     where id = p_id;
    update public.ship_destinations set use_count = use_count + 1, last_used_at = now() where id = v_d.id;
  end if;
  perform public.log_audit('outbound.destination_set', 'outbound_file', p_id::text, v_f.warehouse_id,
    jsonb_build_object('destination_id', p_destination_id));
  return true;
end;
$$;
revoke all on function public.outbound_file_set_destination(bigint, bigint) from public, anon;
grant execute on function public.outbound_file_set_destination(bigint, bigint) to authenticated;

-- outbound_files_list / outbound_file_detail (0188/0189) with the card.
do $mig$
declare
  d text;
  r text;
begin
  d := pg_get_functiondef('public.outbound_files_list(date, date, bigint)'::regprocedure);
  r := replace(d, '''kind'', f.kind, ''principal'', f.principal,',
                  '''kind'', f.kind, ''principal'', f.principal, ''destination_id'', f.destination_id, ''ship_to'', f.ship_to,');
  if r = d then raise exception 'outbound_files_list: no change'; end if;
  execute r;
  d := pg_get_functiondef('public.outbound_file_detail(bigint)'::regprocedure);
  r := replace(d, '''kind'', v_f.kind, ''principal'', v_f.principal,',
                  '''kind'', v_f.kind, ''principal'', v_f.principal, ''destination_id'', v_f.destination_id, ''ship_to'', v_f.ship_to,');
  if r = d then raise exception 'outbound_file_detail: no change'; end if;
  execute r;
end
$mig$;
