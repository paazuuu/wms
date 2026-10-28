-- 0160: 参照資料 — what the JAN catalogs (0153–0159) were read from, and any
-- web page or PDF a person adds, kept with a copy as it was each time, by
-- fiscal year (年度: April to March, Japan time), to look back on.
--
-- * reference_sources: one per catalog (jan_catalog_id; kept when the catalog
--   is deleted, so its history stays) and one per site a person adds (url).
-- * reference_snapshots: a copy as it was — taken when a catalog has been
--   read (its JANs with 品番・重量・page, and a meclib book's text), or when a
--   site is saved (the page's HTML and its text, or the PDF itself). A new
--   copy only when the content changed (content_hash); else last_checked_at.
-- * Files in the private bucket reference-archive, read by product.view;
--   written by the jan-catalog function (service role) only.

create table if not exists public.reference_sources (
  id bigint generated always as identity primary key,
  kind text not null check (kind in ('catalog', 'site')),
  jan_catalog_id bigint unique references public.jan_catalogs (id) on delete set null,
  url text not null,
  title text,
  maker text,
  note text,
  last_checked_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid
);
create unique index if not exists reference_sources_site_url on public.reference_sources (url) where kind = 'site';

create table if not exists public.reference_snapshots (
  id bigint generated always as identity primary key,
  source_id bigint not null references public.reference_sources (id) on delete cascade,
  taken_at timestamptz not null default now(),
  fiscal_year integer not null,
  title text,
  edition text,
  page_count integer,
  entry_count integer,
  weight_count integer,
  content_hash text,
  -- [{"kind": "entries"|"text"|"html"|"pdf", "path": "...", "bytes": n, "type": "..."}]
  files jsonb not null default '[]'::jsonb,
  note text
);
create index if not exists reference_snapshots_source on public.reference_snapshots (source_id, taken_at desc);
create index if not exists reference_snapshots_year on public.reference_snapshots (fiscal_year);

-- 年度 of a moment: April to March, in Japan.
create or replace function public.jp_fiscal_year(p_at timestamptz)
returns integer language sql stable set search_path = '' as $$
  select extract(year from ((p_at at time zone 'Asia/Tokyo') - interval '3 months'))::integer;
$$;

create or replace function public.reference_snapshots_year()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.fiscal_year := public.jp_fiscal_year(coalesce(new.taken_at, now()));
  return new;
end;
$$;
create or replace trigger reference_snapshots_year before insert or update of taken_at on public.reference_snapshots
  for each row execute function public.reference_snapshots_year();

alter table public.reference_sources enable row level security;
alter table public.reference_snapshots enable row level security;
create policy reference_sources_read on public.reference_sources
  for select to authenticated using (public.has_permission('product.view'));
create policy reference_snapshots_read on public.reference_snapshots
  for select to authenticated using (public.has_permission('product.view'));
grant select on public.reference_sources, public.reference_snapshots to authenticated;

insert into storage.buckets (id, name, public)
values ('reference-archive', 'reference-archive', false)
on conflict (id) do nothing;

create policy reference_archive_read on storage.objects
  for select to authenticated
  using (bucket_id = 'reference-archive' and public.has_permission('product.view'));

-- Sites saved again on the 2nd of each month, beside the catalogs (0157).
select cron.schedule(
  'reference-sites-refresh',
  '41 19 1 * *',
  $job$
  select net.http_post(
    url := 'https://vjunicsfobglmncjucbb.supabase.co/functions/v1/jan-catalog/reference/refresh',
    headers := jsonb_build_object('Content-Type', 'application/json',
      'x-purge-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'purge_expired_secret')),
    body := '{}'::jsonb,
    timeout_milliseconds := 140000);
  $job$
);
