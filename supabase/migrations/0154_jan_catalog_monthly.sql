-- 0154: the JAN catalogs (0153) read again once a month, so a catalog the
-- maker updates (a new edition at the same URL) is followed without anyone
-- pressing 再取込. Sent with the shared secret 0148 keeps in the vault.
-- On the 2nd of each month at 04:23 in Japan (19:23 UTC on the 1st).
select cron.schedule(
  'jan-catalog-refresh',
  '23 19 1 * *',
  $job$
  select net.http_post(
    url := 'https://vjunicsfobglmncjucbb.supabase.co/functions/v1/jan-catalog/refresh',
    headers := jsonb_build_object('Content-Type', 'application/json',
      'x-purge-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'purge_expired_secret')),
    body := '{}'::jsonb,
    timeout_milliseconds := 300000);
  $job$
);
