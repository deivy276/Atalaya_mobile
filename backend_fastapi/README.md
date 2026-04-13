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

## Seguridad (sesiones + roles)

Se agregó una capa de autenticación basada en cookie de sesión para proteger endpoints cuando se activa `AUTH_ENABLED=true`.

- Login: `POST /auth/login` con `{"username":"...","password":"..."}`.
- Logout: `POST /auth/logout`.
- Perfil activo: `GET /auth/me`.
- Gestión de usuarios (solo admin):
  - `GET /auth/users`
  - `POST /auth/users`
  - `PATCH /auth/users/{username}/role`
  - `PATCH /auth/users/{username}/activation`
- Timeout de sesión: `AUTH_SESSION_TIMEOUT_HOURS` (recomendado 8-12 horas en operación).
- Hash de contraseñas: se usa `werkzeug.security.generate_password_hash` y `check_password_hash` (nunca texto plano).
- Política de contraseña mínima (configurable): longitud (`AUTH_PASSWORD_MIN_LENGTH`, default 12), complejidad (mayúscula/minúscula/número/símbolo) y lista prohibida (`AUTH_BANNED_PASSWORDS`).
- Bloqueo temporal por intentos fallidos: configurable con `AUTH_LOGIN_MAX_ATTEMPTS` y `AUTH_LOGIN_LOCKOUT_MINUTES`.
- RBAC:
  - `admin`: acceso total (incluye endpoints de debug).
  - `operator`: consumo de telemetría/KPs sin privilegios de administración.
- Auditoría mínima en SQLite (`auth_audit_log`): login exitoso/fallido, logout, alta/baja de usuario y cambio de rol.

Bootstrap local de usuario admin:

1. En `.env`, define `BOOTSTRAP_ADMIN_USERNAME` y `BOOTSTRAP_ADMIN_PASSWORD`.
2. Reinicia FastAPI; en startup se crea/actualiza el usuario admin en SQLite (`AUTH_SQLITE_PATH`).

> Importante (prod):
> - Configura secreto por ambiente (`APP_ENV` + `AUTH_SECRET_KEY_DEV|STAGE|PROD`).
> - Forzar cookie segura con `AUTH_COOKIE_SECURE=true`.
> - Definir `AUTH_COOKIE_SAMESITE=lax` o `strict`.
> - Nunca commitear `.env` real; usar gestor de secretos/vault.

## Base de datos esperada

El backend asume las tablas del sistema original:

- `public.kp_state`
- `public.atalaya_samples`
- `public.atalaya_alerts`
- una de las tablas candidatas de adjuntos configuradas en `ATTACHMENT_TABLE_CANDIDATES`
