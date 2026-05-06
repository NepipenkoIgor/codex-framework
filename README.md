# AI Codex Framework

Codex-first engineering framework for running production-oriented work with:

- a visible orchestration layer
- role briefs and portable skills
- repo-intelligence-driven routing
- explicit verification and quality gates
- repo-local state under `.codex/`

This is the Codex counterpart to the Claude framework in `ai-skills`, but the runtime model is different.
Claude relied heavily on product-native hooks and settings.
This framework uses explicit scripts, cached repo intelligence, generated briefs, and repo-local artifacts as the control plane.

## Start Reading Here

If you want to understand the framework quickly, read in this order:

1. [README.md](/Users/igornepipenko/work/ai-codex-framework/README.md)
   system overview, architecture, file responsibilities, and workflow
2. [CODEX.md](/Users/igornepipenko/work/ai-codex-framework/CODEX.md)
   rules for the main Codex session and orchestration behavior
3. [ORCHESTRATOR_REFERENCE.md](/Users/igornepipenko/work/ai-codex-framework/ORCHESTRATOR_REFERENCE.md)
   model tiers, fallback chains, and execution patterns
4. [scripts/codex-fw.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/codex-fw.sh)
   the actual framework entrypoint and command flow

Short version:

- `README.md` = what the system is
- `CODEX.md` = how the orchestrator should behave
- `ORCHESTRATOR_REFERENCE.md` = tier/pattern policy
- `scripts/codex-fw.sh` = what actually runs

## What This Framework Is

This repo is the source of truth for:

- how Codex sessions should start
- how tasks are routed
- how the main session chooses role, tier, and skills
- how repo facts are detected and cached
- how verification and quality checks run
- how issue/spec-driven work is structured

The framework is trying to make the main Codex session behave like a strong engineer:

1. understand the repo
2. understand the task
3. choose the right owner
4. load the right knowledge lazily
5. implement within repo conventions
6. verify and report clearly

Domain roles are intended to behave like senior engineers inside their own area, so a mobile, backend, or frontend task should naturally carry design, security, documentation, release, and performance awareness when relevant.

## Architecture

The framework is split into five layers.

### 1. Knowledge Layer

- `agents/`
- `skills/`

This is the portable knowledge base.

- `agents/*.md` are role briefs
- `skills/*/SKILL.md` are reusable domain and workflow instructions

This layer should be mostly provider-agnostic.

### 2. Control-Plane Layer

- [CODEX.md](/Users/igornepipenko/work/ai-codex-framework/CODEX.md)
- [CODEX.skills.md](/Users/igornepipenko/work/ai-codex-framework/CODEX.skills.md)
- [CODEX.concepts.md](/Users/igornepipenko/work/ai-codex-framework/CODEX.concepts.md)
- [CODEX.versions.md](/Users/igornepipenko/work/ai-codex-framework/CODEX.versions.md)
- [CODEX.capabilities.md](/Users/igornepipenko/work/ai-codex-framework/CODEX.capabilities.md)
- [CODEX.permissions.md](/Users/igornepipenko/work/ai-codex-framework/CODEX.permissions.md)
- [ORCHESTRATOR_REFERENCE.md](/Users/igornepipenko/work/ai-codex-framework/ORCHESTRATOR_REFERENCE.md)
- `SKILLS_MAP.*.md`
- [routing.yaml](/Users/igornepipenko/work/ai-codex-framework/routing.yaml)

This layer defines policy:

- what the orchestrator is allowed to do
- how skills are layered
- which framework/runtime versions are current targets
- what model tiers mean
- what execution patterns exist
- what the output contract is

### 3. Repo-Intelligence Layer

- [scripts/detect-project-stack.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/detect-project-stack.sh)
- [scripts/detect-project-features.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/detect-project-features.sh)
- [scripts/detect-project-policy.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/detect-project-policy.sh)
- [scripts/detect-project-conventions.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/detect-project-conventions.sh)
- [scripts/detect-project-commands.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/detect-project-commands.sh)
- [scripts/detect-repo-intelligence.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/detect-repo-intelligence.sh)

