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

## Base de datos esperada

El backend asume las tablas del sistema original:

- `public.kp_state`
- `public.atalaya_samples`
- `public.atalaya_alerts`
- una de las tablas candidatas de adjuntos configuradas en `ATTACHMENT_TABLE_CANDIDATES`
