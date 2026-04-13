$ErrorActionPreference = 'Stop'

$folders = @(
  'docs/test-plan',
  'checks/ui',
  'scripts/test',
  'test/widget',
  'test/integration'
)

foreach ($folder in $folders) {
  if (-not (Test-Path $folder)) {
    New-Item -ItemType Directory -Path $folder | Out-Null
    Write-Host "[mkdir] $folder"
  } else {
    Write-Host "[ok]    $folder"
  }
}

Write-Host "`nEstructura mínima de pruebas lista."
