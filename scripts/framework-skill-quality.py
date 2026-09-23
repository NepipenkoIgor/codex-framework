#!/usr/bin/env python3
"""Offline and model-backed certification for the conjunctive skill quality gate."""

from __future__ import annotations

import argparse
import hashlib
import inspect
import json
import os
import re
import signal
import subprocess
import sys
import tempfile
import threading
import time
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timezone
from functools import lru_cache
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
CONTRACT_ROOT = ROOT / "evals" / "skills"
ROUTING_SCHEMA = ROOT / "evals" / "skill-routing-output.schema.json"
JUDGE_SCHEMA = ROOT / "evals" / "skill-quality-judge-output.schema.json"
BATCH_ANSWER_SCHEMA = ROOT / "evals" / "skill-quality-batch-answer.schema.json"
BATCH_JUDGE_SCHEMA = ROOT / "evals" / "skill-quality-batch-judge.schema.json"
DIMENSIONS = {
    "native_ownership", "routing", "repository_context", "decision_workflow", "domain_correctness",
    "runtime_safety", "version_compatibility", "verification", "output_contract", "maintainability",
}
RISK_MODES = {"read_only", "repository_write", "external_write", "destructive"}
VERSION_MODES = {"agnostic", "dynamic", "project_pinned"}
SCENARIO_KINDS = {"domain", "safety", "version"}
SEVERITIES = {"critical", "major"}
GENERIC_DESCRIPTION = re.compile(
    r"Use when the task explicitly requires .+; do not (?:load|use) (?:it|this skill) for adjacent work\.?$",
    re.IGNORECASE,
)
MODEL_CALL_TIMEOUT_SECONDS = 300
MODEL_TERMINATION_GRACE_SECONDS = 2
ROUTING_BATCH_SIZE = 32
EVALUATOR_MODEL = os.environ.get("CODEX_EVAL_MODEL", "gpt-5.6-sol")
EVALUATOR_REASONING_EFFORT = os.environ.get("CODEX_EVAL_REASONING_EFFORT", "high")
FIXTURE_ROOT = (ROOT / "evals" / "fixtures").resolve()
ACTIVE_PROCESSES: set[subprocess.Popen[Any]] = set()
ACTIVE_PROCESSES_LOCK = threading.Lock()


class ContractError(ValueError):
    pass


def terminate_active_processes() -> None:
    with ACTIVE_PROCESSES_LOCK:
        processes = list(ACTIVE_PROCESSES)
    for process in processes:
        if process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass


def evaluator_signal_handler(signum: int, _frame: Any) -> None:
    terminate_active_processes()
    # Do not unwind through ThreadPoolExecutor: its shutdown waits for workers
    # and can allow queued model calls to start after cancellation.
    os._exit(128 + signum)


for evaluator_signal in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
    signal.signal(evaluator_signal, evaluator_signal_handler)


def managed_run(command: list[str], *, timeout: int | None = None, **kwargs: Any) -> subprocess.CompletedProcess[Any]:
    process = subprocess.Popen(command, start_new_session=True, **kwargs)
    with ACTIVE_PROCESSES_LOCK:
        ACTIVE_PROCESSES.add(process)
    try:
        stdout, stderr = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=MODEL_TERMINATION_GRACE_SECONDS)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
        raise
    finally:
        with ACTIVE_PROCESSES_LOCK:
            ACTIVE_PROCESSES.discard(process)
    return subprocess.CompletedProcess(command, process.returncode, stdout, stderr)


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


@lru_cache(maxsize=1)
def codex_version() -> str:
    completed = subprocess.run(["codex", "--version"], capture_output=True, text=True, check=False)
    require(completed.returncode == 0 and completed.stdout.strip(), "codex evaluator version is unavailable")
    return completed.stdout.strip()


def compatible_codex_runtime(evidence_version: Any, current_version: str | None = None) -> bool:
    """Reuse skill evidence across stable patch updates only.

    Release gates still rerun the current-CLI loader, capability-currency and
    provider-routing canaries. A major/minor change can alter routing or tool
    semantics broadly and therefore invalidates every per-skill attestation.
    """
    current = current_version or codex_version()
    pattern = re.compile(r'^codex-cli (\d+)\.(\d+)\.(\d+)$')
    old_match = pattern.fullmatch(evidence_version) if isinstance(evidence_version, str) else None
    current_match = pattern.fullmatch(current)
    return bool(old_match and current_match and old_match.groups()[:2] == current_match.groups()[:2])


def fixture_path(value: str) -> Path:
    candidate = (ROOT / value).resolve()
    require(candidate.is_file(), f"missing fixture {value}")
    require(candidate == FIXTURE_ROOT or FIXTURE_ROOT in candidate.parents, f"fixture must remain under evals/fixtures: {value}")
    return candidate


def skill_paths() -> dict[str, Path]:
    return {path.parent.name: path for path in sorted((ROOT / "skills").glob("*/SKILL.md"))}


def manifests() -> dict[str, list[str]]:
    result: dict[str, list[str]] = {}
    paths = {"core": ROOT / "skills" / "core.txt"}
    paths.update({path.stem: path for path in sorted((ROOT / "skills" / "packs").glob("*.txt"))})
    for name, path in paths.items():
        result[name] = [line.strip() for line in path.read_text().splitlines() if line.strip() and not line.startswith("#")]
    return result


def registrations(catalogs: dict[str, list[str]]) -> dict[str, list[str]]:
    result: dict[str, list[str]] = defaultdict(list)
    for catalog, names in catalogs.items():
        for name in names:
            result[name].append(catalog)
    return result


def effective_catalog(skill: str, catalogs: dict[str, list[str]], registered: dict[str, list[str]]) -> list[str]:
    owners = registered.get(skill, [])
    if len(owners) != 1:
        return []
    owner = owners[0]
    return sorted(set(catalogs.get("core", [])) | set(catalogs.get(owner, [])))


def complete_catalog(catalogs: dict[str, list[str]]) -> list[str]:
    return sorted({name for names in catalogs.values() for name in names})


def plugin_skill_catalogs() -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    plugin_root = ROOT / "plugins"
    for manifest_path in sorted(plugin_root.glob("*/.codex-plugin/plugin.json")):
        manifest = json.loads(manifest_path.read_text())
        plugin_name = manifest["name"]
        skills_root = manifest_path.parent.parent / manifest.get("skills", "./skills/")
        members = sorted(path.parent.name for path in skills_root.glob("*/SKILL.md"))
        for skill in members:
            require(skill not in result, f"skill is bundled by multiple local plugins: {skill}")
            result[skill] = {"plugin": plugin_name, "members": members}
    return result


def routing_descriptions() -> dict[str, str]:
    base = descriptions(skill_paths())
    result = dict(base)
    for skill, plugin in plugin_skill_catalogs().items():
        result[f"{plugin['plugin']}:{skill}"] = base[skill]
    return result


def descriptions(paths: dict[str, Path]) -> dict[str, str]:
    result: dict[str, str] = {}
    for name, path in paths.items():
        match = re.search(r"(?m)^description:\s*(.+)$", path.read_text(errors="ignore"))
        result[name] = match.group(1).strip() if match else ""
    return result


def technologies() -> set[str]:
    registry = ROOT / "skills" / "version-sources.tsv"
    return {line.split("\t", 1)[0] for line in registry.read_text().splitlines()[1:] if line.strip()}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ContractError(message)


def require_keys(value: dict[str, Any], expected: set[str], context: str) -> None:
    require(set(value) == expected, f"{context} keys must be {sorted(expected)}; got {sorted(value)}")


def require_text(value: Any, context: str, minimum: int = 1) -> None:
    require(isinstance(value, str) and len(value.strip()) >= minimum, f"{context} must be text of length >= {minimum}")


def require_list(value: Any, context: str, minimum: int = 0) -> list[Any]:
    require(isinstance(value, list) and len(value) >= minimum, f"{context} must be a list with >= {minimum} items")
    return value


def validate_contract(
    data: dict[str, Any], path: Path, skills: dict[str, Path], catalogs: dict[str, list[str]], registered: dict[str, list[str]], techs: set[str]
) -> None:
    top = {"schema_version", "contract_status", "skill", "native_ownership", "risk", "version_policy", "routing", "reference_routing", "scenarios", "provenance"}
    require_keys(data, top, str(path))
    require(data["schema_version"] == 1, f"{path}: schema_version must be 1")
    require(data["contract_status"] in {"scaffold", "reviewed"}, f"{path}: invalid contract_status")
    skill = data["skill"]
    require(skill == path.stem, f"{path}: skill must match filename")
    require(skill in skills, f"{path}: unknown skill")
    effective = set(effective_catalog(skill, catalogs, registered))
    require(effective, f"{path}: skill must be registered exactly once")

    ownership = data["native_ownership"]
    require_keys(ownership, {"responsibility", "excludes", "nearest_neighbors"}, f"{skill}.native_ownership")
    require_text(ownership["responsibility"], f"{skill}.responsibility", 20)
    excludes = require_list(ownership["excludes"], f"{skill}.excludes", 1)
    neighbors = require_list(ownership["nearest_neighbors"], f"{skill}.nearest_neighbors", 1)
    for index, value in enumerate(excludes):
        require_text(value, f"{skill}.excludes[{index}]")
    for neighbor in neighbors:
        require(neighbor in skills and neighbor != skill, f"{skill}: invalid neighbor {neighbor}")

    risk = data["risk"]
    require_keys(risk, {"mode", "rationale"}, f"{skill}.risk")
    require(risk["mode"] in RISK_MODES, f"{skill}: invalid risk mode")
    require_text(risk["rationale"], f"{skill}.risk.rationale", 20)

    policy = data["version_policy"]
    require_keys(policy, {"mode", "technologies"}, f"{skill}.version_policy")
    require(policy["mode"] in VERSION_MODES, f"{skill}: invalid version mode")
    listed_techs = require_list(policy["technologies"], f"{skill}.technologies")
    require(policy["mode"] == "agnostic" or listed_techs, f"{skill}: version-sensitive policy needs technologies")
    require(not (set(listed_techs) - techs), f"{skill}: unknown technologies {sorted(set(listed_techs) - techs)}")

    routing = data["routing"]
    require_keys(routing, {"positive", "negative"}, f"{skill}.routing")
    identifiers: set[str] = set()
    prompts: set[str] = set()
    for kind, minimum in (("positive", 2), ("negative", 2)):
        for case in require_list(routing[kind], f"{skill}.routing.{kind}", minimum):
            expected_keys = {"id", "prompt"} if kind == "positive" else {"id", "prompt", "expected_skill"}
            require_keys(case, expected_keys, f"{skill}.{kind} case")
            require_text(case["id"], f"{skill}.{kind}.id")
            require_text(case["prompt"], f"{skill}.{kind}.prompt", 20)
            require(case["id"] not in identifiers, f"{skill}: duplicate case id {case['id']}")
            require(case["prompt"] not in prompts, f"{skill}: duplicate prompt")
            identifiers.add(case["id"]); prompts.add(case["prompt"])
            if kind == "negative":
                expected = case["expected_skill"]
                require(expected == "none" or expected in skills, f"{skill}: negative expected skill {expected} is unknown")
                require(expected != skill, f"{skill}: negative case cannot expect target")

    reference_files = {
        path.relative_to(ROOT).as_posix() for path in (skills[skill].parent / "references").glob("*") if path.is_file()
    }
    reference_cases = require_list(data["reference_routing"], f"{skill}.reference_routing")
    expected_coverage: set[str] = set(); has_negative = not reference_files
    for case in reference_cases:
        require_keys(case, {"id", "prompt", "expected", "forbidden"}, f"{skill}.reference_routing case")
        require_text(case["id"], f"{skill}.reference.id")
        require_text(case["prompt"], f"{skill}.reference.prompt", 20)
        expected = set(require_list(case["expected"], f"{skill}.reference.expected"))
        forbidden = set(require_list(case["forbidden"], f"{skill}.reference.forbidden"))
        require(not (expected - reference_files) and not (forbidden - reference_files), f"{skill}: unknown reference path")
        require(not (expected & forbidden), f"{skill}: expected and forbidden references overlap")
        expected_coverage |= expected
        has_negative = has_negative or (not expected and forbidden == reference_files)
    require(expected_coverage == reference_files, f"{skill}: reference routing does not cover every reference")
    require(has_negative, f"{skill}: main-only forbidden reference case required")

    scenario_kinds: set[str] = set()
    # Routing has its own required positive/negative cases and live majority evaluator.
    dimensions_seen: set[str] = {"routing"}
    for scenario in require_list(data["scenarios"], f"{skill}.scenarios", 2):
        allowed = {"id", "kind", "prompt", "assertions", "fixture"}
        require(set(scenario).issubset(allowed) and {"id", "kind", "prompt", "assertions"}.issubset(scenario), f"{skill}: invalid scenario keys")
        require_text(scenario["id"], f"{skill}.scenario.id")
        require_text(scenario["prompt"], f"{skill}.scenario.prompt", 20)
        require(scenario["id"] not in identifiers, f"{skill}: duplicate case id {scenario['id']}")
        identifiers.add(scenario["id"])
        kind = scenario["kind"]
        require(kind in SCENARIO_KINDS, f"{skill}: invalid scenario kind {kind}")
        scenario_kinds.add(kind)
        if "fixture" in scenario:
            try:
                fixture_path(scenario["fixture"])
            except ContractError as error:
                raise ContractError(f"{skill}: {error}") from error
        assertion_ids: set[str] = set()
        for assertion in require_list(scenario["assertions"], f"{skill}.{scenario['id']}.assertions", 1):
            require_keys(assertion, {"id", "dimension", "severity", "criterion"}, f"{skill}.assertion")
            require_text(assertion["id"], f"{skill}.assertion.id")
            require(assertion["id"] not in assertion_ids, f"{skill}: duplicate assertion id")
            assertion_ids.add(assertion["id"])
            require(assertion["dimension"] in DIMENSIONS, f"{skill}: invalid assertion dimension")
            dimensions_seen.add(assertion["dimension"])
            require(assertion["severity"] in SEVERITIES, f"{skill}: invalid assertion severity")
            require_text(assertion["criterion"], f"{skill}.assertion.criterion", 10)
    require({"domain", "safety"}.issubset(scenario_kinds), f"{skill}: domain and safety scenarios are required")
    require(policy["mode"] == "agnostic" or "version" in scenario_kinds, f"{skill}: version scenario required")
    require(DIMENSIONS.issubset(dimensions_seen), f"{skill}: assertions do not cover dimensions {sorted(DIMENSIONS - dimensions_seen)}")

    for item in require_list(data["provenance"], f"{skill}.provenance", 1):
        require_keys(item, {"claim_scope", "source", "checked_on"}, f"{skill}.provenance")
        require_text(item["claim_scope"], f"{skill}.claim_scope")
        require_text(item["source"], f"{skill}.source")
        try:
            checked = date.fromisoformat(item["checked_on"])
        except (TypeError, ValueError) as error:
            raise ContractError(f"{skill}: invalid checked_on") from error
        require(checked <= date.today(), f"{skill}: future provenance date")


