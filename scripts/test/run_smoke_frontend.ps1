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
Invoke-Step "[smoke-frontend] flutter analyze" "flutter analyze"
Invoke-Step "[smoke-frontend] flutter test" "flutter test"
