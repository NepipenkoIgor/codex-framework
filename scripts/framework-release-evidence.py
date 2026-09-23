#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import importlib.util
import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
EVIDENCE = ROOT / "docs" / "framework-release-evidence.json"
RETAINED_DELIVERY = ROOT / "docs" / "framework-release-delivery-evidence"
MAX_AGE = dt.timedelta(days=7)
ARTIFACT_POLICY = "incremental-commit-bound-attestation-v2"
DELIVERY_CASES = ("pending-evidence", "merge-cleanup", "false-positive", "ci-repair")
DELIVERY_SCOPE = "disposable native delivery fixtures; no external delivery acceptance"
DELIVERY_RECEIPT_VERSION = 3
DEBATE_CONFORMANCE_VERSION = 4
GATE_COMMANDS = {
    "deterministicHealth": ["bash", "scripts/framework-health.sh"],
    "tokenEfficiency": ["python3", "scripts/framework-token-budget-check.py", "--live"],
    "effectiveInstallDoctor": ["bash", "scripts/framework-doctor.sh", "--skip-evidence"],
    "nativeSkillLoaderCanary": ["bash", "scripts/framework-skill-loader-live-eval.sh"],
    "liveVersionResolution": ["bash", "scripts/framework-version-drift-check.sh", "--live"],
    "nativeCapabilityCurrency": ["python3", "scripts/framework-native-capability-check.py", "--live"],
    "nativeDeliveryBehavior": ["python3", "scripts/framework-release-evidence.py", "validate-delivery",
                               "--summary", "<delivery-artifact-dir>/summary.json", "--emit-summary"],
    "skillCorpusCertification": ["python3", "scripts/framework-skill-quality.py", "certify-incremental", "--artifact-dir", "<quality-artifact-dir>", "--baseline-evidence", "docs/framework-release-evidence.json"],
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
    retained = RETAINED_DELIVERY.relative_to(ROOT).as_posix()
    if relative == EVIDENCE.relative_to(ROOT).as_posix() \
            or relative == retained or relative.startswith(retained + "/") \
            or "__pycache__" in Path(relative).parts or relative.endswith(".pyc"):
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


def baseline_snapshot() -> tuple[dict[str, Any], dict[str, Any]]:
    raw = EVIDENCE.read_bytes()
    evidence_commit = command_text("git", "log", "-1", "--format=%H", "--", EVIDENCE.relative_to(ROOT).as_posix())
    if not git_commit_exists(evidence_commit):
        raise ValueError("baseline release evidence commit is unavailable")
    committed = subprocess.run(
        ["git", "show", f"{evidence_commit}:{EVIDENCE.relative_to(ROOT).as_posix()}"],
        cwd=ROOT, capture_output=True, check=True,
    ).stdout
    if committed != raw:
        raise ValueError("baseline release evidence differs from its last committed version")
    data = json.loads(raw)
    source_commit = data.get("gitHeadAtGeneration")
    if not isinstance(source_commit, str) or data.get("sourceDigest") != git_digest(source_commit):
        raise ValueError("baseline release evidence is not bound to its source commit")
    return data, {
        "baselineEvidenceCommit": evidence_commit,
        "baselineEvidenceSha256": hashlib.sha256(raw).hexdigest(),
        "baselineSourceCommit": source_commit,
    }


def skill_attestation(artifact_dir: Path) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    baseline, provenance = baseline_snapshot()
    rows, fresh, reused = quality_module().certify_incremental(
        artifact_dir, baseline.get("skillCorpusAttestation")
    )
    provenance.update({"freshSkills": fresh, "reusedSkills": reused})
    return rows, provenance


def validate_skill_attestation(rows: Any) -> None:
    quality_module().validate_compact_attestation(rows)


def validate_skill_provenance(provenance: Any, rows: Any, current_commit: Any) -> list[str]:
    expected = {"baselineEvidenceCommit", "baselineEvidenceSha256", "baselineSourceCommit", "freshSkills", "reusedSkills"}
    if not isinstance(provenance, dict) or set(provenance) != expected:
        return ["skill corpus provenance is malformed"]
    failures: list[str] = []
    evidence_commit = provenance.get("baselineEvidenceCommit")
    source_commit = provenance.get("baselineSourceCommit")
    if not git_commit_exists(str(evidence_commit)) or not git_commit_exists(str(source_commit)):
        return ["skill corpus baseline commit is unavailable"]
    if command("git", "merge-base", "--is-ancestor", str(evidence_commit), str(current_commit)).returncode:
        failures.append("skill corpus baseline evidence is not an ancestor of the release")
    try:
        raw = subprocess.run(
            ["git", "show", f"{evidence_commit}:{EVIDENCE.relative_to(ROOT).as_posix()}"],
            cwd=ROOT, capture_output=True, check=True,
        ).stdout
        baseline = json.loads(raw)
    except (subprocess.CalledProcessError, json.JSONDecodeError):
        return failures + ["skill corpus baseline evidence cannot be read"]
    if provenance.get("baselineEvidenceSha256") != hashlib.sha256(raw).hexdigest():
        failures.append("skill corpus baseline evidence digest mismatch")
    if baseline.get("gitHeadAtGeneration") != source_commit or baseline.get("sourceDigest") != git_digest(str(source_commit)):
        failures.append("skill corpus baseline source binding mismatch")
    names = sorted(quality_module().skill_paths())
    fresh = provenance.get("freshSkills")
    reused = provenance.get("reusedSkills")
    if not isinstance(fresh, list) or not isinstance(reused, list) or sorted(fresh + reused) != names or set(fresh) & set(reused):
        return failures + ["skill corpus fresh/reused partition mismatch"]
    current_by_skill = {row.get("skill"): row for row in rows} if isinstance(rows, list) else {}
    baseline_by_skill = {row.get("skill"): row for row in baseline.get("skillCorpusAttestation", []) if isinstance(row, dict)}
    for skill in reused:
        if current_by_skill.get(skill) != baseline_by_skill.get(skill):
            failures.append(f"reused skill attestation differs from committed baseline: {skill}")
    quality = quality_module()
    for skill in fresh:
        old = baseline_by_skill.get(skill)
        try:
            quality.validate_compact_attestation([old], skill)
        except (KeyError, ValueError):
            continue
        failures.append(f"fresh skill did not require recertification: {skill}")
    return failures


def delivery_source_digest() -> str:
    # Same ordered policy/evaluator/profile bytes used by the delivery producer.
    files = [ROOT / "scripts/framework-delivery-behavior-eval.py", ROOT / "templates/global/AGENTS.md"]
    files.extend(sorted((ROOT / ".codex/agents").glob("*.toml")))
    return hashlib.sha256(b"".join(path.read_bytes() for path in files)).hexdigest()


def delivery_runtime() -> str:
    version = command_text("codex", "--version")
    match = re.fullmatch(r"codex-cli (\d+\.\d+\.\d+)", version)
    if not match:
        raise ValueError("native CLI runtime identity unavailable")
    return match[1]


def delivery_module():
    path = ROOT / "scripts/framework-delivery-behavior-eval.py"
    spec = importlib.util.spec_from_file_location("framework_delivery_behavior", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def validate_delivery_summary(summary: Any, artifact_dir: Path | None = None,
                              require_session_store: bool = True) -> list[str]:
    if not isinstance(summary, dict) or set(summary) != {"sourceDigest", "scope", "results"}:
        return ["native delivery summary is malformed"]
    failures = []
    if summary.get("sourceDigest") != delivery_source_digest():
        failures.append("native delivery source digest does not match evaluator, policy and profiles")
    if summary.get("scope") != DELIVERY_SCOPE:
        failures.append("native delivery scope is unsupported")
    rows = summary.get("results")
    if not isinstance(rows, list) or len(rows) != len(DELIVERY_CASES) or not all(isinstance(row, dict) for row in rows):
        return failures + ["native delivery case coverage is incomplete"]
    if sorted(str(row.get("case")) for row in rows) != sorted(DELIVERY_CASES):
        failures.append("native delivery cases are missing, duplicated or unexpected")
    if any(row.get("status") != "passed" or type(row.get("nativeExitCode")) is not int or row["nativeExitCode"] != 0 for row in rows):
        failures.append("native delivery contains a non-passing result")
    if artifact_dir is None:
        failures.append("native delivery requires raw native/state artifacts; summary claims are insufficient")
    if failures:
        return failures
    try:
        runtime = delivery_runtime()
        module = delivery_module()
        for case in DELIVERY_CASES:
            module.validate_case_artifacts(artifact_dir / case, case, ROOT, runtime,
                                           require_session_store=require_session_store)
    except (OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError) as error:
        failures.append("native delivery artifact validation failed: " + str(error))
    return failures


def artifact_reference(artifact_dir: Path) -> str:
    resolved = artifact_dir.resolve()
    try:
        return resolved.relative_to(ROOT).as_posix()
    except ValueError:
        return str(resolved)


def delivery_receipt(summary: dict, artifact_dir: Path,
                     require_session_store: bool = True) -> dict:
    failures = validate_delivery_summary(summary, artifact_dir, require_session_store)
    if failures:
        raise ValueError("; ".join(failures))
    runtime = delivery_runtime()
    module = delivery_module()
    return {"receiptVersion": DELIVERY_RECEIPT_VERSION,
            "conformanceVersion": DEBATE_CONFORMANCE_VERSION,
            "sourceDigest": summary["sourceDigest"], "cliVersion": runtime,
            "artifactDirectory": artifact_reference(artifact_dir),
            "cases": [module.validate_case_artifacts(
                artifact_dir / case, case, ROOT, runtime,
                require_session_store=require_session_store) for case in DELIVERY_CASES]}


def retain_delivery(source: Path, destination: Path = RETAINED_DELIVERY) -> None:
    source = source.resolve()
    destination = destination.resolve()
    if destination != RETAINED_DELIVERY.resolve():
        raise ValueError("retained delivery destination is not repository-owned")
    summary = json.loads((source / "summary.json").read_text())
    failures = validate_delivery_summary(summary, source, require_session_store=True)
    if failures:
        raise ValueError("; ".join(failures))
    destination.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=".framework-release-delivery-evidence.",
                                  dir=destination.parent))
    try:
        shutil.copy2(source / "summary.json", stage / "summary.json")
        for case in DELIVERY_CASES:
            source_case, target_case = source / case, stage / case
            target_case.mkdir()
            for name in ("events.jsonl", "state-attestation.json", "grade.json"):
                shutil.copy2(source_case / name, target_case / name)
            shutil.copytree(source_case / "native-rollouts", target_case / "native-rollouts")
        retained_summary = json.loads((stage / "summary.json").read_text())
        failures = validate_delivery_summary(retained_summary, stage, require_session_store=False)
        if failures:
            raise ValueError("retained delivery validation failed: " + "; ".join(failures))
        if destination.exists():
            shutil.rmtree(destination)
        stage.rename(destination)
    finally:
        if stage.exists():
            shutil.rmtree(stage)


