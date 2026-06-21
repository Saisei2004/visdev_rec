import AppKit
import CoreGraphics
import Darwin

enum RecorderSettings {
    private static let defaults = UserDefaults.standard
    private static let recordingNameKey = "recordingName"
    private static let showOverlayKey = "showRecordingOverlay"
    private static let showPauseOverlayKey = "showPauseOverlay"
    private static let showMenuBarStatusKey = "showMenuBarStatus"
    private static let compactMenuBarIconKey = "compactMenuBarIcon"
    private static let showReportMenuKey = "showReportMenu"
    private static let showMonthlyScoreKey = "showMonthlyScore"
    private static let hourlyRateKey = "hourlyRate"
    private static let monthlyGoalKey = "monthlyGoal"
    private static let monthlyScoreResetAtPrefix = "monthlyScoreResetAt."
    private static let glowWhenGoalReachedKey = "glowWhenGoalReached"
    private static let pauseOnSleepKey = "pauseOnSleep"
    private static let pauseOnMouseIdleKey = "pauseOnMouseIdle"
    private static let mouseIdleMinutesKey = "mouseIdleMinutes"
    private static let startMessageIndexKey = "startMessageIndex"
    private static let stopMessageIndexKey = "stopMessageIndex"
    private static let reporterNameKey = "reporterName"
    private static let driveFolderURLKey = "driveFolderURL"
    private static let videoDriveFolderURLKey = "videoDriveFolderURL"
    private static let defaultWorkPlanKey = "defaultWorkPlan"
    private static let defaultWorkContentKey = "defaultWorkContent"
    private static let defaultNextTaskKey = "defaultNextTask"
    private static let defaultReportStatusKey = "defaultReportStatus"
    private static let defaultReportMessageKey = "defaultReportMessage"
    private static let reportTemplatePathKey = "reportTemplatePath"
    private static let defaultDriveFolderURL = ""
    private static let defaultVideoDriveFolderURL = ""

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

    static var showPauseOverlay: Bool {
        get {
            defaults.synchronize()
            if defaults.object(forKey: showPauseOverlayKey) == nil {
                return true
            }
            return defaults.bool(forKey: showPauseOverlayKey)
        }
        set {
            defaults.set(newValue, forKey: showPauseOverlayKey)
        }
    }

    static var showMenuBarStatus: Bool {
        get {
            defaults.synchronize()
            if defaults.object(forKey: showMenuBarStatusKey) == nil {
                return true
            }
            return defaults.bool(forKey: showMenuBarStatusKey)
        }
        set { defaults.set(newValue, forKey: showMenuBarStatusKey) }
    }

    static var compactMenuBarIcon: Bool {
        get {
            defaults.synchronize()
            return defaults.bool(forKey: compactMenuBarIconKey)
        }
        set { defaults.set(newValue, forKey: compactMenuBarIconKey) }
    }

