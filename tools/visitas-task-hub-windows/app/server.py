#!/usr/bin/env python3
"""Local-only web server for the practical Visitas task UI."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import uuid
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

from task_store import PRIORITIES, STATUSES, TaskStore, safe_id, utc_now


ROOT = Path(__file__).resolve().parent
INDEX = ROOT / "index.html"


class ExclusiveThreadingHTTPServer(ThreadingHTTPServer):
    """Prevent two Windows tray server processes from sharing port 7700."""

    allow_reuse_address = False


def personal_id(title: str) -> str:
    slug = safe_id(title)[:20].upper()
    if slug == "DEVICE":
        slug = "TASK"
    return f"P-{utc_now()[:10].replace('-', '')}-{slug}-{uuid.uuid4().hex[:5].upper()}"


class Handler(BaseHTTPRequestHandler):
    store = TaskStore(app_root=ROOT)

    def send_value(self, status: int, value: object, content_type: str = "application/json; charset=utf-8") -> None:
        if isinstance(value, (dict, list)):
            body = json.dumps(value, ensure_ascii=False).encode("utf-8")
        elif isinstance(value, bytes):
            body = value
        else:
            body = str(value).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if path in {"/", "/index.html"}:
            self.send_value(200, INDEX.read_bytes(), "text/html; charset=utf-8")
        elif path in {"/api/state", "/api/tasks"}:
            self.send_value(200, self.store.materialize())
        elif path == "/api/health":
            state = self.store.materialize()
            self.send_value(
                200,
                {
                    "ok": True,
                    "version": 2,
                    "event_count": state["meta"]["event_count"],
                    "device": state["meta"]["device_name"],
                },
            )
        else:
            self.send_value(404, {"error": "not found"})

    def read_json(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0 or length > 1_000_000:
            raise ValueError("invalid content length")
        value = json.loads(self.rfile.read(length).decode("utf-8"))
        if not isinstance(value, dict):
            raise ValueError("body must be an object")
        return value

    def task_exists(self, task_id: str) -> bool:
        return any(task["id"] == task_id for task in self.store.materialize()["tasks"])

    def do_POST(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if path == "/api/sync":
            self.send_value(200, self.store.materialize())
            return
        if path != "/api/action":
            self.send_value(404, {"error": "not found"})
            return
        try:
            body = self.read_json()
            action = body.get("action")
            actor = body.get("actor") or "ui"
            if action == "add":
                title = str(body.get("title") or "").strip()
                if not title:
                    raise ValueError("title is required")
                task_id = body.get("id") or personal_id(title)
                payload = {
                    "title": title,
                    "status": body.get("status") if body.get("status") in STATUSES else "inbox",
                    "priority": body.get("priority") if body.get("priority") in PRIORITIES else "P2",
                    "area": body.get("area") or "general",
                    "source": body.get("source") or "manual",
                    "source_ref": body.get("source_ref") or "",
                    "url": body.get("url") or "",
                    "owner": body.get("owner") or "Saisei",
                    "next_action": body.get("next_action") or "",
                    "blocker": body.get("blocker") or "",
                    "due": body.get("due") or "",
                    "tags": body.get("tags") if isinstance(body.get("tags"), list) else [],
                }
                self.store.emit("task.upsert", task_id, payload, actor=actor)
            elif action == "update":
                task_id = str(body.get("task_id") or "")
                if not task_id or not self.task_exists(task_id):
                    raise ValueError("task not found")
                allowed = {
                    "title",
                    "status",
                    "priority",
                    "area",
                    "source",
                    "source_ref",
                    "url",
                    "owner",
                    "next_action",
                    "blocker",
                    "due",
                    "tags",
                }
                payload = {key: body[key] for key in allowed if key in body}
                self.store.emit("task.patch", task_id, payload, actor=actor)
            elif action == "status":
                task_id = str(body.get("task_id") or "")
                status = body.get("status")
                if not self.task_exists(task_id) or status not in STATUSES:
                    raise ValueError("invalid task or status")
                payload = {"status": status}
                if status != "blocked":
                    payload["blocker"] = ""
                elif body.get("blocker") is not None:
                    payload["blocker"] = body.get("blocker")
                self.store.emit("task.patch", task_id, payload, actor=actor)
            elif action == "note":
                task_id = str(body.get("task_id") or "")
                text = str(body.get("text") or "").strip()
                if not self.task_exists(task_id) or not text:
                    raise ValueError("task and note are required")
                self.store.emit("task.note", task_id, {"text": text}, actor=actor)
            elif action == "handoff":
                task_id = str(body.get("task_id") or "")
                self.store.emit(
                    "handoff",
                    task_id or None,
                    {
                        "summary": body.get("summary") or "",
                        "next_action": body.get("next_action") or "",
                        "files": body.get("files") if isinstance(body.get("files"), list) else [],
                        "verification": body.get("verification") or "",
                    },
                    actor=actor,
                )
            elif action == "source-check":
                source = str(body.get("source") or "").strip()
                if not source:
                    raise ValueError("source is required")
                self.store.emit(
                    "source.check",
                    None,
                    {
                        "source": source,
                        "status": body.get("status") or "not_checked",
                        "note": body.get("note") or "",
                    },
                    actor=actor,
                )
            elif action == "github-import":
                repositories = body.get("repositories") or [
                    "visit-as/Visitas",
                    "visit-as/AINS",
                    "visit-as/beta-visitas",
                ]
                result = self.store.github_import(repositories, actor=actor)
                self.send_value(200, {"ok": True, "result": result, "state": self.store.materialize()})
                return
            else:
                raise ValueError("unknown action")
            self.send_value(200, {"ok": True, "state": self.store.materialize()})
        except (ValueError, json.JSONDecodeError, subprocess.CalledProcessError) as error:
            detail = getattr(error, "stderr", None) or str(error)
            self.send_value(400, {"error": detail})
        except Exception as error:  # noqa: BLE001
            self.send_value(500, {"error": str(error)})

    def log_message(self, *_: object) -> None:
        pass


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=7700)
    parser.add_argument("--open", action="store_true")
    args = parser.parse_args()
    Handler.store.ensure()
    Handler.store.materialize()
    server = ExclusiveThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    url = f"http://127.0.0.1:{args.port}/"
    print(f"Visitas Practical Task Hub v2: {url}")
    if args.open:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
