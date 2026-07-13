import AppKit
import Foundation

struct DailyReportDraft: Codable {
    var date: Date
    var reporter: String
    var workPlan: String
    var done: String
    var blockers: String
    var tomorrow: String
    var status: String
    var message: String
    var videoLink: String

    init(date: Date) {
        self.date = date
        reporter = RecorderSettings.reporterName
        workPlan = RecorderSettings.defaultWorkPlan
        done = RecorderSettings.defaultWorkContent
        blockers = "なし"
        tomorrow = RecorderSettings.defaultNextTask
        status = RecorderSettings.defaultReportStatus
        message = RecorderSettings.defaultReportMessage
        videoLink = ""
    }

    init(date: Date, existing: StoredReportEntry?) {
        self.init(date: date)
        guard let existing else { return }
        reporter = existing.reporter
        workPlan = existing.workPlan
        done = existing.workContent
        tomorrow = existing.nextTask
        status = existing.status
        videoLink = existing.videoLink == existing.videoFileName ? "" : existing.videoLink

        let lines = existing.message.components(separatedBy: .newlines)
        let prefix = "詰まった / 判断待ち:"
        if let first = lines.first, first.hasPrefix(prefix) {
            blockers = String(first.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            message = lines.dropFirst().joined(separator: "\n")
        } else if existing.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blockers = "なし"
            message = ""
        } else {
            blockers = existing.message
            message = ""
        }
    }

    var form: ReportSubmissionForm {
        let combinedMessage: String
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedMessage.isEmpty {
            combinedMessage = blockers
        } else {
            combinedMessage = "詰まった / 判断待ち: \(blockers)\n\(trimmedMessage)"
        }
        return ReportSubmissionForm(
            date: date,
            reporter: reporter,
            workPlan: workPlan,
            workContent: done,
            nextTask: tomorrow,
            status: status,
            message: combinedMessage,
            videoLink: videoLink,
            driveFolderURL: RecorderSettings.driveFolderURL,
            videoDriveFolderURL: RecorderSettings.videoDriveFolderURL
        )
    }
}

struct SubmissionReceipt: Codable {
    var date: String
    var localPrepared: Bool
    var videoUploadedToDrive: Bool
    var driveReportUpdated: Bool
    var slackPosted: Bool
    var updatedAt: String
}

struct DailyReportSkillItem: Codable {
    var date: String
    var reporter: String?
    var workPlan: String?
    var done: String?
    var blockers: String?
    var tomorrow: String?
    var status: String?
    var message: String?
    var videoLink: String?
}

struct DailyReportSkillRequest: Codable {
    var reports: [DailyReportSkillItem]
    var destinations: ReportSubmissionDestinations
}

private struct VisitasTaskHubFile: Decodable {
    var meta: VisitasTaskHubMeta
    var tasks: [VisitasTaskHubEntry]
}

private struct VisitasTaskHubMeta: Decodable {
    var owner: String?
    var title: String?
    var updated: String?
    var lastSweep: VisitasTaskHubSweep?

    enum CodingKeys: String, CodingKey {
        case owner, title, updated
        case lastSweep = "last_sweep"
    }
}

private struct VisitasTaskHubSweep: Decodable {
    var at: String?
    var mode: String?
    var note: String?
    var sources: [String: String]?
}

private struct VisitasTaskHubEntry: Decodable {
    var id: String
    var title: String
    var status: String
    var priority: String
    var source: String?
    var ref: String?
    var url: String?
    var nextAction: String?
    var blocker: String?
    var due: String?

    enum CodingKeys: String, CodingKey {
        case id, title, status, priority, source, ref, url, blocker, due
        case nextAction = "next_action"
    }
}

