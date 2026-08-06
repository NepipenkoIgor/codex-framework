#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EVIDENCE = ROOT / "docs" / "framework-release-evidence.json"
MAX_AGE = dt.timedelta(days=7)
GATE_FILES = {
    "deterministicHealth": "deterministic-health.passed",
    "effectiveInstallDoctor": "effective-install-doctor.passed",
    "nativeSkillLoaderCanary": "native-skill-loader-canary.passed",
    "liveVersionResolution": "live-version-resolution.passed",
}
INCLUDED = (
    ROOT / "AGENTS.md",
    ROOT / "README.md",
    ROOT / ".gitignore",
    ROOT / ".github",
    ROOT / ".codex" / "config.toml",
    ROOT / ".codex" / "agents",
    ROOT / ".codex" / "rules",
    ROOT / ".codex" / "skill-packs.txt",
    ROOT / "docs",
    ROOT / "evals",
    ROOT / "plugins",
    ROOT / "scripts",
    ROOT / "skills",
    ROOT / "templates",
)


def source_files() -> list[Path]:
    files: set[Path] = set()
    for path in INCLUDED:
        if path.is_file():
            files.add(path)
        elif path.is_dir():
            for child in path.rglob("*"):
                if not child.is_file():
                    continue
                if "__pycache__" in child.parts or child.suffix == ".pyc":
                    continue
                if child == EVIDENCE:
                    continue
                files.add(child)
    return sorted(files, key=lambda item: item.relative_to(ROOT).as_posix())


def digest() -> str:
    value = hashlib.sha256()
    for path in source_files():
        relative = path.relative_to(ROOT).as_posix().encode()
        content = path.read_bytes()
        value.update(len(relative).to_bytes(8, "big"))
        value.update(relative)
        value.update(len(content).to_bytes(8, "big"))
        value.update(content)
    return value.hexdigest()


def command_text(*command: str) -> str:
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    return (result.stdout or result.stderr).strip()


def corpus_metrics() -> dict[str, int]:
    skills = sorted((ROOT / "skills").glob("*/SKILL.md"))
    descriptions = []
    for skill in skills:
        for line in skill.read_text().splitlines():
            if line.startswith("description: "):
                descriptions.append(line.removeprefix("description: ").strip('"'))
                break
    references = sorted((ROOT / "skills").glob("*/references/*"))
    references = [path for path in references if path.is_file()]
    return {
        "skills": len(skills),
        "skillMainLines": sum(len(path.read_text().splitlines()) for path in skills),
        "skillDescriptionCharacters": sum(len(item) for item in descriptions),
        "largestSkillBytes": max((path.stat().st_size for path in skills), default=0),
        "references": len(references),
        "versionResolvers": sum(
            1
            for line in (ROOT / "skills" / "version-sources.tsv").read_text().splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        ),
    }


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def is_sha256(value: object) -> bool:
    return isinstance(value, str) and len(value) == 64 and all(character in "0123456789abcdef" for character in value)


def changed_skill_evidence(artifact_dir: Path) -> dict[str, object]:
    routing_path = artifact_dir / "routing-framework-management.json"
    quality_path = artifact_dir / "quality-framework-management.json"
    routing = json.loads(routing_path.read_text())
    quality = json.loads(quality_path.read_text())
    cases = routing.get("cases")
    if not isinstance(cases, list) or routing.get("verdict") != "pass":
        raise ValueError("routing artifact is not a passing case collection")
    passed = sum(case.get("status") == "pass" for case in cases if isinstance(case, dict))
    if passed != len(cases) or quality.get("skill") != "framework-management" or quality.get("verdict") != "pass":
        raise ValueError("changed skill artifacts are not certified")
    run = quality.get("run")
    if not isinstance(run, dict):
        raise ValueError("quality artifact run metadata is missing")
    current_skill_sha = file_sha256(ROOT / "skills" / "framework-management" / "SKILL.md")
    routing_run = routing.get("run")
    if run.get("skill_sha256") != current_skill_sha \
            or not isinstance(routing_run, dict) \
            or routing_run.get("routing_digest") != run.get("routing_digest"):
        raise ValueError("quality artifacts do not match the current skill or each other")
    return {
        "skill": "framework-management",
        "routingPassed": passed,
        "routingTotal": len(cases),
        "certified": 1,
        "routingArtifactSha256": file_sha256(routing_path),
        "qualityArtifactSha256": file_sha256(quality_path),
        "routingDigest": run.get("routing_digest"),
        "semanticDigest": run.get("semantic_digest"),
        "contractSha256": run.get("contract_sha256"),
        "skillSha256": run.get("skill_sha256"),
    }


