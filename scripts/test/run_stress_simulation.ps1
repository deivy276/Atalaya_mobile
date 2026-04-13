$ErrorActionPreference = 'Stop'

Write-Host "[stress] benchmark dashboard v3"
powershell -ExecutionPolicy Bypass -File ./scripts/benchmark_dashboard_v3.ps1

Write-Host "[stress] benchmark alerts v31"
powershell -ExecutionPolicy Bypass -File ./scripts/benchmark_alerts_v31.ps1
