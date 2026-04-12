#!/usr/bin/env bash
set -euo pipefail
cd "${1:-.}"
[ -f pubspec.yaml ] || { echo "No se encontro pubspec.yaml"; exit 1; }
flutter create . --platforms=android,ios,linux,macos,web,windows
flutter pub get
echo "Scaffold recreado correctamente"
