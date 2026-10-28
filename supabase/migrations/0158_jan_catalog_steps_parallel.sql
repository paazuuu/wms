-- 0158: the stepping job (0157) steps every catalog waiting at once, each by
-- its id, instead of one a run: four catalogs of 250–420 pages finish in
-- about 20 minutes rather than an hour. Two steps of one catalog cannot
-- clash (jan-catalog upserts its entries, ignoring a JAN already added).
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
   where c.next_page is not null and c.kind = 'icata';
  $job$
);
