#!/usr/bin/env python3
"""Fail closed on framework-owned token regressions and report live prompt pressure."""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib


ROOT = pathlib.Path(__file__).resolve().parents[1]
BYTE_LIMITS = {
    "AGENTS.md": 5_500,
    "templates/global/AGENTS.md": 9_000,
    "templates/project/AGENTS.md": 2_000,
    "skills/framework-management/SKILL.md": 5_000,
}
COMBINED_LIMITS = {
    ("AGENTS.md", "templates/global/AGENTS.md"): 14_000,
    ("templates/project/AGENTS.md", "templates/global/AGENTS.md"): 11_000,
}
LIVE_PROMPT_CHAR_LIMIT = 45_000
TOOL_OUTPUT_TOKEN_LIMIT = 4_000
NATIVE_DEFAULT_FEATURES = ("enable_request_compression", "remote_compaction_v2", "skill_search")
FORBIDDEN_CONFIG_KEYS = {
    "compact_prompt",
    "developer_instructions",
    "experimental_compact_prompt_file",
    "model_instructions_file",
}
USAGE_KEYS = (
    "input_tokens", "cached_input_tokens", "cache_write_input_tokens",
    "output_tokens", "reasoning_output_tokens",
)
MAX_IDENTICAL_EXTERNAL_STATUS_READS = 12
MAX_FAILED_EXTERNAL_WAITS = 5
WARN_RESPONSES_PER_HOUR = 120
WARN_NEAR_WINDOW_RESPONSES = 10
WARN_FULL_GATE_RUNS = 3


def valid_usage(value: object) -> bool:
    return isinstance(value, dict) and all(
        isinstance(value.get(key), int) and not isinstance(value.get(key), bool)
        and value[key] >= 0 for key in USAGE_KEYS
    ) and value["cached_input_tokens"] <= value["input_tokens"]


def timestamp(value: object) -> dt.datetime | None:
    if not isinstance(value, str):
        return None
    try:
        return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def output_sizes(output: object) -> tuple[bool, int, int, int]:
    serialized = len(json.dumps(output, ensure_ascii=False, separators=(",", ":")))
    if isinstance(output, str):
        return True, len(output), 0, serialized
    if not isinstance(output, list) or not all(isinstance(part, dict) for part in output):
        return False, 0, 0, serialized
    text_chars = 0
    image_chars = 0
    for part in output:
        part_type = part.get("type")
        if part_type in {"input_text", "output_text", "text"} and isinstance(part.get("text"), str):
            text_chars += len(part["text"])
        elif part_type in {"input_image", "image"} and isinstance(part.get("image_url"), str):
            image_chars += len(part["image_url"])
        else:
            return False, 0, 0, serialized
    return True, text_chars, image_chars, serialized


def command_text(item: object) -> str:
    if not isinstance(item, dict):
        return ""
    command = item.get("command", "")
    if isinstance(command, list):
        return " ".join(str(value) for value in command)
    return str(command)


def external_status_keys(text: str) -> list[str]:
    keys: list[str] = []
    keys.extend(f"gh-run-{verb}:{identifier}" for verb, identifier in
                re.findall(r"\bgh\s+run\s+(view|watch)\s+(\d+)", text))
    keys.extend(f"gh-pr-checks:{identifier}" for identifier in
                re.findall(r"\bgh\s+pr\s+checks\s+(\d+)", text))
    return keys


def has_shell_poll_loop(text: str) -> bool:
    external = re.compile(r"\b(?:gh\s+(?:run\s+(?:view|watch)|pr\s+checks)|curl)\b")
    for match in re.finditer(r"\b(for|while|until)\b(.*?)\bdone\b", text, re.DOTALL):
        kind, body = match.group(1), match.group(2)
        if external.search(body) and (kind in {"while", "until"} or re.search(r"\bsleep\s+\d+", body)):
            return True
    return bool(re.search(r"\bsleep\s+\d+.*\bgh\s+(?:run\s+view|pr\s+checks)\b", text, re.DOTALL))


