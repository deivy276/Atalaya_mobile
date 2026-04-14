# Fase C — Optimización de consultas KPI

## Objetivo

Que `/api/v1/dashboard` lea casi siempre de estructuras optimizadas:

1. `public.atalaya_latest_samples_mv` (o una tabla equivalente latest-by-tag).
2. Ruta exacta por tag.
3. Fallback costoso solo como excepción.

## Cambios operativos recomendados

- Crear índice funcional para normalización de tag:
  - `LOWER(TRIM(TRAILING '.' FROM tag))`.
- Programar refresh de MV concurrente cada 2–5s según carga.
- Si el volumen crece, migrar a tabla incremental `public.atalaya_latest_by_tag`.

## Configuración backend

- `LATEST_SAMPLES_FALLBACK_MAX_MISSING_TAGS` (default 2)
- `LATEST_SAMPLES_FALLBACK_MAX_MISSING_RATIO` (default 0.35)

Si faltan demasiados tags, el backend evita el fallback pesado y responde parcial
con source `MATVIEW_PARTIAL` o `BASE_TABLE_EXACT_PARTIAL`.

Headers de observabilidad en `/api/v1/dashboard` y `/api/v1/dashboard/full`:

- `X-Samples-Missing-Tags`
- `X-Samples-Missing-Ratio`
- `X-Samples-Resolution-Ms`
- `X-Samples-Fallback-Used`

## Scripts SQL

- Índices base: `sql/atalaya_v3_indexes.sql`
- Refresh MV: `sql/refresh_atalaya_latest_samples_mv.sql`
- Schedule (pg_cron): `sql/schedule_refresh_atalaya_latest_samples_mv.sql`
- Alternativa latest-by-tag por trigger: `sql/atalaya_latest_by_tag_table.sql`



## Verificación de rendimiento (Fase C)

- Script comparativo de rutas KPI: `checks/check_v4_kpi_query_paths_benchmark.py`
  - Ejecuta `EXPLAIN (ANALYZE, BUFFERS)` para:
    1. `SUMMARY_MV` (lookup por `tag_norm` en `atalaya_latest_samples_mv`)
    2. `BASE_TABLE_EXACT` (tags exactos `plain/dotted`)
    3. `BASE_TABLE_NORM` (`DISTINCT ON` con normalización)
- Ejemplo:
  - `python checks/check_v4_kpi_query_paths_benchmark.py --tags spp,rpm,wob`
- Nota: los scripts de `checks/` ahora fallan de forma controlada con mensaje claro si faltan `DB_*` en el entorno (exit code 2).
- Cobertura automatizada: `backend_fastapi/tests/test_phase_c_checks_scripts.py` valida este comportamiento de falla controlada.
- Cobertura de headers KPI: `backend_fastapi/tests/test_dashboard_observability_headers.py` valida `X-Samples-*` en `/dashboard` y `/dashboard/full`.

## Avance Fase C

- Avance técnico estimado: **99%**.
- Pendiente para cierre al 100%:
  1. Ejecutar benchmark en entorno con datos reales.
  2. Registrar latencias p50/p95 por ruta.
  3. Confirmar reducción sostenida del uso de fallback pesado.
