param(
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "ProjectRoot: $ProjectRoot" -ForegroundColor Cyan
Set-Location $ProjectRoot

Write-Host "-> flutter pub get" -ForegroundColor Yellow
flutter pub get

Write-Host "-> launching Chrome in MOCK mode" -ForegroundColor Yellow
flutter run -d chrome --dart-define=ATALAYA_USE_MOCK=true
