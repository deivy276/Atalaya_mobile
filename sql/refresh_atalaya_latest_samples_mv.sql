-- Run this after new samples arrive, or schedule it externally.
REFRESH MATERIALIZED VIEW CONCURRENTLY public.atalaya_latest_samples_mv;
ANALYZE public.atalaya_latest_samples_mv;
