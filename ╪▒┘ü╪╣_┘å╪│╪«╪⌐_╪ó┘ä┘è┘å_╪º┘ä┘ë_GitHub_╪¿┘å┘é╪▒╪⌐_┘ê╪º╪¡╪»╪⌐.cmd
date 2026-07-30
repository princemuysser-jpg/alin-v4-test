@echo off
chcp 65001 >nul
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0رفع_نسخة_آلين_الى_GitHub.ps1"
echo.
if errorlevel 1 (
  echo تعذر الرفع. التقط صورة لهذه النافذة فقط.
) else (
  echo تم رفع النسخة. يمكنك اغلاق النافذة.
)
pause
