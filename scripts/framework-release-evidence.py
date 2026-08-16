#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import importlib.util
import json
import os
import re
import subprocess
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
EVIDENCE = ROOT / "docs" / "framework-release-evidence.json"
MAX_AGE = dt.timedelta(days=7)
ARTIFACT_POLICY = "compact-validator-attestation-v1"
GATE_COMMANDS = {
    "deterministicHealth": ["bash", "scripts/framework-health.sh"],
    "effectiveInstallDoctor": ["bash", "scripts/framework-doctor.sh", "--skip-evidence"],
    "nativeSkillLoaderCanary": ["bash", "scripts/framework-skill-loader-live-eval.sh"],
    "liveVersionResolution": ["bash", "scripts/framework-version-drift-check.sh", "--live"],
    "nativeCapabilityCurrency": ["python3", "scripts/framework-native-capability-check.py", "--live"],
    "skillCorpusCertification": ["python3", "scripts/framework-skill-quality.py", "certify", "--artifact-dir", "<quality-artifact-dir>"],
}
INCLUDED = (
    "AGENTS.md", "README.md", ".gitignore", ".github", ".codex/config.toml", ".codex/agents",
    ".codex/rules", ".codex/skill-packs.txt", "docs", "evals", "plugins", "scripts", "skills", "templates",
)


def command(*args: str, check: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=ROOT, text=True, capture_output=True, check=check)


def command_text(*args: str) -> str:
    result = command(*args)
    return (result.stdout or result.stderr).strip()


def included_relative(relative: str) -> bool:
    if relative == EVIDENCE.relative_to(ROOT).as_posix() or "__pycache__" in Path(relative).parts or relative.endswith(".pyc"):
        return False
    return any(relative == prefix or relative.startswith(prefix + "/") for prefix in INCLUDED)


def worktree_entries() -> list[tuple[str, bytes]]:
    entries: dict[str, bytes] = {}
    for item in INCLUDED:
        path = ROOT / item
        candidates = [path] if path.is_file() or path.is_symlink() else path.rglob("*") if path.is_dir() else []
        for child in candidates:
            relative = child.relative_to(ROOT).as_posix()
            if not included_relative(relative) or not (child.is_file() or child.is_symlink()):
                continue
            entries[relative] = os.readlink(child).encode() if child.is_symlink() else child.read_bytes()
    return sorted(entries.items())


def git_commit_exists(commit: str) -> bool:
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        return False
    return command("git", "cat-file", "-e", f"{commit}^{{commit}}").returncode == 0


def git_entries(commit: str) -> list[tuple[str, bytes]]:
    if not git_commit_exists(commit):
        raise ValueError("gitHeadAtGeneration is not an existing commit")
    listing = command("git", "ls-tree", "-r", "--name-only", commit, check=True).stdout.splitlines()
    rows = []
    for relative in sorted(path for path in listing if included_relative(path)):
        content = subprocess.run(
            ["git", "show", f"{commit}:{relative}"], cwd=ROOT, capture_output=True, check=True,
        ).stdout
        rows.append((relative, content))
    return rows


def digest_entries(entries: list[tuple[str, bytes]]) -> str:
    value = hashlib.sha256()
    for relative, content in entries:
        encoded = relative.encode()
        value.update(len(encoded).to_bytes(8, "big")); value.update(encoded)
        value.update(len(content).to_bytes(8, "big")); value.update(content)
    return value.hexdigest()


def digest() -> str:
    return digest_entries(worktree_entries())


def git_digest(commit: str) -> str:
    return digest_entries(git_entries(commit))


def corpus_metrics() -> dict[str, int]:
    skills = sorted((ROOT / "skills").glob("*/SKILL.md"))
    descriptions = []
    for skill in skills:
        for line in skill.read_text().splitlines():
            if line.startswith("description: "):
                descriptions.append(line.removeprefix("description: ").strip('"'))
                break
    references = [path for path in sorted((ROOT / "skills").glob("*/references/*")) if path.is_file()]
    return {
        "skills": len(skills),
        "skillMainLines": sum(len(path.read_text().splitlines()) for path in skills),
        "skillDescriptionCharacters": sum(len(item) for item in descriptions),
        "largestSkillBytes": max((path.stat().st_size for path in skills), default=0),
        "references": len(references),
        "versionResolvers": sum(1 for line in (ROOT / "skills" / "version-sources.tsv").read_text().splitlines()[1:] if line.strip() and not line.lstrip().startswith("#")),
    }


