-- Rebuild public.atalaya_alerts_feed_mv so FastAPI v3.1 can use SUMMARY_MV
-- even when public.atalaya_alerts does not have a physical id column.
--
-- It also fixes the most common mojibake sequences directly inside the MV,
-- so the API can return clean Spanish text without depending on runtime repair.

DROP MATERIALIZED VIEW IF EXISTS public.atalaya_alerts_feed_mv;

CREATE MATERIALIZED VIEW public.atalaya_alerts_feed_mv AS
WITH src AS (
    SELECT
        -- Stable synthetic identifier when the source table lacks a real id.
        md5(
            coalesce(description, '') || '|' ||
            coalesce(severity, '') || '|' ||
            coalesce(created_at::text, '')
        ) AS synthetic_id,
        NULL::text AS raw_id_text,
        -- Fix common UTF-8/Latin-1 mojibake patterns that appear in the source data.
        trim(
            replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(
            replace(replace(replace(replace(replace(replace(replace(replace(
                coalesce(description, ''),
                'Ã¡', 'á'),
                'Ã©', 'é'),
                'Ã­', 'í'),
                'Ã³', 'ó'),
                'Ãº', 'ú'),
                'Ã', 'Á'),
                'Ã‰', 'É'),
                'Ã', 'Í'),
                'Ã“', 'Ó'),
                'Ãš', 'Ú'),
                'Ã±', 'ñ'),
                'Ã‘', 'Ñ'),
                'Ã¼', 'ü'),
                'Ãœ', 'Ü'),
                'Â¿', '¿'),
                'Â¡', '¡'),
                'Â°', '°'),
                'Â', ''
            )
        ) AS description,
        upper(trim(coalesce(severity, 'OK'))) AS severity,
        created_at
    FROM public.atalaya_alerts
    WHERE created_at IS NOT NULL
)
SELECT
    synthetic_id AS alert_id_text,
    raw_id_text,
    description,
    severity,
    created_at
FROM src
ORDER BY created_at DESC;

CREATE UNIQUE INDEX IF NOT EXISTS ux_atalaya_alerts_feed_mv_alert_id_text
    ON public.atalaya_alerts_feed_mv (alert_id_text);

CREATE INDEX IF NOT EXISTS ix_atalaya_alerts_feed_mv_created_at_desc
    ON public.atalaya_alerts_feed_mv (created_at DESC);

ANALYZE public.atalaya_alerts_feed_mv;

-- Quick verification
SELECT COUNT(*) AS mv_rows FROM public.atalaya_alerts_feed_mv;
SELECT alert_id_text, description, severity, created_at
FROM public.atalaya_alerts_feed_mv
ORDER BY created_at DESC
LIMIT 10;
