#!/usr/bin/env bash
set -euo pipefail

folders=(
  "docs/test-plan"
  "checks/ui"
  "scripts/test"
  "test/widget"
  "test/integration"
)

for folder in "${folders[@]}"; do
  if [[ ! -d "$folder" ]]; then
    mkdir -p "$folder"
    echo "[mkdir] $folder"
  else
    echo "[ok]    $folder"
  fi
done

echo
echo "Estructura mínima de pruebas lista."
