#!/usr/bin/env python3
"""Opt-in native execution in disposable projects; never product acceptance evidence."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import shlex
import signal
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
CASES = ("python-discovery", "node-runtime", "incremental-contract")


def write_fixture(path: Path, case: str) -> tuple[str, list[str]]:
    # Proposed guidance is installed only in the disposable project. Real user
    # configuration, model/effort and global instruction files are untouched.
    (path / "AGENTS.md").write_text((ROOT / "templates/global/AGENTS.md").read_text())
    if case != "node-runtime":
        (path / "README.md").write_text(
            "# Invoices\nA Python standard-library project. Public function: "
            "invoice.total(lines), each line is (unit price string, integer quantity). "
            "Return an exact two-decimal string using Decimal, ROUND_HALF_UP on the final sum. "
            "Local verification: python3 -m unittest discover -s tests. "
            "No package install, network service or deployment is required.\n")
        (path / "invoice.py").write_text(
            "def total(lines):\n    return str(sum(float(price) * quantity for price, quantity in lines))\n")
        (path / "tests").mkdir()
        (path / "tests/test_invoice.py").write_text(
            "import unittest\nfrom invoice import total\nclass InvoiceTest(unittest.TestCase):\n"
            "    def test_exact(self): self.assertEqual(total([('0.10',3)]), '0.30')\n")
        prompt = "Fix invoice totals to satisfy this repository's documented contract and verify the change."
        grader = [sys.executable, "-c",
                  "from invoice import total; "
                  "assert total([('0.10',3)]) == '0.30'; "
                  "assert total([('1.005',1)]) == '1.01'; "
                  "assert total([('0.005',2)]) == '0.01'; "
                  "assert total([]) == '0.00'; print('behavior-ok')"]
    else:
        (path / "README.md").write_text(
            "# Job CLI\nNode CommonJS; no dependencies or package installation. "
            "The deployed entry point is bin/job.cjs. It must print exactly ready on success. "
            "Validation: npm test AND node bin/job.cjs. The unit check alone does not launch the deployed entry.\n")
        (path / "package.json").write_text(json.dumps({"private": True, "type": "commonjs",
                                                       "scripts": {"test": "node test.cjs"}}))
        (path / "test.cjs").write_text("require('node:assert').equal(1 + 1, 2);\n")
        (path / "bin").mkdir()
        (path / "bin/job.cjs").write_text("const value = await Promise.resolve('ready');\nconsole.log(value);\n")
        prompt = "Fix the job CLI startup failure while preserving the documented output and verify the change."
        grader = ["node", "bin/job.cjs"]
    if case == "incremental-contract":
        (path / "README.md").write_text((path / "README.md").read_text() + "Only nonnegative unit prices are supported. The authoritative unit-price input contract is invoice.inputs.schema.json.\n")
        (path / "invoice.inputs.schema.json").write_text(json.dumps({"type": "object", "properties": {"unitPrice": {"type": "string", "pattern": r"^\d+(?:\.\d+)?$"}}, "required": ["unitPrice"]}))
        (path / "invoice.py").write_text(
            "from decimal import Decimal, ROUND_HALF_UP\n"
            "def total(lines):\n"
            "    if any(Decimal(p) < 0 for p,q in lines): raise ValueError('negative price')\n"
            "    return format(sum((Decimal(p)*q for p,q in lines), Decimal(0)).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP), '.2f')\n")
        prompt = "Extend invoice totals to support negative unit-price lines for refunds, preserving existing behavior. Verify the change."
        grader = [sys.executable, "-c", "from invoice import total; "
                  "assert total([('-1.005',1)]) == '-1.01'; "
                  "assert total([('2.00',1),('-0.10',3)]) == '1.70'; "
                  "assert total([('0.10',3)]) == '0.30'; print('behavior-ok')"]
    prompt += (" This is an isolated local evaluation fixture. Work only inside this directory; "
               "do not use external accounts, network, other projects, subagents, commits or installs. "
               "Use available repository evidence to decide the work. Report the actual checks and remaining gaps.")
    return prompt, grader


def commands_from_events(raw: str) -> list[str]:
    commands = []
    for line in raw.splitlines():
        if not line.strip():
            continue
        event = json.loads(line)
        if not isinstance(event, dict):
            raise ValueError("native event is not an object")
        item = event.get("item", {})
        if event.get("type") == "item.completed" and isinstance(item, dict) \
                and item.get("type") == "command_execution":
            if isinstance(item.get("command"), str) and item.get("exit_code") == 0:
                commands.append(item["command"])
    return commands


def check_invocations(command: str) -> set[str]:
    """Accept only unambiguous successful direct checks or cd/check && chains.

    Aggregate exit zero does not prove commands behind ||, ;, pipelines, shell
    control flow, exec/exit or arbitrary prefixes executed. Such traces remain
    unverified rather than being counted as passing checks.
    """
    try:
        words = shlex.split(command)
    except ValueError:
        return set()
    if len(words) == 3 and Path(words[0]).name in {"bash", "zsh", "sh"} and words[1] in {"-c", "-lc"}:
        return check_invocations(words[2])
    if "\n" in command or "\r" in command:
        return set()
    try:
        tokens = list(shlex.shlex(command, posix=True, punctuation_chars=";&|"))
    except ValueError:
        return set()
    segments, segment = [], []
    for token in tokens + ["&&"]:
        if token and all(c in ";&|" for c in token):
            if token != "&&" or not segment: return set()
            segments.append(segment)
            segment = []
        else: segment.append(token)
    found = set()
    for words in segments:
        name = Path(words[0]).name
        if name.startswith("python") and words[1:3] == ["-m", "unittest"]: found.add("unittest")
        elif name == "npm" and words[1:] == ["test"]: found.add("npm test")
        elif name == "node" and words[1:] == ["bin/job.cjs"]: found.add("node bin/job.cjs")
        elif name == "cd" and len(words) == 2: continue
        else: return set()
    return found


def contract_evidence(path: Path) -> bool:
    """Check the fixture's machine-readable input contract, not prose keywords."""
    try:
        schema = json.loads((path / "invoice.inputs.schema.json").read_text())
        price = schema["properties"]["unitPrice"]
        if schema["type"] != "object" or price["type"] != "string" or "unitPrice" not in schema["required"]:
            return False
        pattern = re.compile(price["pattern"])
        return all(pattern.fullmatch(value) for value in ("0.10", "-1.005", "2")) and not any(
            pattern.fullmatch(value) for value in ("refund", "--1", ".", " 1", "1x"))
    except (OSError, ValueError, KeyError, TypeError, re.error):
        return False


