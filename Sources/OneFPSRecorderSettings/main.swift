import AppKit

enum SharedSettings {
    private static let defaults = UserDefaults.standard
    private static let recordingNameKey = "recordingName"
    private static let showOverlayKey = "showRecordingOverlay"
    private static let showPauseOverlayKey = "showPauseOverlay"
    private static let showMonthlyScoreKey = "showMonthlyScore"
    private static let hourlyRateKey = "hourlyRate"
    private static let monthlyGoalKey = "monthlyGoal"
    private static let monthlyScoreResetAtPrefix = "monthlyScoreResetAt."
    private static let glowWhenGoalReachedKey = "glowWhenGoalReached"
    private static let pauseOnSleepKey = "pauseOnSleep"
    private static let pauseOnMouseIdleKey = "pauseOnMouseIdle"
    private static let mouseIdleMinutesKey = "mouseIdleMinutes"

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

final class SettingsDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let nameField = NSTextField(string: SharedSettings.recordingName)
    private let overlayCheckbox = NSButton(checkboxWithTitle: "録画中パネルを表示する", target: nil, action: nil)
    private let pauseOverlayCheckbox = NSButton(checkboxWithTitle: "一時停止パネルを表示する", target: nil, action: nil)
    private let monthlyScoreCheckbox = NSButton(checkboxWithTitle: "月間スコアを表示する", target: nil, action: nil)
    private let hourlyRateField = NSTextField(string: "\(SharedSettings.hourlyRate)")
    private let monthlyGoalField = NSTextField(string: "\(SharedSettings.monthlyGoal)")
    private let glowCheckbox = NSButton(checkboxWithTitle: "目標達成時に光らせる", target: nil, action: nil)
    private let resetMonthlyScoreButton = NSButton(title: "今月を初期化", target: nil, action: nil)
    private let pauseOnSleepCheckbox = NSButton(checkboxWithTitle: "スリープ時に一時停止する", target: nil, action: nil)
    private let pauseOnMouseIdleCheckbox = NSButton(checkboxWithTitle: "マウス無操作で一時停止する", target: nil, action: nil)
    private let mouseIdleMinutesField = NSTextField(string: "\(SharedSettings.mouseIdleMinutes)")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildWindow()
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 456),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "1FPS録画 設定"
        window.isReleasedWhenClosed = false
        window.delegate = self

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 430))
        window.contentView = content

        let title = NSTextField(labelWithString: "保存名")
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        title.frame = NSRect(x: 30, y: 360, width: 80, height: 20)

        nameField.frame = NSRect(x: 130, y: 354, width: 320, height: 28)
        nameField.placeholderString = "録画"

        let hint = NSTextField(labelWithString: "ファイル名は MMDD_名前.mp4 になります。名前変更時は既存動画も更新します。")
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 130, y: 326, width: 340, height: 18)

        overlayCheckbox.state = SharedSettings.showOverlay ? .on : .off
        overlayCheckbox.frame = NSRect(x: 130, y: 294, width: 240, height: 22)

        pauseOverlayCheckbox.state = SharedSettings.showPauseOverlay ? .on : .off
        pauseOverlayCheckbox.frame = NSRect(x: 130, y: 268, width: 240, height: 22)

        let scoreTitle = NSTextField(labelWithString: "月間スコア")
        scoreTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        scoreTitle.frame = NSRect(x: 30, y: 238, width: 90, height: 20)

        monthlyScoreCheckbox.state = SharedSettings.showMonthlyScore ? .on : .off
        monthlyScoreCheckbox.frame = NSRect(x: 130, y: 238, width: 200, height: 22)

        resetMonthlyScoreButton.target = self
        resetMonthlyScoreButton.action = #selector(resetMonthlyScorePressed)
        resetMonthlyScoreButton.bezelStyle = .rounded
        resetMonthlyScoreButton.frame = NSRect(x: 350, y: 232, width: 120, height: 28)

        let hourlyRateLabel = NSTextField(labelWithString: "係数")
        hourlyRateLabel.font = NSFont.systemFont(ofSize: 12)
        hourlyRateLabel.frame = NSRect(x: 130, y: 202, width: 60, height: 20)

        hourlyRateField.frame = NSRect(x: 190, y: 196, width: 100, height: 28)
        hourlyRateField.placeholderString = "2000"

        let goalLabel = NSTextField(labelWithString: "月末ライン")
        goalLabel.font = NSFont.systemFont(ofSize: 12)
        goalLabel.frame = NSRect(x: 310, y: 202, width: 78, height: 20)

        monthlyGoalField.frame = NSRect(x: 390, y: 196, width: 80, height: 28)
        monthlyGoalField.placeholderString = "100000"

        glowCheckbox.state = SharedSettings.glowWhenGoalReached ? .on : .off
        glowCheckbox.frame = NSRect(x: 130, y: 166, width: 220, height: 22)

        let scoreHint = NSTextField(labelWithString: "係数の標準値は 2000。月末ラインを超えると録画中パネルを発光できます。")
        scoreHint.font = NSFont.systemFont(ofSize: 11)
        scoreHint.textColor = .secondaryLabelColor
        scoreHint.frame = NSRect(x: 130, y: 140, width: 340, height: 18)

        let pauseTitle = NSTextField(labelWithString: "一時停止")
        pauseTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        pauseTitle.frame = NSRect(x: 30, y: 112, width: 90, height: 20)

        pauseOnSleepCheckbox.state = SharedSettings.pauseOnSleep ? .on : .off
        pauseOnSleepCheckbox.frame = NSRect(x: 130, y: 112, width: 220, height: 22)

        pauseOnMouseIdleCheckbox.state = SharedSettings.pauseOnMouseIdle ? .on : .off
        pauseOnMouseIdleCheckbox.frame = NSRect(x: 130, y: 82, width: 220, height: 22)

        let idleMinutesLabel = NSTextField(labelWithString: "無操作分")
        idleMinutesLabel.font = NSFont.systemFont(ofSize: 12)
        idleMinutesLabel.frame = NSRect(x: 330, y: 84, width: 60, height: 20)

        mouseIdleMinutesField.frame = NSRect(x: 390, y: 78, width: 80, height: 28)
        mouseIdleMinutesField.placeholderString = "5"

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
        content.addSubview(closeButton)
        content.addSubview(saveButton)
    }

    @objc private func savePressed() {
        let newName = SharedSettings.sanitizedRecordingName(nameField.stringValue)
        SharedSettings.recordingName = newName
        SharedSettings.showOverlay = overlayCheckbox.state == .on
        SharedSettings.showPauseOverlay = pauseOverlayCheckbox.state == .on
        SharedSettings.showMonthlyScore = monthlyScoreCheckbox.state == .on
        SharedSettings.hourlyRate = Int(hourlyRateField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 2000
        SharedSettings.monthlyGoal = Int(monthlyGoalField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 100000
        SharedSettings.glowWhenGoalReached = glowCheckbox.state == .on
        SharedSettings.pauseOnSleep = pauseOnSleepCheckbox.state == .on
        SharedSettings.pauseOnMouseIdle = pauseOnMouseIdleCheckbox.state == .on
        SharedSettings.mouseIdleMinutes = Int(mouseIdleMinutesField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 5
        renameExistingRecordings(to: newName)
        rewriteRecordingLogFileNames(to: newName)
        syncAllDerivedLogs()
        NSApp.terminate(nil)
    }

    @objc private func closePressed() {
        NSApp.terminate(nil)
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
