#!/usr/bin/env python3
"""Append-only, Box-synced task store for Visitas Task Hub v2."""

from __future__ import annotations

import json
import os
import platform
import re
import shutil
import socket
import subprocess
import tempfile
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


STATUSES = ("inbox", "next", "in_progress", "waiting", "blocked", "done", "archived")
PRIORITIES = ("P0", "P1", "P2", "P3")
STATUS_ORDER = {name: index for index, name in enumerate(STATUSES)}
PRIORITY_ORDER = {name: index for index, name in enumerate(PRIORITIES)}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def atomic_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(value, handle, ensure_ascii=False, indent=2, sort_keys=True)
            handle.write("\n")
        os.replace(tmp_name, path)
    finally:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)


def append_json(path: Path, value: Any) -> None:
    """Create an immutable event file and fail rather than overwrite it."""
    path.parent.mkdir(parents=True, exist_ok=True)
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    descriptor = os.open(path, flags)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(value, handle, ensure_ascii=False, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
    except Exception:
        try:
            path.unlink()
        except OSError:
            pass
        raise


def safe_id(value: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "-", value.strip()).strip("-._")
    return cleaned[:64] or "device"


def default_shared_root() -> Path:
    home = Path.home()
    configured = os.environ.get("VISITAS_TASK_HUB_SHARED_ROOT")
    if configured:
        return Path(configured).expanduser()
    candidates = [
        home / "Box" / "Codex Transfers" / "Visitas Task Hub Shared",
        home / "Box Sync" / "Codex Transfers" / "Visitas Task Hub Shared",
        home / "Documents" / "Box" / "Codex Transfers" / "Visitas Task Hub Shared",
        home / "Library" / "CloudStorage" / "Box-Box" / "Codex Transfers" / "Visitas Task Hub Shared",
    ]
    for candidate in candidates:
        if candidate.exists() or candidate.parent.exists():
            return candidate
    return candidates[0]


def default_config_path() -> Path:
    if os.name == "nt":
        local_app_data = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
        return local_app_data / "VisitasTaskHub" / "config.json"
    return Path.home() / ".config" / "visitas-task-hub" / "config.json"


@dataclass
class HubConfig:
    shared_root: Path
    device_id: str
    device_name: str


class TaskStore:
    def __init__(
        self,
        app_root: Path | None = None,
        shared_root: Path | None = None,
        device_id: str | None = None,
        device_name: str | None = None,
        config_path: Path | None = None,
    ) -> None:
        self.app_root = (app_root or Path(__file__).resolve().parent).resolve()
        self.config_path = config_path or default_config_path()
        config = self._load_config()
        generated_device_name = device_name or config.get("device_name") or platform.node() or socket.gethostname()
        generated_device_id = device_id or config.get("device_id") or f"{safe_id(generated_device_name)}-{uuid.uuid4().hex[:8]}"
        self.config = HubConfig(
            shared_root=(shared_root or Path(config.get("shared_root") or default_shared_root())).expanduser().resolve(),
            device_id=safe_id(generated_device_id),
            device_name=generated_device_name,
        )
        self.events_root = self.config.shared_root / "data" / "events"
        self.cache_path = self.app_root / "tasks.json"

    def _load_config(self) -> dict[str, Any]:
        try:
            return json.loads(self.config_path.read_text(encoding="utf-8"))
        except (FileNotFoundError, json.JSONDecodeError, OSError):
            return {}

    def save_config(self) -> None:
        atomic_json(
            self.config_path,
            {
                "version": 2,
                "shared_root": str(self.config.shared_root),
                "device_id": self.config.device_id,
                "device_name": self.config.device_name,
            },
        )

    def ensure(self) -> None:
        self.events_root.mkdir(parents=True, exist_ok=True)
        (self.config.shared_root / "data" / "attachments").mkdir(parents=True, exist_ok=True)
        (self.config.shared_root / "data" / "exports").mkdir(parents=True, exist_ok=True)
        self.save_config()

    def register_device(self, actor: str = "installer") -> dict[str, Any]:
        state = self.materialize(write_cache=False)
        current = state.get("devices", {}).get(self.config.device_id)
        facts = {
            "name": self.config.device_name,
            "platform": platform.platform(),
            "app_root": str(self.app_root),
        }
        if current and all(current.get(key) == value for key, value in facts.items()):
            return current
        self.emit("device.register", None, facts, actor=actor)
        return facts

    def emit(
        self,
        event_type: str,
        task_id: str | None,
        payload: dict[str, Any],
        actor: str,
    ) -> dict[str, Any]:
        self.ensure()
        timestamp = utc_now()
        event_id = f"{timestamp.replace(':', '').replace('-', '')}-{self.config.device_id}-{uuid.uuid4().hex[:10]}"
        event = {
            "schema": 2,
            "event_id": event_id,
            "occurred_at": timestamp,
            "device_id": self.config.device_id,
            "device_name": self.config.device_name,
            "actor": actor,
            "type": event_type,
            "task_id": task_id,
            "payload": payload,
        }
        month = timestamp[:7]
        target = self.events_root / month / f"{event_id}.json"
        append_json(target, event)
        return event

    def iter_events(self) -> Iterable[dict[str, Any]]:
        self.ensure()
        events: list[dict[str, Any]] = []
        for path in self.events_root.glob("*/*.json"):
            try:
                event = json.loads(path.read_text(encoding="utf-8"))
                if isinstance(event, dict) and event.get("event_id") and event.get("type"):
                    events.append(event)
            except (OSError, json.JSONDecodeError):
                continue
        events.sort(key=lambda item: (item.get("occurred_at", ""), item.get("event_id", "")))
        return events

    @staticmethod
    def _task_defaults(task_id: str, event: dict[str, Any]) -> dict[str, Any]:
        timestamp = event.get("occurred_at") or utc_now()
        return {
            "id": task_id,
            "title": "",
            "status": "inbox",
            "priority": "P2",
            "area": "general",
            "source": "manual",
            "source_ref": "",
            "url": "",
            "owner": "Saisei",
            "next_action": "",
            "blocker": "",
            "due": "",
            "tags": [],
            "labels": [],
            "notes": [],
            "created_at": timestamp,
            "created_by": event.get("actor", "unknown"),
            "updated_at": timestamp,
            "updated_by": event.get("actor", "unknown"),
            "updated_device": event.get("device_name", "unknown"),
        }

    def materialize(self, write_cache: bool = True) -> dict[str, Any]:
        tasks: dict[str, dict[str, Any]] = {}
        handoffs: list[dict[str, Any]] = []
        source_status: dict[str, dict[str, Any]] = {}
        devices: dict[str, dict[str, Any]] = {}
        last_event_at = ""
        event_count = 0

        for event in self.iter_events():
            event_count += 1
            last_event_at = max(last_event_at, event.get("occurred_at", ""))
            event_type = event.get("type")
            payload = event.get("payload") or {}
            task_id = event.get("task_id")

            if event_type in {"task.upsert", "task.patch"} and task_id:
                task = tasks.setdefault(task_id, self._task_defaults(task_id, event))
                for key, value in payload.items():
                    if key not in {"id", "notes", "created_at", "created_by"}:
                        task[key] = value
                if payload.get("notes") and isinstance(payload["notes"], list):
                    task["notes"] = payload["notes"]
                task["updated_at"] = event.get("occurred_at", "")
                task["updated_by"] = event.get("actor", "unknown")
                task["updated_device"] = event.get("device_name", "unknown")
            elif event_type == "task.note" and task_id:
                task = tasks.setdefault(task_id, self._task_defaults(task_id, event))
                task.setdefault("notes", []).append(
                    {
                        "at": event.get("occurred_at"),
                        "actor": event.get("actor"),
                        "device": event.get("device_name"),
                        "text": payload.get("text", ""),
                    }
                )
                task["updated_at"] = event.get("occurred_at", "")
                task["updated_by"] = event.get("actor", "unknown")
                task["updated_device"] = event.get("device_name", "unknown")
            elif event_type == "handoff":
                handoffs.append(
                    {
                        "at": event.get("occurred_at"),
                        "actor": event.get("actor"),
                        "device": event.get("device_name"),
                        "task_id": task_id or "",
                        **payload,
                    }
                )
            elif event_type == "source.check":
                source_name = payload.get("source")
                if source_name:
                    source_status[source_name] = {
                        "status": payload.get("status", "not_checked"),
                        "note": payload.get("note", ""),
                        "checked_at": event.get("occurred_at"),
                        "actor": event.get("actor"),
                        "device": event.get("device_name"),
                    }
            elif event_type == "device.register":
                devices[event.get("device_id", "unknown")] = {
                    **payload,
                    "last_seen": event.get("occurred_at"),
                    "actor": event.get("actor"),
                }

        normalized_tasks = []
        for task_id, task in tasks.items():
            task["id"] = task_id
            task["status"] = task.get("status") if task.get("status") in STATUSES else "inbox"
            task["priority"] = task.get("priority") if task.get("priority") in PRIORITIES else "P2"
            task["tags"] = task.get("tags") if isinstance(task.get("tags"), list) else []
            task["labels"] = task.get("labels") if isinstance(task.get("labels"), list) else []
            task["notes"] = task.get("notes") if isinstance(task.get("notes"), list) else []
            # v1 compatibility: OneFPSRecorder and older helper scripts read `ref`.
            task["ref"] = task.get("ref") or task.get("source_ref", "")
            normalized_tasks.append(task)
        normalized_tasks.sort(
            key=lambda task: (
                STATUS_ORDER.get(task.get("status", "inbox"), 99),
                PRIORITY_ORDER.get(task.get("priority", "P2"), 99),
                task.get("due") or "9999-99-99",
                task.get("id", ""),
            )
        )
        handoffs.sort(key=lambda item: item.get("at", ""), reverse=True)

        state = {
            "meta": {
                "version": 2,
                "title": "Visitas Practical Task Hub",
                # v1 compatibility: this was a YYYY-MM-DD field.
                "updated": (last_event_at or utc_now())[:10],
                "generated_at": utc_now(),
                "last_event_at": last_event_at,
                "event_count": event_count,
                "shared_root": str(self.config.shared_root),
                "sync_transport": "Box append-only events",
                "device_id": self.config.device_id,
                "device_name": self.config.device_name,
            },
            "tasks": normalized_tasks,
            "handoffs": handoffs[:100],
            "source_status": source_status,
            "devices": devices,
        }
        if write_cache:
            atomic_json(self.cache_path, state)
        return state

    def brief(self) -> dict[str, Any]:
        state = self.materialize()
        active = [task for task in state["tasks"] if task["status"] not in {"done", "archived"}]
        focus = sorted(
            active,
            key=lambda task: (
                0 if task["status"] == "in_progress" else 1 if task["status"] == "next" else 2,
                PRIORITY_ORDER.get(task["priority"], 99),
                task.get("due") or "9999-99-99",
            ),
        )
        return {
            "focus": focus[0] if focus else None,
            "active_count": len(active),
            "inbox_count": sum(task["status"] == "inbox" for task in active),
            "blocked_count": sum(task["status"] == "blocked" for task in active),
            "recent_handoffs": state["handoffs"][:5],
            "source_status": state["source_status"],
            "devices": state["devices"],
            "meta": state["meta"],
        }

    def github_import(self, repositories: list[str], actor: str) -> dict[str, Any]:
        gh = next(
            (
                path
                for path in [
                    shutil.which("gh"),
                    str(Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "GitHub CLI" / "gh.exe"),
                    str(Path.home() / ".local" / "bin" / "gh"),
                    "/opt/homebrew/bin/gh",
                    "/usr/local/bin/gh",
                ]
                if path and Path(path).is_file()
            ),
            None,
        )
        if not gh:
            raise RuntimeError("GitHub CLI gh が見つかりません")
        existing = {task["id"]: task for task in self.materialize()["tasks"]}
        created = 0
        updated = 0
        unchanged = 0
        for repository in repositories:
            command = [
                gh,
                "issue",
                "list",
                "-R",
                repository,
                "--state",
                "open",
                "--assignee",
                "@me",
                "--limit",
                "200",
                "--json",
                "number,title,url,labels,updatedAt",
            ]
            result = subprocess.run(command, check=True, capture_output=True, text=True)
            issues = json.loads(result.stdout or "[]")
            repo_key = safe_id(repository.split("/")[-1]).upper()
            for issue in issues:
                task_id = f"GH-{repo_key}-{issue['number']}"
                labels = [item.get("name", "") for item in issue.get("labels", [])]
                priority = next((label.split(":", 1)[1].strip() for label in labels if label.startswith("priority:")), "P2")
                if priority not in PRIORITIES:
                    priority = "P2"
                current = existing.get(task_id)
                payload = {
                    "title": issue["title"],
                    "priority": current.get("priority", priority) if current else priority,
                    "source": "github",
                    "source_ref": f"{repository}#{issue['number']}",
                    "url": issue["url"],
                    "labels": labels,
                    "area": repository.split("/")[-1].lower(),
                }
                if not current:
                    payload.update(
                        {
                            "status": "inbox",
                            "next_action": "担当範囲と、次に実行する1手を確認する",
                            "owner": "Saisei",
                        }
                    )
                    self.emit("task.upsert", task_id, payload, actor=actor)
                    existing[task_id] = {"id": task_id, **payload}
                    created += 1
                else:
                    changed = any(current.get(key) != value for key, value in payload.items())
                    if changed:
                        self.emit("task.patch", task_id, payload, actor=actor)
                        current.update(payload)
                        updated += 1
                    else:
                        unchanged += 1
        self.emit(
            "source.check",
            None,
            {
                "source": "github_issues",
                "status": "checked",
                "note": f"{len(repositories)} repositories; created={created}, updated={updated}",
            },
            actor=actor,
        )
        self.materialize()
        return {"created": created, "updated": updated, "unchanged": unchanged}