def validate_debate_conformance(receipt: Any) -> list[str]:
    if not isinstance(receipt, dict) or set(receipt) != {
            "conformanceVersion", "scope", "familyComplete", "bindings", "results"}:
        return ["debate conformance receipt is malformed"]
    if receipt.get("conformanceVersion") != DEBATE_CONFORMANCE_VERSION \
            or receipt.get("scope") != "release-certification" \
            or receipt.get("familyComplete") is not True:
        return ["debate conformance receipt is stale or incomplete"]
    bindings = receipt.get("bindings")
    expected_bindings = delivery_module().debate_bindings(Path("/binding-placeholder"))
    if not isinstance(bindings, dict) or set(bindings) != set(expected_bindings) \
            or any(bindings.get(key) != expected_bindings[key] for key in
                   ("sourceDigest", "contractRevision", "configRevision", "environmentScope")) \
            or not is_nonzero_sha256(bindings.get("taskPathDigest")):
        return ["debate conformance source, contract, config or environment binding is invalid"]
    results = receipt.get("results")
    if not isinstance(results, list) or not results:
        return ["debate conformance finding coverage is incomplete"]
    observed_ids = set()
    observed_phases = set()
    for result in results:
        if not isinstance(result, dict) or set(result) != {
                "batchId", "exchangeId", "findingId", "challengerId", "phase", "severity",
                "claim", "acceptanceRows", "blockedStages", "disposition", "adjudication",
                "status", "reasons", "evidencePointers"}:
            return ["debate conformance finding is malformed"]
        finding_id = result.get("findingId")
        if not all(isinstance(result.get(key), str) and result[key] for key in
                   ("batchId", "exchangeId", "findingId", "challengerId", "claim")) \
                or finding_id in observed_ids \
                or result.get("severity") not in {"low", "medium", "high", "critical"} \
                or not isinstance(result.get("acceptanceRows"), list) or not result["acceptanceRows"] \
                or not isinstance(result.get("blockedStages"), list) or not result["blockedStages"] \
                or result.get("disposition") not in {"resolved", "withdrawn"} \
                or result.get("adjudication") != "accept":
            return ["debate conformance finding identity or closure is invalid"]
        observed_ids.add(finding_id)
        observed_phases.add(result.get("phase"))
        if result.get("status") != "compliant" or result.get("reasons") != []:
            return ["debate conformance contains a non-compliant finding"]
        pointers = result.get("evidencePointers")
        if not isinstance(pointers, list) or not pointers or any(
                not isinstance(pointer, dict) or set(pointer) != {"source", "pointer"}
                or pointer.get("source") not in {"command", "file", "provider", "browser", "trace"}
                or not isinstance(pointer.get("pointer"), str) or not pointer["pointer"]
                for pointer in pointers):
            return ["debate conformance evidence pointer is invalid"]
    return [] if {"pre", "post"} <= observed_phases else ["debate conformance phase coverage is incomplete"]


