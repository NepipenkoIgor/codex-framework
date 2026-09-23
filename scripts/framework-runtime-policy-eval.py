#!/usr/bin/env python3
"""Batched, sampled native runtime-policy classifier with exact usage receipts."""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import tempfile
from collections import Counter
from typing import Any

ROOT = pathlib.Path(__file__).resolve().parents[1]
CASES = ROOT / "evals/runtime-efficiency-cases.tsv"
ACTIONS = ["continue_execution", "bounded_wait", "heartbeat", "checkpoint",
           "blocked_split", "reuse_evidence", "review_unavailable"]
TRIALS = 3


def load_cases() -> list[dict[str, Any]]:
    rows = []
    for line in CASES.read_text().splitlines():
        if not line.strip():
            continue
        name, expected, poll, repeat, reviewer, prompt = line.split("\t", 5)
        rows.append({"case": name, "expectedActions": expected.split("|"),
                     "shell_poll_allowed": poll == "true", "repeat_full_gate": repeat == "true",
                     "start_reviewer": reviewer == "true", "prompt": prompt})
    if not rows or len({row["case"] for row in rows}) != len(rows):
        raise ValueError("runtime policy cases must be nonempty and uniquely named")
    return rows


def output_schema(cases: list[dict[str, Any]]) -> dict[str, Any]:
    return {"$schema": "https://json-schema.org/draft/2020-12/schema", "type": "object",
            "additionalProperties": False, "required": ["results"], "properties": {"results": {
                "type": "array", "minItems": len(cases), "maxItems": len(cases), "items": {
                    "type": "object", "additionalProperties": False,
                    "required": ["case", "action", "shell_poll_allowed", "repeat_full_gate",
                                 "start_reviewer", "reason"], "properties": {
                        "case": {"type": "string", "enum": [row["case"] for row in cases]},
                        "action": {"type": "string", "enum": ACTIONS},
                        "shell_poll_allowed": {"type": "boolean"},
                        "repeat_full_gate": {"type": "boolean"},
                        "start_reviewer": {"type": "boolean"},
                        "reason": {"type": "string", "minLength": 1}}}}}}


def prompt_for(cases: list[dict[str, Any]]) -> str:
    tasks = "\n".join(f"{index + 1}. {row['case']}: {row['prompt']}"
                      for index, row in enumerate(cases))
    return ("Do not use tools or change files. Classify every hypothetical long-running task below "
            "using the repository agreement. Return one result per case in the listed order and assess "
            "each independently. shell_poll_allowed means a repeated shell/sleep polling loop, not a "
            "one-time command or attached native wait. repeat_full_gate means rerunning every check, "
            "not only checks invalidated by new evidence. This is policy classification, not proof of "
            f"tool behavior.\n\n{tasks}")


def parse_usage(events: pathlib.Path) -> dict[str, int]:
    usages = []
    for line in events.read_text().splitlines():
        event = json.loads(line)
        if event.get("type") == "turn.completed" and isinstance(event.get("usage"), dict):
            usages.append(event["usage"])
    if len(usages) != 1:
        raise ValueError("each fresh trial must contain exactly one usage receipt")
    usage = usages[0]
    keys = ("input_tokens", "cached_input_tokens", "cache_write_input_tokens",
            "output_tokens", "reasoning_output_tokens")
    if any(not isinstance(usage.get(key), int) or usage[key] < 0 for key in keys):
        raise ValueError("runtime policy usage receipt is incomplete")
    if usage["cached_input_tokens"] > usage["input_tokens"]:
        raise ValueError("cached input exceeds input tokens")
    if usage["reasoning_output_tokens"] > usage["output_tokens"]:
        raise ValueError("reasoning output exceeds output tokens")
    return {key: usage[key] for key in keys}


def validate_results(payload: Any, cases: list[dict[str, Any]]) -> list[dict[str, Any]]:
    if not isinstance(payload, dict) or set(payload) != {"results"} or not isinstance(payload["results"], list):
        raise ValueError("runtime policy batch output has the wrong shape")
    results = payload["results"]
    if [item.get("case") for item in results if isinstance(item, dict)] != [row["case"] for row in cases]:
        raise ValueError("runtime policy batch output is missing, duplicated, or reordered")
    return results


def decision_tuple(item: dict[str, Any]) -> tuple[Any, ...]:
    return (item["action"], item["shell_poll_allowed"], item["repeat_full_gate"], item["start_reviewer"])


def evaluate(cases: list[dict[str, Any]], trials: list[list[dict[str, Any]]]) -> list[dict[str, Any]]:
    if len(trials) != TRIALS:
        raise ValueError(f"runtime policy certification requires exactly {TRIALS} fresh trials")
    verdicts = []
    for index, case in enumerate(cases):
        votes = Counter(decision_tuple(trial[index]) for trial in trials)
        majority, count = votes.most_common(1)[0]
        expected = (majority[0] in case["expectedActions"]
                    and majority[1] == case["shell_poll_allowed"]
                    and majority[2] == case["repeat_full_gate"]
                    and majority[3] == case["start_reviewer"])
        verdicts.append({"case": case["case"], "majority": list(majority), "majorityCount": count,
                         "passed": count >= 2 and expected,
                         "votes": [{"decision": list(decision), "count": vote_count}
                                   for decision, vote_count in sorted(votes.items(), key=lambda pair: str(pair[0]))]})
    return verdicts


