$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host 'Flutter غير مثبت أو غير مضاف إلى PATH.' -ForegroundColor Red
  exit 1
}
flutter --version
flutter pub get
flutter analyze
flutter test
Write-Host 'مشروع آلين Flutter الإنتاجي جاهز. للبناء شغّل tool\build_play_release.ps1' -ForegroundColor Green