This layer extracts structured repo facts:

- stack
- features
- project commands
- repo policy
- local conventions
- domain hints
- primary framework
- frontend/backend/test systems

This is the most important layer for “code should look like it belongs in the repo.”

### 4. Orchestration Layer

- [scripts/codex-fw.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/codex-fw.sh)
- [scripts/task-brief.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/task-brief.sh)
- [scripts/plan.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/plan.sh)
- [scripts/session-start.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/session-start.sh)
- [scripts/work.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/work.sh)
- [scripts/banner.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/banner.sh)
- [scripts/preflight.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/preflight.sh)

This layer turns repo facts + task intent into:

- role
- tier
- model
- skill set
- execution pattern
- task brief
- session plan

### 5. Enforcement Layer

- [scripts/guard-scan.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/guard-scan.sh)
- [scripts/quality-check.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/quality-check.sh)
- [scripts/post-change-check.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/post-change-check.sh)
- [scripts/framework-health.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/framework-health.sh)
- [scripts/doctor.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/doctor.sh)
- [scripts/install-git-hooks.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/install-git-hooks.sh)
- repo-local git hooks installed into the repository's hooks directory

This layer catches:

- secret and attribution violations
- repo-quality issues
- missing bootstrap state
- stale hooks
- missing framework files

## Main Session Model

The main Codex session is the orchestrator.

It is not a hidden Claude-style hook runtime.
It is a normal Codex session started with a generated context and explicit session contract.

The main session is expected to:

1. read the generated session context
2. show the startup banner
3. print the generated plan file verbatim
4. wait for `go` on high-risk/contract/strategic work, or auto-start low-risk mechanical work
5. execute the task with the routed route badge and skills
6. verify and report

The framework can also use sub-agents, but the main session remains the top-level coordinator.

## Model Tiers

Model tier policy lives in [ORCHESTRATOR_REFERENCE.md](/Users/igornepipenko/work/ai-codex-framework/ORCHESTRATOR_REFERENCE.md) and [routing.yaml](/Users/igornepipenko/work/ai-codex-framework/routing.yaml).

Current tier mapping:

| Tier | Model | Use |
|---|---|---|
| `low` | `gpt-5.4-mini` | purely mechanical edits, PR/commit mechanics, narrow single-file work |
| `medium` | `gpt-5.5` | normal implementation, review, tests |
| `high` | `gpt-5.5` | architecture, migrations, cross-system debugging |
| `xhigh` | `gpt-5.5` | rescue/recovery, framework redesign, ambiguous high-risk work |

Important policy decision:

- `low` is reserved for almost fully mechanical work
- `medium` is the normal default for most tasks, including coordination-heavy work
- contract-bearing tasks should usually be routed to `high`
- `high`, `xhigh`, strategic, production, spec-driven, requirement-check, and contract-bearing work pauses for `go` after the plan by default
- low-risk mechanical work auto-starts after the plan by default
- the framework is intentionally biased away from cheap-but-weak defaults for normal work

## Orchestration Flow

At a high level the framework does this:

1. bootstrap project state if needed
2. load cached repo intelligence
3. refresh repo intelligence if fingerprint is stale
4. detect task intent
5. choose role from repo intelligence + task
6. choose role/model/tier
7. resolve skills in layers
8. generate brief and plan
9. run work
10. run guard/quality/verification checks

The current route path is:

`repo intelligence -> task intent -> role -> tier -> skill layering -> plan/brief -> execution -> verification`

This is the direction away from old ad hoc regex-only routing.

## Skill Injection Model

Skill injection is explicit and lazy.

The layering order is:

1. domain baseline
2. stack refinement
3. feature refinement
4. domain-map skills
5. task extras

The key files are:

