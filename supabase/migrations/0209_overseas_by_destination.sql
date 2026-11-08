-- 0209: 国外の仮想在庫, by 出荷先カード.
--
-- Each site abroad is a 出荷先カード's summary: what we shipped to it, and
-- what the partner (downstream) says it still holds. Apart from our own
-- stock: nothing here moves it.
-- * overseas_sites.destination_id: the card the site is (one site a card);
--   is_default marks the one made here — 国外の仮想在庫（中国・広東）, made
--   with its card.
-- * overseas_shipments / overseas_shipment_lines: every list shipped to a
--   card (status shipped, not taken back, not replaced) is recorded, its rows
--   copied (version: the rows as last copied). Taken back or put back to
--   planned, the record is marked removed. Kept by a trigger on
--   outbound_files, run at the end of the transaction (the rows are written
--   after the list).
-- * overseas_site_for_destination(card): the card's site, made if missing.
-- * overseas_site_estimate(site): each product — shipped in all, the last
--   count the partner gave (and its day), shipped since, and the estimate:
--   that count + shipped since (or everything shipped, before any count).
-- * overseas_destinations_list: the sites with their card, shipments, the
--   last count and the estimate.
-- * overseas_estimate_overview(q): each product across the sites, by the
--   estimate.
-- * overseas_site_events(site): the shipments and the counts given, for
--   the charts (stock over time, what was used between counts).

alter table public.overseas_sites add column if not exists destination_id bigint references public.ship_destinations(id);
alter table public.overseas_sites add column if not exists is_default boolean not null default false;
create unique index if not exists overseas_sites_destination on public.overseas_sites (destination_id) where destination_id is not null;

create table if not exists public.overseas_shipments (
  id bigint generated always as identity primary key,
  site_id bigint not null references public.overseas_sites(id),
  outbound_file_id bigint not null unique,
  shipped_on date not null,
  file_name text,
  kind text,
  version integer not null default 0,
  line_count integer not null default 0,
  units numeric not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  removed_at timestamptz
);
create index if not exists overseas_shipments_site on public.overseas_shipments (site_id, shipped_on) where removed_at is null;

create table if not exists public.overseas_shipment_lines (
  id bigint generated always as identity primary key,
  shipment_id bigint not null references public.overseas_shipments(id),
  version integer not null,
  row_no integer,
  product_id bigint,
  jan text,
  code text,
  name text,
  maker text,
  quantity numeric not null default 0
);
create index if not exists overseas_shipment_lines_shipment on public.overseas_shipment_lines (shipment_id, version);

alter table public.overseas_shipments enable row level security;
alter table public.overseas_shipment_lines enable row level security;

-- A product as compared across shipments and counts: its JAN, else its
-- 品番 and name.
create or replace function public.overseas_key(p_jan text, p_code text, p_name text)
returns text language sql immutable set search_path = '' as $$
  select coalesce(nullif(btrim(p_jan), ''), 'c:' || lower(btrim(coalesce(p_code, ''))) || ':' || lower(btrim(coalesce(p_name, ''))));
$$;
grant execute on function public.overseas_key(text, text, text) to authenticated;

create or replace function public.overseas_site_for_destination(p_destination_id bigint)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
  v_d public.ship_destinations;
begin
  select id into v_id from public.overseas_sites where destination_id = p_destination_id;
  if v_id is not null then
    return v_id;
  end if;
  select * into v_d from public.ship_destinations where id = p_destination_id;
  if v_d.id is null then
    return null;
  end if;
  insert into public.overseas_sites (name, kind, country, destination_id, note)
  values (v_d.name, 'partner', v_d.country_code, v_d.id, null)
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.overseas_site_for_destination(bigint) from public, anon;
grant execute on function public.overseas_site_for_destination(bigint) to authenticated;

-- The list's state now, recorded for its card (or the record removed).
create or replace function public.overseas_record_outbound(p_file_id bigint)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_f public.outbound_files;
  v_ship public.overseas_shipments;
  v_site bigint;
  v_version integer;
