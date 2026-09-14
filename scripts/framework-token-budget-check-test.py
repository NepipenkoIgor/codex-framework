#!/usr/bin/env python3
"""Model-independent rollout diagnostics fixtures; no live sessions/providers."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("budget", Path(__file__).with_name("framework-token-budget-check.py"))
budget = importlib.util.module_from_spec(spec)
spec.loader.exec_module(budget)


def usage(n=1):
    return dict(input_tokens=10*n, cached_input_tokens=5*n, cache_write_input_tokens=0,
                output_tokens=2*n, reasoning_output_tokens=n)


def record(n=1, response_id="r1"):
    return {"type": "token_usage_record", "payload": {"response_id": response_id,
        "turn_id": f"t{n}", "usage": usage(), "turn_token_usage": usage(), "thread_token_usage": usage(n)}}


class Diagnostics(unittest.TestCase):
    def analyze(self, entries, **kwargs):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/"fixture.jsonl"
            path.write_text("\n".join(json.dumps(entry) for entry in entries))
            return budget.rollout_report(path, **kwargs)

    def test_duplicate_response_and_cumulative_are_separate(self):
        report, errors = self.analyze([record(), record(), record(2, "r2")])
        self.assertFalse(errors)
        self.assertEqual(report["responses"], 2)
        self.assertEqual(report["duplicateResponseRecords"], 1)
        self.assertEqual(report["responseUsageSum"], usage(2))
        self.assertEqual(report["latestCumulativeProviderUsage"], usage(2))
        self.assertEqual(report["latestPerResponseProviderUsage"], usage())

    def test_conflicting_duplicate_is_invalid_evidence(self):
        changed = record()
        changed["payload"]["thread_token_usage"] = usage(2)
        report, errors = self.analyze([record(), changed])
        self.assertEqual(report["malformedTokenUsageRecords"], 1)
        self.assertFalse(report["responseCountExact"])
        self.assertTrue(errors)

    def test_changed_operation_state_is_never_a_policy_failure(self):
        entries = [record()]
        for index in range(20):
            entries.extend([
                {"type": "response_item", "payload": {"type": "function_call", "name": "exec_command", "arguments": json.dumps({"cmd": "gh run view 42", "workdir": f"/environment-{index}"})}},
                {"type": "response_item", "payload": {"type": "function_call_output", "output": json.dumps({"status": f"state-{index}"})}}])
        report, errors = self.analyze(entries)
        self.assertFalse(errors)
        self.assertTrue(report["warnings"])
        self.assertTrue(any("unverified" in warning for warning in report["warnings"]))

    def test_missing_identity_is_explicit(self):
        report, errors = self.analyze([record(response_id=None)])
        self.assertFalse(errors)
        self.assertFalse(report["responseCountExact"])
        self.assertIsNone(report["responseUsageSum"])
        self.assertIsNone(report["rootTurns"])

    def test_child_and_root_are_labeled(self):
        for source, role in [("cli", "root"), ({"subagent": {"thread_spawn": {"parent_thread_id": "p"}}}, "child")]:
            report, errors = self.analyze([{"type": "session_meta", "payload": {"source": source}}, record()])
            self.assertFalse(errors)
            self.assertEqual(report["threadRole"], role)
            self.assertEqual(report[role+"Turns"], 1)

    def test_native_shapes_repeats_are_advisory(self):
        call = {"type": "response_item", "payload": {"type": "function_call", "name": "exec_command", "arguments": json.dumps({"cmd": "gh run view 42", "workdir": "/project"})}}
        output = {"type": "response_item", "payload": {"type": "function_call_output", "output": "failed is merely quoted text"}}
        custom = {"type": "response_item", "payload": {"type": "custom_tool_call", "name": "exec", "input": 'await tools.exec_command({cmd:"gh run view 42"})'}}
        report, errors = self.analyze([record(), call, output, custom] + [call]*15)
        self.assertFalse(errors)
        self.assertEqual(report["failedExternalWaitCommands"], 0)
        self.assertEqual(report["toolOutputCalls"], 1)
        self.assertIn("exec_command", report["nestedToolCalls"])
        self.assertTrue(report["warnings"])
        # Distinct user/heartbeat epochs cannot accumulate into a repeat finding.
        entries = [record()]
        for _ in range(20):
            entries.extend([{"type": "event_msg", "payload": {"type": "user_message", "message": "heartbeat"}}, call, output])
        report, errors = self.analyze(entries)
        self.assertFalse(errors)
        self.assertEqual(report["maxIdenticalExternalStatusReads"], 1)
        self.assertFalse(report["warnings"])

    def test_default_bounded_and_details_opt_in(self):
        entries = [record(n, f"r{n}") for n in range(1, 1001)]
        report, errors = self.analyze(entries)
        self.assertFalse(errors)
        self.assertLess(len(json.dumps(report)), 6000)
        self.assertNotIn("perTurnFinalUsage", report)
        report, errors = self.analyze(entries, details=True)
        self.assertEqual(len(report["perTurnFinalUsage"]), 1000)

    def test_unsupported_output_fails_evidence_validation(self):
        report, errors = self.analyze([record(), {"type": "response_item", "payload": {"type": "function_call_output", "output": {"unknown": True}}}])
        self.assertEqual(report["malformedToolOutputs"], 1)
        self.assertTrue(any("unsupported tool-output" in error for error in errors))

    def test_live_prompt_uses_requested_project(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(budget.subprocess, "run") as run:
                run.return_value.returncode = 0
                run.return_value.stdout = json.dumps([{"content": [{"text": "TOKEN_BUDGET_SENTINEL framework-management"}]}])
                report, errors = budget.live_prompt_report(Path(directory))
                self.assertEqual(run.call_args.kwargs["cwd"], Path(directory))
                self.assertEqual(report["project"], str(Path(directory).resolve()))
                self.assertFalse(errors)


if __name__ == "__main__":
    unittest.main()
