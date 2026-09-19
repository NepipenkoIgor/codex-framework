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

    def analyze_family(self, roots, *, profile="advisory"):
        with tempfile.TemporaryDirectory() as directory:
            paths = []
            for index, entries in enumerate(roots):
                path = Path(directory)/f"fixture-{index}.jsonl"
                path.write_text("\n".join(json.dumps(entry) for entry in entries))
                paths.append(path)
            return budget.family_report(paths, profile=profile)

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

    def test_explicit_family_provenance_and_usage_do_not_double_count(self):
        root_response = record(response_id="root-response")
        root_response["timestamp"] = "2026-09-18T20:00:00Z"
        child_response = record(response_id="child-response")
        child_response["timestamp"] = "2026-09-18T20:01:00Z"
        root = [{"type": "session_meta", "payload": {"id": "root-id", "source": "cli"}},
                root_response]
        child = [{"type": "session_meta", "payload": {"id": "child-id", "source": {
            "subagent": {"thread_spawn": {"parent_thread_id": "root-id", "agent_type": "worker"}}}}},
                 child_response]
        report, errors = self.analyze_family([root, child], profile="certification")
        self.assertFalse(errors)
        self.assertTrue(report["provenanceValid"])
        self.assertEqual(report["sessionsByProfile"], {"root": 1, "worker": 1})
        self.assertEqual(report["providerUsage"]["input_tokens"], 20)
        self.assertEqual(report["responses"], 2)

        child[-1] = record(response_id="root-response")
        report, errors = self.analyze_family([root, child])
        self.assertFalse(report["provenanceValid"])
        self.assertTrue(any("double counting" in error for error in errors))

    def test_certification_rejects_unavailable_response_rate(self):
        report = {name: 0 for name in budget.CERTIFICATION_LIMITS}
        report.update({
            "responsesPerHour": None,
            "responseCountExact": True,
            "responseTimestampsComplete": False,
            "provenanceValid": True,
            "sessionsByProfile": {"root": 1, "worker": 1},
        })
        errors = budget.certification_failures(report)
        self.assertTrue(any("responsesPerHour" in error for error in errors))
        self.assertTrue(any("timestamp" in error for error in errors))

    def test_inherited_parent_metadata_does_not_rewrite_child_identity(self):
        root_meta = {"type": "session_meta", "payload": {
            "id": "root-id", "source": "vscode"}}
        child_meta = {"type": "session_meta", "payload": {
            "id": "child-id", "parent_thread_id": "root-id", "source": {
                "subagent": {"thread_spawn": {
                    "parent_thread_id": "root-id", "agent_role": "worker"}}}}}
        report, errors = self.analyze([
            child_meta, record(response_id="child-response"), root_meta])
        self.assertFalse(errors)
        self.assertEqual(report["sessionId"], "child-id")
        self.assertEqual(report["parentThreadId"], "root-id")
        self.assertEqual(report["threadRole"], "child")
        self.assertEqual(report["agentProfile"], "worker")

    def test_inherited_parent_events_are_excluded_from_child_diagnostics(self):
        root_meta = {"type": "session_meta", "payload": {
            "id": "root-id", "source": "vscode"}}
        child_meta = {"type": "session_meta", "payload": {
            "id": "child-id", "parent_thread_id": "root-id", "source": {
                "subagent": {"thread_spawn": {
                    "parent_thread_id": "root-id", "agent_role": "worker"}}}}}
        inherited_start = {"type": "event_msg", "payload": {
            "type": "task_started", "turn_id": "root-turn"}}
        child_start = {"type": "event_msg", "payload": {
            "type": "task_started", "turn_id": "child-turn"}}
        inherited_output = {"type": "response_item", "payload": {
            "type": "function_call_output", "output": "inherited"}}
        child_output = {"type": "response_item", "payload": {
            "type": "function_call_output", "output": "owned"}}
        child_record = record(response_id="child-response")
        child_record["payload"]["thread_id"] = "child-id"
        child_record["payload"]["turn_id"] = "child-turn"
        report, errors = self.analyze([
            child_meta, root_meta, inherited_start, inherited_output,
            child_start, child_output, child_record])
        self.assertFalse(errors)
        self.assertEqual(report["toolOutputCalls"], 1)
        self.assertEqual(report["rawLoggedToolOutputTextChars"], len("owned"))

    def test_family_rejects_missing_parent_and_certification_requires_worker(self):
        root = [{"type": "session_meta", "payload": {"id": "root-id", "source": "cli"}},
                record(response_id="root-response")]
        child = [{"type": "session_meta", "payload": {"id": "child-id", "source": {
            "subagent": {"thread_spawn": {"parent_thread_id": "absent", "agent_type": "tester"}}}}},
                 record(response_id="child-response")]
        report, errors = self.analyze_family([root, child], profile="certification")
        self.assertFalse(report["provenanceValid"])
        self.assertTrue(any("absent parent" in error for error in errors))
        self.assertTrue(any("worker" in error for error in errors))

    def test_family_rejects_disconnected_child_cycle(self):
        root = [{"type": "session_meta", "payload": {"id": "root-id", "source": "cli"}},
                record(response_id="root-response")]
        child_a = [{"type": "session_meta", "payload": {"id": "child-a", "source": {
            "subagent": {"thread_spawn": {"parent_thread_id": "child-b", "agent_type": "worker"}}}}},
                   record(response_id="child-a-response")]
        child_b = [{"type": "session_meta", "payload": {"id": "child-b", "source": {
            "subagent": {"thread_spawn": {"parent_thread_id": "child-a", "agent_type": "tester"}}}}},
                   record(response_id="child-b-response")]
        report, errors = self.analyze_family([root, child_a, child_b], profile="certification")
        self.assertFalse(report["provenanceValid"])
        self.assertTrue(any("cyclic" in error for error in errors))

    def test_runtime_churn_and_repeated_output_diagnostics(self):
        blocked = {"type": "response_item", "payload": {"type": "function_call",
            "name": "update_goal", "arguments": json.dumps({"status": "blocked"})}}
        continuation = {"type": "event_msg", "payload": {"type": "user_message",
            "message": '<codex_internal_context source="goal">continue</codex_internal_context>'}}
        doc = {"type": "response_item", "payload": {"type": "function_call_output",
            "output": "Control native apps or browsers on the user’s computer through the initialized cua API."}}
        report, errors = self.analyze([record(), blocked, continuation, blocked, doc, doc])
        self.assertFalse(errors)
        self.assertEqual(report["goalBlockedContinuationChurn"], 1)
        self.assertEqual(report["computerUseDocumentationLoads"], 2)
        self.assertEqual(report["repeatedComputerUseDocumentationLoads"], 1)
        self.assertEqual(report["repeatedToolOutputCalls"], 1)

    def test_identical_external_read_results_are_correlated_by_call_id(self):
        entries = [record()]
        for index in range(4):
            entries.extend([
                {"type": "response_item", "payload": {"type": "function_call", "call_id": f"c{index}",
                    "name": "exec_command", "arguments": json.dumps({"cmd": "gh run view 42"})}},
                {"type": "response_item", "payload": {"type": "function_call_output", "call_id": f"c{index}",
                    "output": "queued"}},
            ])
        report, errors = self.analyze(entries)
        self.assertFalse(errors)
        self.assertEqual(report["maxIdenticalExternalReadResults"], 4)


if __name__ == "__main__":
    unittest.main()
