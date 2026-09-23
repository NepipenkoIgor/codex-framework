# Token efficiency contract

This framework minimizes model input and repeated inference without replacing native Codex caching, compaction, model selection, skill routing, or telemetry.

## Measured baseline

The 2026-08-23 audit used Codex CLI 0.149.0, `codex debug prompt-input`, the active task rollout, the current official Codex manual, changelog through 2026-08-20, and stable release `rust-v0.149.0`.

Before changes, the native prompt-input diagnostic exposed 38,733 model-visible text characters across five message items. The installed global plus repository `AGENTS.md` files contributed 15,403 bytes. After consolidation they contribute 13,405 bytes, a 1,998-byte (13.0%) reduction in framework-owned always-on instructions; the same diagnostic fell to 36,740 characters (5.1%) without removing a safety or execution contract.

The active rollout proves prompt caching is working: one stable late response reported 101,799 input tokens, of which 98,048 were cached (96.3%). `cache_write_input_tokens` was zero in this ChatGPT-authenticated task, so this audit does not infer provider cache-write accounting from that field. The rollout also contained 373,844 raw logged text characters across 21 tool results, including 11 over 10,000 characters. Raw JSONL output size is pressure evidence, not proof that every byte was retained in later model-visible context: truncation, compaction, images, and runtime serialization can change what the model receives.

## Enforced decisions

- Keep native request compression, remote compaction v2, skill search, prompt caching, model-owned auto-compaction, and MCP catalog caching authoritative. Do not add local cache, transcript replay, prompt injection, or compaction wrappers.
- Leave stable request compression, remote compaction, skill search, and cached web search at native defaults. Do not pin defaults merely to mirror the runtime; an explicit disabling override is a reviewable regression.
- Retain at most 4,000 tokens per tool result. Prefer targeted `rg`, exact line ranges, bounded JSON fields, and summaries. Paginate or increase the particular read limit when narrow output would omit required evidence.
- Do not pin or downgrade the ordinary project model or reasoning effort for token savings. Leave selection native and quality/risk-driven; explicit high effort remains justified for the existing architect/reviewer risk boundary. Optimize prompt and tool context independently of model quality.
- Keep native auto-compaction thresholds model-owned. An arbitrary lower threshold can spend extra summarization tokens and lose evidence; an arbitrary higher threshold can grow every subsequent inference.
- Keep the universal core at one task-routed framework skill. Full skill bodies load only after selection; domain packs remain opt-in.

## Gates and diagnostics

Static CI and health run:

```bash
python3 scripts/framework-token-budget-check.py --self-test
```

The check enforces file byte ceilings, combined global/project instruction ceilings, the 4,000-token tool-output cap, absence of explicit stable-optimization disabling, absence of startup prompt/compaction overrides, and absence of ordinary model/effort pins. Its self-test proves that oversized instructions, a 12,000-token output cap, disabled skill search, empty rollout evidence, malformed rollout JSON, and unsupported tool-output shapes are rejected.

The live diagnostic performs no model call:

```bash
python3 scripts/framework-token-budget-check.py --project /absolute/project --live
```

The release gate records this live diagnostic as `tokenEfficiency` before any model-backed corpus certification.

Per-skill semantic evidence is invalidated by the skill, contract, routing/semantic evaluator digest, evaluator model, reasoning effort, or a Codex major/minor runtime change. An unchanged attestation may cross only a stable patch update in the same CLI line, because the release reruns current-CLI loader, capability-currency, and provider-routing canaries separately. This prevents a patch-only runtime update from triggering 156 identical semantic runs while a broader runtime or evidence-contract change still fails closed and schedules recertification.

For a real task, inspect exact provider and tool-output evidence from its local rollout:

```bash
python3 scripts/framework-token-budget-check.py --rollout /absolute/path/to/rollout.jsonl
```

For a task family, supply every root and child rollout explicitly. The analyzer validates one root, each child parent link, unique session paths/IDs, and unique response IDs before summing per-response provider usage:

