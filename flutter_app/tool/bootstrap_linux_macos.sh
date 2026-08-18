#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
command -v flutter >/dev/null || { echo 'Flutter not found in PATH'; exit 1; }
flutter --version
flutter pub get
flutter analyze
flutter test
echo 'Alin Flutter production source is ready. Run tool/build_play_release.sh for Android release.'