def text_parts(items: list[object]) -> list[str]:
    parts: list[str] = []
    for item in items:
        if not isinstance(item, dict):
            continue
        content = item.get("content", [])
        if not isinstance(content, list):
            continue
        for part in content:
            if isinstance(part, dict):
                text = part.get("text") or part.get("input_text") or part.get("output_text")
                if isinstance(text, str):
                    parts.append(text)
    return parts


def static_failures(root: pathlib.Path = ROOT) -> list[str]:
    failures: list[str] = []
    sizes: dict[str, int] = {}
    for relative, limit in BYTE_LIMITS.items():
        path = root / relative
        if not path.is_file():
            failures.append(f"missing token-budget input: {relative}")
            continue
        sizes[relative] = path.stat().st_size
        if sizes[relative] > limit:
            failures.append(f"{relative} is {sizes[relative]} bytes; limit is {limit}")
    for paths, limit in COMBINED_LIMITS.items():
        if all(path in sizes for path in paths):
            total = sum(sizes[path] for path in paths)
            if total > limit:
                failures.append(f"{' + '.join(paths)} is {total} bytes; limit is {limit}")

    config_path = root / ".codex/config.toml"
    try:
        config = tomllib.loads(config_path.read_text())
    except (OSError, tomllib.TOMLDecodeError) as error:
        failures.append(f"cannot parse .codex/config.toml: {error}")
        return failures
    if config.get("tool_output_token_limit") != TOOL_OUTPUT_TOKEN_LIMIT:
        failures.append(f"tool_output_token_limit must equal {TOOL_OUTPUT_TOKEN_LIMIT}")
    features = config.get("features", {})
    for feature in NATIVE_DEFAULT_FEATURES:
        if isinstance(features, dict) and features.get(feature) is False:
            failures.append(f"stable native token optimization is explicitly disabled: {feature}")
    for key in FORBIDDEN_CONFIG_KEYS:
        if key in config:
            failures.append(f"startup prompt or compaction override is forbidden: {key}")
    if "model" in config or "model_reasoning_effort" in config:
        failures.append("project config must not pin the default model or reasoning effort")
    return failures


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="framework-token-budget-") as directory:
        fixture = pathlib.Path(directory)
        for relative in (*BYTE_LIMITS, ".codex/config.toml"):
            source = ROOT / relative
            target = fixture / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
        assert not static_failures(fixture), "valid token budget fixture failed"

        global_agents = fixture / "templates/global/AGENTS.md"
        global_agents.write_text(global_agents.read_text() + "x" * 500)
        assert any("templates/global/AGENTS.md" in item for item in static_failures(fixture)), \
            "oversized persistent instructions were accepted"
        shutil.copyfile(ROOT / "templates/global/AGENTS.md", global_agents)

        config_path = fixture / ".codex/config.toml"
        original = config_path.read_text()
        config_path.write_text(original.replace("tool_output_token_limit = 4000", "tool_output_token_limit = 12000"))
        assert any("tool_output_token_limit" in item for item in static_failures(fixture)), \
            "oversized tool-output retention was accepted"
        config_path.write_text(original + "\n[features]\nskill_search = false\n")
        assert any("skill_search" in item for item in static_failures(fixture)), \
            "disabled native skill search was accepted"

        empty_rollout = fixture / "empty.jsonl"
        empty_rollout.write_text("")
        _, failures = rollout_report(empty_rollout)
        assert any("no valid token usage" in item for item in failures), \
            "empty rollout evidence was accepted"
        malformed_rollout = fixture / "malformed.jsonl"
        malformed_rollout.write_text("{not-json}\n")
        report, failures = rollout_report(malformed_rollout)
        assert report["malformedLines"] == 1 and failures, "malformed rollout evidence was accepted"
        shaped_rollout = fixture / "shapes.jsonl"
        shaped_rollout.write_text("\n".join((
            json.dumps({"type": "event_msg", "payload": {"type": "token_count", "info": {
                "last_token_usage": {"input_tokens": 10, "cached_input_tokens": 5,
                    "cache_write_input_tokens": 0, "output_tokens": 2, "reasoning_output_tokens": 1},
                "total_token_usage": {"input_tokens": 20, "cached_input_tokens": 8,
                    "cache_write_input_tokens": 0, "output_tokens": 4, "reasoning_output_tokens": 2}}}}),
            json.dumps({"type": "response_item", "payload": {"type": "custom_tool_call_output",
                "output": "plain"}}),
            json.dumps({"type": "response_item", "payload": {"type": "custom_tool_call_output",
                "output": [{"type": "input_text", "text": "text"},
                           {"type": "input_image", "image_url": "data:image/png;base64,AA=="}]}}),
        )))
        report, failures = rollout_report(shaped_rollout)
        assert not failures and report["rawLoggedToolOutputTextChars"] == 9 \
            and report["latestCumulativeProviderUsage"]["input_tokens"] == 20, \
            "supported rollout output or cumulative usage shapes were rejected"
        malformed_total_rollout = fixture / "malformed-total.jsonl"
        valid_event = {"type": "event_msg", "payload": {"type": "token_count", "info": {
            "last_token_usage": {"input_tokens": 10, "cached_input_tokens": 5,
                "cache_write_input_tokens": 0, "output_tokens": 2, "reasoning_output_tokens": 1},
            "total_token_usage": {"input_tokens": 20, "cached_input_tokens": 8,
                "cache_write_input_tokens": 0, "output_tokens": 4, "reasoning_output_tokens": 2}}}}
        missing_total_event = json.loads(json.dumps(valid_event))
        missing_total_event["payload"]["info"].pop("total_token_usage")
        malformed_total_rollout.write_text("\n".join((json.dumps(valid_event), json.dumps(missing_total_event))))
        report, failures = rollout_report(malformed_total_rollout)
        assert report["responses"] == 1 and report["malformedUsageEvents"] == 1 and failures, \
            "a latest response was paired with an older cumulative total"
        impossible_total_event = json.loads(json.dumps(valid_event))
        impossible_total_event["payload"]["info"]["total_token_usage"]["cached_input_tokens"] = 99
        malformed_total_rollout.write_text(json.dumps(impossible_total_event))
        report, failures = rollout_report(malformed_total_rollout)
        assert report["responses"] == 0 and report["malformedUsageEvents"] == 1 and failures, \
            "impossible cumulative cached-input usage was accepted"

        pathological_rollout = fixture / "pathological.jsonl"
        entries: list[dict[str, object]] = [
            {"timestamp": "2026-01-01T00:00:00Z", "type": "event_msg", "payload": {
                "type": "token_count", "info": {
                    "last_token_usage": {"input_tokens": 90, "cached_input_tokens": 80,
                        "cache_write_input_tokens": 0, "output_tokens": 2,
                        "reasoning_output_tokens": 1},
                    "total_token_usage": {"input_tokens": 100, "cached_input_tokens": 80,
                        "cache_write_input_tokens": 0, "output_tokens": 2,
                        "reasoning_output_tokens": 1},
                    "model_context_window": 100}}},
            {"timestamp": "2026-01-01T00:00:01Z", "type": "event_msg", "payload": {
                "type": "token_count", "info": {
                    "last_token_usage": {"input_tokens": 9, "cached_input_tokens": 8,
                        "cache_write_input_tokens": 0, "output_tokens": 1,
                        "reasoning_output_tokens": 0},
                    "total_token_usage": {"input_tokens": 10, "cached_input_tokens": 8,
                        "cache_write_input_tokens": 0, "output_tokens": 1,
                        "reasoning_output_tokens": 0},
                    "model_context_window": 100}}},
            {"timestamp": "2026-01-01T00:00:02Z", "type": "token_usage_record", "payload": {
                "turn_id": "turn-1",
                "usage": {"input_tokens": 50, "cached_input_tokens": 40,
                    "cache_write_input_tokens": 0, "output_tokens": 3,
                    "reasoning_output_tokens": 1},
                "turn_token_usage": {"input_tokens": 150, "cached_input_tokens": 120,
                    "cache_write_input_tokens": 0, "output_tokens": 6,
                    "reasoning_output_tokens": 2},
                "thread_token_usage": {"input_tokens": 150, "cached_input_tokens": 120,
                    "cache_write_input_tokens": 0, "output_tokens": 6,
                    "reasoning_output_tokens": 2}}},
            {"type": "response_item", "payload": {"type": "function_call_output", "output": [
                {"type": "input_text", "text": "visible"},
                {"type": "input_image", "image_url": "data:image/png;base64,AA=="}]}}
        ]
        entries.extend({"type": "response_item", "payload": {
            "type": "custom_tool_call", "name": "exec",
            "input": f'const r = await tools.exec_command({{"cmd":"gh run view 42"}}); // {index}'}}
            for index in range(MAX_IDENTICAL_EXTERNAL_STATUS_READS + 1))
        pathological_rollout.write_text("\n".join(json.dumps(entry) for entry in entries))
        report, failures = rollout_report(pathological_rollout)
        assert report["latestCumulativeProviderUsage"]["input_tokens"] == 150 \
            and report["latestEventCumulativeUsage"]["input_tokens"] == 10 \
            and report["eventCounterResets"] == 1, \
            "thread totals or event counter reset were misreported"
        assert report["toolOutputCallsByType"]["function_call_output"] == 1 \
            and report["rawLoggedToolOutputTextChars"] == 7 \
            and report["rawLoggedToolOutputImageChars"] > 0, \
            "function or image output accounting was omitted"
        assert not failures and any("external operation" in warning for warning in report["warnings"]), \
            "pathological repeated status reads were accepted"
        assert has_shell_poll_loop("until gh run view 42; do sleep 30; done"), \
            "until polling loop was accepted"
        assert not has_shell_poll_loop(
            "for url in https://example.test/a https://example.test/b; do curl -fsS $url; done"
        ), "finite curl batch was rejected"

        rollback_rollout = fixture / "thread-counter-rollback.jsonl"
        records = []
        for output_tokens in (50, 1):
            records.append({"type": "token_usage_record", "payload": {
                "turn_id": "turn-1",
                "usage": {"input_tokens": 10, "cached_input_tokens": 5,
                    "cache_write_input_tokens": 0, "output_tokens": 1,
                    "reasoning_output_tokens": 0},
                "turn_token_usage": {"input_tokens": 50, "cached_input_tokens": 25,
                    "cache_write_input_tokens": 0, "output_tokens": output_tokens,
                    "reasoning_output_tokens": 0},
                "thread_token_usage": {"input_tokens": 100, "cached_input_tokens": 50,
                    "cache_write_input_tokens": 0, "output_tokens": output_tokens,
                    "reasoning_output_tokens": 0}}})
        rollback_rollout.write_text("\n".join(json.dumps(record) for record in records))
        _, failures = rollout_report(rollback_rollout)
        assert any("malformed token usage record" in failure for failure in failures), \
            "non-input thread counter rollback was accepted"


