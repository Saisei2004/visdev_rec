import json
import tempfile
import unittest
from datetime import date
from pathlib import Path

from report_core import default_config, receipt_for, report_candidates, submit_request


class FakePublisher:
    def __init__(self, fail=()):
        self.fail = set(fail)
        self.calls = {"video": 0, "drive": 0, "slack": 0}

    def _run(self, name):
        self.calls[name] += 1
        if name in self.fail:
            raise RuntimeError(f"{name} failed")
        return {"destination": name}

    def publish_video(self, _prepared):
        return self._run("video")

    def update_drive_report(self, _prepared):
        return self._run("drive")

    def post_slack(self, _prepared):
        return self._run("slack")


class ReportCoreTest(unittest.TestCase):
    def setup_recording(self, root: Path, day: date) -> Path:
        directory = root / day.strftime("%Y-%m") / day.strftime("%m%d")
        directory.mkdir(parents=True)
        video = directory / f"{day:%m%d}_recording.mp4"
        video.write_bytes(b"not-a-real-video")
        return video

    def config(self, root: Path):
        value = default_config()
        value["recordingsRoot"] = str(root)
        value["sources"]["github_issues"]["status"] = "checked"
        return value

    def request(self, day: date):
        return {
            "reports": [{
                "date": day.isoformat(),
                "reporter": "Reporter",
                "workPlan": "Plan",
                "done": "Done",
                "blockers": "None",
                "tomorrow": "Next",
                "status": "Good",
                "message": "",
                "videoLink": "",
            }],
            "destinations": {
                "uploadVideoToDrive": True,
                "updateDriveReport": True,
                "postToSlack": True,
            },
        }

    def test_dry_run_does_not_write_state(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            day = date(2026, 7, 13)
            self.setup_recording(root, day)
            result = submit_request(self.request(day), self.config(root), dry_run=True)
            self.assertEqual(result["results"][0]["destinations"]["video"], "would_submit")
            self.assertFalse((root / "2026-07" / "提出状態-2026-07.json").exists())

    def test_partial_success_is_idempotent_per_destination(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            day = date(2026, 7, 13)
            self.setup_recording(root, day)
            first = FakePublisher(fail={"drive"})
            result = submit_request(
                self.request(day), self.config(root), dry_run=False,
                permissions={"video", "drive", "slack"}, publisher=first,
            )
            self.assertEqual(result["results"][0]["destinations"]["drive"]["status"], "failed")
            receipt = receipt_for(root, day)
            self.assertTrue(receipt["videoUploadedToDrive"])
            self.assertFalse(receipt["driveReportUpdated"])
            self.assertTrue(receipt["slackPosted"])

            second = FakePublisher()
            result = submit_request(
                self.request(day), self.config(root), dry_run=False,
                permissions={"video", "drive", "slack"}, publisher=second,
            )
            self.assertEqual(second.calls, {"video": 0, "drive": 1, "slack": 0})
            self.assertEqual(result["results"][0]["destinations"]["video"], "skipped_already_successful")
            self.assertTrue(receipt_for(root, day)["driveReportUpdated"])

    def test_execute_requires_individual_permissions(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            day = date(2026, 7, 13)
            self.setup_recording(root, day)
            with self.assertRaises(PermissionError):
                submit_request(self.request(day), self.config(root), dry_run=False, permissions={"video"}, publisher=FakePublisher())

    def test_candidates_keep_unchecked_sources_explicit(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            day = date(2026, 7, 13)
            self.setup_recording(root, day)
            result = report_candidates("2026-07", self.config(root))
            self.assertEqual(result["unsubmitted"][0]["date"], day.isoformat())
            sources = result["configuration"]["sources"]
            self.assertEqual(sources["github_issues"]["status"], "checked")
            self.assertEqual(sources["gmail_notta"]["status"], "not_checked")

    def test_receipt_schema_remains_mac_compatible(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            day = date(2026, 7, 13)
            self.setup_recording(root, day)
            submit_request(
                self.request(day), self.config(root), dry_run=False,
                permissions={"video", "drive", "slack"}, publisher=FakePublisher(),
            )
            path = root / "2026-07" / "提出状態-2026-07.json"
            receipt = json.loads(path.read_text(encoding="utf-8"))[0]
            self.assertEqual(
                set(receipt),
                {"date", "localPrepared", "videoUploadedToDrive", "driveReportUpdated", "slackPosted", "updatedAt"},
            )


if __name__ == "__main__":
    unittest.main()
