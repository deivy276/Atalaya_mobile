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

Invoke-Step "[smoke-frontend] flutter pub get" "flutter pub get"
Invoke-Step "[smoke-frontend] flutter analyze (lib + stable tests)" "flutter analyze lib test/unit_converter_test.dart test/widget_test.dart"
Invoke-Step "[smoke-frontend] flutter test (stable tests)" "flutter test test/unit_converter_test.dart test/widget_test.dart"

Write-Host "[note] Para ejecutar el suite completo (incluye placeholders), usa: flutter analyze && flutter test"
