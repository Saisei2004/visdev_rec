#!/usr/bin/env python3
"""Strict append-only event bridge used by Task Hub SSH synchronization."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path, PurePosixPath

from task_store import TaskStore


ROOT = Path(__file__).resolve().parent
MONTH_RE = re.compile(r"^\d{4}-\d{2}$")
FILENAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,199}\.json$")
WINDOWS_RESERVED = {"CON", "PRN", "AUX", "NUL", *(f"COM{n}" for n in range(1, 10)), *(f"LPT{n}" for n in range(1, 10))}


def event_root() -> Path:
    store = TaskStore(app_root=ROOT)
    store.ensure()
    return store.events_root


def safe_relative(value: str) -> PurePosixPath:
    relative = PurePosixPath(value.replace("\\", "/"))
    if (
        len(relative.parts) != 2
        or not MONTH_RE.fullmatch(relative.parts[0])
        or not FILENAME_RE.fullmatch(relative.parts[1])
        or relative.parts[1].split(".", 1)[0].upper() in WINDOWS_RESERVED
    ):
        raise ValueError("invalid event path")
    return relative


def event_path(root: Path, relative: PurePosixPath) -> Path:
    root = root.resolve()
    target = root.joinpath(*relative.parts).resolve(strict=False)
    try:
        target.relative_to(root)
    except ValueError as error:
        raise ValueError("event path escapes event root") from error
    return target


def validate_event(raw: bytes, relative: PurePosixPath) -> dict:
    event = json.loads(raw.decode("utf-8"))
    if not isinstance(event, dict) or event.get("schema") != 2:
        raise ValueError("invalid event schema")
    event_id = str(event.get("event_id") or "")
    occurred_at = str(event.get("occurred_at") or "")
    if not event_id or not event.get("type"):
        raise ValueError("event id and type are required")
    if relative.stem != event_id or relative.parts[0] != occurred_at[:7]:
        raise ValueError("event path does not match payload")
    return event


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def append_bytes(path: Path, raw: bytes) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        existing = path.read_bytes()
        if digest(existing) != digest(raw):
            raise RuntimeError(f"append-only conflict: {path.name}")
        return "exists"
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(raw)
            handle.flush()
            os.fsync(handle.fileno())
    except Exception:
        try:
            path.unlink()
        except OSError:
            pass
        raise
    return "created"


def manifest(root: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for path in sorted(root.glob("*/*.json")):
        relative = safe_relative(path.relative_to(root).as_posix())
        path = event_path(root, relative)
        raw = path.read_bytes()
        validate_event(raw, relative)
        result[relative.as_posix()] = digest(raw)
    return result


def write_json(value: object) -> None:
    sys.stdout.buffer.write(json.dumps(value, ensure_ascii=True, sort_keys=True).encode("utf-8"))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("manifest", "get", "put", "state"))
    parser.add_argument("relative", nargs="?")
    args = parser.parse_args()
    root = event_root()

    if args.action == "manifest":
        files = manifest(root)
        write_json({"count": len(files), "files": files})
        return
    if args.action == "state":
        write_json(TaskStore(app_root=ROOT).materialize())
        return
    if not args.relative:
        raise ValueError("relative event path is required")

    relative = safe_relative(args.relative)
    target = event_path(root, relative)
    if args.action == "get":
        raw = target.read_bytes()
        validate_event(raw, relative)
        sys.stdout.buffer.write(raw)
        return

    raw = sys.stdin.buffer.read()
    validate_event(raw, relative)
    write_json({"status": append_bytes(target, raw), "relative": relative.as_posix(), "sha256": digest(raw)})


if __name__ == "__main__":
    main()