def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def is_nonzero_sha256(value: object) -> bool:
    return isinstance(value, str) and bool(re.fullmatch(r"[0-9a-f]{64}", value)) and value != "0" * 64


def quality_module():
    path = ROOT / "scripts" / "framework-skill-quality.py"
    spec = importlib.util.spec_from_file_location("framework_skill_quality", path)
    if spec is None or spec.loader is None:
        raise ValueError("cannot load skill quality validator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def skill_attestation(artifact_dir: Path) -> list[dict[str, Any]]:
    return quality_module().compact_attestation(artifact_dir)


def validate_skill_attestation(rows: Any) -> None:
    quality_module().validate_compact_attestation(rows)


def gate_records(gate_dir: Path) -> list[dict[str, Any]]:
    records = []
    for name, expected_command in GATE_COMMANDS.items():
        log = gate_dir / f"{name}.log"
        if not log.is_file():
            raise ValueError(f"missing gate log: {log}")
        output = log.read_text()
        records.append({"name": name, "command": expected_command, "exitCode": 0, "output": output, "outputSha256": sha256_text(output)})
    return records


def validate_gate_records(records: Any) -> list[str]:
    failures = []
    if not isinstance(records, list) or len(records) != len(GATE_COMMANDS) or not all(isinstance(row, dict) for row in records):
        return ["gate evidence coverage is malformed"]
    by_name = {row.get("name"): row for row in records}
    if len(by_name) != len(records) or set(by_name) != set(GATE_COMMANDS):
        return ["gate evidence names are missing, duplicated, or unexpected"]
    for name, expected_command in GATE_COMMANDS.items():
        row = by_name[name]
        if set(row) != {"name", "command", "exitCode", "output", "outputSha256"}:
            failures.append(f"{name} gate record keys are malformed"); continue
        if row.get("command") != expected_command or row.get("exitCode") != 0:
            failures.append(f"{name} gate command or exit code is invalid")
        output = row.get("output")
        if not isinstance(output, str) or not output or not is_nonzero_sha256(row.get("outputSha256")) or row.get("outputSha256") != sha256_text(output):
            failures.append(f"{name} gate output attestation is invalid")
    return failures


def validate_git_binding(commit: Any, source_digest: Any) -> list[str]:
    if not isinstance(commit, str) or not git_commit_exists(commit):
        return ["gitHeadAtGeneration is not an existing 40-character commit"]
    try:
        commit_digest = git_digest(commit)
    except (OSError, subprocess.CalledProcessError, ValueError):
        return ["gitHeadAtGeneration tree cannot be read"]
    failures = []
    if source_digest != commit_digest:
        failures.append("sourceDigest is not bound to gitHeadAtGeneration")
    if source_digest != digest():
        failures.append("sourceDigest does not match the current framework")
    return failures


def payload(args: argparse.Namespace) -> dict[str, Any]:
    head = command_text("git", "rev-parse", "HEAD")
    source_digest = digest()
    binding_failures = validate_git_binding(head, source_digest)
    if binding_failures:
        raise ValueError("; ".join(binding_failures) + "; commit all included framework source before generating release evidence")
    return {
        "schemaVersion": 3,
        "generatedAt": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
        "sourceDigest": source_digest,
        "gitHeadAtGeneration": head,
        "codexVersion": command_text("codex", "--version") or None,
        "corpus": corpus_metrics(),
        "gateEvidence": gate_records(Path(args.gate_dir)),
        "skillCorpusAttestation": skill_attestation(Path(args.artifact_dir)),
        "artifactPolicy": ARTIFACT_POLICY,
    }


def check(evidence: Path = EVIDENCE) -> int:
    if not evidence.is_file():
        print(f"missing release evidence: {evidence}"); return 1
    try:
        current = json.loads(evidence.read_text())
    except (OSError, json.JSONDecodeError) as error:
        print(f"invalid release evidence: {error}"); return 1
    failures = []
    expected_top = {"schemaVersion", "generatedAt", "sourceDigest", "gitHeadAtGeneration", "codexVersion", "corpus", "gateEvidence", "skillCorpusAttestation", "artifactPolicy"}
    if not isinstance(current, dict) or set(current) != expected_top:
        failures.append("top-level schema fields are missing or unexpected")
    if current.get("schemaVersion") != 3:
        failures.append("unsupported schemaVersion")
    try:
        generated_at = dt.datetime.fromisoformat(current["generatedAt"])
        if generated_at.tzinfo is None:
            raise ValueError("timezone missing")
        age = dt.datetime.now(dt.timezone.utc) - generated_at.astimezone(dt.timezone.utc)
        if age < dt.timedelta(0) or age > MAX_AGE:
            failures.append("release evidence is outside the seven-day freshness window")
    except (KeyError, TypeError, ValueError):
        failures.append("generatedAt is missing or invalid")
    failures.extend(validate_git_binding(current.get("gitHeadAtGeneration"), current.get("sourceDigest")))
    if current.get("corpus") != corpus_metrics():
        failures.append("corpus metrics do not match the current framework")
    runtime = command_text("codex", "--version")
    if not runtime or current.get("codexVersion") != runtime:
        failures.append("codexVersion does not match the current runtime")
    failures.extend(validate_gate_records(current.get("gateEvidence")))
    try:
        validate_skill_attestation(current.get("skillCorpusAttestation"))
    except (OSError, json.JSONDecodeError, KeyError, ValueError) as error:
        failures.append(f"skill corpus attestation is invalid: {error}")
    if current.get("artifactPolicy") != ARTIFACT_POLICY:
        failures.append("artifactPolicy is unsupported")
    if failures:
        print("release evidence check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print(f"release evidence matches source digest {current['sourceDigest']}")
    return 0


def self_test() -> None:
    records = [
        {"name": name, "command": command, "exitCode": 0, "output": f"{name} passed\n", "outputSha256": sha256_text(f"{name} passed\n")}
        for name, command in GATE_COMMANDS.items()
    ]
    if validate_gate_records(records):
        raise AssertionError("valid gate records were rejected")
    counterexamples = []
    invalid = json.loads(json.dumps(records)); invalid[0]["outputSha256"] = "0" * 64; counterexamples.append(invalid)
    invalid = json.loads(json.dumps(records)); invalid[0]["output"] += "tampered"; counterexamples.append(invalid)
    counterexamples.append(records[:-1])
    invalid = json.loads(json.dumps(records)); invalid.append(invalid[0]); counterexamples.append(invalid)
    for invalid in counterexamples:
        if not validate_gate_records(invalid):
            raise AssertionError("release evidence validator accepted forged gate records")
    if not validate_git_binding("bogus", "0" * 64):
        raise AssertionError("release evidence validator accepted malformed git commit")
    if not validate_git_binding("f" * 40, "0" * 64):
        raise AssertionError("release evidence validator accepted nonexistent git commit")
    quality = quality_module()
    rows = []
    for skill in sorted(quality.skill_paths()):
        contract = json.loads((quality.CONTRACT_ROOT / f"{skill}.json").read_text())
        rows.append({
            "skill": skill,
            "skillSha256": quality.sha256_file(quality.skill_paths()[skill]),
            "contractSha256": quality.sha256_file(quality.CONTRACT_ROOT / f"{skill}.json"),
            "routingDigest": quality.routing_digest(skill),
            "semanticDigest": quality.semantic_digest(skill),
            "rawEvidenceDigest": "1" * 64,
            "model": quality.EVALUATOR_MODEL,
            "reasoningEffort": quality.EVALUATOR_REASONING_EFFORT,
            "codexVersion": quality.codex_version(),
            "caseCount": len(quality.route_cases(skill)) + len(contract["reference_routing"]) + len(contract["scenarios"]),
            "verdict": "pass",
        })
    quality.validate_compact_attestation(rows)
    attestation_counterexamples = []
    invalid = json.loads(json.dumps(rows)); invalid[0]["rawEvidenceDigest"] = "0" * 64; attestation_counterexamples.append(invalid)
    invalid = json.loads(json.dumps(rows)); invalid[0]["semanticDigest"] = "2" * 64; attestation_counterexamples.append(invalid)
    attestation_counterexamples.append(rows[:-1])
    invalid = json.loads(json.dumps(rows)); invalid[-1] = invalid[0]; attestation_counterexamples.append(invalid)
    for invalid in attestation_counterexamples:
        try:
            quality.validate_compact_attestation(invalid)
        except ValueError:
            continue
        raise AssertionError("release evidence validator accepted forged skill attestation")
    print("release evidence self-test: passed")


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    check_parser = sub.add_parser("check"); check_parser.add_argument("--evidence", type=Path, default=EVIDENCE)
    write_parser = sub.add_parser("write"); write_parser.add_argument("--artifact-dir", required=True); write_parser.add_argument("--gate-dir", required=True)
    sub.add_parser("self-test")
    args = parser.parse_args()
    if args.command == "check":
        return check(args.evidence)
    if args.command == "self-test":
        self_test(); return 0
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(payload(args), indent=2, sort_keys=True) + "\n")
    print(EVIDENCE)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
