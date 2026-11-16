// Loopie 選單列程式
// 功能：一鍵把系統聲音送進 Loopie、自動監聽、音量表、錄音、回溯錄音

import AppKit
import AVFoundation
import Accelerate
import Carbon.HIToolbox
import CoreAudio
import ServiceManagement

let loopieUID = "Loopie_UID"
let multiUID = "audio.loopie.monitor"
let sysObj = AudioObjectID(kAudioObjectSystemObject)

// MARK: - 語言

let englishText: [String: String] = [
    "Loopie 監聽": "Loopie Monitor",
    "Loopie 驅動已安裝": "Loopie driver installed",
    "找不到 Loopie 驅動": "Loopie driver not found",
    "找不到輸出裝置": "No output device found",
    "無法建立監聽裝置": "Could not create monitor device",
    "無法錄音": "Cannot record",
    "無法儲存": "Cannot save",
    "沒有聲音": "No sound",
    "已儲存": "Saved",
    "儲存失敗": "Save failed",
    "選擇": "Choose",
    "需要「麥克風」權限才能錄音，按這裡開啟設定…": "Microphone access is needed to record. Click to open Settings…",
    "把系統聲音送進 Loopie": "Send System Audio to Loopie",
    "同時從喇叭監聽": "Monitor Through Speakers",
    "監聽音量": "Volume",
    "■ 停止錄音並儲存　⌃⌥⌘R": "■ Stop and Save Recording   ⌃⌥⌘R",
    "● 開始錄音　⌃⌥⌘R": "● Start Recording   ⌃⌥⌘R",
    "儲存最近 15 秒": "Save Last 15 Seconds",
    "儲存最近 30 秒　⌃⌥⌘S": "Save Last 30 Seconds   ⌃⌥⌘S",
    "儲存最近 60 秒": "Save Last 60 Seconds",
    "儲存最近 2 分鐘": "Save Last 2 Minutes",
    "待命聆聽（音量表與回溯）": "Standby Listening (Meter and Save Last)",
    "WAV 格式": "WAV Format",
    "自動去除頭尾靜音": "Trim Silence at Start and End",
    "打開取樣資料夾": "Open Samples Folder",
    "更改取樣資料夾…": "Change Samples Folder…",
    "登入時自動啟動": "Launch at Login",
    "結束 Loopie": "Quit Loopie",
    "跟隨系統": "System Default",
]

// 介面語言：設定為 "zh" 或 "en" 時固定，否則跟隨系統語言
func useChinese() -> Bool {
    let pref = UserDefaults.standard.string(forKey: "lang") ?? "auto"
    if pref == "zh" { return true }
    if pref == "en" { return false }
    let sys = Locale.preferredLanguages.first ?? "en"
    return sys.hasPrefix("zh")
}

func L(_ zh: String) -> String {
    if useChinese() { return zh }
    return englishText[zh] ?? zh
}

// MARK: - CoreAudio 小工具

