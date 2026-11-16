#!/bin/bash
# 移除 Loopie 驅動
set -euo pipefail
sudo rm -rf "/Library/Audio/Plug-Ins/HAL/Loopie.driver"
sudo killall -9 coreaudiod 2>/dev/null || sudo launchctl kickstart -kp system/com.apple.audio.coreaudiod
echo "已移除 Loopie"
