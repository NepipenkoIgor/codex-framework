# AI Codex Framework

This repository is a native Codex extension layer. Codex owns planning, model selection, skills, approvals, sandboxing, plugins, MCP, worktrees, and subagent lifecycle. Do not recreate those capabilities with shell routing, prompt gates, retries, or workflow wrappers.

## Execution

1. Read the relevant code and local instructions before editing.
2. Use native planning for a task with a contract, multiple files, or non-trivial risk.
3. Use a custom agent only for a bounded responsibility. The parent owns requirements, decisions, integration, and the final report.
4. Verify the actual diff and changed behavior. Report residual risk rather than claiming certainty.

## Delegation

- Delegate read-heavy exploration, reviews, log analysis, and independent tests in parallel when their outputs can be combined without a shared write boundary.
- Use a separate worktree for every parallel writer. Never run concurrent shared-directory edits.
- Resolve API, schema, dependency, or other shared contracts before parallel implementation.
- Do not delegate recursively: direct child agents only.

## Native Agent Profiles

- `explorer`: read-only evidence gathering; use for reconnaissance and broad scans.
- `architect`: read-only contracts, migrations, and tradeoffs before a cross-cutting change.
- `builder`: scoped implementation after the contract is clear.
- `reviewer`: read-only correctness, security, regression, and test-gap review.
- `tester`: targeted tests and reproducible verification.

Keep the parent model choice by default. Use higher reasoning for architecture, security, multi-system work, ambiguity, and a failed substantive verification attempt; use lower-cost workers only for bounded read-heavy work.

## Skills and Integrations

Use the smallest matching skill set. Skills are reusable workflow knowledge, not a reason to preload every domain. Prefer installed native plugins and MCP servers over project wrappers. Start connectors read-only and enable write actions only for the task that requires them.

Use the Browser plugin for observable UI verification. Use GitHub integration for issue, PR, and CI context when it is available. Do not add filesystem, git, or browser MCP servers that duplicate Codex tools.

## Hooks

Framework hooks may enforce deterministic safety policy, record durable project memory, and run closeout checks. They must not route prompts, choose a model, generate plans, manage agents, or implement retries.