enum CA {
    static func addr(_ sel: AudioObjectPropertySelector,
                     _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                     _ elem: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        return AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: elem)
    }

    static func allDevices() -> [AudioDeviceID] {
        var a = addr(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(sysObj, &a, 0, nil, &size) == noErr else { return [] }
        let n = Int(size) / MemoryLayout<AudioDeviceID>.size
        if n == 0 { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: n)
        guard AudioObjectGetPropertyData(sysObj, &a, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    static func string(_ id: AudioObjectID, _ sel: AudioObjectPropertySelector) -> String? {
        var a = addr(sel)
        var size = UInt32(MemoryLayout<CFString?>.size)
        var cf: CFString? = nil
        let err = withUnsafeMutablePointer(to: &cf) { ptr -> OSStatus in
            return AudioObjectGetPropertyData(id, &a, 0, nil, &size, ptr)
        }
        guard err == noErr, let s = cf else { return nil }
        return s as String
    }

    static func uid(_ id: AudioDeviceID) -> String? { return string(id, kAudioDevicePropertyDeviceUID) }
    static func name(_ id: AudioDeviceID) -> String? { return string(id, kAudioObjectPropertyName) }

    static func device(uid: String) -> AudioDeviceID? {
        for d in allDevices() where CA.uid(d) == uid { return d }
        return nil
    }

    static func uint32(_ id: AudioObjectID, _ sel: AudioObjectPropertySelector) -> UInt32? {
        var a = addr(sel)
        var v: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, &v) == noErr else { return nil }
        return v
    }

    static func isVirtualOrAggregate(_ id: AudioDeviceID) -> Bool {
        guard let t = uint32(id, kAudioDevicePropertyTransportType) else { return false }
        return t == kAudioDeviceTransportTypeAggregate || t == kAudioDeviceTransportTypeVirtual
    }

    static func hasOutput(_ id: AudioDeviceID) -> Bool {
        var a = addr(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &a, 0, nil, &size) == noErr && size > 0
    }

    static func defaultOutput() -> AudioDeviceID {
        var a = addr(kAudioHardwarePropertyDefaultOutputDevice)
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        _ = AudioObjectGetPropertyData(sysObj, &a, 0, nil, &size, &id)
        return id
    }

    @discardableResult
    static func setDefaultOutput(_ id: AudioDeviceID) -> Bool {
        var a = addr(kAudioHardwarePropertyDefaultOutputDevice)
        var v = id
        return AudioObjectSetPropertyData(sysObj, &a, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &v) == noErr
    }

    static func sampleRate(_ id: AudioDeviceID) -> Double {
        var a = addr(kAudioDevicePropertyNominalSampleRate)
        var v: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        _ = AudioObjectGetPropertyData(id, &a, 0, nil, &size, &v)
        return v
    }

    static func volume(_ id: AudioDeviceID) -> Float32? {
        let elems: [UInt32] = [0, 1]
        for el in elems {
            var a = addr(kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput, el)
            if AudioObjectHasProperty(id, &a) {
                var v: Float32 = 0
                var size = UInt32(MemoryLayout<Float32>.size)
                if AudioObjectGetPropertyData(id, &a, 0, nil, &size, &v) == noErr { return v }
            }
        }
        return nil
    }

    static func setVolume(_ id: AudioDeviceID, _ value: Float32) {
        let elems: [UInt32] = [0, 1, 2]
        for el in elems {
            var a = addr(kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput, el)
            if AudioObjectHasProperty(id, &a) {
                var v = value
                _ = AudioObjectSetPropertyData(id, &a, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
            }
        }
    }

    // 建立「多重輸出裝置」：實體輸出 + Loopie
    static func createMultiOutput(mainUID: String) -> AudioDeviceID? {
        let subs: [[String: Any]] = [
            [kAudioSubDeviceUIDKey: mainUID],
            [kAudioSubDeviceUIDKey: loopieUID, kAudioSubDeviceDriftCompensationKey: 1],
        ]
        let desc: [String: Any] = [
            kAudioAggregateDeviceNameKey: L("Loopie 監聽"),
            kAudioAggregateDeviceUIDKey: multiUID,
            kAudioAggregateDeviceSubDeviceListKey: subs,
            "master": mainUID,
            kAudioAggregateDeviceIsStackedKey: 1,
            kAudioAggregateDeviceIsPrivateKey: 0,
        ]
        var id = AudioDeviceID(0)
        let err = AudioHardwareCreateAggregateDevice(desc as CFDictionary, &id)
        return err == noErr ? id : nil
    }

    static func destroyMultiOutput() {
        if let d = device(uid: multiUID) { _ = AudioHardwareDestroyAggregateDevice(d) }
    }
}

// MARK: - 擷取 Loopie 的聲音（環狀緩衝）

final class Capture {
    static let seconds = 180

    private(set) var running = false
    private(set) var deviceID: AudioDeviceID = 0
    private(set) var sampleRate: Double = 0

    private var procID: AudioDeviceIOProcID?
    private var ring: UnsafeMutablePointer<Float32>?
    private var capFrames = 0
    private var written: Int64 = 0
    private let lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
    private var peakL: Float = 0
    private var peakR: Float = 0

    init() { lock.initialize(to: os_unfair_lock()) }

    var framesWritten: Int64 {
        os_unfair_lock_lock(lock)
        let w = written
        os_unfair_lock_unlock(lock)
        return w
    }

    func takePeaks() -> (Float, Float) {
        let p = (peakL, peakR)
        peakL = 0
        peakR = 0
        return p
    }

    func start(device: AudioDeviceID, sampleRate sr: Double) {
        stop()
        guard sr > 0 else { return }
        capFrames = Int(sr) * Capture.seconds
        guard let raw = calloc(capFrames * 2, MemoryLayout<Float32>.size) else { return }
        ring = raw.assumingMemoryBound(to: Float32.self)
        written = 0
        deviceID = device
        sampleRate = sr

        var pid: AudioDeviceIOProcID?
        let err = AudioDeviceCreateIOProcIDWithBlock(&pid, device, nil) { [unowned self] _, inData, _, outData, _ in
            self.process(inData, outData)
        }
        guard err == noErr, let thePid = pid else {
            free(raw)
            ring = nil
            return
        }
        procID = thePid
        if AudioDeviceStart(device, thePid) == noErr {
            running = true
        } else {
            _ = AudioDeviceDestroyIOProcID(device, thePid)
            procID = nil
            free(raw)
            ring = nil
        }
    }

    func stop() {
        if let pid = procID {
            _ = AudioDeviceStop(deviceID, pid)
            _ = AudioDeviceDestroyIOProcID(deviceID, pid)
            procID = nil
            usleep(50_000)
        }
        running = false
        if let r = ring {
            free(r)
            ring = nil
        }
    }

    // 在音訊執行緒上執行
    private func process(_ inData: UnsafePointer<AudioBufferList>, _ outData: UnsafeMutablePointer<AudioBufferList>) {
        let outs = UnsafeMutableAudioBufferListPointer(outData)
        for b in outs {
            if let d = b.mData { memset(d, 0, Int(b.mDataByteSize)) }
        }
        let ins = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inData))
        guard ins.count > 0, let ring = ring else { return }
        let b = ins[0]
        let ch = Int(b.mNumberChannels)
        guard ch > 0, let raw = b.mData else { return }
        let frames = Int(b.mDataByteSize) / (4 * ch)
        guard frames > 0, frames <= capFrames else { return }
        let src = UnsafePointer<Float32>(raw.assumingMemoryBound(to: Float32.self))

        var pos = Int(written % Int64(capFrames))
        if ch == 2 {
            var remaining = frames
            var s = src
            while remaining > 0 {
                let n = min(remaining, capFrames - pos)
                memcpy(ring + pos * 2, s, n * 8)
                s += n * 2
                pos = (pos + n) % capFrames
                remaining -= n
            }
        } else {
            for f in 0..<frames {
                let l = src[f * ch]
                let r = ch > 1 ? src[f * ch + 1] : l
                ring[pos * 2] = l
                ring[pos * 2 + 1] = r
                pos += 1
                if pos == capFrames { pos = 0 }
            }
        }

        var l: Float = 0
        var r: Float = 0
        vDSP_maxmgv(src, ch, &l, vDSP_Length(frames))
        if ch > 1 { vDSP_maxmgv(src + 1, ch, &r, vDSP_Length(frames)) } else { r = l }
        if l > peakL { peakL = l }
        if r > peakR { peakR = r }

        os_unfair_lock_lock(lock)
        written += Int64(frames)
        os_unfair_lock_unlock(lock)
    }

    // 讀出 [start, end) 的立體聲交錯取樣；end 省略時讀到最新
    func read(from start: Int64, to end: Int64? = nil) -> [Float32] {
        guard let ring = ring, capFrames > 0 else { return [] }
        let w = framesWritten
        let oldest = max(Int64(0), w - Int64(capFrames))
        let s = max(start, oldest)
        let e = min(w, end ?? w)
        guard e > s else { return [] }
        let n = Int(e - s)
        var out = [Float32](repeating: 0, count: n * 2)
        let cap = capFrames
        out.withUnsafeMutableBufferPointer { dst in
            guard var d = dst.baseAddress else { return }
            var pos = Int(s % Int64(cap))
            var rem = n
            while rem > 0 {
                let k = min(rem, cap - pos)
                memcpy(d, ring + pos * 2, k * 8)
                d += k * 2
                pos = (pos + k) % cap
                rem -= k
            }
        }
        return out
    }
}

