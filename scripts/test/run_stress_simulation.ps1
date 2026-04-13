$ErrorActionPreference = 'Stop'

function Test-BackendHttp {
  param([string]$Url)
  try {
    $null = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
    return $true
  } catch {
    return $false
  }
}

$healthUrl = "http://127.0.0.1:8010/health"
if (-not (Test-BackendHttp -Url $healthUrl)) {
  throw "Backend HTTP no disponible en 127.0.0.1:8010. Inicia FastAPI antes de correr stress (ej: uvicorn app.main:app --host 127.0.0.1 --port 8010)."
}

Write-Host "[stress] benchmark dashboard v3"
powershell -ExecutionPolicy Bypass -File ./scripts/benchmark_dashboard_v3.ps1

Write-Host "[stress] benchmark alerts v31"
powershell -ExecutionPolicy Bypass -File ./scripts/benchmark_alerts_v31.ps1