extension OneFPSRecorder {
    static func unsubmittedReportDates(inMonthContaining date: Date = Date()) -> [Date] {
        let calendar = Calendar.current
        let monthDirectory = reportMonthDirectory(for: date)
        let submitted = Set(storedReportEntries(for: date).map(\.date))
        let receipts = Dictionary(uniqueKeysWithValues: submissionReceipts(for: date).map { ($0.date, $0) })
        guard let dayDirectories = try? FileManager.default.contentsOfDirectory(
            at: monthDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return dayDirectories.compactMap { directory -> Date? in
            guard directory.lastPathComponent.range(of: #"^\d{4}$"#, options: .regularExpression) != nil,
                  (try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                  let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil),
                  files.contains(where: { $0.pathExtension.lowercased() == "mp4" && !$0.lastPathComponent.hasPrefix(".") }),
                  let day = dateFromMonthDay(directory.lastPathComponent, monthDate: date)
            else { return nil }
            let key = isoDay(day)
            let receiptIncomplete = receipts[key].map {
                !$0.videoUploadedToDrive || !$0.driveReportUpdated || !$0.slackPosted
            } ?? false
            guard (!submitted.contains(key) || receiptIncomplete),
                  calendar.compare(day, to: Date(), toGranularity: .day) != .orderedDescending else {
                return nil
            }
            return day
        }.sorted()
    }

    static func reportDraft(for date: Date) -> DailyReportDraft {
        let key = isoDay(date)
        return DailyReportDraft(date: date, existing: storedReportEntries(for: date).first { $0.date == key })
    }

    static func reportAutomationConfigurationJSON() -> String {
        let taskDirectory = URL(fileURLWithPath: NSString(string: RecorderSettings.taskLedgerPath).expandingTildeInPath)
            .deletingLastPathComponent()
        let config: [String: Any] = [
            "slackWorkspace": RecorderSettings.slackWorkspace,
            "slackDailyChannel": RecorderSettings.slackDailyChannel,
            "slackReporterName": RecorderSettings.slackReporterName,
            "slackDailyThreadConfigured": !RecorderSettings.slackDailyThreadTimestamp.isEmpty,
            "gmailNottaQuery": RecorderSettings.gmailNottaQuery,
            "taskLedgerPath": RecorderSettings.taskLedgerPath,
            "taskAgentPath": taskDirectory.appendingPathComponent("AGENT.md").path,
            "taskKnowledgePath": taskDirectory.appendingPathComponent("KNOWLEDGE.md").path,
            "taskHubURL": RecorderSettings.taskHubURL,
            "githubIssueRepositories": RecorderSettings.githubIssueRepositories
                .split(separator: "\n").map(String.init),
            "extraReferences": RecorderSettings.extraReportReferences,
            "slackWebhookConfigured": !OneFPSSecretStore.slackWebhookURL.isEmpty
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys]) else {
            return "{}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func reportCandidatesJSON(inMonthContaining date: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        let drafts = unsubmittedReportDates(inMonthContaining: date).map { day -> [String: Any] in
            let draft = reportDraft(for: day)
            let receipt = submissionReceipts(for: day).first { $0.date == isoDay(day) }
            return [
                "date": isoDay(day),
                "video": existingVideoPathForAutomation(on: day) ?? "",
                "workMinutes": dailyWorkSeconds(for: day) / 60,
                "submissionState": [
                    "videoUploadedToDrive": receipt?.videoUploadedToDrive ?? false,
                    "driveReportUpdated": receipt?.driveReportUpdated ?? false,
                    "slackPosted": receipt?.slackPosted ?? false
                ],
                "defaultDraft": [
                    "reporter": draft.reporter,
                    "workPlan": draft.workPlan,
                    "done": draft.done,
                    "blockers": draft.blockers,
                    "tomorrow": draft.tomorrow,
                    "status": draft.status,
                    "message": draft.message
                ]
            ]
        }
        let result: [String: Any] = [
            "generatedAt": formatter.string(from: Date()),
            "month": monthKey(date),
            "unsubmitted": drafts,
            "configuration": tryJSONDictionary(reportAutomationConfigurationJSON())
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) else {
            return "{}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func submitSkillRequest(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let request = try JSONDecoder().decode(DailyReportSkillRequest.self, from: data)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var completed: [[String: Any]] = []
        var failed: [[String: Any]] = []
        for item in request.reports {
            guard let date = formatter.date(from: item.date) else {
                failed.append(["date": item.date, "error": "日付はyyyy-MM-ddで指定してください"])
                continue
            }
            let blockers = item.blockers?.trimmingCharacters(in: .whitespacesAndNewlines)
            let messageParts = [
                blockers.map { "詰まった / 判断待ち: \($0)" },
                item.message?.trimmingCharacters(in: .whitespacesAndNewlines)
            ].compactMap { $0 }.filter { !$0.isEmpty }
            let form = ReportSubmissionForm(
                date: date,
                reporter: item.reporter ?? RecorderSettings.reporterName,
                workPlan: item.workPlan ?? RecorderSettings.defaultWorkPlan,
                workContent: item.done ?? RecorderSettings.defaultWorkContent,
                nextTask: item.tomorrow ?? RecorderSettings.defaultNextTask,
                status: item.status ?? RecorderSettings.defaultReportStatus,
                message: messageParts.isEmpty ? RecorderSettings.defaultReportMessage : messageParts.joined(separator: "\n"),
                videoLink: item.videoLink ?? "",
                driveFolderURL: RecorderSettings.driveFolderURL,
                videoDriveFolderURL: RecorderSettings.videoDriveFolderURL
            )
            do {
                let result = try submitReport(form, destinations: request.destinations)
                completed.append([
                    "date": item.date,
                    "report": result.reportURL.path,
                    "video": result.submittedVideoURL.path,
                    "minutes": result.minutes,
                    "slackText": slackDailyReportText(form: form)
                ])
            } catch {
                failed.append(["date": item.date, "error": error.localizedDescription])
            }
        }
        let result: [String: Any] = ["completed": completed, "failed": failed]
        let output = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return String(data: output, encoding: .utf8) ?? "{}"
    }

    static func markSlackPosted(on date: Date) {
        recordSubmissionReceipt(
            date: date,
            videoUploadedToDrive: false,
            driveReportUpdated: false,
            slackPosted: true
        )
    }

    static func postSlackDailyReport(form: ReportSubmissionForm) throws {
        let webhook = OneFPSSecretStore.slackWebhookURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: webhook),
              url.scheme == "https",
              url.host == "hooks.slack.com"
        else {
            throw NSError(
                domain: "OneFPSRecorder",
                code: 1201,
                userInfo: [NSLocalizedDescriptionKey: "Slack Incoming Webhookが未設定です。設定の「日報・参照元...」からVisitas #日報用Webhookを登録するか、visitas-daily-report Skillから投稿してください。"]
            )
        }

        let threadTimestamp = RecorderSettings.slackDailyThreadTimestamp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !threadTimestamp.isEmpty else {
            throw NSError(
                domain: "OneFPSRecorder",
                code: 1204,
                userInfo: [NSLocalizedDescriptionKey: "#日報は個人スレッドへの投稿です。「日報・参照元...」で個人スレッドIDを設定するか、visitas-daily-report Skillから投稿してください。"]
            )
        }

        let payload = [
            "text": slackDailyReportText(form: form),
            "thread_ts": threadTimestamp
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let semaphore = DispatchSemaphore(value: 0)
        var responseError: Error?
        var statusCode = 0
        var responseText = ""
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            responseError = error
            statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            responseText = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            semaphore.signal()
        }
        task.resume()
        guard semaphore.wait(timeout: .now() + 30) == .success else {
            task.cancel()
            throw NSError(domain: "OneFPSRecorder", code: 1202, userInfo: [NSLocalizedDescriptionKey: "Slack投稿がタイムアウトしました。"])
        }
        if let responseError { throw responseError }
        guard (200..<300).contains(statusCode), responseText.trimmingCharacters(in: .whitespacesAndNewlines) == "ok" else {
            throw NSError(domain: "OneFPSRecorder", code: 1203, userInfo: [NSLocalizedDescriptionKey: "Slack投稿に失敗しました（HTTP \(statusCode)）。"])
        }
    }

    static func slackDailyReportText(form: ReportSubmissionForm) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = "M/d"
        let name = RecorderSettings.slackReporterName.trimmingCharacters(in: .whitespacesAndNewlines)
        let mention = name.hasPrefix("@") ? name : "@\(name)"
        let blockers = blockersText(from: form.message)
        return """
        📅 \(dateFormatter.string(from: form.date)) \(mention)
        ✅ やった
        ・\(bulletText(form.workContent))
        🚧 詰まった / 判断待ち
        ・\(bulletText(blockers, fallback: "なし"))
        ➡️ 明日
        ・\(bulletText(form.nextTask))
        """
    }

