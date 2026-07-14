"""Windows daily-report core compatible with OneFPSRecorder's macOS JSON formats."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import urllib.error
import urllib.request
from copy import deepcopy
from dataclasses import dataclass
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any, Protocol

from update_report_docx import regenerate_docx
from windows_credentials import read_secret


DESTINATIONS = {
    "video": ("uploadVideoToDrive", "videoUploadedToDrive"),
    "drive": ("updateDriveReport", "driveReportUpdated"),
    "slack": ("postToSlack", "slackPosted"),
}
SOURCE_NAMES = ("github_issues", "task_hub", "slack_visitas", "gmail_notta", "task_board")
REQUIRED_REPORT_FIELDS = ("date", "reporter", "workPlan", "done", "blockers", "tomorrow", "status", "message", "videoLink")


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def secret_configured(target: str) -> bool:
    """Report credential availability without failing in non-interactive sessions."""
    if os.name != "nt":
        return False
    try:
        return bool(read_secret(target))
    except OSError:
        return False


def atomic_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def default_app_data() -> Path:
    return Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local")) / "OneFPSRecorder"


def default_recordings_root() -> Path:
    configured = os.environ.get("ONEFPS_RECORDINGS_ROOT")
    return Path(configured).expanduser() if configured else Path.home() / "Videos" / "1FPS録画"


def default_config() -> dict[str, Any]:
    return {
        "version": 1,
        "recordingsRoot": str(default_recordings_root()),
        "reporter": "",
        "workPlan": "Visitasの開発",
        "done": "",
        "blockers": "なし",
        "tomorrow": "",
        "status": "順調",
        "message": "",
        "reportTemplatePath": "",
        "driveReportFolderUrl": "",
        "videoDriveFolderUrl": "",
        "slackWorkspace": "Visitas",
        "slackDailyChannel": "#日報",
        "slackReporterMention": "",
        "slackDailyThreadTs": "",
        "slackWebhookCredential": "OneFPSRecorder/SlackWebhook",
        "githubIssueRepositories": [],
        "sources": {name: {"reference": "", "status": "not_checked", "note": ""} for name in SOURCE_NAMES},
    }


def load_config(path: Path | None = None, create: bool = False) -> tuple[Path, dict[str, Any]]:
    config_path = path or default_app_data() / "report-config.json"
    config = default_config()
    try:
        saved = json.loads(config_path.read_text(encoding="utf-8"))
        if isinstance(saved, dict):
            config.update(saved)
            saved_sources = saved.get("sources") if isinstance(saved.get("sources"), dict) else {}
            config["sources"] = default_config()["sources"]
            for name, value in saved_sources.items():
                if isinstance(value, dict):
                    config["sources"].setdefault(name, {"reference": "", "status": "not_checked", "note": ""})
                    config["sources"][name].update(value)
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        pass
    if create and not config_path.exists():
        atomic_json(config_path, config)
    return config_path, config


def save_config(config: dict[str, Any], path: Path | None = None) -> Path:
    target = path or default_app_data() / "report-config.json"
    atomic_json(target, config)
    return target


def parse_day(value: str) -> date:
    return date.fromisoformat(value)


def month_directory(root: Path, day: date) -> Path:
    return root / day.strftime("%Y-%m")


def receipt_path(root: Path, day: date) -> Path:
    return month_directory(root, day) / f"提出状態-{day:%Y-%m}.json"


def entries_path(root: Path, day: date) -> Path:
    return month_directory(root, day) / f"業務報告データ-{day:%Y-%m}.json"


def load_list(path: Path) -> list[dict[str, Any]]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        return [item for item in value if isinstance(item, dict)] if isinstance(value, list) else []
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return []


def load_receipts(root: Path, day: date) -> list[dict[str, Any]]:
    return load_list(receipt_path(root, day))


def receipt_for(root: Path, day: date) -> dict[str, Any]:
    key = day.isoformat()
    existing = next((item for item in load_receipts(root, day) if item.get("date") == key), {})
    return {
        "date": key,
        "localPrepared": bool(existing.get("localPrepared", False)),
        "videoUploadedToDrive": bool(existing.get("videoUploadedToDrive", False)),
        "driveReportUpdated": bool(existing.get("driveReportUpdated", False)),
        "slackPosted": bool(existing.get("slackPosted", False)),
        "updatedAt": existing.get("updatedAt", ""),
    }


def record_receipt(root: Path, day: date, **successes: bool) -> dict[str, Any]:
    receipts = load_receipts(root, day)
    key = day.isoformat()
    current = receipt_for(root, day)
    for field in ("localPrepared", "videoUploadedToDrive", "driveReportUpdated", "slackPosted"):
        current[field] = bool(current.get(field)) or bool(successes.get(field, False))
    current["updatedAt"] = utc_now()
    receipts = [item for item in receipts if item.get("date") != key]
    receipts.append(current)
    receipts.sort(key=lambda item: str(item.get("date", "")))
    atomic_json(receipt_path(root, day), receipts)
    return current


def find_video(root: Path, day: date) -> Path | None:
    directory = month_directory(root, day) / day.strftime("%m%d")
    videos = sorted(path for path in directory.glob("*.mp4") if not path.name.startswith("."))
    return videos[0] if videos else None


def video_minutes(video: Path) -> int:
    ffprobe = shutil.which("ffprobe")
    if not ffprobe:
        return 0
    try:
        result = subprocess.run(
            [ffprobe, "-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1", str(video)],
            check=True,
            capture_output=True,
            text=True,
            timeout=30,
        )
        return max(0, int(float(result.stdout.strip()) // 60))
    except (OSError, ValueError, subprocess.SubprocessError):
        return 0


def default_draft(config: dict[str, Any], existing: dict[str, Any] | None = None) -> dict[str, str]:
    draft = {
        "reporter": str(config.get("reporter", "")),
        "workPlan": str(config.get("workPlan", "")),
        "done": str(config.get("done", "")),
        "blockers": str(config.get("blockers", "なし")),
        "tomorrow": str(config.get("tomorrow", "")),
        "status": str(config.get("status", "順調")),
        "message": str(config.get("message", "")),
        "videoLink": "",
    }
    if existing:
        draft.update({
            "reporter": str(existing.get("reporter", draft["reporter"])),
            "workPlan": str(existing.get("workPlan", draft["workPlan"])),
            "done": str(existing.get("workContent", draft["done"])),
            "tomorrow": str(existing.get("nextTask", draft["tomorrow"])),
            "status": str(existing.get("status", draft["status"])),
            "message": str(existing.get("message", draft["message"])),
            "videoLink": str(existing.get("videoLink", "")),
        })
    return draft


def public_configuration(config: dict[str, Any]) -> dict[str, Any]:
    sources = {}
    for name in SOURCE_NAMES:
        value = config.get("sources", {}).get(name, {})
        status = value.get("status") if value.get("status") in {"checked", "not_checked", "blocked"} else "not_checked"
        sources[name] = {"reference": value.get("reference", ""), "status": status, "note": value.get("note", "")}
    return {
        "recordingsRoot": config.get("recordingsRoot", ""),
        "slackWorkspace": config.get("slackWorkspace", ""),
        "slackDailyChannel": config.get("slackDailyChannel", "#日報"),
        "slackDailyThreadConfigured": bool(config.get("slackDailyThreadTs")),
        "slackWebhookConfigured": secret_configured(str(config.get("slackWebhookCredential", "OneFPSRecorder/SlackWebhook"))),
        "driveReportFolderConfigured": bool(config.get("driveReportFolderUrl")),
        "videoDriveFolderConfigured": bool(config.get("videoDriveFolderUrl") or config.get("driveReportFolderUrl")),
        "githubIssueRepositories": config.get("githubIssueRepositories", []),
        "sources": sources,
    }


def report_candidates(month: str, config: dict[str, Any]) -> dict[str, Any]:
    datetime.strptime(month, "%Y-%m")
    root = Path(str(config.get("recordingsRoot") or default_recordings_root())).expanduser()
    directory = root / month
    entries = {str(item.get("date")): item for item in load_list(directory / f"業務報告データ-{month}.json")}
    candidates = []
    for day_directory in sorted(directory.glob("[0-1][0-9][0-3][0-9]")):
        if not day_directory.is_dir():
            continue
        try:
            day = datetime.strptime(f"{month}-{day_directory.name[-2:]}", "%Y-%m-%d").date()
        except ValueError:
            continue
        if day > date.today():
            continue
        video = find_video(root, day)
        if not video:
            continue
        receipt = receipt_for(root, day)
        if all(receipt[field] for field in ("videoUploadedToDrive", "driveReportUpdated", "slackPosted")):
            continue
        candidates.append({
            "date": day.isoformat(),
            "video": str(video),
            "workMinutes": video_minutes(video),
            "submissionState": {
                "videoUploadedToDrive": receipt["videoUploadedToDrive"],
                "driveReportUpdated": receipt["driveReportUpdated"],
                "slackPosted": receipt["slackPosted"],
            },
            "defaultDraft": default_draft(config, entries.get(day.isoformat())),
        })
    return {"generatedAt": utc_now(), "month": month, "unsubmitted": candidates, "configuration": public_configuration(config)}


def normalize_report(item: dict[str, Any], config: dict[str, Any]) -> dict[str, str]:
    day = parse_day(str(item.get("date", "")))
    values = default_draft(config)
    for key in values:
        if item.get(key) is not None:
            values[key] = str(item[key])
    values["date"] = day.isoformat()
    return values


def combined_message(report: dict[str, str]) -> str:
    blockers = report.get("blockers", "").strip()
    message = report.get("message", "").strip()
    parts = [f"詰まった / 判断待ち: {blockers}"] if blockers else []
    if message:
        parts.append(message)
    return "\n".join(parts)


def upsert_entry(root: Path, report: dict[str, str], video: Path, minutes: int, video_link: str | None = None) -> dict[str, Any]:
    day = parse_day(report["date"])
    path = entries_path(root, day)
    entries = load_list(path)
    entry = {
        "date": day.isoformat(),
        "displayDate": f"{day.month}/{day.day}",
        "reporter": report["reporter"].strip(),
        "hours": minutes // 60,
        "minutes": minutes,
        "workPlan": report["workPlan"].strip(),
        "workContent": report["done"].strip(),
        "videoLink": (video_link if video_link is not None else report.get("videoLink", "").strip()) or video.name,
        "videoFileName": video.name,
        "nextTask": report["tomorrow"].strip(),
        "status": report["status"].strip(),
        "message": combined_message(report),
    }
    entries = [item for item in entries if item.get("date") != day.isoformat()]
    entries.append(entry)
    entries.sort(key=lambda item: str(item.get("date", "")))
    atomic_json(path, entries)
    return entry


@dataclass
class PreparedReport:
    day: date
    report: dict[str, str]
    source_video: Path
    submitted_video: Path
    entries_file: Path
    entry: dict[str, Any]
    minutes: int


def prepare_local(root: Path, config: dict[str, Any], report: dict[str, str]) -> PreparedReport:
    day = parse_day(report["date"])
    source_video = find_video(root, day)
    if source_video is None:
        raise FileNotFoundError(f"指定日の動画が見つかりません: {day.isoformat()}")
    destination_dir = month_directory(root, day) / "提出" / day.strftime("%m%d")
    destination_dir.mkdir(parents=True, exist_ok=True)
    submitted_video = destination_dir / source_video.name
    temporary = submitted_video.with_suffix(submitted_video.suffix + ".copying")
    shutil.copy2(source_video, temporary)
    os.replace(temporary, submitted_video)
    minutes = video_minutes(source_video)
    entry = upsert_entry(root, report, submitted_video, minutes)
    template = Path(str(config.get("reportTemplatePath", ""))).expanduser()
    if str(template) and template.is_file():
        regenerate_docx(str(template), str(month_directory(root, day) / f"業務報告-{day:%Y-%m}.docx"), str(entries_path(root, day)))
    record_receipt(root, day, localPrepared=True)
    return PreparedReport(day, report, source_video, submitted_video, entries_path(root, day), entry, minutes)


def slack_text(report: dict[str, str], config: dict[str, Any]) -> str:
    day = parse_day(report["date"])
    mention = str(config.get("slackReporterMention", "")).strip()
    done = report.get("done", "").strip().replace("\n", "\n・") or "未入力"
    blockers = report.get("blockers", "").strip().replace("\n", "\n・") or "なし"
    tomorrow = report.get("tomorrow", "").strip().replace("\n", "\n・") or "未入力"
    return f"📅 {day.month}/{day.day} {mention}\n✅ やった\n・{done}\n🚧 詰まった / 判断待ち\n・{blockers}\n➡️ 明日\n・{tomorrow}".rstrip()


class Publisher(Protocol):
    def publish_video(self, prepared: PreparedReport) -> dict[str, Any]: ...
    def update_drive_report(self, prepared: PreparedReport) -> dict[str, Any]: ...
    def post_slack(self, prepared: PreparedReport) -> dict[str, Any]: ...


class WindowsPublisher:
    def __init__(self, config: dict[str, Any], script_root: Path | None = None) -> None:
        self.config = config
        self.script_root = script_root or Path(__file__).resolve().parent

    def _drive(self, prepared: PreparedReport, upload_video: bool, update_document: bool) -> dict[str, Any]:
        report_folder = str(self.config.get("driveReportFolderUrl", "")).strip()
        video_folder = str(self.config.get("videoDriveFolderUrl", "")).strip()
        if update_document and not report_folder:
            raise RuntimeError("Drive月報フォルダが未設定です")
        if upload_video and not (video_folder or report_folder):
            raise RuntimeError("動画Driveフォルダが未設定です")
        template = Path(str(self.config.get("reportTemplatePath", ""))).expanduser()
        if update_document and not template.is_file():
            raise RuntimeError("報告書テンプレートが見つかりません")
        with tempfile.TemporaryDirectory() as temporary:
            result_path = Path(temporary) / "result.json"
            entries_copy = Path(temporary) / "entries.json"
            shutil.copy2(prepared.entries_file, entries_copy)
            command = [
                os.environ.get("PYTHON", "py"),
                "-3" if os.name == "nt" else str(self.script_root / "sync_google_report.py"),
            ]
            if os.name == "nt":
                command.append(str(self.script_root / "sync_google_report.py"))
            command += [
                "--folder-url", report_folder or video_folder,
                "--video-folder-url", video_folder,
                "--document-name", f"報告書（{prepared.day.month}月分）",
                "--entries-json", str(entries_copy),
                "--output-json", str(result_path),
            ]
            if upload_video:
                command += ["--video", str(prepared.submitted_video)]
            else:
                command.append("--skip-video")
            if update_document:
                command += ["--template", str(template)]
            else:
                command.append("--skip-document")
            result = subprocess.run(command, check=True, capture_output=True, text=True, timeout=600)
            value = json.loads(result_path.read_text(encoding="utf-8")) if result_path.exists() else json.loads(result.stdout)
            if upload_video:
                video = value.get("video") or {}
                link = video.get("webViewLink") or ""
                if link:
                    upsert_entry(Path(str(self.config["recordingsRoot"])), prepared.report, prepared.submitted_video, prepared.minutes, link)
            return value

    def publish_video(self, prepared: PreparedReport) -> dict[str, Any]:
        return self._drive(prepared, upload_video=True, update_document=False)

    def update_drive_report(self, prepared: PreparedReport) -> dict[str, Any]:
        return self._drive(prepared, upload_video=False, update_document=True)

    def post_slack(self, prepared: PreparedReport) -> dict[str, Any]:
        if str(self.config.get("slackDailyChannel", "")) != "#日報":
            raise RuntimeError("Slack投稿先は #日報 に設定してください")
        thread_ts = str(self.config.get("slackDailyThreadTs", "")).strip()
        if not thread_ts:
            raise RuntimeError("#日報の本人スレッドIDが未設定です。チャンネル直下には投稿しません")
        webhook = read_secret(str(self.config.get("slackWebhookCredential", "OneFPSRecorder/SlackWebhook"))).strip()
        if not webhook.startswith("https://hooks.slack.com/"):
            raise RuntimeError("Slack WebhookがWindows Credential Managerに未設定です")
        payload = json.dumps({"text": slack_text(prepared.report, self.config), "thread_ts": thread_ts}, ensure_ascii=False).encode("utf-8")
        request = urllib.request.Request(webhook, data=payload, method="POST", headers={"Content-Type": "application/json; charset=utf-8"})
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                body = response.read().decode("utf-8", errors="replace").strip()
                if response.status < 200 or response.status >= 300 or body != "ok":
                    raise RuntimeError(f"Slack投稿に失敗しました: HTTP {response.status}")
        except urllib.error.URLError as error:
            raise RuntimeError(f"Slack投稿に失敗しました: {error}") from error
        return {"thread_ts": thread_ts, "channel": "#日報"}


def validate_request(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict) or not isinstance(value.get("reports"), list) or not isinstance(value.get("destinations"), dict):
        raise ValueError("reports と destinations を持つJSONオブジェクトが必要です")
    for report in value["reports"]:
        if not isinstance(report, dict):
            raise ValueError("reportsの各要素はオブジェクトにしてください")
        parse_day(str(report.get("date", "")))
    return value


def submit_request(
    request: dict[str, Any],
    config: dict[str, Any],
    *,
    dry_run: bool,
    permissions: set[str] | None = None,
    publisher: Publisher | None = None,
) -> dict[str, Any]:
    request = validate_request(request)
    permissions = permissions or set()
    selected = {name for name, (request_key, _) in DESTINATIONS.items() if bool(request["destinations"].get(request_key))}
    if not dry_run:
        missing = selected - permissions
        if missing:
            raise PermissionError("外部書き込み許可が不足しています: " + ", ".join(sorted(missing)))
    root = Path(str(config.get("recordingsRoot") or default_recordings_root())).expanduser()
    publisher = publisher or WindowsPublisher(config)
    results: list[dict[str, Any]] = []
    for raw in request["reports"]:
        report = normalize_report(raw, config)
        day = parse_day(report["date"])
        receipt = receipt_for(root, day)
        item_result: dict[str, Any] = {"date": day.isoformat(), "dryRun": dry_run, "destinations": {}, "sources": public_configuration(config)["sources"]}
        if dry_run:
            if find_video(root, day) is None:
                item_result["error"] = "video_not_found"
            for name in DESTINATIONS:
                if name not in selected:
                    item_result["destinations"][name] = "not_requested"
                elif receipt[DESTINATIONS[name][1]]:
                    item_result["destinations"][name] = "skipped_already_successful"
                else:
                    item_result["destinations"][name] = "would_submit"
            results.append(item_result)
            continue

        try:
            prepared = prepare_local(root, config, report)
            item_result["localPrepared"] = True
        except Exception as error:  # noqa: BLE001
            item_result["error"] = str(error)
            results.append(item_result)
            continue

        operations = {
            "video": publisher.publish_video,
            "drive": publisher.update_drive_report,
            "slack": publisher.post_slack,
        }
        for name, (_, receipt_field) in DESTINATIONS.items():
            if name not in selected:
                item_result["destinations"][name] = "not_requested"
                continue
            if receipt_for(root, day)[receipt_field]:
                item_result["destinations"][name] = "skipped_already_successful"
                continue
            try:
                detail = operations[name](prepared)
                record_receipt(root, day, **{receipt_field: True})
                item_result["destinations"][name] = {"status": "success", "detail": detail}
            except Exception as error:  # noqa: BLE001
                item_result["destinations"][name] = {"status": "failed", "error": str(error)}
        results.append(item_result)
    return {"generatedAt": utc_now(), "dryRun": dry_run, "results": results}
