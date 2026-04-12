# Atalaya v3.1.1 — Encoding cleanup only

This follow-up is for the state where:
- `/api/v1/alerts?fresh=true` is already fast enough from `BASE_TABLE`
- `public.atalaya_alerts_feed_mv` may still be empty
- alert descriptions still contain mojibake like `presiÃ³n` or `rotaciÃ³n`

## Files
- `atalaya_alerts_encoding_preview_and_fix.sql`

## How to use
1. Open the SQL file in pgAdmin/DBeaver/psql against the same database used by FastAPI.
2. Run only the preview section first.
3. Inspect `old_description` vs `new_description`.
4. If it looks correct, uncomment the `BEGIN; ... COMMIT;` block and run it.
5. Re-test:
   - `powershell -ExecutionPolicy Bypass -File .\backend_fastapi\scripts\benchmark_alerts_v31.ps1`
   - `python .\atalaya_v32_alerts\check_v32_alerts_api_case_insensitive.py`

## Notes
- This script updates the source table `public.atalaya_alerts`.
- It refreshes `public.atalaya_alerts_feed_mv` automatically if that materialized view exists.
- It does not touch Flutter, `kp_state`, dashboard variables, or trends.
