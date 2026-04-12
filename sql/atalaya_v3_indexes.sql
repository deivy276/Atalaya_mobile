CREATE INDEX IF NOT EXISTS idx_kp_state_key
    ON public.kp_state (key);

CREATE INDEX IF NOT EXISTS idx_alerts_created_at_desc
    ON public.atalaya_alerts (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_samples_tag_created_at_desc
    ON public.atalaya_samples (tag, created_at DESC);
