#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
command -v flutter >/dev/null || { echo 'Flutter not found in PATH'; exit 1; }
[ -f android/key.properties ] || { echo 'android/key.properties missing'; exit 1; }
[ -f android/keystore/alin-upload-keystore.jks ] || { echo 'upload keystore missing'; exit 1; }
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release --target-platform android-arm,android-arm64,android-x64
flutter build apk --release --split-per-abi
echo "AAB: $ROOT/build/app/outputs/bundle/release/app-release.aab"
