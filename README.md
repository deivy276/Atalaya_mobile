# Scripts para recrear plataformas Flutter

Uso en Windows PowerShell:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
.\recreate_flutter_scaffold.ps1 -ProjectRoot "C:\Ruta\Atalaya_Flutter_Core_Source"
```

Uso en bash:

```bash
chmod +x recreate_flutter_scaffold.sh
./recreate_flutter_scaffold.sh /ruta/Atalaya_Flutter_Core_Source
```

## Ejecutar localmente antes de generar el APK

### 1) Requisitos previos

- Flutter SDK instalado (`flutter --version`).
- Android Studio + Android SDK + al menos un emulador Android configurado.
- JDK 17 disponible (recomendado para proyectos Flutter/Android actuales).
- Python 3.10+ para el backend FastAPI.

### 2) Levantar backend local (FastAPI)

Desde la raíz del repo:

**Bash (Linux/macOS/Git Bash):**

```bash
cd backend_fastapi
python -m venv .venv
source .venv/bin/activate
cp .env.example .env
pip install -r requirements.txt
python -m uvicorn app.main:app --host 127.0.0.1 --port 8010
```

**Windows PowerShell:**

```powershell
cd backend_fastapi
python -m venv .venv
.\.venv\Scripts\Activate.ps1
Copy-Item .env.example .env
pip install -r requirements.txt
python -m uvicorn app.main:app --host 127.0.0.1 --port 8010
```

El backend debe quedar escuchando en `http://127.0.0.1:8010`.

> Nota: en PowerShell no existe `source`; usa `\.venv\Scripts\Activate.ps1`.

### 3) Verificar/ajustar URL base en Flutter

Asegúrate de que el cliente HTTP del app apunte al backend local. Si ejecutas en:

- Emulador Android: normalmente usa `http://10.0.2.2:8010`
- iOS Simulator/Web/Desktop: `http://127.0.0.1:8010`
- Dispositivo físico Android: usa la IP LAN de tu PC, p. ej. `http://192.168.1.100:8010`

### 4) Ejecutar la app Flutter en local

Desde la raíz del repo:

```bash
flutter pub get
flutter run
```

Si tienes varios dispositivos:

```bash
flutter devices
flutter run -d <device_id>
```

### 5) Validación rápida antes del APK

```bash
flutter analyze
flutter test
```

### 6) Generar APK (cuando ya pase en local)

```bash
flutter build apk --release
```

APK de salida:

`build/app/outputs/flutter-apk/app-release.apk`
