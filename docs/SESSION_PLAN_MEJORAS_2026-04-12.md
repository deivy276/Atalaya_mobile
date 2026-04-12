# Atalaya Mobile — Bitácora de sesión y plan de mejoras

Fecha: 2026-04-12

## 1) Resumen de la sesión

Durante esta sesión se atendieron tres frentes:

1. **Error inicial 503 en dashboard (frontend web)**
   - Se confirmó que la app cargaba, pero mostraba error por respuesta `503` del backend.
   - Se ajustó el frontend para no caer en pantalla bloqueante y mostrar estado degradado con mensaje amigable.

2. **Carga de variables de entorno en backend FastAPI**
   - Se detectó fragilidad en la lectura de `.env` por ruta relativa.
   - Se corrigió configuración para priorizar `backend_fastapi/.env`.
   - Se agregó `backend_fastapi/.env.example` para guiar la configuración local.

3. **Estado `STALE` persistente**
   - Se validó que ya existe captura de datos del pozo.
   - El estado `STALE` se debe a antigüedad real de muestra vs umbral de staleness.
   - Se recomendó calibrar `STALE_THRESHOLD_SECONDS` según cadencia real de telemetría.

---

## 2) Hallazgos clave (causa raíz)

### 2.1 `503` del backend no era problema de Flutter

El backend respondía 503 por falla de conexión a DB (credenciales/host o resolución DNS), no por UI.

### 2.2 Error de resolución DNS para `DB_HOST`

Se observó un `getaddrinfo failed` por host incompleto o incorrecto.

### 2.3 `STALE` ahora es comportamiento esperado

Con muestras antiguas (ej. >24h), el cálculo de estado marca `STALE` por diseño.

---

## 3) Cambios técnicos aplicados

1. **Backend config**
   - Lectura de `.env` robusta en `backend_fastapi/app/config.py`.

2. **Plantilla de entorno**
   - Archivo nuevo `backend_fastapi/.env.example`.

3. **Control de ignore**
   - Ajuste de `.gitignore` para permitir `*.env.example`.

4. **Resiliencia de dashboard**
   - Manejo de errores en `DashboardController` para fallback sin bloquear UI.

---

## 4) Plan de mejoras (siguiente fase)

## Fase A — Estabilidad operativa (prioridad alta)

1. **Healthcheck operativo extendido**
   - Añadir endpoint `/health/details` con:
     - estado DB
     - última muestra global
     - `stale_threshold_seconds` efectivo
   - Objetivo: diagnóstico inmediato sin entrar a logs.

2. **Observabilidad mínima**
   - Incluir logs estructurados con:
     - tiempo de consulta dashboard
     - número de variables configuradas
     - edad de muestra más reciente
   - Objetivo: reducir tiempo de troubleshooting.

3. **Guía de configuración de entornos**
   - Crear `docs/SETUP_WINDOWS_BACKEND.md` con:
     - pasos de `.env`
     - verificación con `Invoke-RestMethod`
     - troubleshooting de puertos (`WinError 10048`) y DNS.

## Fase B — Calidad de datos (prioridad alta)

1. **Calibración de staleness por operación real**
   - Definir valor por ambiente para `STALE_THRESHOLD_SECONDS`.
   - Recomendación inicial:
     - laboratorio: 60–120s
     - operación intermitente: 600–3600s
     - modo histórico: 86400+.

2. **Indicador de “edad de datos” en backend**
   - Exponer `latest_sample_age_seconds` en payload para monitoreo externo.

3. **Validación de tags críticos**
   - Check automático al arranque para verificar presencia de tags esenciales.

## Fase C — UX del dashboard (prioridad media)

1. **Estados más explícitos**
   - Diferenciar:
     - `OFFLINE` (sin backend)
     - `DB_ERROR` (backend sin DB)
     - `STALE` (datos viejos pero válidos).

2. **Banner de acción recomendada**
   - Mostrar CTA contextual:
     - “Verificar DB_HOST/credenciales”
     - “Aumentar threshold de staleness”
     - “Reintentar”.

3. **Panel de diagnóstico rápido**
   - Drawer con:
     - base URL efectiva
     - hora última muestra
     - threshold actual
     - último error backend.

## Fase D — Automatización (prioridad media)

1. **Checks de pre-entrega**
   - Script único PowerShell para:
     - validar backend
     - validar DB
     - validar dashboard endpoint.

2. **Test de contrato básico**
   - Prueba automática para confirmar estructura de `/api/v1/dashboard`.

---

## 5) Criterios de éxito para cerrar mejoras

1. App carga dashboard sin pantalla bloqueante.
2. `/health/db` estable en `ok`.
3. Estado `STALE` alineado con operación real (no falsos positivos).
4. Diagnóstico de incidentes en <5 minutos con docs + health endpoint.

---

## 6) Próximas acciones inmediatas recomendadas

1. Confirmar valor objetivo de `STALE_THRESHOLD_SECONDS` con operación.
2. Implementar Fase A.1 (`/health/details`) y Fase B.2 (`latest_sample_age_seconds`).
3. Documentar setup en `docs/SETUP_WINDOWS_BACKEND.md`.

