#!/usr/bin/env bash
# Mac / Linux: runs `flutter pub get` + `flutter analyze` and saves everything to analyze.txt
cd "$(dirname "$0")" || exit 1
if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter belum terpasang atau tidak ada di PATH."
  echo "Lihat: https://docs.flutter.dev/get-started/install"
  exit 1
fi
{
  echo "== flutter --version =="; flutter --version 2>&1
  echo; echo "== flutter pub get =="; flutter pub get 2>&1
  echo; echo "== flutter analyze =="; flutter analyze 2>&1
} > analyze.txt
echo "Selesai. Buka file analyze.txt di folder ini, salin SELURUH isinya, lalu paste ke chat."
echo "--- 5 baris terakhir ---"; tail -n 5 analyze.txt
