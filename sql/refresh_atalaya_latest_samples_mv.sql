-- Run this after new samples arrive, or schedule it externally (recommended cadence: every 2-5s).
REFRESH MATERIALIZED VIEW CONCURRENTLY public.atalaya_latest_samples_mv;
ANALYZE public.atalaya_latest_samples_mv;
