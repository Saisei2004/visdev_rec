import AppKit

enum SharedSettings {
    private static let defaults = UserDefaults.standard
    private static let recordingNameKey = "recordingName"
    private static let showOverlayKey = "showRecordingOverlay"
    private static let showPauseOverlayKey = "showPauseOverlay"
    private static let showMenuBarStatusKey = "showMenuBarStatus"
    private static let showMonthlyScoreKey = "showMonthlyScore"
    private static let hourlyRateKey = "hourlyRate"
    private static let monthlyGoalKey = "monthlyGoal"
    private static let monthlyScoreResetAtPrefix = "monthlyScoreResetAt."
    private static let glowWhenGoalReachedKey = "glowWhenGoalReached"
    private static let pauseOnSleepKey = "pauseOnSleep"
    private static let pauseOnMouseIdleKey = "pauseOnMouseIdle"
    private static let mouseIdleMinutesKey = "mouseIdleMinutes"
    private static let reporterNameKey = "reporterName"
    private static let driveFolderURLKey = "driveFolderURL"
    private static let videoDriveFolderURLKey = "videoDriveFolderURL"
    private static let defaultWorkPlanKey = "defaultWorkPlan"
    private static let defaultWorkContentKey = "defaultWorkContent"
    private static let defaultNextTaskKey = "defaultNextTask"
    private static let defaultReportStatusKey = "defaultReportStatus"
    private static let defaultReportMessageKey = "defaultReportMessage"
    private static let reportTemplatePathKey = "reportTemplatePath"
    private static let defaultDriveFolderURL = "https://drive.google.com/drive/folders/1W-Vc69ELQ-gtul7VVtQCs7mLMLk2LbIH"
    private static let defaultVideoDriveFolderURL = "https://drive.google.com/drive/folders/1NjjboZDYCDLAC_OhhPOBj5PmF3Rs9U_x"

    static var recordingName: String {
        get {
            let saved = defaults.string(forKey: recordingNameKey) ?? "録画"
            return sanitizedRecordingName(saved)
        }
        set {
            defaults.set(sanitizedRecordingName(newValue), forKey: recordingNameKey)
        }
    }

    static var showOverlay: Bool {
        get {
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
            if defaults.object(forKey: showMenuBarStatusKey) == nil {
                return true
            }
            return defaults.bool(forKey: showMenuBarStatusKey)
        }
        set { defaults.set(newValue, forKey: showMenuBarStatusKey) }
    }

    static var showMonthlyScore: Bool {
        get { defaults.bool(forKey: showMonthlyScoreKey) }
        set { defaults.set(newValue, forKey: showMonthlyScoreKey) }
    }

    static var hourlyRate: Int {
        get {
            let value = defaults.integer(forKey: hourlyRateKey)
            return value > 0 ? value : 2000
        }
        set { defaults.set(max(0, newValue), forKey: hourlyRateKey) }
    }

    static var monthlyGoal: Int {
        get {
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
        get { defaults.bool(forKey: glowWhenGoalReachedKey) }
        set { defaults.set(newValue, forKey: glowWhenGoalReachedKey) }
    }

    static var pauseOnSleep: Bool {
        get {
            if defaults.object(forKey: pauseOnSleepKey) == nil {
                return true
            }
            return defaults.bool(forKey: pauseOnSleepKey)
        }
        set { defaults.set(newValue, forKey: pauseOnSleepKey) }
    }

    static var pauseOnMouseIdle: Bool {
        get { defaults.bool(forKey: pauseOnMouseIdleKey) }
        set { defaults.set(newValue, forKey: pauseOnMouseIdleKey) }
    }

    static var mouseIdleMinutes: Int {
        get {
            let value = defaults.integer(forKey: mouseIdleMinutesKey)
            return value > 0 ? value : 5
        }
        set { defaults.set(min(max(1, newValue), 180), forKey: mouseIdleMinutesKey) }
    }

    static var reporterName: String {
        get { savedText(forKey: reporterNameKey, fallback: "馬場幸成") }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: reporterNameKey) }
    }

    static var driveFolderURL: String {
        get {
            let saved = defaults.string(forKey: driveFolderURLKey) ?? defaultDriveFolderURL
            let trimmed = saved.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? defaultDriveFolderURL : trimmed
        }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: driveFolderURLKey) }
    }

    static var videoDriveFolderURL: String {
        get {
            let saved = defaults.string(forKey: videoDriveFolderURLKey) ?? defaultVideoDriveFolderURL
            let trimmed = saved.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? defaultVideoDriveFolderURL : trimmed
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
        let saved = defaults.string(forKey: key) ?? fallback
        let trimmed = saved.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    static func sanitizedRecordingName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "録画" : trimmed
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let sanitized = fallback.components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = sanitized.isEmpty ? "録画" : sanitized
        return String(safeName.prefix(48))
    }
}

