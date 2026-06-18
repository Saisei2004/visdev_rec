#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path


ROOT = Path.home() / "Movies" / "1FPS録画"
FFPROBE = Path.home() / ".local" / "bin" / "ffprobe"


def video_stream(path: Path) -> dict:
    result = subprocess.run(
        [
            str(FFPROBE),
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=nb_frames,avg_frame_rate,duration,sample_aspect_ratio",
            "-of",
            "json",
            str(path),
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"ffprobe failed: {path}")
    streams = json.loads(result.stdout).get("streams", [])
    if not streams:
        raise RuntimeError(f"video stream not found: {path}")
    return streams[0]


def parse_month_log(log_path: Path) -> tuple[dict[str, int], int, int]:
    totals: dict[str, int] = {}
    rows = 0
    legacy_rows = 0
    for line in log_path.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("開始"):
            continue
        columns = line.split("\t")
        if len(columns) < 4:
            raise RuntimeError(f"bad log row in {log_path}: {line}")
        match = re.search(r"(\d+)秒", columns[2])
        if not match:
            raise RuntimeError(f"bad duration in {log_path}: {line}")
        if len(columns) < 5 or not columns[4].strip():
            legacy_rows += 1
        rows += 1
        totals[columns[3]] = totals.get(columns[3], 0) + int(match.group(1))
    return totals, rows, legacy_rows


def main() -> int:
    issues: list[str] = []
    if not ROOT.exists():
        print(f"録画フォルダがありません: {ROOT}")
        return 1

    for month_dir in sorted(ROOT.iterdir()):
        if not month_dir.is_dir() or not re.match(r"^\d{4}-\d{2}$", month_dir.name):
            continue
        log_path = month_dir / f"録画区間ログ-{month_dir.name}.txt"
        if not log_path.exists():
            issues.append(f"録画区間ログがありません: {log_path}")
            continue

        totals, rows, legacy_rows = parse_month_log(log_path)
        print(f"{month_dir.name}: {rows}区間 legacy_idなし={legacy_rows}")
        for filename, log_seconds in sorted(totals.items()):
            video_path = month_dir / filename
            if not video_path.exists():
                issues.append(f"動画がありません: {video_path}")
                continue
            stream = video_stream(video_path)
            frames = int(stream.get("nb_frames") or 0)
            avg_rate = stream.get("avg_frame_rate")
            diff = log_seconds - frames
            print(
                f"  {filename}: log={log_seconds} frames={frames} "
                f"diff={diff} avg={avg_rate} sar={stream.get('sample_aspect_ratio')}"
            )
            if frames != log_seconds:
                issues.append(f"ログ秒数と動画フレーム数が不一致: {filename}")
            if avg_rate != "1/1":
                issues.append(f"1FPSではありません: {filename} avg={avg_rate}")

        for hidden in month_dir.glob(".*"):
            if hidden.name.startswith((".repair-", ".daily-", ".rename-merge-")):
                issues.append(f"一時ファイルが残っています: {hidden}")

    for frames_dir in ROOT.glob(".frames-*"):
        issues.append(f"未復旧の一時フレームがあります: {frames_dir}")

    if issues:
        print("NG")
        for issue in issues:
            print(f"- {issue}")
        return 1

    print("OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
