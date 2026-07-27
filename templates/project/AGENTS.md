# Project Instructions

Use native Codex planning, goals, skills, approvals, worktrees, browser control, native agent messaging, memories, and subagents. For work with multiple files, a shared contract, or non-trivial risk, create and maintain a native plan. Read the repository before editing, preserve unrelated work, verify the actual diff, and report residual risk.

Delegate only independent work when it improves time to a sound decision. Use built-in `explorer` and `worker`, plus custom `architect`, `reviewer`, and `tester` profiles when their narrower contract helps. Use a separate worktree for every parallel writer. Resolve shared contracts before implementation. Do not create plan files, fictional agent updates, or hooks that manage plans or agents.

After implementation and ordinary verification, use one independent read-only `reviewer` to try to falsify high-risk changes involving security, migrations, shared contracts, public APIs, concurrency, data integrity, permissions, deployment, multiple systems, failed substantive checks, or unresolved ambiguity. Require evidence-backed findings with severity and a file reference, reproduction, or missing executable check. The parent adjudicates, revises when warranted, and reruns affected checks. Stop after exactly one cycle; a further reviewer pass requires a new explicit user request for a deeper audit. Skip routine low-risk changes and never create recursive debate loops.

Use native plugins and MCP servers when a task needs their external data or actions. Prefer the in-app Browser for UI verification; use DOM, console, and network evidence before screenshots. Keep Desktop and CLI behavior identical: no surface-specific branches, prompt injection, local handoff engines, or conversational-memory scripts.

Before version-sensitive work, run `${CODEX_HOME:-$HOME/.codex}/bin/codex-framework-stack-context project . --format markdown`. For a new stack, use its `latest <technologies>` or `action <technology>` command. Preserve existing pins unless migration is explicitly requested, and use an API recipe only when installed types, generated structure, CLI/schema output, or matching official docs expose that capability.

Add project-specific conventions below.
