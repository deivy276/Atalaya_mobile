-- Atalaya v3: accelerate fresh=true by precomputing the latest sample per tag.
-- This object is derived from public.atalaya_samples, so dropping/recreating it is safe.

DROP MATERIALIZED VIEW IF EXISTS public.atalaya_latest_samples_mv;

CREATE MATERIALIZED VIEW public.atalaya_latest_samples_mv AS
SELECT DISTINCT ON (LOWER(TRIM(TRAILING '.' FROM tag)))
       LOWER(TRIM(TRAILING '.' FROM tag)) AS tag_norm,
       tag AS actual_tag,
       value,
       created_at,
       id
FROM public.atalaya_samples
WHERE tag IS NOT NULL
  AND created_at IS NOT NULL
ORDER BY LOWER(TRIM(TRAILING '.' FROM tag)), created_at DESC, id DESC
WITH DATA;

CREATE UNIQUE INDEX idx_atalaya_latest_samples_mv_tag_norm
    ON public.atalaya_latest_samples_mv (tag_norm);

CREATE INDEX idx_atalaya_latest_samples_mv_created_at_desc
    ON public.atalaya_latest_samples_mv (created_at DESC);

ANALYZE public.atalaya_latest_samples_mv;
