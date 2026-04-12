$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
Write-Host "Installing backend requirements..." -ForegroundColor Cyan
python -m pip install -r requirements.txt
if (-not (Test-Path .env)) {
    Copy-Item .env.example .env
    Write-Host "Created .env from .env.example. Edit DB_PASSWORD before continuing if needed." -ForegroundColor Yellow
}
Write-Host "Starting FastAPI on http://127.0.0.1:8010" -ForegroundColor Green
python -m uvicorn app.main:app --host 127.0.0.1 --port 8010
