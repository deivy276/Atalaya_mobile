-- Optional pg_cron schedule for latest-samples MV refresh.
-- Recommended interval for near real-time dashboards: every 2-5 seconds.
-- Requires pg_cron extension enabled in the PostgreSQL instance.

-- CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Every 5 seconds:
SELECT cron.schedule(
  'atalaya_refresh_latest_samples_mv_5s',
  '*/5 * * * * *',
  $$REFRESH MATERIALIZED VIEW CONCURRENTLY public.atalaya_latest_samples_mv;$$
);

