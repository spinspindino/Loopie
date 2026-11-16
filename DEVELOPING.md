# Loopie 開發者說明

這份文件給要閱讀、修改或除錯 Loopie 原始碼的人。使用說明請看 README.md。

English version below.


## 專案由兩個部分組成

1. 驅動（Loopie.driver）：一個 CoreAudio HAL 外掛（AudioServerPlugIn），
   在系統裡建立名為 Loopie 的 2 聲道虛擬裝置。送進它輸出端的聲音會原樣
   出現在它的輸入端。
2. 選單列程式（Loopie.app）：Swift 寫的 AppKit 程式，負責切換系統輸出、
   建立監聽用的多重輸出裝置、顯示音量表、錄音。

兩者獨立。沒有 app，驅動照常運作；app 只透過 CoreAudio 的公開 API
和驅動溝通，靠裝置 UID「Loopie_UID」找到它。


## 檔案結構

    driver/BlackHole.c    驅動原始碼，BlackHole 0.7.1，未修改
    driver/Info.plist     驅動的 bundle 設定（含 CFPlugIn 工廠 UUID）
    driver/LICENSE        GPL v3
    app/main.swift        選單列程式，全部在這一個檔案
    app/Info.plist        app 的 bundle 設定
    app/icon.png          1024x1024 圖示原圖
    build.sh              編譯驅動 -> build/Loopie.driver
    install.sh            編譯並安裝驅動（需要 sudo）
    build_app.sh          編譯 app，安裝到 /Applications 並啟動
    package.sh            產生 dist/Loopie-<版本>.dmg
    uninstall.sh          移除驅動
    build/、dist/         產物，可刪除後重新產生


## 編譯

需求：Apple Silicon、macOS 13 以上、Command Line Tools
（xcode-select --install）。不需要 Xcode，也沒有 Xcode 專案。

    bash install.sh                  # 驅動：編譯、安裝、重啟 coreaudiod
    bash build_app.sh                # app：編譯、安裝、啟動
    NO_INSTALL=1 bash build_app.sh   # app：只編譯
    bash package.sh                  # 兩者都重新編譯並打包成 dmg

目前只編譯 arm64。所有產物都是 ad-hoc 簽章（codesign --sign -），
沒有 Developer ID，也沒有公證。


## 驅動怎麼運作

BlackHole.c 沒有改動。Loopie 的名稱和設定是 build.sh 用 -D 參數在編譯時
覆寫 BlackHole.c 裡的巨集：

    kDriver_Name="Loopie"            決定 UID：Loopie_UID
    kHas_Driver_Name_Format=0        名稱裡不加聲道數
    kDevice_Name="Loopie"
    kDevice2_Name="Loopie Mirror"    BlackHole 內建的第二個裝置，預設隱藏
    kPlugIn_BundleID="audio.loopie.driver"
    kNumber_Of_Channels=2

所以在 BlackHole.c 裡搜尋「Loopie」找不到東西是正常的。

要注意的對應關係：

- kPlugIn_BundleID 必須和 driver/Info.plist 的 CFBundleIdentifier 相同，
  驅動在執行時用它找自己的 bundle。
- driver/Info.plist 裡的工廠 UUID 是 Loopie 專用的，和 BlackHole 不同，
  兩者可以同時安裝。工廠函式名稱仍是 BlackHole_Create。
- 驅動被 coreaudiod 載入。這裡當掉會影響整台電腦的音訊，所以功能都放在
  app，驅動保持原樣。


## app 怎麼運作

app/main.swift 依 MARK 分成幾段：

- 語言：englishText 對照表和 L() 函式。程式裡的字串以中文為鍵，
  英文介面時查表。
- CoreAudio 小工具（enum CA）：列出裝置、讀寫預設輸出、音量、
  建立和移除多重輸出裝置。
- 擷取（class Capture）：用 AudioDeviceCreateIOProcIDWithBlock 在 Loopie
  裝置上掛 IOProc，把輸入寫進 180 秒的環狀緩衝，並計算峰值。
- WAV：trimSilence() 和 writeWAV()，自己寫檔頭，支援 16 與 24 bit。
- 全域快捷鍵（enum HotKeys）：Carbon 的 RegisterEventHotKey。
- App（class AppDelegate）：選單、路由、錄音、設定。

幾個設計上的重點：

- 路由只改「預設輸出裝置」，不改「系統音效輸出」，所以提示音不會進 Loopie。
- 監聽是用 AudioHardwareCreateAggregateDevice 建一個 stacked（多重輸出）
  聚集裝置，UID 是 audio.loopie.monitor，子裝置為原本的實體輸出加 Loopie。
  關閉路由或結束 app 時移除。
