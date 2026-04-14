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

## Scripts SQL

- Índices base: `sql/atalaya_v3_indexes.sql`
- Refresh MV: `sql/refresh_atalaya_latest_samples_mv.sql`
- Schedule (pg_cron): `sql/schedule_refresh_atalaya_latest_samples_mv.sql`
- Alternativa latest-by-tag por trigger: `sql/atalaya_latest_by_tag_table.sql`

