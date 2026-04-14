-- Optional high-volume alternative to MV refresh:
-- maintain a latest-by-tag table incrementally via trigger.

CREATE TABLE IF NOT EXISTS public.atalaya_latest_by_tag (
  tag_norm text PRIMARY KEY,
  actual_tag text NOT NULL,
  value double precision,
  created_at timestamptz NOT NULL,
  id bigint
);

CREATE INDEX IF NOT EXISTS idx_atalaya_latest_by_tag_created_at_desc
  ON public.atalaya_latest_by_tag (created_at DESC);

CREATE OR REPLACE FUNCTION public.fn_atalaya_upsert_latest_by_tag()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_tag_norm text;
BEGIN
  IF NEW.tag IS NULL OR NEW.created_at IS NULL THEN
    RETURN NEW;
  END IF;

  v_tag_norm := lower(trim(trailing '.' FROM NEW.tag));
  IF v_tag_norm = '' THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.atalaya_latest_by_tag(tag_norm, actual_tag, value, created_at, id)
  VALUES (v_tag_norm, NEW.tag, NEW.value, NEW.created_at, NEW.id)
  ON CONFLICT (tag_norm) DO UPDATE
    SET actual_tag = EXCLUDED.actual_tag,
        value = EXCLUDED.value,
        created_at = EXCLUDED.created_at,
        id = EXCLUDED.id
    WHERE EXCLUDED.created_at > public.atalaya_latest_by_tag.created_at
       OR (
            EXCLUDED.created_at = public.atalaya_latest_by_tag.created_at
            AND COALESCE(EXCLUDED.id, -1) > COALESCE(public.atalaya_latest_by_tag.id, -1)
          );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_atalaya_samples_latest_by_tag ON public.atalaya_samples;

CREATE TRIGGER trg_atalaya_samples_latest_by_tag
AFTER INSERT ON public.atalaya_samples
FOR EACH ROW
EXECUTE FUNCTION public.fn_atalaya_upsert_latest_by_tag();

-- Backfill once:
INSERT INTO public.atalaya_latest_by_tag(tag_norm, actual_tag, value, created_at, id)
SELECT DISTINCT ON (lower(trim(trailing '.' FROM tag)))
       lower(trim(trailing '.' FROM tag)) AS tag_norm,
       tag AS actual_tag,
       value,
       created_at,
       id
FROM public.atalaya_samples
WHERE tag IS NOT NULL
  AND created_at IS NOT NULL
ORDER BY lower(trim(trailing '.' FROM tag)), created_at DESC, id DESC
ON CONFLICT (tag_norm) DO UPDATE
  SET actual_tag = EXCLUDED.actual_tag,
      value = EXCLUDED.value,
      created_at = EXCLUDED.created_at,
      id = EXCLUDED.id;

ANALYZE public.atalaya_latest_by_tag;

