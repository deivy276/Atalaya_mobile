-- v3.1 alerts performance indexes
-- Safe to run multiple times.

DO $$
DECLARE
  cols text[];
  created_col text;
  candidate_schema text;
  candidate_table text;
  fk_col text;
  idx_name text;
BEGIN
  SELECT array_agg(column_name ORDER BY ordinal_position)
  INTO cols
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'atalaya_alerts';

  IF cols IS NOT NULL THEN
    SELECT c
    INTO created_col
    FROM unnest(ARRAY['created_at','created','alert_time','timestamp','ts','event_time','time']) AS c
    WHERE c = ANY(cols)
    LIMIT 1;

    IF created_col IS NOT NULL THEN
      EXECUTE format(
        'CREATE INDEX IF NOT EXISTS %I ON public.atalaya_alerts (%I DESC)',
        'idx_atalaya_alerts_' || created_col || '_desc',
        created_col
      );
    END IF;
  END IF;

  FOREACH candidate_table IN ARRAY ARRAY['atalaya_alert_attachments','atalaya_attachments','alert_attachments']
  LOOP
    candidate_schema := 'public';
    SELECT c
    INTO fk_col
    FROM (
      SELECT column_name AS c
      FROM information_schema.columns
      WHERE table_schema = candidate_schema
        AND table_name = candidate_table
        AND column_name IN ('alert_id','atalaya_alert_id','atalaya_alerts_id')
      ORDER BY CASE column_name
        WHEN 'alert_id' THEN 1
        WHEN 'atalaya_alert_id' THEN 2
        ELSE 3
      END
      LIMIT 1
    ) q;

    IF fk_col IS NOT NULL THEN
      idx_name := 'idx_' || candidate_table || '_' || fk_col;
      EXECUTE format(
        'CREATE INDEX IF NOT EXISTS %I ON %I.%I (%I)',
        idx_name,
        candidate_schema,
        candidate_table,
        fk_col
      );
    END IF;
  END LOOP;
END $$;
