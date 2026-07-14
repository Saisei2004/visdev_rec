#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from datetime import date
from pathlib import Path

from report_core import (
    load_config,
    public_configuration,
    record_receipt,
    report_candidates,
    save_config,
    submit_request,
)


def print_json(value: object) -> None:
    print(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="OneFPSRecorder Windows daily report automation")
    parser.add_argument("--config", type=Path)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--report-config", action="store_true")
    mode.add_argument("--report-candidates", metavar="YYYY-MM")
    mode.add_argument("--submit-report-json", type=Path)
    mode.add_argument("--mark-slack-posted-date", metavar="YYYY-MM-DD")
    mode.add_argument("--register-source", nargs=3, metavar=("NAME", "STATUS", "REFERENCE"))
    parser.add_argument("--note", default="")
    parser.add_argument("--execute", action="store_true", help="perform permitted external writes; default is dry-run")
    parser.add_argument("--dry-run", action="store_true", help="explicitly select dry-run")
    parser.add_argument("--permission", action="append", choices=("video", "drive", "slack"), default=[])
    return parser


def main() -> int:
    args = build_parser().parse_args()
    config_path, config = load_config(args.config, create=True)
    if args.report_config:
        value = public_configuration(config)
        value["configPath"] = str(config_path)
        print_json(value)
        return 0
    if args.report_candidates:
        print_json(report_candidates(args.report_candidates, config))
        return 0
    if args.mark_slack_posted_date:
        day = date.fromisoformat(args.mark_slack_posted_date)
        print_json(record_receipt(Path(str(config["recordingsRoot"])), day, slackPosted=True))
        return 0
    if args.register_source:
        name, status, reference = args.register_source
        if status not in {"checked", "not_checked", "blocked"}:
            raise SystemExit("status は checked / not_checked / blocked のいずれかです")
        config.setdefault("sources", {})[name] = {"status": status, "reference": reference, "note": args.note}
        save_config(config, config_path)
        print_json(config["sources"][name])
        return 0
    if args.submit_report_json:
        request = json.loads(args.submit_report_json.read_text(encoding="utf-8"))
        # Safety default: --execute is required in addition to per-destination permission flags.
        dry_run = not args.execute or args.dry_run
        print_json(submit_request(request, config, dry_run=dry_run, permissions=set(args.permission)))
        return 0
    return 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, PermissionError, OSError, json.JSONDecodeError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(2)
