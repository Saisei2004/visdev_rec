import AppKit

final class PopupCustomizationWindowController: NSWindowController {
    private let presetPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let widthField = NSTextField()
    private let showTitle = NSButton(checkboxWithTitle: "状態と録画時間", target: nil, action: nil)
    private let showMessage = NSButton(checkboxWithTitle: "メッセージ", target: nil, action: nil)
    private let showCapture = NSButton(checkboxWithTitle: "録画画面の切り替え", target: nil, action: nil)
    private let showSettings = NSButton(checkboxWithTitle: "設定ボタン", target: nil, action: nil)
    private let showControl = NSButton(checkboxWithTitle: "開始・停止ボタン", target: nil, action: nil)
    private let showReport = NSButton(checkboxWithTitle: "日報ボタン", target: nil, action: nil)
    private let showTasks = NSButton(checkboxWithTitle: "タスクボタン", target: nil, action: nil)
    private let idleText = NSTextField()
    private let recordingText = NSTextField()
    private let startText = NSTextField()
    private let stopText = NSTextField()
    private let settingsText = NSTextField()
    private let reportText = NSTextField()
    private let tasksText = NSTextField()
    private let onSave: () -> Void

    init(onSave: @escaping () -> Void) {
        self.onSave = onSave
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 610),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "録画ポップアップをカスタマイズ"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func showWindow(_ sender: Any?) {
        loadValues()
        super.showWindow(sender)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let intro = NSTextField(labelWithString: "最小構成は録画状態を示す点だけを表示します。カスタムでは項目・幅・表記を自由に変更できます。")
        intro.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        intro.frame = NSRect(x: 24, y: 548, width: 600, height: 24)
        content.addSubview(intro)

        addLabel("表示モード", x: 24, y: 504, width: 110, content: content)
        presetPopup.addItems(withTitles: ["標準", "最小（状態点のみ）", "カスタム"])
        presetPopup.frame = NSRect(x: 150, y: 498, width: 230, height: 30)
        content.addSubview(presetPopup)

        addLabel("カスタム幅", x: 400, y: 504, width: 90, content: content)
        widthField.frame = NSRect(x: 492, y: 498, width: 90, height: 28)
        let px = NSTextField(labelWithString: "px")
        px.frame = NSRect(x: 586, y: 504, width: 30, height: 20)
        content.addSubview(widthField)
        content.addSubview(px)

        let itemsTitle = NSTextField(labelWithString: "表示する項目")
        itemsTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        itemsTitle.frame = NSRect(x: 24, y: 452, width: 120, height: 20)
        content.addSubview(itemsTitle)
        let checks = [showTitle, showMessage, showCapture, showSettings, showControl, showReport, showTasks]
        for (index, check) in checks.enumerated() {
            let column = index % 2
            let row = index / 2
            check.frame = NSRect(x: 150 + column * 230, y: 448 - row * 32, width: 220, height: 22)
            content.addSubview(check)
        }

        let labelsTitle = NSTextField(labelWithString: "表記")
        labelsTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        labelsTitle.frame = NSRect(x: 24, y: 304, width: 120, height: 20)
        content.addSubview(labelsTitle)

        let fields: [(String, NSTextField)] = [
            ("待機中", idleText),
            ("録画中", recordingText),
            ("開始ボタン", startText),
            ("停止ボタン", stopText),
            ("設定ボタン", settingsText),
            ("日報ボタン", reportText),
            ("タスクボタン", tasksText)
        ]
        for (index, pair) in fields.enumerated() {
            let column = index % 2
            let row = index / 2
            let x = CGFloat(24 + column * 310)
            let y = CGFloat(268 - row * 48)
            addLabel(pair.0, x: x, y: y + 6, width: 100, content: content)
            pair.1.frame = NSRect(x: x + 108, y: y, width: 170, height: 28)
            content.addSubview(pair.1)
        }

        let reset = NSButton(title: "標準に戻す", target: self, action: #selector(resetPressed))
        reset.bezelStyle = .rounded
        reset.frame = NSRect(x: 24, y: 18, width: 110, height: 30)
        let close = NSButton(title: "閉じる", target: self, action: #selector(closePressed))
        close.bezelStyle = .rounded
        close.frame = NSRect(x: 464, y: 18, width: 76, height: 30)
        let save = NSButton(title: "保存", target: self, action: #selector(savePressed))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        save.frame = NSRect(x: 550, y: 18, width: 76, height: 30)
        [reset, close, save].forEach(content.addSubview)
    }

    private func addLabel(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, content: NSView) {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        label.frame = NSRect(x: x, y: y, width: width, height: 20)
        content.addSubview(label)
    }

    private func loadValues() {
        switch SharedSettings.popupPreset {
        case "minimal": presetPopup.selectItem(at: 1)
        case "custom": presetPopup.selectItem(at: 2)
        default: presetPopup.selectItem(at: 0)
        }
        widthField.stringValue = String(Int(SharedSettings.popupWidth))
        showTitle.state = SharedSettings.popupShowTitle ? .on : .off
        showMessage.state = SharedSettings.popupShowMessage ? .on : .off
        showCapture.state = SharedSettings.popupShowCaptureTarget ? .on : .off
        showSettings.state = SharedSettings.popupShowSettingsButton ? .on : .off
        showControl.state = SharedSettings.popupShowControlButton ? .on : .off
        showReport.state = SharedSettings.popupShowReportButton ? .on : .off
        showTasks.state = SharedSettings.popupShowTasksButton ? .on : .off
        idleText.stringValue = SharedSettings.popupIdleText
        recordingText.stringValue = SharedSettings.popupRecordingText
        startText.stringValue = SharedSettings.popupStartText
        stopText.stringValue = SharedSettings.popupStopText
        settingsText.stringValue = SharedSettings.popupSettingsText
        reportText.stringValue = SharedSettings.popupReportText
        tasksText.stringValue = SharedSettings.popupTasksText
    }

    @objc private func savePressed() {
        SharedSettings.popupPreset = ["standard", "minimal", "custom"][max(0, presetPopup.indexOfSelectedItem)]
        SharedSettings.popupWidth = CGFloat(Int(widthField.stringValue) ?? 520)
        SharedSettings.popupShowTitle = showTitle.state == .on
        SharedSettings.popupShowMessage = showMessage.state == .on
        SharedSettings.popupShowCaptureTarget = showCapture.state == .on
        SharedSettings.popupShowSettingsButton = showSettings.state == .on
        SharedSettings.popupShowControlButton = showControl.state == .on
        SharedSettings.popupShowReportButton = showReport.state == .on
        SharedSettings.popupShowTasksButton = showTasks.state == .on
        SharedSettings.popupIdleText = idleText.stringValue
        SharedSettings.popupRecordingText = recordingText.stringValue
        SharedSettings.popupStartText = startText.stringValue
        SharedSettings.popupStopText = stopText.stringValue
        SharedSettings.popupSettingsText = settingsText.stringValue
        SharedSettings.popupReportText = reportText.stringValue
        SharedSettings.popupTasksText = tasksText.stringValue
        onSave()
        close()
    }

    @objc private func resetPressed() {
        presetPopup.selectItem(at: 0)
        widthField.stringValue = "520"
        [showTitle, showMessage, showCapture, showSettings, showControl].forEach { $0.state = .on }
        [showReport, showTasks].forEach { $0.state = .off }
        idleText.stringValue = "1FPS 待機中"
        recordingText.stringValue = "録画"
        startText.stringValue = "開始"
        stopText.stringValue = "停止"
        settingsText.stringValue = "設定"
        reportText.stringValue = "日報"
        tasksText.stringValue = "タスク"
    }

    @objc private func closePressed() { close() }
}

final class AutomationSettingsWindowController: NSWindowController {
    private let workspaceField = NSTextField()
    private let channelField = NSTextField()
    private let reporterField = NSTextField()
    private let threadTimestampField = NSTextField()
    private let webhookField = NSSecureTextField()
    private let gmailQueryField = NSTextField()
    private let taskLedgerField = NSTextField()
    private let taskHubField = NSTextField()
    private let githubReposView = NSTextView()
    private let extraReferencesView = NSTextView()
    private let onSave: () -> Void

    init(onSave: @escaping () -> Void) {
        self.onSave = onSave
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 720),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "日報自動化・参照元"
        window.minSize = NSSize(width: 680, height: 680)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func showWindow(_ sender: Any?) {
        loadValues()
        super.showWindow(sender)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let intro = NSTextField(labelWithString: "Codex/Claude Skillが日報下書きを作る時に読む参照元です。Webhookはキーチェーンへ安全に保存します。")
        intro.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        intro.frame = NSRect(x: 24, y: 660, width: 710, height: 22)
        content.addSubview(intro)

        let fields: [(String, NSTextField, String)] = [
            ("Slackワークスペース", workspaceField, "Visitas"),
            ("Slack日報チャンネル", channelField, "#日報"),
            ("Slackでの名前", reporterField, "@名前"),
            ("個人スレッドID", threadTimestampField, "例: 1720000000.000000"),
            ("Incoming Webhook", webhookField, "https://hooks.slack.com/..."),
            ("Gmail Notta検索", gmailQueryField, "from:(notta.ai) ..."),
            ("タスク台帳", taskLedgerField, "~/visitas-tasks/tasks.json"),
            ("Task Hub URL", taskHubField, "http://127.0.0.1:7700")
        ]
        var y: CGFloat = 618
        for (labelText, field, placeholder) in fields {
            let label = NSTextField(labelWithString: labelText)
            label.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
            label.frame = NSRect(x: 24, y: y + 6, width: 150, height: 20)
            field.frame = NSRect(x: 182, y: y, width: 548, height: 28)
            field.placeholderString = placeholder
            content.addSubview(label)
            content.addSubview(field)
            y -= 42
        }

        addTextArea(label: "GitHub Issues（1行1repo）", textView: githubReposView, y: 190, height: 92, content: content)
        addTextArea(label: "追加の参照内容", textView: extraReferencesView, y: 60, height: 112, content: content)

        let webhookHint = NSTextField(labelWithString: "Webhook未設定でも、Codex/Claude SkillはSlack連携から投稿できます。外部投稿前は必ず確認します。")
        webhookHint.font = NSFont.systemFont(ofSize: 11)
        webhookHint.textColor = .secondaryLabelColor
        webhookHint.frame = NSRect(x: 182, y: 296, width: 548, height: 18)
        content.addSubview(webhookHint)

        let close = NSButton(title: "閉じる", target: self, action: #selector(closePressed))
        close.bezelStyle = .rounded
        close.frame = NSRect(x: 564, y: 20, width: 76, height: 30)
        let save = NSButton(title: "保存", target: self, action: #selector(savePressed))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        save.frame = NSRect(x: 650, y: 20, width: 76, height: 30)
        content.addSubview(close)
        content.addSubview(save)
    }

    private func addTextArea(label: String, textView: NSTextView, y: CGFloat, height: CGFloat, content: NSView) {
        let labelView = NSTextField(labelWithString: label)
        labelView.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        labelView.frame = NSRect(x: 24, y: y + height - 22, width: 150, height: 20)
        let scroll = NSScrollView(frame: NSRect(x: 182, y: y, width: 548, height: height))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: 12)
        textView.autoresizingMask = [.width]
        scroll.documentView = textView
        content.addSubview(labelView)
        content.addSubview(scroll)
    }

    private func loadValues() {
        workspaceField.stringValue = SharedSettings.slackWorkspace
        channelField.stringValue = SharedSettings.slackDailyChannel
        reporterField.stringValue = SharedSettings.slackReporterName
        threadTimestampField.stringValue = SharedSettings.slackDailyThreadTimestamp
        webhookField.stringValue = OneFPSSecretStore.slackWebhookURL
        gmailQueryField.stringValue = SharedSettings.gmailNottaQuery
        taskLedgerField.stringValue = SharedSettings.taskLedgerPath
        taskHubField.stringValue = SharedSettings.taskHubURL
        githubReposView.string = SharedSettings.githubIssueRepositories
        extraReferencesView.string = SharedSettings.extraReportReferences
    }

    @objc private func savePressed() {
        SharedSettings.slackWorkspace = workspaceField.stringValue
        SharedSettings.slackDailyChannel = channelField.stringValue
        SharedSettings.slackReporterName = reporterField.stringValue
        SharedSettings.slackDailyThreadTimestamp = threadTimestampField.stringValue
        OneFPSSecretStore.slackWebhookURL = webhookField.stringValue
        SharedSettings.gmailNottaQuery = gmailQueryField.stringValue
        SharedSettings.taskLedgerPath = taskLedgerField.stringValue
        SharedSettings.taskHubURL = taskHubField.stringValue
        SharedSettings.githubIssueRepositories = githubReposView.string
        SharedSettings.extraReportReferences = extraReferencesView.string
        onSave()
        close()
    }

    @objc private func closePressed() { close() }
}