def live_prompt_report(project: pathlib.Path = ROOT) -> tuple[dict[str, object], list[str]]:
    completed = subprocess.run(
        ["codex", "debug", "prompt-input", "TOKEN_BUDGET_SENTINEL"],
        cwd=project,
        check=False,
        capture_output=True,
        text=True,
        timeout=30,
    )
    if completed.returncode != 0:
        return {}, [f"codex debug prompt-input failed: {completed.stderr.strip()}"]
    try:
        items = json.loads(completed.stdout)
    except json.JSONDecodeError as error:
        return {}, [f"codex debug prompt-input returned invalid JSON: {error}"]
    if not isinstance(items, list):
        return {}, ["codex debug prompt-input did not return an item list"]
    parts = text_parts(items)
    total_chars = sum(len(part) for part in parts)
    joined = "\n".join(parts)
    report: dict[str, object] = {
        "project": str(project.resolve()),
        "items": len(items),
        "textParts": len(parts),
        "totalChars": total_chars,
        "frameworkInstructionBytes": (ROOT / "AGENTS.md").stat().st_size
        + (ROOT / "templates/global/AGENTS.md").stat().st_size,
        "sentinelVisible": "TOKEN_BUDGET_SENTINEL" in joined,
        "frameworkSkillVisible": "framework-management" in joined,
    }
    failures: list[str] = []
    if total_chars > LIVE_PROMPT_CHAR_LIMIT:
        failures.append(f"live prompt input is {total_chars} characters; limit is {LIVE_PROMPT_CHAR_LIMIT}")
    if not report["sentinelVisible"]:
        failures.append("live prompt input omitted the sentinel")
    if not report["frameworkSkillVisible"]:
        failures.append("live prompt input omitted the framework-management skill metadata")
    return report, failures


