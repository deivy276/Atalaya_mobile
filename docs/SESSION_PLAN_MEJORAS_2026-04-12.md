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

---

## 7) Nuevos requerimientos solicitados (distribución multiusuario)

Los siguientes puntos quedan incorporados al plan de mejora y priorización:

### RQ-01 — Control de acceso con usuarios y contraseñas (Alta)

Objetivo: habilitar distribución segura de Atalaya Mobile a múltiples usuarios.

Alcance propuesto:
- Autenticación con usuario/contraseña (login backend).
- Sesión con JWT (access + refresh token).
- Control de roles base (Admin, Operaciones, Consulta).
- Política de contraseñas y bloqueo por intentos fallidos.
- Registro de auditoría (inicio de sesión, cierre, cambios de contraseña).

Entregables:
1. Endpoints de auth en FastAPI (`/auth/login`, `/auth/refresh`, `/auth/logout`, `/auth/me`).
2. Tabla de usuarios/roles/permisos.
3. Pantalla de login en Flutter y guardado seguro de tokens.
4. Protección de endpoints existentes de dashboard/trends/alerts.

### RQ-02 — Integración completa con Atalaya Predictor (Alta)

Objetivo: además de trends, mostrar alertas, comentarios y adjuntos originados en Predictor.

Alcance propuesto:
- Feed de alertas con severidad, estado y timestamp.
- Comentarios asociados por alerta (timeline conversacional).
- Descarga/visualización de adjuntos subidos por usuarios de Predictor.
- Sincronización incremental (polling optimizado y/o websocket en fase 2).
- Nueva sección de “Gráficas especiales” configurable por pozo/job.

Entregables:
1. Contrato API unificado para alertas/comentarios/adjuntos.
2. Nuevos modelos Flutter y providers de estado.
3. UI de alertas enriquecida + pantalla de gráficas especiales.
4. Manejo de errores de adjuntos (host permitido, expiración URL, fallback).

### RQ-03 — Mejora de visualización y reordenamiento manual de variables (Media-Alta)

Objetivo: mejorar ergonomía visual y permitir personalización del tablero por usuario.

Alcance propuesto:
- Rediseño visual de tarjetas de variables (jerarquía, contraste, estados).
- Modo edición para mover tarjetas con drag & drop.
- Persistencia del layout por usuario/dispositivo.
- Acción “restablecer layout por defecto”.

Entregables:
1. Grid reordenable con guardado local/remoto.
2. Modelo de preferencias de layout por usuario.
3. Guía visual de estados (normal/warn/critical/stale/offline).

### RQ-04 — Corrección de cambio de unidades (Alta)

Objetivo: asegurar conversiones consistentes, trazables y estables por variable.

Alcance propuesto:
- Revisar factor de conversión y redondeo por tipo de variable.
- Unificar origen de verdad de unidades (backend + catálogo en app).
- Persistir preferencia por usuario y por variable/tag.
- Corregir actualización de valor convertido en tiempo real y en trends.
- Cobertura de pruebas unitarias de conversiones clave.

Entregables:
1. Matriz de conversiones validada con negocio.
2. Refactor de `unit_converter` y controladores de preferencia.
3. Test unitarios para conversiones y regresiones.
4. Checklist QA funcional (dashboard + trend + alert detail).

### Orden recomendado de implementación

1. **RQ-01 (Auth)** y **RQ-04 (Unidades)** en paralelo (fundación de seguridad + exactitud).
2. **RQ-02 (Predictor completo)** sobre APIs autenticadas.
3. **RQ-03 (UX + reordenamiento manual)** como cierre de experiencia de usuario.

### Criterios de aceptación globales de esta fase

- Solo usuarios autenticados acceden a datos operativos.
- Alertas/comentarios/adjuntos visibles y consistentes con Predictor.
- Usuario puede personalizar el orden de variables y conservarlo.
- Conversiones de unidades coinciden con referencia operativa y no presentan saltos inconsistentes.
