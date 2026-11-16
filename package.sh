#!/bin/bash
# 打包 Loopie：產生 dist/Loopie-<版本>.dmg（內含 .pkg 安裝檔、README、原始碼）
set -euo pipefail
cd "$(dirname "$0")"

VERSION="0.1.0"
NAME="Loopie-${VERSION}"

echo "1/4 編譯驅動與選單列程式"
bash ./build.sh
NO_INSTALL=1 bash ./build_app.sh

echo "2/4 製作 .pkg 安裝檔"
WORK="build/package"
rm -rf "${WORK}"
ROOT="${WORK}/root"
SCRIPTS="${WORK}/scripts"
STAGE="${WORK}/dmg"
mkdir -p "${ROOT}/Library/Audio/Plug-Ins/HAL" "${ROOT}/Applications" "${SCRIPTS}" "${STAGE}" dist

cp -R build/Loopie.driver "${ROOT}/Library/Audio/Plug-Ins/HAL/"
cp -R build/Loopie.app "${ROOT}/Applications/"

cat > "${SCRIPTS}/preinstall" <<'PRE'
#!/bin/bash
/usr/bin/pkill -x Loopie 2>/dev/null || true
exit 0
PRE

cat > "${SCRIPTS}/postinstall" <<'POST'
#!/bin/bash
/usr/bin/killall -9 coreaudiod 2>/dev/null || true
sleep 3
if [ -n "${USER:-}" ] && [ "${USER}" != "root" ]; then
  /usr/bin/sudo -u "${USER}" /usr/bin/open "/Applications/Loopie.app" 2>/dev/null || true
fi
exit 0
POST
chmod +x "${SCRIPTS}/preinstall" "${SCRIPTS}/postinstall"

# 關閉「可重新定位」，否則安裝程式可能把 app 裝到電腦上其他同名副本的位置
COMP="${WORK}/components.plist"
pkgbuild --analyze --root "${ROOT}" "${COMP}" >/dev/null
i=0
while /usr/libexec/PlistBuddy -c "Print :${i}" "${COMP}" >/dev/null 2>&1; do
  /usr/libexec/PlistBuddy -c "Set :${i}:BundleIsRelocatable false" "${COMP}" >/dev/null 2>&1 || true
  i=$((i + 1))
done

pkgbuild --root "${ROOT}" \
  --component-plist "${COMP}" \
  --scripts "${SCRIPTS}" \
  --identifier audio.loopie.pkg \
  --version "${VERSION}" \
  --install-location / \
  --ownership recommended \
  "${STAGE}/${NAME}.pkg"

echo "3/4 加入 README 與原始碼"
cp README.md "${STAGE}/README.txt"
zip -r -q "${STAGE}/Loopie-source.zip" \
  README.md DEVELOPING.md LICENSE driver app build.sh build_app.sh install.sh uninstall.sh package.sh \
  -x "*.DS_Store"

echo "4/4 製作 dmg"
rm -f "dist/${NAME}.dmg"
hdiutil create -volname "${NAME}" -srcfolder "${STAGE}" -ov -format UDZO "dist/${NAME}.dmg" >/dev/null

echo "完成：dist/${NAME}.dmg"
open dist