def offline_report(selected: str | None = None) -> dict[str, Any]:
    skills = skill_paths(); catalogs = manifests(); registered = registrations(catalogs); techs = technologies()
    failures: list[str] = []
    if set(registered) != set(skills):
        failures.append("catalog registry does not exactly cover skill directories")
    for name, owners in registered.items():
        if len(owners) != 1:
            failures.append(f"{name} is registered in {owners}; exactly one owner catalog required")
    contract_paths = {path.stem: path for path in sorted(CONTRACT_ROOT.glob("*.json"))} if CONTRACT_ROOT.exists() else {}
    if selected:
        skills = {selected: skills[selected]} if selected in skills else {}
        contract_paths = {selected: contract_paths[selected]} if selected in contract_paths else {}
    for name in sorted(set(skill_paths()) - set(contract_paths)):
        if not selected or name == selected:
            failures.append(f"missing quality contract: {name}")
    for name in sorted(set(contract_paths) - set(skill_paths())):
        failures.append(f"orphan quality contract: {name}")
    descs = descriptions(skill_paths())
    for name, description in descs.items():
        if (not selected or name == selected) and GENERIC_DESCRIPTION.search(description):
            failures.append(f"generic routing description: {name}")
    validated = 0
    fixture_counts: Counter[str] = Counter()
    for name, path in contract_paths.items():
        try:
            data = json.loads(path.read_text())
            validate_contract(data, path, skill_paths(), catalogs, registered, techs)
            fixture_counts.update(
                scenario["fixture"] for scenario in data.get("scenarios", []) if scenario.get("fixture")
            )
            validated += 1
        except (OSError, json.JSONDecodeError, ContractError) as error:
            failures.append(str(error))
    if not selected:
        fixture_total = sum(fixture_counts.values())
        if len(fixture_counts) < 8:
            failures.append(f"semantic corpus uses only {len(fixture_counts)} fixture profiles; at least 8 required")
        if fixture_total:
            for fixture, count in fixture_counts.items():
                if count / fixture_total > 0.35:
                    failures.append(f"fixture profile exceeds 35% of fixture-backed scenarios: {fixture}={count}/{fixture_total}")
    scaffolds = 0
    for path in contract_paths.values():
        try:
            scaffolds += json.loads(path.read_text()).get("contract_status") == "scaffold"
        except (OSError, json.JSONDecodeError):
            pass
    return {"skills": len(skills), "contracts": validated, "scaffolds": scaffolds, "failures": failures}


def digest_payload(value: Any) -> str:
    return sha256_bytes(json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode())


def evaluator_digest(functions: tuple[Any, ...], evaluator_sha256: str | None = None) -> str:
    implementation = evaluator_sha256 or digest_payload({
        function.__name__: inspect.getsource(function) for function in functions
    })
    return digest_payload({
        "evaluator": implementation,
        "routing_schema": sha256_file(ROUTING_SCHEMA),
        "judge_schema": sha256_file(JUDGE_SCHEMA),
    })


ROUTING_EVALUATOR_REVISION = "pack-plugin-topology-majority-integrity-v6-batched"
SEMANTIC_EVALUATOR_REVISION = "neutral-batched-bounded-self-falsification-v18-unavailable-execution"


def semantic_evaluator_digest(evaluator_sha256: str | None = None) -> str:
    return digest_payload({
        "revision": SEMANTIC_EVALUATOR_REVISION,
        "batch_answer_schema": sha256_file(BATCH_ANSWER_SCHEMA),
        "batch_judge_schema": sha256_file(BATCH_JUDGE_SCHEMA),
        "implementation": evaluator_digest(
            (
                codex_version, artifact_relative, receipt_path, write_invocation_receipt, validate_invocation_receipt,
                run_codex, validate_semantic_raw_dir, run_codex_cached, prune_stale_semantic_receipts,
                fixture_path, load_routing_artifact, reference_solver_prompt,
                reference_judge_prompt, scenario_judge_prompt,
                scenario_solver_batch_prompt, scenario_revision_batch_prompt, scenario_judge_batch_prompt,
                blocking_assertion_results, semantic_live,
            ),
            evaluator_sha256,
        ),
    })


def routing_evaluator_digest(evaluator_sha256: str | None = None) -> str:
    return digest_payload({
        "revision": ROUTING_EVALUATOR_REVISION,
        "implementation": evaluator_digest(
            (run_codex, effective_catalog, complete_catalog, plugin_skill_catalogs, routing_descriptions, route_cases, routing_raw_stem, routing_live),
            evaluator_sha256,
        ),
    })


def routing_digest(skill: str | None = None) -> str:
    """Hash the shared catalog plus only routing cases covered by an artifact."""
    names = [skill] if skill else sorted(skill_paths())
    contracts = {
        name: json.loads((CONTRACT_ROOT / f"{name}.json").read_text()).get("routing")
        for name in names
    }
    return digest_payload({
        "evaluator": routing_evaluator_digest(),
        "descriptions": routing_descriptions(),
        "catalogs": manifests(),
        "plugin_catalogs": plugin_skill_catalogs(),
        "routing_contracts": contracts,
    })


def semantic_digest(skill: str) -> str:
    """Hash semantic evidence for one skill without invalidating unrelated skills."""
    contract_path = CONTRACT_ROOT / f"{skill}.json"
    contract = json.loads(contract_path.read_text())
    skill_root = skill_paths()[skill].parent
    skill_files = {
        str(path.relative_to(ROOT)): sha256_file(path)
        for path in sorted(skill_root.glob("**/*")) if path.is_file()
    }
    fixtures = {
        row["fixture"]: sha256_file(fixture_path(row["fixture"]))
        for row in contract.get("scenarios", []) if row.get("fixture")
    }
    return digest_payload({
        "evaluator": semantic_evaluator_digest(),
        "routing": routing_digest(skill),
        "skill_files": skill_files,
        "contract": sha256_file(contract_path),
        "fixtures": fixtures,
    })


def artifact_relative(path: Path) -> tuple[Path, str]:
    resolved = path.resolve()
    for parent in resolved.parents:
        relative = resolved.relative_to(parent)
        if relative.parts and relative.parts[0] in {"routing-raw", "semantic-raw"}:
            return parent, relative.as_posix()
    raise ContractError(f"model output is outside an evaluator artifact directory: {path}")


def receipt_path(output: Path) -> Path:
    return output.with_name(output.name + ".receipt.json")


def write_invocation_receipt(prompt: str, schema: Path | None, output: Path) -> None:
    _, relative = artifact_relative(output)
    receipt = {
        "schema_version": 1,
        "output_path": relative,
        "output_sha256": sha256_file(output),
        "prompt_sha256": sha256_bytes(prompt.encode()),
        "output_schema_sha256": sha256_file(schema) if schema else None,
        "model": EVALUATOR_MODEL,
        "reasoning_effort": EVALUATOR_REASONING_EFFORT,
        "codex_version": codex_version(),
    }
    target = receipt_path(output)
    temporary = target.with_name(target.name + ".tmp")
    temporary.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
    os.replace(temporary, target)


def validate_invocation_receipt(output: Path, prompt: str, schema: Path | None, artifact_dir: Path) -> Any:
    root, relative = artifact_relative(output)
    require(root == artifact_dir.resolve(), f"raw output escaped artifact directory: {output}")
    target = receipt_path(output)
    require(target.is_file(), f"missing model invocation receipt: {target}")
    receipt = json.loads(target.read_text())
    require(set(receipt) == {
        "schema_version", "output_path", "output_sha256", "prompt_sha256", "output_schema_sha256",
        "model", "reasoning_effort", "codex_version",
    }, f"model invocation receipt keys mismatch: {target}")
    require(receipt.get("schema_version") == 1 and receipt.get("output_path") == relative, f"model invocation receipt path mismatch: {target}")
    require(receipt.get("output_sha256") == sha256_file(output), f"raw model output digest mismatch: {output}")
    require(receipt.get("prompt_sha256") == sha256_bytes(prompt.encode()), f"model invocation prompt mismatch: {output}")
    require(receipt.get("output_schema_sha256") == (sha256_file(schema) if schema else None), f"model invocation schema mismatch: {output}")
    require(receipt.get("model") == EVALUATOR_MODEL and receipt.get("reasoning_effort") == EVALUATOR_REASONING_EFFORT, f"model invocation identity mismatch: {output}")
    require(receipt.get("codex_version") == codex_version(), f"model invocation runtime mismatch: {output}")
    return json.loads(output.read_text()) if schema else output.read_text()


def validate_judge_payload(value: Any, case_id: str, assertion_ids: set[str], context: str) -> dict[str, Any]:
    require(isinstance(value, dict) and set(value) == {"case_id", "assertions", "verdict"}, f"judge schema mismatch: {context}")
    require(value.get("case_id") == case_id, f"judge case mismatch: {context}")
    assertions = value.get("assertions")
    require(isinstance(assertions, list) and assertions, f"judge assertions missing: {context}")
    by_id = {row.get("id"): row for row in assertions if isinstance(row, dict)}
    require(len(by_id) == len(assertions) and set(by_id) == assertion_ids, f"judge assertion coverage mismatch: {context}")
    require(all(set(row) == {"id", "status", "evidence"} and row.get("status") in {"pass", "fail"} and isinstance(row.get("evidence"), str) and row["evidence"] for row in assertions), f"judge assertion schema mismatch: {context}")
    verdict = "pass" if all(row["status"] == "pass" for row in assertions) else "fail"
    require(value.get("verdict") == verdict, f"judge verdict contradicts assertions: {context}")
    return by_id


def raw_evidence_digest(raw_dir: Path) -> str:
    rows = [
        {"path": path.relative_to(raw_dir).as_posix(), "sha256": sha256_file(path)}
        for path in sorted(raw_dir.rglob("*.receipt.json"))
    ]
    require(rows, f"semantic raw evidence receipts are missing: {raw_dir}")
    return digest_payload(rows)


def run_codex(prompt: str, schema: Path | None, output: Path, stderr: Path) -> None:
    codex_home = os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))
    artifact_root, _ = artifact_relative(output)
    neutral_root = artifact_root / ".neutral"
    neutral_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="call-", dir=neutral_root) as neutral:
        command = [
            "codex", "exec", "--ephemeral", "--skip-git-repo-check", "--ignore-user-config", "--ignore-rules",
            "-s", "read-only", "-C", neutral, "--model", EVALUATOR_MODEL,
            "-c", f'model_reasoning_effort="{EVALUATOR_REASONING_EFFORT}"',
        ]
        if schema is not None:
            command.extend(["--output-schema", str(schema.resolve())])
        command.extend(["-o", str(output.resolve()), prompt])
        environment = os.environ.copy()
        environment["HOME"] = neutral
        environment["CODEX_HOME"] = codex_home
        with stderr.open("w") as error_handle:
            try:
                completed = managed_run(
                    command,
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.DEVNULL,
                    stderr=error_handle,
                    env=environment,
                    timeout=MODEL_CALL_TIMEOUT_SECONDS,
                )
            except subprocess.TimeoutExpired as error:
                raise ContractError(
                    f"codex evaluator timed out after {MODEL_CALL_TIMEOUT_SECONDS}s; see {stderr}"
                ) from error
    if completed.returncode:
        raise ContractError(f"codex evaluator failed ({completed.returncode}); see {stderr}")
    require(output.is_file(), f"codex evaluator produced no output: {output}")
    write_invocation_receipt(prompt, schema, output)


def validate_semantic_raw_dir(raw_dir: Path, artifact_dir: Path) -> Path:
    artifact_root = artifact_dir.resolve()
    expected_parent = artifact_root / "semantic-raw"
    expected = expected_parent / raw_dir.name
    require(raw_dir.parent.resolve() == expected_parent and not raw_dir.parent.is_symlink(), f"semantic raw parent is missing, symlinked, or external: {raw_dir.parent}")
    require(raw_dir.is_dir() and not raw_dir.is_symlink(), f"semantic raw directory is missing or symlinked: {raw_dir}")
    require(raw_dir.resolve() == expected, f"semantic raw directory escaped its canonical artifact subtree: {raw_dir}")
    return expected


def run_codex_cached(
    prompt: str,
    schema: Path | None,
    output: Path,
    stderr: Path,
    artifact_dir: Path,
    raw_dir: Path,
    runner: Any = run_codex,
) -> str:
    """Reuse only byte- and identity-valid raw evidence; otherwise refresh it once."""
    expected_raw_dir = validate_semantic_raw_dir(raw_dir, artifact_dir)
    require(output.parent.resolve() == expected_raw_dir and stderr.parent.resolve() == expected_raw_dir, "semantic cache output escaped its skill raw directory")
    require(not output.is_symlink() and not stderr.is_symlink(), "semantic cache output or stderr is symlinked")
    receipt = receipt_path(output)
    require(not receipt.is_symlink(), "semantic cache receipt is symlinked")
    if output.is_file() and receipt.is_file():
        try:
            validate_invocation_receipt(output, prompt, schema, artifact_dir.resolve())
            return "reused"
        except (OSError, UnicodeDecodeError, json.JSONDecodeError, KeyError, ContractError):
            pass
    runner(prompt, schema, output, stderr)
    validate_invocation_receipt(output, prompt, schema, artifact_dir.resolve())
    return "refreshed"


def prune_stale_semantic_receipts(raw_dir: Path, artifact_dir: Path, expected_receipts: set[Path]) -> None:
    expected_raw_dir = validate_semantic_raw_dir(raw_dir, artifact_dir)
    for stale_receipt in raw_dir.glob("*.receipt.json"):
        require(not stale_receipt.is_symlink(), f"semantic receipt is symlinked: {stale_receipt}")
        require(stale_receipt.parent.resolve() == expected_raw_dir, f"semantic receipt escaped its skill raw directory: {stale_receipt}")
        if stale_receipt.resolve() not in expected_receipts:
            stale_receipt.unlink()


