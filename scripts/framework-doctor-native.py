#!/usr/bin/env python3
"""Classify native Codex doctor output without promoting advisories to failures."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=Path)
    parser.add_argument("native_status", type=int)
    args = parser.parse_args()
    report = json.loads(args.report.read_text())
    failures: list[str] = []
    advisories: list[str] = []
    ignored_non_tty = False

    for name, check in report.get("checks", {}).items():
        status = check.get("status")
        summary = check.get("summary", status)
        if status in {"ok", "idle"}:
            continue
        if status == "warning":
            advisories.append(f"{name}: {summary}")
            continue
        if name == "terminal.env" and not os.isatty(0) and check.get("details", {}).get("TERM") == "dumb":
            ignored_non_tty = True
            continue
        failures.append(f"{name}: {summary}")

    if args.native_status != 0 and not failures and not ignored_non_tty:
        failures.append(f"native codex doctor exited with status {args.native_status}")
    for advisory in advisories:
        print(f"note framework doctor: native advisory: {advisory}")
    if ignored_non_tty:
        print("note framework doctor: ignored TERM=dumb because this audit is running without a TTY")
    for failure in failures:
        print(failure, file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
