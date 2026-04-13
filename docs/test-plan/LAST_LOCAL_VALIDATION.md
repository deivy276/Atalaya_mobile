# Atalaya Mobile — Acta de Validación Local

Fecha: 2026-04-13  
Entorno: Windows PowerShell (usuario local)  
Repositorio: `Atalaya_mobile`

## 1) Comandos ejecutados

```powershell
git pull
powershell -ExecutionPolicy Bypass -File .\scripts\test\run_smoke_frontend.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\test\run_smoke_backend.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\test\run_stress_simulation.ps1
```

## 2) Resultado ejecutivo

- ✅ **Smoke Frontend:** PASS
  - `flutter analyze (lib + stable tests)` sin issues.
  - `flutter test (stable tests)` con `All tests passed`.
- ✅ **Smoke Backend:** PASS
  - checks `v3`, `v31`, `v32` ejecutados sin excepciones fatales.
- ✅ **Stress/Benchmark:** PASS
  - Dashboard: patrón esperado MISS/HIT y tiempos consistentes.
  - Alerts: patrón esperado MISS/HIT y tiempos consistentes.

## 3) Métricas observadas (resumen)

### Dashboard benchmark
- Cold dashboard: ~1469 ms (MISS)
- Immediate dashboard: ~42 ms (HIT)
- Fresh dashboard core: ~1612 ms (MISS)
- Fresh alerts (separado): ~697 ms (MISS)
- Legacy full dashboard: ~1113 ms (MISS)

### Alerts benchmark
- Fresh alerts: ~802 ms (MISS)
- Cached alerts: ~47 ms (HIT)
- Immediate cached alerts: ~68 ms (HIT)

## 4) Evidencia funcional

- Frontend smoke ejecutado con el script estable de repo (`run_smoke_frontend.ps1`).
- Backend smoke validando materialized views y endpoint de alertas case-insensitive (`run_smoke_backend.ps1`).
- Stress ejecutado con benchmarks existentes (`run_stress_simulation.ps1`).

## 5) Pendientes recomendados

- Ejecutar suite completa (`flutter analyze && flutter test`) cuando se habiliten tests placeholder.
- Repetir esta acta tras cambios de lógica en Dashboard, KP o Alerts.
- Adjuntar capturas de UI manual para checklist móvil en cada ciclo de release.