// MARK: - WAV

func trimSilence(_ s: [Float32], rate: Double) -> [Float32] {
    let thr: Float32 = 0.001
    let n = s.count
    var first = -1
    var i = 0
    while i < n {
        if abs(s[i]) > thr { first = i; break }
        i += 1
    }
    if first < 0 { return [] }
    var last = n - 1
    while last > first && abs(s[last]) <= thr { last -= 1 }
    let pad = Int(rate * 0.01)
    let f0 = max(0, first / 2 - pad)
    let f1 = min(n / 2, last / 2 + 1 + pad)
    if f1 <= f0 { return [] }
    return Array(s[(f0 * 2)..<(f1 * 2)])
}

func writeWAV(_ s: [Float32], rate: Double, bits: Int, to url: URL) throws {
    let bytesPer = bits / 8
    let dataSize = s.count * bytesPer
    var d = Data(capacity: 44 + dataSize)
    func u32(_ v: UInt32) {
        var x = v.littleEndian
        withUnsafeBytes(of: &x) { d.append(contentsOf: $0) }
    }
    func u16(_ v: UInt16) {
        var x = v.littleEndian
        withUnsafeBytes(of: &x) { d.append(contentsOf: $0) }
    }
    func tag(_ t: String) { d.append(contentsOf: Array(t.utf8)) }

    let sr = UInt32(rate)
    tag("RIFF"); u32(UInt32(36 + dataSize)); tag("WAVE")
    tag("fmt "); u32(16); u16(1); u16(2)
    u32(sr); u32(sr * 2 * UInt32(bytesPer)); u16(UInt16(2 * bytesPer)); u16(UInt16(bits))
    tag("data"); u32(UInt32(dataSize))

    if bits == 16 {
        var out = [Int16](repeating: 0, count: s.count)
        for i in 0..<s.count {
            let x = s[i]
            let v: Float32 = x.isFinite ? max(-1, min(1, x)) : 0
            out[i] = Int16(v * 32767)
        }
        out.withUnsafeBytes { d.append(contentsOf: $0) }
    } else {
        var out = [UInt8](repeating: 0, count: dataSize)
        for i in 0..<s.count {
            let x = s[i]
            let f: Float32 = x.isFinite ? max(-1, min(1, x)) : 0
            let v = Int32(f * 8388607)
            out[i * 3] = UInt8(truncatingIfNeeded: v)
            out[i * 3 + 1] = UInt8(truncatingIfNeeded: v >> 8)
            out[i * 3 + 2] = UInt8(truncatingIfNeeded: v >> 16)
        }
        d.append(contentsOf: out)
    }
    try d.write(to: url)
}