def self_test() -> None:
    cases = [{"case": "a", "expectedActions": ["checkpoint"], "shell_poll_allowed": False,
              "repeat_full_gate": False, "start_reviewer": False}]
    good = {"case": "a", "action": "checkpoint", "shell_poll_allowed": False,
            "repeat_full_gate": False, "start_reviewer": False, "reason": "good"}
    bad = {**good, "action": "continue_execution"}
    assert evaluate(cases, [[good], [good], [bad]])[0]["passed"]
    assert not evaluate(cases, [[good], [bad], [bad]])[0]["passed"]
    ordered_cases = [cases[0], {**cases[0], "case": "b"}]
    ordered = [good, {**good, "case": "b"}]
    assert validate_results({"results": ordered}, ordered_cases) == ordered
    for invalid in ([ordered[1], ordered[0]], [ordered[0], ordered[0]]):
        try:
            validate_results({"results": invalid}, ordered_cases)
        except ValueError:
            pass
        else:
            raise AssertionError("runtime policy evaluator accepted reordered or duplicated cases")
    valid_usage = {"input_tokens": 10, "cached_input_tokens": 5, "cache_write_input_tokens": 0,
                   "output_tokens": 2, "reasoning_output_tokens": 1}
    with tempfile.TemporaryDirectory(prefix="framework-runtime-policy-self-test-") as directory:
        events = pathlib.Path(directory) / "events.jsonl"
        events.write_text(json.dumps({"type": "turn.completed", "usage": valid_usage}) + "\n")
        assert parse_usage(events) == valid_usage
        for invalid_usage in ({**valid_usage, "reasoning_output_tokens": 3},
                              {key: value for key, value in valid_usage.items() if key != "output_tokens"}):
            events.write_text(json.dumps({"type": "turn.completed", "usage": invalid_usage}) + "\n")
            try:
                parse_usage(events)
            except ValueError:
                pass
            else:
                raise AssertionError("runtime policy evaluator accepted invalid usage")
    print("runtime policy evaluator self-test: passed")


def run(receipt_path: pathlib.Path | None) -> int:
    cases = load_cases()
    trial_results: list[list[dict[str, Any]]] = []
    trial_receipts = []
    with tempfile.TemporaryDirectory(prefix="framework-runtime-policy-") as directory:
        temp = pathlib.Path(directory)
        schema = temp / "schema.json"
        schema.write_text(json.dumps(output_schema(cases)))
        for trial in range(1, TRIALS + 1):
            output, events, stderr = (temp / f"trial-{trial}.{suffix}" for suffix in ("json", "jsonl", "stderr"))
            command = ["codex", "exec", "--ephemeral", "--json", "--color", "never", "-s", "read-only",
                       "-C", str(ROOT), "--output-schema", str(schema), "-o", str(output), prompt_for(cases)]
            with events.open("w") as stdout_file, stderr.open("w") as stderr_file:
                completed = subprocess.run(command, stdin=subprocess.DEVNULL, stdout=stdout_file,
                                           stderr=stderr_file, check=False)
            if completed.returncode:
                raise RuntimeError(f"runtime policy trial {trial} failed: {stderr.read_text()[-1000:]}")
            results = validate_results(json.loads(output.read_text()), cases)
            usage = parse_usage(events)
            trial_results.append(results)
            trial_receipts.append({"trial": trial, "usage": usage,
                                   "decisions": [{"case": item["case"], "decision": list(decision_tuple(item))}
                                                 for item in results]})
    verdicts = evaluate(cases, trial_results)
    totals = {key: sum(trial["usage"][key] for trial in trial_receipts)
              for key in trial_receipts[0]["usage"]}
    totals["uncached_input_tokens"] = totals["input_tokens"] - totals["cached_input_tokens"]
    receipt = {"receiptVersion": 1, "method": {"batchSize": len(cases), "freshTrials": TRIALS, "threshold": 2},
               "trials": trial_receipts, "cases": verdicts, "usageTotals": totals,
               "totalCases": len(cases), "failureCount": sum(not item["passed"] for item in verdicts)}
    if receipt_path:
        receipt_path.write_text(json.dumps(receipt, indent=2) + "\n")
    for index, verdict in enumerate(verdicts, 1):
        majority = verdict["majority"]
        print(f"{'ok' if verdict['passed'] else 'not ok'} {index:02d} {verdict['case']} -> {majority[0]} "
              f"poll={str(majority[1]).lower()} repeat={str(majority[2]).lower()} "
              f"reviewer={str(majority[3]).lower()} votes={verdict['majorityCount']}/{TRIALS}")
    print(json.dumps({"runtimePolicyUsage": totals, "method": receipt["method"]}, sort_keys=True))
    print(f"framework policy classification: {len(cases)} cases, {receipt['failureCount']} failures "
          f"({TRIALS} batched fresh trials; per-case majority)")
    return 1 if receipt["failureCount"] else 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--receipt", type=pathlib.Path)
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    return run(args.receipt)


if __name__ == "__main__":
    raise SystemExit(main())