    static func recordSubmissionReceipt(
        date: Date,
        videoUploadedToDrive: Bool,
        driveReportUpdated: Bool,
        slackPosted: Bool
    ) {
        let url = receiptURL(for: date)
        var receipts: [SubmissionReceipt] = []
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([SubmissionReceipt].self, from: data) {
            receipts = decoded
        }
        let key = isoDay(date)
        let existing = receipts.first(where: { $0.date == key })
        receipts.removeAll { $0.date == key }
        receipts.append(SubmissionReceipt(
            date: key,
            localPrepared: true,
            videoUploadedToDrive: (existing?.videoUploadedToDrive ?? false) || videoUploadedToDrive,
            driveReportUpdated: (existing?.driveReportUpdated ?? false) || driveReportUpdated,
            slackPosted: (existing?.slackPosted ?? false) || slackPosted,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        ))
        receipts.sort { $0.date < $1.date }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? encoder.encode(receipts) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func reportMonthDirectory(for date: Date) -> URL {
        recordingsDirectory.appendingPathComponent(monthKey(date), isDirectory: true)
    }

    private static func storedReportEntries(for date: Date) -> [StoredReportEntry] {
        let url = reportMonthDirectory(for: date).appendingPathComponent("業務報告データ-\(monthKey(date)).json")
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([StoredReportEntry].self, from: data)
        else { return [] }
        return entries
    }

    private static func receiptURL(for date: Date) -> URL {
        reportMonthDirectory(for: date).appendingPathComponent("提出状態-\(monthKey(date)).json")
    }

    private static func submissionReceipts(for date: Date) -> [SubmissionReceipt] {
        guard let data = try? Data(contentsOf: receiptURL(for: date)),
              let receipts = try? JSONDecoder().decode([SubmissionReceipt].self, from: data)
        else { return [] }
        return receipts
    }

    private static func existingVideoPathForAutomation(on date: Date) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMdd"
        let day = formatter.string(from: date)
        let directory = reportMonthDirectory(for: date).appendingPathComponent(day, isDirectory: true)
        return (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))?
            .first(where: { $0.pathExtension.lowercased() == "mp4" && !$0.lastPathComponent.hasPrefix(".") })?.path
    }

    private static func dateFromMonthDay(_ monthDay: String, monthDate: Date) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: "\(monthKey(monthDate))-\(monthDay.suffix(2))")
    }

    private static func monthKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    private static func isoDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func tryJSONDictionary(_ text: String) -> [String: Any] {
        guard let data = text.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return value
    }

    private static func blockersText(from message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "なし" }
        if trimmed.hasPrefix("詰まった / 判断待ち:") {
            return trimmed.dropFirst("詰まった / 判断待ち:".count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private static func bulletText(_ value: String, fallback: String = "未入力") -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        return trimmed.replacingOccurrences(of: "\n", with: "\n・")
    }
}

