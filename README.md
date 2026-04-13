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

## Arranque rápido para iterar UI (sin backend)

Para evitar fricción durante mejoras visuales, puedes correr la app en modo mock en Chrome:

```powershell
.\scripts\dev_run_chrome_mock.ps1
```

Este script ejecuta `flutter pub get` y levanta `flutter run -d chrome --dart-define=ATALAYA_USE_MOCK=true`.

## Pruebas locales (estructura y smoke)

Antes de ejecutar pruebas, actualiza/crea la estructura local de carpetas:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test\update_local_test_folders.ps1
```

```bash
./scripts/test/update_local_test_folders.sh
```

Luego puedes correr:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test\run_smoke_frontend.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\test\run_smoke_backend.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\test\run_stress_simulation.ps1
```
