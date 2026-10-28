-- 0159: catalogs from a meclib e-book library (Kobe Ecole's maker catalog
-- library: ゼブラ, 三菱鉛筆, ぺんてる, コクヨ, キングジム … some 90 books).
--
-- A meclib book (https://<site>.meclib.jp/<book>/book/) has its pages' text
-- for search (data/txtsearch.txt, digits run together) and, where the book
-- allows it from a PC (book.txt `pdf`), each page as a PDF (pdf/0001.pdf).
-- jan-catalog reads the pages whose text has a JAN's digits from their PDFs,
-- placing JANs and weights by where they sit, as for the other catalogs; a
-- book that offers no PDF is not read. Kind 'meclib'; its catalog_id is the
-- book's id. A JAN's link opens the book at its page.

do $$
begin
  if exists (select 1 from pg_constraint where conname = 'jan_catalogs_kind_check'
              and pg_get_constraintdef(oid) not like '%meclib%') then
    alter table public.jan_catalogs drop constraint jan_catalogs_kind_check;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'jan_catalogs_kind_check') then
    alter table public.jan_catalogs add constraint jan_catalogs_kind_check check (kind in ('icata', 'pdf', 'meclib'));
  end if;
end $$;

create or replace function public.jan_catalog_page_url(c public.jan_catalogs, p_page_group text)
returns text language sql immutable set search_path = '' as $$
  select case
    when c.kind = 'pdf' then
      case when coalesce(c.url, '') ~ '^https?://' then c.url || '#page=' || coalesce(p_page_group, '') end
    when c.kind = 'meclib' then
      'https://' || c.host || '/' || c.catalog_id || '/book/index.html#target/page_no=' || coalesce(p_page_group, '1')
    else 'https://' || c.host || '/iportal/CatalogViewInterfaceStartUpAction.do?method=startUp&mode=PAGE'
      || '&volumeID=' || c.volume_id || '&catalogId=' || c.catalog_id
      || '&pageGroupId=' || coalesce(p_page_group, '')
      || '&designID=' || c.design_id || '&designConfirmFlg='
  end;
$$;

select cron.schedule(
  'jan-catalog-refresh',
  '23 19 1 * *',
  $job$ update public.jan_catalogs set next_page = 0 where kind in ('icata', 'meclib'); $job$
);

select cron.schedule(
  'jan-catalog-step',
  '*/2 * * * *',
  $job$
  select net.http_post(
    url := 'https://vjunicsfobglmncjucbb.supabase.co/functions/v1/jan-catalog/step',
    headers := jsonb_build_object('Content-Type', 'application/json',
      'x-purge-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'purge_expired_secret')),
    body := jsonb_build_object('catalog_id', c.id),
    timeout_milliseconds := 140000)
    from public.jan_catalogs c
   where c.next_page is not null and c.kind in ('icata', 'meclib');
  $job$
);