final class DailyReportBatchWindowController: NSWindowController, NSWindowDelegate {
    private var drafts: [DailyReportDraft]
    private var currentIndex = 0
    private let onSubmit: ([ReportSubmissionForm], ReportSubmissionDestinations) -> Void
    private let datePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let reporterField = NSTextField()
    private let workPlanField = NSTextField()
    private let doneView = NSTextView()
    private let blockersView = NSTextView()
    private let tomorrowView = NSTextView()
    private let statusField = NSTextField()
    private let messageView = NSTextView()
    private let videoLinkField = NSTextField()
    private let videoDriveCheckbox = NSButton(checkboxWithTitle: "今日の動画をDriveへ投稿", target: nil, action: nil)
    private let driveReportCheckbox = NSButton(checkboxWithTitle: "Driveの報告書を更新", target: nil, action: nil)
    private let slackCheckbox = NSButton(checkboxWithTitle: "Slackの日報へ投稿", target: nil, action: nil)

    init(dates: [Date], onSubmit: @escaping ([ReportSubmissionForm], ReportSubmissionDestinations) -> Void) {
        drafts = dates.map { OneFPSRecorder.reportDraft(for: $0) }
        self.onSubmit = onSubmit
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 710),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "今月の未提出日をまとめて投稿"
        window.minSize = NSSize(width: 780, height: 650)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildUI()
        reloadDatePopup()
        loadDraft(at: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let title = NSTextField(labelWithString: "動画があり、未作成またはDrive・Slackへの投稿が未完了の日です。日付ごとに全項目を編集できます。")
        title.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        title.frame = NSRect(x: 24, y: 650, width: 850, height: 22)
        content.addSubview(title)

        let dateLabel = NSTextField(labelWithString: "編集する日")
        dateLabel.frame = NSRect(x: 24, y: 610, width: 100, height: 20)
        datePopup.frame = NSRect(x: 130, y: 604, width: 220, height: 30)
        datePopup.target = self
        datePopup.action = #selector(dateChanged)
        content.addSubview(dateLabel)
        content.addSubview(datePopup)

        addField(label: "担当者", field: reporterField, y: 566, content: content)
        addField(label: "業務プラン", field: workPlanField, y: 528, content: content)
        addTextView(label: "✅ やった", textView: doneView, y: 430, height: 82, content: content)
        addTextView(label: "🚧 詰まった / 判断待ち", textView: blockersView, y: 332, height: 82, content: content)
        addTextView(label: "➡️ 明日", textView: tomorrowView, y: 234, height: 82, content: content)
        addField(label: "業務状態", field: statusField, y: 194, content: content)
        addTextView(label: "Visitasへのメッセージ", textView: messageView, y: 100, height: 76, content: content)
        addField(label: "動画リンク（任意）", field: videoLinkField, y: 62, content: content)

        videoDriveCheckbox.frame = NSRect(x: 24, y: 22, width: 210, height: 22)
        driveReportCheckbox.frame = NSRect(x: 236, y: 22, width: 190, height: 22)
        slackCheckbox.frame = NSRect(x: 428, y: 22, width: 180, height: 22)
        content.addSubview(videoDriveCheckbox)
        content.addSubview(driveReportCheckbox)
        content.addSubview(slackCheckbox)

        let cancel = NSButton(title: "閉じる", target: self, action: #selector(closePressed))
        cancel.bezelStyle = .rounded
        cancel.frame = NSRect(x: 690, y: 16, width: 82, height: 30)
        let submit = NSButton(title: "全日を一括投稿", target: self, action: #selector(submitPressed))
        submit.bezelStyle = .rounded
        submit.keyEquivalent = "\r"
        submit.frame = NSRect(x: 780, y: 16, width: 104, height: 30)
        content.addSubview(cancel)
        content.addSubview(submit)
    }

    private func addField(label: String, field: NSTextField, y: CGFloat, content: NSView) {
        let labelView = NSTextField(labelWithString: label)
        labelView.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        labelView.frame = NSRect(x: 24, y: y + 6, width: 170, height: 20)
        field.frame = NSRect(x: 200, y: y, width: 674, height: 28)
        content.addSubview(labelView)
        content.addSubview(field)
    }

    private func addTextView(label: String, textView: NSTextView, y: CGFloat, height: CGFloat, content: NSView) {
        let labelView = NSTextField(labelWithString: label)
        labelView.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        labelView.frame = NSRect(x: 24, y: y + height - 22, width: 170, height: 20)
        let scroll = NSScrollView(frame: NSRect(x: 200, y: y, width: 674, height: height))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: 12)
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        scroll.documentView = textView
        content.addSubview(labelView)
        content.addSubview(scroll)
    }

    private func reloadDatePopup() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd (E)"
        datePopup.removeAllItems()
        drafts.forEach { datePopup.addItem(withTitle: formatter.string(from: $0.date)) }
    }

