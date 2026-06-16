import AppKit
import CoreGraphics
import Darwin

enum RecorderSettings {
    private static let defaults = UserDefaults(suiteName: "local.codex.OneFPSRecorder") ?? .standard
    private static let recordingNameKey = "recordingName"
    private static let showOverlayKey = "showRecordingOverlay"
    private static let showMonthlyScoreKey = "showMonthlyScore"
    private static let hourlyRateKey = "hourlyRate"
    private static let monthlyGoalKey = "monthlyGoal"
    private static let glowWhenGoalReachedKey = "glowWhenGoalReached"
    private static let startMessageIndexKey = "startMessageIndex"
    private static let stopMessageIndexKey = "stopMessageIndex"

    static var recordingName: String {
        get {
            defaults.synchronize()
            let saved = defaults.string(forKey: recordingNameKey) ?? "録画"
            return sanitizedRecordingName(saved)
        }
        set {
            defaults.set(sanitizedRecordingName(newValue), forKey: recordingNameKey)
        }
    }

    static var showOverlay: Bool {
        get {
            defaults.synchronize()
            if defaults.object(forKey: showOverlayKey) == nil {
                return true
            }
            return defaults.bool(forKey: showOverlayKey)
        }
        set {
            defaults.set(newValue, forKey: showOverlayKey)
        }
    }

    static var showMonthlyScore: Bool {
        get {
            defaults.synchronize()
            return defaults.bool(forKey: showMonthlyScoreKey)
        }
        set { defaults.set(newValue, forKey: showMonthlyScoreKey) }
    }

    static var hourlyRate: Int {
        get {
            defaults.synchronize()
            let value = defaults.integer(forKey: hourlyRateKey)
            return value > 0 ? value : 2000
        }
        set { defaults.set(max(0, newValue), forKey: hourlyRateKey) }
    }

    static var monthlyGoal: Int {
        get {
            defaults.synchronize()
            return max(0, defaults.integer(forKey: monthlyGoalKey))
        }
        set { defaults.set(max(0, newValue), forKey: monthlyGoalKey) }
    }

    static var glowWhenGoalReached: Bool {
        get {
            defaults.synchronize()
            return defaults.bool(forKey: glowWhenGoalReachedKey)
        }
        set { defaults.set(newValue, forKey: glowWhenGoalReachedKey) }
    }

    static func nextStartMessageIndex(modulo: Int) -> Int {
        nextIndex(forKey: startMessageIndexKey, modulo: modulo)
    }

    static func nextStopMessageIndex(modulo: Int) -> Int {
        nextIndex(forKey: stopMessageIndexKey, modulo: modulo)
    }

    private static func nextIndex(forKey key: String, modulo: Int) -> Int {
        guard modulo > 0 else { return 0 }
        let current = defaults.integer(forKey: key)
        defaults.set((current + 1) % modulo, forKey: key)
        return current % modulo
    }

    static func sanitizedRecordingName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "録画" : trimmed
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let parts = fallback.components(separatedBy: invalid)
        let sanitized = parts.joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = sanitized.isEmpty ? "録画" : sanitized
        return String(safeName.prefix(48))
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let appSupportDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library", isDirectory: true)
        .appendingPathComponent("Application Support", isDirectory: true)
        .appendingPathComponent("OneFPSRecorder", isDirectory: true)
    private static let commandFile = appSupportDirectory.appendingPathComponent("command.txt")
    private let logFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library", isDirectory: true)
        .appendingPathComponent("Logs", isDirectory: true)
        .appendingPathComponent("1FPS録画.log")
    private var statusItem: NSStatusItem!
    private var overlay: RecordingOverlay!
    private var recorder: OneFPSRecorder!
    private var lastToggleAt = Date.distantPast
    private var commandTimer: DispatchSourceTimer?
    private var lastCommandLine = ""
    private var lockFileHandle: FileHandle?
    private var settingsWindowController: SettingsWindowController?
    private var overlayMessage = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        guard acquireSingleInstanceLock() else {
            NSApp.terminate(nil)
            return
        }
        migrateLegacyAppLog()

        recorder = OneFPSRecorder(status: { [weak self] state in
            DispatchQueue.main.async {
                self?.applyStatus(state)
            }
        })
        OneFPSRecorder.migrateRecordingsDirectory()
        OneFPSRecorder.recoverOrphanedFrameDirectories()
        OneFPSRecorder.migrateSavedTextFileNames()
        OneFPSRecorder.renameExistingRecordings(from: "", to: RecorderSettings.recordingName)
        OneFPSRecorder.rewriteRecordingLogFileNames(to: RecorderSettings.recordingName)
        OneFPSRecorder.updateDailyTotalLog()