```bash
python3 scripts/framework-token-budget-check.py \
  --rollout-family /absolute/root.jsonl /absolute/worker.jsonl /absolute/tester.jsonl
```

Ordinary diagnosis is advisory. A controlled replay may opt into the strict profile:

```bash
python3 scripts/framework-token-budget-check.py --profile certification \
  --rollout-family /absolute/root.jsonl /absolute/worker.jsonl /absolute/tester.jsonl
```

Certification requires exact response identity, a timestamp for every response, a connected acyclic provenance graph, every child named by a native spawn receipt, and effective model plus effort metadata for every supplied session. A worker is not mandatory: parent-only execution is valid when lanes are coupled or child startup/context cost exceeds the expected critical-path gain. Response, token, compaction, polling, repeated-read and output-size figures remain controlled-canary diagnostics rather than universal project pass/fail quotas. Runtime efficiency is certified from complete-family usage together with verified acceptance-row progress, changed evidence identity, useful overlap and the absence of proven unchanged re-wakes or identical rework. Dollar cost remains unavailable without applicable billing rates for the exact responses.

The report deduplicates provider responses by response ID, separates cumulative/event counters, and labels observed root/child/unknown provenance without assuming one rollout includes child costs. Family mode exposes root/child profile, effective model/effort, and tool splits without summing inherited cumulative snapshots. It reports total and per-session empty polls, repeated status reads with identical results, repeated and oversized tool outputs, repeated Computer Use documentation, compactions, response rate, near-window responses, and Goal blocked/continuation churn. Function and custom tool forms are recognized. Missing model/effort telemetry is unavailable rather than silently assigned to a default. Repetition is scoped to observed boundaries, but environment, changed state, authorization, check digest, blocker dwell, board readback, Browser acceptance and reviewer identity can remain unavailable; unavailable telemetry is never reported as zero. Full-gate identity is not inferred from a project-specific command substring. Malformed evidence remains an error. Default output omits per-turn detail; use `--details` only for an identified investigation. Raw logged text/image characters are not retained context or billable cost.

Provider-reported cached input is proof of cache use. Raw logged tool-output characters describe stored rollout evidence only, not retained model context or token savings. The rollout diagnostic rejects malformed evidence. Poll-loop candidates, repeated command mentions, failed command events, response rate and window pressure are advisory: they do not establish unchanged target/state, authorization or check identity. Investigate the original events before attributing waste or failure. File presence and feature flags prove configuration acceptance only—not actual request compression, compaction, catalog-cache hits, or tool-result truncation. `cache_write_input_tokens = 0` alone is not proof of a cache hit or miss. ChatGPT plan usage does not provide a trustworthy dollar amount; API cost needs the actual model plus input, cached-input, output, and reasoning rates for the same response.

The execution invariants that prevent these pathologies are defined in `docs/runtime-efficiency.md`. They preserve native Goals and automations while bounding execution epochs, external waits, verification reuse, and reviewer identity.

## Existing user-owned configuration

Setup does not overwrite `~/.codex/config.toml`. Project bootstrap preserves an existing `.codex/config.toml` and installs no shell hook. The framework project retains this measured local preference:

```toml
tool_output_token_limit = 4000
```

Do not overwrite unrelated settings or pin native defaults, model, or effort as part of this optimization. A user-owned global model pin is an explicit personal choice; it also means a newly released native default model will not take effect until the user removes that pin.

## Runtime acceptance

Static prompt budgets and policy-classification tests do not prove efficient execution. The bounded project behavior suite runs actual native tools and independent result checks; live-project delivery, complete-family usage and sustained Goal/heartbeat behavior remain separate acceptance evidence. The rollout analyzer is read-only diagnostics, never a scheduler or a safety-hook policy engine.

The always-on instruction budgets live only in `framework-token-budget-check.py`; other checks do not duplicate numeric limits. The expanded global contract adds automatic challenge and single-writer worktree/config/cleanup requirements. Static success now explicitly leaves runtime efficiency uncertified, and rollout warnings are reported separately. No savings percentage is inferred from removing source lines.
