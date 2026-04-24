# ORCHESTRATOR_REFERENCE.md

Reference for routing, execution patterns, and model fallback behavior.

## Model Tiers

| Tier | Preferred model | Use for |
|---|---|---|
| `low` | `codex-mini-latest` | mechanical edits, narrow test fixes, obvious config changes |
| `medium` | `gpt-5.4` | normal implementation, review, and test work |
| `high` | `gpt-5.4` | architecture, multi-system work, migrations, hard debugging |
| `xhigh` | `gpt-5.4` | rescue attempts, framework redesign, ambiguous high-risk work |

## Fallback Chains

Deterministic fallback order:

- `codex-mini-latest -> gpt-5.4`
- `gpt-5.4 -> codex-mini-latest`

Each step may be attempted at most once before the framework reports exhaustion.

## Execution Patterns

### Fast Path

Use for one clear mechanical action.

- single owner
- low tier
- no contract work
- no architecture step

### Implement Standard

Use for a single-domain build with known patterns.

- one builder/fixer/refactorer
- targeted verification afterward

### Contract First

Use when the task crosses API, schema, or shared ownership boundaries.

1. architecture/contract step
2. implementation step(s)
3. verification step

### Review First

Use when file locations or failure rows must be clarified before edits.

- visual polish
- broad gap analysis
- ambiguous review comments
- requirement-sensitive corrections where the agent must first state what is wrong

### Batched Mechanical Fixes

Use when many independent cosmetic or low-risk edits are present.

- review discovers files
- low-tier fixes execute in batches
- reviewer validates afterward

## Multi-Agent Rules

- do not delegate the next immediate blocker unless parallel work is genuinely possible
- do not have two workers edit the same files at once
- create handoff state when coordination spans more than one owner
- if an upstream agent blocks, downstream dependent steps should not proceed blindly

## Output Contract

Delegated work should return:

- `Status: done | partial | blocked`
- `Requirement: ...`
- `Current behavior: ...`
- `Mismatch: ...`
- `Fix intent: ...`
- `Changed: [...]`
- `Verification: [...]`
- `Notes: [...]`

For requirement-sensitive work, the first substantive output must be the mismatch report, not code edits.
