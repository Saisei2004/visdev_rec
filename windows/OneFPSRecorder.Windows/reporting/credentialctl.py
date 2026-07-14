#!/usr/bin/env python3
from __future__ import annotations

import argparse
import getpass

from windows_credentials import read_secret, write_secret


def main() -> int:
    parser = argparse.ArgumentParser(description="OneFPSRecorder secret settings")
    parser.add_argument("action", choices=("set-slack-webhook", "status"))
    args = parser.parse_args()
    target = "OneFPSRecorder/SlackWebhook"
    if args.action == "status":
        print("configured" if read_secret(target) else "not_configured")
        return 0
    value = getpass.getpass("Slack Incoming Webhook URL: ").strip()
    if not value.startswith("https://hooks.slack.com/"):
        raise SystemExit("hooks.slack.com のHTTPS URLを指定してください")
    write_secret(target, value)
    print("saved to Windows Credential Manager")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
