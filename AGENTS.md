# AI Codex Framework

This repository is a thin, native Codex extension layer. Codex owns planning, model selection, skills, approvals, sandboxing, plugins, MCP, browser control, worktrees, native agent communication, and subagent lifecycle. Do not recreate them with shell routing, prompt gates, retries, memory injection, or workflow wrappers.

## Execution

1. Read the relevant code and local instructions before editing.
2. For a task with a contract, multiple files, or non-trivial risk, create and maintain a native plan before substantive tool work; keep routine one-file work lightweight.
3. For multi-step implementation work with a clear outcome, start a native goal immediately and continue it automatically. A progress update or plan is never a terminal response: proceed to the next executable step until the definition of done is met, a real blocker requires a user decision, or the user explicitly asks to pause. Do not start a goal for a question, review, one-off explanation, or an explicitly plan-only request.
4. Use a custom agent only for a bounded responsibility. The parent owns requirements, decisions, integration, and the final report.
5. Verify the actual diff and changed behavior. Report residual risk rather than claiming certainty.
6. Before version-sensitive work, generate an ephemeral stack context with `scripts/framework-stack-context.py`: inspect manifests and lockfiles for an existing project, or resolve stable frameworks and production LTS runtimes from official distribution channels for a new project. Verify generated manifests and apply version-specific recipes only when the installed stack exposes the required capability. Preserve existing pins unless migration is explicitly in scope.

## Visible orchestration

- Keep the plan user-visible through concise progress updates. Update it at a decision boundary, after a failed substantive check, or when the scope changes; do not narrate routine commands.
- For a deep audit, cross-system incident, or independent read-heavy investigation, delegate the separable evidence-gathering or review to a real native sub-agent when it improves time to a sound decision. Keep the contract, integration, and all shared writes with the parent.
- Announce a sub-agent only after it has actually been spawned, using `profile — model / effort — bounded responsibility`; report its conclusion or failure when it returns. A profile being available is not an active agent.
- When a skill materially guides the work, identify it as a skill. Skills do not have a model, so never present a skill as an agent or invent a model for it. Show the parent model only when the native runtime exposes it.
- Do not manufacture plan files, status dashboards, fictional agent updates, or hooks that start agents. Native planning and native agent lifecycle remain the source of truth.

## Delegation

- Delegate read-heavy exploration, reviews, log analysis, and independent tests in parallel when their outputs can be combined without a shared write boundary.
- Use a separate worktree for every parallel writer. Never run concurrent shared-directory edits.
- Resolve API, schema, dependency, or other shared contracts before parallel implementation.
- Do not delegate recursively: direct child agents only.
- Give every delegated task a deliverable, file/responsibility boundary, and expected evidence. Use native messages to clarify a live subagent; do not create handoff files or proxy conversations.

## Agent Profiles

- Use Codex's built-in `explorer` for read-only reconnaissance and `worker` for scoped implementation.
- `architect`: read-only contracts, migrations, and tradeoffs before a cross-cutting change.
- `reviewer`: read-only correctness, security, regression, and test-gap review.
- `tester`: targeted tests and reproducible verification.

Let the native catalog choose models by default. Pin only a justified reasoning level in a custom profile; use higher reasoning for architecture, security, migrations, ambiguity, and failed substantive verification.

## Falsification review

- After implementation and ordinary verification, spawn one independent read-only `reviewer` when a change affects security or authorization, migrations or shared schemas, public APIs, concurrency or data integrity, permissions or deployment, multiple systems, or when a substantive check failed or material ambiguity remains.
- Ask the reviewer to try to falsify the result with counterexamples, affected execution paths, regressions, and missing tests. Give it the request and acceptance criteria, the actual diff, and verification evidence; do not delegate implementation or invite style-only feedback.
- Require every actionable finding to include severity, concrete evidence, and a file reference, reproduction, or missing executable check. Treat unsupported concerns as hypotheses, not defects.
- The parent adjudicates the findings, revises only when evidence warrants it, and reruns the affected checks. Stop after exactly one reviewer-to-revision cycle. A further reviewer pass requires a new explicit user request for a deeper audit.
- Skip this review for routine, localized, low-risk changes with clear passing checks. Never create recursive debate loops or let the reviewer edit the shared worktree.

## Skills and Integrations

Use the smallest matching skill set. Skills are reusable workflow knowledge, not a reason to preload every domain. Prefer installed native plugins and MCP servers over project wrappers. Start connectors read-only and enable write actions only for the task that requires them. For UI work, use the native in-app Browser first; retain screenshots only when they prove a visual result that DOM, console, or network evidence cannot.

## Process hygiene

- Clean up only resources started by the current task. Track exact process identifiers or tool sessions; never use broad `pkill`, wildcard deletion, or shared temporary-directory cleanup.
- Stop task-owned development servers and browser sessions before close-out unless the user explicitly asks to keep them running. Let test runners manage servers they started themselves.
- When an API contract changes, update the repository's authoritative API documentation or schema in the same change.
- Follow the repository's existing branch, commit, and pull-request workflow. User intent and closer project instructions override framework defaults.
- Verify current official documentation before introducing a version-sensitive framework or provider pattern.

Use the Browser plugin for observable UI verification. Use GitHub integration for issue, PR, and CI context when it is available. Do not add filesystem, git, or browser MCP servers that duplicate Codex tools.

## Hooks

Hooks may enforce deterministic safety policy and run closeout checks. They must not inject context, route prompts, choose a model, generate plans, manage agents, persist conversational memory, or implement retries.

## Surface parity and token hygiene

Desktop and CLI use the same project `AGENTS.md`, `.codex/config.toml`, skills, profiles, and hooks. Never branch framework behavior by surface. Keep durable repository facts in tracked project documentation; use Codex-native thread memory for conversation continuity. Avoid startup payloads, generated briefs, duplicate role prompts, full skill-map injection, and screenshot-heavy evidence.
