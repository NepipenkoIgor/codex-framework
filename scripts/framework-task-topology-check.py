#!/usr/bin/env python3
"""Validate the native fork/new-task/subagent contract and reject semantic reversals."""

from __future__ import annotations

import sys
from pathlib import Path


REQUIRED = (
    "Choose a fork only when the new task needs the source task's completed history",
    "choose a new task when it should start without that history",
    "a subagent when it remains a bounded part of the current request",
    "A running turn is not forked history",
    "parallel writers require separate worktrees",
    "Use native task messaging and task management instead of local queues, status files, or handoff machinery",
    "verify the effective working directory and permission profile before consequential work",
    "a mismatch is an explicit stop-and-resolve boundary",
    "Export or share task history only on explicit user request",
)

REVERSALS = (
    "fork only when the new task does not need the source task's completed history",
    "new task when it should inherit that history",
    "subagent when it is unrelated to the current request",
    "running turn is forked history",
    "parallel writers may share a worktree",
    "use local queues, status files, or handoff machinery instead of native task messaging",
    "a mismatch authorizes continuing with broader access",
    "export or share task history automatically",
)


def validate(text: str) -> list[str]:
    lower = " ".join(text.split()).lower()
    failures = [f"missing required task-topology rule: {rule}" for rule in REQUIRED if rule.lower() not in lower]
    failures.extend(f"contradictory task-topology rule: {rule}" for rule in REVERSALS if rule in lower)
    return failures


def self_test(valid: str) -> None:
    assert not validate(valid), "authoritative task-topology contract failed its own validator"
    counterexamples = (
        ("needs the source task's completed history", "does not need the source task's completed history"),
        ("start without that history", "inherit that history"),
        ("remains a bounded part of the current request", "is unrelated to the current request"),
        ("A running turn is not forked history", "A running turn is forked history"),
        ("parallel writers require separate worktrees", "parallel writers may share a worktree"),
        ("before consequential work", "after consequential work"),
        ("only on explicit user request", "automatically"),
    )
    for source, replacement in counterexamples:
        mutated = valid.replace(source, replacement, 1)
        assert validate(mutated), f"task-topology semantic reversal was accepted: {replacement}"


def main() -> int:
    path = Path(sys.argv[1]) if len(sys.argv) == 2 else Path(__file__).resolve().parent.parent / "templates/global/AGENTS.md"
    text = path.read_text()
    failures = validate(text)
    if failures:
        print("native task topology check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1
    self_test(text)
    print("native task topology check passed: authoritative rules and semantic reversals")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
