#!/usr/bin/env python3
"""Fail closed on framework-owned token regressions and report live prompt pressure."""

from __future__ import annotations

import argparse
import json
import pathlib
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


def live_prompt_report() -> tuple[dict[str, object], list[str]]:
    completed = subprocess.run(
        ["codex", "debug", "prompt-input", "TOKEN_BUDGET_SENTINEL"],
        cwd=ROOT,
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


def rollout_report(path: pathlib.Path) -> tuple[dict[str, object], list[str]]:
    usages: list[tuple[dict[str, int], dict[str, int]]] = []
    tool_output_chars: list[int] = []
    malformed_lines = 0
    malformed_usage_events = 0
    malformed_tool_outputs = 0
    failures: list[str] = []
    try:
        lines = path.read_text().splitlines()
    except OSError as error:
        return {}, [f"cannot read rollout evidence {path}: {error}"]
    for line in lines:
        if not line.strip():
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            malformed_lines += 1
            continue
        if not isinstance(entry, dict):
            malformed_lines += 1
            continue
        payload = entry.get("payload", {}) if isinstance(entry, dict) else {}
        if not isinstance(payload, dict):
            malformed_lines += 1
            continue
        if entry.get("type") == "event_msg" and payload.get("type") == "token_count":
            info = payload.get("info", {})
            usage = info.get("last_token_usage", {}) if isinstance(info, dict) else {}
            cumulative = info.get("total_token_usage", {}) if isinstance(info, dict) else {}
            if isinstance(usage, dict) and isinstance(cumulative, dict):
                keys = (
                    "input_tokens", "cached_input_tokens", "cache_write_input_tokens",
                    "output_tokens", "reasoning_output_tokens",
                )
                valid_last = all(isinstance(usage.get(key), int) and not isinstance(usage.get(key), bool)
                                 and usage[key] >= 0 for key in keys)
                valid_total = all(isinstance(cumulative.get(key), int)
                                  and not isinstance(cumulative.get(key), bool)
                                  and cumulative[key] >= 0 for key in keys)
                if valid_last and valid_total:
                    values = {key: usage[key] for key in keys}
                    totals = {key: cumulative[key] for key in keys}
                    if values["cached_input_tokens"] <= values["input_tokens"] \
                            and totals["cached_input_tokens"] <= totals["input_tokens"] \
                            and all(totals[key] >= values[key] for key in keys):
                        usages.append((values, totals))
                    else:
                        malformed_usage_events += 1
                else:
                    malformed_usage_events += 1
            else:
                malformed_usage_events += 1
        if entry.get("type") == "response_item" and payload.get("type") == "custom_tool_call_output":
            output = payload.get("output", [])
            if isinstance(output, str):
                tool_output_chars.append(len(output))
            elif isinstance(output, list) and all(isinstance(part, dict) for part in output):
                supported = all(
                    part.get("type") in {"input_text", "output_text", "text", "input_image", "image"}
                    and (part.get("type") in {"input_image", "image"} or isinstance(part.get("text"), str))
                    for part in output
                )
                if supported:
                    tool_output_chars.append(sum(
                        len(part["text"]) for part in output if isinstance(part.get("text"), str)
                    ))
                else:
                    malformed_tool_outputs += 1
            else:
                malformed_tool_outputs += 1
    latest, cumulative = usages[-1] if usages else ({}, {})
    input_tokens = latest.get("input_tokens", 0)
    cached_tokens = latest.get("cached_input_tokens", 0)
    report: dict[str, object] = {
        "nonblankLines": sum(bool(line.strip()) for line in lines),
        "malformedLines": malformed_lines,
        "malformedUsageEvents": malformed_usage_events,
        "malformedToolOutputs": malformed_tool_outputs,
        "responses": len(usages),
        "latestPerResponseProviderUsage": latest,
        "latestCumulativeProviderUsage": cumulative,
        "latestUncachedInputTokens": max(0, input_tokens - cached_tokens),
        "latestCachePercent": round(100 * cached_tokens / input_tokens, 1) if input_tokens else None,
        "toolOutputCalls": len(tool_output_chars),
        "rawLoggedToolOutputTextChars": sum(tool_output_chars),
        "toolOutputsOver16000Chars": sum(value > 16_000 for value in tool_output_chars),
        "largestToolOutputChars": max(tool_output_chars, default=0),
    }
    if not usages:
        failures.append(f"rollout evidence has no valid token usage event: {path}")
    if malformed_lines:
        failures.append(f"rollout evidence contains {malformed_lines} malformed nonblank line(s)")
    if malformed_usage_events:
        failures.append(f"rollout evidence contains {malformed_usage_events} malformed token usage event(s)")
    if malformed_tool_outputs:
        failures.append(f"rollout evidence contains {malformed_tool_outputs} unsupported tool-output shape(s)")
    return report, failures


def main() -> int:
    parser = argparse.ArgumentParser()
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
        live_report, live_failures = live_prompt_report()
        report["livePrompt"] = live_report
        failures.extend(live_failures)
    if args.rollout:
        rollout, rollout_failures = rollout_report(args.rollout.expanduser())
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