final class ReportDefaultsWindowController: NSWindowController {
    private let reporterField = NSTextField(string: SharedSettings.reporterName)
    private let planField = NSTextField(string: SharedSettings.defaultWorkPlan)
    private let contentField = NSTextField(string: SharedSettings.defaultWorkContent)
    private let nextTaskField = NSTextField(string: SharedSettings.defaultNextTask)
    private let statusField = NSTextField(string: SharedSettings.defaultReportStatus)
    private let messageField = NSTextField(string: SharedSettings.defaultReportMessage)
    private let driveURLField = NSTextField(string: SharedSettings.driveFolderURL)
    private let videoDriveURLField = NSTextField(string: SharedSettings.videoDriveFolderURL)
    private let templatePathField = NSTextField(string: SharedSettings.reportTemplatePath)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 458),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "業務報告 初期値"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        reporterField.stringValue = SharedSettings.reporterName
        planField.stringValue = SharedSettings.defaultWorkPlan
        contentField.stringValue = SharedSettings.defaultWorkContent
        nextTaskField.stringValue = SharedSettings.defaultNextTask
        statusField.stringValue = SharedSettings.defaultReportStatus
        messageField.stringValue = SharedSettings.defaultReportMessage
        driveURLField.stringValue = SharedSettings.driveFolderURL
        videoDriveURLField.stringValue = SharedSettings.videoDriveFolderURL
        templatePathField.stringValue = SharedSettings.reportTemplatePath
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }
        let rows: [(String, NSTextField, String)] = [
            ("担当者", reporterField, ""),
            ("業務プラン", planField, ""),
            ("業務内容", contentField, "空でも可"),
            ("次回までのTask", nextTaskField, "空でも可"),
            ("業務は順調ですか？", statusField, ""),
            ("Visitasへのメッセージ", messageField, "空でも可"),
            ("報告書Driveフォルダ", driveURLField, ""),
            ("動画Driveフォルダ", videoDriveURLField, ""),
            ("報告書テンプレート", templatePathField, "~/Downloads/報告書（6月分）.docx")
        ]

        var y = 382
        for (label, field, placeholder) in rows {
            let labelView = NSTextField(labelWithString: label)
            labelView.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
            labelView.frame = NSRect(x: 28, y: y + 6, width: 130, height: 20)
            field.frame = NSRect(x: 166, y: y, width: 420, height: 28)
            field.placeholderString = placeholder
            contentView.addSubview(labelView)
            contentView.addSubview(field)
            y -= 38
        }

        let hint = NSTextField(labelWithString: "ここで保存した値が、業務報告提出画面の初期値になります。提出画面で変更して提出した値も次回初期値になります。")
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 28, y: 54, width: 560, height: 18)
        contentView.addSubview(hint)

        let cancelButton = NSButton(title: "閉じる", target: self, action: #selector(closePressed))
        cancelButton.bezelStyle = .rounded
        cancelButton.frame = NSRect(x: 410, y: 18, width: 82, height: 30)
        contentView.addSubview(cancelButton)

        let saveButton = NSButton(title: "保存", target: self, action: #selector(savePressed))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.frame = NSRect(x: 504, y: 18, width: 82, height: 30)
        contentView.addSubview(saveButton)
    }

    @objc private func savePressed() {
        SharedSettings.reporterName = reporterField.stringValue
        SharedSettings.defaultWorkPlan = planField.stringValue
        SharedSettings.defaultWorkContent = contentField.stringValue
        SharedSettings.defaultNextTask = nextTaskField.stringValue
        SharedSettings.defaultReportStatus = statusField.stringValue
        SharedSettings.defaultReportMessage = messageField.stringValue
        SharedSettings.driveFolderURL = driveURLField.stringValue
        SharedSettings.videoDriveFolderURL = videoDriveURLField.stringValue
        SharedSettings.reportTemplatePath = templatePathField.stringValue
        close()
    }

    @objc private func closePressed() {
        close()
    }
}

