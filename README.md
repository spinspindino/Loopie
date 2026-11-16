# Loopie

Loopie 是一個給 Mac 用的虛擬音效卡，加上一個選單列小程式。
它讓你把電腦正在播放的聲音直接送進其他軟體（DAW、OBS、取樣軟體），
或是一鍵錄成 WAV 檔，全程數位、不經過喇叭和麥克風。

English version below.


## 需求

- Apple Silicon 的 Mac（M1 以後）。Intel Mac 目前不支援。
- macOS 13 以上。


## 安裝

1. 打開 dmg，點兩下 Loopie 的 .pkg 安裝檔。
2. 第一次打開時 macOS 會說無法驗證開發者而擋下來，這是因為這個安裝檔
   沒有付費的 Apple 開發者簽章。請到
   「系統設定 → 隱私權與安全性」，往下捲，在 Loopie 那一行按「仍要打開」，
   然後再開一次安裝檔。
3. 照畫面安裝，中途會要求管理員密碼。安裝完成時聲音會中斷一兩秒。
4. 選單列右上會出現兩條小直條，那就是 Loopie。
5. 第一次啟動會詢問「麥克風」權限，請按允許。
   macOS 把讀取任何音訊輸入都歸類為麥克風，Loopie 只會讀取 Loopie
   虛擬裝置的聲音，不會使用你的麥克風。

安裝了兩樣東西：

- 驅動：/Library/Audio/Plug-Ins/HAL/Loopie.driver
- 選單列程式：/Applications/Loopie.app


## 使用

### 把聲音送進其他軟體

1. 點選單列的 Loopie，勾選「把系統聲音送進 Loopie」。
2. 在接收的軟體裡，把音訊輸入裝置選成 Loopie。
3. 用完再點一次取消勾選，輸出會回到原本的喇叭或耳機。

「同時從喇叭監聽」打勾時，你還是聽得到聲音。這個模式下鍵盤的音量鍵
沒有作用，請用選單裡的「監聽音量」滑桿。

也可以不用選單列程式：在任何軟體把輸出選成 Loopie，另一個軟體把輸入
選成 Loopie，聲音就會從一邊流到另一邊。

### 錄音

- 「開始錄音」到「停止錄音並儲存」：手動錄一段。
- 「儲存最近 15 秒／30 秒／60 秒／2 分鐘」：回溯錄音。聽到想要的段落
  之後再按，就能把剛剛播過的聲音存下來。需要開著「待命聆聽」。

檔案預設存在「音樂/Loopie」資料夾，可以在選單裡更改。

### 快捷鍵

- Control + Option + Command + R：開始或停止錄音
- Control + Option + Command + S：儲存最近 30 秒

### 設定

- 待命聆聽：讓 Loopie 在背景持續聽，音量表和回溯錄音才有作用。
- WAV 格式：16-bit 或 24-bit。
- 自動去除頭尾靜音：存檔時把開頭和結尾的無聲部分切掉。
- 登入時自動啟動。
- 語言 / Language：選單可切換中文或英文，預設跟隨系統語言。


## 注意事項

- 待命聆聽開著時，選單列的橘色麥克風指示燈會一直亮，Mac 也可能不會
  自動進入睡眠。不用時可以關掉待命聆聽或結束 Loopie。
- 錄音檔的取樣率跟 Loopie 裝置相同，程式不做轉換。要更改請到
  「音訊 MIDI 設定」調整 Loopie 的取樣率。
- 系統提示音不會被錄進去。


## 移除

打開「終端機」，貼上這兩行（會要求管理員密碼）：

    sudo rm -rf /Library/Audio/Plug-Ins/HAL/Loopie.driver /Applications/Loopie.app
    sudo killall -9 coreaudiod


## 原始碼與授權

Loopie 以 GNU GPL v3 授權釋出，完整原始碼在 dmg 裡的 Loopie-source.zip。
要閱讀或修改程式，請看原始碼裡的 DEVELOPING.md。

驅動部分使用 Existential Audio 的 BlackHole 0.7.1 原始碼（GPL v3），
未經修改，只在編譯時更改了名稱設定。
https://github.com/ExistentialAudio/BlackHole

本軟體不提供任何擔保，請自行評估後使用。


---------------------------------------------------------------------


# Loopie (English)

Loopie is a virtual audio device for Mac with a small menu bar app.
It lets you send whatever your computer is playing straight into other
software (a DAW, OBS, a sampler), or save it as a WAV file with one
click. The signal stays digital and never touches speakers or a mic.


## Requirements

- A Mac with Apple Silicon (M1 or later). Intel Macs are not supported yet.
- macOS 13 or later.


## Install

1. Open the dmg and double-click the Loopie .pkg installer.
2. The first time, macOS will block it because the installer has no paid
   Apple developer signature. Go to
   System Settings > Privacy & Security, scroll down, click "Open Anyway"
   next to Loopie, then open the installer again.
3. Follow the installer. It asks for an administrator password. Audio
   drops out for a second or two when it finishes.
4. Two small bars appear at the right of the menu bar. That is Loopie.
5. On first launch it asks for Microphone access. Click Allow.
   macOS files every audio input under "Microphone". Loopie only reads
   the Loopie virtual device and never uses your microphone.

Two things are installed:

- Driver: /Library/Audio/Plug-Ins/HAL/Loopie.driver
- Menu bar app: /Applications/Loopie.app


## Use

The menu follows your system language (English or Traditional Chinese).
You can switch it under "語言 / Language". The items, top to bottom:

- Send System Audio to Loopie: routes everything you play into Loopie
  (click again to undo)
- Monitor Through Speakers: keep hearing it while it is routed
- Volume: monitor volume (the keyboard volume keys do not work in this mode)
- Start Recording / Stop and Save Recording
- Save Last 15 Seconds / 30 Seconds / 60 Seconds / 2 Minutes: saves audio
  that has already played. Needs Standby Listening.
- Standby Listening: keeps Loopie listening in the background, needed for
  the meter and "Save Last"
- WAV Format: 16-bit or 24-bit
- Trim Silence at Start and End
- Open Samples Folder / Change Samples Folder
- Launch at Login
- Quit Loopie

To route audio, tick the first item, then choose Loopie as the audio
input in the receiving app. You can also skip the menu bar app: set any
app's output to Loopie and another app's input to Loopie.

Recordings are saved to Music/Loopie by default.

Shortcuts:

- Control + Option + Command + R: start or stop recording
- Control + Option + Command + S: save the last 30 seconds


## Good to know

- While standby listening is on, the orange microphone indicator stays
  lit and the Mac may not go to sleep on its own. Turn standby listening
  off or quit Loopie when you are not using it.
- Recordings use the Loopie device's sample rate with no conversion.
  Change it in Audio MIDI Setup.
- System alert sounds are not recorded.


## Uninstall

Open Terminal and paste these two lines (asks for an admin password):

    sudo rm -rf /Library/Audio/Plug-Ins/HAL/Loopie.driver /Applications/Loopie.app
    sudo killall -9 coreaudiod


## Source and license

Loopie is released under the GNU GPL v3. Full source code is in
Loopie-source.zip inside the dmg.
To read or change the code, see DEVELOPING.md in the source.

The driver is built from the unmodified source of BlackHole 0.7.1 by
Existential Audio (GPL v3), with only the names changed at build time.
https://github.com/ExistentialAudio/BlackHole

This software comes with no warranty.