def grade(case: str, path: Path, raw: str, grader: list[str]) -> tuple[bool, dict]:
    try:
        commands = commands_from_events(raw)
    except (ValueError, TypeError) as error:
        return False, {"error": f"unsupported native trace: {error}"}
    required = ("unittest",) if case != "node-runtime" else ("npm test", "node bin/job.cjs")
    observed = set(required).issubset(set().union(*(check_invocations(command) for command in commands)))
    # The grader command is held outside the candidate workspace. Agent-authored
    # tests and final claims cannot replace these independent behavior checks.
    try:
        result = subprocess.run(grader, cwd=path, capture_output=True, text=True, timeout=15)
        behavior = result.returncode == 0 and result.stdout.strip() == ("ready" if case == "node-runtime" else "behavior-ok")
    except (OSError, subprocess.TimeoutExpired) as error:
        return False, {"error": f"independent check unavailable: {error}"}
    contract_updated = case != "incremental-contract" or contract_evidence(path)
    return observed and behavior and contract_updated, {"machineContractPassed": contract_updated,
                                   "documentationSemantics": "unverified; free-form prose is not graded",
                                   "observedCommands": len(commands), "requiredChecksObserved": observed,
                                   "independentBehaviorPassed": behavior, "checkExitCode": result.returncode}


def run_case(case: str, artifact_dir: Path, timeout: int) -> dict:
    if case == "node-runtime" and (not shutil.which("node") or not shutil.which("npm")):
        return {"case": case, "status": "unavailable", "error": "node/npm unavailable"}
    case_artifacts = artifact_dir / case
    case_artifacts.mkdir()
    with tempfile.TemporaryDirectory(prefix=f"codex-behavior-{case}-") as temporary:
        path = Path(temporary)
        prompt, grader = write_fixture(path, case)
        command = ["codex", "-a", "never", "exec", "--ephemeral", "--json", "--color", "never",
                   "--sandbox", "workspace-write", "--skip-git-repo-check", "--cd", str(path), prompt]
        print(f"running isolated native fixture: {case}", flush=True)
        try:
            with (case_artifacts / "events.jsonl").open("w") as stdout, (case_artifacts / "stderr.txt").open("w") as stderr:
                process = subprocess.Popen(command, stdout=stdout, stderr=stderr, start_new_session=True)
                try:
                    exit_code = process.wait(timeout=timeout)
                except (subprocess.TimeoutExpired, KeyboardInterrupt):
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait()
                    return {"case": case, "status": "unavailable", "error": "native execution interrupted or timed out"}
        except OSError as error:
            return {"case": case, "status": "unavailable", "error": str(error)}
        if exit_code:
            return {"case": case, "status": "unavailable", "error": f"native execution exit {exit_code}; inspect stderr artifact"}
        accepted, evidence = grade(case, path, (case_artifacts / "events.jsonl").read_text(), grader)
        shutil.copytree(path, case_artifacts / "result")
        return {"case": case, "status": "passed" if accepted else "failed", **evidence}