- [CODEX.skills.md](/Users/igornepipenko/work/ai-codex-framework/CODEX.skills.md)
- `SKILLS_MAP.core.md`
- `SKILLS_MAP.frontend.md`
- `SKILLS_MAP.backend.md`
- `SKILLS_MAP.mobile.md`
- `SKILLS_MAP.infra.md`
- `SKILLS_MAP.specialized.md`
- `SKILLS_MAP.testing.md`

Important invariant:

- the planner should identify skill names during planning
- it should not eagerly read all skill bodies during classification

## Repo Intelligence Artifact

The framework now stores repo intelligence as a first-class artifact:

- `.codex/cache/repo-intelligence.env`
- or `/tmp/ai-codex-framework/.../repo-intelligence.env` when project cache is blocked

This file contains fields like:

- `RI_STACK`
- `RI_FEATURES`
- `RI_POLICY`
- `RI_CONVENTIONS`
- `RI_PRIMARY_FRAMEWORK`
- `RI_FRONTEND_SYSTEM`
- `RI_BACKEND_SYSTEM`
- `RI_TEST_SYSTEM`
- `RI_DOMAIN_HINTS`
- `RI_REFRESHED_AT`
- `RI_FINGERPRINT`

Purpose:

- new sessions can reuse repo understanding immediately
- refresh only happens when the repo fingerprint changes
- routing and briefing use one cached source of truth

Inspect it with:

```bash
codex-fw intelligence .
```

## Repo-Local Artifacts

The framework uses `.codex/` inside a working repo.
These are runtime artifacts and should stay out of git. The framework repo keeps templates under `templates/project/`, while local `.codex/` and `.githooks/` paths are ignored.

Important files and directories:

- `.codex/project.env`
  detected project commands
- `.codex/specs/`
  issue/spec-driven work
- `.codex/cache/`
  cached repo intelligence and related detector outputs
- `.codex/runs/`
  generated session, banner, plan, and brief artifacts
- `.codex/handoffs/`
  multi-agent coordination state
- `.codex/memory/`
  local project memory, preferences, decisions, and task episodes

When the environment blocks writes under `.codex/`, the framework falls back to `/tmp/ai-codex-framework/...`.

## Key Files And Responsibilities

### Root docs

- [CODEX.md](/Users/igornepipenko/work/ai-codex-framework/CODEX.md)
  main operating rules
- [CODEX.skills.md](/Users/igornepipenko/work/ai-codex-framework/CODEX.skills.md)
  skill layering policy
- [CODEX.concepts.md](/Users/igornepipenko/work/ai-codex-framework/CODEX.concepts.md)
  hard invariants of the system
- [CODEX.capabilities.md](/Users/igornepipenko/work/ai-codex-framework/CODEX.capabilities.md)
  runtime capability model
- [CODEX.permissions.md](/Users/igornepipenko/work/ai-codex-framework/CODEX.permissions.md)
  permission model and defaults
- [ORCHESTRATOR_REFERENCE.md](/Users/igornepipenko/work/ai-codex-framework/ORCHESTRATOR_REFERENCE.md)
  tiers, patterns, fallback rules
- [CONCEPTS.md](/Users/igornepipenko/work/ai-codex-framework/CONCEPTS.md)
  broader framework notes and migration context

### Main entrypoints

- [scripts/setup.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/setup.sh)
  install the wrapper and defaults
- [scripts/codex-fw.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/codex-fw.sh)
  unified CLI entrypoint
- [scripts/session-start.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/session-start.sh)
  generate session context and launch a framework session
- [scripts/work.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/work.sh)
  issue/spec worktree workflow

### Detection and intelligence

- [scripts/detect-project-stack.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/detect-project-stack.sh)
  raw stack detection
- [scripts/detect-project-features.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/detect-project-features.sh)
  raw feature detection
- [scripts/detect-project-policy.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/detect-project-policy.sh)
  repo policy extraction
- [scripts/detect-project-conventions.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/detect-project-conventions.sh)
  nearby-pattern summary
- [scripts/detect-project-commands.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/detect-project-commands.sh)
  command registry generation
- [scripts/detect-repo-intelligence.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/detect-repo-intelligence.sh)
  structured intelligence artifact generation

