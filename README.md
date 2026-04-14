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

## Seguridad móvil (Fase 4)

- Evitar almacenamiento en texto plano de tokens/sesiones.
- Usar almacenamiento seguro por plataforma (Keychain/Keystore) mediante `flutter_secure_storage`.
- Implementación base: `lib/core/security/session_secure_storage.dart`.

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

> `run_smoke_frontend.ps1` ejecuta un smoke estable (`lib` + `test/unit_converter_test.dart` + `test/layout_order_controller_test.dart` + `test/widget_test.dart`).
> Para suite completa: `flutter analyze && flutter test`.

Última acta de corrida local: `docs/test-plan/LAST_LOCAL_VALIDATION.md`.
> `run_smoke_backend.ps1` valida checks DB y, si HTTP backend está activo en `127.0.0.1:8010`, también ejecuta el check API v32.
> `run_stress_simulation.ps1` requiere backend HTTP activo en `127.0.0.1:8010`.



### Solución de problemas frecuentes (Windows)

Si `git pull` falla con:

`The following untracked working tree files would be overwritten by merge: test/widget_test.dart`

ejecuta (sin depender de scripts nuevos):

```powershell
Remove-Item .\test\widget_test.dart -Force -ErrorAction SilentlyContinue
git pull
```

Opcional (si ya existe en tu rama):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test\fix_git_pull_untracked.ps1
git pull
```

Si quieres limpiar *todos* los no trackeados (con cuidado):

```powershell
git clean -fd
```

> ⚠️ `git clean -fd` borra archivos no versionados.

Si `run_smoke_backend.ps1` reporta `ModuleNotFoundError: No module named 'app'`, actualiza a la versión más reciente del script con `git pull` y vuelve a ejecutar desde la **raíz del repo**.
