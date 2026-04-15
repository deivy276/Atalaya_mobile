# Fase B — Guía rápida de tuning Render ↔ PostgreSQL

## Objetivo

Evitar cortes intermitentes y saturación de conexiones cuando se escala backend + pool.

## Variables clave

- `APP_WORKERS`
- `POOL_SIZE`
- `MAX_OVERFLOW`
- `DB_CONNECTION_BUDGET`
- `DB_CONNECT_TIMEOUT_SECONDS`
- `STATEMENT_TIMEOUT_MS`
- `IDLE_IN_TRANSACTION_SESSION_TIMEOUT_MS`
- `DB_RETRY_ATTEMPTS`
- `DB_RETRY_BACKOFF_MS`

## Regla de presupuesto

Pico estimado de conexiones por servicio:

`estimated_peak = APP_WORKERS * (POOL_SIZE + MAX_OVERFLOW)`

Configura `DB_CONNECTION_BUDGET` con el máximo que quieres permitir para el servicio.
En startup, el backend imprime advertencia si el pico estimado supera ese presupuesto.

## Recomendación inicial por plan pequeño/medio

> Ajusta según límite real de conexiones del plan en Render Postgres.

- `APP_WORKERS=1`
- `POOL_SIZE=3`
- `MAX_OVERFLOW=2`
- `DB_CONNECTION_BUDGET=5`

Para más carga:

- sube primero `POOL_SIZE` de forma gradual (3 -> 4 -> 5),
- mide latencia p95 y errores,
- solo después evalúa subir `APP_WORKERS`.

## Estrategia de rollout

1. Activa nuevos valores en staging.
2. Corre smoke + carga controlada.
3. Verifica:
   - `OperationalError` por minuto,
   - latencia p95/p99,
   - saturación de conexiones.
4. Promueve a producción con ventana controlada.