- 是否正在路由不存狀態，每次都從目前的預設輸出裝置判斷（isRouting）。
- 計時器每 0.1 秒執行 onTick()：更新音量表、把錄音資料從環狀緩衝搬到
  記憶體陣列；每 1 秒執行 ensureCapture()，裝置消失或取樣率改變時重啟擷取。
- 錄音資料在停止前都放在記憶體，停止時才寫檔。
- 讀取音訊輸入需要「麥克風」權限。因為是 ad-hoc 簽章，每次重新編譯後
  系統可能會再問一次。

設定存在 UserDefaults（網域 audio.loopie.app），鍵有：
bits、trim、monitor、listening、folder、lang、realUID。


## 常見修改

改裝置名稱
: 改 build.sh 的 kDriver_Name、kDevice_Name、kDevice2_Name，以及
  app/main.swift 最上面的 loopieUID（值為 kDriver_Name 加上 "_UID"）。
  若連 bundle 名稱一起改，還要改兩個 Info.plist 和各腳本裡的路徑。

改聲道數
: 改 build.sh 的 kNumber_Of_Channels。app 目前只取前兩個聲道。

加一種語言或改英文用詞
: 改 app/main.swift 的 englishText 對照表。

改回溯緩衝長度
: Capture.seconds（單位秒）。記憶體用量約為 秒數 x 取樣率 x 8 位元組。

改快捷鍵
: applicationDidFinishLaunching 裡的 HotKeys.register。

換圖示
: 取代 app/icon.png（1024x1024），build_app.sh 會用 sips 和 iconutil
  轉成 icns。

改版本號
: package.sh 的 VERSION、app/Info.plist、driver/Info.plist 三處。


## 除錯

    # 驅動有沒有被載入
    system_profiler SPAudioDataType | grep -A6 Loopie

    # coreaudiod 的記錄
    log show --last 2m --predicate 'process == "coreaudiod"' | grep -i loopie

    # 重啟音訊服務
    sudo killall -9 coreaudiod

    # 在終端機直接執行 app，看得到當機訊息
    /Applications/Loopie.app/Contents/MacOS/Loopie

    # 清除 app 設定
    defaults delete audio.loopie.app

    # 重設麥克風權限
    tccutil reset Microphone audio.loopie.app


## 已知限制

- 沒有 Developer ID 簽章與公證，別台 Mac 第一次打開安裝檔會被 Gatekeeper 擋下。
- 只有 arm64。
- 錄音不做取樣率轉換。
- 多重輸出裝置沒有系統音量控制，所以 app 另外提供監聽音量滑桿。
- app 被強制終止（不是正常結束）時，不會還原輸出裝置，
  也可能留下「Loopie 監聽」裝置；下次啟動且未在路由時會清掉。
- 腳本要相容 macOS 內建的 bash 3.2：變數後面緊接全形字元時必須寫成
  ${VAR}，寫 $VAR 會被當成另一個變數名稱。
- 沒有自動化測試。


## 授權

GPL v3。驅動原始碼來自 Existential Audio 的 BlackHole：
https://github.com/ExistentialAudio/BlackHole


---------------------------------------------------------------------


# Loopie developer notes (English)

For anyone reading, changing or debugging the Loopie source.
User instructions are in README.md.


## Two parts

1. Driver (Loopie.driver): a CoreAudio HAL plug-in (AudioServerPlugIn)
   that creates a 2-channel virtual device called Loopie. Audio sent to
   its output appears unchanged on its input.
2. Menu bar app (Loopie.app): an AppKit app in Swift that switches the
   system output, creates a multi-output device for monitoring, shows a
   level meter and records.

They are independent. The driver works without the app. The app talks to
the driver only through public CoreAudio APIs and finds it by the device
UID "Loopie_UID".


## Layout

    driver/BlackHole.c    driver source, BlackHole 0.7.1, unmodified
    driver/Info.plist     driver bundle settings (with the CFPlugIn factory UUID)
    driver/LICENSE        GPL v3
    app/main.swift        the whole menu bar app, one file
    app/Info.plist        app bundle settings
    app/icon.png          1024x1024 icon source
    build.sh              build the driver -> build/Loopie.driver
    install.sh            build and install the driver (needs sudo)
    build_app.sh          build the app, install to /Applications, launch
    package.sh            produce dist/Loopie-<version>.dmg
    uninstall.sh          remove the driver
    build/, dist/         outputs, safe to delete and regenerate


## Building

Requirements: Apple Silicon, macOS 13 or later, Command Line Tools
(xcode-select --install). No Xcode and no Xcode project.

    bash install.sh                  # driver: build, install, restart coreaudiod
    bash build_app.sh                # app: build, install, launch
    NO_INSTALL=1 bash build_app.sh   # app: build only
    bash package.sh                  # rebuild both and package a dmg

Only arm64 is built. Everything is ad-hoc signed (codesign --sign -),
with no Developer ID and no notarization.


