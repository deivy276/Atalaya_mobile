# Atalaya v3.1.1 — Alerts MV rebuild

Este parche no toca Flutter ni FastAPI.

Se usa cuando:
- `check_v31_alerts_mv_backend.py` muestra que `public.atalaya_alerts_feed_mv` existe,
- pero `row_count = 0`,
- y `benchmark_alerts_v31.ps1` sigue mostrando `XAlertsSource = BASE_TABLE`.

## Qué corrige

1. Recrea `public.atalaya_alerts_feed_mv` desde `public.atalaya_alerts`.
2. Genera `alert_id_text` sintético, para no depender de una columna `id` que no existe.
3. Corrige mojibake frecuente (`presiÃ³n`, `rotaciÃ³n`, etc.) directamente dentro de la MV.
4. Deja índices para acelerar `ORDER BY created_at DESC`.

## Cómo aplicarlo

Ejecuta en PostgreSQL, sobre la MISMA base que usa FastAPI:

1. `backend_fastapi/db/atalaya_v311_alerts_feed_mv_rebuild.sql`
2. Reinicia FastAPI en `127.0.0.1:8010`
3. Verifica:

```powershell
python .\check_v31_alerts_mv_backend.py
powershell -ExecutionPolicy Bypass -File .\backend_fastapi\scripts\benchmark_alerts_v31.ps1
```

## Resultado esperado

- `row_count > 0`
- `alerts_preview` con filas reales
- `last_alerts_source = SUMMARY_MV`
- `XAlertsSource = SUMMARY_MV`
- menor latencia en `fresh=true`
- descripciones ya limpias, incluso si `XAlertsRepairs` se queda en `0`
