-- Runs the fetch-ev-news Edge Function every day at 6:00 AM Philippine time
-- (22:00 UTC). Run once in the SQL editor after deploying the function.
--
-- Replace <project-ref> with the project's reference and <anon-key> with the
-- legacy anon key from Project Settings > API. That key is the public client
-- key, so it is safe to keep in the database schedule.

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

select cron.unschedule('fetch-ev-news-daily')
where exists (select 1 from cron.job where jobname = 'fetch-ev-news-daily');

select cron.schedule(
  'fetch-ev-news-daily',
  '0 22 * * *',
  $$
  select net.http_post(
    url := 'https://<project-ref>.supabase.co/functions/v1/fetch-ev-news',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer <anon-key>"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);
