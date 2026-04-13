# Atalaya Mobile — Acta de Validación Local

Fecha: 2026-04-13  
Entorno: Windows PowerShell (usuario local)  
Repositorio: `Atalaya_mobile`

## 1) Comandos ejecutados

```powershell
git pull
powershell -ExecutionPolicy Bypass -File .\scripts\test\update_local_test_folders.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\test\run_smoke_frontend.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\test\run_smoke_backend.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\test\run_stress_simulation.ps1
```

## 2) Resultado ejecutivo (última corrida reportada)

- ✅ **Smoke Frontend:** PASS
  - `flutter analyze (lib + stable tests)` sin issues.
  - `flutter test (stable tests)` con `All tests passed`.
- ✅ **Smoke Backend:** PASS
  - checks `v3`, `v31`, `v32` ejecutados sin excepciones fatales.
- ✅ **Stress/Benchmark:** PASS
  - Dashboard y Alerts con patrón esperado MISS/HIT y tiempos consistentes.

## 3) Métricas observadas (resumen)

### Dashboard benchmark
- Cold dashboard: ~1775 ms (MISS)
- Immediate dashboard: ~30 ms (HIT)
- Fresh dashboard core: ~896 ms (MISS)
- Fresh alerts (separado): ~730 ms (MISS)
- Legacy full dashboard: ~1193 ms (MISS)

### Alerts benchmark
- Fresh alerts: ~866 ms (MISS)
- Cached alerts: ~49 ms (HIT)
- Immediate cached alerts: ~72 ms (HIT)

## 4) Evidencia funcional

- Frontend smoke ejecutado con script estable (`run_smoke_frontend.ps1`).
- Backend smoke validando materialized views y endpoint de alertas case-insensitive (`run_smoke_backend.ps1`).
- Stress ejecutado con benchmarks existentes (`run_stress_simulation.ps1`) tras validar backend HTTP activo.

## 5) Pendientes recomendados

- Ejecutar suite completa (`flutter analyze && flutter test`) cuando se habiliten tests placeholder.
- Repetir esta acta tras cambios de lógica en Dashboard, KP o Alerts.
- Adjuntar capturas de UI manual para checklist móvil en cada ciclo de release.