    static var showReportMenu: Bool {
        get {
            defaults.synchronize()
            return defaults.bool(forKey: showReportMenuKey)
        }
        set { defaults.set(newValue, forKey: showReportMenuKey) }
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
            if defaults.object(forKey: monthlyGoalKey) == nil {
                return 100000
            }
            return max(0, defaults.integer(forKey: monthlyGoalKey))
        }
        set { defaults.set(max(0, newValue), forKey: monthlyGoalKey) }
    }

    static func monthlyScoreResetAt(for date: Date = Date()) -> Date? {
        defaults.synchronize()
        let key = monthlyScoreResetAtPrefix + monthKey(from: date)
        guard let text = defaults.string(forKey: key) else { return nil }
        return ISO8601DateFormatter().date(from: text)
    }

    static func resetMonthlyScore(for date: Date = Date(), at resetAt: Date = Date()) {
        let key = monthlyScoreResetAtPrefix + monthKey(from: date)
        defaults.set(ISO8601DateFormatter().string(from: resetAt), forKey: key)
        defaults.synchronize()
    }

    private static func monthKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    static var glowWhenGoalReached: Bool {
        get {
            defaults.synchronize()
            return defaults.bool(forKey: glowWhenGoalReachedKey)
        }
        set { defaults.set(newValue, forKey: glowWhenGoalReachedKey) }
    }

    static var pauseOnSleep: Bool {
        get {
            defaults.synchronize()
            if defaults.object(forKey: pauseOnSleepKey) == nil {
                return true
            }
            return defaults.bool(forKey: pauseOnSleepKey)
        }
        set { defaults.set(newValue, forKey: pauseOnSleepKey) }
    }

    static var pauseOnMouseIdle: Bool {
        get {
            defaults.synchronize()
            return defaults.bool(forKey: pauseOnMouseIdleKey)
        }
        set { defaults.set(newValue, forKey: pauseOnMouseIdleKey) }
    }

    static var mouseIdleMinutes: Int {
        get {
            defaults.synchronize()
            let value = defaults.integer(forKey: mouseIdleMinutesKey)
            return value > 0 ? value : 5
        }
        set { defaults.set(min(max(1, newValue), 180), forKey: mouseIdleMinutesKey) }
    }

    static func nextStartMessageIndex(modulo: Int) -> Int {
        nextIndex(forKey: startMessageIndexKey, modulo: modulo)
    }

    static func nextStopMessageIndex(modulo: Int) -> Int {
        nextIndex(forKey: stopMessageIndexKey, modulo: modulo)
    }

    static var reporterName: String {
        get {
            defaults.synchronize()
            let saved = defaults.string(forKey: reporterNameKey) ?? currentUserDisplayName()
            let trimmed = saved.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? currentUserDisplayName() : trimmed
        }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: reporterNameKey) }
    }

    static var driveFolderURL: String {
        get {
            defaults.synchronize()
            let saved = defaults.string(forKey: driveFolderURLKey) ?? defaultDriveFolderURL
            return saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultDriveFolderURL : saved
        }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: driveFolderURLKey) }
    }

    static var videoDriveFolderURL: String {
        get {
            defaults.synchronize()
            let saved = defaults.string(forKey: videoDriveFolderURLKey) ?? defaultVideoDriveFolderURL
            return saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultVideoDriveFolderURL : saved
        }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: videoDriveFolderURLKey) }
    }

    static var defaultWorkPlan: String {
        get { savedText(forKey: defaultWorkPlanKey, fallback: "Visitasの開発") }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: defaultWorkPlanKey) }
    }

    static var defaultWorkContent: String {
        get { savedText(forKey: defaultWorkContentKey, fallback: "") }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: defaultWorkContentKey) }
    }

    static var defaultNextTask: String {
        get { savedText(forKey: defaultNextTaskKey, fallback: "") }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: defaultNextTaskKey) }
    }

    static var defaultReportStatus: String {
        get { savedText(forKey: defaultReportStatusKey, fallback: "順調") }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: defaultReportStatusKey) }
    }

    static var defaultReportMessage: String {
        get { savedText(forKey: defaultReportMessageKey, fallback: "") }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: defaultReportMessageKey) }
    }

    static var reportTemplatePath: String {
        get {
            defaults.synchronize()
            let fallback = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Downloads")
                .appendingPathComponent("報告書（6月分）.docx")
                .path
            let saved = defaults.string(forKey: reportTemplatePathKey) ?? fallback
            let trimmed = saved.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? fallback : trimmed
        }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: reportTemplatePathKey) }
    }

    private static func savedText(forKey key: String, fallback: String) -> String {
        defaults.synchronize()
        let saved = defaults.string(forKey: key) ?? fallback
        let trimmed = saved.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func currentUserDisplayName() -> String {
        let fullName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        if !fullName.isEmpty {
            return fullName
        }
        let loginName = NSUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        return loginName.isEmpty ? "担当者" : loginName
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

struct ReportSubmissionForm {
    var date: Date
    var reporter: String
    var workPlan: String
    var workContent: String
    var nextTask: String
    var status: String
    var message: String
    var videoLink: String
    var driveFolderURL: String
    var videoDriveFolderURL: String
}

struct ReportSubmissionResult {
    var reportURL: URL
    var submittedVideoURL: URL
    var hours: Int
}

struct StoredReportEntry: Codable {
    var date: String
    var displayDate: String
    var reporter: String
    var hours: Int
    var workPlan: String
    var workContent: String
    var videoLink: String
    var videoFileName: String
    var nextTask: String
    var status: String
    var message: String
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
    private var reportMenuItem: NSMenuItem?
    private var overlay: RecordingOverlay!
    private var recorder: OneFPSRecorder!
    private var lastToggleAt = Date.distantPast
    private var commandTimer: DispatchSourceTimer?
    private var lastCommandLine = ""
    private var lockFileHandle: FileHandle?
    private var settingsWindowController: SettingsWindowController?
    private var reportWindowController: ReportSubmissionWindowController?
    private var overlayMessage = ""
    private var manualReadyOverlayVisible = false
    private var activityTimer: DispatchSourceTimer?
    private var lastMouseLocation: CGPoint?
    private var lastMouseMovedAt = Date()
    private var autoPausedBySleep = false
    private var autoPausedByMouseIdle = false
    private let launchedInBackground = CommandLine.arguments.contains("--background")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        guard acquireSingleInstanceLock() else {
            Self.sendCommand("settings")
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
        OneFPSRecorder.migrateToDailyDirectories()
        OneFPSRecorder.renameExistingRecordings(from: "", to: RecorderSettings.recordingName)
        OneFPSRecorder.rewriteRecordingLogFileNames(to: RecorderSettings.recordingName)
        OneFPSRecorder.reconcileDailyVideosWithLogs()
        OneFPSRecorder.syncAllDerivedLogs()

        setupStatusItem()
        overlay = RecordingOverlay(
            startAction: { [weak self] in
                self?.startRecordingFromOverlay()
            },
            stopAction: { [weak self] in
                self?.stopRecordingFromOverlay()
            },
            resumeAction: { [weak self] in
                self?.resumeRecordingFromPauseOverlay()
            }
        )
        setupCommandNotifications()
        setupAutomaticPauseHandling()
        applyStatus(.idle)
        log("OneFPSRecorder launched")
        if !launchedInBackground {
            DispatchQueue.main.async { [weak self] in
                self?.openSettings()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if recorder.isRecording {
            recorder.stop()
        }
        commandTimer?.cancel()
        activityTimer?.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        if let lockFileHandle {
            flock(lockFileHandle.fileDescriptor, LOCK_UN)
            try? lockFileHandle.close()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: RecorderSettings.compactMenuBarIcon ? NSStatusItem.squareLength : NSStatusItem.variableLength
        )
        let menu = NSMenu()
        let toggleItem = NSMenuItem(title: "録画開始", action: #selector(toggleRecording), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let folderItem = NSMenuItem(title: "保存フォルダを開く", action: #selector(openFolder), keyEquivalent: "")
        folderItem.target = self
        menu.addItem(folderItem)

        let reportItem = NSMenuItem(title: "業務報告を提出...", action: #selector(openReportSubmission), keyEquivalent: "")
        reportItem.target = self
        reportItem.isHidden = !RecorderSettings.showReportMenu
        reportMenuItem = reportItem
        menu.addItem(reportItem)

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
        refreshMenuVisibility()
        switch state {
        case .idle:
            setMenuBarDisplay(
                title: RecorderSettings.showMenuBarStatus && isAutomaticallyPaused ? "1FPS 一時停止" : "1FPS",
                symbolName: isAutomaticallyPaused ? "pause.circle.fill" : "record.circle",
                tint: isAutomaticallyPaused ? .systemYellow : nil
            )
            statusItem.menu?.item(at: 0)?.title = "録画開始"
            statusItem.menu?.item(at: 0)?.isEnabled = true
            if isAutomaticallyPaused, RecorderSettings.showPauseOverlay {
                overlay.showPaused(message: automaticPauseMessage)
            } else if manualReadyOverlayVisible, RecorderSettings.showOverlay {
                overlay.showReady(message: "ここから録画できます")
            } else {
                overlay.hide()
            }
        case .idleSaving:
            setMenuBarDisplay(
                title: RecorderSettings.showMenuBarStatus ? "1FPS 保存中" : "1FPS",
                symbolName: "tray.and.arrow.down.fill",
                tint: .systemOrange
            )
            statusItem.menu?.item(at: 0)?.title = "録画開始"
            statusItem.menu?.item(at: 0)?.isEnabled = true
            if isAutomaticallyPaused, RecorderSettings.showPauseOverlay {
                overlay.showSaving(message: "一時停止を保存中")
            } else if RecorderSettings.showOverlay {
                overlay.showSaving(message: overlayMessage)
            } else {
                overlay.hide()
            }
        case .recording(let startedAt):
            let elapsed = Int(Date().timeIntervalSince(startedAt))
            let score = OneFPSRecorder.monthlyScore(includingCurrentStartedAt: startedAt)
            let scoreText = RecorderSettings.showMonthlyScore ? " \(Self.currency(score.earnedYen))" : ""
            setMenuBarDisplay(
                title: RecorderSettings.showMenuBarStatus
                    ? String(format: "録画中 1FPS %02d:%02d%@", elapsed / 60, elapsed % 60, scoreText)
                    : "1FPS",
                symbolName: "record.circle.fill",
                tint: .systemRed
            )
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
            setMenuBarDisplay(
                title: RecorderSettings.showMenuBarStatus ? "1FPS 保存中" : "1FPS",
                symbolName: "tray.and.arrow.down.fill",
                tint: .systemOrange
            )
            statusItem.menu?.item(at: 0)?.title = "保存中..."
            statusItem.menu?.item(at: 0)?.isEnabled = false
            if isAutomaticallyPaused, RecorderSettings.showPauseOverlay {
                overlay.showSaving(message: "一時停止を保存中")
            } else if RecorderSettings.showOverlay {
                overlay.showSaving(message: overlayMessage)
            } else {
                overlay.hide()
            }
        case .error(let message):
            setMenuBarDisplay(title: "1FPS エラー", symbolName: "exclamationmark.circle.fill", tint: .systemRed)
            statusItem.menu?.item(at: 0)?.title = "録画開始"
            statusItem.menu?.item(at: 0)?.isEnabled = true
            overlay.hide()
            showAlert(message)
        }
    }

    private func refreshMenuVisibility() {
        reportMenuItem?.isHidden = !RecorderSettings.showReportMenu
    }

    private func setMenuBarDisplay(title: String, symbolName: String, tint: NSColor?) {
        guard let button = statusItem.button else { return }
        statusItem.length = RecorderSettings.compactMenuBarIcon ? NSStatusItem.squareLength : NSStatusItem.variableLength
        if RecorderSettings.compactMenuBarIcon {
            button.title = ""
            button.imagePosition = .imageOnly
            if tint == nil, let icon = appMenuBarIcon(accessibilityDescription: title) {
                button.image = icon
            } else if let symbol = coloredMenuBarSymbol(symbolName: symbolName, tint: tint ?? .systemRed, accessibilityDescription: title) {
                button.image = symbol
            } else {
                button.image = nil
                button.title = "●"
            }
            button.contentTintColor = nil
            button.toolTip = title
        } else {
            button.image = nil
            button.title = title
            button.contentTintColor = nil
            button.toolTip = nil
        }
    }

    private func appMenuBarIcon(accessibilityDescription: String) -> NSImage? {
        let resourceNames = ["AppIcon.png", "AppIcon.icns"]
        for resourceName in resourceNames {
            guard let resourceURL = Bundle.main.resourceURL?.appendingPathComponent(resourceName),
                  let source = NSImage(contentsOf: resourceURL) else {
                continue
            }
            let image = NSImage(size: NSSize(width: 18, height: 18))
            image.lockFocus()
            source.draw(
                in: NSRect(x: 1, y: 1, width: 16, height: 16),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
            image.unlockFocus()
            image.isTemplate = false
            image.accessibilityDescription = accessibilityDescription
            return image
        }
        return nil
    }

    private func coloredMenuBarSymbol(symbolName: String, tint: NSColor, accessibilityDescription: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)?
            .withSymbolConfiguration(configuration) else {
            return nil
        }
        symbol.isTemplate = true

        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        tint.set()
        symbol.draw(
            in: NSRect(x: 1, y: 1, width: 16, height: 16),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        image.unlockFocus()
        image.isTemplate = false
        image.accessibilityDescription = accessibilityDescription
        return image
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
        manualReadyOverlayVisible = false
        if recorder.isRecording {
            autoPausedBySleep = false
            autoPausedByMouseIdle = false
            overlayMessage = Self.stopMessage()
            recorder.stop()
        } else {
            autoPausedBySleep = false
            autoPausedByMouseIdle = false
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
        manualReadyOverlayVisible = false
        autoPausedBySleep = false
        autoPausedByMouseIdle = false
        log("Overlay stop requested")
        overlayMessage = Self.stopMessage()
        recorder.stop()
    }

    private func startRecordingFromOverlay() {
        guard !recorder.isRecording else { return }
        manualReadyOverlayVisible = false
        autoPausedBySleep = false
        autoPausedByMouseIdle = false
        log("Overlay start requested")
        overlayMessage = Self.startMessage()
        Task {
            do {
                try await recorder.start()
            } catch {
                log("Overlay start failed: \(error.localizedDescription)")
                await MainActor.run {
                    applyStatus(.error(error.localizedDescription))
                }
            }
        }
    }

    private func resumeRecordingFromPauseOverlay() {
        guard isAutomaticallyPaused else { return }
        log("Pause overlay resume requested")
        autoPausedBySleep = false
        autoPausedByMouseIdle = false
        overlayMessage = Self.startMessage()
        startRecordingAfterAutomaticPause()
    }

    private var isAutomaticallyPaused: Bool {
        autoPausedBySleep || autoPausedByMouseIdle
    }

    private var automaticPauseMessage: String {
        if autoPausedBySleep {
            return "スリープを検知して一時停止しました"
        }
        if autoPausedByMouseIdle {
            return "無操作を検知して一時停止しました"
        }
        return "一時停止しました"
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
        case "showOverlay":
            RecorderSettings.showOverlay = true
            if recorder.isRecording, let startedAt = recorder.currentStartedAt {
                manualReadyOverlayVisible = false
                applyStatus(.recording(startedAt))
                overlay.revealOnMainDisplay()
            } else {
                manualReadyOverlayVisible = true
                overlay.showReady(message: "ここから録画できます")
                overlay.revealOnMainDisplay()
            }
        case "refreshSettings":
            if recorder.isRecording, let startedAt = recorder.currentStartedAt {
                applyStatus(.recording(startedAt))
            } else {
                applyStatus(recorder.isEncoding ? .idleSaving : .idle)
            }
        case "toggle":
            toggleRecording()
        default:
            break
        }
    }

    private func setupAutomaticPauseHandling() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        lastMouseLocation = currentMouseLocation()
        lastMouseMovedAt = Date()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0, leeway: .milliseconds(200))
        timer.setEventHandler { [weak self] in
            self?.checkMouseActivity()
        }
        activityTimer = timer
        timer.resume()
    }

    @objc private func workspaceWillSleep() {
        guard RecorderSettings.pauseOnSleep, recorder.isRecording else { return }
        log("Auto pause before sleep")
        autoPausedBySleep = true
        overlayMessage = "スリープのため一時停止"
        recorder.stop()
    }

    @objc private func workspaceDidWake() {
        guard autoPausedBySleep else { return }
        log("Wake detected while automatically paused")
        applyStatus(.idle)
    }

    private func checkMouseActivity() {
        guard let currentLocation = currentMouseLocation() else { return }
        defer { lastMouseLocation = currentLocation }

        if let lastMouseLocation,
           hypot(currentLocation.x - lastMouseLocation.x, currentLocation.y - lastMouseLocation.y) >= 2 {
            lastMouseMovedAt = Date()
            if autoPausedByMouseIdle {
                applyStatus(.idle)
            }
            return
        }

        guard RecorderSettings.pauseOnMouseIdle, recorder.isRecording else { return }
        let idleSeconds = Date().timeIntervalSince(lastMouseMovedAt)
        guard idleSeconds >= TimeInterval(RecorderSettings.mouseIdleMinutes * 60) else { return }
        log("Auto pause after mouse idle: \(Int(idleSeconds))s")
        autoPausedByMouseIdle = true
        overlayMessage = "無操作のため一時停止"
        recorder.stop()
    }

    private func currentMouseLocation() -> CGPoint? {
        CGEvent(source: nil)?.location
    }

    private func startRecordingAfterAutomaticPause() {
        guard !recorder.isRecording else { return }
        Task {
            do {
                try await recorder.start()
            } catch {
                log("Auto resume failed: \(error.localizedDescription)")
                await MainActor.run {
                    applyStatus(.error(error.localizedDescription))
                }
            }
        }
    }

    @objc private func openFolder() {
        NSWorkspace.shared.open(OneFPSRecorder.recordingsDirectory)
    }

    @objc private func openReportSubmission() {
        log("Report submission requested")
        if recorder.isRecording {
            recorder.flushCurrentSegment()
        }
        reportWindowController = ReportSubmissionWindowController { [weak self] form in
            RecorderSettings.reporterName = form.reporter
            RecorderSettings.driveFolderURL = form.driveFolderURL
            RecorderSettings.defaultWorkPlan = form.workPlan
            RecorderSettings.defaultWorkContent = form.workContent
            RecorderSettings.defaultNextTask = form.nextTask
            RecorderSettings.defaultReportStatus = form.status
            RecorderSettings.defaultReportMessage = form.message
            do {
                let result = try OneFPSRecorder.submitReport(form)
                self?.showAlert("業務報告を更新しました。\n業務時間: \(result.hours)h\n\n報告: \(result.reportURL.path)\n提出動画: \(result.submittedVideoURL.path)")
                if let driveURL = URL(string: form.driveFolderURL), !form.driveFolderURL.isEmpty {
                    NSWorkspace.shared.open(driveURL)
                } else {
                    NSWorkspace.shared.open(result.submittedVideoURL.deletingLastPathComponent())
                }
            } catch {
                self?.showAlert(error.localizedDescription)
            }
        }
        reportWindowController?.showWindow(nil)
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

    private static func sendCommand(_ command: String) {
        try? FileManager.default.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
        let commandFile = appSupportDirectory.appendingPathComponent("command.txt")
        let line = "\(Date().timeIntervalSince1970) \(command)\n"
        if FileManager.default.fileExists(atPath: commandFile.path),
           let handle = try? FileHandle(forWritingTo: commandFile) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
            try? handle.close()
        } else {
            try? Data(line.utf8).write(to: commandFile)
        }
    }

}

enum RecorderState {
    case idle
    case idleSaving
    case recording(Date)
    case encoding
    case error(String)
}

final class ReportSubmissionWindowController: NSWindowController, NSWindowDelegate {
    private let dateField = NSTextField(string: ReportSubmissionWindowController.defaultDateText())
    private let reporterField = NSTextField(string: RecorderSettings.reporterName)
    private let workPlanField = NSTextField(string: RecorderSettings.defaultWorkPlan)
    private let workContentField = NSTextField(string: RecorderSettings.defaultWorkContent)
    private let nextTaskField = NSTextField(string: RecorderSettings.defaultNextTask)
    private let statusField = NSTextField(string: RecorderSettings.defaultReportStatus)
    private let messageField = NSTextField(string: RecorderSettings.defaultReportMessage)
    private let videoLinkField = NSTextField(string: "")
    private let onSubmit: (ReportSubmissionForm) -> Void

    init(onSubmit: @escaping (ReportSubmissionForm) -> Void) {
        self.onSubmit = onSubmit
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 430),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = "業務報告を提出"
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
        dateField.stringValue = Self.defaultDateText()
        reporterField.stringValue = RecorderSettings.reporterName
        workPlanField.stringValue = RecorderSettings.defaultWorkPlan
        workContentField.stringValue = RecorderSettings.defaultWorkContent
        nextTaskField.stringValue = RecorderSettings.defaultNextTask
        statusField.stringValue = RecorderSettings.defaultReportStatus
        messageField.stringValue = RecorderSettings.defaultReportMessage
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }
        let fields: [(String, NSTextField, String)] = [
            ("日付", dateField, "yyyy-MM-dd"),
            ("担当者", reporterField, ""),
            ("業務プラン", workPlanField, ""),
            ("業務内容", workContentField, ""),
            ("業務動画リンク", videoLinkField, "Drive共有リンクを取得できたら貼る"),
            ("次回までのTask", nextTaskField, ""),
            ("業務は順調ですか？", statusField, ""),
            ("Visitasへのメッセージ", messageField, "")
        ]

        var y = 360
        for (label, field, placeholder) in fields {
            let labelView = NSTextField(labelWithString: label)
            labelView.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
            labelView.frame = NSRect(x: 28, y: y + 6, width: 130, height: 20)
            field.frame = NSRect(x: 166, y: y, width: 420, height: 28)
            field.placeholderString = placeholder
            contentView.addSubview(labelView)
            contentView.addSubview(field)
            y -= 36
        }

        let destination = NSTextField(labelWithString: "提出先: 設定したDriveフォルダ。未設定の場合はローカル保存のみ")
        destination.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        destination.textColor = .secondaryLabelColor
        destination.frame = NSRect(x: 28, y: 78, width: 560, height: 18)
        contentView.addSubview(destination)

        let hint = NSTextField(labelWithString: "業務時間は録画区間ログから切り捨て1時間単位で入ります。日付を変えると過去日の上書きになります。")
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 28, y: 46, width: 560, height: 18)
        contentView.addSubview(hint)

        let cancelButton = NSButton(title: "キャンセル", target: self, action: #selector(cancelPressed))
        cancelButton.bezelStyle = .rounded
        cancelButton.frame = NSRect(x: 410, y: 16, width: 82, height: 30)
        contentView.addSubview(cancelButton)

        let submitButton = NSButton(title: "提出", target: self, action: #selector(submitPressed))
        submitButton.bezelStyle = .rounded
        submitButton.keyEquivalent = "\r"
        submitButton.frame = NSRect(x: 504, y: 16, width: 82, height: 30)
        contentView.addSubview(submitButton)
    }

    @objc private func submitPressed() {
        guard let date = Self.parseDate(dateField.stringValue) else {
            showInlineAlert("日付は yyyy-MM-dd で入力してください。")
            return
        }
        let form = ReportSubmissionForm(
            date: date,
            reporter: reporterField.stringValue,
            workPlan: workPlanField.stringValue,
            workContent: workContentField.stringValue,
            nextTask: nextTaskField.stringValue,
            status: statusField.stringValue,
            message: messageField.stringValue,
            videoLink: videoLinkField.stringValue,
            driveFolderURL: RecorderSettings.driveFolderURL,
            videoDriveFolderURL: RecorderSettings.videoDriveFolderURL
        )
        onSubmit(form)
        close()
    }

    @objc private func cancelPressed() {
        close()
    }

    private func showInlineAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "業務報告"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private static func defaultDateText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static func parseDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let nameField = NSTextField(string: RecorderSettings.recordingName)
    private let overlayCheckbox = NSButton(checkboxWithTitle: "録画中パネルを表示する", target: nil, action: nil)
    private let pauseOverlayCheckbox = NSButton(checkboxWithTitle: "一時停止パネルを表示する", target: nil, action: nil)
    private let onSave: (String, String) -> Void

    init(onSave: @escaping (String, String) -> Void) {
        self.onSave = onSave

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 220),
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
        pauseOverlayCheckbox.state = RecorderSettings.showPauseOverlay ? .on : .off
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let title = NSTextField(labelWithString: "保存名")
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        title.frame = NSRect(x: 24, y: 162, width: 80, height: 20)

        nameField.frame = NSRect(x: 104, y: 156, width: 282, height: 28)
        nameField.placeholderString = "録画"

        let hint = NSTextField(labelWithString: "ファイル名は MMDD_名前.mp4 になります。名前変更時は既存動画も更新します。")
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 104, y: 130, width: 292, height: 18)

        overlayCheckbox.target = self
        overlayCheckbox.frame = NSRect(x: 104, y: 98, width: 240, height: 22)

        pauseOverlayCheckbox.target = self
        pauseOverlayCheckbox.frame = NSRect(x: 104, y: 68, width: 240, height: 22)

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
        contentView.addSubview(pauseOverlayCheckbox)
        contentView.addSubview(saveButton)
        contentView.addSubview(cancelButton)
    }

    @objc private func savePressed() {
        let oldName = RecorderSettings.recordingName
        let newName = RecorderSettings.sanitizedRecordingName(nameField.stringValue)
        RecorderSettings.recordingName = newName
        RecorderSettings.showOverlay = overlayCheckbox.state == .on
        RecorderSettings.showPauseOverlay = pauseOverlayCheckbox.state == .on
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
    private let startAction: () -> Void
    private let stopAction: () -> Void
    private let resumeAction: () -> Void
    private var buttonMode: ButtonMode = .stop
    private var glowTimer: Timer?
    private var glowHue: CGFloat = 0

    private enum ButtonMode {
        case start
        case stop
        case resume
    }

    init(startAction: @escaping () -> Void, stopAction: @escaping () -> Void, resumeAction: @escaping () -> Void) {
        self.startAction = startAction
        self.stopAction = stopAction
        self.resumeAction = resumeAction

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

    func showReady(message: String) {
        titleLabel.stringValue = "1FPS 待機中"
        scoreLabel.stringValue = ""
        scoreLabel.isHidden = true
        messageLabel.stringValue = message
        statusDot.layer?.backgroundColor = NSColor.systemBlue.cgColor
        statusDot.layer?.shadowColor = NSColor.systemBlue.cgColor
        stopButton.isEnabled = true
        stopButton.title = "開始"
        stopButton.contentTintColor = .systemBlue
        buttonMode = .start
        setGlowEnabled(false)
        show()
    }

    func showRecording(elapsedSeconds: Int, message: String, scoreText: String?, glow: Bool) {
        titleLabel.stringValue = String(format: "録画 %02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
        scoreLabel.stringValue = scoreText ?? ""
        scoreLabel.isHidden = scoreText == nil
        messageLabel.stringValue = message
        statusDot.layer?.backgroundColor = NSColor.systemRed.cgColor
        statusDot.layer?.shadowColor = NSColor.systemRed.cgColor
        stopButton.isEnabled = true
        stopButton.title = "停止"
        stopButton.contentTintColor = .systemRed
        buttonMode = .stop
        setGlowEnabled(glow)
        show()
    }

    func showSaving(message: String) {
        titleLabel.stringValue = "保存中"
        scoreLabel.stringValue = ""
        scoreLabel.isHidden = true
        messageLabel.stringValue = message
        statusDot.layer?.backgroundColor = NSColor.systemOrange.cgColor
        statusDot.layer?.shadowColor = NSColor.systemOrange.cgColor
        stopButton.isEnabled = false
        stopButton.title = "..."
        stopButton.contentTintColor = .systemOrange
        buttonMode = .stop
        setGlowEnabled(false)
        show()
    }

    func showPaused(message: String) {
        titleLabel.stringValue = "一時停止"
        scoreLabel.stringValue = ""
        scoreLabel.isHidden = true
        messageLabel.stringValue = message
        statusDot.layer?.backgroundColor = NSColor.systemYellow.cgColor
        statusDot.layer?.shadowColor = NSColor.systemYellow.cgColor
        stopButton.isEnabled = true
        stopButton.title = "再開"
        stopButton.contentTintColor = .systemBlue
        buttonMode = .resume
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

    func revealOnMainDisplay() {
        positionOnMainDisplay(ignoringSavedOrigin: true)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
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

    private func positionOnMainDisplay(ignoringSavedOrigin: Bool = false) {
        if !ignoringSavedOrigin, let savedOrigin = savedOriginInsideAnyScreen() {
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
        switch buttonMode {
        case .start:
            startAction()
        case .stop:
            stopAction()
        case .resume:
            resumeAction()
        }
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
    private static let maxSegmentFrames = 900
    static let recordingsDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Movies", isDirectory: true)
        .appendingPathComponent("1FPS録画", isDirectory: true)
    private static let legacyRecordingsDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Movies", isDirectory: true)
        .appendingPathComponent("OneFPSRecordings", isDirectory: true)
    private static var ffmpegURL: URL { bundledExecutable("ffmpeg") }
    private static var ffprobeURL: URL { bundledExecutable("ffprobe") }

    private let status: (RecorderState) -> Void
    private var startedAt: Date?
    private var segmentStartedAt: Date?
    private var displayTimer: DispatchSourceTimer?
    private var captureTimer: DispatchSourceTimer?
    private let captureQueue = DispatchQueue(label: "onefps.capture", qos: .utility)
    private let encodeQueue = DispatchQueue(label: "onefps.encode", qos: .utility)
    private var frameDirectory: URL?
    private var outputURL: URL?
    private var frameIndex = 0
    private var firstFrameCapturedAt: Date?
    private var lastFrameCapturedAt: Date?
    private var capturedFrameCount = 0
    private var lastMonthlyScoreSyncAt = Date.distantPast
    private(set) var isEncoding = false
    private var encodingJobCount = 0

    var isRecording: Bool { startedAt != nil }
    var currentStartedAt: Date? { startedAt }

    private struct PendingSegment {
        let frameDirectory: URL
        let outputURL: URL
        let startedAt: Date
        let endedAt: Date
        let id: String
        let frameCount: Int
    }

    private struct SegmentMetadata: Codable {
        var id: String
        var startedAt: Date
        var endedAt: Date
        var outputFilename: String
        var videoAppended: Bool
        var frameCount: Int?
    }

    private static func bundledExecutable(_ name: String) -> URL {
        if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent(name),
           FileManager.default.isExecutableFile(atPath: resourceURL.path) {
            return resourceURL
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin/\(name)")
    }

    init(status: @escaping (RecorderState) -> Void) {
        self.status = status
        super.init()
    }

    func start() async throws {
        guard !isRecording else { return }
        try Self.ensureScreenCaptureAccess()
        try FileManager.default.createDirectory(at: Self.recordingsDirectory, withIntermediateDirectories: true)

        let now = Date()
        try createSegment(startedAt: now)
        startedAt = now
        lastMonthlyScoreSyncAt = Date.distantPast
        Self.updateMonthlyScoreLog(for: now, includingCurrentStartedAt: now)

        status(.recording(startedAt ?? Date()))
        startDisplayTimer()
        startCaptureTimer()
    }

    private static func ensureScreenCaptureAccess() throws {
        if CGPreflightScreenCaptureAccess() {
            return
        }
        if canCaptureTestFrame() {
            return
        }
        _ = CGRequestScreenCaptureAccess()
        if CGPreflightScreenCaptureAccess() || canCaptureTestFrame() {
            return
        }
        throw NSError(
            domain: "OneFPSRecorder",
            code: 10,
            userInfo: [
                NSLocalizedDescriptionKey: "画面収録の許可が必要です。システム設定 > プライバシーとセキュリティ > 画面とシステムオーディオ収録 で OneFPSRecorder を許可してから、もう一度録画開始してください。"
            ]
        )
    }

    private static func canCaptureTestFrame() -> Bool {
        let testURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("onefps-permission-\(UUID().uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: testURL) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-t", "jpg", testURL.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: testURL.path)[.size] as? NSNumber)?
                .intValue ?? 0
            return process.terminationStatus == 0
                && FileManager.default.fileExists(atPath: testURL.path)
                && fileSize > 0
        } catch {
            return false
        }
    }

    func stop() {
        guard isRecording else { return }
        stopDisplayTimer()
        stopCaptureTimer()

        let segment = captureQueue.sync {
            detachCurrentSegment(endedAt: Date(), keepRecording: false)
        }
        status(.idleSaving)

        if let segment {
            enqueueEncoding(segment)
        } else {
            status(isEncoding ? .idleSaving : .idle)
        }
    }

    func flushCurrentSegment() {
        guard isRecording else { return }
        stopCaptureTimer()
        let nextStartedAt = Date()
        let segment = captureQueue.sync {
            let detached = detachCurrentSegment(endedAt: nextStartedAt, keepRecording: true)
            do {
                try createSegment(startedAt: nextStartedAt)
            } catch {
                startedAt = nil
            }
            return detached
        }

        if startedAt == nil {
            stopDisplayTimer()
            status(.error("次の録画区切りを作成できませんでした。"))
            return
        }

        if let segment {
            DispatchQueue.main.async {
                self.enqueueEncoding(segment)
            }
        }
        status(.recording(startedAt ?? Date()))
        startCaptureTimer()
    }

    private func createSegment(startedAt: Date) throws {
        let frameDirectory = Self.recordingsDirectory
            .appendingPathComponent(".frames-\(Self.timestamp())-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: frameDirectory, withIntermediateDirectories: true)
        self.frameDirectory = frameDirectory
        self.outputURL = frameDirectory.appendingPathComponent("segment-\(Self.timestamp())-\(UUID().uuidString).mp4")
        self.segmentStartedAt = startedAt
        frameIndex = 0
        firstFrameCapturedAt = nil
        lastFrameCapturedAt = nil
        capturedFrameCount = 0
    }

    private func cleanupCurrentSegment() {
        if let frameDirectory {
            try? FileManager.default.removeItem(at: frameDirectory)
        }
        frameDirectory = nil
        outputURL = nil
        frameIndex = 0
        firstFrameCapturedAt = nil
        lastFrameCapturedAt = nil
        capturedFrameCount = 0
        segmentStartedAt = nil
    }

    private func cleanupAll() {
        cleanupCurrentSegment()
        startedAt = nil
    }

    private func detachCurrentSegment(endedAt: Date, keepRecording: Bool) -> PendingSegment? {
        guard let frameDirectory, let outputURL else {
            if !keepRecording {
                startedAt = nil
            }
            self.frameDirectory = nil
            self.outputURL = nil
            frameIndex = 0
            firstFrameCapturedAt = nil
            lastFrameCapturedAt = nil
            capturedFrameCount = 0
            segmentStartedAt = nil
            return nil
        }
        let actualStartedAt = firstFrameCapturedAt ?? segmentStartedAt ?? startedAt ?? endedAt
        let actualFrameCount = capturedFrameCount
        let actualEndedAt = actualStartedAt.addingTimeInterval(TimeInterval(max(1, actualFrameCount)))
        let segment = PendingSegment(
            frameDirectory: frameDirectory,
            outputURL: outputURL,
            startedAt: actualStartedAt,
            endedAt: max(actualEndedAt, actualStartedAt.addingTimeInterval(1)),
            id: UUID().uuidString,
            frameCount: actualFrameCount
        )
        self.frameDirectory = nil
        self.outputURL = nil
        frameIndex = 0
        firstFrameCapturedAt = nil
        lastFrameCapturedAt = nil
        capturedFrameCount = 0
        segmentStartedAt = nil
        if !keepRecording {
            startedAt = nil
        }
        return segment
    }

    private func startDisplayTimer() {
        stopDisplayTimer()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 1.0, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            guard let self, let startedAt = self.startedAt else { return }
            self.status(.recording(startedAt))
            self.syncMonthlyScoreDuringRecordingIfNeeded(startedAt: startedAt)
        }
        displayTimer = timer
        timer.resume()
    }

    private func syncMonthlyScoreDuringRecordingIfNeeded(startedAt: Date) {
        let now = Date()
        guard now.timeIntervalSince(lastMonthlyScoreSyncAt) >= 60 else { return }
        lastMonthlyScoreSyncAt = now
        Self.updateMonthlyScoreLog(for: now, includingCurrentStartedAt: startedAt)
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
        rotateIfDateChangedBeforeCapture()
        guard let frameDirectory else { return }
        let index = frameIndex
        frameIndex += 1
        let frameURL = frameDirectory.appendingPathComponent(String(format: "frame-%06d.jpg", index))
        let capturedAt = Date()
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
        guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: frameURL.path) else { return }
        if firstFrameCapturedAt == nil {
            firstFrameCapturedAt = capturedAt
        }
        lastFrameCapturedAt = capturedAt
        capturedFrameCount += 1

        if frameIndex >= Self.maxSegmentFrames {
            rotateSegmentFromCaptureQueue()
        }
    }

    private func rotateIfDateChangedBeforeCapture() {
        guard let segmentStartedAt, !Calendar.current.isDate(segmentStartedAt, inSameDayAs: Date()) else { return }
        rotateSegmentFromCaptureQueue()
    }

    private func rotateSegmentFromCaptureQueue() {
        guard isRecording else { return }
        let nextStartedAt = Date()
        let segment = detachCurrentSegment(endedAt: nextStartedAt, keepRecording: true)
        do {
            try createSegment(startedAt: nextStartedAt)
        } catch {
            DispatchQueue.main.async {
                self.stopDisplayTimer()
                self.cleanupAll()
                self.status(.error("次の録画区切りを作成できませんでした。"))
            }
            return
        }
        if let segment {
            DispatchQueue.main.async {
                self.enqueueEncoding(segment)
            }
        }
    }

    private func enqueueEncoding(_ segment: PendingSegment) {
        encodingJobCount += 1
        isEncoding = true
        encodeQueue.async { [weak self] in
            self?.encodeSegment(segment)
        }
    }

    private func finishEncoding(success: Bool, errorMessage: String?) {
        encodingJobCount = max(0, encodingJobCount - 1)
        isEncoding = encodingJobCount > 0
        if let errorMessage {
            stopDisplayTimer()
            cleanupAll()
            status(.error(errorMessage))
            return
        }
        if isRecording {
            status(.recording(startedAt ?? Date()))
        } else {
            status(isEncoding ? .idleSaving : .idle)
        }
    }

    private func encodeSegment(_ segment: PendingSegment) {
        let frameDirectory = segment.frameDirectory
        let outputURL = segment.outputURL
        guard FileManager.default.fileExists(atPath: frameDirectory.path) else {
            DispatchQueue.main.async {
                self.finishEncoding(success: true, errorMessage: nil)
            }
            return
        }
        Self.writeSegmentMetadata(
            SegmentMetadata(
                id: segment.id,
                startedAt: segment.startedAt,
                endedAt: segment.endedAt,
                outputFilename: Self.dailyOutputURL(for: segment.endedAt).lastPathComponent,
                videoAppended: false,
                frameCount: segment.frameCount
            ),
            in: frameDirectory
        )

        let frameNames = (try? FileManager.default.contentsOfDirectory(atPath: frameDirectory.path)
            .filter { $0.hasSuffix(".jpg") }
            .sorted()) ?? []
        let frameCount = frameNames.count

        guard frameCount > 0 else {
            try? FileManager.default.removeItem(at: frameDirectory)
            DispatchQueue.main.async {
                self.finishEncoding(success: true, errorMessage: nil)
            }
            return
        }

        let listURL = frameDirectory.appendingPathComponent("frames.txt")
        let frameList = Self.frameConcatList(frameNames: frameNames, in: frameDirectory)
        do {
            try frameList.write(to: listURL, atomically: true, encoding: .utf8)
        } catch {
            DispatchQueue.main.async {
                self.finishEncoding(success: false, errorMessage: "録画フレーム一覧の作成に失敗しました。")
            }
            return
        }

        let ffmpeg = Self.ffmpegURL
        let process = Process()
        process.executableURL = ffmpeg
        process.arguments = [
            "-hide_banner",
            "-loglevel", "error",
            "-f", "concat",
            "-safe", "0",
            "-i", listURL.path,
            "-vf", "scale=960:600:force_original_aspect_ratio=decrease,pad=960:600:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=1",
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

        var appendSucceeded = false
        if process.terminationStatus == 0 {
            appendSucceeded = Self.appendSegmentToDailyFile(
                segmentURL: outputURL,
                frameDirectory: frameDirectory,
                date: segment.endedAt,
                expectedAddedFrames: max(1, frameCount)
            )
            if appendSucceeded {
                Self.writeSegmentMetadata(
                    SegmentMetadata(
                        id: segment.id,
                        startedAt: segment.startedAt,
                        endedAt: segment.endedAt,
                        outputFilename: Self.dailyOutputURL(for: segment.endedAt).lastPathComponent,
                        videoAppended: true,
                        frameCount: frameCount
                    ),
                    in: frameDirectory
                )
            }
        }
        if appendSucceeded {
            let logSucceeded = Self.appendRecordingLog(
                startedAt: segment.startedAt,
                endedAt: segment.endedAt,
                outputURL: Self.dailyOutputURL(for: segment.endedAt),
                segmentID: segment.id
            )
            && Self.syncDerivedLogs(for: segment.endedAt)
            if logSucceeded {
                try? FileManager.default.removeItem(at: frameDirectory)
            }
            appendSucceeded = logSucceeded
        }

        DispatchQueue.main.async {
            if process.terminationStatus == 0, appendSucceeded {
                self.finishEncoding(success: true, errorMessage: nil)
            } else if process.terminationStatus == 0 {
                self.finishEncoding(success: false, errorMessage: "日別動画への追記に失敗しました。")
            } else {
                self.finishEncoding(success: false, errorMessage: "ffmpeg が失敗しました。終了コード: \(process.terminationStatus)")
            }
        }
    }

    private static func appendSegmentToDailyFile(segmentURL: URL, frameDirectory: URL, date: Date, expectedAddedFrames: Int) -> Bool {
        let dailyURL = dailyOutputURL(for: date)
        do {
            try FileManager.default.createDirectory(at: dailyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: dailyURL.path) {
                guard videoFrameCount(segmentURL) == expectedAddedFrames else { return false }
                try FileManager.default.moveItem(at: segmentURL, to: dailyURL)
                return videoFrameCount(dailyURL) == expectedAddedFrames
            }

            let originalFrameCount = videoFrameCount(dailyURL)
            let tempDailyURL = dailyURL.deletingLastPathComponent()
                .appendingPathComponent(".daily-\(Self.timestamp())-\(UUID().uuidString).mp4")

            let ffmpeg = Self.ffmpegURL
            let process = Process()
            process.executableURL = ffmpeg
            process.arguments = [
                "-hide_banner",
                "-loglevel", "error",
                "-i", dailyURL.path,
                "-i", segmentURL.path,
                "-filter_complex",
                "[0:v]scale=960:600:force_original_aspect_ratio=decrease,pad=960:600:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=1[v0];[1:v]scale=960:600:force_original_aspect_ratio=decrease,pad=960:600:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=1[v1];[v0][v1]concat=n=2:v=1:a=0[v]",
                "-map", "[v]",
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
            guard videoFrameCount(tempDailyURL) == originalFrameCount + expectedAddedFrames else {
                try? FileManager.default.removeItem(at: tempDailyURL)
                return false
            }

            let backupURL = dailyURL.deletingLastPathComponent()
                .appendingPathComponent(".daily-backup-\(Self.timestamp())-\(UUID().uuidString).mp4")
            try FileManager.default.moveItem(at: dailyURL, to: backupURL)
            do {
                try FileManager.default.moveItem(at: tempDailyURL, to: dailyURL)
                guard videoFrameCount(dailyURL) == originalFrameCount + expectedAddedFrames else {
                    try? FileManager.default.moveItem(at: dailyURL, to: tempDailyURL)
                    try? FileManager.default.moveItem(at: backupURL, to: dailyURL)
                    try? FileManager.default.removeItem(at: tempDailyURL)
                    return false
                }
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

    private static func videoFrameCount(_ url: URL) -> Int {
        guard FileManager.default.fileExists(atPath: url.path) else { return 0 }
        let ffprobe = Self.ffprobeURL
        let process = Process()
        let pipe = Pipe()
        process.executableURL = ffprobe
        process.arguments = [
            "-v", "error",
            "-select_streams", "v:0",
            "-show_entries", "stream=nb_frames",
            "-of", "default=noprint_wrappers=1:nokey=1",
            url.path
        ]
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return 0 }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return Int(text) ?? 0
        } catch {
            return 0
        }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private static func dailyOutputURL(for date: Date = Date()) -> URL {
        let filename = "\(monthDayString(from: date))_\(RecorderSettings.recordingName).mp4"
        return dailyDirectory(for: date)
            .appendingPathComponent(filename)
    }

    private static func existingDailyVideoURL(for date: Date = Date()) -> URL {
        let directory = dailyDirectory(for: date)
        let monthDay = monthDayString(from: date)
        if let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ),
           let videoURL = files
            .filter({ $0.pathExtension.lowercased() == "mp4" })
            .filter({ $0.deletingPathExtension().lastPathComponent.hasPrefix("\(monthDay)_") })
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            .first {
            return videoURL
        }
        return dailyOutputURL(for: date)
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
            for fileURL in canonicalDailyVideoURLs(in: monthURL) {
                guard let day = recordingDay(from: fileURL.deletingPathExtension().lastPathComponent) else { continue }
                let newURL = fileURL.deletingLastPathComponent().appendingPathComponent("\(day)_\(targetName).mp4")
                guard fileURL.path != newURL.path else { continue }
                if FileManager.default.fileExists(atPath: newURL.path) {
                    _ = mergeVideoFile(fileURL, into: newURL)
                    continue
                }
                try? FileManager.default.moveItem(at: fileURL, to: newURL)
            }
        }
    }

    private static func isCanonicalDailyVideo(_ url: URL) -> Bool {
        guard url.pathExtension.lowercased() == "mp4" else { return false }
        let basename = url.deletingPathExtension().lastPathComponent
        guard !basename.hasPrefix(".") else { return false }
        guard !basename.contains(".before-") else { return false }
        guard !basename.contains(".rename-") else { return false }
        guard !basename.contains(".daily-") else { return false }
        return recordingDay(from: basename) != nil
    }

    private static func canonicalDailyVideoURLs(in monthURL: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: monthURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var urls: [URL] = []
        for case let fileURL as URL in enumerator {
            if fileURL.pathComponents.contains("バックアップ") { continue }
            if fileURL.pathComponents.contains("提出") { continue }
            if isCanonicalDailyVideo(fileURL) {
                urls.append(fileURL)
            }
        }
        return urls
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
            let ffmpeg = Self.ffmpegURL
            let process = Process()
            process.executableURL = ffmpeg
            process.arguments = [
                "-hide_banner",
                "-loglevel", "error",
                "-f", "concat",
                "-safe", "0",
                "-i", listURL.path,
                "-vf", "scale=960:600:force_original_aspect_ratio=decrease,pad=960:600:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=1",
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

            for logURL in activeRecordingLogURLs(in: monthURL, month: month) {
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
        syncAllDerivedLogs()
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

    private static func dailyLogURL(for date: Date = Date()) -> URL {
        let directory = dailyDirectory(for: date)
        if let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ),
           let existingLog = files.first(where: {
               $0.pathExtension == "txt" && $0.lastPathComponent.contains("録画区間")
           }) {
            return existingLog
        }
        return directory.appendingPathComponent("録画区間ログ-\(dayString(from: date)).txt")
    }

    private static func legacyMonthlyLogURL(for date: Date = Date()) -> URL {
        monthlyDirectory(for: date)
            .appendingPathComponent("recording-log-\(monthString(from: date)).txt")
    }

    private static func dailyTotalLogURL(for date: Date = Date()) -> URL {
        monthlyDirectory(for: date)
            .appendingPathComponent("日別合計作業時間-\(monthString(from: date)).txt")
    }

    private static func monthlyScoreLogURL(for date: Date = Date()) -> URL {
        monthlyDirectory(for: date)
            .appendingPathComponent("月間スコア-\(monthString(from: date)).txt")
    }

    private static func legacyDailyTotalLogURL(for date: Date = Date()) -> URL {
        monthlyDirectory(for: date)
            .appendingPathComponent("daily-total-\(monthString(from: date)).txt")
    }

    private static func monthlyDirectory(for date: Date = Date()) -> URL {
        recordingsDirectory
            .appendingPathComponent(monthString(from: date), isDirectory: true)
    }

    private static func dailyDirectory(for date: Date = Date()) -> URL {
        monthlyDirectory(for: date)
            .appendingPathComponent(monthDayString(from: date), isDirectory: true)
    }

    private static func monthString(from date: Date = Date()) -> String {
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        return monthFormatter.string(from: date)
    }

    private static func dayString(from date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func monthDayString(from date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMdd"
        return formatter.string(from: date)
    }

    private static func date(from month: String, monthDay: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let day = "\(month)-\(monthDay.prefix(2))-\(monthDay.suffix(2))"
        return formatter.date(from: day)
    }

    private static func segmentMetadataURL(in frameDirectory: URL) -> URL {
        frameDirectory.appendingPathComponent("segment-info.json")
    }

    private static func writeSegmentMetadata(_ metadata: SegmentMetadata, in frameDirectory: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(metadata)
            try data.write(to: segmentMetadataURL(in: frameDirectory), options: .atomic)
        } catch {
            return
        }
    }

    private static func readSegmentMetadata(in frameDirectory: URL) -> SegmentMetadata? {
        do {
            let data = try Data(contentsOf: segmentMetadataURL(in: frameDirectory))
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(SegmentMetadata.self, from: data)
        } catch {
            return nil
        }
    }

    private static func activeRecordingLogURLs(in monthURL: URL, month: String) -> [URL] {
        var urls: [URL] = []
        if let items = try? FileManager.default.contentsOfDirectory(
            at: monthURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for itemURL in items {
                let values = try? itemURL.resourceValues(forKeys: [.isDirectoryKey])
                guard values?.isDirectory == true else { continue }
                let day = itemURL.lastPathComponent
                guard day.range(of: #"^\d{4}$"#, options: .regularExpression) != nil else { continue }
                let canonicalLogURL = itemURL.appendingPathComponent("録画区間ログ-\(month)-\(day.suffix(2)).txt")
                if FileManager.default.fileExists(atPath: canonicalLogURL.path) {
                    urls.append(canonicalLogURL)
                    continue
                }
                if let files = try? FileManager.default.contentsOfDirectory(
                    at: itemURL,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) {
                    urls.append(contentsOf: files.filter {
                        $0.pathExtension == "txt" && $0.lastPathComponent.contains("録画区間")
                    })
                }
            }
        }
        urls.sort { $0.path < $1.path }

        if urls.isEmpty {
            let monthlyURL = monthURL.appendingPathComponent("録画区間ログ-\(month).txt")
            if FileManager.default.fileExists(atPath: monthlyURL.path) {
                urls.append(monthlyURL)
            }
        }
        return urls
    }

    private static func recordingLogRows(for date: Date) -> [String] {
        let month = monthString(from: date)
        let monthURL = monthlyDirectory(for: date)
        return activeRecordingLogURLs(in: monthURL, month: month).flatMap { logURL in
            ((try? String(contentsOf: logURL, encoding: .utf8)) ?? "")
                .split(separator: "\n")
                .dropFirst()
                .map(String.init)
        }
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
        guard let enumerator = FileManager.default.enumerator(
            at: recordingsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else { return }

        var frameDirectories: [URL] = []
        for case let itemURL as URL in enumerator where itemURL.lastPathComponent.hasPrefix(".frames-") {
            let values = try? itemURL.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            frameDirectories.append(itemURL)
            enumerator.skipDescendants()
        }

        for frameDirectory in frameDirectories.sorted(by: { $0.path < $1.path }) {
            recoverFrameDirectory(frameDirectory)
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
        let metadata = readSegmentMetadata(in: frameDirectory)
        let recoveredFrameCount = max(1, metadata?.frameCount ?? frameNames.count)
        let startedAt = metadata?.startedAt ?? dateFromFrameDirectoryName(frameDirectory.lastPathComponent) ?? recoveredAt
        let endedAt = startedAt.addingTimeInterval(TimeInterval(recoveredFrameCount))
        let segmentID = metadata?.id ?? UUID().uuidString
        let outputURL = frameDirectory.appendingPathComponent("recovered-\(timestamp()).mp4")
        let listURL = frameDirectory.appendingPathComponent("frames.txt")
        let frameList = frameConcatList(frameNames: frameNames, in: frameDirectory)
        guard (try? frameList.write(to: listURL, atomically: true, encoding: .utf8)) != nil else {
            return
        }

        do {
            if metadata?.videoAppended != true {
                let ffmpeg = Self.ffmpegURL
                let process = Process()
                process.executableURL = ffmpeg
                process.arguments = [
                    "-hide_banner",
                    "-loglevel", "error",
                    "-f", "concat",
                    "-safe", "0",
                    "-i", listURL.path,
                    "-vf", "scale=960:600:force_original_aspect_ratio=decrease,pad=960:600:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=1",
                    "-c:v", "libx264",
                    "-preset", "veryfast",
                    "-tune", "stillimage",
                    "-pix_fmt", "yuv420p",
                    "-an",
                    "-movflags", "+faststart",
                    outputURL.path,
                    "-y"
                ]

                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0,
                      appendSegmentToDailyFile(
                        segmentURL: outputURL,
                        frameDirectory: frameDirectory,
                        date: endedAt,
                        expectedAddedFrames: frameNames.count
                      ) else {
                    return
                }
                writeSegmentMetadata(
                    SegmentMetadata(
                        id: segmentID,
                        startedAt: startedAt,
                        endedAt: endedAt,
                        outputFilename: dailyOutputURL(for: endedAt).lastPathComponent,
                        videoAppended: true,
                        frameCount: frameNames.count
                    ),
                    in: frameDirectory
                )
            }
            guard appendRecordingLog(
                startedAt: startedAt,
                endedAt: endedAt,
                outputURL: dailyOutputURL(for: endedAt),
                segmentID: segmentID
            ), syncDerivedLogs(for: endedAt) else { return }
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

    static func migrateToDailyDirectories() {
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
            splitMonthlyLogIntoDailyLogs(monthURL: monthURL, month: month)
            moveRootDailyVideosIntoDailyDirectories(monthURL: monthURL, month: month)
            normalizeDailyLogFileNames(monthURL: monthURL, month: month)
            moveLegacyLogBackups(monthURL: monthURL)
        }
    }

    private static func splitMonthlyLogIntoDailyLogs(monthURL: URL, month: String) {
        let logURL = monthURL.appendingPathComponent("録画区間ログ-\(month).txt")
        let sourceURL: URL
        if FileManager.default.fileExists(atPath: logURL.path) {
            sourceURL = logURL
        } else if activeRecordingLogURLs(in: monthURL, month: month).isEmpty,
                  let migratedBackup = latestMigratedMonthlyLogBackup(in: monthURL) {
            sourceURL = migratedBackup
        } else {
            return
        }
        guard let content = try? String(contentsOf: sourceURL, encoding: .utf8) else { return }

        let rows = content.split(separator: "\n").dropFirst().map(String.init)
        guard !rows.isEmpty else { return }

        var rowsByDay: [String: [String]] = [:]
        for row in rows {
            let columns = row.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard let startedAt = columns.first, startedAt.count >= 10 else { continue }
            let day = String(startedAt.prefix(10))
            guard day.hasPrefix(month) else { continue }
            let monthDay = day.replacingOccurrences(of: "-", with: "").suffix(4)
            rowsByDay[String(monthDay), default: []].append(row)
        }

        for (monthDay, dayRows) in rowsByDay {
            let dailyURL = monthURL
                .appendingPathComponent(monthDay, isDirectory: true)
                .appendingPathComponent("録画区間ログ-\(month)-\(monthDay.suffix(2)).txt")
            mergeLogRows(dayRows, into: dailyURL, header: "開始\t終了\t時間\tファイル\tID")
        }

        if sourceURL.path == logURL.path {
            let backupURL = backupDirectory(in: monthURL)
                .appendingPathComponent("録画区間ログ-\(month).migrated-\(timestamp()).txt")
            try? FileManager.default.createDirectory(at: backupURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.moveItem(at: logURL, to: backupURL)
        }
    }

    private static func latestMigratedMonthlyLogBackup(in monthURL: URL) -> URL? {
        let backupURL = backupDirectory(in: monthURL)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: backupURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return files
            .filter { $0.lastPathComponent.contains(".migrated-") && $0.lastPathComponent.hasSuffix(".txt") }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .first
    }

    private static func mergeLogRows(_ rows: [String], into logURL: URL, header: String) {
        do {
            try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let existingText = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
            var existing = Set(existingText.split(separator: "\n").map(String.init))
            var lines = existingText
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map(String.init)
            if lines.first?.hasPrefix("開始\t終了\t時間\tファイル") != true {
                lines.insert(header, at: 0)
                existing.insert(header)
            }
            for row in rows where !existing.contains(row) {
                lines.append(row)
                existing.insert(row)
            }
            try (lines.joined(separator: "\n") + "\n").write(to: logURL, atomically: true, encoding: .utf8)
        } catch {
            return
        }
    }

    private static func moveRootDailyVideosIntoDailyDirectories(monthURL: URL, month: String) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: monthURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        for fileURL in files where isCanonicalDailyVideo(fileURL) {
            guard let monthDay = recordingDay(from: fileURL.deletingPathExtension().lastPathComponent) else { continue }
            let destinationURL = monthURL
                .appendingPathComponent(monthDay, isDirectory: true)
                .appendingPathComponent(fileURL.lastPathComponent)
            do {
                try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    _ = mergeVideoFile(fileURL, into: destinationURL)
                } else {
                    try FileManager.default.moveItem(at: fileURL, to: destinationURL)
                }
            } catch {
                continue
            }
        }
    }

    private static func moveLegacyLogBackups(monthURL: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: monthURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        let backupURL = backupDirectory(in: monthURL)
        for fileURL in files {
            let name = fileURL.lastPathComponent
            guard name.contains("録画区間"), name.contains(".before-") else { continue }
            try? FileManager.default.createDirectory(at: backupURL, withIntermediateDirectories: true)
            let destination = backupURL.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: destination.path) {
                try? FileManager.default.moveItem(at: fileURL, to: destination)
            }
        }
    }

    private static func normalizeDailyLogFileNames(monthURL: URL, month: String) {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: monthURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for dayURL in items {
            let values = try? dayURL.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            let monthDay = dayURL.lastPathComponent
            guard monthDay.range(of: #"^\d{4}$"#, options: .regularExpression) != nil else { continue }
            let canonicalURL = dayURL.appendingPathComponent("録画区間ログ-\(month)-\(monthDay.suffix(2)).txt")
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: dayURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for fileURL in files where fileURL.pathExtension == "txt" && fileURL.lastPathComponent.contains("録画区間") {
                guard fileURL.path != canonicalURL.path else { continue }
                if FileManager.default.fileExists(atPath: canonicalURL.path) {
                    migrateTextFile(from: fileURL, to: canonicalURL, header: "開始\t終了\t時間\tファイル\tID")
                } else {
                    try? FileManager.default.moveItem(at: fileURL, to: canonicalURL)
                }
            }
        }
    }

    private static func backupDirectory(in monthURL: URL) -> URL {
        monthURL.appendingPathComponent("バックアップ", isDirectory: true)
    }

    @discardableResult
    private static func appendRecordingLog(startedAt: Date, endedAt: Date, outputURL: URL, segmentID: String) -> Bool {
        let logURL = dailyLogURL(for: endedAt)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let duration = max(0, Int(endedAt.timeIntervalSince(startedAt).rounded()))
        let columns = [
            formatter.string(from: startedAt),
            formatter.string(from: endedAt),
            "\(duration)秒",
            outputURL.lastPathComponent,
            segmentID
        ]
        let line = columns.joined(separator: "\t")

        do {
            try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let existingText = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
            var lines = existingText
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map(String.init)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if lines.first?.hasPrefix("開始\t終了\t時間\tファイル") != true {
                lines.insert("開始\t終了\t時間\tファイル\tID", at: 0)
            } else if lines.first == "開始\t終了\t時間\tファイル" {
                lines[0] = "開始\t終了\t時間\tファイル\tID"
            }
            if lines.dropFirst().contains(where: { row in
                let parts = row.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                return parts.count >= 5 && parts[4] == segmentID
            }) {
                return true
            }
            lines.append(line)
            try (lines.joined(separator: "\n") + "\n").write(to: logURL, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func syncDerivedLogs(for date: Date = Date()) -> Bool {
        updateDailyTotalLog(for: date) && updateMonthlyScoreLog(for: date)
    }

    static func syncAllDerivedLogs() {
        guard let months = try? FileManager.default.contentsOfDirectory(
            at: recordingsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for monthURL in months {
            let values = try? monthURL.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            guard monthURL.lastPathComponent.range(of: #"^\d{4}-\d{2}$"#, options: .regularExpression) != nil else { continue }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            if let date = formatter.date(from: monthURL.lastPathComponent) {
                _ = syncDerivedLogs(for: date)
            }
        }
    }

    static func reconcileDailyVideosWithLogs() {
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
            reconcileMonthVideosWithLog(monthURL: monthURL, month: month)
        }
    }

    private static func reconcileMonthVideosWithLog(monthURL: URL, month: String) {
        var targetSecondsByFilename: [String: Int] = [:]
        for line in activeRecordingLogURLs(in: monthURL, month: month).flatMap({ logURL in
            ((try? String(contentsOf: logURL, encoding: .utf8)) ?? "")
                .split(separator: "\n")
                .dropFirst()
                .map(String.init)
        }) {
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard columns.count >= 4 else { continue }
            let filename = columns[3]
            guard filename.hasSuffix(".mp4") else { continue }
            targetSecondsByFilename[filename, default: 0] += parsedDurationSeconds(columns[2])
        }

        for (filename, targetSeconds) in targetSecondsByFilename where targetSeconds > 0 {
            guard let videoURL = canonicalDailyVideoURLs(in: monthURL).first(where: { $0.lastPathComponent == filename }) else { continue }
            repairDailyVideo(videoURL, targetFrames: targetSeconds)
        }
    }

    @discardableResult
    private static func repairDailyVideo(_ videoURL: URL, targetFrames: Int) -> Bool {
        guard FileManager.default.fileExists(atPath: videoURL.path) else { return false }
        let currentFrames = videoFrameCount(videoURL)
        guard currentFrames > 0, currentFrames != targetFrames else { return currentFrames == targetFrames }

        let tempURL = videoURL.deletingLastPathComponent()
            .appendingPathComponent(".repair-\(timestamp())-\(UUID().uuidString).mp4")
        let backupURL = videoURL.deletingLastPathComponent()
            .appendingPathComponent("\(videoURL.deletingPathExtension().lastPathComponent).before-video-reconcile-\(timestamp()).mp4")
        let ffmpeg = Self.ffmpegURL
        let filter = "setpts=PTS*\(targetFrames)/\(currentFrames),fps=1,scale=960:600:force_original_aspect_ratio=decrease,pad=960:600:(ow-iw)/2:(oh-ih)/2,setsar=1"

        let process = Process()
        process.executableURL = ffmpeg
        process.arguments = [
            "-hide_banner",
            "-loglevel", "error",
            "-i", videoURL.path,
            "-vf", filter,
            "-c:v", "libx264",
            "-preset", "veryfast",
            "-tune", "stillimage",
            "-pix_fmt", "yuv420p",
            "-an",
            "-movflags", "+faststart",
            tempURL.path,
            "-y"
        ]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0, videoFrameCount(tempURL) == targetFrames else {
                try? FileManager.default.removeItem(at: tempURL)
                return false
            }

            try FileManager.default.moveItem(at: videoURL, to: backupURL)
            do {
                try FileManager.default.moveItem(at: tempURL, to: videoURL)
                if videoFrameCount(videoURL) == targetFrames {
                    try? FileManager.default.removeItem(at: backupURL)
                    return true
                }
                try? FileManager.default.moveItem(at: videoURL, to: tempURL)
                try? FileManager.default.moveItem(at: backupURL, to: videoURL)
                try? FileManager.default.removeItem(at: tempURL)
                return false
            } catch {
                if FileManager.default.fileExists(atPath: backupURL.path) {
                    try? FileManager.default.moveItem(at: backupURL, to: videoURL)
                }
                try? FileManager.default.removeItem(at: tempURL)
                return false
            }
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            return false
        }
    }

    @discardableResult
    static func updateDailyTotalLog(for date: Date = Date()) -> Bool {
        let outputURL = dailyTotalLogURL(for: date)
        let rows = recordingLogRows(for: date)
        guard !rows.isEmpty else { return false }

        var totals: [String: (seconds: Int, count: Int)] = [:]
        for line in rows {
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
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func updateMonthlyScoreLog(for date: Date = Date(), includingCurrentStartedAt startedAt: Date? = nil) -> Bool {
        let rows = recordingLogRows(for: date)
        guard !rows.isEmpty else { return false }
        let resetAt = RecorderSettings.monthlyScoreResetAt(for: date)
        let score = monthlyScoreValues(
            for: date,
            rows: rows,
            resetAt: resetAt,
            includingCurrentStartedAt: startedAt
        )

        var outputLines = [
            "項目\t値",
            "月\t\(monthString(from: date))",
            "合計作業時間\t\(formattedDuration(score.seconds))",
            "合計秒数\t\(score.seconds)秒",
            "記録回数\t\(score.count)",
            "係数\t\(RecorderSettings.hourlyRate)円/時間",
            "月間スコア\t\(score.earnedYen)円",
            "月末ライン\t\(RecorderSettings.monthlyGoal)円",
            "達成\t\(RecorderSettings.monthlyGoal > 0 && score.earnedYen >= RecorderSettings.monthlyGoal ? "はい" : "いいえ")"
        ]
        if let resetAt {
            outputLines.append("初期化日時\t\(displayDateTime(resetAt))")
        }
        let output = outputLines.joined(separator: "\n") + "\n"

        do {
            let outputURL = monthlyScoreLogURL(for: date)
            try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try output.write(to: outputURL, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    static func dailyWorkSeconds(for date: Date = Date()) -> Int {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let targetDay = dayFormatter.string(from: date)
        return workSeconds(in: recordingLogRows(for: date)) { startedAt in
            startedAt.hasPrefix(targetDay)
        }
    }

    static func monthlyScore(for date: Date = Date(), includingCurrentStartedAt startedAt: Date? = nil) -> (seconds: Int, earnedYen: Int) {
        let score = monthlyScoreValues(
            for: date,
            rows: recordingLogRows(for: date),
            resetAt: RecorderSettings.monthlyScoreResetAt(for: date),
            includingCurrentStartedAt: startedAt
        )
        return (score.seconds, score.earnedYen)
    }

    static func submitReport(_ form: ReportSubmissionForm) throws -> ReportSubmissionResult {
        _ = syncDerivedLogs(for: form.date)
        let videoURL = existingDailyVideoURL(for: form.date)
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            throw NSError(
                domain: "OneFPSRecorder",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "指定日の動画が見つかりません: \(videoURL.path)"]
            )
        }

        let seconds = dailyWorkSeconds(for: form.date)
        let hours = max(0, seconds / 3600)
        let month = monthString(from: form.date)
        let day = dayString(from: form.date)
        let monthDay = monthDayString(from: form.date)
        let submissionDirectory = monthlyDirectory(for: form.date)
            .appendingPathComponent("提出", isDirectory: true)
            .appendingPathComponent(monthDay, isDirectory: true)
        try FileManager.default.createDirectory(at: submissionDirectory, withIntermediateDirectories: true)

        let submittedVideoURL = submissionDirectory.appendingPathComponent(videoURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: submittedVideoURL.path) {
            try FileManager.default.removeItem(at: submittedVideoURL)
        }
        try FileManager.default.copyItem(at: videoURL, to: submittedVideoURL)

        let reportURL = monthlyDirectory(for: form.date).appendingPathComponent("業務報告-\(month).md")
        try upsertReportEntry(
            form: form,
            reportURL: reportURL,
            submittedVideoURL: submittedVideoURL,
            hours: hours,
            day: day
        )

        let docxReportURL = monthlyDirectory(for: form.date).appendingPathComponent("業務報告-\(month).docx")
        let reportDataURL = monthlyDirectory(for: form.date).appendingPathComponent("業務報告データ-\(month).json")
        try upsertDocxReportEntry(
            form: form,
            entriesURL: reportDataURL,
            docxReportURL: docxReportURL,
            submittedVideoURL: submittedVideoURL,
            hours: hours,
            day: day
        )
        try syncGoogleReportIfPossible(
            form: form,
            entriesURL: reportDataURL,
            submittedVideoURL: submittedVideoURL
        )

        return ReportSubmissionResult(reportURL: docxReportURL, submittedVideoURL: submittedVideoURL, hours: hours)
    }

    private static func syncGoogleReportIfPossible(
        form: ReportSubmissionForm,
        entriesURL: URL,
        submittedVideoURL: URL
    ) throws {
        let folderURL = form.driveFolderURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let videoFolderURL = form.videoDriveFolderURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !folderURL.isEmpty else { return }
        let scriptURL = try googleReportSyncScriptURL()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [
            scriptURL.path,
            "--folder-url", folderURL,
            "--video-folder-url", videoFolderURL,
            "--template", expandedPath(RecorderSettings.reportTemplatePath),
            "--entries-json", entriesURL.path,
            "--video", submittedVideoURL.path
        ]
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "詳細不明"
            throw NSError(
                domain: "OneFPSRecorder",
                code: 1004,
                userInfo: [NSLocalizedDescriptionKey: "Drive上の報告書更新に失敗しました。ローカル保存は完了しています。\n\(output)"]
            )
        }
    }

    private static func googleReportSyncScriptURL() throws -> URL {
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("sync_google_report.py"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("scripts")
                .appendingPathComponent("sync_google_report.py"),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("scripts")
                .appendingPathComponent("sync_google_report.py")
        ].compactMap { $0 }
        if let found = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return found
        }
        throw NSError(
            domain: "OneFPSRecorder",
            code: 1005,
            userInfo: [NSLocalizedDescriptionKey: "Drive同期スクリプトが見つかりません。再インストールしてください。"]
        )
    }

    private static func upsertDocxReportEntry(
        form: ReportSubmissionForm,
        entriesURL: URL,
        docxReportURL: URL,
        submittedVideoURL: URL,
        hours: Int,
        day: String
    ) throws {
        try FileManager.default.createDirectory(at: entriesURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var entries: [StoredReportEntry] = []
        if let data = try? Data(contentsOf: entriesURL),
           let decoded = try? JSONDecoder().decode([StoredReportEntry].self, from: data) {
            entries = decoded
        }
        let videoText = form.videoLink.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = StoredReportEntry(
            date: day,
            displayDate: shortDateString(from: form.date),
            reporter: form.reporter.trimmingCharacters(in: .whitespacesAndNewlines),
            hours: hours,
            workPlan: form.workPlan.trimmingCharacters(in: .whitespacesAndNewlines),
            workContent: form.workContent.trimmingCharacters(in: .whitespacesAndNewlines),
            videoLink: videoText.isEmpty ? submittedVideoURL.lastPathComponent : videoText,
            videoFileName: submittedVideoURL.lastPathComponent,
            nextTask: form.nextTask.trimmingCharacters(in: .whitespacesAndNewlines),
            status: form.status.trimmingCharacters(in: .whitespacesAndNewlines),
            message: form.message.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        entries.removeAll { $0.date == day }
        entries.append(entry)
        entries.sort { $0.date < $1.date }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(entries).write(to: entriesURL, options: .atomic)
        try regenerateDocxReport(entriesURL: entriesURL, outputURL: docxReportURL)
    }

    private static func regenerateDocxReport(entriesURL: URL, outputURL: URL) throws {
        let scriptURL = try reportDocxScriptURL()
        let templateURL = URL(fileURLWithPath: expandedPath(RecorderSettings.reportTemplatePath))
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [
            scriptURL.path,
            "--template", templateURL.path,
            "--output", outputURL.path,
            "--entries-json", entriesURL.path
        ]
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "詳細不明"
            throw NSError(
                domain: "OneFPSRecorder",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "報告書DOCXの更新に失敗しました: \(output)"]
            )
        }
    }

    private static func reportDocxScriptURL() throws -> URL {
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("update_report_docx.py"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("scripts")
                .appendingPathComponent("update_report_docx.py"),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("scripts")
                .appendingPathComponent("update_report_docx.py")
        ].compactMap { $0 }
        if let found = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return found
        }
        throw NSError(
            domain: "OneFPSRecorder",
            code: 1003,
            userInfo: [NSLocalizedDescriptionKey: "報告書更新スクリプトが見つかりません。再インストールしてください。"]
        )
    }

    private static func expandedPath(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }

    private static func upsertReportEntry(
        form: ReportSubmissionForm,
        reportURL: URL,
        submittedVideoURL: URL,
        hours: Int,
        day: String
    ) throws {
        let markerStart = "<!-- OneFPSReport:\(day) -->"
        let markerEnd = "<!-- /OneFPSReport:\(day) -->"
        let titleDate = shortDateString(from: form.date)
        let videoText = form.videoLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? submittedVideoURL.lastPathComponent
            : form.videoLink.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = """
        \(markerStart)
        ## \(titleDate)

        | 項目 | 入力欄 | 備考欄 |
        | --- | --- | --- |
        | 担当者 | \(markdownCell(form.reporter)) |  |
        | 日付 | \(titleDate) |  |
        | 業務時間 | \(hours)h |  |
        | 業務プラン | \(markdownCell(form.workPlan)) |  |
        | 業務内容 | \(markdownCell(form.workContent)) |  |
        | 業務動画リンク | \(markdownCell(videoText)) |  |
        | 次回までのTask | \(markdownCell(form.nextTask)) |  |
        | 業務は順調ですか？ | \(markdownCell(form.status)) |  |
        | Visitasへのメッセージ | \(markdownCell(form.message)) |  |

        \(markerEnd)
        """

        try FileManager.default.createDirectory(at: reportURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let existing = (try? String(contentsOf: reportURL, encoding: .utf8)) ?? "# 業務報告 \(monthString(from: form.date))\n\n"
        let updated: String
        if let startRange = existing.range(of: markerStart),
           let endRange = existing.range(of: markerEnd, range: startRange.upperBound..<existing.endIndex) {
            updated = existing.replacingCharacters(in: startRange.lowerBound..<endRange.upperBound, with: entry)
        } else {
            updated = existing.trimmingCharacters(in: .newlines) + "\n\n" + entry + "\n"
        }
        try updated.write(to: reportURL, atomically: true, encoding: .utf8)
    }

    private static func markdownCell(_ text: String) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: "<br>")
            .replacingOccurrences(of: "|", with: "\\|")
        return cleaned.isEmpty ? "-" : cleaned
    }

    private static func shortDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private static func monthlyScoreValues(
        for date: Date,
        rows: [String],
        resetAt: Date?,
        includingCurrentStartedAt startedAt: Date?
    ) -> (seconds: Int, count: Int, earnedYen: Int) {
        var seconds = 0
        var count = 0
        var latestLoggedEndAt: Date?
        for row in rows {
            let columns = row.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard columns.count >= 3 else { continue }
            let duration = parsedDurationSeconds(columns[2])
            guard duration > 0 else { continue }
            guard let rowStartedAt = parseLogDate(columns[0]) else {
                if resetAt == nil {
                    seconds += duration
                    count += 1
                }
                continue
            }
            let rowEndedAt: Date
            if columns.count >= 2, let parsedEndedAt = parseLogDate(columns[1]) {
                rowEndedAt = parsedEndedAt
            } else {
                rowEndedAt = rowStartedAt.addingTimeInterval(TimeInterval(duration))
            }
            if let currentLatest = latestLoggedEndAt {
                latestLoggedEndAt = max(currentLatest, rowEndedAt)
            } else {
                latestLoggedEndAt = rowEndedAt
            }
            let includedSeconds = overlapSeconds(start: rowStartedAt, end: rowEndedAt, resetAt: resetAt)
            guard includedSeconds > 0 else { continue }
            seconds += includedSeconds
            count += 1
        }
        if let startedAt,
           Calendar.current.isDate(startedAt, equalTo: date, toGranularity: .month) {
            let unloggedStartAt = max(startedAt, latestLoggedEndAt ?? startedAt)
            seconds += overlapSeconds(start: unloggedStartAt, end: Date(), resetAt: resetAt)
        }
        let earned = Int((Double(seconds) / 3600.0 * Double(RecorderSettings.hourlyRate)).rounded())
        return (seconds, count, earned)
    }

    private static func overlapSeconds(start: Date, end: Date, resetAt: Date?) -> Int {
        let effectiveStart = max(start, resetAt ?? start)
        guard end > effectiveStart else { return 0 }
        return max(0, Int(end.timeIntervalSince(effectiveStart).rounded()))
    }

    private static func parseLogDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: text)
    }

    private static func displayDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private static func workSeconds(in rows: [String], matching include: (String) -> Bool) -> Int {
        rows.reduce(0) { total, row in
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

    private static func frameConcatList(frameNames: [String], in frameDirectory: URL) -> String {
        guard let lastFrameName = frameNames.last else { return "" }
        var lines = frameNames.flatMap { frameName in
            [
                "file '\(concatEscapedPath(frameDirectory.appendingPathComponent(frameName).path))'",
                "duration 1"
            ]
        }
        lines.append("file '\(concatEscapedPath(frameDirectory.appendingPathComponent(lastFrameName).path))'")
        return lines.joined(separator: "\n") + "\n"
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
} else if CommandLine.arguments.count >= 3, CommandLine.arguments[1] == "--submit-report-date" {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let date = formatter.date(from: CommandLine.arguments[2]) else {
        fputs("日付は yyyy-MM-dd で指定してください。\n", stderr)
        exit(2)
    }
    let form = ReportSubmissionForm(
        date: date,
        reporter: RecorderSettings.reporterName,
        workPlan: RecorderSettings.defaultWorkPlan,
        workContent: CommandLine.arguments.count >= 4 ? CommandLine.arguments[3] : RecorderSettings.defaultWorkContent,
        nextTask: CommandLine.arguments.count >= 5 ? CommandLine.arguments[4] : RecorderSettings.defaultNextTask,
        status: RecorderSettings.defaultReportStatus,
        message: RecorderSettings.defaultReportMessage,
        videoLink: "",
        driveFolderURL: RecorderSettings.driveFolderURL,
        videoDriveFolderURL: RecorderSettings.videoDriveFolderURL
    )
    do {
        let result = try OneFPSRecorder.submitReport(form)
        print("report=\(result.reportURL.path)")
        print("video=\(result.submittedVideoURL.path)")
        print("hours=\(result.hours)")
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
        exit(1)
    }
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
