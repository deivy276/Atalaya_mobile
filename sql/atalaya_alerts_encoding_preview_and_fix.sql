-- Atalaya v3.1.1 - Preview and fix mojibake in alert descriptions
-- Run this in the SAME PostgreSQL database used by FastAPI.
-- Safe workflow:
--   1) Execute the preview SELECTs first and inspect results.
--   2) If they look correct, execute the UPDATE block.
--   3) Refresh the alerts materialized view if present.

-- ============================================================
-- 1) PREVIEW rows that likely contain mojibake
-- ============================================================
WITH candidate_rows AS (
  SELECT
    ctid,
    created_at,
    description,
    REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(description,
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
        'â', '’'),
        'â', '"'),
        'â', '"'),
        'â', '-'),
        'â', '-'),
        'â¦', '...'),
        'Â ', ' '),
        'Â', ''),
        'Ã ', 'à '),
        'Ã', 'á'),
        'â€™', '’') AS repaired_description
  FROM public.atalaya_alerts
  WHERE description IS NOT NULL
    AND (
      description LIKE '%Ã%'
      OR description LIKE '%Â%'
      OR description LIKE '%â%'
    )
)
SELECT created_at, description AS old_description, repaired_description AS new_description
FROM candidate_rows
ORDER BY created_at DESC
LIMIT 200;

-- ============================================================
-- 2) APPLY FIX
--    Uncomment this block only after reviewing the preview above.
-- ============================================================
/*
BEGIN;

UPDATE public.atalaya_alerts
SET description = repaired.repaired_description
FROM (
  SELECT
    ctid,
    REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(
      REPLACE(description,
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
        'â', '’'),
        'â', '"'),
        'â', '"'),
        'â', '-'),
        'â', '-'),
        'â¦', '...'),
        'Â ', ' '),
        'Â', ''),
        'Ã ', 'à '),
        'Ã', 'á'),
        'â€™', '’') AS repaired_description
  FROM public.atalaya_alerts
  WHERE description IS NOT NULL
    AND (
      description LIKE '%Ã%'
      OR description LIKE '%Â%'
      OR description LIKE '%â%'
    )
) AS repaired
WHERE public.atalaya_alerts.ctid = repaired.ctid
  AND public.atalaya_alerts.description IS DISTINCT FROM repaired.repaired_description;

-- Refresh alerts MV if it exists.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_matviews
    WHERE schemaname = 'public'
      AND matviewname = 'atalaya_alerts_feed_mv'
  ) THEN
    EXECUTE 'REFRESH MATERIALIZED VIEW public.atalaya_alerts_feed_mv';
  END IF;
END $$;

COMMIT;
*/

-- ============================================================
-- 3) VERIFY AFTER UPDATE
-- ============================================================
-- Re-run the preview query. Ideally it should return 0 rows.
-- Then test the API again:
--   powershell -ExecutionPolicy Bypass -File .\backend_fastapi\scripts\benchmark_alerts_v31.ps1
--   python .\atalaya_v32_alerts\check_v32_alerts_api_case_insensitive.py