final class SettingsDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var advancedWindow: NSWindow?
    private var reportDefaultsWindow: ReportDefaultsWindowController?
    private let nameField = NSTextField(string: SharedSettings.recordingName)
    private let overlayCheckbox = NSButton(checkboxWithTitle: "録画中パネルを表示する", target: nil, action: nil)
    private let pauseOverlayCheckbox = NSButton(checkboxWithTitle: "一時停止パネルを表示する", target: nil, action: nil)
    private let menuBarStatusCheckbox = NSButton(checkboxWithTitle: "メニューバーに録画状態を表示する", target: nil, action: nil)
    private let monthlyScoreCheckbox = NSButton(checkboxWithTitle: "月間スコアを表示する", target: nil, action: nil)
    private let hourlyRateField = NSTextField(string: "\(SharedSettings.hourlyRate)")
    private let monthlyGoalField = NSTextField(string: "\(SharedSettings.monthlyGoal)")
    private let glowCheckbox = NSButton(checkboxWithTitle: "目標達成時に光らせる", target: nil, action: nil)
    private let resetMonthlyScoreButton = NSButton(title: "今月を初期化", target: nil, action: nil)
    private let pauseOnSleepCheckbox = NSButton(checkboxWithTitle: "スリープ時に一時停止する", target: nil, action: nil)
    private let pauseOnMouseIdleCheckbox = NSButton(checkboxWithTitle: "マウス無操作で一時停止する", target: nil, action: nil)
    private let mouseIdleMinutesField = NSTextField(string: "\(SharedSettings.mouseIdleMinutes)")
    private let reportDefaultsButton = NSButton(title: "業務報告初期値...", target: nil, action: nil)
    private let advancedButton = NSButton(title: "詳細設定...", target: nil, action: nil)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildWindow()
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 276),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "1FPS録画 設定"
        window.isReleasedWhenClosed = false
        window.delegate = self

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 250))
        window.contentView = content

        let title = NSTextField(labelWithString: "保存名")
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        title.frame = NSRect(x: 30, y: 190, width: 80, height: 20)

        nameField.frame = NSRect(x: 130, y: 184, width: 320, height: 28)
        nameField.placeholderString = "録画"

        let hint = NSTextField(labelWithString: "ファイル名は MMDD_名前.mp4 になります。名前変更時は既存動画も更新します。")
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 130, y: 156, width: 340, height: 18)

        overlayCheckbox.state = SharedSettings.showOverlay ? .on : .off
        overlayCheckbox.frame = NSRect(x: 130, y: 124, width: 240, height: 22)

        pauseOverlayCheckbox.state = SharedSettings.showPauseOverlay ? .on : .off
        pauseOverlayCheckbox.frame = NSRect(x: 130, y: 96, width: 240, height: 22)

        menuBarStatusCheckbox.state = SharedSettings.showMenuBarStatus ? .on : .off
        menuBarStatusCheckbox.frame = NSRect(x: 130, y: 68, width: 300, height: 22)

        advancedButton.target = self
        advancedButton.action = #selector(openAdvancedSettings)
        advancedButton.bezelStyle = .rounded
        advancedButton.frame = NSRect(x: 30, y: 22, width: 110, height: 30)

        let closeButton = NSButton(title: "閉じる", target: self, action: #selector(closePressed))
        closeButton.bezelStyle = .rounded
        closeButton.frame = NSRect(x: 308, y: 22, width: 76, height: 30)

        let saveButton = NSButton(title: "保存", target: self, action: #selector(savePressed))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.frame = NSRect(x: 394, y: 22, width: 76, height: 30)

        content.addSubview(title)
        content.addSubview(nameField)
        content.addSubview(hint)
        content.addSubview(overlayCheckbox)
        content.addSubview(pauseOverlayCheckbox)
        content.addSubview(menuBarStatusCheckbox)
        content.addSubview(advancedButton)
        content.addSubview(closeButton)
        content.addSubview(saveButton)
    }

    @objc private func savePressed() {
        let newName = SharedSettings.sanitizedRecordingName(nameField.stringValue)
        SharedSettings.recordingName = newName
        SharedSettings.showOverlay = overlayCheckbox.state == .on
        SharedSettings.showPauseOverlay = pauseOverlayCheckbox.state == .on
        SharedSettings.showMenuBarStatus = menuBarStatusCheckbox.state == .on
        renameExistingRecordings(to: newName)
        rewriteRecordingLogFileNames(to: newName)
        syncAllDerivedLogs()
        NSApp.terminate(nil)
    }

    @objc private func closePressed() {
        NSApp.terminate(nil)
    }

    @objc private func openAdvancedSettings() {
        if advancedWindow == nil {
            buildAdvancedWindow()
        }
        monthlyScoreCheckbox.state = SharedSettings.showMonthlyScore ? .on : .off
        hourlyRateField.stringValue = "\(SharedSettings.hourlyRate)"
        monthlyGoalField.stringValue = "\(SharedSettings.monthlyGoal)"
        glowCheckbox.state = SharedSettings.glowWhenGoalReached ? .on : .off
        pauseOnSleepCheckbox.state = SharedSettings.pauseOnSleep ? .on : .off
        pauseOnMouseIdleCheckbox.state = SharedSettings.pauseOnMouseIdle ? .on : .off
        mouseIdleMinutesField.stringValue = "\(SharedSettings.mouseIdleMinutes)"
        advancedWindow?.center()
        advancedWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildAdvancedWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 334),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "1FPS録画 詳細設定"
        window.isReleasedWhenClosed = false
        advancedWindow = window

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 308))
        window.contentView = content

        let scoreTitle = NSTextField(labelWithString: "月間スコア")
        scoreTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        scoreTitle.frame = NSRect(x: 30, y: 254, width: 90, height: 20)

        monthlyScoreCheckbox.state = SharedSettings.showMonthlyScore ? .on : .off
        monthlyScoreCheckbox.frame = NSRect(x: 130, y: 254, width: 200, height: 22)

        resetMonthlyScoreButton.target = self
        resetMonthlyScoreButton.action = #selector(resetMonthlyScorePressed)
        resetMonthlyScoreButton.bezelStyle = .rounded
        resetMonthlyScoreButton.frame = NSRect(x: 350, y: 248, width: 120, height: 28)

        let hourlyRateLabel = NSTextField(labelWithString: "係数")
        hourlyRateLabel.font = NSFont.systemFont(ofSize: 12)
        hourlyRateLabel.frame = NSRect(x: 130, y: 218, width: 60, height: 20)

        hourlyRateField.frame = NSRect(x: 190, y: 212, width: 100, height: 28)
        hourlyRateField.placeholderString = "2000"

        let goalLabel = NSTextField(labelWithString: "月末ライン")
        goalLabel.font = NSFont.systemFont(ofSize: 12)
        goalLabel.frame = NSRect(x: 310, y: 218, width: 78, height: 20)

        monthlyGoalField.frame = NSRect(x: 390, y: 212, width: 80, height: 28)
        monthlyGoalField.placeholderString = "100000"

        glowCheckbox.state = SharedSettings.glowWhenGoalReached ? .on : .off
        glowCheckbox.frame = NSRect(x: 130, y: 182, width: 220, height: 22)

        let scoreHint = NSTextField(labelWithString: "係数の標準値は 2000。月末ラインを超えると録画中パネルが発光できます。")
        scoreHint.font = NSFont.systemFont(ofSize: 11)
        scoreHint.textColor = .secondaryLabelColor
        scoreHint.frame = NSRect(x: 130, y: 156, width: 340, height: 18)

        let pauseTitle = NSTextField(labelWithString: "一時停止")
        pauseTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        pauseTitle.frame = NSRect(x: 30, y: 124, width: 90, height: 20)

        pauseOnSleepCheckbox.state = SharedSettings.pauseOnSleep ? .on : .off
        pauseOnSleepCheckbox.frame = NSRect(x: 130, y: 124, width: 220, height: 22)

        pauseOnMouseIdleCheckbox.state = SharedSettings.pauseOnMouseIdle ? .on : .off
        pauseOnMouseIdleCheckbox.frame = NSRect(x: 130, y: 94, width: 220, height: 22)

        let idleMinutesLabel = NSTextField(labelWithString: "無操作分")
        idleMinutesLabel.font = NSFont.systemFont(ofSize: 12)
        idleMinutesLabel.frame = NSRect(x: 330, y: 96, width: 60, height: 20)

        mouseIdleMinutesField.frame = NSRect(x: 390, y: 90, width: 80, height: 28)
        mouseIdleMinutesField.placeholderString = "5"

        reportDefaultsButton.target = self
        reportDefaultsButton.action = #selector(openReportDefaults)
        reportDefaultsButton.bezelStyle = .rounded
        reportDefaultsButton.frame = NSRect(x: 30, y: 22, width: 150, height: 30)

        let closeButton = NSButton(title: "閉じる", target: self, action: #selector(closeAdvancedPressed))
        closeButton.bezelStyle = .rounded
        closeButton.frame = NSRect(x: 308, y: 22, width: 76, height: 30)

        let saveButton = NSButton(title: "保存", target: self, action: #selector(saveAdvancedPressed))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.frame = NSRect(x: 394, y: 22, width: 76, height: 30)

        content.addSubview(scoreTitle)
        content.addSubview(monthlyScoreCheckbox)
        content.addSubview(resetMonthlyScoreButton)
        content.addSubview(hourlyRateLabel)
        content.addSubview(hourlyRateField)
        content.addSubview(goalLabel)
        content.addSubview(monthlyGoalField)
        content.addSubview(glowCheckbox)
        content.addSubview(scoreHint)
        content.addSubview(pauseTitle)
        content.addSubview(pauseOnSleepCheckbox)
        content.addSubview(pauseOnMouseIdleCheckbox)
        content.addSubview(idleMinutesLabel)
        content.addSubview(mouseIdleMinutesField)
        content.addSubview(reportDefaultsButton)
        content.addSubview(closeButton)
        content.addSubview(saveButton)
    }

    @objc private func saveAdvancedPressed() {
        SharedSettings.showMonthlyScore = monthlyScoreCheckbox.state == .on
        SharedSettings.hourlyRate = Int(hourlyRateField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 2000
        SharedSettings.monthlyGoal = Int(monthlyGoalField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 100000
        SharedSettings.glowWhenGoalReached = glowCheckbox.state == .on
        SharedSettings.pauseOnSleep = pauseOnSleepCheckbox.state == .on
        SharedSettings.pauseOnMouseIdle = pauseOnMouseIdleCheckbox.state == .on
        SharedSettings.mouseIdleMinutes = Int(mouseIdleMinutesField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 5
        syncAllDerivedLogs()
        advancedWindow?.orderOut(nil)
    }

    @objc private func closeAdvancedPressed() {
        advancedWindow?.orderOut(nil)
    }

    @objc private func openReportDefaults() {
        reportDefaultsWindow = ReportDefaultsWindowController()
        reportDefaultsWindow?.showWindow(nil)
    }

    @objc private func resetMonthlyScorePressed() {
        let alert = NSAlert()
        alert.messageText = "今月の月間スコアを初期化しますか？"
        alert.informativeText = "録画動画、録画区間ログ、日別合計は消しません。月間スコアだけ、この時刻以降の作業時間から再計算します。"
        alert.addButton(withTitle: "初期化")
        alert.addButton(withTitle: "キャンセル")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        SharedSettings.resetMonthlyScore()
        syncAllDerivedLogs()
    }

    private func renameExistingRecordings(to newName: String) {
        let recordingsDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies", isDirectory: true)
            .appendingPathComponent("1FPS録画", isDirectory: true)

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
                let newURL = fileURL.deletingLastPathComponent().appendingPathComponent("\(day)_\(newName).mp4")
                guard fileURL.path != newURL.path else { continue }
                if FileManager.default.fileExists(atPath: newURL.path) {
                    _ = mergeVideoFile(fileURL, into: newURL)
                    continue
                }
                try? FileManager.default.moveItem(at: fileURL, to: newURL)
            }
        }
    }

    private func canonicalDailyVideoURLs(in monthURL: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: monthURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var urls: [URL] = []
        for case let fileURL as URL in enumerator {
            if fileURL.pathComponents.contains("バックアップ") { continue }
            if fileURL.pathExtension.lowercased() == "mp4",
               let basename = Optional(fileURL.deletingPathExtension().lastPathComponent),
               !basename.hasPrefix("."),
               !basename.contains(".before-"),
               recordingDay(from: basename) != nil {
                urls.append(fileURL)
            }
        }
        return urls
    }

    private func mergeVideoFile(_ sourceURL: URL, into targetURL: URL) -> Bool {
        let directory = targetURL.deletingLastPathComponent()
        let stamp = timestamp()
        let listURL = directory.appendingPathComponent(".rename-merge-\(stamp)-\(UUID().uuidString).txt")
        let tempURL = directory.appendingPathComponent(".rename-merge-\(stamp)-\(UUID().uuidString).mp4")
        let backupURL = directory.appendingPathComponent(".rename-backup-\(stamp)-\(UUID().uuidString).mp4")
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

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private func concatEscapedPath(_ path: String) -> String {
        path.replacingOccurrences(of: "'", with: "'\\''")
    }

    private func rewriteRecordingLogFileNames(to newName: String) {
        let targetName = SharedSettings.sanitizedRecordingName(newName)
        let recordingsDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies", isDirectory: true)
            .appendingPathComponent("1FPS録画", isDirectory: true)

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
                    let monthDay = dayText.replacingOccurrences(of: "-", with: "").suffix(4)
                    guard monthDay.count == 4 else { return line }

                    var updatedColumns = columns
                    updatedColumns[3] = "\(monthDay)_\(targetName).mp4"
                    return updatedColumns.joined(separator: "\t")
                }

                try? rewrittenLines.joined(separator: "\n").write(to: logURL, atomically: true, encoding: .utf8)
            }
        }
    }

    private var recordingsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies", isDirectory: true)
            .appendingPathComponent("1FPS録画", isDirectory: true)
    }

    private func syncAllDerivedLogs() {
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
            syncDerivedLogs(monthURL: monthURL, month: month)
        }
    }

    private func syncDerivedLogs(monthURL: URL, month: String) {
        let rows = activeRecordingLogURLs(in: monthURL, month: month).flatMap { logURL in
            ((try? String(contentsOf: logURL, encoding: .utf8)) ?? "")
                .split(separator: "\n")
                .dropFirst()
                .map(String.init)
        }
        guard !rows.isEmpty else { return }

        var dailyTotals: [String: (seconds: Int, count: Int)] = [:]
        let resetAt = SharedSettings.monthlyScoreResetAt(for: monthDate(from: month) ?? Date())
        var scoreSeconds = 0
        var scoreCount = 0
        for line in rows {
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard columns.count >= 3 else { continue }
            let seconds = parsedDurationSeconds(columns[2])
            guard seconds > 0 else { continue }
            let day = String(columns[0].prefix(10))
            let current = dailyTotals[day] ?? (0, 0)
            dailyTotals[day] = (current.seconds + seconds, current.count + 1)
            guard let startedAt = parseLogDate(columns[0]) else {
                if resetAt == nil {
                    scoreSeconds += seconds
                    scoreCount += 1
                }
                continue
            }
            let endedAt = (columns.count >= 2 ? parseLogDate(columns[1]) : nil)
                ?? startedAt.addingTimeInterval(TimeInterval(seconds))
            let included = overlapSeconds(start: startedAt, end: endedAt, resetAt: resetAt)
            if included > 0 {
                scoreSeconds += included
                scoreCount += 1
            }
        }

        let dailyLines = dailyTotals.keys.sorted().map { day -> String in
            let value = dailyTotals[day] ?? (0, 0)
            return "\(day)\t\(formattedDuration(value.seconds))\t\(value.seconds)秒\t\(value.count)"
        }
        let dailyOutput = "日付\t合計作業時間\t合計秒数\t記録回数\n" + dailyLines.joined(separator: "\n") + "\n"
        try? dailyOutput.write(
            to: monthURL.appendingPathComponent("日別合計作業時間-\(month).txt"),
            atomically: true,
            encoding: .utf8
        )

        let earned = Int((Double(scoreSeconds) / 3600.0 * Double(SharedSettings.hourlyRate)).rounded())
        var scoreLines = [
            "項目\t値",
            "月\t\(month)",
            "合計作業時間\t\(formattedDuration(scoreSeconds))",
            "合計秒数\t\(scoreSeconds)秒",
            "記録回数\t\(scoreCount)",
            "係数\t\(SharedSettings.hourlyRate)円/時間",
            "月間スコア\t\(earned)円",
            "月末ライン\t\(SharedSettings.monthlyGoal)円",
            "達成\t\(SharedSettings.monthlyGoal > 0 && earned >= SharedSettings.monthlyGoal ? "はい" : "いいえ")"
        ]
        if let resetAt {
            scoreLines.append("初期化日時\t\(displayDateTime(resetAt))")
        }
        let scoreOutput = scoreLines.joined(separator: "\n") + "\n"
        try? scoreOutput.write(
            to: monthURL.appendingPathComponent("月間スコア-\(month).txt"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func activeRecordingLogURLs(in monthURL: URL, month: String) -> [URL] {
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
        if urls.isEmpty {
            let legacy = monthURL.appendingPathComponent("録画区間ログ-\(month).txt")
            if FileManager.default.fileExists(atPath: legacy.path) {
                urls.append(legacy)
            }
        }
        return urls.sorted { $0.path < $1.path }
    }

    private func parsedDurationSeconds(_ text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("秒") {
            return Int(trimmed.dropLast()) ?? 0
        }
        if trimmed.hasSuffix("s") {
            return Int(trimmed.dropLast()) ?? 0
        }
        return Int(trimmed) ?? 0
    }

    private func monthDate(from month: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.date(from: month)
    }

    private func formattedDuration(_ seconds: Int) -> String {
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

    private func parseLogDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: text)
    }

    private func overlapSeconds(start: Date, end: Date, resetAt: Date?) -> Int {
        let effectiveStart = max(start, resetAt ?? start)
        guard end > effectiveStart else { return 0 }
        return max(0, Int(end.timeIntervalSince(effectiveStart).rounded()))
    }

    private func displayDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private func recordingDay(from basename: String) -> String? {
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
}

extension SettingsDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = SettingsDelegate()
app.delegate = delegate
app.run()