def validate_delivery_receipt(receipt: Any, require_artifacts: bool = False) -> list[str]:
    if not isinstance(receipt, dict) or set(receipt) != {"receiptVersion", "conformanceVersion", "sourceDigest", "cliVersion", "artifactDirectory", "cases"}:
        return ["native delivery requires a validated artifact receipt"]
    try:
        runtime = delivery_runtime()
    except (OSError, ValueError) as error:
        return [str(error)]
    if receipt.get("receiptVersion") != DELIVERY_RECEIPT_VERSION \
            or receipt.get("conformanceVersion") != DEBATE_CONFORMANCE_VERSION \
            or receipt.get("sourceDigest") != delivery_source_digest() or receipt.get("cliVersion") != runtime:
        return ["native delivery receipt source/runtime binding is stale"]
    cases = receipt.get("cases")
    if not isinstance(cases, list) or len(cases) != len(DELIVERY_CASES) or not all(isinstance(row, dict) for row in cases) or sorted(str(row.get('case')) for row in cases) != sorted(DELIVERY_CASES):
        return ["native delivery receipt coverage is invalid"]
    for row in cases:
        if set(row) != {"case", "verdict", "rootThreadId", "cliVersion", "debateConformance", "artifacts"} or row.get("verdict") != "passed" or row.get("cliVersion") != receipt["cliVersion"] or not re.fullmatch(r"[a-f0-9-]{36}", str(row.get("rootThreadId"))):
            return ["native delivery receipt case is invalid"]
        failures = validate_debate_conformance(row.get("debateConformance"))
        if failures:
            return failures
        files = row.get("artifacts")
        if not isinstance(files, list) or not files or not all(isinstance(file, dict) for file in files):
            return ["native delivery artifact digests missing"]
        names = [file.get('path') for file in files]
        if not all(isinstance(name, str) for name in names):
            return ['native delivery artifact paths are malformed']
        if len(set(names)) != len(names) or not {'events.jsonl', 'state-attestation.json', 'grade.json'} <= set(names) or sum(str(name).startswith('native-rollouts/') for name in names) < 2:
            return ["native delivery raw evidence coverage missing"]
        if any(set(file) != {'path','sha256','bytes'} or not is_nonzero_sha256(file['sha256']) or type(file['bytes']) is not int or file['bytes'] <= 0 or not isinstance(file['path'], str) or Path(file['path']).is_absolute() or '..' in Path(file['path']).parts for file in files):
            return ["native delivery artifact digest record malformed"]
    if require_artifacts:
        try:
            reference = Path(receipt['artifactDirectory'])
            if reference.is_absolute():
                root = reference
                require_session_store = True
            else:
                root = (ROOT / reference).resolve()
                if root != RETAINED_DELIVERY.resolve():
                    raise ValueError("relative artifact directory is not the retained release bundle")
                require_session_store = False
            summary = json.loads((root / 'summary.json').read_text())
            if delivery_receipt(summary, root, require_session_store=require_session_store) != receipt:
                return ["native delivery receipt differs from validated raw evidence"]
        except (OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError) as error:
            return ["native delivery receipt raw validation failed: " + str(error)]
    return []


