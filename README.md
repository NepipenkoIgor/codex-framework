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
- [CODEX.capabilities.md](/Users/igornepipenko/work/ai-codex-framework/CODEX.capabilities.md)
- [CODEX.permissions.md](/Users/igornepipenko/work/ai-codex-framework/CODEX.permissions.md)
- [ORCHESTRATOR_REFERENCE.md](/Users/igornepipenko/work/ai-codex-framework/ORCHESTRATOR_REFERENCE.md)
- `SKILLS_MAP.*.md`
- [routing.yaml](/Users/igornepipenko/work/ai-codex-framework/routing.yaml)

This layer defines policy:

- what the orchestrator is allowed to do
- how skills are layered
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
- repo-local `.githooks/`

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
3. show the plan
4. wait for `go`
5. execute the task with the routed role/tier/skills
6. verify and report

The framework can also use sub-agents, but the main session remains the top-level coordinator.

## Model Tiers

Model tier policy lives in [ORCHESTRATOR_REFERENCE.md](/Users/igornepipenko/work/ai-codex-framework/ORCHESTRATOR_REFERENCE.md) and [routing.yaml](/Users/igornepipenko/work/ai-codex-framework/routing.yaml).

Current tier mapping:

| Tier | Model | Use |
|---|---|---|
| `low` | `codex-mini-latest` | mechanical edits, narrow single-file work |
| `medium` | `gpt-5.4` | normal implementation, review, tests |
| `high` | `gpt-5.4` | architecture, migrations, cross-system debugging |
| `xhigh` | `gpt-5.4` | rescue/recovery, framework redesign, ambiguous high-risk work |

Important policy decision:

- `medium` already uses the stronger main model
- the framework is intentionally biased away from cheap-but-weak defaults for normal work

## Orchestration Flow

At a high level the framework does this:

1. bootstrap project state if needed
2. load cached repo intelligence
3. refresh repo intelligence if fingerprint is stale
4. detect task intent
5. choose role from repo intelligence + task
6. choose tier/model
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
  progress block rendering
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

### Coordination state

- [scripts/handoff-state.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/handoff-state.sh)
- [scripts/retry-state.sh](/Users/igornepipenko/work/ai-codex-framework/scripts/retry-state.sh)

## Commands You Actually Use

### Start a normal framework session

```bash
codex
```

### Start task-first

```bash
codex --task "fix login timeout"
```

### Start issue/spec flow

```bash
codex -w 495
```

### Inspect readiness

```bash
codex-fw doctor
```

### Inspect repo intelligence

```bash
codex-fw intelligence .
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
- role/tier/skill planning
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
- chosen tier/model
- generated brief
- repo policy and conventions
- verification and quality output

That is the fastest way to see whether the framework is behaving like the engineering system you want.
