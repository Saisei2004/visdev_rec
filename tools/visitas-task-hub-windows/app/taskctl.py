#!/usr/bin/env python3
"""CLI used by humans, Codex, Claude, the UI, and the sync LaunchAgent."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import uuid
from pathlib import Path

from task_store import PRIORITIES, STATUSES, TaskStore, safe_id, utc_now


if sys.platform == "win32":
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")


def split_csv(value: str) -> list[str]:
    return [item.strip() for item in value.split(",") if item.strip()]


def new_personal_id(title: str) -> str:
    day = utc_now()[:10].replace("-", "")
    slug = safe_id(title)[:24].upper()
    if slug == "DEVICE":
        slug = "TASK"
    return f"P-{day}-{slug}-{uuid.uuid4().hex[:5].upper()}"


def task_or_exit(store: TaskStore, task_id: str) -> dict:
    state = store.materialize()
    task = next((item for item in state["tasks"] if item["id"] == task_id), None)
    if task is None:
        raise SystemExit(f"タスクが見つかりません: {task_id}")
    return task


def print_json(value: object) -> None:
    print(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True))


def print_brief(brief: dict) -> None:
    meta = brief["meta"]
    print(f"同期: {meta.get('sync_transport')} / {meta.get('device_name')} / events={meta.get('event_count')}")
    focus = brief.get("focus")
    if focus:
        print(f"今やる: {focus['id']} [{focus['priority']}/{focus['status']}] {focus['title']}")
        print(f"次の1手: {focus.get('next_action') or '未設定'}")
        if focus.get("blocker"):
            print(f"ブロッカー: {focus['blocker']}")
    else:
        print("今やる: 未設定")
    print(
        f"未完了={brief['active_count']} / 受信箱={brief['inbox_count']} / ブロック={brief['blocked_count']}"
    )
    if brief.get("recent_handoffs"):
        print("最近の引き継ぎ:")
        for item in brief["recent_handoffs"][:3]:
            print(
                f"- {item.get('at', '')} {item.get('actor', '')}@{item.get('device', '')}: "
                f"{item.get('summary', '')} / 次: {item.get('next_action', '')}"
            )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Visitas Practical Task Hub v2")
    parser.add_argument("--actor", default="human", help="human / codex / claude / ui / sync")
    sub = parser.add_subparsers(dest="command", required=True)

    init = sub.add_parser("init")
    init.add_argument("--shared-root", type=Path)
    init.add_argument("--device-name")

    sub.add_parser("sync")
    brief = sub.add_parser("brief")
    brief.add_argument("--json", action="store_true")

    listing = sub.add_parser("list")
    listing.add_argument("--status", choices=STATUSES)
    listing.add_argument("--json", action="store_true")

    add = sub.add_parser("add")
    add.add_argument("title")
    add.add_argument("--id")
    add.add_argument("--status", choices=STATUSES, default="inbox")
    add.add_argument("--priority", choices=PRIORITIES, default="P2")
    add.add_argument("--area", default="general")
    add.add_argument("--source", default="manual")
    add.add_argument("--ref", default="")
    add.add_argument("--url", default="")
    add.add_argument("--owner", default="Saisei")
    add.add_argument("--next", default="")
    add.add_argument("--due", default="")
    add.add_argument("--tags", default="")

    update = sub.add_parser("update")
    update.add_argument("task_id")
    update.add_argument("--title")
    update.add_argument("--status", choices=STATUSES)
    update.add_argument("--priority", choices=PRIORITIES)
    update.add_argument("--area")
    update.add_argument("--owner")
    update.add_argument("--next")
    update.add_argument("--blocker")
    update.add_argument("--due")
    update.add_argument("--url")
    update.add_argument("--tags")

    for name, status in [("start", "in_progress"), ("done", "done"), ("wait", "waiting")]:
        command = sub.add_parser(name)
        command.add_argument("task_id")
        command.set_defaults(target_status=status)

    block = sub.add_parser("block")
    block.add_argument("task_id")
    block.add_argument("reason")

    archive = sub.add_parser("archive")
    archive.add_argument("task_id")

    note = sub.add_parser("note")
    note.add_argument("task_id")
    note.add_argument("text")

    handoff = sub.add_parser("handoff")
    handoff.add_argument("--task", default="")
    handoff.add_argument("--summary", required=True)
    handoff.add_argument("--next", default="")
    handoff.add_argument("--files", default="")
    handoff.add_argument("--verification", default="")

    source = sub.add_parser("source-check")
    source.add_argument("source")
    source.add_argument("status", choices=("checked", "not_checked", "blocked"))
    source.add_argument("--note", default="")

    github = sub.add_parser("github-import")
    github.add_argument(
        "repositories",
        nargs="*",
        default=["visit-as/Visitas", "visit-as/AINS", "visit-as/beta-visitas"],
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if args.command == "init":
        store = TaskStore(shared_root=args.shared_root, device_name=args.device_name)
        store.ensure()
        store.register_device(actor=args.actor)
        state = store.materialize()
        print_json(state["meta"])
        return 0

    store = TaskStore()
    store.ensure()

    if args.command == "sync":
        state = store.materialize()
        print_json(state["meta"])
        return 0
    if args.command == "brief":
        value = store.brief()
        print_json(value) if args.json else print_brief(value)
        return 0
    if args.command == "list":
        tasks = store.materialize()["tasks"]
        if args.status:
            tasks = [task for task in tasks if task["status"] == args.status]
        if args.json:
            print_json(tasks)
        else:
            for task in tasks:
                print(f"{task['id']}\t{task['priority']}\t{task['status']}\t{task['title']}")
        return 0
    if args.command == "add":
        task_id = args.id or new_personal_id(args.title)
        payload = {
            "title": args.title,
            "status": args.status,
            "priority": args.priority,
            "area": args.area,
            "source": args.source,
            "source_ref": args.ref,
            "url": args.url,
            "owner": args.owner,
            "next_action": args.next,
            "due": args.due,
            "tags": split_csv(args.tags),
        }
        store.emit("task.upsert", task_id, payload, actor=args.actor)
        store.materialize()
        print(task_id)
        return 0
    if args.command == "update":
        task_or_exit(store, args.task_id)
        mapping = {
            "title": args.title,
            "status": args.status,
            "priority": args.priority,
            "area": args.area,
            "owner": args.owner,
            "next_action": args.next,
            "blocker": args.blocker,
            "due": args.due,
            "url": args.url,
            "tags": split_csv(args.tags) if args.tags is not None else None,
        }
        payload = {key: value for key, value in mapping.items() if value is not None}
        if not payload:
            raise SystemExit("更新内容がありません")
        store.emit("task.patch", args.task_id, payload, actor=args.actor)
        store.materialize()
        print(args.task_id)
        return 0
    if args.command in {"start", "done", "wait"}:
        task_or_exit(store, args.task_id)
        payload = {"status": args.target_status}
        if args.target_status != "blocked":
            payload["blocker"] = ""
        store.emit("task.patch", args.task_id, payload, actor=args.actor)
        store.materialize()
        print(args.task_id)
        return 0
    if args.command == "block":
        task_or_exit(store, args.task_id)
        store.emit(
            "task.patch",
            args.task_id,
            {"status": "blocked", "blocker": args.reason},
            actor=args.actor,
        )
        store.materialize()
        print(args.task_id)
        return 0
    if args.command == "archive":
        task_or_exit(store, args.task_id)
        store.emit("task.patch", args.task_id, {"status": "archived"}, actor=args.actor)
        store.materialize()
        print(args.task_id)
        return 0
    if args.command == "note":
        task_or_exit(store, args.task_id)
        store.emit("task.note", args.task_id, {"text": args.text}, actor=args.actor)
        store.materialize()
        print(args.task_id)
        return 0
    if args.command == "handoff":
        if args.task:
            task_or_exit(store, args.task)
        store.emit(
            "handoff",
            args.task or None,
            {
                "summary": args.summary,
                "next_action": args.next,
                "files": split_csv(args.files),
                "verification": args.verification,
            },
            actor=args.actor,
        )
        store.materialize()
        print("handoff recorded")
        return 0
    if args.command == "source-check":
        store.emit(
            "source.check",
            None,
            {"source": args.source, "status": args.status, "note": args.note},
            actor=args.actor,
        )
        store.materialize()
        print(args.source)
        return 0
    if args.command == "github-import":
        print_json(store.github_import(args.repositories, actor=args.actor))
        return 0
    return 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except subprocess.CalledProcessError as error:
        print(error.stderr or str(error), file=sys.stderr)
        sys.exit(error.returncode or 1)
