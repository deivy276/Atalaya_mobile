# Atalaya FastAPI backend

Backend REST mínimo para Atalaya, pensado para reemplazar la conexión directa a PostgreSQL desde la app móvil.

## Arranque recomendado en Windows

Evita `--reload` y evita el puerto `8000` si en tu equipo Windows da `WinError 10013`.

```powershell
cd backend_fastapi
python -m pip install -r requirements.txt
Copy-Item .env.example .env
# Edita .env y coloca la contraseña real de Render/PostgreSQL en DB_PASSWORD
python -m uvicorn app.main:app --host 127.0.0.1 --port 8010
```

Pruebas rápidas:

```powershell
curl http://127.0.0.1:8010/health
curl http://127.0.0.1:8010/health/db
```

Resultados esperados:

- `/health` => `{"status":"ok"}`
- `/health/db` => `{"status":"ok"}`

Si `/health` responde pero `/health/db` falla, el problema ya no es FastAPI sino la conexión a PostgreSQL o la contraseña.

## Seguridad (sesiones + roles + RBAC)

Se agregó una capa de autenticación basada en cookie de sesión para proteger endpoints cuando se activa `AUTH_ENABLED=true`.

- Login: `POST /auth/login` con `{"username":"...","password":"..."}`.
- Logout: `POST /auth/logout`.
- Perfil activo: `GET /auth/me`.
- Gestión de usuarios (solo admin):
  - `GET /auth/users`
  - `POST /auth/users`
  - `PATCH /auth/users/{username}/role`
  - `PATCH /auth/users/{username}/activation`
- Catálogo RBAC (solo admin):
  - `GET /auth/roles`
  - `GET /auth/permissions`
- Scope por pozo:
  - `GET /auth/users/{username}/well-access` (admin/specialist)
  - `PUT /auth/users/{username}/well-access` (solo admin)
- Ciclo de credenciales (Fase 3):
  - `POST /auth/change-password` (cambio de contraseña autenticado)
  - `POST /auth/users/{username}/reset-password-token` (admin)
  - `POST /auth/reset-password/confirm` (token temporal)
- Sesiones y revocación:
  - `GET /auth/sessions`
  - `POST /auth/sessions/{session_id}/revoke`
- MFA opcional (admin/specialist):
  - `POST /auth/mfa/setup`
  - `POST /auth/mfa/enable`
  - `POST /auth/mfa/disable/{username}` (solo admin)
- Timeout de sesión: `AUTH_SESSION_TIMEOUT_HOURS` (recomendado 8-12 horas en operación).
- Hash de contraseñas: se usa `werkzeug.security.generate_password_hash` y `check_password_hash` (nunca texto plano).
- Política de contraseña mínima (configurable): longitud (`AUTH_PASSWORD_MIN_LENGTH`, default 12), complejidad (mayúscula/minúscula/número/símbolo) y lista prohibida (`AUTH_BANNED_PASSWORDS`).
- Bloqueo temporal por intentos fallidos: configurable con `AUTH_LOGIN_MAX_ATTEMPTS` y `AUTH_LOGIN_LOCKOUT_MINUTES`.
- RBAC:
  - `admin`: gestión de usuarios, roles y configuración global.
  - `specialist`: ajustes de predictor/control panel.
  - `operator`: visualiza telemetría/KPs y ejecuta acciones operativas permitidas.
  - `viewer`: solo lectura.
- Auditoría mínima en PostgreSQL (`auth_audit_log`): login exitoso/fallido, logout, alta/baja de usuario y cambio de rol.
- La autenticación ya no depende de SQLite local: usa tablas en PostgreSQL (`users`, `roles`, `permissions`, `role_permissions`, `user_well_access`).
- Se guarda session store en DB (`auth_sessions`) para revocación remota por riesgo (robo/pérdida).
- Reset de contraseña usa token temporal (`password_reset_tokens`) con expiración corta y revoca sesiones activas al confirmar.
- API hardening fase 4:
  - Rate limit en login y endpoints sensibles.
  - Límite de payload por `Content-Length`.
  - Headers de seguridad (`HSTS`, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`).
  - En `prod`: rechazo de HTTP sin TLS cuando `ENFORCE_HTTPS_IN_PROD=true`.

Bootstrap local de usuario admin:

1. En `.env`, define `BOOTSTRAP_ADMIN_USERNAME` y `BOOTSTRAP_ADMIN_PASSWORD`.
2. Reinicia FastAPI; en startup se crea/actualiza el usuario admin en PostgreSQL (tabla `users`).

> Importante (prod):
> - Configura secreto por ambiente (`APP_ENV` + `AUTH_SECRET_KEY_DEV|STAGE|PROD`).
> - Forzar cookie segura con `AUTH_COOKIE_SECURE=true`.
> - Definir `AUTH_COOKIE_SAMESITE=lax` o `strict`.
> - Cerrar CORS por ambiente (`CORS_ORIGINS` sin `*` en prod).
> - Nunca commitear `.env` real; usar gestor de secretos/vault.
> - Para pruebas locales sin bootstrap DB: `AUTH_SKIP_DB_INIT=true`.

## Base de datos esperada

El backend asume las tablas del sistema original:

- `public.kp_state`
- `public.atalaya_samples`
- `public.atalaya_alerts`
- una de las tablas candidatas de adjuntos configuradas en `ATTACHMENT_TABLE_CANDIDATES`
