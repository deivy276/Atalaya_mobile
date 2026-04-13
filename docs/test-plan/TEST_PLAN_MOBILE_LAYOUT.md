# Atalaya Mobile — Plan de Pruebas (Flutter + FastAPI)

Fecha: 2026-04-13

## 0) Actualización local de carpetas (obligatorio antes de probar)
Crear/confirmar estructura mínima:

- `docs/test-plan/`
- `checks/ui/`
- `scripts/test/`
- `test/widget/`
- `test/integration/`

### Opción PowerShell (Windows)
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test\update_local_test_folders.ps1
```

### Opción bash (Linux/macOS/Git Bash)
```bash
./scripts/test/update_local_test_folders.sh
```

## 1) Objetivo
Validar de forma incremental la estabilidad funcional y visual de Atalaya Mobile sobre la arquitectura real del repositorio:
- **Frontend:** Flutter (entrada principal en `DashboardScreen`).
- **Backend:** FastAPI (endpoints `/api/v1/dashboard`, `/trends`, `/alerts`, etc.).

## 2) Alcance por fases

### Fase 1 — UI mobile-first + personalización de layout
- Branding en AppBar (texto/logo en tema oscuro).
- Grilla responsiva (1/2/3 columnas según ancho).
- Sparklines por variable y apertura de detalle táctil.
- Bottom sheet para tendencia y alerta.
- Reordenamiento de variables (drag & drop) con persistencia por pozo/job.

### Fase 2 — Conectividad predictor + KP
- Polling inteligente con refresh manual y backoff.
- Estado visual `retrying/offline` ante caída del backend.
- Mapeo de severidad KP (attention/critical) en tarjetas.
- Barra inferior autoexpandible con recomendación.

### Fase 3 — Seguridad y roles
- Higiene de secretos (`.env`, `.gitignore`, no hardcode).
- Autenticación con expiración de sesión/token.
- RBAC (administrador, ingeniero, visualizador).
- Registro de auditoría de acciones sensibles.

### Fase 4 — Estrés y resiliencia
- Ingesta histórica acelerada (x5/x10).
- Ráfagas de alertas (20–50 eventos en intervalos cortos).
- Recuperación automática tras caída de backend (30–60 s).
- Estabilidad de CPU/memoria en sesión larga (1–2 h).

## 3) Entornos y dispositivos objetivo
- Resoluciones base: **360x640**, **390x844**, **412x915**.
- Android/iOS con foco en usabilidad a una mano.
- Flutter web (Chrome) para iteración de UI.

## 4) Criterios de aceptación globales
- ✅ Layout usable a una mano.
- ✅ Orden drag & drop persistente por usuario/pozo/job.
- ✅ Reflejo de alertas KP sin retraso perceptible.
- ✅ Reconexión automática sin congelamiento de UI.
- ✅ Seguridad base: secretos fuera del código + auth + roles.

## 5) Evidencias requeridas por corrida
- Capturas de estado inicial/final por caso manual.
- Logs de frontend/backend por ejecución.
- Registro de versión de app, commit y fecha/hora UTC.
- Resultado por caso: `PASS | FAIL | BLOCKED` + observaciones.
