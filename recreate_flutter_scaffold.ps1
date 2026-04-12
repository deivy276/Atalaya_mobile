param(
  [string]$ProjectRoot = "."
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Resolve-Path $ProjectRoot
Set-Location $root

if (-not (Test-Path "pubspec.yaml")) {
  throw "No se encontro pubspec.yaml en $root"
}

flutter create . --platforms=android,ios,linux,macos,web,windows
flutter pub get
Write-Host "Scaffold de plataformas recreado correctamente en $root" -ForegroundColor Green