begin
  select * into v_f from public.outbound_files where id = p_file_id;
  select * into v_ship from public.overseas_shipments where outbound_file_id = p_file_id;
  if v_f.id is null or v_f.status <> 'shipped' or v_f.undone_at is not null or v_f.replaced_by is not null
     or v_f.destination_id is null then
    if v_ship.id is not null and v_ship.removed_at is null then
      update public.overseas_shipments set removed_at = now(), updated_at = now() where id = v_ship.id;
    end if;
    return;
  end if;
  v_site := public.overseas_site_for_destination(v_f.destination_id);
  if v_site is null then
    return;
  end if;
  if v_ship.id is null then
    insert into public.overseas_shipments (site_id, outbound_file_id, shipped_on, file_name, kind, version)
    values (v_site, v_f.id, v_f.shipped_on, v_f.file_name, v_f.kind, 1)
    returning * into v_ship;
    v_version := 1;
  else
    v_version := v_ship.version + 1;
    update public.overseas_shipments set site_id = v_site, shipped_on = v_f.shipped_on, file_name = v_f.file_name,
           kind = v_f.kind, version = v_version, removed_at = null, updated_at = now()
     where id = v_ship.id;
  end if;
  insert into public.overseas_shipment_lines (shipment_id, version, row_no, product_id, jan, code, name, maker, quantity)
  select v_ship.id, v_version, l.row_no, l.product_id, nullif(btrim(coalesce(l.jan_code, '')), ''), l.item_code, l.product_name, l.maker,
         case when l.action = 'ship' then coalesce(l.shipped_quantity, l.quantity, 0) else coalesce(l.quantity, 0) end
    from public.outbound_file_lines l
   where l.file_id = v_f.id and l.action in ('ship', 'record');
  update public.overseas_shipments s set
    line_count = (select count(*) from public.overseas_shipment_lines x where x.shipment_id = s.id and x.version = v_version),
    units = (select coalesce(sum(x.quantity), 0) from public.overseas_shipment_lines x where x.shipment_id = s.id and x.version = v_version)
   where s.id = v_ship.id;
end;
$$;
revoke all on function public.overseas_record_outbound(bigint) from public, anon;

create or replace function public.overseas_track_outbound()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.overseas_record_outbound(new.id);
  return null;
end;
$$;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'overseas_track_outbound') then
    create constraint trigger overseas_track_outbound
      after insert or update of status, undone_at, destination_id, replaced_by, shipped_on on public.outbound_files
      deferrable initially deferred
      for each row execute function public.overseas_track_outbound();
  end if;
end $$;

-- Lists already shipped to a card.
do $$
declare
  f record;
begin
  for f in select id from public.outbound_files where status = 'shipped' and destination_id is not null loop
    perform public.overseas_record_outbound(f.id);
  end loop;
end $$;

-- The default: 国外の仮想在庫（中国・広東）, a card and its site.
do $$
declare
  v_card bigint;
begin
  if not exists (select 1 from public.overseas_sites where is_default) then
    insert into public.ship_destinations (company_id, name, name_en, country_code, address1, note)
    values ((select id from public.companies order by id limit 1), '国外の仮想在庫（中国・広東）',
            'Overseas virtual stock (Guangdong, China)', 'CN', '中国 広東省', '国外の仮想在庫のデフォルトの出荷先（0209）')
    returning id into v_card;
    insert into public.overseas_sites (name, kind, country, city, destination_id, is_default)
    values ('国外の仮想在庫（中国・広東）', 'branch', '中国', '広東', v_card, true);
  end if;
end $$;

-- ------------------------------------------------------------ reading

create or replace function public.overseas_site_estimate(p_site_id bigint)
returns table (k text, jan text, code text, name text, maker text, unit text, shipped_total numeric,
               reported numeric, reported_on date, shipped_since numeric, estimate numeric)
