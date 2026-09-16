#!/usr/bin/env python3
"""Lint declared review policy; this does not inspect or certify a native reviewer context."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
FILES = {
    "AGENTS.md": ROOT / "AGENTS.md",
    "templates/global/AGENTS.md": ROOT / "templates/global/AGENTS.md",
    ".codex/agents/reviewer.toml": ROOT / ".codex/agents/reviewer.toml",
}
REQUIRED = {
    "AGENTS.md": (
        "no inherited conversation turns or prior-agent history",
        "only a neutral evidence bundle",
        "exclude the implementer's plan, reasoning, conclusions, memories, and earlier review commentary",
        "cannot prove the no-history boundary",
        "the parent adjudicates and performs at most one revision cycle",
    ),
    "templates/global/AGENTS.md": (
        "no inherited conversation turns or prior-agent history",
        "Without native no-history spawn, review is unavailable",
        "One revision only for that review",
    ),
    ".codex/agents/reviewer.toml": (
        "fresh context with no prior conversation or agent history",
        "Use only the supplied neutral evidence bundle",
        "report the independence contract as invalid instead of certifying",
        "Do not edit files",
    ),
}
REVERSAL_PATTERNS = (
    r"\b(?:fresh-context|no-history|no inherited conversation turns).{0,80}\b(?:optional|advisory|recommended|not required)\b",
    r"\bdo not require\b.{0,80}\b(?:fresh context|fresh-context|no-history|no inherited conversation)\b",
    r"\breviewer\b.{0,60}\b(?:may|can|should)\b.{0,40}\b(?:inherit|use|consult)\b.{0,80}\b(?:history|memories|prior transcripts|commentary)\b",
    r"^(?!.*\b(?:do not|never|not|exclude|excluded|omit|omitted)\b).*\b(?:include|supply|give|use)\b.{0,80}\b(?:implementer|author)('s)?\b.{0,80}\b(?:plan|reasoning|conclusions?|memories|commentary)\b",
    r"\bindependent\b.{0,80}\b(?:with|despite|without proving)\b.{0,80}\b(?:inherited context|conversation history|no-history boundary)\b",
    r"\bcertif(?:y|ies)\b.{0,100}\b(?:without|unproven|not explicit)\b.{0,80}\b(?:fresh context|fresh-context|no-history boundary)\b",
    r"\breviewer\b.{0,60}\bmay\b.{0,40}\b(?:edit|modify|change|write)\b.{0,40}\b(?:files?|code|implementation)\b",
    r"\b(?:repeat|continue|rerun)\b.{0,80}\b(?:review|revision)\b.{0,80}\b(?:until|recursively|again|multiple)\b",
    r"\b(?:two|multiple|unbounded|more than one)\b.{0,40}\b(?:review|revision)\b",
)


def validate(texts: dict[str, str]) -> list[str]:
    failures: list[str] = []
    for name, required in REQUIRED.items():
        compact = " ".join(texts[name].split())
        for rule in required:
            if rule.lower() not in compact.lower():
                failures.append(f"{name}: missing fresh-review rule: {rule}")
    combined = "\n".join(texts.values())
    sentences = [" ".join(value.split()).lower() for value in re.split(r"(?<=[.!?])\s+|\n+", combined) if value.strip()]
    for pattern in REVERSAL_PATTERNS:
        if any(re.search(pattern, sentence, flags=re.IGNORECASE) for sentence in sentences):
            failures.append(f"contradictory fresh-review rule: {pattern}")
    return failures


def self_test(texts: dict[str, str]) -> None:
    contradictions = (
        "The no inherited conversation turns or prior-agent history rule is optional.",
        "The reviewer may inherit conversation history.",
        "Supply the implementer's plan and reasoning to the reviewer.",
        "The review remains independent despite inherited context.",
        "Certify the result without an explicit fresh-context boundary.",
        "The reviewer may edit the implementation directly.",
        "Repeat the review and revision cycle until no findings remain.",
        "Multiple revision cycles are allowed.",
    )
    for contradiction in contradictions:
        mutated = dict(texts)
        mutated["AGENTS.md"] += f"\n{contradiction}\n"
        assert validate(mutated), f"fresh-review semantic reversal was accepted: {contradiction}"


def main() -> int:
    texts = {name: path.read_text() for name, path in FILES.items()}
    failures = validate(texts)
    if failures:
        print("fresh-context review check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1
    self_test(texts)
    print("review policy lint passed: required clauses and known contradictions; native isolation NOT certified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
