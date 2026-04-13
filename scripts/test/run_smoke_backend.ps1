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

$env:PYTHONPATH = "backend_fastapi"

Invoke-Step "[smoke-backend] python --version" "python --version"
Invoke-Step "[smoke-backend] checks/check_v3_matview_backend.py" "python checks/check_v3_matview_backend.py"
Invoke-Step "[smoke-backend] checks/check_v31_alerts_mv_backend.py" "python checks/check_v31_alerts_mv_backend.py"
Invoke-Step "[smoke-backend] checks/check_v32_alerts_api_case_insensitive.py" "python checks/check_v32_alerts_api_case_insensitive.py"