class GraderTests(unittest.TestCase):
    def test_claim_without_commands_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            _, grader = write_fixture(path, "python-discovery")
            raw = json.dumps({"type": "item.completed", "item": {"type": "agent_message", "text": "unittest passed"}})
            self.assertFalse(grade("python-discovery", path, raw, grader)[0])

    def test_broken_product_with_check_command_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            _, grader = write_fixture(path, "python-discovery")
            raw = json.dumps({"type": "item.completed", "item": {"type": "command_execution", "command": "python3 -m unittest discover -s tests", "exit_code": 0}})
            self.assertFalse(grade("python-discovery", path, raw, grader)[0])

    def test_echo_is_not_execution(self):
        self.assertFalse(check_invocations("echo 'npm test'; echo 'python3 -m unittest'"))
        self.assertEqual(check_invocations("/bin/zsh -lc 'npm test && node bin/job.cjs'"), {"npm test", "node bin/job.cjs"})

    def test_skipped_and_swallowed_checks_are_unverified(self):
        for command in ("true || npm test; true || node bin/job.cjs", "npm test; true", "npm test || true", "exit 0 && npm test", "exec true && npm test", "false && npm test; true"):
            self.assertFalse(check_invocations(command), command)

    def test_prose_claims_cannot_pass_machine_contract(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            write_fixture(path, "incremental-contract")
            (path / "README.md").write_text("Negative unit prices are unsupported. Refund lines are rejected.")
            self.assertFalse(contract_evidence(path))
            (path / "invoice.inputs.schema.json").unlink()
            (path / "README.md").write_text("All refunds and negative prices now work.")
            self.assertFalse(contract_evidence(path))

    def test_valid_product_and_execution_are_accepted(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            _, grader = write_fixture(path, "python-discovery")
            (path / "invoice.py").write_text("from decimal import Decimal, ROUND_HALF_UP\ndef total(lines):\n    return format(sum((Decimal(p)*q for p,q in lines), Decimal(0)).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP), '.2f')\n")
            raw = json.dumps({"type": "item.completed", "item": {"type": "command_execution", "command": "python3 -m unittest discover -s tests", "exit_code": 0}})
            self.assertTrue(grade("python-discovery", path, raw, grader)[0])

    def test_malformed_trace_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertFalse(grade("python-discovery", Path(directory), "not json", [sys.executable, "-V"])[0])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--live", action="store_true")
    parser.add_argument("--case", choices=CASES, action="append")
    parser.add_argument("--artifact-dir", type=Path)
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()
    if args.self_test:
        return 0 if unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(GraderTests)).wasSuccessful() else 1
    if not args.live:
        parser.error("use --self-test or explicit --live")
    if not 1 <= args.timeout <= 600:
        parser.error("timeout must be 1..600 seconds per case")
    artifacts = args.artifact_dir or Path(tempfile.mkdtemp(prefix="codex-behavior-evidence-"))
    artifacts.mkdir(parents=True, exist_ok=True)
    cases = args.case or list(CASES)
    if len(set(cases)) != len(cases) or any((artifacts / case).exists() for case in cases):
        parser.error("use unique cases and a fresh artifact directory; existing evidence is not overwritten")
    source_digest = hashlib.sha256(Path(__file__).read_bytes() + (ROOT / "templates/global/AGENTS.md").read_bytes()).hexdigest()
    results = [run_case(case, artifacts, args.timeout) for case in cases]
    summary = {"sourceDigest": source_digest, "scope": "isolated local fixtures; not live-project acceptance", "artifacts": str(artifacts), "results": results}
    (artifacts / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, indent=2))
    return 0 if all(result["status"] == "passed" for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