// MARK: - 全域快捷鍵

enum HotKeys {
    static var handlers: [UInt32: () -> Void] = [:]
    static var installed = false
    static var refs: [EventHotKeyRef?] = []

    static func register(id: UInt32, keyCode: Int, modifiers: Int, handler: @escaping () -> Void) {
        if !installed {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { (_, event, _) -> OSStatus in
                var hk = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                  nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
                let theID = hk.id
                DispatchQueue.main.async { HotKeys.handlers[theID]?() }
                return noErr
            }, 1, &spec, nil, nil)
            installed = true
        }
        handlers[id] = handler
        var ref: EventHotKeyRef?
        let sig: OSType = 0x4C4F4F50 // 'LOOP'
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), EventHotKeyID(signature: sig, id: id),
                            GetApplicationEventTarget(), 0, &ref)
        refs.append(ref)
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menu = NSMenu()
    let capture = Capture()
    let defaults = UserDefaults.standard

    var micGranted = false
    var micAsked = false
    var dispL: Float = 0
    var dispR: Float = 0
    var tick = 0

    var recording = false
    var recWanted = false
    var recSamples: [Float32] = []
    var recRead: Int64 = 0
    var recRate: Double = 48000
    var recStart = Date()

    var flashText = ""
    var flashUntil = Date.distantPast

    // 設定
    var bits: Int { return defaults.integer(forKey: "bits") == 24 ? 24 : 16 }
    var trim: Bool { return defaults.object(forKey: "trim") as? Bool ?? true }
    var monitor: Bool { return defaults.object(forKey: "monitor") as? Bool ?? true }
    var listening: Bool { return defaults.object(forKey: "listening") as? Bool ?? true }
    var folder: URL {
        if let p = defaults.string(forKey: "folder") { return URL(fileURLWithPath: p) }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music/Loopie")
    }

    var isRouting: Bool {
        guard let u = CA.uid(CA.defaultOutput()) else { return false }
        return u == loopieUID || u == multiUID
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        statusItem.button?.imagePosition = .imageLeft
        statusItem.button?.image = meterImage()

        if !isRouting { CA.destroyMultiOutput() }

        AVCaptureDevice.requestAccess(for: .audio) { ok in
            DispatchQueue.main.async {
                self.micGranted = ok
                self.micAsked = true
                self.ensureCapture()
            }
        }

        let t = Timer(timeInterval: 0.1, target: self, selector: #selector(onTick), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)

        let mods = cmdKey | optionKey | controlKey
        HotKeys.register(id: 1, keyCode: kVK_ANSI_R, modifiers: mods) { [weak self] in self?.toggleRecording() }
        HotKeys.register(id: 2, keyCode: kVK_ANSI_S, modifiers: mods) { [weak self] in self?.saveLast(seconds: 30) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if recording { stopRecording(sync: true) }
        if isRouting { disableRouting() }
        capture.stop()
    }

    // MARK: 定時更新

    @objc func onTick() {
        tick += 1
        if tick % 10 == 0 { ensureCapture() }

        let (l, r) = capture.takePeaks()
        dispL = max(l, dispL * 0.75)
        dispR = max(r, dispR * 0.75)

        if recording { drainRecording() }

        guard let button = statusItem.button else { return }
        button.image = meterImage()
        var title = ""
        if Date() < flashUntil {
            title = " " + flashText
        } else if recording {
            let sec = Int(Date().timeIntervalSince(recStart))
            title = String(format: " %d:%02d", sec / 60, sec % 60)
        }
        if button.title != title { button.title = title }
    }

    func ensureCapture() {
        guard listening || recWanted, micGranted, let dev = CA.device(uid: loopieUID) else {
            if capture.running {
                if recording { stopRecording(sync: false) }
                capture.stop()
            }
            return
        }
        let sr = CA.sampleRate(dev)
        if !capture.running || capture.deviceID != dev || capture.sampleRate != sr {
            if recording { stopRecording(sync: false) }
            capture.start(device: dev, sampleRate: sr)
        }
    }

    func flash(_ text: String) {
        flashText = text
        flashUntil = Date().addingTimeInterval(2.0)
    }

    // MARK: 音量表圖示

    func level(_ v: Float) -> CGFloat {
        if v <= 0.001 { return 0 }
        let db = 20 * log10(v)
        return CGFloat(max(0, min(1, (db + 60) / 60)))
    }

    func meterImage() -> NSImage {
        let l = dispL
        let r = dispR
        let rec = recording
        let active = capture.running
        let img = NSImage(size: NSSize(width: 18, height: 16), flipped: false) { _ in
            let values = [l, r]
            for i in 0..<2 {
                let x = CGFloat(3 + i * 7)
                let back = NSRect(x: x, y: 1, width: 5, height: 14)
                NSColor.labelColor.withAlphaComponent(active ? 0.28 : 0.12).setFill()
                NSBezierPath(roundedRect: back, xRadius: 1.5, yRadius: 1.5).fill()
                let h = 14 * self.level(values[i])
                if h > 0.5 {
                    let color: NSColor
                    if values[i] >= 0.99 { color = NSColor.systemOrange }
                    else if rec { color = NSColor.systemRed }
                    else { color = NSColor.labelColor }
                    color.setFill()
                    NSBezierPath(roundedRect: NSRect(x: x, y: 1, width: 5, height: max(2, h)), xRadius: 1.5, yRadius: 1.5).fill()
                } else if rec {
                    NSColor.systemRed.setFill()
                    NSBezierPath(roundedRect: NSRect(x: x, y: 1, width: 5, height: 2), xRadius: 1, yRadius: 1).fill()
                }
            }
            return true
        }
        img.isTemplate = false
        return img
    }

    // MARK: 路由

    func realOutputUID() -> String? {
        let cur = CA.defaultOutput()
        if let u = CA.uid(cur), !u.hasPrefix("Loopie"), u != multiUID, !CA.isVirtualOrAggregate(cur) { return u }
        if let saved = defaults.string(forKey: "realUID"), CA.device(uid: saved) != nil { return saved }
        for d in CA.allDevices() where CA.hasOutput(d) && !CA.isVirtualOrAggregate(d) {
            if let u = CA.uid(d), !u.hasPrefix("Loopie") { return u }
        }
        return nil
    }

    func enableRouting() {
        guard let loopie = CA.device(uid: loopieUID) else { flash(L("找不到 Loopie 驅動")); return }
        guard let real = realOutputUID() else { flash(L("找不到輸出裝置")); return }
        defaults.set(real, forKey: "realUID")
        CA.setVolume(loopie, 1.0)
        CA.destroyMultiOutput()
        if monitor {
            guard let agg = CA.createMultiOutput(mainUID: real) else { flash(L("無法建立監聽裝置")); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                CA.setDefaultOutput(agg)
            }
        } else {
            CA.setDefaultOutput(loopie)
        }
    }

    func disableRouting() {
        if let saved = defaults.string(forKey: "realUID"), let dev = CA.device(uid: saved) {
            CA.setDefaultOutput(dev)
        } else if let real = realOutputUID(), let dev = CA.device(uid: real) {
            CA.setDefaultOutput(dev)
        }
        CA.destroyMultiOutput()
    }

    @objc func toggleRouting(_ sender: Any?) {
        if isRouting { disableRouting() } else { enableRouting() }
    }

    @objc func toggleMonitor(_ sender: Any?) {
        let wasRouting = isRouting
        defaults.set(!monitor, forKey: "monitor")
        if wasRouting { enableRouting() }
    }

    @objc func volumeChanged(_ sender: NSSlider) {
        if let saved = defaults.string(forKey: "realUID"), let dev = CA.device(uid: saved) {
            CA.setVolume(dev, Float32(sender.doubleValue))
        }
    }

    // MARK: 錄音

    func toggleRecording() {
        if recording { stopRecording(sync: false) } else { startRecording() }
    }

    @objc func toggleRecordingAction(_ sender: Any?) { toggleRecording() }

    func startRecording() {
        if !capture.running {
            // 待命聆聽關閉時，只在錄音期間開啟擷取
            recWanted = true
            ensureCapture()
        }
        guard capture.running else { recWanted = false; flash(L("無法錄音")); return }
        recSamples = []
        recRead = capture.framesWritten
        recRate = capture.sampleRate
        recStart = Date()
        recording = true
    }

    func drainRecording() {
        let chunk = capture.read(from: recRead)
        if !chunk.isEmpty {
            recSamples.append(contentsOf: chunk)
            recRead += Int64(chunk.count / 2)
        }
    }

    func stopRecording(sync: Bool) {
        drainRecording()
        recording = false
        recWanted = false
        let samples = recSamples
        recSamples = []
        save(samples, rate: recRate, sync: sync)
    }

    func saveLast(seconds: Int) {
        guard capture.running else { flash(L("無法儲存")); return }
        let total = capture.framesWritten
        let frames = Int64(Double(seconds) * capture.sampleRate)
        let samples = capture.read(from: max(Int64(0), total - frames), to: total)
        save(samples, rate: capture.sampleRate, sync: false)
    }

    @objc func saveLastAction(_ sender: NSMenuItem) { saveLast(seconds: sender.tag) }

    func save(_ input: [Float32], rate: Double, sync: Bool) {
        let doTrim = trim
        let theBits = bits
        let dir = folder
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let url = dir.appendingPathComponent("Loopie " + fmt.string(from: Date()) + ".wav")

        let work = { () -> String in
            var s = input
            if doTrim { s = trimSilence(s, rate: rate) }
            if s.isEmpty { return L("沒有聲音") }
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                try writeWAV(s, rate: rate, bits: theBits, to: url)
                return L("已儲存")
            } catch {
                return L("儲存失敗")
            }
        }
        if sync {
            _ = work()
        } else {
            DispatchQueue.global(qos: .userInitiated).async {
                let result = work()
                DispatchQueue.main.async { self.flash(result) }
            }
        }
    }

    // MARK: 其他動作

    @objc func toggleListening(_ sender: Any?) {
        defaults.set(!listening, forKey: "listening")
        ensureCapture()
    }

    @objc func setBits(_ sender: NSMenuItem) { defaults.set(sender.tag, forKey: "bits") }
    @objc func toggleTrim(_ sender: Any?) { defaults.set(!trim, forKey: "trim") }
    @objc func setLang(_ sender: NSMenuItem) {
        let values = ["auto", "zh", "en"]
        defaults.set(values[max(0, min(2, sender.tag))], forKey: "lang")
    }

    @objc func openFolder(_ sender: Any?) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }

    @objc func chooseFolder(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = L("選擇")
        if panel.runModal() == .OK, let url = panel.url {
            defaults.set(url.path, forKey: "folder")
        }
    }

    @objc func openMicSettings(_ sender: Any?) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func toggleLogin(_ sender: Any?) {
        let service = SMAppService.mainApp
        if service.status == .enabled {
            try? service.unregister()
        } else {
            try? service.register()
        }
    }

    @objc func quit(_ sender: Any?) { NSApp.terminate(nil) }

    // MARK: 選單

    func item(_ title: String, _ action: Selector?, on: Bool = false, enabled: Bool = true, tag: Int = 0) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: "")
        it.target = self
        it.state = on ? .on : .off
        it.isEnabled = enabled
        it.tag = tag
        return it
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let loopie = CA.device(uid: loopieUID)
        let routing = isRouting

        // 狀態
        if let dev = loopie {
            let sr = CA.sampleRate(dev)
            let khz = sr.truncatingRemainder(dividingBy: 1000) == 0 ? String(format: "%.0f", sr / 1000) : String(format: "%.1f", sr / 1000)
            menu.addItem(item(L("Loopie 驅動已安裝") + " · \(khz) kHz", nil, enabled: false))
        } else {
            menu.addItem(item(L("找不到 Loopie 驅動"), nil, enabled: false))
        }
        if micAsked && !micGranted {
            menu.addItem(item(L("需要「麥克風」權限才能錄音，按這裡開啟設定…"), #selector(openMicSettings(_:))))
        }
        menu.addItem(NSMenuItem.separator())

        // 路由
        menu.addItem(item(L("把系統聲音送進 Loopie"), #selector(toggleRouting(_:)), on: routing, enabled: loopie != nil))
        menu.addItem(item(L("同時從喇叭監聽"), #selector(toggleMonitor(_:)), on: monitor))

        if routing, monitor, let saved = defaults.string(forKey: "realUID"), let dev = CA.device(uid: saved), let vol = CA.volume(dev) {
            let view = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 30))
            let label = NSTextField(labelWithString: L("監聽音量"))
            label.font = NSFont.menuFont(ofSize: 0)
            label.frame = NSRect(x: 22, y: 6, width: 70, height: 18)
            let slider = NSSlider(value: Double(vol), minValue: 0, maxValue: 1, target: self, action: #selector(volumeChanged(_:)))
            slider.isContinuous = true
            slider.frame = NSRect(x: 94, y: 5, width: 140, height: 20)
            view.addSubview(label)
            view.addSubview(slider)
            let it = NSMenuItem()
            it.view = view
            menu.addItem(it)
        }
        menu.addItem(NSMenuItem.separator())

        // 錄音
        let canSaveLast = capture.running
        let canRecord = capture.running || (loopie != nil && micGranted)
        if recording {
            menu.addItem(item(L("■ 停止錄音並儲存　⌃⌥⌘R"), #selector(toggleRecordingAction(_:))))
        } else {
            menu.addItem(item(L("● 開始錄音　⌃⌥⌘R"), #selector(toggleRecordingAction(_:)), enabled: canRecord))
        }
        menu.addItem(item(L("儲存最近 15 秒"), #selector(saveLastAction(_:)), enabled: canSaveLast, tag: 15))
        menu.addItem(item(L("儲存最近 30 秒　⌃⌥⌘S"), #selector(saveLastAction(_:)), enabled: canSaveLast, tag: 30))
        menu.addItem(item(L("儲存最近 60 秒"), #selector(saveLastAction(_:)), enabled: canSaveLast, tag: 60))
        menu.addItem(item(L("儲存最近 2 分鐘"), #selector(saveLastAction(_:)), enabled: canSaveLast, tag: 120))
        menu.addItem(NSMenuItem.separator())

        // 設定
        menu.addItem(item(L("待命聆聽（音量表與回溯）"), #selector(toggleListening(_:)), on: listening))
        let fmtItem = NSMenuItem(title: L("WAV 格式"), action: nil, keyEquivalent: "")
        let fmtMenu = NSMenu()
        fmtMenu.autoenablesItems = false
        fmtMenu.addItem(item("16-bit", #selector(setBits(_:)), on: bits == 16, tag: 16))
        fmtMenu.addItem(item("24-bit", #selector(setBits(_:)), on: bits == 24, tag: 24))
        fmtItem.submenu = fmtMenu
        menu.addItem(fmtItem)
        menu.addItem(item(L("自動去除頭尾靜音"), #selector(toggleTrim(_:)), on: trim))
        menu.addItem(item(L("打開取樣資料夾"), #selector(openFolder(_:))))
        menu.addItem(item(L("更改取樣資料夾…"), #selector(chooseFolder(_:))))
        let langItem = NSMenuItem(title: "語言 / Language", action: nil, keyEquivalent: "")
        let langMenu = NSMenu()
        langMenu.autoenablesItems = false
        let lang = defaults.string(forKey: "lang") ?? "auto"
        langMenu.addItem(item(L("跟隨系統"), #selector(setLang(_:)), on: lang == "auto", tag: 0))
        langMenu.addItem(item("中文", #selector(setLang(_:)), on: lang == "zh", tag: 1))
        langMenu.addItem(item("English", #selector(setLang(_:)), on: lang == "en", tag: 2))
        langItem.submenu = langMenu
        menu.addItem(langItem)
        menu.addItem(item(L("登入時自動啟動"), #selector(toggleLogin(_:)), on: SMAppService.mainApp.status == .enabled))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(item(L("結束 Loopie"), #selector(quit(_:))))
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
_ = app.setActivationPolicy(.accessory)
app.run()