language sql stable security definer set search_path = '' as $$
  with rep as (
    select i.id, i.as_of from public.overseas_stock_imports i where i.id = public.overseas_latest_import(p_site_id)
  ), sh as (
    select public.overseas_key(l.jan, l.code, l.name) as k, l.jan, l.code, l.name, l.maker, l.quantity, s.shipped_on
      from public.overseas_shipments s
      join public.overseas_shipment_lines l on l.shipment_id = s.id and l.version = s.version
     where s.site_id = p_site_id and s.removed_at is null
  ), shg as (
    select sh.k, max(sh.jan) as jan, max(sh.code) as code, max(sh.name) as name, max(sh.maker) as maker,
           sum(sh.quantity) as total,
           sum(sh.quantity) filter (where (select as_of from rep) is null or sh.shipped_on > (select as_of from rep)) as since
      from sh group by sh.k
  ), rlg as (
    select public.overseas_key(l.jan, l.code, l.name) as k, max(l.jan) as jan, max(l.code) as code, max(l.name) as name,
           max(l.maker) as maker, max(l.unit) as unit, sum(l.quantity) as reported
      from public.overseas_stock_lines l join rep on rep.id = l.import_id
     group by 1
  )
  select coalesce(r.k, s.k), coalesce(r.jan, s.jan), coalesce(s.code, r.code), coalesce(s.name, r.name), coalesce(s.maker, r.maker),
         r.unit, coalesce(s.total, 0),
         case when (select id from rep) is null then null else coalesce(r.reported, 0) end,
         (select as_of from rep),
         coalesce(s.since, 0),
         case when (select id from rep) is null then coalesce(s.total, 0) else coalesce(r.reported, 0) + coalesce(s.since, 0) end
    from rlg r full join shg s on s.k = r.k;
$$;
revoke all on function public.overseas_site_estimate(bigint) from public, anon;
grant execute on function public.overseas_site_estimate(bigint) to authenticated;

create or replace function public.overseas_destinations_list(p_include_archived boolean default false)
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when not public.overseas_can_view() then '[]'::jsonb else coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', s.id, 'name', s.name, 'kind', s.kind, 'country', s.country, 'city', s.city,
      'contact', s.contact, 'note', s.note, 'archived_at', s.archived_at, 'is_default', s.is_default,
      'destination_id', s.destination_id,
      'destination_name', (select d.name from public.ship_destinations d where d.id = s.destination_id),
      'latest', (select jsonb_build_object('id', i.id, 'as_of', i.as_of, 'line_count', i.line_count,
                                           'units', i.units, 'file_name', i.file_name, 'read_by', i.read_by)
                   from public.overseas_stock_imports i where i.id = public.overseas_latest_import(s.id)),
      'import_count', (select count(*) from public.overseas_stock_imports i where i.site_id = s.id and i.undone_at is null),
      'shipment_count', (select count(*) from public.overseas_shipments x where x.site_id = s.id and x.removed_at is null),
      'shipped_units', (select coalesce(sum(x.units), 0) from public.overseas_shipments x where x.site_id = s.id and x.removed_at is null),
      'last_shipped_on', (select max(x.shipped_on) from public.overseas_shipments x where x.site_id = s.id and x.removed_at is null),
      'estimate_units', (select coalesce(sum(e.estimate), 0) from public.overseas_site_estimate(s.id) e),
      'estimate_items', (select count(*) from public.overseas_site_estimate(s.id) e where e.estimate <> 0),
      'note_count', (select count(*) from public.record_notes n
                      where n.subject_kind = 'overseas_site' and n.subject_id = s.id and n.removed_at is null)
    ) order by s.archived_at nulls first, s.is_default desc, s.name, s.id)
      from public.overseas_sites s
     where p_include_archived or s.archived_at is null), '[]'::jsonb) end;
$$;

create or replace function public.overseas_site_stock(p_site_id bigint)
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when not public.overseas_can_view() then '[]'::jsonb else coalesce((
    select jsonb_agg(jsonb_build_object(
      'jan', e.jan, 'code', e.code, 'name', e.name, 'maker', e.maker, 'unit', e.unit,
      'shipped_total', e.shipped_total, 'reported', e.reported, 'reported_on', e.reported_on,
      'shipped_since', e.shipped_since, 'estimate', e.estimate,
      'ours', (select pr.name from public.products pr where e.jan is not null and pr.jan_code = e.jan limit 1)
    ) order by e.maker nulls last, e.name nulls last, e.k)
      from public.overseas_site_estimate(p_site_id) e), '[]'::jsonb) end;
$$;