    @objc private func dateChanged() {
        saveCurrentDraft()
        currentIndex = max(0, datePopup.indexOfSelectedItem)
        loadDraft(at: currentIndex)
    }

    private func saveCurrentDraft() {
        guard drafts.indices.contains(currentIndex) else { return }
        drafts[currentIndex].reporter = reporterField.stringValue
        drafts[currentIndex].workPlan = workPlanField.stringValue
        drafts[currentIndex].done = doneView.string
        drafts[currentIndex].blockers = blockersView.string
        drafts[currentIndex].tomorrow = tomorrowView.string
        drafts[currentIndex].status = statusField.stringValue
        drafts[currentIndex].message = messageView.string
        drafts[currentIndex].videoLink = videoLinkField.stringValue
    }

    private func loadDraft(at index: Int) {
        guard drafts.indices.contains(index) else { return }
        let draft = drafts[index]
        reporterField.stringValue = draft.reporter
        workPlanField.stringValue = draft.workPlan
        doneView.string = draft.done
        blockersView.string = draft.blockers
        tomorrowView.string = draft.tomorrow
        statusField.stringValue = draft.status
        messageView.string = draft.message
        videoLinkField.stringValue = draft.videoLink
    }

    @objc private func submitPressed() {
        saveCurrentDraft()
        let destinations = ReportSubmissionDestinations(
            uploadVideoToDrive: videoDriveCheckbox.state == .on,
            updateDriveReport: driveReportCheckbox.state == .on,
            postToSlack: slackCheckbox.state == .on
        )
        let alert = NSAlert()
        alert.messageText = "\(drafts.count)日分を一括処理しますか？"
        var actions = ["ローカル報告書を更新"]
        if destinations.uploadVideoToDrive { actions.append("動画をDriveへ投稿") }
        if destinations.updateDriveReport { actions.append("Drive報告書を更新") }
        if destinations.postToSlack { actions.append("\(RecorderSettings.slackWorkspace) \(RecorderSettings.slackDailyChannel)へ投稿") }
        alert.informativeText = actions.map { "・\($0)" }.joined(separator: "\n")
        alert.addButton(withTitle: "実行")
        alert.addButton(withTitle: "キャンセル")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        onSubmit(drafts.map(\.form), destinations)
        close()
    }

