$ErrorActionPreference = 'Stop'

Write-Host "[smoke-backend] python --version"
python --version

Write-Host "[smoke-backend] checks/check_v3_matview_backend.py"
python checks/check_v3_matview_backend.py

Write-Host "[smoke-backend] checks/check_v31_alerts_mv_backend.py"
python checks/check_v31_alerts_mv_backend.py

Write-Host "[smoke-backend] checks/check_v32_alerts_api_case_insensitive.py"
python checks/check_v32_alerts_api_case_insensitive.py
