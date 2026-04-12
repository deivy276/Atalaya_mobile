-- v3.1 alerts feed materialized view
-- Creates a lightweight summary used by /api/v1/alerts fresh=true.
-- Safe to re-run; it recreates the MV using the real columns found in public.atalaya_alerts.

DO $$
DECLARE
  cols text[];
  id_col text;
  desc_col text;
  sev_col text;
  created_col text;
  desc_expr text;
  sev_expr text;
  alert_id_expr text;
  raw_id_expr text;
  sql_stmt text;
BEGIN
  SELECT array_agg(column_name ORDER BY ordinal_position)
  INTO cols
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'atalaya_alerts';

  IF cols IS NULL THEN
    RAISE EXCEPTION 'public.atalaya_alerts was not found in the current database/schema.';
  END IF;

  SELECT c INTO id_col
  FROM unnest(ARRAY['id','alert_id','atalaya_alert_id']) AS c
  WHERE c = ANY(cols)
  LIMIT 1;

  SELECT c INTO desc_col
  FROM unnest(ARRAY['description','message','comment','comments','text','details','alert_description']) AS c
  WHERE c = ANY(cols)
  LIMIT 1;

  SELECT c INTO sev_col
  FROM unnest(ARRAY['severity','level','status','priority']) AS c
  WHERE c = ANY(cols)
  LIMIT 1;

  SELECT c INTO created_col
  FROM unnest(ARRAY['created_at','created','alert_time','timestamp','ts','event_time','time']) AS c
  WHERE c = ANY(cols)
  LIMIT 1;

  IF created_col IS NULL THEN
    RAISE EXCEPTION 'public.atalaya_alerts has no timestamp column compatible with v3.1.';
  END IF;

  desc_expr := CASE
    WHEN desc_col IS NOT NULL THEN format('COALESCE(%I, '''')', desc_col)
    ELSE ''''::text
  END;

  sev_expr := CASE
    WHEN sev_col IS NOT NULL THEN format('UPPER(COALESCE(%I, ''OK''))', sev_col)
    ELSE '''OK''::text'
  END;

  IF id_col IS NOT NULL THEN
    alert_id_expr := format('%I::text', id_col);
    raw_id_expr := format('%I::text', id_col);
  ELSE
    alert_id_expr := format(
      'md5(COALESCE(%I::text, '''') || ''|'' || %s || ''|'' || %s)',
      created_col,
      desc_expr,
      sev_expr
    );
    raw_id_expr := 'NULL::text';
  END IF;

  EXECUTE 'DROP MATERIALIZED VIEW IF EXISTS public.atalaya_alerts_feed_mv';

  sql_stmt := format(
    'CREATE MATERIALIZED VIEW public.atalaya_alerts_feed_mv AS
     SELECT %s AS alert_id_text,
            %s AS raw_id_text,
            %s AS description,
            %s AS severity,
            %I AS created_at
     FROM public.atalaya_alerts
     WHERE %I IS NOT NULL',
    alert_id_expr,
    raw_id_expr,
    desc_expr,
    sev_expr,
    created_col,
    created_col
  );

  EXECUTE sql_stmt;

  EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS idx_atalaya_alerts_feed_mv_alert_id_text ON public.atalaya_alerts_feed_mv (alert_id_text)';
  EXECUTE 'CREATE INDEX IF NOT EXISTS idx_atalaya_alerts_feed_mv_created_at_desc ON public.atalaya_alerts_feed_mv (created_at DESC)';
  EXECUTE 'CREATE INDEX IF NOT EXISTS idx_atalaya_alerts_feed_mv_raw_id_text ON public.atalaya_alerts_feed_mv (raw_id_text)';

  EXECUTE 'ANALYZE public.atalaya_alerts_feed_mv';
END $$;
