$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Fail([string]$message) { Write-Host "ERROR: $message" -ForegroundColor Red; exit 1 }

$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) { Fail 'Flutter غير مثبت أو غير مضاف إلى PATH.' }
$flutterBin = $flutterCmd.Source
$flutterSdk = Split-Path (Split-Path $flutterBin -Parent) -Parent

$sdk = $env:ANDROID_SDK_ROOT
if (-not $sdk) { $sdk = $env:ANDROID_HOME }
if (-not $sdk) {
  $candidate = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
  if (Test-Path $candidate) { $sdk = $candidate }
}
if (-not $sdk -or -not (Test-Path $sdk)) { Fail 'Android SDK غير موجود. افتح Android Studio وثبت Android SDK 36.' }

if (-not (Test-Path 'android\key.properties')) { Fail 'ملف android\key.properties غير موجود. انسخه من حزمة مفتاح التوقيع السرية.' }
if (-not (Test-Path 'android\keystore\alin-upload-keystore.jks')) { Fail 'مفتاح android\keystore\alin-upload-keystore.jks غير موجود.' }

$flutterSdkProp = $flutterSdk.Replace('\','/')
$sdkProp = $sdk.Replace('\','/')
@"
flutter.sdk=$flutterSdkProp
sdk.dir=$sdkProp
"@ | Set-Content -Path 'android\local.properties' -Encoding ASCII

Write-Host '1/5 Flutter version' -ForegroundColor Cyan
flutter --version
Write-Host '2/5 Dependencies' -ForegroundColor Cyan
flutter pub get
Write-Host '3/5 Analyze' -ForegroundColor Cyan
flutter analyze
Write-Host '4/5 Tests' -ForegroundColor Cyan
flutter test
Write-Host '5/5 Play release AAB + APK' -ForegroundColor Cyan
flutter build appbundle --release --target-platform android-arm,android-arm64,android-x64
flutter build apk --release --split-per-abi

Write-Host ''
Write-Host 'READY FOR GOOGLE PLAY:' -ForegroundColor Green
Write-Host (Join-Path $root 'build\app\outputs\bundle\release\app-release.aab') -ForegroundColor Green
Write-Host 'APK files:' -ForegroundColor Green
Write-Host (Join-Path $root 'build\app\outputs\flutter-apk\') -ForegroundColor Green
