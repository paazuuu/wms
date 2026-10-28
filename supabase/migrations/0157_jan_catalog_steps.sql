-- 0157: a catalog read a few pages at a time.
--
-- A whole catalog (Pilot 373 pages, Lion 920) is more than one edge-function
-- run may compute (WORKER_RESOURCE_LIMIT). jan_catalogs.next_page is where a
-- read has got to (null: not being read). jan-catalog/sync now only sets it
-- to 0; jan-catalog/step reads the next 40 pages of one catalog waiting.
--
--   * the app steps the catalog it asked for, showing how far;
--   * every 2 minutes the database steps whichever catalog is waiting, so a
--     read the app left (a closed tab) still finishes;
--   * on the 2nd of each month every viewer catalog is set back to page 0
--     (0154's job, now without an HTTP call of its own).

alter table public.jan_catalogs add column if not exists next_page integer;

select cron.schedule(
  'jan-catalog-refresh',
  '23 19 1 * *',
  $job$ update public.jan_catalogs set next_page = 0 where kind = 'icata'; $job$
);

select cron.schedule(
  'jan-catalog-step',
  '*/2 * * * *',
  $job$
  select net.http_post(
    url := 'https://vjunicsfobglmncjucbb.supabase.co/functions/v1/jan-catalog/step',
    headers := jsonb_build_object('Content-Type', 'application/json',
      'x-purge-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'purge_expired_secret')),
    body := '{}'::jsonb,
    timeout_milliseconds := 140000)
   where exists (select 1 from public.jan_catalogs where next_page is not null and kind = 'icata');
  $job$
);