def rollout_report(path: pathlib.Path, *, details: bool = False) -> tuple[dict[str, object], list[str]]:
    event_usages: list[tuple[dict[str, int], dict[str, int]]] = []
    response_usages: list[dict[str, int]] = []
    final_thread_usage: dict[str, int] = {}
    final_turn_usage: dict[str, dict[str, int]] = {}
    previous_thread_usage: dict[str, int] = {}
    seen_responses: dict[str, tuple[object, ...]] = {}
    duplicate_responses = 0
    unidentified_responses = 0
    duplicate_events = 0
    previous_event_signature = None
    thread_role = "unknown"
    epoch = 0
    direct_commands: collections.Counter[str] = collections.Counter()
    previous_event_input = -1
    event_counter_resets = 0
    model_context_window = 0
    near_window_responses = 0
    response_times: list[dt.datetime] = []
    tool_output_text_chars: list[int] = []
    tool_output_image_chars: list[int] = []
    tool_output_serialized_chars: list[int] = []
    output_calls: collections.Counter[str] = collections.Counter()
    nested_tools: collections.Counter[str] = collections.Counter()
    external_reads: collections.Counter[str] = collections.Counter()
    empty_write_polls: collections.Counter[str] = collections.Counter()
    shell_poll_loops = 0
    failed_external_waits = 0
    compactions = 0
    root_turns: set[str] = set()
    nonblank_lines = 0
    malformed_lines = 0
    malformed_usage_events = 0
    malformed_token_records = 0
    malformed_tool_outputs = 0
    failures: list[str] = []
    try:
        lines = path.open(encoding="utf-8")
    except OSError as error:
        return {}, [f"cannot read rollout evidence {path}: {error}"]
    with lines:
        for line in lines:
            if not line.strip():
                continue
            nonblank_lines += 1
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                malformed_lines += 1
                continue
            if not isinstance(entry, dict):
                malformed_lines += 1
                continue
            payload = entry.get("payload", {})
            if not isinstance(payload, dict):
                malformed_lines += 1
                continue
            entry_type = entry.get("type")
            payload_type = payload.get("type")
            if entry_type == "session_meta":
                source = payload.get("source")
                if isinstance(source, dict) and "subagent" in source:
                    thread_role = "child"
                elif source in ("cli", "vscode", "exec", "appServer"):
                    thread_role = "root"
            if (entry_type == "event_msg" and payload_type in {"user_message", "task_started"}) or entry_type == "turn_context":
                epoch += 1
            if entry_type == "compacted":
                compactions += 1
            if entry_type == "event_msg" and payload_type == "token_count":
                info = payload.get("info", {})
                usage = info.get("last_token_usage", {}) if isinstance(info, dict) else {}
                cumulative = info.get("total_token_usage", {}) if isinstance(info, dict) else {}
                window = info.get("model_context_window", 0) if isinstance(info, dict) else 0
                if valid_usage(usage) and valid_usage(cumulative) \
                        and all(cumulative[key] >= usage[key] for key in USAGE_KEYS):
                    values = {key: usage[key] for key in USAGE_KEYS}
                    totals = {key: cumulative[key] for key in USAGE_KEYS}
                    signature = (values, totals)
                    if signature == previous_event_signature:
                        duplicate_events += 1
                        continue
                    previous_event_signature = signature
                    event_usages.append((values, totals))
                    if previous_event_input >= 0 and totals["input_tokens"] < previous_event_input:
                        event_counter_resets += 1
                    previous_event_input = totals["input_tokens"]
                    if isinstance(window, int) and window > 0:
                        model_context_window = window
                        if values["input_tokens"] >= int(window * 0.9):
                            near_window_responses += 1
                else:
                    malformed_usage_events += 1
            if entry_type == "token_usage_record":
                usage = payload.get("usage", {})
                turn_usage = payload.get("turn_token_usage", {})
                thread_usage = payload.get("thread_token_usage", {})
                turn_id = payload.get("turn_id")
                response_id = payload.get("response_id")
                if isinstance(response_id, str) and response_id and response_id in seen_responses:
                    if (usage, turn_usage, thread_usage, turn_id) != seen_responses[response_id]:
                        malformed_token_records += 1
                    else:
                        duplicate_responses += 1
                    continue
                valid_record = valid_usage(usage) and valid_usage(turn_usage) and valid_usage(thread_usage) \
                    and all(thread_usage[key] >= turn_usage[key] >= usage[key] for key in USAGE_KEYS) \
                    and all(thread_usage[key] >= previous_thread_usage.get(key, 0) for key in USAGE_KEYS)
                if valid_record:
                    if isinstance(response_id, str) and response_id:
                        seen_responses[response_id] = (usage, turn_usage, thread_usage, turn_id)
                    else:
                        unidentified_responses += 1
                    response_usages.append({key: usage[key] for key in USAGE_KEYS})
                    final_thread_usage = {key: thread_usage[key] for key in USAGE_KEYS}
                    previous_thread_usage = final_thread_usage
                    if isinstance(turn_id, str) and turn_id:
                        root_turns.add(turn_id)
                        final_turn_usage[turn_id] = {key: turn_usage[key] for key in USAGE_KEYS}
                    observed = timestamp(entry.get("timestamp"))
                    if observed:
                        response_times.append(observed)
                else:
                    malformed_token_records += 1
            if entry_type == "response_item" and payload_type in {
                    "custom_tool_call_output", "function_call_output"}:
                supported, text_chars, image_chars, serialized_chars = output_sizes(payload.get("output", []))
                if supported:
                    output_calls[payload_type] += 1
                    tool_output_text_chars.append(text_chars)
                    tool_output_image_chars.append(image_chars)
                    tool_output_serialized_chars.append(serialized_chars)
                else:
                    malformed_tool_outputs += 1
            if entry_type == "response_item" and payload_type in {"custom_tool_call", "function_call"}:
                tool_input = payload.get("input", "") if payload_type == "custom_tool_call" else payload.get("arguments", "")
                name = payload.get("name", "unknown")
                if isinstance(name, str):
                    nested_tools[name] += 1
                arguments = None
                if payload_type == "function_call" and isinstance(tool_input, str):
                    try:
                        arguments = json.loads(tool_input)
                    except json.JSONDecodeError:
                        pass
                if isinstance(arguments, dict):
                    if name in {"exec_command", "functions.exec_command", "shell_command"} and isinstance(arguments.get("cmd", arguments.get("command")), str):
                        command = arguments.get("cmd", arguments.get("command"))
                        direct_commands[f"epoch={epoch} cwd={arguments.get('workdir', 'unobserved')} command={command}"] += 1
                    if name in {"write_stdin", "functions.write_stdin"} and arguments.get("chars", "") == "":
                        empty_write_polls[f"{epoch}:{arguments.get('session_id', 'unknown')}"] += 1
                if not isinstance(tool_input, str):
                    continue
                for nested in re.findall(r"\btools\.([A-Za-z0-9_]+)", tool_input):
                    nested_tools[nested] += 1
                for key in external_status_keys(tool_input):
                    external_reads[f"{epoch}:{key}"] += 1
                if "tools.write_stdin" in tool_input and re.search(r"chars\s*:\s*[\"']{2}", tool_input):
                    match = re.search(r"session_id\s*:\s*(\d+)", tool_input)
                    empty_write_polls[f"{epoch}:{match.group(1) if match else 'unknown'}"] += 1
                if has_shell_poll_loop(tool_input):
                    shell_poll_loops += 1
            if entry_type == "event_msg" and payload_type == "item_completed":
                item = payload.get("item", {})
                text = command_text(item)
                if isinstance(item, dict) and item.get("type") == "CommandExecution" \
                        and item.get("status") == "failed" and external_status_keys(text):
                    failed_external_waits += 1
    latest = response_usages[-1] if response_usages else (event_usages[-1][0] if event_usages else {})
    event_cumulative = event_usages[-1][1] if event_usages else {}
    cumulative = final_thread_usage or event_cumulative
    input_tokens = latest.get("input_tokens", 0)
    cached_tokens = latest.get("cached_input_tokens", 0)
    duration_hours = 0.0
    if len(response_times) > 1:
        duration_hours = max((response_times[-1] - response_times[0]).total_seconds() / 3600, 1 / 3600)
    response_count = len(response_usages) if response_usages else len(event_usages)
    responses_per_hour = round(response_count / duration_hours, 1) if duration_hours else None
    max_external_reads = max(external_reads.values(), default=0)
    max_empty_polls = max(empty_write_polls.values(), default=0)
    warnings: list[str] = []
    if responses_per_hour and responses_per_hour > WARN_RESPONSES_PER_HOUR:
        warnings.append(f"response rate is {responses_per_hour}/hour; investigate model-driven microsteps")
    if near_window_responses >= WARN_NEAR_WINDOW_RESPONSES:
        warnings.append(f"{near_window_responses} responses used at least 90% of the context window")
    report: dict[str, object] = {
        "nonblankLines": nonblank_lines,
        "malformedLines": malformed_lines,
        "malformedUsageEvents": malformed_usage_events,
        "malformedTokenUsageRecords": malformed_token_records,
        "malformedToolOutputs": malformed_tool_outputs,
        "responses": response_count,
        "eventUsageRecords": len(event_usages),
        "threadUsageRecords": len(response_usages),
        "threadRole": thread_role,
        "turns": len(root_turns),
        "rootTurns": len(root_turns) if thread_role == "root" else None,
        "childTurns": len(root_turns) if thread_role == "child" else None,
        "duplicateResponseRecords": duplicate_responses,
        "duplicateEventSnapshots": duplicate_events,
        "unidentifiedResponseRecords": unidentified_responses,
        "responseCountExact": bool(response_usages) and not unidentified_responses and not malformed_token_records,
        "responseCountScope": "unique IDs in supplied records" if response_usages and not unidentified_responses else "record/snapshot estimate; response identity unavailable",
        "responseUsageSum": {key: sum(value[key] for value in response_usages) for key in USAGE_KEYS} if response_usages and not unidentified_responses else None,
        "compactions": compactions,
        "eventCounterResets": event_counter_resets,
        "responsesPerHour": responses_per_hour,
        "modelContextWindow": model_context_window or None,
        "nearWindowResponses": near_window_responses,
        "latestPerResponseProviderUsage": latest,
        "latestCumulativeProviderUsage": cumulative,
        "latestEventCumulativeUsage": event_cumulative,
        "latestThreadUsage": final_thread_usage,

        "latestUncachedInputTokens": max(0, input_tokens - cached_tokens),
        "latestCachePercent": round(100 * cached_tokens / input_tokens, 1) if input_tokens else None,
        "toolOutputCalls": sum(output_calls.values()),
        "toolOutputCallsByType": dict(sorted(output_calls.items())),
        "rawLoggedToolOutputTextChars": sum(tool_output_text_chars),
        "rawLoggedToolOutputImageChars": sum(tool_output_image_chars),
        "rawLoggedToolOutputSerializedChars": sum(tool_output_serialized_chars),
        "toolOutputsOver16000TextChars": sum(value > 16_000 for value in tool_output_text_chars),
        "largestToolOutputTextChars": max(tool_output_text_chars, default=0),
        "largestToolOutputImageChars": max(tool_output_image_chars, default=0),
        "largestToolOutputSerializedChars": max(tool_output_serialized_chars, default=0),
        "nestedToolCalls": dict(sorted(nested_tools.items())),
        "externalStatusReads": sum(external_reads.values()),
        "maxIdenticalExternalStatusReads": max_external_reads,
        "emptyWriteStdinPolls": sum(empty_write_polls.values()),
        "maxEmptyWriteStdinPollsPerSession": max_empty_polls,
        "shellPollingLoops": shell_poll_loops,
        "failedExternalWaitCommands": failed_external_waits,
        "fullGateCommandMentions": None,
        "maxRepeatedDirectCommandMentionsInEpoch": max(direct_commands.values(), default=0),
        "evidenceLimitations": [
            "One rollout only; child usage is not added to root usage and inherited history cannot be excluded without provenance.",
            "Event token counts are cumulative snapshots, not independently identified responses.",
            "Commands in custom-tool source are textual candidates; execution, operation environment, state changes and heartbeat authorization are not proven.",
            "Check identity (code SHA, config, environment and inputs) is unavailable; full-gate identity is not inferred from command substrings.",
            "Logged output characters are not retained model-input tokens."
        ],
        "warnings": warnings,
    }
    if not response_usages and not event_usages:
        failures.append(f"rollout evidence has no valid token usage event: {path}")
    if malformed_lines:
        failures.append(f"rollout evidence contains {malformed_lines} malformed nonblank line(s)")
    if malformed_usage_events:
        failures.append(f"rollout evidence contains {malformed_usage_events} malformed token usage event(s)")
    if malformed_token_records:
        failures.append(f"rollout evidence contains {malformed_token_records} malformed token usage record(s)")
    if malformed_tool_outputs:
        failures.append(f"rollout evidence contains {malformed_tool_outputs} unsupported tool-output shape(s)")
    if shell_poll_loops:
        warnings.append(f"{shell_poll_loops} shell polling loop candidate(s); inspect executed command and authorization")
    if max_external_reads > MAX_IDENTICAL_EXTERNAL_STATUS_READS:
        warnings.append(f"external operation command candidates repeated {max_external_reads} times in one observed epoch; environment/state/authorization unverified")
    if failed_external_waits > MAX_FAILED_EXTERNAL_WAITS:
        warnings.append(f"{failed_external_waits} explicitly failed external command events; original failure causes require inspection")
    if max(direct_commands.values(), default=0) > WARN_FULL_GATE_RUNS:
        warnings.append("direct command repeated within one observed epoch; input identity and changed state are unverified")
    if details:
        report["perTurnFinalUsage"] = final_turn_usage
        report["directCommandMentionsByEpoch"] = dict(direct_commands)
    # Tool names are untrusted/unbounded identifiers; default output stays compact.
    if not details:
        report["nestedToolCalls"] = {name[:160]: count for name, count in nested_tools.most_common(20)}
        report["omittedToolNames"] = max(0, len(nested_tools) - 20)
    return report, failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=pathlib.Path, default=pathlib.Path.cwd(), help="effective project directory for --live")
    parser.add_argument("--details", action="store_true", help="include per-turn usage and command detail")
    parser.add_argument("--live", action="store_true", help="inspect native model-visible prompt input")
    parser.add_argument("--rollout", type=pathlib.Path, help="report provider token/cache and tool-output evidence")
    parser.add_argument("--self-test", action="store_true", help="falsify budget and configuration counterexamples")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        print("token budget self-test passed")
    failures = static_failures()
    report: dict[str, object] = {"static": "passed" if not failures else "failed"}
    if args.live:
        live_report, live_failures = live_prompt_report(args.project.expanduser().resolve())
        report["livePrompt"] = live_report
        failures.extend(live_failures)
    if args.rollout:
        rollout, rollout_failures = rollout_report(args.rollout.expanduser(), details=args.details)
        report["rollout"] = rollout
        failures.extend(rollout_failures)
    print(json.dumps(report, indent=2, sort_keys=True))
    if failures:
        print("token budget check failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1
    print("token budget check passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