        setupStatusItem()
        overlay = RecordingOverlay(stopAction: { [weak self] in
            self?.stopRecordingFromOverlay()
        })
        setupCommandNotifications()
        applyStatus(.idle)
        log("OneFPSRecorder launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        if recorder.isRecording {
            recorder.stop()
        }
        commandTimer?.cancel()
        if let lockFileHandle {
            flock(lockFileHandle.fileDescriptor, LOCK_UN)
            try? lockFileHandle.close()
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        let toggleItem = NSMenuItem(title: "録画開始", action: #selector(toggleRecording), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let folderItem = NSMenuItem(title: "保存フォルダを開く", action: #selector(openFolder), keyEquivalent: "")
        folderItem.target = self
        menu.addItem(folderItem)

        let settingsItem = NSMenuItem(title: "設定...", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func applyStatus(_ state: RecorderState) {
        guard let button = statusItem.button else { return }
        button.attributedTitle = NSAttributedString(string: "")
        switch state {
        case .idle:
            button.title = "1FPS"
            button.contentTintColor = nil
            statusItem.menu?.item(at: 0)?.title = "録画開始"
            statusItem.menu?.item(at: 0)?.isEnabled = true
            overlay.hide()
        case .recording(let startedAt):
            let elapsed = Int(Date().timeIntervalSince(startedAt))
            let score = OneFPSRecorder.monthlyScore(includingCurrentStartedAt: startedAt)
            let scoreText = RecorderSettings.showMonthlyScore ? " \(Self.currency(score.earnedYen))" : ""
            button.title = String(format: "録画中 1FPS %02d:%02d%@", elapsed / 60, elapsed % 60, scoreText)
            button.contentTintColor = nil
            statusItem.menu?.item(at: 0)?.title = "録画停止"
            statusItem.menu?.item(at: 0)?.isEnabled = true
            if RecorderSettings.showOverlay {
                overlay.showRecording(
                    elapsedSeconds: elapsed,
                    message: overlayMessage,
                    scoreText: RecorderSettings.showMonthlyScore ? "月間 \(Self.currency(score.earnedYen))" : nil,
                    glow: RecorderSettings.showMonthlyScore
                        && RecorderSettings.glowWhenGoalReached
                        && RecorderSettings.monthlyGoal > 0
                        && score.earnedYen >= RecorderSettings.monthlyGoal
                )
            } else {
                overlay.hide()
            }
        case .encoding:
            button.title = "1FPS 保存中"
            button.contentTintColor = nil
            statusItem.menu?.item(at: 0)?.title = "保存中..."
            statusItem.menu?.item(at: 0)?.isEnabled = false
            if RecorderSettings.showOverlay {
                overlay.showSaving(message: overlayMessage)
            } else {
                overlay.hide()
            }
        case .error(let message):
            button.title = "1FPS エラー"
            button.contentTintColor = nil
            statusItem.menu?.item(at: 0)?.title = "録画開始"
            statusItem.menu?.item(at: 0)?.isEnabled = true
            overlay.hide()
            showAlert(message)
        }
    }

    private static func currency(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)円"
    }

    @objc private func toggleRecording() {
        let now = Date()
        if now.timeIntervalSince(lastToggleAt) < 0.5 {
            log("Ignored duplicate toggle")
            return
        }
        lastToggleAt = now
        log("Toggle recording requested")
        if recorder.isRecording {
            overlayMessage = Self.stopMessage()
            recorder.stop()
        } else if recorder.isEncoding {
            log("Ignored toggle while encoding")
        } else {
            overlayMessage = Self.startMessage()
            Task {
                do {
                    try await recorder.start()
                } catch {
                    log("Start failed: \(error.localizedDescription)")
                    await MainActor.run {
                        applyStatus(.error(error.localizedDescription))
                    }
                }
            }
        }
    }

    private func stopRecordingFromOverlay() {
        guard recorder.isRecording else { return }
        log("Overlay stop requested")
        overlayMessage = Self.stopMessage()
        recorder.stop()
    }

    private func handleCommand(_ command: String) {
        log("Command received: \(command)")
        switch command {
        case "start":
            if !recorder.isRecording {
                toggleRecording()
            }
        case "stop":
            if recorder.isRecording {
                toggleRecording()
            }
        case "flush":
            if recorder.isRecording {
                recorder.flushCurrentSegment()
            }
        case "settings":
            openSettings()
        case "toggle":
            toggleRecording()
        default:
            break
        }
    }

    @objc private func openFolder() {
        NSWorkspace.shared.open(OneFPSRecorder.recordingsDirectory)
    }

    @objc private func openSettings() {
        log("Settings requested")
        let helperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("OneFPSRecorderSettings")
        let process = Process()
        process.executableURL = helperURL
        do {
            try process.run()
        } catch {
            showAlert("設定画面を開けませんでした: \(error.localizedDescription)")
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "OneFPSRecorder"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func setupCommandNotifications() {
        try? FileManager.default.createDirectory(at: Self.appSupportDirectory, withIntermediateDirectories: true)
        lastCommandLine = currentCommandLine() ?? ""
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.5, repeating: 0.5, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            self?.pollCommandFile()
        }
        commandTimer = timer
        timer.resume()
        log("Registered command file watcher")
    }

    private func pollCommandFile() {
        guard let line = currentCommandLine(),
              !line.isEmpty,
              line != lastCommandLine
        else { return }

        lastCommandLine = line
        let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        handleCommand(parts[1])
    }

    private func currentCommandLine() -> String? {
        try? String(contentsOf: Self.commandFile, encoding: .utf8)
            .split(separator: "\n")
            .last
            .map(String.init)
    }

    private func log(_ message: String) {
        let formatter = ISO8601DateFormatter()
        let line = "\(formatter.string(from: Date())) \(message)\n"
        try? FileManager.default.createDirectory(at: logFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path),
               let handle = try? FileHandle(forWritingTo: logFile) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            } else {
                try? data.write(to: logFile)
            }
        }
    }

    private func migrateLegacyAppLog() {
        let legacyLogFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("OneFPSRecorder.log")
        guard FileManager.default.fileExists(atPath: legacyLogFile.path) else { return }

        do {
            try FileManager.default.createDirectory(at: logFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: logFile.path) {
                try FileManager.default.moveItem(at: legacyLogFile, to: logFile)
                return
            }

            let legacyText = (try? String(contentsOf: legacyLogFile, encoding: .utf8)) ?? ""
            if !legacyText.isEmpty, let handle = try? FileHandle(forWritingTo: logFile) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(legacyText.utf8))
                try? handle.close()
            }
            try? FileManager.default.removeItem(at: legacyLogFile)
        } catch {
            return
        }
    }

    private static func startMessage() -> String {
        let messages = messageCandidates(forStart: true)
        let index = RecorderSettings.nextStartMessageIndex(modulo: messages.count)
        return clippedMessage(messages[index])
    }

    private static func stopMessage() -> String {
        let messages = messageCandidates(forStart: false)
        let index = RecorderSettings.nextStopMessageIndex(modulo: messages.count)
        return clippedMessage(messages[index])
    }

    private static func messageCandidates(forStart: Bool) -> [String] {
        let hour = Calendar.current.component(.hour, from: Date())
        let dailySeconds = OneFPSRecorder.dailyWorkSeconds()
        let workBlock: [String]
        if dailySeconds >= 8 * 3600 {
            workBlock = ["8時間突破。今日は強い。", "働きすぎ注意、でも偉い。", "Visitas級の粘りです。"]
        } else if dailySeconds >= 4 * 3600 {
            workBlock = ["4時間突破、ここから差が出る。", "積み上げが見えてきた。", "画面録画係も驚いてます。"]
        } else if dailySeconds >= 3600 {
            workBlock = ["1時間超え。いい流れ。", "もう助走は終わった。", "この調子で記録します。"]
        } else {
            workBlock = ["今日の1本目、いきましょう。", "まずは短く始めよう。", "1FPSで静かに見守ります。"]
        }

        let timeBlock: [String]
        switch hour {
        case 5..<11:
            timeBlock = [
                "朝から偉いですね。", "今日も頑張るんだ。", "こんな時間から偉いぞ〜。",
                "朝のVisitas、始動。", "朝活を記録します。", "早い開始は強い。",
                "眠気ごと前に進もう。", "朝の集中、いただきます。", "まず一手、JUST DO IT。",
                "朝の画面を逃しません。", "今日の勝ち筋を作ろう。", "午前中に差をつけよう。",
                "いい朝、いい記録。", "起きて作業、かなり偉い。", "朝の自分に投資です。",
                "ここから一日を作る。", "静かに録画を始めます。", "朝の積み上げ開始。",
                "目が覚めたら前進。", "朝から攻めてるね。", "この時間の作業は価値ある。",
                "軽く始めて深く入ろう。", "朝の1FPS、仕事します。", "Visitasまで届かせよう。",
                "午前の集中を形に。", "早起きの勝利です。", "朝から画面が燃えてる。",
                "まず保存、そして前進。", "朝の自分、いいぞ。", "今日も勝ちにいこう。"
            ]
        case 11..<17:
            timeBlock = [
                "昼ごはんは食べたかい。", "ここからが本番。", "気合い入れていくぞ。",
                "目指せ上場。", "午後のVisitas、伸ばそう。", "昼の集中を録ります。",
                "JUST DO IT。", "午後から巻き返せる。", "手を動かせば進む。",
                "画面録画係、待機完了。", "昼の一手を記録します。", "ここで積む人が勝つ。",
                "次の30分を取りにいこう。", "ランチ後の再起動です。", "眠気に勝てば強い。",
                "午後のログを残します。", "勢いを作る時間です。", "焦らず速くいこう。",
                "Visitasの未来に投資。", "集中のスイッチ入れよう。", "机上の作業を成果へ。",
                "昼からでも十分いける。", "1FPSで着実に残します。", "今日の山場、いこう。",
                "作業は裏切らない。", "午後の自分に任せよう。", "小さく出して大きく進む。",
                "ここからもう一段。", "熱量を画面に残そう。", "気持ちよく進めよう。"
            ]
        default:
            timeBlock = [
                "今日も頑張ってるね。", "早めに寝るんだぞ。", "いけいけいけー！",
                "夜のVisitas、静かに進行。", "夜作業を記録します。", "無理はするな、でも進もう。",
                "JUST DO IT。", "ここからの集中は強い。", "夜の一手、残します。",
                "画面録画係も夜勤です。", "深追いしすぎ注意。", "今日の締めを作ろう。",
                "あと少し、形にしよう。", "夜でも手は動かせる。", "寝る前に勝ちを作る。",
                "静かな時間は武器です。", "今日の粘り、いいね。", "録画しながら支えます。",
                "夜の積み上げ開始。", "短く決めて休もう。", "未来の自分が見返します。",
                "Visitasに効く作業を。", "今日のラストスパート。", "眠る前に一歩だけ。",
                "夜の集中、開始。", "自分との約束を残そう。", "明日に効く記録です。",
                "遅い時間でも偉い。", "保存できる努力にしよう。", "ここで終わらせにいこう。"
            ]
        }

        let common = forStart ? [
            "今日も頑張りましょう！", "作業開始です。", "集中の時間です。",
            "記録を始めます。", "進捗を動画に残します。", "いい流れでいきましょう。",
            "迷ったら前へ。", "始める人が一番強い。", "勝つまでやる、短くてもやる。",
            "できることから始めよう。", "1秒1枚で見守ります。", "今日の積み上げ開始。",
            "画面の変化を逃しません。", "小さく始めて大きく進む。", "Visitasも見ています。"
        ] : [
            "今日もお疲れ様でした！", "ここまで保存します。", "いい区切りです。",
            "作業ログをまとめています。", "動画へ追記しています。", "ひとまず休みましょう。",
            "記録を確定します。", "積み上げを保存します。", "今日の努力を残します。",
            "画面録画係、保存中です。", "ここまでの流れを残します。", "Visitasにも効く一歩。",
            "一区切りつけます。", "次に見返せる形へ。", "お疲れ様、保存します。"
        ]

        return timeBlock + workBlock + common
    }

    private static func clippedMessage(_ message: String) -> String {
        let limit = 28
        if message.count <= limit { return message }
        return String(message.prefix(limit - 1)) + "…"
    }

    private func acquireSingleInstanceLock() -> Bool {
        try? FileManager.default.createDirectory(at: Self.appSupportDirectory, withIntermediateDirectories: true)
        let lockURL = Self.appSupportDirectory.appendingPathComponent("app.lock")
        if !FileManager.default.fileExists(atPath: lockURL.path) {
            FileManager.default.createFile(atPath: lockURL.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: lockURL) else { return true }
        if flock(handle.fileDescriptor, LOCK_EX | LOCK_NB) == 0 {
            lockFileHandle = handle
            return true
        }
        try? handle.close()
        return false
    }

}

