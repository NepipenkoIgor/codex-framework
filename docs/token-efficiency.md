# Token efficiency contract

This framework minimizes model input and repeated inference without replacing native Codex caching, compaction, model selection, skill routing, or telemetry.

## Measured baseline

The 2026-08-23 audit used Codex CLI 0.149.0, `codex debug prompt-input`, the active task rollout, the current official Codex manual, changelog through 2026-08-20, and stable release `rust-v0.149.0`.

Before changes, the native prompt-input diagnostic exposed 38,733 model-visible text characters across five message items. The installed global plus repository `AGENTS.md` files contributed 15,403 bytes. After consolidation they contribute 13,405 bytes, a 1,998-byte (13.0%) reduction in framework-owned always-on instructions; the same diagnostic fell to 36,740 characters (5.1%) without removing a safety or execution contract.

The active rollout proves prompt caching is working: one stable late response reported 101,799 input tokens, of which 98,048 were cached (96.3%). `cache_write_input_tokens` was zero in this ChatGPT-authenticated task, so this audit does not infer provider cache-write accounting from that field. The rollout also contained 373,844 raw logged text characters across 21 tool results, including 11 over 10,000 characters. Raw JSONL output size is pressure evidence, not proof that every byte was retained in later model-visible context: truncation, compaction, images, and runtime serialization can change what the model receives.

## Enforced decisions

- Keep native request compression, remote compaction v2, skill search, prompt caching, model-owned auto-compaction, and MCP catalog caching authoritative. Do not add local cache, transcript replay, prompt injection, or compaction wrappers.
- Leave stable request compression, remote compaction, skill search, and cached web search at native defaults. Do not pin defaults merely to mirror the runtime; an explicit disabling override is a reviewable regression.
- Retain at most 4,000 tokens per tool result. Prefer targeted `rg`, exact line ranges, bounded JSON fields, and summaries. A larger read is justified only after the narrow query cannot establish the required evidence.
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
python3 scripts/framework-token-budget-check.py --live
```

The release gate records this live diagnostic as `tokenEfficiency` before any model-backed corpus certification.

For a real task, inspect exact provider and tool-output evidence from its local rollout:

```bash
python3 scripts/framework-token-budget-check.py --rollout /absolute/path/to/rollout.jsonl
```

The report labels `last_token_usage` as per-response usage and `total_token_usage` as cumulative provider totals. Provider-reported cached input is proof of cache use. Raw logged tool-output characters describe stored rollout evidence only, not retained model context or token savings. File presence, strict config success, and feature flags prove configuration acceptance only—not actual request compression, compaction, catalog-cache hits, or tool-result truncation. `cache_write_input_tokens = 0` alone is not proof of a cache hit or miss. ChatGPT plan usage does not provide a trustworthy dollar amount; API cost needs the actual model plus input, cached-input, output, and reasoning rates for the same response.

## Existing user-owned configuration

Setup does not overwrite `~/.codex/config.toml`. Hook bootstrap preserves an existing project `.codex/config.toml` and validates only its safety-hook contract. The framework project retains this measured local preference:

```toml
tool_output_token_limit = 4000
```

Do not overwrite unrelated settings or pin native defaults, model, or effort as part of this optimization. A user-owned global model pin is an explicit personal choice; it also means a newly released native default model will not take effect until the user removes that pin.