## How the driver works

BlackHole.c is not modified. Loopie's names and settings are macros in
BlackHole.c overridden at compile time by -D flags in build.sh:

    kDriver_Name="Loopie"            sets the UID: Loopie_UID
    kHas_Driver_Name_Format=0        no channel count in the name
    kDevice_Name="Loopie"
    kDevice2_Name="Loopie Mirror"    BlackHole's second device, hidden by default
    kPlugIn_BundleID="audio.loopie.driver"
    kNumber_Of_Channels=2

So searching BlackHole.c for "Loopie" finds nothing, and that is expected.

Things that must stay in step:

- kPlugIn_BundleID must equal CFBundleIdentifier in driver/Info.plist.
  The driver uses it at run time to find its own bundle.
- The factory UUID in driver/Info.plist is Loopie's own, different from
  BlackHole's, so both can be installed together. The factory function
  is still named BlackHole_Create.
- The driver is loaded by coreaudiod. A crash there affects audio for the
  whole machine, so features live in the app and the driver is left alone.


## How the app works

app/main.swift is split by MARK comments:

- Language: the englishText table and L(). Strings in the code are keyed
  by their Chinese text and looked up when the interface is English.
- CoreAudio helpers (enum CA): list devices, get and set the default
  output, volume, create and destroy the multi-output device.
- Capture (class Capture): an IOProc on the Loopie device via
  AudioDeviceCreateIOProcIDWithBlock, writing input into a 180-second
  ring buffer and tracking peaks.
- WAV: trimSilence() and writeWAV(), with a hand-written header,
  16 and 24 bit.
- Global hotkeys (enum HotKeys): Carbon RegisterEventHotKey.
- App (class AppDelegate): menu, routing, recording, settings.

Design points:

- Routing changes only the default output device, not the system sound
  effects output, so alert sounds never reach Loopie.
- Monitoring uses AudioHardwareCreateAggregateDevice to make a stacked
  (multi-output) aggregate with UID audio.loopie.monitor, containing the
  original hardware output plus Loopie. It is destroyed when routing is
  turned off or the app quits.
- Whether routing is on is not stored. It is derived each time from the
  current default output device (isRouting).
- A timer calls onTick() every 0.1 s to update the meter and move
  recording data from the ring buffer into an in-memory array. Every
  second ensureCapture() restarts capture if the device disappeared or
  its sample rate changed.
- A recording stays in memory until it is stopped, then it is written.
- Reading audio input needs Microphone permission. Because the signature
  is ad-hoc, the system may ask again after each rebuild.

Settings are in UserDefaults (domain audio.loopie.app) under the keys
bits, trim, monitor, listening, folder, lang, realUID.


## Common changes

Rename the device
: Change kDriver_Name, kDevice_Name and kDevice2_Name in build.sh, and
  loopieUID at the top of app/main.swift (kDriver_Name plus "_UID").
  To rename the bundles too, also change both Info.plist files and the
  paths in the scripts.

Change the channel count
: kNumber_Of_Channels in build.sh. The app currently uses only the first
  two channels.

Add a language or change English wording
: The englishText table in app/main.swift.

Change the look-back buffer length
: Capture.seconds. Memory use is about seconds x sample rate x 8 bytes.

Change the hotkeys
: HotKeys.register in applicationDidFinishLaunching.

Replace the icon
: Replace app/icon.png (1024x1024). build_app.sh converts it to icns
  with sips and iconutil.

Change the version
: VERSION in package.sh, app/Info.plist and driver/Info.plist.


## Debugging

    # is the driver loaded
    system_profiler SPAudioDataType | grep -A6 Loopie

    # coreaudiod log
    log show --last 2m --predicate 'process == "coreaudiod"' | grep -i loopie

    # restart the audio service
    sudo killall -9 coreaudiod

    # run the app from Terminal to see crash output
    /Applications/Loopie.app/Contents/MacOS/Loopie

    # clear app settings
    defaults delete audio.loopie.app

    # reset Microphone permission
    tccutil reset Microphone audio.loopie.app


## Known limitations

- No Developer ID signature or notarization, so Gatekeeper blocks the
  installer on first open on another Mac.
- arm64 only.
- No sample rate conversion when recording.
- A multi-output device has no system volume control, which is why the
  app has its own monitor volume slider.
- If the app is force-killed rather than quit, the output device is not
  restored and the "Loopie Monitor" device may be left behind. It is
  cleaned up on the next launch when routing is off.
- Scripts must work with the bash 3.2 that ships with macOS: a variable
  directly followed by a full-width character must be written ${VAR},
  because $VAR is read as a different variable name.
- No automated tests.


## License

GPL v3. The driver source is BlackHole by Existential Audio:
https://github.com/ExistentialAudio/BlackHole
