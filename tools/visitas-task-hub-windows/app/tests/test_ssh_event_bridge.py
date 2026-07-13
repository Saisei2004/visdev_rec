import json
import tempfile
import unittest
from pathlib import Path, PurePosixPath

from ssh_event_bridge import append_bytes, digest, event_path, manifest, safe_relative, validate_event


def event_bytes(event_id: str = "event-1", occurred_at: str = "2026-07-13T00:00:00.000Z") -> bytes:
    return json.dumps(
        {
            "schema": 2,
            "event_id": event_id,
            "occurred_at": occurred_at,
            "type": "task.patch",
            "task_id": "T-1",
            "payload": {"status": "next"},
        },
        sort_keys=True,
    ).encode("utf-8")


class SshEventBridgeTest(unittest.TestCase):
    def test_safe_relative_accepts_only_month_and_json_filename(self):
        self.assertEqual(safe_relative(r"2026-07\event-1.json"), PurePosixPath("2026-07/event-1.json"))
        invalid = (
            "../event-1.json",
            "2026-07/../event-1.json",
            "/2026-07/event-1.json",
            "2026-07/nested/event-1.json",
            "2026-7/event-1.json",
            "2026-07/event-1.txt",
            "2026-07/event:stream.json",
            "2026-07/CON.json",
            "2026-07/.hidden.json",
        )
        for value in invalid:
            with self.subTest(value=value), self.assertRaises(ValueError):
                safe_relative(value)

    def test_event_path_rejects_link_outside_event_root(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            root = base / "events"
            outside = base / "outside"
            root.mkdir()
            outside.mkdir()
            try:
                (root / "2026-07").symlink_to(outside, target_is_directory=True)
            except OSError as error:
                self.skipTest(f"directory symlinks unavailable: {error}")
            with self.assertRaisesRegex(ValueError, "escapes event root"):
                event_path(root, PurePosixPath("2026-07/event-1.json"))

    def test_payload_must_match_event_filename_and_month(self):
        raw = event_bytes()
        self.assertEqual(validate_event(raw, PurePosixPath("2026-07/event-1.json"))["event_id"], "event-1")
        for relative in ("2026-07/other.json", "2026-08/event-1.json"):
            with self.subTest(relative=relative), self.assertRaises(ValueError):
                validate_event(raw, PurePosixPath(relative))

    def test_append_is_idempotent_and_rejects_same_name_different_hash(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "2026-07" / "event-1.json"
            original = event_bytes()
            self.assertEqual(append_bytes(path, original), "created")
            self.assertEqual(append_bytes(path, original), "exists")
            with self.assertRaisesRegex(RuntimeError, "append-only conflict"):
                append_bytes(path, event_bytes(occurred_at="2026-07-14T00:00:00.000Z"))
            self.assertEqual(path.read_bytes(), original)

    def test_manifest_hashes_only_valid_event_paths(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            raw = event_bytes()
            path = root / "2026-07" / "event-1.json"
            append_bytes(path, raw)
            self.assertEqual(manifest(root), {"2026-07/event-1.json": digest(raw)})


if __name__ == "__main__":
    unittest.main()
