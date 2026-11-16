#!/bin/bash
# 編譯 Loopie 選單列程式並安裝到 /Applications
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Loopie.app"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"

swiftc -O -swift-version 5 -target arm64-apple-macos13.0 \
  app/main.swift -o "${APP}/Contents/MacOS/Loopie"

cp app/Info.plist "${APP}/Contents/Info.plist"

# 圖示：app/icon.png -> Loopie.icns
if [ -f app/icon.png ]; then
  ICONSET="build/Loopie.iconset"
  rm -rf "${ICONSET}"
  mkdir -p "${ICONSET}"
  for s in 16 32 128 256 512; do
    d=$((s * 2))
    sips -z "${s}" "${s}" app/icon.png --out "${ICONSET}/icon_${s}x${s}.png" >/dev/null
    sips -z "${d}" "${d}" app/icon.png --out "${ICONSET}/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "${ICONSET}" -o "${APP}/Contents/Resources/Loopie.icns"
fi
codesign --force --sign - --identifier audio.loopie.app "${APP}"

if [ "${NO_INSTALL:-0}" = "1" ]; then
  echo "編譯完成：${APP}"
  exit 0
fi

pkill -x Loopie 2>/dev/null || true
sleep 1
rm -rf "/Applications/Loopie.app"
cp -R "${APP}" "/Applications/"
touch "/Applications/Loopie.app"
open "/Applications/Loopie.app"
echo "完成：Loopie 已在選單列啟動"
