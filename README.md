# AI Codex Framework

A thin, native Codex extension layer for reusable engineering skills, project instructions, focused subagent profiles, native rules, and deterministic safety hooks.

## Native ownership

Codex owns planning, models, skill selection, approvals, sandboxing, worktrees, plugins, MCP, browser control, native agent messaging, and agent orchestration. This repository does not ship shell routers, prompt gates, context injection, model fallback chains, issue/PR wrappers, synthetic agent workflows, or local conversation-memory engines.

## Install

```bash
bash scripts/setup.sh
```

Start a new Codex session after installation. Codex discovers the installed skills and agents directly. A portable hooks plugin lives under `plugins/ai-codex-framework`; the default setup installs only the intentionally minimal universal core.

The installer uses the canonical native USER skill location, `~/.agents/skills`, and records only the skill, profile, rule, binary, and framework links it creates. It migrates old namespaced `~/.codex/skills/codex-framework-*` links after a zero-write collision preflight. User-owned files, unrecorded same-target symlinks, symlinked legacy namespaces, and replaced managed links are never adopted, overwritten, or traversed.

Install opt-in domain packs explicitly:

```bash
bash scripts/setup.sh --pack frontend --pack fullstack
```

Available pack names are discovered from `skills/packs/*.txt`; current domains include `engineering`, `frontend`, `backend`, `fullstack`, `mobile`, `ai`, `automation`, `infra`, and `product`. Every non-core local skill has exactly one owning pack and is not loaded globally by default.

To add the framework to a project without overwriting its existing instructions:

```bash
bash scripts/bootstrap-project.sh /path/to/project
```

This creates `AGENTS.md`, project-scoped profiles in `.codex/agents/`, native safety rules, the thin hook config, and `.codex/skill-packs.txt`. Add one pack name per line, then run:

```bash
bash scripts/framework-skill-sync.sh /path/to/project
```

Project packs become direct native REPO skills under `.agents/skills`. Framework ownership is stored outside the worktree in Git metadata, so team-owned skills can coexist and collisions fail before any write.

`setup.sh` also installs the framework's global working agreement at `~/.codex/AGENTS.md` when that path is absent or already points to this framework. It applies visible planning and truthful agent/model status across repositories; any existing personal file or symlink is preserved. Restart or start a new Codex task after installation.

## Native agent profiles

| Profile | Mode | Use |
|---|---|---|
| `explorer` | built in, read-only | evidence gathering and codebase mapping |
| `worker` | built in | narrow implementation ownership |
| `architect` | custom, high reasoning, read-only | shared contracts, migrations, and tradeoffs |
| `reviewer` | custom, high reasoning, read-only | correctness, security, and regression review |
| `tester` | custom, high reasoning | executable verification |

Keep parallel work read-heavy by default. Give each parallel writer a separate worktree and an explicit ownership boundary. The parent owns contracts and integration. Custom profiles inherit the current native model catalog, avoiding stale model pins after Codex releases.

## Observable native workflow

For a task with multiple files, a shared contract, or non-trivial risk, Codex must create a native plan before substantive tool work and keep it visible through short progress updates. Those updates state the outcome, next steps, and which real sub-agents are active.

For deep audits, cross-system incidents, and independent read-heavy investigations, the parent delegates only separable work that improves the time to a sound decision. It announces an agent only after native delegation has actually started as `profile — model / effort — bounded responsibility`, and reports the result when it returns. It identifies a material skill as a skill, not as an agent: skills have no model. Profiles are available capabilities, not automatically running agents. This restores accountability without reintroducing shell-created plans, fake status feeds, or lifecycle hooks.

High-risk changes get one native falsification-review pass after implementation and normal checks. A read-only `reviewer` tries to disprove the result using the request, diff, affected paths, and verification evidence. The parent accepts only substantiated findings, makes any warranted revision, and reruns affected checks. Routine low-risk work skips the pass, and the contract forbids recursive debate loops, keeping the quality gain bounded in latency and token cost.

## Skills and integrations

Skills are a maintained local library, not a blanket prompt payload. `scripts/setup.sh` installs the curated universal core from `skills/core.txt`; `skills/packs/*.txt` provide explicit domain sets. Prefer native Browser, GitHub, Figma, and product integrations over wrappers. Use Browser DOM, console, and network evidence before screenshots. Add MCP servers only for external context that Codex does not already provide.

Codex initially exposes only skill name, description, and path. That metadata catalog is bounded by the native context budget; the complete selected `SKILL.md` is loaded after selection, and routed references are read only when the skill requires them. Installing all 155 skills globally would reduce routing efficiency, so the default core remains one skill and domain packs stay project-scoped.

