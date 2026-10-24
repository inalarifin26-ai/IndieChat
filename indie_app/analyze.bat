@echo off
rem Windows: runs "flutter pub get" + "flutter analyze" and saves everything to analyze.txt
cd /d "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter belum terpasang atau tidak ada di PATH.
  echo Lihat: https://docs.flutter.dev/get-started/install
  pause
  exit /b 1
)
(
  echo == flutter --version ==
  call flutter --version 2>&1
  echo.
  echo == flutter pub get ==
  call flutter pub get 2>&1
  echo.
  echo == flutter analyze ==
  call flutter analyze 2>&1
) > analyze.txt
echo Selesai. Buka file analyze.txt di folder ini, salin SELURUH isinya, lalu paste ke chat.
pause
