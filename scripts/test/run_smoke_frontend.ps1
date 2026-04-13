$ErrorActionPreference = 'Stop'

Write-Host "[smoke-frontend] flutter pub get"
flutter pub get

Write-Host "[smoke-frontend] flutter analyze"
flutter analyze

Write-Host "[smoke-frontend] flutter test"
flutter test