enum RecorderState {
    case idle
    case recording(Date)
    case encoding
    case error(String)
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let nameField = NSTextField(string: RecorderSettings.recordingName)
    private let overlayCheckbox = NSButton(checkboxWithTitle: "録画中パネルを表示する", target: nil, action: nil)
    private let onSave: (String, String) -> Void

    init(onSave: @escaping (String, String) -> Void) {
        self.onSave = onSave

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 190),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = "1FPS録画 設定"
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.isFloatingPanel = true
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        nameField.stringValue = RecorderSettings.recordingName
        overlayCheckbox.state = RecorderSettings.showOverlay ? .on : .off
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let title = NSTextField(labelWithString: "保存名")
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        title.frame = NSRect(x: 24, y: 132, width: 80, height: 20)

        nameField.frame = NSRect(x: 104, y: 126, width: 282, height: 28)
        nameField.placeholderString = "録画"

        let hint = NSTextField(labelWithString: "ファイル名は MMDD_名前.mp4 になります。名前変更時は既存動画も更新します。")
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 104, y: 100, width: 292, height: 18)

        overlayCheckbox.target = self
        overlayCheckbox.frame = NSRect(x: 104, y: 68, width: 240, height: 22)

        let saveButton = NSButton(title: "保存", target: self, action: #selector(savePressed))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.frame = NSRect(x: 310, y: 24, width: 76, height: 30)

        let cancelButton = NSButton(title: "閉じる", target: self, action: #selector(closePressed))
        cancelButton.bezelStyle = .rounded
        cancelButton.frame = NSRect(x: 224, y: 24, width: 76, height: 30)

        contentView.addSubview(title)
        contentView.addSubview(nameField)
        contentView.addSubview(hint)
        contentView.addSubview(overlayCheckbox)
        contentView.addSubview(saveButton)
        contentView.addSubview(cancelButton)
    }

    @objc private func savePressed() {
        let oldName = RecorderSettings.recordingName
        let newName = RecorderSettings.sanitizedRecordingName(nameField.stringValue)
        RecorderSettings.recordingName = newName
        RecorderSettings.showOverlay = overlayCheckbox.state == .on
        onSave(oldName, newName)
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    @objc private func closePressed() {
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

final class RecordingOverlay {
    private static let originXKey = "recordingOverlayOriginX"
    private static let originYKey = "recordingOverlayOriginY"
    private let panel: NSPanel
    private let root = DraggableVisualEffectView(frame: NSRect(x: 0, y: 0, width: 336, height: 76))
    private let titleLabel = DraggableLabel(labelWithString: "録画 00:00")
    private let scoreLabel = DraggableLabel(labelWithString: "")
    private let messageLabel = DraggableLabel(labelWithString: "")
    private let statusDot = DraggableDotView(frame: NSRect(x: 0, y: 0, width: 9, height: 9))
    private let stopButton = NSButton(title: "停止", target: nil, action: nil)
    private let stopAction: () -> Void
    private var glowTimer: Timer?
    private var glowHue: CGFloat = 0

    init(stopAction: @escaping () -> Void) {
        self.stopAction = stopAction

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 336, height: 76),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false

        root.material = .hudWindow
        root.blendingMode = .behindWindow
        root.state = .active
        root.wantsLayer = true
        root.layer?.cornerRadius = 18
        root.layer?.borderWidth = 1
        root.layer?.borderColor = NSColor.systemRed.withAlphaComponent(0.55).cgColor
        root.layer?.masksToBounds = true

        statusDot.wantsLayer = true
        statusDot.layer?.backgroundColor = NSColor.systemRed.cgColor
        statusDot.layer?.cornerRadius = 4.5
        statusDot.layer?.shadowColor = NSColor.systemRed.cgColor
        statusDot.layer?.shadowOpacity = 0.8
        statusDot.layer?.shadowRadius = 4
        statusDot.layer?.shadowOffset = .zero

        titleLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.alignment = .left

        scoreLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        scoreLabel.textColor = NSColor.white.withAlphaComponent(0.92)
        scoreLabel.alignment = .right
        scoreLabel.lineBreakMode = .byTruncatingTail

        messageLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        messageLabel.textColor = NSColor.white.withAlphaComponent(0.9)
        messageLabel.alignment = .left
        messageLabel.lineBreakMode = .byTruncatingTail

        stopButton.target = self
        stopButton.action = #selector(stopPressed)
        stopButton.bezelStyle = .rounded
        stopButton.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        stopButton.contentTintColor = .systemRed
        stopButton.setButtonType(.momentaryPushIn)

        root.addSubview(statusDot)
        root.addSubview(titleLabel)
        root.addSubview(scoreLabel)
        root.addSubview(messageLabel)
        root.addSubview(stopButton)
        panel.contentView = root
        layoutSubviews()
    }

    func showRecording(elapsedSeconds: Int, message: String, scoreText: String?, glow: Bool) {
        titleLabel.stringValue = String(format: "録画 %02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
        scoreLabel.stringValue = scoreText ?? ""
        scoreLabel.isHidden = scoreText == nil
        messageLabel.stringValue = message
        statusDot.layer?.backgroundColor = NSColor.systemRed.cgColor
        stopButton.isEnabled = true
        stopButton.title = "停止"
        setGlowEnabled(glow)
        show()
    }

    func showSaving(message: String) {
        titleLabel.stringValue = "保存中"
        scoreLabel.stringValue = ""
        scoreLabel.isHidden = true
        messageLabel.stringValue = message
        statusDot.layer?.backgroundColor = NSColor.systemOrange.cgColor
        stopButton.isEnabled = false
        stopButton.title = "..."
        setGlowEnabled(false)
        show()
    }

    func hide() {
        setGlowEnabled(false)
        saveCurrentOrigin()
        panel.orderOut(nil)
    }

    private func show() {
        if !panel.isVisible {
            positionOnMainDisplay()
        }
        panel.orderFrontRegardless()
    }

    private func layoutSubviews() {
        statusDot.frame = NSRect(x: 16, y: 49, width: 9, height: 9)
        titleLabel.frame = NSRect(x: 34, y: 44, width: 118, height: 18)
        scoreLabel.frame = NSRect(x: 154, y: 44, width: 104, height: 18)
        messageLabel.frame = NSRect(x: 16, y: 16, width: 248, height: 18)
        stopButton.frame = NSRect(x: 274, y: 41, width: 48, height: 26)
    }

    private func setGlowEnabled(_ enabled: Bool) {
        if enabled {
            guard glowTimer == nil else { return }
            glowTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                self?.advanceGlow()
            }
            RunLoop.main.add(glowTimer!, forMode: .common)
        } else {
            glowTimer?.invalidate()
            glowTimer = nil
            root.layer?.borderColor = NSColor.systemRed.withAlphaComponent(0.55).cgColor
            statusDot.layer?.backgroundColor = NSColor.systemRed.cgColor
        }
    }

    private func advanceGlow() {
        glowHue += 0.018
        if glowHue > 1 { glowHue -= 1 }
        let color = NSColor(calibratedHue: glowHue, saturation: 0.9, brightness: 1.0, alpha: 1.0)
        root.layer?.borderColor = color.cgColor
        statusDot.layer?.backgroundColor = color.cgColor
        statusDot.layer?.shadowColor = color.cgColor
    }

    private func positionOnMainDisplay() {
        if let savedOrigin = savedOriginInsideAnyScreen() {
            panel.setFrameOrigin(savedOrigin)
            return
        }

        let visibleFrame = Self.mainScreenVisibleFrame()
        let size = panel.frame.size
        let margin: CGFloat = 18
        let x = visibleFrame.maxX - size.width - margin
        let y = visibleFrame.maxY - size.height - margin
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func saveCurrentOrigin() {
        let origin = panel.frame.origin
        UserDefaults.standard.set(origin.x, forKey: Self.originXKey)
        UserDefaults.standard.set(origin.y, forKey: Self.originYKey)
    }

    private func savedOriginInsideAnyScreen() -> NSPoint? {
        guard UserDefaults.standard.object(forKey: Self.originXKey) != nil,
              UserDefaults.standard.object(forKey: Self.originYKey) != nil
        else { return nil }

        let origin = NSPoint(
            x: UserDefaults.standard.double(forKey: Self.originXKey),
            y: UserDefaults.standard.double(forKey: Self.originYKey)
        )
        let frame = NSRect(origin: origin, size: panel.frame.size)
        let isVisible = NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(frame)
        }
        return isVisible ? origin : nil
    }

    private static func mainScreenVisibleFrame() -> NSRect {
        if let screen = NSScreen.main {
            return screen.visibleFrame
        }
        return NSScreen.screens.first?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
    }

    @objc private func stopPressed() {
        saveCurrentOrigin()
        stopAction()
    }
}

final class DraggableVisualEffectView: NSVisualEffectView {
    override var mouseDownCanMoveWindow: Bool { true }
}

final class DraggableLabel: NSTextField {
    override var mouseDownCanMoveWindow: Bool { true }
}

final class DraggableDotView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}

final class OneFPSRecorder: NSObject {
    private static let maxSegmentFrames = 3600
    static let recordingsDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Movies", isDirectory: true)
        .appendingPathComponent("1FPS録画", isDirectory: true)
    private static let legacyRecordingsDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Movies", isDirectory: true)
        .appendingPathComponent("OneFPSRecordings", isDirectory: true)

    private let status: (RecorderState) -> Void
    private var startedAt: Date?
    private var segmentStartedAt: Date?
    private var displayTimer: DispatchSourceTimer?
    private var captureTimer: DispatchSourceTimer?
    private let captureQueue = DispatchQueue(label: "onefps.capture", qos: .utility)
    private var frameDirectory: URL?
    private var outputURL: URL?
    private var frameIndex = 0
    private(set) var isEncoding = false
    private var pendingStopAfterEncode = false

    var isRecording: Bool { startedAt != nil }

    init(status: @escaping (RecorderState) -> Void) {
        self.status = status
        super.init()
    }

    func start() async throws {
        guard !isRecording else { return }
        try FileManager.default.createDirectory(at: Self.recordingsDirectory, withIntermediateDirectories: true)

        let now = Date()
        try createSegment(startedAt: now)
        isEncoding = false
        pendingStopAfterEncode = false
        startedAt = now

        status(.recording(startedAt ?? Date()))
        startDisplayTimer()
        startCaptureTimer()
    }

    func stop() {
        guard isRecording else { return }
        pendingStopAfterEncode = true
        if isEncoding {
            status(.encoding)
            return
        }
        stopDisplayTimer()
        stopCaptureTimer()
        isEncoding = true
        status(.encoding)

        captureQueue.async { [weak self] in
            self?.encodeCurrentSegment(final: true)
        }
    }

    func flushCurrentSegment() {
        guard isRecording, !isEncoding else { return }
        stopCaptureTimer()
        isEncoding = true
        status(.encoding)

        captureQueue.async { [weak self] in
            self?.encodeCurrentSegment(final: false)
        }
    }

    private func createSegment(startedAt: Date) throws {
        let frameDirectory = Self.recordingsDirectory
            .appendingPathComponent(".frames-\(Self.timestamp())", isDirectory: true)
        try FileManager.default.createDirectory(at: frameDirectory, withIntermediateDirectories: true)
        self.frameDirectory = frameDirectory
        self.outputURL = frameDirectory.appendingPathComponent("segment-\(Self.timestamp()).mp4")
        self.segmentStartedAt = startedAt
        frameIndex = 0
    }

    private func cleanupCurrentSegment() {
        if let frameDirectory {
            try? FileManager.default.removeItem(at: frameDirectory)
        }
        frameDirectory = nil
        outputURL = nil
        frameIndex = 0
        segmentStartedAt = nil
    }

    private func cleanupAll() {
        cleanupCurrentSegment()
        isEncoding = false
        pendingStopAfterEncode = false
        startedAt = nil
    }

    private func startDisplayTimer() {
        stopDisplayTimer()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 1.0, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            guard let self, let startedAt = self.startedAt else { return }
            self.status(.recording(startedAt))
        }
        displayTimer = timer
        timer.resume()
    }

    private func stopDisplayTimer() {
        displayTimer?.cancel()
        displayTimer = nil
    }

    private func startCaptureTimer() {
        stopCaptureTimer()
        let timer = DispatchSource.makeTimerSource(queue: captureQueue)
        timer.schedule(deadline: .now(), repeating: 1.0, leeway: .milliseconds(150))
        timer.setEventHandler { [weak self] in
            self?.captureFrame()
        }
        captureTimer = timer
        timer.resume()
    }

    private func stopCaptureTimer() {
        captureTimer?.cancel()
        captureTimer = nil
    }

    private func captureFrame() {
        guard let frameDirectory else { return }
        let index = frameIndex
        frameIndex += 1
        let frameURL = frameDirectory.appendingPathComponent(String(format: "frame-%06d.jpg", index))
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        if let captureRectangle = Self.displayBoundsContainingMouse() {
            process.arguments = [
                "-x",
                "-t", "jpg",
                "-R", Self.rectangleArgument(captureRectangle),
                frameURL.path
            ]
        } else {
            process.arguments = ["-x", "-t", "jpg", frameURL.path]
        }
        try? process.run()
        process.waitUntilExit()

        if frameIndex >= Self.maxSegmentFrames {
            rotateSegmentFromCaptureQueue()
        }
    }

    private func rotateSegmentFromCaptureQueue() {
        guard isRecording, !isEncoding else { return }
        stopCaptureTimer()
        isEncoding = true
        DispatchQueue.main.async {
            self.status(.encoding)
        }
        encodeCurrentSegment(final: false)
    }

    private func encodeCurrentSegment(final: Bool) {
        guard let frameDirectory, let outputURL else {
            DispatchQueue.main.async {
                self.cleanupAll()
                self.status(.idle)
            }
            return
        }
        let recordingStartedAt = segmentStartedAt ?? startedAt ?? Date()
        let recordingEndedAt = Date()

        let frameCount = (try? FileManager.default.contentsOfDirectory(atPath: frameDirectory.path)
            .filter { $0.hasSuffix(".jpg") }
            .count) ?? 0

        guard frameCount > 0 else {
            DispatchQueue.main.async {
                if final || self.pendingStopAfterEncode {
                    self.cleanupAll()
                    self.status(.idle)
                } else {
                    self.restartAfterSegmentSave()
                }
            }
            return
        }

        let ffmpeg = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin/ffmpeg")
        let process = Process()
        process.executableURL = ffmpeg
        process.arguments = [
            "-hide_banner",
            "-loglevel", "error",
            "-framerate", "1",
            "-i", frameDirectory.appendingPathComponent("frame-%06d.jpg").path,
            "-vf", "scale=960:600:force_original_aspect_ratio=decrease,pad=960:600:(ow-iw)/2:(oh-ih)/2",
            "-c:v", "libx264",
            "-preset", "veryfast",
            "-tune", "stillimage",
            "-pix_fmt", "yuv420p",
            "-an",
            "-movflags", "+faststart",
            outputURL.path,
            "-y"
        ]
        try? process.run()
        process.waitUntilExit()

        let appendSucceeded = process.terminationStatus == 0
            ? appendSegmentToDailyFile(segmentURL: outputURL, frameDirectory: frameDirectory)
            : false
        if appendSucceeded {
            Self.appendRecordingLog(startedAt: recordingStartedAt, endedAt: recordingEndedAt, outputURL: Self.dailyOutputURL(for: recordingEndedAt))
            Self.updateDailyTotalLog(for: recordingEndedAt)
        }

        DispatchQueue.main.async {
            if process.terminationStatus == 0, appendSucceeded {
                if final || self.pendingStopAfterEncode {
                    self.stopDisplayTimer()
                    self.cleanupAll()
                    self.status(.idle)
                } else {
                    self.restartAfterSegmentSave()
                }
            } else if process.terminationStatus == 0 {
                self.stopDisplayTimer()
                self.cleanupAll()
                self.status(.error("日別動画への追記に失敗しました。"))
            } else {
                self.stopDisplayTimer()
                self.cleanupAll()
                self.status(.error("ffmpeg が失敗しました。終了コード: \(process.terminationStatus)"))
            }
        }
    }

    private func restartAfterSegmentSave() {
        cleanupCurrentSegment()
        do {
            try createSegment(startedAt: Date())
            isEncoding = false
            pendingStopAfterEncode = false
            status(.recording(startedAt ?? Date()))
            startCaptureTimer()
        } catch {
            stopDisplayTimer()
            cleanupAll()
            status(.error("次の録画区切りを作成できませんでした。"))
        }
    }

    private func appendSegmentToDailyFile(segmentURL: URL, frameDirectory: URL) -> Bool {
        Self.appendSegmentToDailyFile(segmentURL: segmentURL, frameDirectory: frameDirectory, date: Date())
    }

    private static func appendSegmentToDailyFile(segmentURL: URL, frameDirectory: URL, date: Date) -> Bool {
        let dailyURL = dailyOutputURL(for: date)
        do {
            try FileManager.default.createDirectory(at: dailyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: dailyURL.path) {
                try FileManager.default.moveItem(at: segmentURL, to: dailyURL)
                return true
            }

            let listURL = frameDirectory.appendingPathComponent("concat.txt")
            let tempDailyURL = dailyURL.deletingLastPathComponent()
                .appendingPathComponent(".daily-\(Self.timestamp())-\(UUID().uuidString).mp4")
            let concatList = [
                "file '\(Self.concatEscapedPath(dailyURL.path))'",
                "file '\(Self.concatEscapedPath(segmentURL.path))'"
            ].joined(separator: "\n") + "\n"
            try concatList.write(to: listURL, atomically: true, encoding: .utf8)

            let ffmpeg = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".local/bin/ffmpeg")
            let process = Process()
            process.executableURL = ffmpeg
            process.arguments = [
                "-hide_banner",
                "-loglevel", "error",
                "-f", "concat",
                "-safe", "0",
                "-i", listURL.path,
                "-vf", "scale=960:600:force_original_aspect_ratio=decrease,pad=960:600:(ow-iw)/2:(oh-ih)/2,fps=1",
                "-c:v", "libx264",
                "-preset", "veryfast",
                "-tune", "stillimage",
                "-pix_fmt", "yuv420p",
                "-an",
                "-movflags", "+faststart",
                tempDailyURL.path,
                "-y"
            ]
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                try? FileManager.default.removeItem(at: tempDailyURL)
                return false
            }

            let backupURL = dailyURL.deletingLastPathComponent()
                .appendingPathComponent(".daily-backup-\(Self.timestamp())-\(UUID().uuidString).mp4")
            try FileManager.default.moveItem(at: dailyURL, to: backupURL)
            do {
                try FileManager.default.moveItem(at: tempDailyURL, to: dailyURL)
                try? FileManager.default.removeItem(at: backupURL)
                try? FileManager.default.removeItem(at: segmentURL)
                return true
            } catch {
                if FileManager.default.fileExists(atPath: backupURL.path) {
                    try? FileManager.default.moveItem(at: backupURL, to: dailyURL)
                }
                try? FileManager.default.removeItem(at: tempDailyURL)
                return false
            }
        } catch {
            return false
        }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private static func dailyOutputURL(for date: Date = Date()) -> URL {
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "MMdd"
        let filename = "\(dayFormatter.string(from: date))_\(RecorderSettings.recordingName).mp4"
        return recordingsDirectory
            .appendingPathComponent(monthFormatter.string(from: date), isDirectory: true)
            .appendingPathComponent(filename)
    }

    static func renameExistingRecordings(from oldName: String, to newName: String) {
        let targetName = RecorderSettings.sanitizedRecordingName(newName)
        guard let months = try? FileManager.default.contentsOfDirectory(
            at: recordingsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for monthURL in months {
            let values = try? monthURL.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: monthURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for fileURL in files where fileURL.pathExtension.lowercased() == "mp4" {
                guard let day = recordingDay(from: fileURL.deletingPathExtension().lastPathComponent) else { continue }
                let newURL = monthURL.appendingPathComponent("\(day)_\(targetName).mp4")
                guard fileURL.path != newURL.path else { continue }
                if FileManager.default.fileExists(atPath: newURL.path) {
                    _ = mergeVideoFile(fileURL, into: newURL)
                    continue
                }
                try? FileManager.default.moveItem(at: fileURL, to: newURL)
            }
        }
    }

    private static func mergeVideoFile(_ sourceURL: URL, into targetURL: URL) -> Bool {
        let directory = targetURL.deletingLastPathComponent()
        let listURL = directory.appendingPathComponent(".rename-merge-\(timestamp())-\(UUID().uuidString).txt")
        let tempURL = directory.appendingPathComponent(".rename-merge-\(timestamp())-\(UUID().uuidString).mp4")
        let backupURL = directory.appendingPathComponent(".rename-backup-\(timestamp())-\(UUID().uuidString).mp4")
        let concatList = [
            "file '\(concatEscapedPath(targetURL.path))'",
            "file '\(concatEscapedPath(sourceURL.path))'"
        ].joined(separator: "\n") + "\n"

        do {
            try concatList.write(to: listURL, atomically: true, encoding: .utf8)
            let ffmpeg = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".local/bin/ffmpeg")
            let process = Process()
            process.executableURL = ffmpeg
            process.arguments = [
                "-hide_banner",
                "-loglevel", "error",
                "-f", "concat",
                "-safe", "0",
                "-i", listURL.path,
                "-vf", "scale=960:600:force_original_aspect_ratio=decrease,pad=960:600:(ow-iw)/2:(oh-ih)/2,fps=1",
                "-c:v", "libx264",
                "-preset", "veryfast",
                "-tune", "stillimage",
                "-pix_fmt", "yuv420p",
                "-an",
                "-movflags", "+faststart",
                tempURL.path,
                "-y"
            ]
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                try? FileManager.default.removeItem(at: listURL)
                try? FileManager.default.removeItem(at: tempURL)
                return false
            }

            try FileManager.default.moveItem(at: targetURL, to: backupURL)
            do {
                try FileManager.default.moveItem(at: tempURL, to: targetURL)
                try? FileManager.default.removeItem(at: backupURL)
                try? FileManager.default.removeItem(at: sourceURL)
                try? FileManager.default.removeItem(at: listURL)
                return true
            } catch {
                if FileManager.default.fileExists(atPath: backupURL.path) {
                    try? FileManager.default.moveItem(at: backupURL, to: targetURL)
                }
                try? FileManager.default.removeItem(at: tempURL)
                try? FileManager.default.removeItem(at: listURL)
                return false
            }
        } catch {
            try? FileManager.default.removeItem(at: listURL)
            try? FileManager.default.removeItem(at: tempURL)
            return false
        }
    }

    static func rewriteRecordingLogFileNames(to newName: String) {
        let targetName = RecorderSettings.sanitizedRecordingName(newName)
        guard let months = try? FileManager.default.contentsOfDirectory(
            at: recordingsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for monthURL in months {
            let values = try? monthURL.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            let month = monthURL.lastPathComponent
            guard month.range(of: #"^\d{4}-\d{2}$"#, options: .regularExpression) != nil else { continue }

            let logURL = monthURL.appendingPathComponent("録画区間ログ-\(month).txt")
            guard let content = try? String(contentsOf: logURL, encoding: .utf8) else { continue }

            let rewrittenLines = content.split(separator: "\n", omittingEmptySubsequences: false).map { rawLine -> String in
                let line = String(rawLine)
                let columns = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                guard columns.count >= 4 else { return line }
                let dayText = String(columns[0].prefix(10))
                guard dayText.count == 10 else { return line }
                let monthDay = dayText
                    .replacingOccurrences(of: "-", with: "")
                    .suffix(4)
                guard monthDay.count == 4 else { return line }

                var updatedColumns = columns
                updatedColumns[3] = "\(monthDay)_\(targetName).mp4"
                return updatedColumns.joined(separator: "\t")
            }

            try? rewrittenLines.joined(separator: "\n").write(to: logURL, atomically: true, encoding: .utf8)
        }
    }

    private static func recordingDay(from basename: String) -> String? {
        if basename.count >= 5,
           basename[basename.index(basename.startIndex, offsetBy: 4)] == "_" {
            let day = String(basename.prefix(4))
            return day.allSatisfy(\.isNumber) ? day : nil
        }

        if basename.hasPrefix("daily-"), basename.count >= 14 {
            let start = basename.index(basename.startIndex, offsetBy: 10)
            let end = basename.index(basename.startIndex, offsetBy: 14)
            let day = String(basename[start..<end])
            return day.allSatisfy(\.isNumber) ? day : nil
        }

        return nil
    }

    private static func monthlyLogURL(for date: Date = Date()) -> URL {
        monthlyDirectory(for: date)
            .appendingPathComponent("録画区間ログ-\(monthString(from: date)).txt")
    }

    private static func legacyMonthlyLogURL(for date: Date = Date()) -> URL {
        monthlyDirectory(for: date)
            .appendingPathComponent("recording-log-\(monthString(from: date)).txt")
    }

    private static func dailyTotalLogURL(for date: Date = Date()) -> URL {
        monthlyDirectory(for: date)
            .appendingPathComponent("日別合計作業時間-\(monthString(from: date)).txt")
    }

    private static func legacyDailyTotalLogURL(for date: Date = Date()) -> URL {
        monthlyDirectory(for: date)
            .appendingPathComponent("daily-total-\(monthString(from: date)).txt")
    }

    private static func monthlyDirectory(for date: Date = Date()) -> URL {
        recordingsDirectory
            .appendingPathComponent(monthString(from: date), isDirectory: true)
    }

    private static func monthString(from date: Date = Date()) -> String {
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        return monthFormatter.string(from: date)
    }

    static func migrateRecordingsDirectory() {
        guard FileManager.default.fileExists(atPath: legacyRecordingsDirectory.path) else { return }

        do {
            try FileManager.default.createDirectory(at: recordingsDirectory.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: recordingsDirectory.path) {
                try FileManager.default.moveItem(at: legacyRecordingsDirectory, to: recordingsDirectory)
                return
            }

            guard let items = try? FileManager.default.contentsOfDirectory(
                at: legacyRecordingsDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            ) else { return }

            for itemURL in items {
                let destinationURL = recordingsDirectory.appendingPathComponent(itemURL.lastPathComponent)
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    mergeDirectoryContents(from: itemURL, to: destinationURL)
                } else {
                    try? FileManager.default.moveItem(at: itemURL, to: destinationURL)
                }
            }

            try? FileManager.default.removeItem(at: legacyRecordingsDirectory)
        } catch {
            return
        }
    }

    static func recoverOrphanedFrameDirectories() {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: recordingsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else { return }

        for itemURL in items where itemURL.lastPathComponent.hasPrefix(".frames-") {
            let values = try? itemURL.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            recoverFrameDirectory(itemURL)
        }
    }

    private static func recoverFrameDirectory(_ frameDirectory: URL) {
        let frameNames = ((try? FileManager.default.contentsOfDirectory(atPath: frameDirectory.path)) ?? [])
            .filter { $0.hasSuffix(".jpg") }
            .sorted()
        guard !frameNames.isEmpty else {
            try? FileManager.default.removeItem(at: frameDirectory)
            return
        }

        let recoveredAt = Date()
        let startedAt = dateFromFrameDirectoryName(frameDirectory.lastPathComponent) ?? recoveredAt
        let endedAt = startedAt.addingTimeInterval(TimeInterval(max(1, frameNames.count)))
        let outputURL = frameDirectory.appendingPathComponent("recovered-\(timestamp()).mp4")
        let ffmpeg = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin/ffmpeg")
        let process = Process()
        process.executableURL = ffmpeg
        process.arguments = [
            "-hide_banner",
            "-loglevel", "error",
            "-framerate", "1",
            "-i", frameDirectory.appendingPathComponent("frame-%06d.jpg").path,
            "-vf", "scale=960:600:force_original_aspect_ratio=decrease,pad=960:600:(ow-iw)/2:(oh-ih)/2",
            "-c:v", "libx264",
            "-preset", "veryfast",
            "-tune", "stillimage",
            "-pix_fmt", "yuv420p",
            "-an",
            "-movflags", "+faststart",
            outputURL.path,
            "-y"
        ]

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  appendSegmentToDailyFile(segmentURL: outputURL, frameDirectory: frameDirectory, date: endedAt) else {
                return
            }
            appendRecordingLog(startedAt: startedAt, endedAt: endedAt, outputURL: dailyOutputURL(for: endedAt))
            updateDailyTotalLog(for: endedAt)
            try? FileManager.default.removeItem(at: frameDirectory)
        } catch {
            return
        }
    }

    private static func dateFromFrameDirectoryName(_ name: String) -> Date? {
        guard name.hasPrefix(".frames-") else { return nil }
        let timestampText = String(name.dropFirst(".frames-".count).prefix(15))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.date(from: timestampText)
    }

    private static func mergeDirectoryContents(from sourceURL: URL, to destinationURL: URL) {
        let sourceValues = try? sourceURL.resourceValues(forKeys: [.isDirectoryKey])
        let destinationValues = try? destinationURL.resourceValues(forKeys: [.isDirectoryKey])
        guard sourceValues?.isDirectory == true, destinationValues?.isDirectory == true else { return }
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else { return }

        for childURL in children {
            let childDestinationURL = destinationURL.appendingPathComponent(childURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: childDestinationURL.path) {
                mergeDirectoryContents(from: childURL, to: childDestinationURL)
            } else {
                try? FileManager.default.moveItem(at: childURL, to: childDestinationURL)
            }
        }

        try? FileManager.default.removeItem(at: sourceURL)
    }

    static func migrateSavedTextFileNames() {
        guard let months = try? FileManager.default.contentsOfDirectory(
            at: recordingsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for monthURL in months {
            let values = try? monthURL.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            let month = monthURL.lastPathComponent
            guard month.range(of: #"^\d{4}-\d{2}$"#, options: .regularExpression) != nil else { continue }

            migrateTextFile(
                from: monthURL.appendingPathComponent("recording-log-\(month).txt"),
                to: monthURL.appendingPathComponent("録画区間ログ-\(month).txt"),
                header: "開始\t終了\t時間\tファイル"
            )
            migrateTextFile(
                from: monthURL.appendingPathComponent("daily-total-\(month).txt"),
                to: monthURL.appendingPathComponent("日別合計作業時間-\(month).txt"),
                header: "日付\t合計作業時間\t合計秒数\t記録回数"
            )
        }
    }

    private static func migrateTextFile(from oldURL: URL, to newURL: URL, header: String) {
        guard FileManager.default.fileExists(atPath: oldURL.path) else { return }

        do {
            try FileManager.default.createDirectory(at: newURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            if !FileManager.default.fileExists(atPath: newURL.path) {
                try FileManager.default.moveItem(at: oldURL, to: newURL)
                return
            }

            let oldLines = (try? String(contentsOf: oldURL, encoding: .utf8))?
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init) ?? []
            let existingText = (try? String(contentsOf: newURL, encoding: .utf8)) ?? ""
            var existingLines = Set(existingText.split(separator: "\n").map(String.init))
            var mergedLines = existingText.trimmingCharacters(in: .newlines)

            if mergedLines.isEmpty {
                mergedLines = header
                existingLines.insert(header)
            }

            for line in oldLines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed != header, !existingLines.contains(line) else { continue }
                mergedLines += "\n" + line
                existingLines.insert(line)
            }

            try (mergedLines + "\n").write(to: newURL, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(at: oldURL)
        } catch {
            return
        }
    }

    private static func appendRecordingLog(startedAt: Date, endedAt: Date, outputURL: URL) {
        let logURL = monthlyLogURL(for: endedAt)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let duration = max(0, Int(endedAt.timeIntervalSince(startedAt).rounded()))
        let line = [
            formatter.string(from: startedAt),
            formatter.string(from: endedAt),
            "\(duration)秒",
            outputURL.lastPathComponent
        ].joined(separator: "\t") + "\n"

        do {
            try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: logURL.path) {
                let header = "開始\t終了\t時間\tファイル\n"
                try header.write(to: logURL, atomically: true, encoding: .utf8)
            }
            if let handle = try? FileHandle(forWritingTo: logURL) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(line.utf8))
                try? handle.close()
            }
        } catch {
            return
        }
    }

    static func updateDailyTotalLog(for date: Date = Date()) {
        let sourceURL = monthlyLogURL(for: date)
        let outputURL = dailyTotalLogURL(for: date)
        let fallbackSourceURL = legacyMonthlyLogURL(for: date)
        let content = (try? String(contentsOf: sourceURL, encoding: .utf8))
            ?? (try? String(contentsOf: fallbackSourceURL, encoding: .utf8))
        guard let content else { return }

        var totals: [String: (seconds: Int, count: Int)] = [:]
        for line in content.split(separator: "\n").dropFirst() {
            let columns = line.split(separator: "\t").map(String.init)
            guard columns.count >= 3 else { continue }
            let day = String(columns[0].prefix(10))
            let durationText = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let numericText: String
            if durationText.hasSuffix("秒") {
                numericText = String(durationText.dropLast())
            } else if durationText.hasSuffix("s") {
                numericText = String(durationText.dropLast())
            } else {
                numericText = durationText
            }
            guard let seconds = Int(numericText) else { continue }
            let current = totals[day] ?? (0, 0)
            totals[day] = (current.seconds + seconds, current.count + 1)
        }

        let lines = totals.keys.sorted().map { day -> String in
            let value = totals[day] ?? (0, 0)
            return [
                day,
                formattedDuration(value.seconds),
                "\(value.seconds)秒",
                "\(value.count)"
            ].joined(separator: "\t")
        }
        let output = "日付\t合計作業時間\t合計秒数\t記録回数\n" + lines.joined(separator: "\n") + "\n"

        do {
            try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try output.write(to: outputURL, atomically: true, encoding: .utf8)
        } catch {
            return
        }
    }

    static func dailyWorkSeconds(for date: Date = Date()) -> Int {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let targetDay = dayFormatter.string(from: date)
        return workSeconds(in: monthlyLogURL(for: date)) { startedAt in
            startedAt.hasPrefix(targetDay)
        }
    }

    static func monthlyScore(for date: Date = Date(), includingCurrentStartedAt startedAt: Date? = nil) -> (seconds: Int, earnedYen: Int) {
        var seconds = workSeconds(in: monthlyLogURL(for: date)) { _ in true }
        if let startedAt,
           Calendar.current.isDate(startedAt, equalTo: date, toGranularity: .month) {
            seconds += max(0, Int(Date().timeIntervalSince(startedAt)))
        }
        let earned = Int((Double(seconds) / 3600.0 * Double(RecorderSettings.hourlyRate)).rounded())
        return (seconds, earned)
    }

    private static func workSeconds(in logURL: URL, matching include: (String) -> Bool) -> Int {
        guard let content = try? String(contentsOf: logURL, encoding: .utf8) else { return 0 }
        return content.split(separator: "\n").dropFirst().reduce(0) { total, row in
            let columns = row.split(separator: "\t").map(String.init)
            guard columns.count >= 3, include(columns[0]) else { return total }
            return total + parsedDurationSeconds(columns[2])
        }
    }

    private static func parsedDurationSeconds(_ text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("秒") {
            return Int(trimmed.dropLast()) ?? 0
        }
        if trimmed.hasSuffix("s") {
            return Int(trimmed.dropLast()) ?? 0
        }
        return Int(trimmed) ?? 0
    }

    private static func formattedDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        if hours > 0 {
            return "\(hours)時間\(minutes)分\(remainingSeconds)秒"
        }
        if minutes > 0 {
            return "\(minutes)分\(remainingSeconds)秒"
        }
        return "\(remainingSeconds)秒"
    }

    private static func concatEscapedPath(_ path: String) -> String {
        path.replacingOccurrences(of: "'", with: "'\\''")
    }

    private static func displayBoundsContainingMouse() -> CGRect? {
        guard let mouse = CGEvent(source: nil)?.location else {
            return CGDisplayBounds(CGMainDisplayID())
        }

        var displayCount: UInt32 = 0
        var display = CGDirectDisplayID()
        let result = CGGetDisplaysWithPoint(mouse, 1, &display, &displayCount)
        guard result == .success, displayCount > 0 else {
            return CGDisplayBounds(CGMainDisplayID())
        }
        return CGDisplayBounds(display)
    }

    private static func rectangleArgument(_ rectangle: CGRect) -> String {
        let x = Int(rectangle.origin.x.rounded())
        let y = Int(rectangle.origin.y.rounded())
        let width = Int(rectangle.width.rounded())
        let height = Int(rectangle.height.rounded())
        return "\(x),\(y),\(width),\(height)"
    }
}

enum RecorderError: LocalizedError {
    case noDisplay
    case cannotWrite

    var errorDescription: String? {
        switch self {
        case .noDisplay:
            return "録画できる画面が見つかりませんでした。"
        case .cannotWrite:
            return "動画の書き込みを開始できませんでした。"
        }
    }
}

if CommandLine.arguments.count >= 3, CommandLine.arguments[1] == "--command" {
    let appSupportDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library", isDirectory: true)
        .appendingPathComponent("Application Support", isDirectory: true)
        .appendingPathComponent("OneFPSRecorder", isDirectory: true)
    let commandFile = appSupportDirectory.appendingPathComponent("command.txt")
    try? FileManager.default.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
    let line = "\(Date().timeIntervalSince1970) \(CommandLine.arguments[2])\n"
    if FileManager.default.fileExists(atPath: commandFile.path),
       let handle = try? FileHandle(forWritingTo: commandFile) {
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(line.utf8))
        try? handle.close()
    } else {
        try? Data(line.utf8).write(to: commandFile)
    }
    Thread.sleep(forTimeInterval: 0.6)
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