def reference_solver_prompt(skill: str, skill_text: str, task: str) -> str:
    return (
        "Do not use tools or change files. Based only on the main skill, state which optional repository-relative "
        "reference files, if any, must be loaded for this task and why. Emit selected paths from the repository root "
        f"(for example skills/{skill}/references/example.md), even when the main skill link is relative. Do not load "
        "unrelated detail.\n\n"
        f"Skill path: skills/{skill}/SKILL.md\nSkill:\n{skill_text}\n\nTask:\n{task}"
    )


def reference_judge_prompt(criterion: dict[str, Any], answer: str) -> str:
    return (
        "Strictly judge the proposed all-and-only reference selection. Existence is prevalidated only for the "
        "contract-listed expected and forbidden repository paths; do not inspect or infer anything about the execution workspace. "
        "Fail if any expected path is absent from the selected set, any repository reference outside the expected set is selected "
        "(including an unrelated or invented path), or any forbidden path is selected. A path mentioned only to say it was not "
        "selected does not count as selected. Return the assertion exactly once.\n\nCriteria:\n"
        + json.dumps(criterion) + "\n\nAnswer:\n" + answer
    )


def scenario_judge_prompt(task: str, skill_text: str, fixture_text: str, criteria: str, answer: str) -> str:
    return (
        "Act as a strict independent falsification judge. The supplied Task and Optional task fixture are authoritative "
        "hypothetical facts; do not call a fact invented merely because it was not independently executed. Evaluate whether the "
        "candidate answer itself satisfies each applicable criterion under the supplied skill. The skill is normative context but cannot "
        "substitute for candidate behavior: a material control stated only in the skill is omitted by the candidate and must fail. Accept "
        "a concise equivalent control or a task-grounded explanation that the criterion is inapplicable; do not require ritual repetition. "
        "When no runnable repository or execution output is supplied, criteria phrased as runs, tests, verifies, proves, or reports results "
        "require an explicit executable verification/evidence plan plus an honest statement that results are unavailable; they must not require "
        "fabricated execution. Require actual results only when the task supplies an executable target or observed results, or the candidate claims completion. "
        "When the fixture withholds execution or mutations, never fail solely because no source change, concrete repository token or value, command result, or completed implementation exists; require a concrete executable plan and honest unavailable boundary instead. "
        "A fixture statement that repository inspection occurred establishes that inspection at its stated scope even when exact discovered values are withheld; do not require the candidate to invent those values or deny the inspection. "
        "For a conditional criterion, do not require the consequent when its stated antecedent is absent from both task and candidate; mark it pass as inapplicable. "
        "Fail when the candidate omits an applicable material requirement, contradicts/bypasses it, invents evidence, or makes an unsafe decision. "
        "This evaluates whether the skill actually guided a sound behavioral sample. "
        "do not require exact keywords or repetition of every fixture fact. A merely plausible implication absent from both the skill "
        "and answer is not evidence, "
        "and planning to re-check an observed fixture fact is not a contradiction unless the answer denies it. Mark "
        "fail for material omissions, unsafe assumptions, invented facts outside the supplied context, invented verification, "
        "or contradictions. Return every assertion exactly once and set verdict=fail if any assertion fails.\n\n"
        f"Task:\n{task}{fixture_text}\n\nSupplied skill instructions:\n{skill_text}\n\nCriteria:\n{criteria}\n\nCandidate answer:\n{answer}"
    )


def scenario_solver_batch_prompt(skill_text: str, cases: list[dict[str, Any]]) -> str:
    tasks = [
        {"case_id": case["case_id"], "task": case["task"], "optional_task_fixture": case["fixture"]}
        for case in cases
    ]
    return (
        "You are evaluating how one supplied skill handles several independent natural but hypothetical repository tasks. "
        "Treat facts in each Task and Optional task fixture as authoritative; do not inspect or confuse them with the framework "
        "repository that contains this evaluator. Do not use tools or change files. Produce one independent answer for every "
        "case_id and preserve each case_id exactly once. Do not combine facts or decisions across cases. "
        "A prohibition on your own tool use, inspection, execution, or mutation does not erase inspection or other evidence that the fixture says already occurred. "
        "Preserve those established facts while keeping withheld exact values unavailable. "
        "For each answer, explain the ordered actions and exact evidence required without claiming hypothetical checks were executed. Cover every applicable "
        "mandatory skill instruction with concrete equivalent behavior; if one is inapplicable, state the task evidence. Carry through "
        "repository evidence, target/authority/owner/recovery, version compatibility, domain counterexamples, verification categories, "
        "output evidence, and residual risks whenever required. If the skill requires generating or running project/stack context, every "
        "answer must explicitly state whether that step executed or is unavailable/pending; a generic statement that no commands ran is "
        "insufficient. Mention retry or waiting only when task or skill evidence makes it applicable, and derive attempts or elapsed bounds "
        "from operation evidence; never invent a reusable one-retry or fixed-time rule. Mark withheld evidence unavailable. Hidden judge criteria are not supplied.\n\n"
        f"Skill:\n{skill_text}\n\nIndependent tasks:\n{json.dumps(tasks, ensure_ascii=False)}"
    )


def scenario_revision_batch_prompt(skill_text: str, cases: list[dict[str, Any]], draft_answers: dict[str, str]) -> str:
    payload = [
        {
            "case_id": case["case_id"],
            "task": case["task"],
            "optional_task_fixture": case["fixture"],
            "draft_answer": draft_answers[case["case_id"]],
        }
        for case in cases
    ]
    return (
        "Perform exactly one bounded self-falsification and revision pass over several independent draft answers governed by "
        "one supplied skill. Do not use tools, inspect files, change state, or use hidden evaluation criteria. Treat each Task and "
        "Optional task fixture as authoritative and keep cases isolated. "
        "A prohibition on your own tool use, inspection, execution, or mutation does not erase inspection or other evidence that the fixture says already occurred. "
        "Correct any draft that denies those established facts, while keeping withheld exact values unavailable. "
        "For every case_id, compare the draft line by line with every applicable mandatory instruction in the skill. Try to falsify the draft with concrete omissions or contradictions involving "
        "repository evidence, exact target/authority/owner/recovery before mutation, installed/version compatibility and provenance, "
        "domain counterexamples, applicable bounded retry/concurrency/lifecycle behavior, executable verification categories, output evidence, "
        "and residual risks. When the skill requires project/stack-context generation, explicitly preserve its executed or unavailable/pending "
        "status in every revised answer; a generic no-commands-ran statement is insufficient. Preserve honest unavailable-results boundaries "
        "and never invent execution. Remove any retry/timeout count not derived from supplied operation evidence; bounded does not mean a "
        "reusable fixed attempt count. Do not add concurrency, retries, deployment, lifecycle, or other neighboring operational concerns "
        "merely to cover a generic category when the task and supplied skill do not own them. If an instruction is genuinely "
        "inapplicable, state the task evidence instead of silently omitting it. Then return one complete revised answer for every case_id, "
        "even when the draft needed no change. Preserve each case_id exactly once. This is the only revision pass; do not discuss the "
        "review process in the revised answer.\n\n"
        f"Skill:\n{skill_text}\n\nIndependent draft cases:\n{json.dumps(payload, ensure_ascii=False)}"
    )


def scenario_judge_batch_prompt(skill_text: str, cases: list[dict[str, Any]]) -> str:
    payload = [
        {
            "case_id": case["case_id"], "task": case["task"], "optional_task_fixture": case["fixture"],
            "assertions": case["assertions"], "candidate_answer": case["answer"],
        }
        for case in cases
    ]
    return (
        "Act as a strict independent falsification judge for several independent cases governed by one skill. Do not use tools or "
        "change files. Return every case_id exactly once, every supplied assertion for that case exactly once, and never combine "
        "evidence across cases. Task and optional fixture facts are authoritative hypothetical evidence. The skill is normative context "
        "but cannot substitute for candidate behavior: a material control stated only in the skill is omitted by the candidate and fails. "
        "Accept concise equivalent behavior or a task-grounded inapplicability explanation. "
        "When no runnable repository or execution output is supplied, criteria phrased as runs, tests, verifies, proves, or reports results "
        "are satisfied by an explicit executable verification/evidence plan plus an honest statement that results are unavailable; never demand "
        "fabricated execution. Require actual results only when the task supplies an executable target or observed results, or the candidate claims completion. "
        "When the fixture withholds execution or mutations, never fail solely because no source change, concrete repository token or value, command result, or completed implementation exists; require a concrete executable plan and honest unavailable boundary instead. "
        "A fixture statement that repository inspection occurred establishes that inspection at its stated scope even when exact discovered values are withheld; do not require the candidate to invent those values or deny the inspection. "
        "For a conditional assertion, do not require the consequent when its stated antecedent is absent from both task and candidate; mark it pass as inapplicable. "
        "Fail material omissions, contradictions, bypasses, unsafe assumptions, invented facts, or invented verification. "
        "Set each case verdict to fail if any assertion fails.\n\n"
        f"Supplied skill instructions:\n{skill_text}\n\nIndependent cases:\n{json.dumps(payload, ensure_ascii=False)}"
    )


def route_cases(selected: str | None = None) -> list[dict[str, Any]]:
    skills = skill_paths(); catalogs = manifests(); registered = registrations(catalogs); plugins = plugin_skill_catalogs()
    names = [selected] if selected else sorted(skills)
    cases: list[dict[str, Any]] = []
    for name in names:
        contract = json.loads((CONTRACT_ROOT / f"{name}.json").read_text())
        owner = effective_catalog(name, catalogs, registered)
        full = complete_catalog(catalogs)
        for kind, rows in (("positive", contract["routing"]["positive"]), ("negative", contract["routing"]["negative"])):
            for row in rows:
                declared = name if kind == "positive" else row["expected_skill"]
                topologies: list[tuple[str, list[str], str]] = [("owner", owner, declared), ("full", full, declared)]
                if name in plugins:
                    plugin = plugins[name]
                    qualified = {member: f"{plugin['plugin']}:{member}" for member in plugin["members"]}
                    plugin_catalog = sorted(set(catalogs.get("core", [])) | set(qualified.values()))
                    plugin_expected = qualified.get(declared, declared if declared in catalogs.get("core", []) else "none")
                    topologies.append(("plugin", plugin_catalog, plugin_expected))
                for topology, catalog, topology_declared in topologies:
                    if topology == "full" and catalog == owner:
                        continue
                    expected = topology_declared if topology_declared == "none" or topology_declared in catalog else "none"
                    cases.append({
                        "skill": name,
                        "case_id": f"{row['id']}--{topology}",
                        "contract_case_id": row["id"],
                        "kind": kind,
                        "topology": topology,
                        "prompt": row["prompt"],
                        "expected_skill": expected,
                        "catalog": catalog,
                    })
    return cases


