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
    try:
        report = json.loads(args.report.read_text())
        if not isinstance(report, dict) or not isinstance(report.get("checks"), dict) or not report["checks"]:
            raise ValueError("expected a nonempty checks object")
        if any(not isinstance(check, dict) for check in report["checks"].values()):
            raise ValueError("invalid native check entry")
    except (OSError, ValueError) as error:
        print(f"native runtime: doctor report unavailable or malformed: {error}", file=sys.stderr)
        return 1
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
        terminal_details = check.get("details", {})
        doctor_output_was_redirected = terminal_details.get("stdout is terminal") == "false"
        if name == "terminal.env" and check.get("details", {}).get("TERM") == "dumb" and (not os.isatty(0) or doctor_output_was_redirected):
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
