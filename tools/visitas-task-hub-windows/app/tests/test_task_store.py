import json
import tempfile
import unittest
from pathlib import Path

from task_store import TaskStore, append_json


class TaskStoreTest(unittest.TestCase):
    def make_store(self, root: Path, device: str) -> TaskStore:
        return TaskStore(
            app_root=root / device,
            shared_root=root / "shared",
            device_id=device,
            device_name=device,
            config_path=root / device / "config.json",
        )

    def test_mac_and_windows_devices_merge_without_overwrite(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            codex = self.make_store(root, "mac-codex")
            claude = self.make_store(root, "windows-claude")
            codex.emit("task.upsert", "T-A", {"title": "Codex task", "status": "next"}, actor="codex")
            claude.emit("task.upsert", "T-B", {"title": "Claude task", "status": "in_progress"}, actor="claude")
            claude.emit("task.note", "T-A", {"text": "reviewed on another Mac"}, actor="claude")
            state = codex.materialize()
            self.assertEqual({task["id"] for task in state["tasks"]}, {"T-A", "T-B"})
            task_a = next(task for task in state["tasks"] if task["id"] == "T-A")
            self.assertEqual(task_a["notes"][0]["actor"], "claude")
            self.assertEqual(json.loads(codex.cache_path.read_text())["meta"]["event_count"], 3)

    def test_windows_reads_an_existing_mac_event_schema_unchanged(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            mac = self.make_store(root, "mac-device")
            event = mac.emit("task.upsert", "T-MAC", {"title": "from mac", "status": "next"}, actor="codex")
            windows = self.make_store(root, "windows-device")
            task = windows.materialize()["tasks"][0]
            self.assertEqual(task["id"], "T-MAC")
            event_path = next((root / "shared" / "data" / "events").glob("*/*.json"))
            persisted = json.loads(event_path.read_text(encoding="utf-8"))
            self.assertEqual(persisted, event)

    def test_event_files_are_never_overwritten(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "event.json"
            append_json(path, {"event_id": "first"})
            with self.assertRaises(FileExistsError):
                append_json(path, {"event_id": "second"})
            self.assertEqual(json.loads(path.read_text(encoding="utf-8"))["event_id"], "first")

    def test_device_id_survives_process_recreation(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            first = TaskStore(
                app_root=root / "app",
                shared_root=root / "shared",
                config_path=root / "config.json",
                device_name="windows-pc",
            )
            first.ensure()
            second = TaskStore(app_root=root / "app", config_path=root / "config.json")
            self.assertEqual(first.config.device_id, second.config.device_id)
            self.assertEqual(first.config.shared_root, second.config.shared_root)

    def test_handoff_source_and_legacy_compatibility(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            store = self.make_store(root, "mac-one")
            store.emit(
                "task.upsert",
                "GH-VISITAS-1",
                {"title": "Issue", "source_ref": "visit-as/Visitas#1"},
                actor="codex",
            )
            store.emit("handoff", "GH-VISITAS-1", {"summary": "implemented", "next_action": "review"}, actor="codex")
            store.emit("source.check", None, {"source": "github_issues", "status": "checked"}, actor="codex")
            state = store.materialize()
            self.assertEqual(state["tasks"][0]["ref"], "visit-as/Visitas#1")
            self.assertRegex(state["meta"]["updated"], r"^\d{4}-\d{2}-\d{2}$")
            self.assertEqual(state["handoffs"][0]["next_action"], "review")
            self.assertEqual(state["source_status"]["github_issues"]["status"], "checked")


if __name__ == "__main__":
    unittest.main()
