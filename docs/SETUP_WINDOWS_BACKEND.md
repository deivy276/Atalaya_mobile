# Setup backend FastAPI en Windows

## 1) Preparar `.env`

1. Copia el ejemplo:
   - `backend_fastapi/.env.example` → `backend_fastapi/.env`
2. Completa al menos estas variables:
   - `DB_HOST`
   - `DB_PORT`
   - `DB_NAME`
   - `DB_USER`
   - `DB_PASSWORD`
   - `DB_SSLMODE` (normalmente `require`)

> El backend prioriza `backend_fastapi/.env` para reducir errores por ruta relativa.

## 2) Levantar backend

Desde `backend_fastapi/`:

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

## 3) Verificar endpoints de salud

En otra terminal PowerShell:

```powershell
Invoke-RestMethod -Uri "http://localhost:8000/health"
Invoke-RestMethod -Uri "http://localhost:8000/health/db"
Invoke-RestMethod -Uri "http://localhost:8000/health/details"
```

Esperado:
- `/health` responde `status: ok`.
- `/health/db` responde `status: ok`.
- `/health/details` incluye `dbStatus`, `latestSampleAt`, `latestSampleAgeSeconds` y `staleThresholdSeconds`.

## 4) Troubleshooting rápido

### `WinError 10048` (puerto en uso)

```powershell
netstat -ano | findstr :8000
taskkill /PID <PID> /F
```

O cambia el puerto:

```powershell
uvicorn app.main:app --host 0.0.0.0 --port 8001 --reload
```

### Error DNS / `getaddrinfo failed`

- Revisa `DB_HOST` (host completo y resoluble).
- Valida conectividad DNS desde Windows:

```powershell
nslookup <tu_db_host>
```

### Backend responde `503`

- Verifica credenciales y host de DB en `backend_fastapi/.env`.
- Reinicia FastAPI después de corregir variables.