### Planning and display

- [scripts/task-brief.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/task-brief.sh)
  structured execution brief
- [scripts/plan.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/plan.sh)
  user-visible plan with `go` gate
- [scripts/banner.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/banner.sh)
  startup banner
- [scripts/status-block.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/status-block.sh)
  compact progress block rendering with route badges like `fix-5.5-h`
- [scripts/preflight.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/preflight.sh)
  startup project state report

### Verification and enforcement

- [scripts/guard-scan.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/guard-scan.sh)
  secret/attribution/policy guard
- [scripts/quality-check.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/quality-check.sh)
  repo-native quality gate
- [scripts/post-change-check.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/post-change-check.sh)
  post-edit verification bundle
- [scripts/framework-health.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/framework-health.sh)
  framework self-check
- [scripts/framework-eval.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/framework-eval.sh)
  golden routing and orchestration evals
- [scripts/framework-maturity.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/framework-maturity.sh)
  executable maturity score for routing, roles, briefs, handoffs, and verification gates
- [scripts/framework-drift-check.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/framework-drift-check.sh)
  detects drift between routing policy, role briefs, skills, and reachable shell routes
- [scripts/framework-benchmark.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/framework-benchmark.sh)
  runs the route benchmark dataset in `templates/framework-benchmark.tsv`
- [scripts/framework-skill-quality.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/framework-skill-quality.sh)
  audits baseline skills and role bundles for UI kit, design-system, DRY/KISS, DB, hardcode, performance, and verification coverage
- [scripts/framework-skill-corpus-audit.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/framework-skill-corpus-audit.sh)
  scores every skill file for structure, workflow, constraints, verification, output contract, domain depth, quality principles, safety, tooling, and repo-context coverage
- [scripts/doctor.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/doctor.sh)
  project readiness check

### Spec, PR, and git flow

- [scripts/extract-spec.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/extract-spec.sh)
- [scripts/spec-status.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/spec-status.sh)
- [scripts/browser-verify.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/browser-verify.sh)
- [scripts/pr-ready.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/pr-ready.sh)
- [scripts/pr-body.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/pr-body.sh)
- [scripts/pr-create.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/pr-create.sh)
- [scripts/safe-commit.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/safe-commit.sh)

`pr-ready` now rebases the branch onto the detected base, auto-resolves simple rebase conflicts in favor of the feature branch, and pushes with `--force-with-lease` only after checks pass.
`pr-create` runs `pr-ready`, rejects shared or `codex/*` head branches, creates/updates the PR with explicit `--base` and `--head`, and generates a `## Test Plan` from the readiness report and active spec.
`codex-fw work` now auto-submits issue work by default after the Codex session finishes: it commits any remaining changes, pushes the branch, and creates or updates the PR. Set `CODEX_AUTO_SUBMIT=0` if you want to keep the branch local.

### Coordination state

- [scripts/handoff-state.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/handoff-state.sh)
- [scripts/retry-state.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/retry-state.sh)

### Local memory

- [scripts/memory-state.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/memory-state.sh)

The memory layer is repo-local runtime state under `.codex/memory/`.
It is ignored by git and is meant to help new sessions start with compact, curated context instead of rediscovering everything from scratch.

Memory files:

- `project.md`
  stable local project notes generated from repo intelligence, then editable by the operator
- `preferences.md`
  local operator/workflow preferences
- `decisions.local.md`
  local decisions that should influence future sessions
- `episodes.jsonl`
  compact summaries of previous tasks
- `summaries/`
  archived older episode logs after compaction

The session startup and task brief now include a compact memory block:

1. project memory
2. preferences
3. local decisions
4. relevant task episodes

This is intentionally not a full transcript store. The goal is to spend fewer tokens on repeated repo discovery while preserving the facts and decisions that actually help the next task.

CLI task and issue sessions automatically append a compact episode after the Codex run completes.
Disable this with:

```bash
CODEX_MEMORY_AUTO_RECORD=0
```

## Commands You Actually Use

### Start a normal framework session