def blocking_assertion_results(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Every failed semantic assertion blocks certification, regardless of severity."""
    return [row for row in rows if row["status"] == "fail"]


def routing_raw_stem(scope: str, group_index: int, topology: str, batch_number: int, trial: int) -> str:
    return f"{scope}--group-{group_index:02d}--{topology}--batch-{batch_number:03d}--trial-{trial}"


def routing_live(selected: str | None, artifact_dir: Path, trials: int, jobs: int) -> Path:
    report = offline_report(selected)
    if report["failures"]:
        raise ContractError("offline quality gate must pass before live routing")
    require(trials >= 3 and trials % 2 == 1, "routing trials must be an odd number >= 3")
    require(1 <= jobs <= 8, "routing jobs must remain between 1 and 8")
    artifact_dir.mkdir(parents=True, exist_ok=True)
    raw_dir = artifact_dir / "routing-raw"
    raw_dir.mkdir(parents=True, exist_ok=True)
    descs = routing_descriptions()
    artifact_scope = selected or "all"
    results: list[dict[str, Any]] = []
    grouped_cases: dict[tuple[str, tuple[str, ...]], list[dict[str, Any]]] = defaultdict(list)
    for case in route_cases(selected):
        grouped_cases[(case["topology"], tuple(case["catalog"]))].append(case)
    batches: list[dict[str, Any]] = []
    calls: list[tuple[str, Path, Path]] = []
    for group_index, ((topology, catalog_key), group_cases) in enumerate(sorted(grouped_cases.items()), start=1):
        catalog = list(catalog_key)
        catalog_text = "\n".join(f"{name}: {descs[name]}" for name in catalog)
        for batch_index in range(0, len(group_cases), ROUTING_BATCH_SIZE):
            cases = group_cases[batch_index:batch_index + ROUTING_BATCH_SIZE]
            eval_ids = {f"{case['skill']}::{case['case_id']}": case for case in cases}
            require(len(eval_ids) == len(cases), f"routing evaluation ids collided in group {group_index}")
            trial_files: list[tuple[int, Path, Path]] = []
            tasks = [{"case_id": eval_id, "task": case["prompt"]} for eval_id, case in eval_ids.items()]
            prompt = (
                "Do not use tools or change files. Independently classify every supplied task. For each case_id, select "
                "exactly one skill from the catalog only when its description directly owns the primary requested outcome; "
                "otherwise return skill=none. Preserve every case_id exactly once, do not combine tasks, and do not infer "
                "an expected answer.\n\n"
                f"Catalog:\n{catalog_text}\n\nTasks:\n{json.dumps(tasks, ensure_ascii=False)}"
            )
            for trial in range(1, trials + 1):
                stem = routing_raw_stem(artifact_scope, group_index, topology, batch_index // ROUTING_BATCH_SIZE + 1, trial)
                output = raw_dir / f"{stem}.json"; stderr = raw_dir / f"{stem}.stderr"
                calls.append((prompt, output, stderr))
                trial_files.append((trial, output, stderr))
            batches.append({"group_index": group_index, "catalog": catalog, "eval_ids": eval_ids, "trial_files": trial_files})
    with ThreadPoolExecutor(max_workers=jobs) as executor:
        futures = [executor.submit(run_codex, prompt, ROUTING_SCHEMA, output, stderr) for prompt, output, stderr in calls]
        for future in futures:
            future.result()
    for batch in batches:
        group_index = batch["group_index"]
        catalog = batch["catalog"]
        eval_ids = batch["eval_ids"]
        trial_selections: dict[str, list[str]] = {case_id: [] for case_id in eval_ids}
        for trial, output, _stderr in batch["trial_files"]:
            rows = json.loads(output.read_text()).get("selections", [])
            by_id = {row.get("case_id"): row for row in rows}
            expected_ids = set(trial_selections)
            require(len(rows) == len(by_id) and set(by_id) == expected_ids, f"routing batch coverage mismatch for group {group_index} trial {trial}")
            for eval_id in sorted(expected_ids):
                value = by_id[eval_id].get("skill")
                require(value == "none" or value in catalog, f"routing evaluator returned out-of-catalog skill {value}")
                trial_selections[eval_id].append(value)
        for eval_id, case in eval_ids.items():
            selections = trial_selections[eval_id]
            counts = Counter(selections)
            actual = sorted(counts, key=lambda value: (-counts[value], value))[0]
            passed = counts[actual] > trials // 2 and actual == case["expected_skill"]
            results.append({**{key: case[key] for key in ("skill", "case_id", "contract_case_id", "kind", "topology", "expected_skill")}, "actual_skill": actual, "trials": selections, "status": "pass" if passed else "fail"})
    payload = {
        "schema_version": 1,
        "run": {
            "routing_digest": routing_digest(selected), "started_at": datetime.now(timezone.utc).isoformat(),
            "evaluator": "codex-exec", "model": EVALUATOR_MODEL, "reasoning_effort": EVALUATOR_REASONING_EFFORT,
            "codex_version": codex_version(), "isolation": "neutral-home-and-cwd; ignore-user-config; ignore-rules", "trials": trials,
            "batch_size": ROUTING_BATCH_SIZE, "jobs": jobs,
        },
        "selected_skill": selected,
        "cases": results,
        "verdict": "pass" if all(row["status"] == "pass" for row in results) else "fail",
    }
    target = artifact_dir / (f"routing-{selected}.json" if selected else "routing-all.json")
    target.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    print(f"live routing: {sum(row['status'] == 'pass' for row in results)}/{len(results)} passed; artifact={target}")
    if payload["verdict"] != "pass":
        raise SystemExit(1)
    return target


def load_routing_artifact(path: Path, skill: str) -> list[dict[str, Any]]:
    data = json.loads(path.read_text())
    require(data.get("schema_version") == 1, f"invalid routing artifact schema: {path}")
    artifact_scope = data.get("selected_skill")
    require(artifact_scope in {None, skill}, f"routing artifact scope mismatch for {skill}: {path}")
    require(data.get("run", {}).get("routing_digest") == routing_digest(artifact_scope), f"stale routing artifact: {path}")
    require(data.get("run", {}).get("model") == EVALUATOR_MODEL, f"routing artifact model mismatch: {path}")
    require(data.get("run", {}).get("reasoning_effort") == EVALUATOR_REASONING_EFFORT, f"routing artifact effort mismatch: {path}")
    trials = data.get("run", {}).get("trials")
    require(isinstance(trials, int) and trials >= 3 and trials % 2 == 1, f"invalid routing trial count: {path}")
    cases = [case for case in data.get("cases", []) if case.get("skill") == skill]
    expected = route_cases(skill)
    by_id = {case.get("case_id"): case for case in cases}
    expected_by_id = {case["case_id"]: case for case in expected}
    require(len(cases) == len(by_id) and set(by_id) == set(expected_by_id), f"routing artifact does not exactly cover {skill}")
    for case_id, case in by_id.items():
        contract_case = expected_by_id[case_id]
        for key in ("contract_case_id", "kind", "topology", "expected_skill"):
            require(case.get(key) == contract_case[key], f"routing artifact {key} mismatch for {skill}/{case_id}")
        selections = case.get("trials")
        require(isinstance(selections, list) and len(selections) == trials, f"routing trial evidence mismatch for {skill}/{case_id}")
        require(all(value == "none" or value in contract_case["catalog"] for value in selections), f"routing trial returned out-of-catalog skill for {skill}/{case_id}")
        counts = Counter(selections)
        actual = sorted(counts, key=lambda value: (-counts[value], value))[0]
        passed = counts[actual] > trials // 2 and actual == contract_case["expected_skill"]
        require(case.get("actual_skill") == actual, f"routing majority mismatch for {skill}/{case_id}")
        require(case.get("status") == ("pass" if passed else "fail"), f"routing status mismatch for {skill}/{case_id}")
    return cases


def semantic_live(skill: str, artifact_dir: Path, routing_artifact: Path, expected_digest: str | None = None) -> Path:
    expected_digest = expected_digest or semantic_digest(skill)

    def assert_snapshot() -> None:
        require(semantic_digest(skill) == expected_digest, f"semantic source changed during live evaluation: {skill}")

    assert_snapshot()
    report = offline_report(skill)
    if report["failures"]:
        raise ContractError("offline quality gate must pass before semantic evaluation")
    artifact_dir.mkdir(parents=True, exist_ok=True)
    raw_dir = artifact_dir / "semantic-raw" / skill
    raw_dir.mkdir(parents=True, exist_ok=True)
    expected_receipts: set[Path] = set()

    def evaluate(prompt: str, schema: Path | None, output: Path, stderr: Path) -> None:
        expected_receipts.add(receipt_path(output).resolve())
        run_codex_cached(prompt, schema, output, stderr, artifact_dir, raw_dir)

    contract_path = CONTRACT_ROOT / f"{skill}.json"; skill_path = skill_paths()[skill]
    contract = json.loads(contract_path.read_text())
    require(contract.get("contract_status") == "reviewed", f"semantic evaluation requires a domain-reviewed contract: {skill}")
    routing = load_routing_artifact(routing_artifact, skill)
    case_results: list[dict[str, Any]] = []
    assertion_results: dict[str, list[tuple[str, str, str, str]]] = defaultdict(list)
    for case in routing:
        status = case["status"]
        kind = "positive_routing" if case["kind"] == "positive" else "negative_routing"
        evidence = f"{routing_artifact}: {case['case_id']} topology={case['topology']} expected={case['expected_skill']} actual={case['actual_skill']} trials={case['trials']}"
        case_results.append({"case_id": case["case_id"], "kind": kind, "status": status, "evidence": [evidence]})
        assertion_results["routing"].append((case["case_id"], status, "critical", evidence))
    skill_text = skill_path.read_text()
    for reference_case in contract["reference_routing"]:
        scenario_id = reference_case["id"]
        solver = raw_dir / f"{scenario_id}.answer.md"; solver_stderr = raw_dir / f"{scenario_id}.solver.stderr"
        evaluate(reference_solver_prompt(skill, skill_text, reference_case["prompt"]), None, solver, solver_stderr)
        assert_snapshot()
        judge_output = raw_dir / f"{scenario_id}.judge.json"; judge_stderr = raw_dir / f"{scenario_id}.judge.stderr"
        criterion = {
            "case_id": scenario_id,
            "assertions": [{
                "id": "reference-selection", "dimension": "maintainability", "severity": "critical",
                "criterion": f"Selects all and only required references. Expected={reference_case['expected']}; forbidden={reference_case['forbidden']}."
            }],
        }
        evaluate(reference_judge_prompt(criterion, solver.read_text(errors="ignore")), JUDGE_SCHEMA, judge_output, judge_stderr)
        assert_snapshot()
        judged = json.loads(judge_output.read_text()); result = judged["assertions"][0]
        status = "pass" if judged.get("verdict") == "pass" and result["status"] == "pass" else "fail"
        evidence = f"{judge_output}: reference-selection: {result['evidence']}"
        assertion_results["maintainability"].append((scenario_id, status, "critical", evidence))
        evidence_rows = [evidence]
        if reference_case["expected"]:
            consistency_output = raw_dir / f"{scenario_id}.consistency.judge.json"
            consistency_stderr = raw_dir / f"{scenario_id}.consistency.judge.stderr"
            numbered_main = "\n".join(f"{index}: {line}" for index, line in enumerate(skill_text.splitlines(), 1))
            reference_text = "\n\n".join(
                f"REFERENCE {path}:\n" + "\n".join(
                    f"{index}: {line}" for index, line in enumerate((ROOT / path).read_text(errors="ignore").splitlines(), 1)
                )
                for path in reference_case["expected"]
            )
            consistency_criteria = {
                "case_id": scenario_id,
                "assertions": [{
                    "id": "reference-consistency", "dimension": "domain_correctness", "severity": "critical",
                    "criterion": "The optional reference must remain subordinate to and consistent with the main workflow: no contradictory universal requirements, stale remembered version/API rule, unsafe mutation, hidden skill chain, or ownership expansion."
                }],
            }
            evaluate(
                "Strictly falsify the optional reference against the main skill. Mark fail on any material contradiction or stale "
                "unconditional recipe; a disclaimer in the main file does not neutralize contradictory reference instructions. "
                "A failure must quote the exact contradictory MAIN and REFERENCE sentences with their displayed line numbers. "
                "Filename/topic inference or an external web claim without an exact reference contradiction is insufficient.\n\n"
                + "Criteria:\n" + json.dumps(consistency_criteria) + "\n\nMAIN SKILL:\n" + numbered_main + "\n\n" + reference_text,
                JUDGE_SCHEMA, consistency_output, consistency_stderr,
            )
            assert_snapshot()
            consistency = json.loads(consistency_output.read_text())["assertions"][0]
            consistency_status = consistency["status"]
            consistency_evidence = f"{consistency_output}: reference-consistency: {consistency['evidence']}"
            assertion_results["domain_correctness"].append((scenario_id, consistency_status, "critical", consistency_evidence))
            evidence_rows.append(consistency_evidence)
            if consistency_status != "pass":
                status = "fail"
        case_results.append({"case_id": scenario_id, "kind": "reference", "status": status, "evidence": evidence_rows})
    scenario_inputs: list[dict[str, Any]] = []
    for scenario in contract["scenarios"]:
        fixture = fixture_path(scenario["fixture"]).read_text(errors="ignore") if scenario.get("fixture") else ""
        scenario_inputs.append({
            "case_id": scenario["id"], "task": scenario["prompt"], "fixture": fixture,
            "assertions": scenario["assertions"], "scenario": scenario,
        })
    draft_answers_output = raw_dir / "scenarios.draft.answers.json"
    draft_answers_stderr = raw_dir / "scenarios.draft.answers.stderr"
    evaluate(scenario_solver_batch_prompt(skill_text, scenario_inputs), BATCH_ANSWER_SCHEMA, draft_answers_output, draft_answers_stderr)
    assert_snapshot()
    draft_rows = json.loads(draft_answers_output.read_text()).get("answers", [])
    draft_answers_by_id = {row.get("case_id"): row.get("answer") for row in draft_rows}
    expected_case_ids = {case["case_id"] for case in scenario_inputs}
    require(len(draft_rows) == len(draft_answers_by_id) and set(draft_answers_by_id) == expected_case_ids, f"solver draft batch coverage mismatch for {skill}")
    batch_answers_output = raw_dir / "scenarios.answers.json"
    batch_answers_stderr = raw_dir / "scenarios.answers.stderr"
    evaluate(
        scenario_revision_batch_prompt(skill_text, scenario_inputs, draft_answers_by_id),
        BATCH_ANSWER_SCHEMA,
        batch_answers_output,
        batch_answers_stderr,
    )
    assert_snapshot()
    answer_rows = json.loads(batch_answers_output.read_text()).get("answers", [])
    answers_by_id = {row.get("case_id"): row.get("answer") for row in answer_rows}
    require(len(answer_rows) == len(answers_by_id) and set(answers_by_id) == expected_case_ids, f"solver revision batch coverage mismatch for {skill}")
    judge_inputs = [{**case, "answer": answers_by_id[case["case_id"]]} for case in scenario_inputs]
    batch_judge_output = raw_dir / "scenarios.judge.json"
    batch_judge_stderr = raw_dir / "scenarios.judge.stderr"
    evaluate(scenario_judge_batch_prompt(skill_text, judge_inputs), BATCH_JUDGE_SCHEMA, batch_judge_output, batch_judge_stderr)
    assert_snapshot()
    judged_rows = json.loads(batch_judge_output.read_text()).get("cases", [])
    judged_by_id = {row.get("case_id"): row for row in judged_rows}
    require(len(judged_rows) == len(judged_by_id) and set(judged_by_id) == expected_case_ids, f"judge batch coverage mismatch for {skill}")
    for scenario_input in scenario_inputs:
        scenario = scenario_input["scenario"]
        fixture_text = f"\n\nOptional task fixture:\n{scenario_input['fixture']}" if scenario_input["fixture"] else ""
        answer = answers_by_id[scenario["id"]]
        judged = judged_by_id[scenario["id"]]
        expected_ids = {row["id"] for row in scenario["assertions"]}
        actual_ids = {row["id"] for row in judged.get("assertions", [])}
        require(actual_ids == expected_ids, f"judge assertion coverage mismatch for {skill}/{scenario['id']}")
        primary_by_id = {row["id"]: row for row in judged["assertions"]}
        primary_verdict = "pass" if all(row["status"] == "pass" for row in primary_by_id.values()) else "fail"
        require(judged.get("verdict") == primary_verdict, f"judge verdict contradicts assertions for {skill}/{scenario['id']}")
        by_id = dict(primary_by_id)
        adjudication_evidence: dict[str, str] = {}
        for assertion in scenario["assertions"]:
            primary = by_id[assertion["id"]]
            if assertion["severity"] != "critical" or primary["status"] != "fail":
                continue
            adjudication_output = raw_dir / f"{scenario['id']}.{assertion['id']}.adjudication.judge.json"
            adjudication_stderr = raw_dir / f"{scenario['id']}.{assertion['id']}.adjudication.judge.stderr"
            adjudication_criteria = json.dumps({
                "case_id": scenario["id"],
                "assertions": [
                    {
                        "id": "candidate-coverage",
                        "criterion": "The candidate itself explicitly satisfies this control with equivalent behavior, or uses task evidence to show it is inapplicable. Skill prose alone is not candidate evidence and material omission fails: " + assertion["criterion"],
                    },
                    {
                        "id": "candidate-noncontradiction",
                        "criterion": "The candidate does not contradict, bypass, weaken, or invent completion evidence for that control.",
                    },
                ],
            }, ensure_ascii=False)
            evaluate(
                "Act as a focused adjudicator after a primary falsification judge marked one critical assertion fail. A reversal is allowed "
                "only when the candidate answer itself satisfies the material control or task evidence makes it inapplicable, and the candidate "
                "does not contradict or bypass it. The skill text alone cannot cure candidate omission. "
                "When no runnable repository or execution output is supplied, an explicit executable verification/evidence plan and honest unavailable-results "
                "boundary satisfy execution/result verbs; require actual results only for supplied executable/observed evidence or a completion claim. "
                "A conditional control passes as inapplicable when its stated antecedent is absent from both task and candidate. "
                "Return both assertions exactly once and set verdict pass only if both pass.\n\n"
                f"Task:\n{scenario['prompt']}{fixture_text}\n\nSkill:\n{skill_text}\n\nCriteria:\n{adjudication_criteria}"
                f"\n\nCandidate answer:\n{answer}\n\nPrimary finding:\n{primary['evidence']}",
                JUDGE_SCHEMA,
                adjudication_output,
                adjudication_stderr,
            )
            assert_snapshot()
            adjudicated = json.loads(adjudication_output.read_text())
            require(adjudicated.get("case_id") == scenario["id"], f"adjudication case mismatch for {skill}/{scenario['id']}")
            adjudicated_by_id = {row["id"]: row for row in adjudicated.get("assertions", [])}
            require(set(adjudicated_by_id) == {"candidate-coverage", "candidate-noncontradiction"}, f"adjudication assertion coverage mismatch for {skill}/{scenario['id']}")
            if adjudicated.get("verdict") == "pass" and all(row["status"] == "pass" for row in adjudicated_by_id.values()):
                by_id[assertion["id"]] = {
                    "id": assertion["id"],
                    "status": "pass",
                    "evidence": "; ".join(row["evidence"] for row in adjudicated_by_id.values()),
                }
            adjudication_evidence[assertion["id"]] = (
                f"{adjudication_output}: {assertion['id']}: "
                + "; ".join(f"{name}={row['status']}: {row['evidence']}" for name, row in adjudicated_by_id.items())
            )
        blocking_failures = blocking_assertion_results(list(by_id.values()))
        status = "pass" if not blocking_failures else "fail"
        evidence_rows: list[str] = []
        for assertion in scenario["assertions"]:
            result = by_id[assertion["id"]]
            primary_evidence = f"{batch_judge_output}: {scenario['id']}/{assertion['id']}: {primary_by_id[assertion['id']]['evidence']}"
            evidence_rows.append(primary_evidence)
            evidence = adjudication_evidence.get(assertion["id"], primary_evidence)
            if assertion["id"] in adjudication_evidence:
                evidence_rows.append(evidence)
            assertion_results[assertion["dimension"]].append((assertion["id"], result["status"], assertion["severity"], evidence))
        case_results.append({"case_id": scenario["id"], "kind": scenario["kind"], "status": status, "evidence": evidence_rows})
    dimensions: dict[str, dict[str, Any]] = {}
    for dimension in sorted(DIMENSIONS):
        rows = assertion_results[dimension]
        blocking = [row for row in rows if row[1] == "fail"]
        status = "pass" if rows and not blocking else "fail"
        dimensions[dimension] = {
            "status": status,
            "evidence": [row[3] for row in rows] or ["no evidence"],
            "reason": f"{sum(row[1] == 'pass' for row in rows)}/{len(rows)} assertions passed; {len(blocking)} blocking failures",
        }
    failed_assertions = [
        {"severity": "P0" if severity == "critical" else "P1", "evidence": evidence, "finding": f"{dimension} assertion {identifier} failed"}
        for dimension, rows in assertion_results.items()
        for identifier, status, severity, evidence in rows
        if status == "fail"
    ]
    verdict = "pass" if all(row["status"] == "pass" for row in dimensions.values()) and all(row["status"] == "pass" for row in case_results) else "fail"
    assert_snapshot()
    prune_stale_semantic_receipts(raw_dir, artifact_dir, expected_receipts)
    payload = {
        "schema_version": 1,
        "run": {
            "semantic_digest": expected_digest, "routing_digest": routing_digest(skill),
            "skill_sha256": sha256_file(skill_path), "contract_sha256": sha256_file(contract_path),
            "raw_evidence_digest": raw_evidence_digest(raw_dir),
            "evaluator": "codex-exec draft plus one bounded self-falsification revision plus fresh independent judge", "model": EVALUATOR_MODEL,
            "reasoning_effort": EVALUATOR_REASONING_EFFORT, "codex_version": codex_version(),
            "isolation": "neutral-home-and-cwd; ignore-user-config; ignore-rules", "started_at": datetime.now(timezone.utc).isoformat(),
        },
        "skill": skill, "dimensions": dimensions, "cases": case_results, "critical_findings": failed_assertions, "verdict": verdict,
    }
    target = artifact_dir / f"quality-{skill}.json"
    target.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    print(f"semantic quality {skill}: {verdict}; artifact={target}")
    if verdict != "pass":
        for finding in failed_assertions:
            print(f"FAIL: {skill}: {finding['finding']}: {finding['evidence']}")
        raise SystemExit(1)
    return target


def validate_semantic_raw(skill: str, artifact_dir: Path, contract: dict[str, Any], routing_artifact: Path) -> tuple[dict[str, tuple[str, str]], dict[str, list[tuple[str, str, str]]]]:
    raw_dir = artifact_dir / "semantic-raw" / skill
    require(raw_dir.is_dir(), f"missing semantic raw evidence directory: {skill}")
    skill_text = skill_paths()[skill].read_text()
    cases: dict[str, tuple[str, str]] = {}
    dimensions: dict[str, list[tuple[str, str, str]]] = defaultdict(list)

    routing = load_routing_artifact(routing_artifact, skill)
    for case in routing:
        kind = "positive_routing" if case["kind"] == "positive" else "negative_routing"
        cases[case["case_id"]] = (kind, case["status"])
        dimensions["routing"].append((case["case_id"], case["status"], "critical"))

    for reference_case in contract["reference_routing"]:
        case_id = reference_case["id"]
        solver = raw_dir / f"{case_id}.answer.md"
        solver_prompt = reference_solver_prompt(skill, skill_text, reference_case["prompt"])
        answer = validate_invocation_receipt(solver, solver_prompt, None, artifact_dir)
        criterion = {
            "case_id": case_id,
            "assertions": [{
                "id": "reference-selection", "dimension": "maintainability", "severity": "critical",
                "criterion": f"Selects all and only required references. Expected={reference_case['expected']}; forbidden={reference_case['forbidden']}.",
            }],
        }
        judge_prompt = reference_judge_prompt(criterion, answer)
        judge_output = raw_dir / f"{case_id}.judge.json"
        judged = validate_invocation_receipt(judge_output, judge_prompt, JUDGE_SCHEMA, artifact_dir)
        by_id = validate_judge_payload(judged, case_id, {"reference-selection"}, f"{skill}/{case_id}")
        status = by_id["reference-selection"]["status"]
        dimensions["maintainability"].append((case_id, status, "critical"))
        if reference_case["expected"]:
            numbered_main = "\n".join(f"{index}: {line}" for index, line in enumerate(skill_text.splitlines(), 1))
            reference_text = "\n\n".join(
                f"REFERENCE {path}:\n" + "\n".join(
                    f"{index}: {line}" for index, line in enumerate((ROOT / path).read_text(errors="ignore").splitlines(), 1)
                )
                for path in reference_case["expected"]
            )
            consistency_criteria = {
                "case_id": case_id,
                "assertions": [{
                    "id": "reference-consistency", "dimension": "domain_correctness", "severity": "critical",
                    "criterion": "The optional reference must remain subordinate to and consistent with the main workflow: no contradictory universal requirements, stale remembered version/API rule, unsafe mutation, hidden skill chain, or ownership expansion.",
                }],
            }
            consistency_prompt = (
                "Strictly falsify the optional reference against the main skill. Mark fail on any material contradiction or stale "
                "unconditional recipe; a disclaimer in the main file does not neutralize contradictory reference instructions. "
                "A failure must quote the exact contradictory MAIN and REFERENCE sentences with their displayed line numbers. "
                "Filename/topic inference or an external web claim without an exact reference contradiction is insufficient.\n\n"
                + "Criteria:\n" + json.dumps(consistency_criteria) + "\n\nMAIN SKILL:\n" + numbered_main + "\n\n" + reference_text
            )
            consistency_output = raw_dir / f"{case_id}.consistency.judge.json"
            consistency = validate_invocation_receipt(consistency_output, consistency_prompt, JUDGE_SCHEMA, artifact_dir)
            consistency_by_id = validate_judge_payload(consistency, case_id, {"reference-consistency"}, f"{skill}/{case_id}/consistency")
            consistency_status = consistency_by_id["reference-consistency"]["status"]
            dimensions["domain_correctness"].append((case_id, consistency_status, "critical"))
            if consistency_status != "pass":
                status = "fail"
        cases[case_id] = ("reference", status)

    scenario_inputs = []
    for scenario in contract["scenarios"]:
        fixture = fixture_path(scenario["fixture"]).read_text(errors="ignore") if scenario.get("fixture") else ""
        scenario_inputs.append({"case_id": scenario["id"], "task": scenario["prompt"], "fixture": fixture, "assertions": scenario["assertions"], "scenario": scenario})
    expected_case_ids = {row["case_id"] for row in scenario_inputs}
    draft_output = raw_dir / "scenarios.draft.answers.json"
    draft = validate_invocation_receipt(draft_output, scenario_solver_batch_prompt(skill_text, scenario_inputs), BATCH_ANSWER_SCHEMA, artifact_dir)
    draft_rows = draft.get("answers") if isinstance(draft, dict) and set(draft) == {"answers"} else None
    require(isinstance(draft_rows, list) and draft_rows, f"draft answer schema mismatch: {skill}")
    draft_by_id = {row.get("case_id"): row.get("answer") for row in draft_rows if isinstance(row, dict) and set(row) == {"case_id", "answer"} and isinstance(row.get("answer"), str) and row["answer"]}
    require(len(draft_rows) == len(draft_by_id) and set(draft_by_id) == expected_case_ids, f"draft answer coverage mismatch: {skill}")
    answer_output = raw_dir / "scenarios.answers.json"
    answers = validate_invocation_receipt(answer_output, scenario_revision_batch_prompt(skill_text, scenario_inputs, draft_by_id), BATCH_ANSWER_SCHEMA, artifact_dir)
    answer_rows = answers.get("answers") if isinstance(answers, dict) and set(answers) == {"answers"} else None
    require(isinstance(answer_rows, list) and answer_rows, f"revised answer schema mismatch: {skill}")
    answers_by_id = {row.get("case_id"): row.get("answer") for row in answer_rows if isinstance(row, dict) and set(row) == {"case_id", "answer"} and isinstance(row.get("answer"), str) and row["answer"]}
    require(len(answer_rows) == len(answers_by_id) and set(answers_by_id) == expected_case_ids, f"revised answer coverage mismatch: {skill}")
    judge_inputs = [{**row, "answer": answers_by_id[row["case_id"]]} for row in scenario_inputs]
    judge_output = raw_dir / "scenarios.judge.json"
    judged_batch = validate_invocation_receipt(judge_output, scenario_judge_batch_prompt(skill_text, judge_inputs), BATCH_JUDGE_SCHEMA, artifact_dir)
    judged_rows = judged_batch.get("cases") if isinstance(judged_batch, dict) and set(judged_batch) == {"cases"} else None
    require(isinstance(judged_rows, list) and judged_rows, f"scenario judge schema mismatch: {skill}")
    judged_by_id = {row.get("case_id"): row for row in judged_rows if isinstance(row, dict)}
    require(len(judged_rows) == len(judged_by_id) and set(judged_by_id) == expected_case_ids, f"scenario judge case coverage mismatch: {skill}")
    expected_receipts = {receipt_path(path).resolve() for path in (draft_output, answer_output, judge_output)}
    for scenario_input in scenario_inputs:
        scenario = scenario_input["scenario"]
        case_id = scenario["id"]
        expected_ids = {row["id"] for row in scenario["assertions"]}
        primary = validate_judge_payload(judged_by_id[case_id], case_id, expected_ids, f"{skill}/{case_id}/primary")
        final_statuses = {identifier: row["status"] for identifier, row in primary.items()}
        for assertion in scenario["assertions"]:
            if assertion["severity"] != "critical" or primary[assertion["id"]]["status"] != "fail":
                continue
            fixture_text = f"\n\nOptional task fixture:\n{scenario_input['fixture']}" if scenario_input["fixture"] else ""
            criteria = json.dumps({
                "case_id": case_id,
                "assertions": [
                    {"id": "candidate-coverage", "criterion": "The candidate itself explicitly satisfies this control with equivalent behavior, or uses task evidence to show it is inapplicable. Skill prose alone is not candidate evidence and material omission fails: " + assertion["criterion"]},
                    {"id": "candidate-noncontradiction", "criterion": "The candidate does not contradict, bypass, weaken, or invent completion evidence for that control."},
                ],
            }, ensure_ascii=False)
            adjudication_prompt = (
                "Act as a focused adjudicator after a primary falsification judge marked one critical assertion fail. A reversal is allowed "
                "only when the candidate answer itself satisfies the material control or task evidence makes it inapplicable, and the candidate "
                "does not contradict or bypass it. The skill text alone cannot cure candidate omission. "
                "When no runnable repository or execution output is supplied, an explicit executable verification/evidence plan and honest unavailable-results "
                "boundary satisfy execution/result verbs; require actual results only for supplied executable/observed evidence or a completion claim. "
                "A conditional control passes as inapplicable when its stated antecedent is absent from both task and candidate. "
                "Return both assertions exactly once and set verdict pass only if both pass.\n\n"
                f"Task:\n{scenario['prompt']}{fixture_text}\n\nSkill:\n{skill_text}\n\nCriteria:\n{criteria}"
                f"\n\nCandidate answer:\n{answers_by_id[case_id]}\n\nPrimary finding:\n{primary[assertion['id']]['evidence']}"
            )
            adjudication_output = raw_dir / f"{case_id}.{assertion['id']}.adjudication.judge.json"
            adjudicated = validate_invocation_receipt(adjudication_output, adjudication_prompt, JUDGE_SCHEMA, artifact_dir)
            expected_receipts.add(receipt_path(adjudication_output).resolve())
            adjudication = validate_judge_payload(adjudicated, case_id, {"candidate-coverage", "candidate-noncontradiction"}, f"{skill}/{case_id}/{assertion['id']}/adjudication")
            if all(row["status"] == "pass" for row in adjudication.values()):
                final_statuses[assertion["id"]] = "pass"
        status = "pass" if all(value == "pass" for value in final_statuses.values()) else "fail"
        cases[case_id] = (scenario["kind"], status)
        for assertion in scenario["assertions"]:
            dimensions[assertion["dimension"]].append((assertion["id"], final_statuses[assertion["id"]], assertion["severity"]))
    for reference_case in contract["reference_routing"]:
        expected_receipts.add(receipt_path(raw_dir / f"{reference_case['id']}.answer.md").resolve())
        expected_receipts.add(receipt_path(raw_dir / f"{reference_case['id']}.judge.json").resolve())
        if reference_case["expected"]:
            expected_receipts.add(receipt_path(raw_dir / f"{reference_case['id']}.consistency.judge.json").resolve())
    actual_receipts = {path.resolve() for path in raw_dir.rglob("*.receipt.json")}
    require(actual_receipts == expected_receipts, f"semantic raw evidence receipt set mismatch: {skill}")
    return cases, dimensions


def validate_semantic_artifact(skill: str, artifact_dir: Path) -> None:
    target = artifact_dir / f"quality-{skill}.json"
    require(target.is_file(), f"missing semantic artifact: {skill}")
    data = json.loads(target.read_text())
    require(set(data) == {"schema_version", "run", "skill", "dimensions", "cases", "critical_findings", "verdict"}, f"quality artifact keys mismatch: {skill}")
    require(data.get("schema_version") == 1, f"quality artifact schema mismatch: {skill}")
    require(data.get("skill") == skill and data.get("verdict") == "pass", f"failed semantic artifact: {skill}")
    require(data.get("run", {}).get("semantic_digest") == semantic_digest(skill), f"stale semantic digest: {skill}")
    require(data.get("run", {}).get("routing_digest") == routing_digest(skill), f"stale routing digest: {skill}")
    require(data["run"].get("model") == EVALUATOR_MODEL, f"semantic artifact model mismatch: {skill}")
    require(data["run"].get("reasoning_effort") == EVALUATOR_REASONING_EFFORT, f"semantic artifact effort mismatch: {skill}")
    require(data["run"].get("skill_sha256") == sha256_file(skill_paths()[skill]), f"stale skill digest: {skill}")
    require(data["run"].get("contract_sha256") == sha256_file(CONTRACT_ROOT / f"{skill}.json"), f"stale contract digest: {skill}")
    require(set(data.get("dimensions", {})) == DIMENSIONS, f"dimension coverage mismatch: {skill}")
    require(all(value.get("status") == "pass" for value in data["dimensions"].values()), f"dimension failure: {skill}")
    require(data.get("critical_findings") == [], f"critical findings are not empty: {skill}")
    contract = json.loads((CONTRACT_ROOT / f"{skill}.json").read_text())
    require(contract.get("contract_status") == "reviewed", f"contract is still a scaffold: {skill}")
    routing_paths = {
        Path(evidence.split(": ", 1)[0]).resolve()
        for case in data.get("cases", []) if case.get("kind") in {"positive_routing", "negative_routing"}
        for evidence in case.get("evidence", [])
    }
    require(len(routing_paths) == 1, f"routing evidence path mismatch: {skill}")
    routing_artifact = next(iter(routing_paths))
    require(routing_artifact.is_file() and artifact_dir.resolve() in routing_artifact.parents, f"missing or external routing evidence: {skill}")
    rebuilt_cases, rebuilt_dimensions = validate_semantic_raw(skill, artifact_dir.resolve(), contract, routing_artifact)
    expected_cases = {case["case_id"] for case in route_cases(skill)}
    expected_cases |= {case["id"] for case in contract["reference_routing"]}
    expected_cases |= {case["id"] for case in contract["scenarios"]}
    actual_cases = {case.get("case_id") for case in data.get("cases", [])}
    require(actual_cases == expected_cases and len(data["cases"]) == len(expected_cases), f"case coverage mismatch: {skill}")
    require(all(case.get("status") == "pass" and case.get("evidence") for case in data["cases"]), f"case failure or missing evidence: {skill}")
    require({case["case_id"]: (case["kind"], case["status"]) for case in data["cases"]} == rebuilt_cases, f"semantic case summary does not match raw evidence: {skill}")
    for dimension, rows in rebuilt_dimensions.items():
        require(rows, f"semantic dimension has no raw assertions: {skill}/{dimension}")
        expected_status = "pass" if all(row[1] == "pass" for row in rows) else "fail"
        expected_reason = f"{sum(row[1] == 'pass' for row in rows)}/{len(rows)} assertions passed; {sum(row[1] == 'fail' for row in rows)} blocking failures"
        require(data["dimensions"][dimension].get("status") == expected_status and data["dimensions"][dimension].get("reason") == expected_reason, f"semantic dimension summary does not match raw evidence: {skill}/{dimension}")
    require(data["run"].get("raw_evidence_digest") == raw_evidence_digest(artifact_dir / "semantic-raw" / skill), f"semantic raw evidence digest mismatch: {skill}")
    for case in data["cases"]:
        for evidence in case["evidence"]:
            evidence_path = Path(evidence.split(": ", 1)[0])
            require(evidence_path.is_file() and artifact_dir.resolve() in evidence_path.resolve().parents, f"missing or external raw evidence for {skill}/{case['case_id']}")


def certify(artifact_dir: Path, selected: str | None) -> None:
    report = offline_report(selected)
    failures = list(report["failures"])
    names = [selected] if selected else sorted(skill_paths())
    for skill in names:
        try:
            validate_semantic_artifact(skill, artifact_dir)
        except (OSError, json.JSONDecodeError, KeyError, ContractError) as error:
            failures.append(str(error))
    for failure in failures:
        print(f"FAIL: {failure}")
    print(f"skill certification: {len(names) - len(failures)}/{len(names)} certified")
    if failures:
        raise SystemExit(1)


def compact_row(artifact_dir: Path, skill: str) -> dict[str, Any]:
    validate_semantic_artifact(skill, artifact_dir)
    quality = json.loads((artifact_dir / f"quality-{skill}.json").read_text())
    run = quality["run"]
    return {
        "skill": skill,
        "skillSha256": run["skill_sha256"],
        "contractSha256": run["contract_sha256"],
        "routingDigest": run["routing_digest"],
        "semanticDigest": run["semantic_digest"],
        "rawEvidenceDigest": run["raw_evidence_digest"],
        "model": run["model"],
        "reasoningEffort": run["reasoning_effort"],
        "codexVersion": run["codex_version"],
        "caseCount": len(quality["cases"]),
        "verdict": quality["verdict"],
    }


def compact_attestation(artifact_dir: Path) -> list[dict[str, Any]]:
    rows = []
    for skill in sorted(skill_paths()):
        rows.append(compact_row(artifact_dir, skill))
    return rows


def validate_compact_attestation(rows: Any, selected: str | None = None) -> None:
    names = [selected] if selected else sorted(skill_paths())
    require(isinstance(rows, list) and len(rows) == len(names), "compact skill attestation coverage mismatch")
    require(all(isinstance(row, dict) for row in rows), "compact skill attestation row is malformed")
    by_skill = {row.get("skill"): row for row in rows}
    require(len(by_skill) == len(rows) and sorted(by_skill) == names, "compact skill attestation skill set mismatch")
    for skill in names:
        row = by_skill[skill]
        require(set(row) == {
            "skill", "skillSha256", "contractSha256", "routingDigest", "semanticDigest", "rawEvidenceDigest",
            "model", "reasoningEffort", "codexVersion", "caseCount", "verdict",
        }, f"compact skill attestation keys mismatch: {skill}")
        contract = json.loads((CONTRACT_ROOT / f"{skill}.json").read_text())
        expected_cases = len(route_cases(skill)) + len(contract["reference_routing"]) + len(contract["scenarios"])
        require(row["skillSha256"] == sha256_file(skill_paths()[skill]), f"compact skill attestation skill digest mismatch: {skill}")
        require(row["contractSha256"] == sha256_file(CONTRACT_ROOT / f"{skill}.json"), f"compact skill attestation contract digest mismatch: {skill}")
        require(row["routingDigest"] == routing_digest(skill), f"compact skill attestation routing digest mismatch: {skill}")
        require(row["semanticDigest"] == semantic_digest(skill), f"compact skill attestation semantic digest mismatch: {skill}")
        require(isinstance(row["rawEvidenceDigest"], str) and len(row["rawEvidenceDigest"]) == 64 and row["rawEvidenceDigest"] != "0" * 64 and all(character in "0123456789abcdef" for character in row["rawEvidenceDigest"]), f"compact skill attestation raw digest malformed: {skill}")
        require(row["model"] == EVALUATOR_MODEL and row["reasoningEffort"] == EVALUATOR_REASONING_EFFORT, f"compact skill attestation evaluator mismatch: {skill}")
        require(compatible_codex_runtime(row["codexVersion"]),
                f"compact skill attestation runtime mismatch: {skill}")
        require(row["caseCount"] == expected_cases and row["verdict"] == "pass", f"compact skill attestation verdict mismatch: {skill}")


def incremental_attestation(artifact_dir: Path, baseline_rows: Any) -> tuple[list[dict[str, Any]], list[str], list[str]]:
    require(isinstance(baseline_rows, list), "incremental baseline attestation is malformed")
    baseline = {row.get("skill"): row for row in baseline_rows if isinstance(row, dict)}
    require(len(baseline) == len(baseline_rows), "incremental baseline attestation has duplicate or malformed rows")
    rows: list[dict[str, Any]] = []
    fresh: list[str] = []
    reused: list[str] = []
    for skill in sorted(skill_paths()):
        quality_path = artifact_dir / f"quality-{skill}.json"
        if quality_path.is_file():
            row = compact_row(artifact_dir, skill)
            fresh.append(skill)
        else:
            require(skill in baseline, f"missing fresh or baseline attestation: {skill}")
            row = baseline[skill]
            reused.append(skill)
        validate_compact_attestation([row], skill)
        rows.append(row)
    return rows, fresh, reused


def incremental_plan(baseline_rows: Any) -> list[str]:
    require(isinstance(baseline_rows, list), "incremental baseline attestation is malformed")
    baseline = {row.get("skill"): row for row in baseline_rows if isinstance(row, dict)}
    stale = []
    for skill in sorted(skill_paths()):
        try:
            validate_compact_attestation([baseline[skill]], skill)
        except (KeyError, ContractError):
            stale.append(skill)
    return stale


def certify_incremental(artifact_dir: Path, baseline_rows: Any) -> tuple[list[dict[str, Any]], list[str], list[str]]:
    report = offline_report()
    require(not report["failures"], "offline quality gate must pass before incremental certification")
    rows, fresh, reused = incremental_attestation(artifact_dir, baseline_rows)
    print(f"skill certification: {len(rows)}/{len(rows)} certified; fresh={len(fresh)} reused={len(reused)}")
    return rows, fresh, reused


def validate_full_live_paths(artifact_dir: Path, routing_artifact: Path) -> tuple[Path, Path, Path]:
    require(artifact_dir.is_dir() and not artifact_dir.is_symlink(), f"semantic artifact directory is missing or symlinked: {artifact_dir}")
    artifact_root = artifact_dir.resolve()
    require(routing_artifact.is_file() and not routing_artifact.is_symlink(), f"routing artifact is missing or symlinked: {routing_artifact}")
    routing_path = routing_artifact.resolve()
    require(routing_path.parent == artifact_root, f"routing artifact must be a direct child of the semantic artifact directory: {routing_artifact}")
    manifest_path = artifact_root / "semantic-run-manifest.json"
    require(not manifest_path.is_symlink(), f"semantic run manifest is symlinked: {manifest_path}")
    return artifact_root, routing_path, manifest_path


def write_json_atomic(path: Path, payload: Any) -> None:
    require(path.parent.is_dir() and not path.parent.is_symlink(), f"atomic JSON parent is missing or symlinked: {path.parent}")
    require(not path.is_symlink(), f"atomic JSON target is symlinked: {path}")
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile("w", dir=path.parent, prefix=f".{path.name}.", suffix=".tmp", delete=False) as handle:
            temporary_path = Path(handle.name)
            json.dump(payload, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_path, path)
        temporary_path = None
        directory_fd = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        if temporary_path is not None and temporary_path.exists() and not temporary_path.is_symlink():
            temporary_path.unlink()


def prepare_semantic_run(
    artifact_dir: Path,
    routing_artifact: Path,
    snapshot: dict[str, Any],
    names: list[str],
    resume: bool,
    refresh: bool,
) -> tuple[Path, Path, Path, list[str]]:
    require(not (resume and refresh), "--resume and --refresh are mutually exclusive")
    artifact_root, routing_path, manifest_path = validate_full_live_paths(artifact_dir, routing_artifact)
    if refresh:
        require(manifest_path.is_file(), f"semantic run manifest is missing for --refresh: {manifest_path}")
        json.loads(manifest_path.read_text())
        write_json_atomic(manifest_path, snapshot)
    elif manifest_path.exists():
        require(resume, f"semantic run manifest already exists without --resume: {manifest_path}")
        require(json.loads(manifest_path.read_text()) == snapshot, "semantic run manifest does not match the current immutable source snapshot")
    else:
        require(not resume, f"semantic run manifest is missing for --resume: {manifest_path}")
        write_json_atomic(manifest_path, snapshot)
    pending: list[str] = []
    for skill in names:
        target = artifact_root / f"quality-{skill}.json"
        if refresh:
            pending.append(skill)
            continue
        if not target.exists():
            pending.append(skill)
            continue
        require(resume, f"semantic artifact already exists without --resume: {target}")
        validate_semantic_artifact(skill, artifact_root)
        print(f"semantic quality {skill}: resume accepted digest-valid artifact")
    return artifact_root, routing_path, manifest_path, pending


def finalize_semantic_run(
    artifact_dir: Path,
    routing_artifact: Path,
    manifest_path: Path,
    snapshot: dict[str, Any],
    names: list[str],
    failures: list[str],
    semantic_digest_reader: Any = semantic_digest,
    certify_runner: Any = None,
) -> None:
    artifact_root, routing_path, expected_manifest = validate_full_live_paths(artifact_dir, routing_artifact)
    require(manifest_path.resolve() == expected_manifest and not manifest_path.is_symlink(), "semantic run manifest path changed during evaluation")
    require(json.loads(manifest_path.read_text()) == snapshot, "semantic run manifest changed during evaluation")
    require(sha256_file(routing_path) == snapshot["routing_artifact_sha256"], "routing artifact changed during semantic evaluation")
    require(
        all(semantic_digest_reader(skill) == snapshot["semantic_digests"][skill] for skill in names),
        "semantic source changed during full live evaluation",
    )
    for failure in failures:
        print(f"FAIL: {failure}")
    if failures:
        raise SystemExit(1)
    (certify_runner or certify)(artifact_root, None)


def full_live(artifact_dir: Path, routing_artifact: Path, jobs: int, resume: bool, refresh: bool) -> None:
    require(1 <= jobs <= 8, "semantic jobs must remain between 1 and 8")
    report = offline_report()
    require(not report["failures"], "offline quality gate must pass before full live evaluation")
    names = sorted(skill_paths())
    artifact_root, routing_path, _ = validate_full_live_paths(artifact_dir, routing_artifact)
    for skill in names:
        load_routing_artifact(routing_path, skill)
    snapshot = {
        "schema_version": 1,
        "model": EVALUATOR_MODEL,
        "reasoning_effort": EVALUATOR_REASONING_EFFORT,
        "codex_version": codex_version(),
        "routing_artifact_sha256": sha256_file(routing_path),
        "semantic_digests": {skill: semantic_digest(skill) for skill in names},
    }
    artifact_root, routing_path, manifest_path, pending = prepare_semantic_run(
        artifact_root, routing_path, snapshot, names, resume, refresh
    )

    def run_skill(skill: str) -> tuple[str, int, str]:
        command = [
            sys.executable, str(Path(__file__).resolve()), "semantic-live", "--skill", skill,
            "--artifact-dir", str(artifact_root), "--routing-artifact", str(routing_path),
            "--expected-semantic-digest", snapshot["semantic_digests"][skill],
        ]
        completed = managed_run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return skill, completed.returncode, (completed.stdout + completed.stderr).strip()

    failures: list[str] = []
    with ThreadPoolExecutor(max_workers=jobs) as executor:
        futures = [executor.submit(run_skill, skill) for skill in pending]
        for future in futures:
            skill, returncode, output = future.result()
            if output:
                print(output)
            if returncode:
                failures.append(f"semantic evaluator failed for {skill} with exit {returncode}")
    finalize_semantic_run(artifact_root, routing_path, manifest_path, snapshot, names, failures)


def self_test() -> None:
    require(sha256_bytes(b"x") == hashlib.sha256(b"x").hexdigest(), "sha helper")
    require(compatible_codex_runtime("codex-cli 0.156.0", "codex-cli 0.156.1"),
            "stable patch update should reuse unchanged per-skill evidence")
    require(not compatible_codex_runtime("codex-cli 0.155.9", "codex-cli 0.156.0"),
            "minor runtime update must invalidate per-skill evidence")
    require(not compatible_codex_runtime("codex-cli 0.156.0-dev", "codex-cli 0.156.1"),
            "non-stable runtime evidence must fail closed")
    require(30 <= MODEL_CALL_TIMEOUT_SECONDS <= 600, "model evaluator timeout must remain bounded")
    require(1 <= MODEL_TERMINATION_GRACE_SECONDS <= 10, "model evaluator termination grace must remain bounded")
    require(EVALUATOR_MODEL and EVALUATOR_REASONING_EFFORT, "evaluator identity must be pinned")
    require(16 <= ROUTING_BATCH_SIZE <= 64, "routing batches must amortize repeated catalog context without becoming unbounded")
    routing_groups: dict[tuple[str, tuple[str, ...]], int] = defaultdict(int)
    for routing_case in route_cases():
        routing_groups[(routing_case["topology"], tuple(routing_case["catalog"]))] += 1
    routing_calls = sum((count + ROUTING_BATCH_SIZE - 1) // ROUTING_BATCH_SIZE for count in routing_groups.values()) * 3
    require(routing_calls <= 150, f"full routing corpus call budget exceeded: {routing_calls}")
    signal_child = subprocess.Popen(
        [sys.executable, str(Path(__file__).resolve()), "signal-self-test-child"],
        stdout=subprocess.PIPE,
        text=True,
        start_new_session=True,
    )
    require(signal_child.stdout is not None, "signal self-test stdout must be available")
    worker_pid = int(signal_child.stdout.readline().strip())
    signal_child.terminate()
    signal_child.wait(timeout=3)
    require(signal_child.returncode != 0, "evaluator signal termination must be observable")
    worker_alive = True
    for _ in range(20):
        try:
            os.kill(worker_pid, 0)
        except ProcessLookupError:
            worker_alive = False
            break
        time.sleep(0.05)
    require(not worker_alive, "evaluator signal handler left a model-call process alive")
    timeout_started = time.monotonic()
    timeout_observed = False
    try:
        managed_run(
            [
                sys.executable,
                "-c",
                "import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(60)",
            ],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=0.2,
        )
    except subprocess.TimeoutExpired:
        timeout_observed = True
    require(timeout_observed, "managed model-call timeout must remain observable")
    require(
        time.monotonic() - timeout_started < MODEL_TERMINATION_GRACE_SECONDS + 2,
        "managed model-call timeout did not kill a TERM-resistant process within the bounded grace",
    )
    require(
        blocking_assertion_results([{"id": "major-counterexample", "severity": "major", "status": "fail"}]),
        "major assertion failure must block",
    )
    require(
        routing_raw_stem("skill-a", 1, "owner", 1, 1) != routing_raw_stem("skill-b", 1, "owner", 1, 1),
        "parallel per-skill routing artifacts must have scope-isolated filenames",
    )
    try:
        require(False, "counterexample")
    except ContractError:
        pass
    else:
        raise AssertionError("require accepted false")
    valid_judge = {
        "case_id": "case-a",
        "assertions": [{"id": "assertion-a", "status": "pass", "evidence": "grounded"}],
        "verdict": "pass",
    }
    validate_judge_payload(valid_judge, "case-a", {"assertion-a"}, "self-test")
    for invalid_judge in (
        "not model output",
        {**valid_judge, "case_id": "wrong-case"},
        {**valid_judge, "assertions": valid_judge["assertions"] * 2},
        {**valid_judge, "assertions": [{**valid_judge["assertions"][0], "status": "fail"}]},
    ):
        try:
            validate_judge_payload(invalid_judge, "case-a", {"assertion-a"}, "self-test-counterexample")
        except ContractError:
            continue
        raise AssertionError("semantic raw judge validator accepted forged evidence")
    with tempfile.TemporaryDirectory(prefix="semantic-receipt-self-test-") as directory:
        artifact_root = Path(directory)
        output = artifact_root / "semantic-raw" / "sample" / "judge.json"
        output.parent.mkdir(parents=True)
        output.write_text(json.dumps(valid_judge))
        write_invocation_receipt("prompt-a", JUDGE_SCHEMA, output)
        validate_invocation_receipt(output, "prompt-a", JUDGE_SCHEMA, artifact_root)
        output.write_text(json.dumps({**valid_judge, "verdict": "fail"}))
        try:
            validate_invocation_receipt(output, "prompt-a", JUDGE_SCHEMA, artifact_root)
        except ContractError:
            pass
        else:
            raise AssertionError("semantic receipt accepted mutated raw output")
    with tempfile.TemporaryDirectory(prefix="semantic-cache-self-test-") as directory:
        artifact_root = Path(directory)
        raw_dir = artifact_root / "semantic-raw" / "sample"
        output = raw_dir / "answer.md"
        stderr = raw_dir / "answer.stderr"
        raw_dir.mkdir(parents=True)
        calls: list[str] = []

        def fake_runner(prompt: str, schema: Path | None, target: Path, error_path: Path) -> None:
            calls.append(prompt)
            target.write_text(json.dumps({"prompt": prompt}) if schema else prompt)
            error_path.write_text("")
            write_invocation_receipt(prompt, schema, target)

        require(run_codex_cached("prompt-a", None, output, stderr, artifact_root, raw_dir, fake_runner) == "refreshed", "missing semantic evidence must refresh")
        require(run_codex_cached("prompt-a", None, output, stderr, artifact_root, raw_dir, fake_runner) == "reused", "digest-valid semantic evidence must be reused")
        require(run_codex_cached("prompt-b", None, output, stderr, artifact_root, raw_dir, fake_runner) == "refreshed", "prompt drift must refresh semantic evidence")
        schema = artifact_root / "judge.schema.json"
        schema.write_text("{}")
        require(run_codex_cached("prompt-b", schema, output, stderr, artifact_root, raw_dir, fake_runner) == "refreshed", "schema drift must refresh semantic evidence")
        require(run_codex_cached("prompt-b", schema, output, stderr, artifact_root, raw_dir, fake_runner) == "reused", "unchanged schema-bound evidence must be reused")

        output.write_bytes(b"\xff")
        write_invocation_receipt("prompt-b", schema, output)
        require(run_codex_cached("prompt-b", schema, output, stderr, artifact_root, raw_dir, fake_runner) == "refreshed", "non-UTF8 cached evidence must refresh")
        receipt_path(output).unlink()
        require(run_codex_cached("prompt-b", schema, output, stderr, artifact_root, raw_dir, fake_runner) == "refreshed", "missing receipt must refresh")
        receipt_path(output).write_text("{")
        require(run_codex_cached("prompt-b", schema, output, stderr, artifact_root, raw_dir, fake_runner) == "refreshed", "malformed receipt must refresh")
        for identity_field in ("model", "reasoning_effort", "codex_version"):
            receipt = json.loads(receipt_path(output).read_text())
            receipt[identity_field] = "mismatch"
            receipt_path(output).write_text(json.dumps(receipt))
            require(run_codex_cached("prompt-b", schema, output, stderr, artifact_root, raw_dir, fake_runner) == "refreshed", f"{identity_field} drift must refresh")

        extra_receipt = raw_dir / "extra.md.receipt.json"
        extra_receipt.write_text("{}")
        prune_stale_semantic_receipts(raw_dir, artifact_root, {receipt_path(output).resolve()})
        require(receipt_path(output).is_file() and not extra_receipt.exists(), "stale receipt pruning must stay inside the exact skill subtree")

        other_raw = artifact_root / "semantic-raw" / "other"
        other_raw.mkdir()
        other_output = other_raw / "answer.md"
        other_stderr = other_raw / "answer.stderr"
        try:
            run_codex_cached("escape", None, other_output, other_stderr, artifact_root, raw_dir, fake_runner)
        except ContractError:
            pass
        else:
            raise AssertionError("semantic cache accepted a cross-skill output path")

        alias_raw = artifact_root / "semantic-raw" / "alias"
        alias_raw.symlink_to(raw_dir, target_is_directory=True)
        try:
            run_codex_cached("alias", None, alias_raw / "alias.md", alias_raw / "alias.stderr", artifact_root, alias_raw, fake_runner)
        except ContractError:
            pass
        else:
            raise AssertionError("semantic cache accepted a symlinked skill raw directory")
        require(receipt_path(output).is_file(), "cross-skill alias handling modified valid evidence")

        dependent_calls_before = len(calls)
        dependent_outputs = [raw_dir / f"dependent-{index}.md" for index in range(3)]
        for index, dependent_output in enumerate(dependent_outputs):
            run_codex_cached(f"dependent-{index}", None, dependent_output, raw_dir / f"dependent-{index}.stderr", artifact_root, raw_dir, fake_runner)
        for index, dependent_output in enumerate(dependent_outputs):
            prompt = "dependent-changed" if index == 1 else f"dependent-{index}"
            run_codex_cached(prompt, None, dependent_output, raw_dir / f"dependent-{index}.stderr", artifact_root, raw_dir, fake_runner)
        require(len(calls) == dependent_calls_before + 4, "selective semantic refresh did not reuse unchanged dependent calls")
        failure_output = raw_dir / "failure.judge.json"
        failure_payload = {
            "case_id": "failure-case",
            "assertions": [{"id": "failure", "status": "fail", "evidence": "counterexample"}],
            "verdict": "fail",
        }
        failure_output.write_text(json.dumps(failure_payload))
        write_invocation_receipt("failure-prompt", JUDGE_SCHEMA, failure_output)
        calls_before_failure_reuse = len(calls)
        require(
            run_codex_cached("failure-prompt", JUDGE_SCHEMA, failure_output, raw_dir / "failure.stderr", artifact_root, raw_dir, fake_runner) == "reused"
            and len(calls) == calls_before_failure_reuse,
            "receipt-valid semantic failure was rerun instead of preserved",
        )
        require(calls[:2] == ["prompt-a", "prompt-b"], "semantic evidence cache reran an unchanged prompt or reused a stale prompt")
    semantic_digest_source = inspect.getsource(semantic_evaluator_digest)
    require(
        all(name in semantic_digest_source for name in (
            "artifact_relative", "receipt_path", "write_invocation_receipt", "validate_invocation_receipt",
            "validate_semantic_raw_dir", "run_codex_cached", "prune_stale_semantic_receipts", "codex_version",
        )),
        "semantic evaluator digest omits an evidence acceptance or identity helper",
    )
    with tempfile.TemporaryDirectory(prefix="semantic-refresh-self-test-") as directory:
        artifact_root = Path(directory)
        routing_path = artifact_root / "routing-all.json"
        routing_path.write_text('{"routing":"stable"}\n')
        manifest_path = artifact_root / "semantic-run-manifest.json"
        write_json_atomic(manifest_path, {"old": True})
        names = ["skill-a", "skill-b"]
        snapshot = {
            "schema_version": 1,
            "model": EVALUATOR_MODEL,
            "reasoning_effort": EVALUATOR_REASONING_EFFORT,
            "codex_version": codex_version(),
            "routing_artifact_sha256": sha256_file(routing_path),
            "semantic_digests": {name: f"digest-{name}" for name in names},
        }
        for name in names:
            (artifact_root / f"quality-{name}.json").write_text('{"stale":true}\n')
        _, _, prepared_manifest, pending = prepare_semantic_run(
            artifact_root, routing_path, snapshot, names, resume=False, refresh=True
        )
        require(pending == names and json.loads(prepared_manifest.read_text()) == snapshot, "refresh did not schedule every skill under the new snapshot")
        require(prepared_manifest.is_file() and not prepared_manifest.is_symlink(), "refresh manifest is not a regular local file")
        try:
            prepare_semantic_run(artifact_root, routing_path, snapshot, names, resume=True, refresh=True)
        except ContractError:
            pass
        else:
            raise AssertionError("semantic refresh accepted simultaneous --resume")

        missing_root = artifact_root / "missing"
        missing_root.mkdir()
        missing_routing = missing_root / "routing-all.json"
        missing_routing.write_text("{}")
        try:
            prepare_semantic_run(missing_root, missing_routing, snapshot, names, resume=False, refresh=True)
        except ContractError:
            pass
        else:
            raise AssertionError("semantic refresh accepted a missing manifest")

        malformed_root = artifact_root / "malformed"
        malformed_root.mkdir()
        malformed_routing = malformed_root / "routing-all.json"
        malformed_routing.write_text("{}")
        (malformed_root / "semantic-run-manifest.json").write_text("{")
        try:
            prepare_semantic_run(malformed_root, malformed_routing, snapshot, names, resume=False, refresh=True)
        except json.JSONDecodeError:
            pass
        else:
            raise AssertionError("semantic refresh accepted a malformed manifest")

        symlink_root = artifact_root / "symlink"
        symlink_root.mkdir()
        symlink_routing = symlink_root / "routing-all.json"
        symlink_routing.write_text("{}")
        external_manifest = artifact_root / "external-manifest.json"
        external_manifest.write_text('{"external":true}\n')
        symlink_manifest = symlink_root / "semantic-run-manifest.json"
        symlink_manifest.symlink_to(external_manifest)
        try:
            prepare_semantic_run(symlink_root, symlink_routing, snapshot, names, resume=False, refresh=True)
        except ContractError:
            pass
        else:
            raise AssertionError("semantic refresh accepted a symlinked manifest")
        require(json.loads(external_manifest.read_text()) == {"external": True}, "semantic refresh modified an external manifest target")

        certificate_calls: list[Path] = []
        digest_reader = lambda name: snapshot["semantic_digests"][name]
        try:
            finalize_semantic_run(
                artifact_root, routing_path, prepared_manifest, snapshot, names, ["child failed"],
                semantic_digest_reader=digest_reader,
                certify_runner=lambda root, selected: certificate_calls.append(root),
            )
        except SystemExit:
            pass
        else:
            raise AssertionError("semantic refresh certified after a child failure")
        require(not certificate_calls, "semantic refresh invoked certification after a child failure")

        routing_path.write_text('{"routing":"drifted"}\n')
        try:
            finalize_semantic_run(
                artifact_root, routing_path, prepared_manifest, snapshot, names, [],
                semantic_digest_reader=digest_reader,
                certify_runner=lambda root, selected: certificate_calls.append(root),
            )
        except ContractError:
            pass
        else:
            raise AssertionError("semantic refresh accepted routing drift")
        routing_path.write_text('{"routing":"stable"}\n')
        write_json_atomic(prepared_manifest, {"changed": True})
        try:
            finalize_semantic_run(
                artifact_root, routing_path, prepared_manifest, snapshot, names, [],
                semantic_digest_reader=digest_reader,
                certify_runner=lambda root, selected: certificate_calls.append(root),
            )
        except ContractError:
            pass
        else:
            raise AssertionError("semantic refresh accepted manifest drift")
        write_json_atomic(prepared_manifest, snapshot)
        finalize_semantic_run(
            artifact_root, routing_path, prepared_manifest, snapshot, names, [],
            semantic_digest_reader=digest_reader,
            certify_runner=lambda root, selected: certificate_calls.append(root),
        )
        require(certificate_calls == [artifact_root.resolve()], "semantic refresh did not certify exactly once after all final checks")
    require(GENERIC_DESCRIPTION.search("Use when the task explicitly requires widgets; do not load it for adjacent work.") is not None, "generic description detector")
    require(routing_digest() == routing_digest(), "full routing digest must be deterministic")
    require(
        routing_evaluator_digest("0" * 64) != routing_evaluator_digest("1" * 64),
        "routing evidence must change with evaluator implementation",
    )
    require(
        semantic_evaluator_digest("0" * 64) != semantic_evaluator_digest("1" * 64),
        "semantic evidence must change with evaluator implementation",
    )
    sample = next(iter(skill_paths()))
    require(routing_digest(sample) == routing_digest(sample), "scoped routing digest must be deterministic")
    require(semantic_digest(sample) == semantic_digest(sample), "semantic digest must be deterministic")
    with tempfile.TemporaryDirectory(prefix="semantic-snapshot-self-test-") as directory:
        try:
            semantic_live(sample, Path(directory), Path(directory) / "missing-routing.json", "0" * 64)
        except ContractError as error:
            require("source changed" in str(error), "semantic snapshot mismatch must fail before model execution")
        else:
            raise AssertionError("semantic evaluator accepted a mismatched immutable snapshot")
    reference_prompt = reference_solver_prompt("sample", "[guide](references/guide.md)", "use the guide")
    require("skills/sample/references/example.md" in reference_prompt and "repository-relative" in reference_prompt, "reference prompt must require canonical repository-relative paths")
    reference_criterion = {
        "case_id": "reference-counterexample",
        "assertions": [{"id": "reference-selection", "criterion": "Expected=['skills/sample/references/guide.md']; forbidden=[]"}],
    }
    reference_counterexample = reference_judge_prompt(
        reference_criterion,
        "skills/sample/references/guide.md\nskills/sample/references/invented.md",
    )
    require(
        all(fragment in reference_counterexample for fragment in (
            "only for the contract-listed expected and forbidden", "outside the expected set", "unrelated or invented path",
            "skills/sample/references/guide.md", "skills/sample/references/invented.md",
        )),
        "reference judge must reject expected-plus-extra-path counterexamples without inferring workspace state",
    )
    judge_prompt = scenario_judge_prompt("TASK_SENTINEL", "SKILL_SENTINEL", "\n\nOptional task fixture:\nFIXTURE_SENTINEL", "CRITERIA_SENTINEL", "ANSWER_SENTINEL")
    require(all(value in judge_prompt for value in ("TASK_SENTINEL", "SKILL_SENTINEL", "FIXTURE_SENTINEL", "CRITERIA_SENTINEL", "ANSWER_SENTINEL")), "semantic judge must receive task, skill, fixture, criteria, and answer")
    batch_cases = [{"case_id": "CASE_SENTINEL", "task": "TASK_SENTINEL", "fixture": "FIXTURE_SENTINEL", "assertions": [{"id": "ASSERTION_SENTINEL"}], "answer": "ANSWER_SENTINEL"}]
    batch_solver_prompt = scenario_solver_batch_prompt("SKILL_SENTINEL", batch_cases)
    batch_revision_prompt = scenario_revision_batch_prompt("SKILL_SENTINEL", batch_cases, {"CASE_SENTINEL": "DRAFT_SENTINEL"})
    batch_judge_prompt = scenario_judge_batch_prompt("SKILL_SENTINEL", batch_cases)
    require(all(value in batch_solver_prompt for value in ("CASE_SENTINEL", "TASK_SENTINEL", "FIXTURE_SENTINEL", "SKILL_SENTINEL")), "batched solver must receive every case boundary")
    require("does not erase inspection or other evidence" in batch_solver_prompt and "does not erase inspection or other evidence" in batch_revision_prompt, "solver and revision must preserve fixture-established inspection evidence")
    require(all(value in batch_revision_prompt for value in ("CASE_SENTINEL", "TASK_SENTINEL", "FIXTURE_SENTINEL", "SKILL_SENTINEL", "DRAFT_SENTINEL")), "bounded revision must receive every draft case boundary")
    require("exactly one bounded self-falsification" in batch_revision_prompt and "hidden evaluation criteria" in batch_revision_prompt, "bounded revision must be single-cycle and assertion-blind")
    require(all(value in batch_judge_prompt for value in ("CASE_SENTINEL", "TASK_SENTINEL", "FIXTURE_SENTINEL", "SKILL_SENTINEL", "ASSERTION_SENTINEL", "ANSWER_SENTINEL")), "batched judge must receive every isolated case, assertion, and candidate answer")
    require("never demand fabricated execution" in batch_judge_prompt, "batched judge must respect the hypothetical execution boundary")
    require("never fail solely because no source change" in batch_judge_prompt and "inspection occurred establishes that inspection" in batch_judge_prompt, "batched judge must honor unavailable execution and fixture-established inspection")
    require("stated antecedent is absent" in batch_judge_prompt, "batched judge must respect conditional assertion antecedents")
    require(set(case["kind"] for case in route_cases(sample)) == {"positive", "negative"}, "routing case expansion")
    topology_cases = route_cases("framework-management")
    require({case["topology"] for case in topology_cases} == {"owner", "full"}, "routing must cover owner-pack and full-catalog topologies")
    require(
        all(case["expected_skill"] == "none" for case in topology_cases if case["topology"] == "owner" and case["kind"] == "negative"),
        "out-of-pack negative routes must fail closed when their neighbor is unavailable",
    )
    require(
        all(case["expected_skill"] != "none" for case in topology_cases if case["topology"] == "full" and case["kind"] == "negative"),
        "full-catalog negative routes must select their declared neighbor",
    )
    plugin_cases = route_cases("accessibility-audit")
    require(
        {case["topology"] for case in plugin_cases} == {"owner", "full", "plugin"},
        "plugin-bundled skills must cover owner-pack, full-catalog, and qualified plugin topologies",
    )
    require(
        all(
            case["expected_skill"] == "codex-frontend-design:accessibility-audit"
            for case in plugin_cases
            if case["topology"] == "plugin" and case["kind"] == "positive"
        ),
        "plugin topology must route positive cases to the qualified plugin skill identity",
    )
    with tempfile.TemporaryDirectory(prefix="routing-artifact-self-test-") as directory:
        routing_path = Path(directory) / "routing-framework-management.json"
        artifact_cases = []
        for case in topology_cases:
            expected = case["expected_skill"]
            artifact_cases.append({
                **{key: case[key] for key in ("skill", "case_id", "contract_case_id", "kind", "topology", "expected_skill")},
                "actual_skill": expected, "trials": [expected, expected, expected], "status": "pass",
            })
        routing_payload = {
            "schema_version": 1,
            "run": {
                "routing_digest": routing_digest("framework-management"), "model": EVALUATOR_MODEL,
                "reasoning_effort": EVALUATOR_REASONING_EFFORT, "trials": 3,
            },
            "selected_skill": "framework-management", "cases": artifact_cases, "verdict": "pass",
        }
        routing_path.write_text(json.dumps(routing_payload))
        load_routing_artifact(routing_path, "framework-management")
        routing_payload["cases"][0]["status"] = "fail"
        routing_path.write_text(json.dumps(routing_payload))
        try:
            load_routing_artifact(routing_path, "framework-management")
        except ContractError:
            pass
        else:
            raise AssertionError("routing artifact validator accepted forged majority status")
    skills = skill_paths(); catalogs = manifests(); registered = registrations(catalogs); techs = technologies()
    original = json.loads((CONTRACT_ROOT / f"{sample}.json").read_text())
    counterexamples = []
    invalid = json.loads(json.dumps(original)); invalid["risk"]["mode"] = "unbounded"; counterexamples.append(invalid)
    invalid = json.loads(json.dumps(original)); invalid["routing"]["positive"] = invalid["routing"]["positive"][:1]; counterexamples.append(invalid)
    invalid = json.loads(json.dumps(original)); invalid["scenarios"] = [row for row in invalid["scenarios"] if row["kind"] != "safety"]; counterexamples.append(invalid)
    invalid = json.loads(json.dumps(original)); invalid["provenance"][0]["checked_on"] = "2999-01-01"; counterexamples.append(invalid)
    invalid = json.loads(json.dumps(original)); invalid["scenarios"][0]["fixture"] = "README.md"; counterexamples.append(invalid)
    with tempfile.TemporaryDirectory(prefix="skill-quality-self-test-") as directory:
        path = Path(directory) / f"{sample}.json"
        for invalid in counterexamples:
            path.write_text(json.dumps(invalid))
            try:
                validate_contract(invalid, path, skills, catalogs, registered, techs)
            except ContractError:
                continue
            raise AssertionError("quality validator accepted a malformed contract")
    print("skill quality self-test: passed")


def signal_self_test_child() -> None:
    worker = subprocess.Popen(["sh", "-c", "sleep 30"], start_new_session=True)
    with ACTIVE_PROCESSES_LOCK:
        ACTIVE_PROCESSES.add(worker)
    print(worker.pid, flush=True)
    signal.pause()


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    check = sub.add_parser("check"); check.add_argument("--skill"); check.add_argument("--json", action="store_true"); check.add_argument("--allow-incomplete", action="store_true")
    routing = sub.add_parser("routing-live"); routing.add_argument("--skill"); routing.add_argument("--artifact-dir", type=Path, required=True); routing.add_argument("--trials", type=int, default=3); routing.add_argument("--jobs", type=int, default=4)
    semantic = sub.add_parser("semantic-live"); semantic.add_argument("--skill", required=True); semantic.add_argument("--artifact-dir", type=Path, required=True); semantic.add_argument("--routing-artifact", type=Path, required=True); semantic.add_argument("--expected-semantic-digest")
    full = sub.add_parser("full-live"); full.add_argument("--artifact-dir", type=Path, required=True); full.add_argument("--routing-artifact", type=Path, required=True); full.add_argument("--jobs", type=int, default=4); full.add_argument("--resume", action="store_true"); full.add_argument("--refresh", action="store_true")
    certification = sub.add_parser("certify"); certification.add_argument("--skill"); certification.add_argument("--artifact-dir", type=Path, required=True)
    incremental = sub.add_parser("certify-incremental"); incremental.add_argument("--artifact-dir", type=Path, required=True); incremental.add_argument("--baseline-evidence", type=Path, required=True)
    plan = sub.add_parser("incremental-plan"); plan.add_argument("--baseline-evidence", type=Path, required=True)
    sub.add_parser("self-test")
    sub.add_parser("signal-self-test-child", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.command == "self-test":
        self_test(); return
    if args.command == "signal-self-test-child":
        signal_self_test_child(); return
    if args.command == "routing-live":
        routing_live(args.skill, args.artifact_dir, args.trials, args.jobs); return
    if args.command == "semantic-live":
        semantic_live(args.skill, args.artifact_dir, args.routing_artifact, args.expected_semantic_digest); return
    if args.command == "full-live":
        full_live(args.artifact_dir, args.routing_artifact, args.jobs, args.resume, args.refresh); return
    if args.command == "certify":
        certify(args.artifact_dir, args.skill); return
    if args.command in {"certify-incremental", "incremental-plan"}:
        baseline = json.loads(args.baseline_evidence.read_text()).get("skillCorpusAttestation")
        if args.command == "incremental-plan":
            print("\n".join(incremental_plan(baseline)))
        else:
            certify_incremental(args.artifact_dir, baseline)
        return
    report = offline_report(args.skill)
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print(f"skill quality: {report['contracts']}/{report['skills']} contracts structurally validated; {report['scaffolds']} scaffolds are not certifiable")
        for failure in report["failures"]: print(f"FAIL: {failure}")
        print(f"skill quality: {len(report['failures'])} failures")
    if report["failures"] and not args.allow_incomplete:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
