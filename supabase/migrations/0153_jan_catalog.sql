-- 0153: JAN catalogs — a maker's own catalog, read for its JAN codes, to check
-- a reading's JAN against.
--
-- A catalog is registered by its viewer URL (a mediapress iCata page, e.g.
-- the Pilot 総合カタログ). The jan-catalog edge function reads the text of
-- every page that carries a JAN, keeps each JAN with the text printed beside
-- it (usually the 品番) and the page it is on, and replaces what it had for
-- that catalog. Nothing here is a product: our own products and price book are
-- not changed. A JAN is looked up here only to say whether the maker lists it.

create table if not exists public.jan_catalogs (
  id bigint generated always as identity primary key,
  url text not null,
  host text not null,
  volume_id text not null,
  catalog_id text not null,
  design_id text not null default '',
  maker text,
  name text,
  published text,
  page_count integer,
  pages_read integer not null default 0,
  entry_count integer not null default 0,
  synced_at timestamptz,
  sync_error text,
  created_at timestamptz not null default now(),
  created_by uuid,
  unique (volume_id, catalog_id)
);

create table if not exists public.jan_catalog_entries (
  catalog_id bigint not null references public.jan_catalogs (id) on delete cascade,
  jan text not null check (jan ~ '^[0-9]{13}$'),
  -- What is printed just before the JAN on its line: usually the 品番 or a
  -- part of it (MAB-F, B-EF…). The whole line is kept beside it.
  code_hint text,
  line_text text,
  page_number text,
  page_group text,
  primary key (catalog_id, jan)
);
create index if not exists jan_catalog_entries_jan on public.jan_catalog_entries (jan);
create index if not exists jan_catalog_entries_prefix on public.jan_catalog_entries (left(jan, 7));

alter table public.jan_catalogs enable row level security;
alter table public.jan_catalog_entries enable row level security;

-- Read by whoever sees products; written only by the edge function (service role).
create policy jan_catalogs_read on public.jan_catalogs
  for select to authenticated using (public.has_permission('product.view'));
create policy jan_catalog_entries_read on public.jan_catalog_entries
  for select to authenticated using (public.has_permission('product.view'));

-- No insert/update/delete policy: RLS keeps every write to the service role.
grant select on public.jan_catalogs, public.jan_catalog_entries to authenticated;

-- The viewer opened at the page a JAN is on.
create or replace function public.jan_catalog_page_url(c public.jan_catalogs, p_page_group text)
returns text language sql immutable set search_path = '' as $$
  select 'https://' || c.host || '/iportal/CatalogViewInterfaceStartUpAction.do?method=startUp&mode=PAGE'
      || '&volumeID=' || c.volume_id || '&catalogId=' || c.catalog_id
      || '&pageGroupId=' || coalesce(p_page_group, '')
      || '&designID=' || c.design_id || '&designConfirmFlg=';
$$;

-- For each JAN asked about: whether a catalog lists it, and where; and, when
-- not, whether a catalog covers its maker at all (the first 7 digits, the
-- maker's GS1 prefix, seen in it) — a JAN of a maker with no catalog here
-- says nothing either way.
create or replace function public.jan_catalog_lookup(p_jans text[])
returns table (
  jan text, found boolean, covered boolean, maker text, catalog_name text,
  code_hint text, line_text text, page_number text, page_url text)
language sql stable security definer set search_path = '' as $$
  with asked as (
    select distinct j as jan from unnest(coalesce(p_jans, '{}')) j
     where j ~ '^[0-9]{13}$' and public.has_permission('product.view')
     limit 2000
  )
  select a.jan,
         e.jan is not null,
         e.jan is not null or exists (
           select 1 from public.jan_catalog_entries x where left(x.jan, 7) = left(a.jan, 7)),
         c.maker, c.name, e.code_hint, e.line_text, e.page_number,
         case when c.id is not null then public.jan_catalog_page_url(c, e.page_group) end
    from asked a
    left join lateral (
      select * from public.jan_catalog_entries x where x.jan = a.jan order by x.catalog_id desc limit 1) e on true
    left join public.jan_catalogs c on c.id = e.catalog_id;
$$;
revoke all on function public.jan_catalog_lookup(text[]) from public, anon;
grant execute on function public.jan_catalog_lookup(text[]) to authenticated;
revoke all on function public.jan_catalog_page_url(public.jan_catalogs, text) from public, anon;
grant execute on function public.jan_catalog_page_url(public.jan_catalogs, text) to authenticated;