def gate_evidence(gate_dir: Path) -> tuple[dict[str, str], dict[str, str]]:
    gates: dict[str, str] = {}
    evidence: dict[str, str] = {}
    for gate, filename in GATE_FILES.items():
        path = gate_dir / filename
        if not path.is_file():
            raise ValueError(f"missing gate receipt: {path}")
        gates[gate] = "pass"
        evidence[gate] = file_sha256(path)
    gates["changedSkillCertification"] = "pass"
    return gates, evidence


def payload(args: argparse.Namespace) -> dict[str, object]:
    git_head = command_text("git", "rev-parse", "HEAD")
    if not git_head or "fatal:" in git_head:
        git_head = None
    gates, receipts = gate_evidence(Path(args.gate_dir))
    changed = changed_skill_evidence(Path(args.artifact_dir))
    return {
        "schemaVersion": 1,
        "generatedAt": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
        "sourceDigest": digest(),
        "gitHeadAtGeneration": git_head,
        "codexVersion": command_text("codex", "--version") or None,
        "corpus": corpus_metrics(),
        "gates": gates,
        "gateReceiptSha256": receipts,
        "changedSkillEvidence": changed,
        "artifactPolicy": "Compact verdict manifest only; raw model transcripts remain task-owned ephemeral data.",
    }


def check(evidence: Path = EVIDENCE) -> int:
    if not evidence.is_file():
        print(f"missing release evidence: {evidence}")
        return 1
    try:
        current = json.loads(evidence.read_text())
    except (OSError, json.JSONDecodeError) as error:
        print(f"invalid release evidence: {error}")
        return 1
    failures = []
    expected_top = {
        "schemaVersion", "generatedAt", "sourceDigest", "gitHeadAtGeneration", "codexVersion",
        "corpus", "gates", "gateReceiptSha256", "changedSkillEvidence", "artifactPolicy",
    }
    if set(current) != expected_top:
        failures.append("top-level schema fields are missing or unexpected")
    if current.get("schemaVersion") != 1:
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
    if current.get("sourceDigest") != digest():
        failures.append("sourceDigest does not match the current framework")
    if current.get("gitHeadAtGeneration") is not None and not isinstance(current.get("gitHeadAtGeneration"), str):
        failures.append("gitHeadAtGeneration is malformed")
    expected_metrics = corpus_metrics()
    if current.get("corpus") != expected_metrics:
        failures.append("corpus metrics do not match the current framework")
    current_codex = command_text("codex", "--version")
    if current.get("codexVersion") != current_codex or not current_codex:
        failures.append("codexVersion does not match the current runtime")
    changed = current.get("changedSkillEvidence")
    required_changed = {
        "skill", "routingPassed", "routingTotal", "certified", "routingArtifactSha256",
        "qualityArtifactSha256", "routingDigest", "semanticDigest", "contractSha256", "skillSha256",
    }
    if not isinstance(changed, dict) or set(changed) != required_changed \
            or changed.get("skill") != "framework-management" \
            or changed.get("routingPassed") != changed.get("routingTotal") \
            or changed.get("routingTotal", 0) < 1 or changed.get("certified") != 1 \
            or any(not is_sha256(changed.get(key)) for key in required_changed - {"skill", "routingPassed", "routingTotal", "certified"}):
        failures.append("changedSkillEvidence is missing or malformed")
    gates = current.get("gates", {})
    expected_gates = {
        "deterministicHealth",
        "effectiveInstallDoctor",
        "nativeSkillLoaderCanary",
        "changedSkillCertification",
        "liveVersionResolution",
    }
    if not isinstance(gates, dict) or set(gates) != expected_gates:
        failures.append("gate fields are missing or unexpected")
    for gate in expected_gates:
        if gates.get(gate) != "pass":
            failures.append(f"{gate} is not pass")
    receipts = current.get("gateReceiptSha256")
    if not isinstance(receipts, dict) or set(receipts) != set(GATE_FILES) \
            or any(not is_sha256(value) for value in receipts.values()):
        failures.append("gate receipt digests are missing or malformed")
    if not isinstance(current.get("artifactPolicy"), str) or not current["artifactPolicy"]:
        failures.append("artifactPolicy is missing")
    if failures:
        print("release evidence check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print(f"release evidence matches source digest {current['sourceDigest']}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    check_parser = subparsers.add_parser("check")
    check_parser.add_argument("--evidence", type=Path, default=EVIDENCE)
    write_parser = subparsers.add_parser("write")
    write_parser.add_argument("--artifact-dir", required=True)
    write_parser.add_argument("--gate-dir", required=True)
    args = parser.parse_args()
    if args.command == "check":
        return check(args.evidence)
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(payload(args), indent=2, sort_keys=True) + "\n")
    print(EVIDENCE)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
