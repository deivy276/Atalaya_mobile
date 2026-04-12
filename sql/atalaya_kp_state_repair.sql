-- Atalaya KP_STATE repair script for IXACHI-45
-- Purpose:
--   1) back up current slot-related configuration
--   2) remove corrupted slot rows (for example VAR_1_UNIT with CSS/blob content)
--   3) load explicit VAR_n_TAG / VAR_n_LABEL mapping using real sample tags
-- Notes:
--   - This script does NOT touch atalaya_samples or atalaya_alerts.
--   - It uses VAR_n_TAG + VAR_n_LABEL on purpose, to avoid the ambiguity that existed
--     when VAR_n was reused as a tag/value field.
--   - Units are left blank initially, except where they are commonly safe to infer.
--     Fill them later if you want conversion options in the mobile app.

BEGIN;

-- 0) Optional backup of current slot-related rows
-- CREATE TABLE IF NOT EXISTS public.kp_state_backup AS
-- SELECT * FROM public.kp_state WHERE 1 = 0;
-- INSERT INTO public.kp_state_backup
-- SELECT * FROM public.kp_state
-- WHERE UPPER(key) LIKE 'VAR_%'
--    OR UPPER(key) LIKE 'VARIABLE_%'
--    OR UPPER(key) LIKE 'TAG_%'
--    OR UPPER(key) LIKE 'SIGNAL_%'
--    OR UPPER(key) LIKE 'POINT_%'
--    OR UPPER(key) IN ('CURRENT_WELL', 'CURRENT_JOB');

-- 1) Remove corrupted/ambiguous slot rows.
DELETE FROM public.kp_state
WHERE UPPER(key) LIKE 'VAR_%'
   OR UPPER(key) LIKE 'VARIABLE_%'
   OR UPPER(key) LIKE 'TAG_%'
   OR UPPER(key) LIKE 'SIGNAL_%'
   OR UPPER(key) LIKE 'POINT_%';

-- 2) Keep/update current context
DELETE FROM public.kp_state
WHERE UPPER(key) IN ('CURRENT_WELL', 'CURRENT_JOB');

INSERT INTO public.kp_state (key, value) VALUES
('CURRENT_WELL', 'IXACHI-45'),
('CURRENT_JOB',  'Monitoreo de pozo');

-- 3) Load slot mapping from real tags seen in atalaya_samples.
--    These labels are operational display names; adjust as needed.
INSERT INTO public.kp_state (key, value) VALUES
('VAR_1_TAG',   'RPMA.'),
('VAR_1_LABEL', 'RPM'),
('VAR_1_UNIT',  ''),

('VAR_2_TAG',   'TQA.'),
('VAR_2_LABEL', 'Torque'),
('VAR_2_UNIT',  ''),

('VAR_3_TAG',   'MFIA.'),
('VAR_3_LABEL', 'Mud Flow In'),
('VAR_3_UNIT',  ''),

('VAR_4_TAG',   'SPPA.'),
('VAR_4_LABEL', 'Standpipe Pressure'),
('VAR_4_UNIT',  'psi'),

('VAR_5_TAG',   'WOBA.'),
('VAR_5_LABEL', 'Weight on Bit'),
('VAR_5_UNIT',  ''),

('VAR_6_TAG',   'HKLA.'),
('VAR_6_LABEL', 'Hook Load'),
('VAR_6_UNIT',  ''),

('VAR_7_TAG',   'DBTM.'),
('VAR_7_LABEL', 'Bit Depth'),
('VAR_7_UNIT',  ''),

('VAR_8_TAG',   'DMEA.'),
('VAR_8_LABEL', 'Measured Depth'),
('VAR_8_UNIT',  ''),

('VAR_9_TAG',   'BPOS.'),
('VAR_9_LABEL', 'Block Position'),
('VAR_9_UNIT',  ''),

('VAR_10_LABEL','VAR 10'),
('VAR_10_UNIT', ''),
('VAR_11_LABEL','VAR 11'),
('VAR_11_UNIT', ''),
('VAR_12_LABEL','VAR 12'),
('VAR_12_UNIT', '');

COMMIT;

-- 4) Verification queries
-- SELECT key, value FROM public.kp_state ORDER BY key;
-- SELECT tag, MAX(created_at) AS latest_at FROM public.atalaya_samples GROUP BY tag ORDER BY latest_at DESC;
