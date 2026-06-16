import AppKit

enum SharedSettings {
    private static let defaults = UserDefaults(suiteName: "local.codex.OneFPSRecorder") ?? .standard
    private static let recordingNameKey = "recordingName"
    private static let showOverlayKey = "showRecordingOverlay"
    private static let showMonthlyScoreKey = "showMonthlyScore"
    private static let hourlyRateKey = "hourlyRate"
    private static let monthlyGoalKey = "monthlyGoal"
    private static let glowWhenGoalReachedKey = "glowWhenGoalReached"

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
        get { max(0, defaults.integer(forKey: monthlyGoalKey)) }
        set { defaults.set(max(0, newValue), forKey: monthlyGoalKey) }
    }

    static var glowWhenGoalReached: Bool {
        get { defaults.bool(forKey: glowWhenGoalReachedKey) }
        set { defaults.set(newValue, forKey: glowWhenGoalReachedKey) }
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
    private let monthlyScoreCheckbox = NSButton(checkboxWithTitle: "月間スコアを表示する", target: nil, action: nil)
    private let hourlyRateField = NSTextField(string: "\(SharedSettings.hourlyRate)")
    private let monthlyGoalField = NSTextField(string: "\(SharedSettings.monthlyGoal)")
    private let glowCheckbox = NSButton(checkboxWithTitle: "目標達成時に光らせる", target: nil, action: nil)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildWindow()
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "1FPS録画 設定"
        window.isReleasedWhenClosed = false
        window.delegate = self

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 340))
        window.contentView = content

        let title = NSTextField(labelWithString: "保存名")
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        title.frame = NSRect(x: 30, y: 270, width: 80, height: 20)

        nameField.frame = NSRect(x: 130, y: 264, width: 320, height: 28)
        nameField.placeholderString = "録画"

        let hint = NSTextField(labelWithString: "ファイル名は MMDD_名前.mp4 になります。名前変更時は既存動画も更新します。")
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 130, y: 236, width: 340, height: 18)

        overlayCheckbox.state = SharedSettings.showOverlay ? .on : .off
        overlayCheckbox.frame = NSRect(x: 130, y: 204, width: 240, height: 22)

        let scoreTitle = NSTextField(labelWithString: "月間スコア")
        scoreTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        scoreTitle.frame = NSRect(x: 30, y: 160, width: 90, height: 20)

        monthlyScoreCheckbox.state = SharedSettings.showMonthlyScore ? .on : .off
        monthlyScoreCheckbox.frame = NSRect(x: 130, y: 160, width: 200, height: 22)

        let hourlyRateLabel = NSTextField(labelWithString: "係数")
        hourlyRateLabel.font = NSFont.systemFont(ofSize: 12)
        hourlyRateLabel.frame = NSRect(x: 130, y: 124, width: 60, height: 20)

        hourlyRateField.frame = NSRect(x: 190, y: 118, width: 100, height: 28)
        hourlyRateField.placeholderString = "2000"

        let goalLabel = NSTextField(labelWithString: "月末ライン")
        goalLabel.font = NSFont.systemFont(ofSize: 12)
        goalLabel.frame = NSRect(x: 310, y: 124, width: 78, height: 20)

        monthlyGoalField.frame = NSRect(x: 390, y: 118, width: 80, height: 28)
        monthlyGoalField.placeholderString = "0"

        glowCheckbox.state = SharedSettings.glowWhenGoalReached ? .on : .off
        glowCheckbox.frame = NSRect(x: 130, y: 88, width: 220, height: 22)

        let scoreHint = NSTextField(labelWithString: "係数の標準値は 2000。月末ラインを超えると録画中パネルを発光できます。")
        scoreHint.font = NSFont.systemFont(ofSize: 11)
        scoreHint.textColor = .secondaryLabelColor
        scoreHint.frame = NSRect(x: 130, y: 62, width: 340, height: 18)

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
        content.addSubview(scoreTitle)
        content.addSubview(monthlyScoreCheckbox)
        content.addSubview(hourlyRateLabel)
        content.addSubview(hourlyRateField)
        content.addSubview(goalLabel)
        content.addSubview(monthlyGoalField)
        content.addSubview(glowCheckbox)
        content.addSubview(scoreHint)
        content.addSubview(closeButton)
        content.addSubview(saveButton)
    }

    @objc private func savePressed() {
        let newName = SharedSettings.sanitizedRecordingName(nameField.stringValue)
        SharedSettings.recordingName = newName
        SharedSettings.showOverlay = overlayCheckbox.state == .on
        SharedSettings.showMonthlyScore = monthlyScoreCheckbox.state == .on
        SharedSettings.hourlyRate = Int(hourlyRateField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 2000
        SharedSettings.monthlyGoal = Int(monthlyGoalField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        SharedSettings.glowWhenGoalReached = glowCheckbox.state == .on
        renameExistingRecordings(to: newName)
        rewriteRecordingLogFileNames(to: newName)
        NSApp.terminate(nil)
    }

    @objc private func closePressed() {
        NSApp.terminate(nil)
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
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: monthURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for fileURL in files where fileURL.pathExtension.lowercased() == "mp4" {
                guard let day = recordingDay(from: fileURL.deletingPathExtension().lastPathComponent) else { continue }
                let newURL = monthURL.appendingPathComponent("\(day)_\(newName).mp4")
                guard fileURL.path != newURL.path else { continue }
                if FileManager.default.fileExists(atPath: newURL.path) {
                    _ = mergeVideoFile(fileURL, into: newURL)
                    continue
                }
                try? FileManager.default.moveItem(at: fileURL, to: newURL)
            }
        }
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

            let logURL = monthURL.appendingPathComponent("録画区間ログ-\(month).txt")
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
