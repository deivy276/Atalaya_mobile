$ErrorActionPreference = 'Stop'

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][string]$Command
  )

  Write-Host $Label
  Invoke-Expression $Command
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed with exit code ${LASTEXITCODE}: $Command"
  }
}

function Test-BackendHttp {
  param([string]$Url)
  try {
    $null = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
    return $true
  } catch {
    return $false
  }
}

$env:PYTHONPATH = "backend_fastapi"

Invoke-Step "[smoke-backend] python --version" "python --version"
Invoke-Step "[smoke-backend] checks/check_v3_matview_backend.py" "python checks/check_v3_matview_backend.py"
Invoke-Step "[smoke-backend] checks/check_v31_alerts_mv_backend.py" "python checks/check_v31_alerts_mv_backend.py"

$alertsApiUrl = "http://127.0.0.1:8010/api/v1/alerts?fresh=true&limit=1"
if (Test-BackendHttp -Url $alertsApiUrl) {
  Invoke-Step "[smoke-backend] checks/check_v32_alerts_api_case_insensitive.py" "python checks/check_v32_alerts_api_case_insensitive.py"
} else {
  Write-Warning "[smoke-backend] Backend HTTP no disponible en 127.0.0.1:8010; se omite check_v32_alerts_api_case_insensitive.py"
}
