#!/bin/bash
# 編譯並安裝 Loopie 驅動（會要求管理員密碼）
set -euo pipefail
cd "$(dirname "$0")"

bash ./build.sh

DEST="/Library/Audio/Plug-Ins/HAL"
echo "安裝到 ${DEST}（需要管理員密碼）"
sudo mkdir -p "${DEST}"
sudo rm -rf "${DEST}/Loopie.driver"
sudo cp -R build/Loopie.driver "${DEST}/"
sudo chown -R root:wheel "${DEST}/Loopie.driver"

echo "重新啟動 CoreAudio（聲音會中斷一兩秒）"
sudo killall -9 coreaudiod 2>/dev/null || sudo launchctl kickstart -kp system/com.apple.audio.coreaudiod
sleep 4

if system_profiler SPAudioDataType 2>/dev/null | grep -q "Loopie"; then
  echo "成功：系統已出現 Loopie 裝置"
else
  echo "警告：還沒看到 Loopie。請把以下記錄貼給 Claude："
  log show --last 1m --predicate 'process == "coreaudiod" OR process CONTAINS "Core-Audio-Driver"' 2>/dev/null | grep -i -E "loopie|plug-in|plugin" | tail -20 || true
fi