create or replace function public.overseas_estimate_overview(p_q text default null, p_limit integer default 500)
returns jsonb language sql stable security definer set search_path = '' as $$
  with e as (
    select s.id as site_id, s.name as site_name, s.kind, s.country, x.*
      from public.overseas_sites s cross join lateral public.overseas_site_estimate(s.id) x
     where s.archived_at is null
       and (p_q is null or btrim(p_q) = ''
            or concat_ws(' ', x.jan, x.code, x.name, x.maker) ilike '%' || btrim(p_q) || '%')
  ), g as (
    select e.k, max(e.jan) as jan, max(e.code) as code, max(e.name) as name, max(e.maker) as maker, max(e.unit) as unit,
           sum(e.estimate) as total,
           jsonb_agg(jsonb_build_object('site_id', e.site_id, 'site_name', e.site_name, 'kind', e.kind, 'country', e.country,
                                        'quantity', e.estimate, 'as_of', e.reported_on) order by e.site_name) as sites
      from e group by e.k
  )
  select case when not public.overseas_can_view() then '[]'::jsonb else coalesce((
    select jsonb_agg(jsonb_build_object(
      'jan', g.jan, 'code', g.code, 'name', g.name, 'maker', g.maker, 'unit', g.unit, 'total', g.total, 'sites', g.sites,
      'ours', (select pr.name from public.products pr where g.jan is not null and pr.jan_code = g.jan limit 1)
    ) order by g.total desc, g.name)
      from (select * from g order by total desc, name limit greatest(1, least(coalesce(p_limit, 500), 5000))) g), '[]'::jsonb) end;
$$;

create or replace function public.overseas_site_events(p_site_id bigint)
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when not public.overseas_can_view() then jsonb_build_object('shipments', '[]'::jsonb, 'reports', '[]'::jsonb)
  else jsonb_build_object(
    'shipments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'outbound_file_id', s.outbound_file_id, 'shipped_on', s.shipped_on, 'file_name', s.file_name,
        'kind', s.kind, 'line_count', s.line_count, 'units', s.units,
        'lines', coalesce((select jsonb_agg(jsonb_build_object('jan', l.jan, 'code', l.code, 'name', l.name, 'maker', l.maker,
                                                               'quantity', l.quantity) order by l.row_no, l.id)
                             from public.overseas_shipment_lines l where l.shipment_id = s.id and l.version = s.version), '[]'::jsonb)
      ) order by s.shipped_on, s.id)
        from public.overseas_shipments s where s.site_id = p_site_id and s.removed_at is null), '[]'::jsonb),
    'reports', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', i.id, 'as_of', i.as_of, 'file_name', i.file_name,
        'lines', coalesce((select jsonb_agg(jsonb_build_object('jan', l.jan, 'code', l.code, 'name', l.name, 'maker', l.maker,
                                                               'quantity', l.quantity) order by l.row_no, l.id)
                             from public.overseas_stock_lines l where l.import_id = i.id), '[]'::jsonb)
      ) order by i.as_of, i.id)
        from public.overseas_stock_imports i where i.site_id = p_site_id and i.undone_at is null), '[]'::jsonb)
  ) end;
$$;

revoke all on function public.overseas_destinations_list(boolean) from public, anon;
revoke all on function public.overseas_site_stock(bigint) from public, anon;
revoke all on function public.overseas_estimate_overview(text, integer) from public, anon;
revoke all on function public.overseas_site_events(bigint) from public, anon;
grant execute on function public.overseas_destinations_list(boolean) to authenticated;
grant execute on function public.overseas_site_stock(bigint) to authenticated;
grant execute on function public.overseas_estimate_overview(text, integer) to authenticated;
grant execute on function public.overseas_site_events(bigint) to authenticated;

-- A site of a card (chosen or made from the screen).
create or replace function public.overseas_site_for_card(p_destination_id bigint)
returns bigint language plpgsql security definer set search_path = '' as $$
begin
  if not public.overseas_can_edit() then
    raise exception 'not permitted';
  end if;
  return public.overseas_site_for_destination(p_destination_id);
end;
$$;
revoke all on function public.overseas_site_for_card(bigint) from public, anon;
grant execute on function public.overseas_site_for_card(bigint) to authenticated;