def gate_records(gate_dir: Path) -> list[dict[str, Any]]:
    records = []
    for name, expected_command in GATE_COMMANDS.items():
        log = gate_dir / f"{name}.log"
        if not log.is_file():
            raise ValueError(f"missing gate log: {log}")
        output = log.read_text()
        records.append({"name": name, "command": expected_command, "exitCode": 0, "output": output, "outputSha256": sha256_text(output)})
    failures = validate_gate_records(records, require_artifacts=True)
    if failures:
        raise ValueError("; ".join(failures))
    return records


def validate_gate_records(records: Any, require_artifacts: bool = False) -> list[str]:
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
        if name == "nativeDeliveryBehavior":
            try:
                failures.extend(validate_delivery_receipt(json.loads(output), require_artifacts))
            except (ValueError, TypeError):
                failures.append("native delivery gate output must be a valid source-bound JSON summary")
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
    attestation, provenance = skill_attestation(Path(args.artifact_dir))
    return {
        "schemaVersion": 4,
        "generatedAt": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
        "sourceDigest": source_digest,
        "gitHeadAtGeneration": head,
        "codexVersion": command_text("codex", "--version") or None,
        "corpus": corpus_metrics(),
        "gateEvidence": gate_records(Path(args.gate_dir)),
        "skillCorpusAttestation": attestation,
        "skillCorpusProvenance": provenance,
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
    expected_top = {"schemaVersion", "generatedAt", "sourceDigest", "gitHeadAtGeneration", "codexVersion", "corpus", "gateEvidence", "skillCorpusAttestation", "skillCorpusProvenance", "artifactPolicy"}
    if not isinstance(current, dict) or set(current) != expected_top:
        failures.append("top-level schema fields are missing or unexpected")
    if current.get("schemaVersion") != 4:
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
    failures.extend(validate_gate_records(current.get("gateEvidence"), require_artifacts=True))
    try:
        validate_skill_attestation(current.get("skillCorpusAttestation"))
    except (OSError, json.JSONDecodeError, KeyError, ValueError) as error:
        failures.append(f"skill corpus attestation is invalid: {error}")
    failures.extend(validate_skill_provenance(
        current.get("skillCorpusProvenance"), current.get("skillCorpusAttestation"), current.get("gitHeadAtGeneration")
    ))
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
    delivery = {"sourceDigest": delivery_source_digest(), "scope": DELIVERY_SCOPE,
                "results": [{"case": case, "status": "passed", "nativeExitCode": 0, "statePassed": True} for case in DELIVERY_CASES]}
    if not validate_delivery_summary(delivery, Path("/nonexistent/summary-only-reproduction")):
        raise AssertionError("fabricated summary with absent artifact files was accepted")
    if not validate_delivery_summary(delivery):
        raise AssertionError("fabricated four-row summary was accepted without raw evidence")
    conformance = {"conformanceVersion": 4, "scope": "release-certification", "familyComplete": True,
                   "bindings": delivery_module().debate_bindings(Path("/fixture/task")),
                   "results": [
                       {"batchId": "delivery-pre", "exchangeId": "delivery-plan-1",
                        "findingId": "PLAN-1", "challengerId": "/root/tester", "phase": "pre",
                        "severity": "high", "claim": "plan counterexample",
                        "acceptanceRows": ["plan"], "blockedStages": ["mutation"],
                        "disposition": "resolved", "adjudication": "accept",
                        "status": "compliant", "reasons": [],
                        "evidencePointers": [{"source": "file", "pointer": "README.md"}]},
                       {"batchId": "delivery-post", "exchangeId": "delivery-result-1",
                        "findingId": "RESULT-1", "challengerId": "/root/tester", "phase": "post",
                        "severity": "high", "claim": "result failure-path attack",
                        "acceptanceRows": ["result"], "blockedStages": ["acceptance"],
                        "disposition": "resolved", "adjudication": "accept",
                        "status": "compliant", "reasons": [],
                        "evidencePointers": [{"source": "command", "pointer": "python3 verify.py --challenge"}]},
                   ]}
    receipt = {"receiptVersion": DELIVERY_RECEIPT_VERSION,
               "conformanceVersion": DEBATE_CONFORMANCE_VERSION,
               "sourceDigest": delivery_source_digest(), "cliVersion": delivery_runtime(),
               "artifactDirectory": "/nonexistent/self-test-evidence", "cases": [
                   {"case": case, "verdict": "passed", "rootThreadId": "12345678-1234-1234-1234-123456789abc", "cliVersion": delivery_runtime(),
                    "debateConformance": conformance,
                    "artifacts": [{"path": path, "sha256": "1" * 64, "bytes": 10} for path in ("events.jsonl", "state-attestation.json", "grade.json", "native-rollouts/root.jsonl", "native-rollouts/child.jsonl")]}
                   for case in DELIVERY_CASES]}
    if not validate_delivery_receipt(receipt, require_artifacts=True):
        raise AssertionError("synthetic receipt was accepted without raw evidence")
    stale = json.loads(json.dumps(receipt)); stale['cliVersion'] = '0.0.1'
    if not validate_delivery_receipt(stale):
        raise AssertionError('old native runtime receipt accepted')
    stale = json.loads(json.dumps(receipt)); stale['receiptVersion'] = 2
    if not validate_delivery_receipt(stale):
        raise AssertionError('old debate receipt accepted')
    unresolved = json.loads(json.dumps(receipt)); unresolved['cases'][0]['debateConformance']['results'][0]['status'] = 'unverifiable'
    if not validate_delivery_receipt(unresolved):
        raise AssertionError('unverifiable debate receipt accepted')
    for row in records:
        if row["name"] == "nativeDeliveryBehavior":
            row["output"] = json.dumps(receipt)
            row["outputSha256"] = sha256_text(row["output"])
    invalid_delivery = []
    invalid = json.loads(json.dumps(delivery)); invalid["results"].pop(); invalid_delivery.append(invalid)
    invalid = json.loads(json.dumps(delivery)); invalid["results"][0]["status"] = "failed"; invalid_delivery.append(invalid)
    invalid = json.loads(json.dumps(delivery)); invalid["results"][0]["status"] = "unavailable"; invalid_delivery.append(invalid)
    invalid = json.loads(json.dumps(delivery)); invalid["sourceDigest"] = "f" * 64; invalid_delivery.append(invalid)
    invalid = json.loads(json.dumps(delivery)); invalid["results"][-1] = invalid["results"][0]; invalid_delivery.append(invalid)
    for invalid in invalid_delivery:
        if not validate_delivery_summary(invalid):
            raise AssertionError("native delivery validator accepted missing/failed/stale evidence")
        forged = json.loads(json.dumps(records))
        row = next(row for row in forged if row["name"] == "nativeDeliveryBehavior")
        row["output"] = json.dumps(invalid); row["outputSha256"] = sha256_text(row["output"])
        if not validate_gate_records(forged):
            raise AssertionError("gate validator accepted invalid delivery JSON with a valid output checksum")
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
    delivery_parser = sub.add_parser("validate-delivery")
    delivery_parser.add_argument("--summary", type=Path, required=True)
    delivery_parser.add_argument("--emit-summary", action="store_true")
    retain_parser = sub.add_parser("retain-delivery")
    retain_parser.add_argument("--source", type=Path, required=True)
    sub.add_parser("self-test")
    args = parser.parse_args()
    if args.command == "validate-delivery":
        try:
            summary = json.loads(args.summary.read_text())
            failures = validate_delivery_summary(summary, args.summary.parent)
        except (OSError, ValueError) as error:
            failures = [str(error)]
        for failure in failures:
            print(failure)
        if not failures and args.emit_summary:
            print(json.dumps(delivery_receipt(summary, args.summary.parent), indent=2, sort_keys=True))
        return 1 if failures else 0
    if args.command == "check":
        return check(args.evidence)
    if args.command == "retain-delivery":
        try:
            retain_delivery(args.source)
        except (OSError, ValueError, json.JSONDecodeError, subprocess.SubprocessError) as error:
            print(f"retained delivery failed: {error}")
            return 1
        print(RETAINED_DELIVERY)
        return 0
    if args.command == "self-test":
        self_test(); return 0
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(payload(args), indent=2, sort_keys=True) + "\n")
    print(EVIDENCE)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
