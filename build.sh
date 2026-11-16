#!/bin/bash
# 編譯 Loopie 虛擬音訊驅動 -> build/Loopie.driver
set -euo pipefail
cd "$(dirname "$0")"

if ! xcode-select -p >/dev/null 2>&1; then
  echo "找不到 Command Line Tools。請先執行： xcode-select --install"
  exit 1
fi

OUT="build/Loopie.driver"
rm -rf "${OUT}"
mkdir -p "${OUT}/Contents/MacOS" "${OUT}/Contents/Resources"

clang -bundle -O2 -arch arm64 -mmacosx-version-min=12.0 \
  -Wno-format-extra-args -Wno-unused-value \
  -DkDriver_Name='"Loopie"' \
  -DkHas_Driver_Name_Format=0 \
  -DkDevice_Name='"Loopie"' \
  -DkDevice2_Name='"Loopie Mirror"' \
  -DkPlugIn_BundleID='"audio.loopie.driver"' \
  -DkPlugIn_Icon='"Loopie.icns"' \
  -DkManufacturer_Name='"Loopie"' \
  -DkNumber_Of_Channels=2 \
  -framework CoreAudio -framework CoreFoundation -framework Accelerate \
  driver/BlackHole.c -o "${OUT}/Contents/MacOS/Loopie"

cp driver/Info.plist "${OUT}/Contents/Info.plist"
[ -f driver/Loopie.icns ] && cp driver/Loopie.icns "${OUT}/Contents/Resources/"
codesign --force --sign - "${OUT}"

echo "編譯完成：${OUT}"