The corpus lifecycle, consolidation map, routing rules, and quality gates are documented in `docs/skills-governance.md`. Trusted community candidates are pinned to immutable upstream commits in `skills/community-pilot.tsv`; they remain opt-in until license, safety, routing, and representative-task evaluation pass. Use `bash scripts/community-skill-pilot.sh list` or read `docs/community-skills.md`.

## Native runtime features

Use Codex memories for cross-thread recall and multi-agent V2 for current subagent routing. Keep Auto-review enabled at the user layer. Fast mode remains an explicit per-task choice because it trades additional credits for latency.

Dynamic workflows remain native compositions: goal and plan for state, skills for repeatable method, subagents for bounded parallel work, rules and hooks for deterministic enforcement, plugins/MCP for authorized data and actions, and Scheduled tasks for stable recurring execution. The framework does not add a workflow engine or prompt router.

Project safety uses native `.codex/rules/` for destructive command prefixes and a small hook for compound shell patterns that rules cannot express. Hook paths resolve from the repository or plugin root, so the configuration is portable.

The repository tracks its project `.codex/config.toml`, so a fresh checkout has the same concurrency and hook contract. The optional hooks plugin is a distribution alternative; do not enable it alongside an equivalent project hook configuration because matching hooks would run twice.

## Desktop / CLI parity

Both surfaces consume the same project instructions, config, profiles, skills, and deterministic hooks. The framework contains no surface-specific branch and injects no SessionStart context, which keeps startup tokens stable. Run `bash scripts/surface-parity-check.sh` after changing the runtime surface.

## Framework checks

```bash
bash scripts/framework-eval.sh
bash scripts/framework-drift-check.sh
bash scripts/surface-parity-check.sh
bash scripts/framework-skill-governance.sh
bash scripts/framework-version-drift-check.sh
bash scripts/framework-version-drift-check.sh --self-test
# Network-backed resolution from current distribution channels:
bash scripts/framework-version-drift-check.sh --live
bash scripts/framework-skill-sync.sh --check .
bash scripts/framework-doctor.sh
bash scripts/framework-skill-loader-live-eval.sh
bash scripts/framework-release.sh
${CODEX_HOME:-$HOME/.codex}/bin/codex-framework-stack-context project /path/to/project --format markdown
${CODEX_HOME:-$HOME/.codex}/bin/codex-framework-stack-context latest nextjs react nodejs --format markdown
SKILL_QUALITY_ARTIFACT_DIR=/tmp/skill-quality bash scripts/framework-skill-routing-live-eval.sh --skill nextjs-development
# Strict per-skill semantic evaluation (after a routing artifact exists):
python3 scripts/framework-skill-quality.py semantic-live --skill nextjs-development --artifact-dir /tmp/skill-quality --routing-artifact /tmp/skill-quality/routing-nextjs-development.json
python3 scripts/framework-skill-quality.py certify --skill nextjs-development --artifact-dir /tmp/skill-quality
bash scripts/framework-health.sh
# Optional model-backed routing regression check:
bash scripts/framework-live-eval.sh
```

`framework-health.sh` validates source and is safe for CI. `framework-doctor.sh` layers effective-install checks over native `codex doctor`, including canonical skills, ownership state, profiles, rules, hooks, prompt metadata, project packs, and release-evidence freshness. `framework-skill-loader-live-eval.sh` uses an ephemeral native `codex exec` to prove initial-turn discovery, end-of-file visibility, required-reference loading, and an observable tool trace without the forbidden reference. It does not claim to force native auto-compaction: that boundary has no stable non-interactive trigger in the pinned CLI and must not be represented by a simulated local workflow. `framework-release.sh` combines the gates and writes the compact, artifact-digest-bound verdict in `docs/framework-release-evidence.json`; raw model transcripts remain ephemeral. Evidence expires after seven days and whenever the source digest or active Codex CLI version changes.

The deterministic checks validate native configuration, profile boundaries, plugin packaging, surface parity, wrapper removal, hook safety, skill ownership/review metadata, exact core/pack coverage, reachable references, unsafe cleanup recipes, dynamic release resolvers, numeric bootstrap pins, and a digest-bound contract for every skill. Quality is conjunctive across ten dimensions; there is no keyword average. Model-backed routing uses three fresh batched trials against the complete installable catalog, and semantic certification uses a solver plus an independent hidden-criteria judge. See `docs/version-currency.md` and `docs/skill-quality-standard.md`.