```bash
codex
```

### Start task-first

```bash
codex --task "fix login timeout"
```

Task-first sessions now create a sibling worktree from the repository default branch by default, so ad hoc work stays isolated from your primary checkout.
Task-first branch names use product-facing prefixes inferred from the task text: `feature/` by default, `fix/` for bug fixes, `chore/` for polish/refactors/maintenance, `docs/` for docs, and `test/` for test work. Avoid tool-revealing prefixes such as `codex/` for any PR branch.
Set `CODEX_TASK_WORKTREE=0` if you want to keep a task session in the current checkout.
When a worktree is created, the framework copies root `.env` / `.env.*` files from the source checkout so local migrations, tests, and scripts can run with the same machine-specific config. It skips template files such as `.env.example`.
Set `CODEX_WORKTREE_ENV_SYNC=symlink` to link those files instead, or `CODEX_WORKTREE_ENV_SYNC=0` to disable env sync.

### Start issue/spec flow

```bash
codex -w 495
```

Issue worktrees default to fresh-by-SHA. Each run fetches the repository default branch, creates a new sibling worktree from the current default-branch SHA, and names the branch/path with that SHA suffix.
Fresh issue worktrees use the same `.env` sync behavior as task worktrees.

```bash
codex -w 495 --resume
codex -w 495 --cleanup
codex --worktrees
```

Use `--resume` only when you explicitly want the latest existing worktree for that issue without fetching. Use `--cleanup` or `--cleanup-all` to remove every worktree for an issue.

### Inspect readiness

```bash
codex-fw doctor
```

### Inspect repo intelligence

```bash
codex-fw intelligence .
```

### Inspect local memory

```bash
codex-fw memory status
codex-fw memory context "fix login timeout"
codex-fw memory search "auth timeout"
```

### Add local memory

```bash
codex-fw memory add-decision "Use Bun as the default package runner for this repo."
codex-fw memory add-episode --task "fix login timeout" --summary "Adjusted auth refresh handling." --files "src/lib/auth.ts" --verification "bunx vitest run src/lib/auth.test.ts" --tags "auth,session"
```

### Compact or prune local memory

```bash
codex-fw memory compact 200
codex-fw memory prune 200
```

### Generate brief or plan without launching a session

```bash
codex-fw brief "fix landing avatar copy"
codex-fw plan "fix landing avatar copy"
```

### Run verification after changes

```bash
codex-fw post-change-check
```

## Runtime Profile And Permissions

After [scripts/setup.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/setup.sh), the wrapper defaults the local runtime profile to:

- approval mode: `never`
- sandbox mode: `danger-full-access`

This is a workstation default, not a repo-side self-grant.

For stricter behavior:

```bash
codex --raw
```

or override with shell env vars.

## How A New Run Understands The Repo Immediately

The framework now relies on cached repo intelligence.

At session start it:

1. bootstraps `.codex/` if needed
2. loads `.codex/cache/repo-intelligence.env`
3. refreshes it if the fingerprint is stale
4. includes it in the session context as a required read

That means the orchestrator does not need to rediscover the repo from scratch every run.

## Current Strengths

The framework is now strong at:

- visible orchestration
- structured session startup
- route badge and skill planning
- issue/spec workflows
- repo-intelligence caching
- requirement-sensitive gating
- explicit guard and quality checks

## Current Limits

The framework is still not perfect.

Remaining gaps are mostly in:

- convention extraction depth on real repos
- helper reuse detection
- boundary detection in mixed repos
- file-path-driven routing refinement
- making quality checks more repo-native across backend/mobile/infra, not only frontend-heavy cases

So this is production-oriented, but still needs tuning against real codebases.

## Recommended Way To Evaluate It

Run it in a real repo with:

```bash
codex-fw doctor
codex-fw intelligence .
codex --task "your real task"
```

Then inspect:

- chosen role
- chosen route badge
- generated brief
- repo policy and conventions
- verification and quality output

That is the fastest way to see whether the framework is behaving like the engineering system you want.