    @objc private func closePressed() { close() }
    func windowWillClose(_ notification: Notification) { NSApp.setActivationPolicy(.accessory) }
}

final class VisitasTaskWindowController: NSWindowController {
    private let textView = NSTextView()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 640),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Visitas タスク管理"
        window.minSize = NSSize(width: 680, height: 480)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func showWindow(_ sender: Any?) {
        refresh()
        super.showWindow(sender)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let scroll = NSScrollView(frame: NSRect(x: 20, y: 62, width: 820, height: 550))
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        textView.isEditable = false
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.autoresizingMask = [.width]
        scroll.documentView = textView
        content.addSubview(scroll)

        let refreshButton = NSButton(title: "更新", target: self, action: #selector(refreshPressed))
        refreshButton.frame = NSRect(x: 20, y: 18, width: 80, height: 30)
        let ledgerButton = NSButton(title: "台帳を開く", target: self, action: #selector(openLedger))
        ledgerButton.frame = NSRect(x: 110, y: 18, width: 110, height: 30)
        let hubButton = NSButton(title: "Task Hubを開く", target: self, action: #selector(openTaskHub))
        hubButton.frame = NSRect(x: 230, y: 18, width: 130, height: 30)
        let issuesButton = NSButton(title: "GitHub Issues", target: self, action: #selector(openIssues))
        issuesButton.frame = NSRect(x: 370, y: 18, width: 120, height: 30)
        [refreshButton, ledgerButton, hubButton, issuesButton].forEach(content.addSubview)
    }

    @objc private func refreshPressed() { refresh() }

    private func refresh() {
        let trackerPath = NSString(string: RecorderSettings.taskLedgerPath).expandingTildeInPath
        var sections = ["# Visitas Task Hub\n\n\(renderTaskHub(at: trackerPath))"]
        let repositories = RecorderSettings.githubIssueRepositories.split(separator: "\n").map(String.init)
        for repository in repositories {
            sections.append("# GitHub \(repository) / 自分のOpen Issue\n\n\(assignedIssues(repository: repository))")
        }
        sections.append("# 日報の参照元\n\nSlack: \(RecorderSettings.slackWorkspace) \(RecorderSettings.slackDailyChannel)\nGmail: \(RecorderSettings.gmailNottaQuery)\nTask Hub: \(RecorderSettings.taskHubURL)")
        textView.string = sections.joined(separator: "\n\n---\n\n")
    }

    private func renderTaskHub(at path: String) -> String {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let hub = try? JSONDecoder().decode(VisitasTaskHubFile.self, from: data)
        else { return "正典タスク台帳を読めません: \(path)" }

        let priorityOrder = ["P0": 0, "P1": 1, "P2": 2, "P3": 3]
        let active = hub.tasks.filter { $0.status != "done" }.sorted {
            let left = priorityOrder[$0.priority] ?? 9
            let right = priorityOrder[$1.priority] ?? 9
            return left == right ? $0.id < $1.id : left < right
        }
        var lines = [
            "正典: \(path)",
            "更新: \(hub.meta.updated ?? "不明") / 未完了: \(active.count)件 / 全体: \(hub.tasks.count)件"
        ]
        if let sweep = hub.meta.lastSweep {
            lines.append("最終棚卸し: \(sweep.at ?? "不明") [\(sweep.mode ?? "-")] \(sweep.note ?? "")")
        }
        lines.append("")
        if active.isEmpty {
            lines.append("現在の未完了タスクはありません。次回の日報作成時に参照元を確認して差分を取り込みます。")
        } else {
            for task in active {
                lines.append("\(task.id) [\(task.priority)/\(task.status)] \(task.title)")
                if let next = task.nextAction, !next.isEmpty { lines.append("  次: \(next)") }
                if let blocker = task.blocker, !blocker.isEmpty { lines.append("  ブロッカー: \(blocker)") }
                if let due = task.due, !due.isEmpty { lines.append("  期限: \(due)") }
                if let ref = task.ref, !ref.isEmpty { lines.append("  根拠: \(ref)") }
                lines.append("")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func assignedIssues(repository: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/gh",
            "/opt/homebrew/bin/gh",
            "/usr/local/bin/gh"
        ]
        guard let ghPath = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return "GitHub CLIが見つかりません。設定済みのGitHub Issuesリンクから確認してください。"
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ghPath)
        process.arguments = ["issue", "list", "-R", repository, "--state", "open", "--assignee", "@me", "--limit", "100"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "担当中のOpen Issueはありません。" : text
        } catch {
            return "GitHub Issueを取得できません: \(error.localizedDescription)"
        }
    }

    @objc private func openLedger() {
        NSWorkspace.shared.open(URL(fileURLWithPath: NSString(string: RecorderSettings.taskLedgerPath).expandingTildeInPath))
    }

    @objc private func openTaskHub() {
        let trackerPath = NSString(string: RecorderSettings.taskLedgerPath).expandingTildeInPath
        let startScript = URL(fileURLWithPath: trackerPath)
            .deletingLastPathComponent()
            .appendingPathComponent("start.sh")
        if FileManager.default.fileExists(atPath: startScript.path) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [startScript.path, "--no-open"]
            try? process.run()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let url = URL(string: RecorderSettings.taskHubURL) { NSWorkspace.shared.open(url) }
        }
    }

    @objc private func openIssues() {
        if let url = URL(string: "https://github.com/visit-as/Visitas/issues/assigned/Saisei2004") { NSWorkspace.shared.open(url) }
    }
}
