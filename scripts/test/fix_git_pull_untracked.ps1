$ErrorActionPreference = 'Stop'

$conflicts = @(
  '.\\test\\widget_test.dart'
)

foreach ($path in $conflicts) {
  if (Test-Path $path) {
    Remove-Item $path -Force
    Write-Host "[removed] $path"
  } else {
    Write-Host "[ok] not present: $path"
  }
}

Write-Host "Ahora puedes ejecutar: git pull"
