# Native Codex framework audit — 2026-08-11

This audit compares the framework at Codex CLI `0.147.0` with the current Codex manual and official changelog. Scores describe verified current behavior after the audit changes; they are not a permanent 10/10 claim.

## Outcome

| Dimension | Score | Current evidence | Remaining gap |
|---|---:|---|---|
| Native ownership | 9/10 | No local plan, goal, model router, browser/GitHub wrapper, memory injector, or agent lifecycle manager; undocumented depth override removed | Custom skill projection remains for direct REPO/USER skill discovery and IDE parity until plugin distribution covers the required surfaces |
| Routing | 9/10 | 155 reviewed structural contracts; fresh owner/full routing passed 1,290/1,290; plugin-qualified pilot canary passed 12/12; all sixteen packs remain below 7,000 description characters | Expand qualified plugin topology only after each bounded domain migration |
| Skill design | 9/10 | 155 focused skills, 46 routed references, one universal core skill, ten bounded domain fixture profiles, and two evidence-backed hardening cycles | Fixtures remain hypothetical contracts rather than executable representative repositories |
| Coordination | 9/10 | Native subagents, parent-owned contracts, read-heavy parallelism, isolated parallel writers, exactly one bounded high-risk review cycle | Native plan/goal/delegation behavior is instructed and partly classified, not fully exercised by one end-to-end canary |
| Verification | 8/10 | 43 deterministic checks, fresh routing 1,290/1,290, immutable semantic v25 at 151/155, post-fix targeted v26 at 4/4, current-digest validation of all 155 per-skill artifacts, and a passing framework release gate | The four post-v25 repairs have targeted evidence but no new same-run immutable 155/155 corpus certificate |
| Runtime safety | 9/10 | Native prefix rules, structurally matched hook contract, collision-safe install, normalized recursive-removal targets, ownership-blind Stop hook removed | The remaining shell tokenizer is intentionally conservative and still requires maintenance as shell syntax evolves |
| Maintainability | 9/10 | Dynamic stable/LTS resolvers, bounded packs, owner/review metadata, replacement map, current CLI pin, official repo plugin layout, and digest-bound evidence | Migrate another domain only after the pilot's full routing and cross-surface evidence pass |

Aggregate assessment after implementation: orchestration `9/10`, agents `9/10`, skills `9/10`, human-like task behavior `9/10`. The framework is strong and native-first. Its remaining quality risk is evidence consolidation: the last immutable corpus snapshot passed 151/155, and all four repaired failures passed targeted post-fix evaluation, but those results must not be combined into a fictional same-snapshot 155/155 certificate.

## Removed or corrected

- Removed `agents.max_depth`. Current documented agent settings expose enablement, concurrency, default model/effort, and interruption behavior; Codex owns subagent lifecycle and depth.
- Removed the forced `high` reasoning override from `tester`. `architect` and `reviewer` keep high effort because their tasks require judgment; routine verification inherits native task-aware selection.
- Removed the global `Stop` hook. It inspected unrelated worktree state, could attribute pre-existing whitespace drift to the current task, and did not satisfy the event-specific JSON output contract.
- Replaced the recursive-removal regex with option/target tokenization. It blocks `/`, normalized aliases such as `/./` and `/tmp/..`, actual or variable home targets, and `.git` across short, mixed, and long `--recursive --force` variants without confusing `.github` or task-owned absolute temporary paths with broad targets.
- Made hook installation parse TOML and verify that the exact script, matcher, command target, and timeout belong to the same hook table. Crossed or unrelated lifecycle hooks are no longer accepted as a successful framework install.
- Replaced the ineffective `codex --strict-config --help` check with an app-server parse that rejects an executable unknown-key counterexample.
- Replaced the all-catalog-implies-all-subsets routing assumption. Each case now runs against `core + owning pack` and the full catalog; an unavailable cross-pack neighbor must fail closed as `none`.
- Updated the CI runtime binding from Codex `0.146.1` to `0.147.0`.
- Declared the CI dependency on ripgrep and replaced the BSD-only fixture fingerprint with a portable archive digest.
- Reworded planning policy around coupled behavior, contracts, and risk rather than raw file count. A resolved failure no longer triggers high-risk review unless residual uncertainty remains.

## Release-by-release adoption review

The audit read the complete current [official Codex changelog](https://learn.chatgpt.com/docs/changelog) through the 2026-08-10 Daybreak access-tier entry and the latest stable 2026-08-07 CLI `0.147.0` release, not only the latest CLI entry.

This is now a permanent maintenance gate rather than a one-off audit. Every framework review, improvement, consolidation, and release must refresh the machine-readable `native-capability-ledger.json` from the official manual, changelog delta, and latest stable release; search local instructions, profiles, hooks, scripts, skills, plugins, and MCP configuration for overlap; record `adopted`, `replaced`, `removed`, `retained`, or `permission-gated`; and perform safe in-scope cleanup in the same task. Static health rejects stale or inconsistent evidence. Release also compares SHA-256 fingerprints of the live manual, changelog, and stable release snapshot, uses a year-agnostic changelog parser, checks the latest stable tag, and fails closed on an unreviewed content delta. See [native-capability-review.md](native-capability-review.md).

| Release period | Relevant native additions | Framework decision |
|---|---|---|
| February 2026 | Desktop tasks, parallel execution, worktrees, skills, Scheduled tasks, steering | Native plans/goals, worktrees, subagents, steering, and skills remain authoritative. Requested recurring work routes to Scheduled tasks instead of local pollers. |
| March 2026 | Handoff, schedules, terminal and early plugin workflows | Handoff and scheduling are selected for genuine long-running boundaries; no handoff files, terminal wrappers, or local workflow engine. |
| April 2026 | Browser, PR workflows, Memories, Auto-review | Visible Browser is now the default for runnable UI work; GitHub/native review and Memories own their domains. Auto-review remains an explicit user security choice. |
| May 2026 | Hooks, persisted Goal, Remote tasks, Computer Use | Goal is used for multi-step outcomes. Hooks are restricted to deterministic safety and cannot plan, route, retry, or manage agents. Remote/Computer Use remain permission-gated native surfaces. |
| June 2026 | Browser Developer mode, Record & Replay, improved handoff | DOM/console/network/runtime evidence is now part of the UI contract. Record & Replay is offered only after a user demonstrates a repetitive flow; availability and Computer Use approval cannot be forced. |
| July 2026 | Unified Work/Codex experience, multi-folder tasks, CLI threads/forks and plugins | Long tasks may use native names, pins, sections, handoff, and forks; repository and task boundaries stay native. Plugin migration is domain-bounded rather than all-at-once. |
| August 2026 | Portable plugins and catalogs, task sections, `--approve-for-me`, external-agent import, MCP 2026-07-28 | The repo marketplace and `codex-frontend-design` pilot use the portable plugin format. Sections are part of the task policy; approval review, imports, and MCP upgrades remain explicit capability or migration choices. |
| August 10, 2026 | Daybreak Blue and separately approved Daybreak Red security access tiers | Security skills may use an already approved native tier only inside the exact authorized engagement. Blue does not grant Red; restricted model selection, Trusted Access, workspace/API organization, project, and product-surface approval remain native gates. |

Automatic selection means “use an already installed and approved matching native capability.” It does not mean bypassing plugin trust/install, Browser site/CDP approval, sign-in, recording consent, Auto-review, or consequential connector permissions.

## Current native features and adoption

Codex `0.147.0` adds portable Agent Plugins and multi-source catalogs, automatic approval review through `--approve-for-me`, imported external-agent skills/conversation synchronization, and opt-in MCP 2026-07-28 support. See the [official Codex changelog](https://learn.chatgpt.com/docs/changelog#codex-2026-08-07) and [0.147.0 release](https://github.com/openai/codex/releases/tag/rust-v0.147.0).

Already used or deliberately delegated to native Codex:

- persisted goals and native plans;
- built-in `explorer` and `worker`, plus narrow project profiles;
- native subagent spawning, steering, waiting, and lifecycle;
- Browser, GitHub, plugins, MCP, memories, worktrees, approvals, and sandboxing;
- native rules plus one deterministic compound-command hook;
- canonical REPO and USER skill locations with progressive disclosure.

Underused but not safe to force globally:

1. Portable marketplace distribution. A repository marketplace and `codex-frontend-design` pilot now package seven design/accessibility skills. Root symlinks preserve direct REPO/IDE discovery while the pilot proves qualified plugin routing. Native install, trust, and new-task activation remain explicit user gates; enabling direct and plugin registration simultaneously would create duplicate identities.
2. Skill UI and dependency metadata. Every pilot plugin skill and `framework-management` now has `agents/openai.yaml`; add presentation metadata or MCP dependencies to later domains only where they change behavior.
3. Scheduled tasks and monitors. Use them for explicitly requested recurring or long-running follow-up instead of adding retry/polling scripts. They require the desktop host, permissions, and project availability.
4. Record & Replay. It can accelerate demonstrated repetitive workflows, but it is a user-visible Computer Use flow, not something repository setup should enable automatically.
5. Browser Developer mode. It improves DOM, console, network, runtime, and profiling evidence after explicit setting and site approval.
6. Native GitHub and `codex review`. Use them for routine review; retain the custom reviewer only for high-risk falsification.
7. Named, pinned, forked, and sectioned tasks. These improve long-running ergonomics without adding framework status machinery.

## Residual evidence gaps

- Backend and frontend are now split into bounded ownership packs; all sixteen packs remain below 7,000 description characters. Fresh owner/full routing passed 1,290/1,290 and the frontend-design qualified plugin canary passed 12/12. Another domain migration still requires its own qualified plugin and cross-surface evidence.
- The 428 fixture-backed scenarios now use ten domain profiles, with the largest profile below 35%. They remain hypothetical rather than executable repositories; add a small executable benchmark per pack, prioritizing auth, payments, migrations, deployment, LLM security, and UI.
- The final immutable v25 run produced 151/155. Its four P0/P1 failures were repaired and each passed a targeted v26 semantic run, but source changes invalidate the old full snapshot. Do not describe the current checkout as a fresh same-snapshot 155/155 or corpus-wide 10/10.
- The release gate no longer certifies only `framework-management`: it validates passing, current-digest semantic artifacts and raw evidence for the entire 155-skill corpus, then records aggregate skill and artifact digests. This aggregate closes changed-skill release coverage but does not rewrite the v25/v26 history into a single immutable model run.
- The skill pack synchronizer duplicates some installation lifecycle that portable plugins can now own, but immediate removal would lose direct repo/user skill discovery and IDE parity. Migrate by bounded domain plugin only after cross-surface and routing benchmarks.

## Independent falsification result

One read-only reviewer challenged the final diff and reproduced three actionable gaps: long-option and normalized-path `rm` bypasses, a 2026-only changelog parser with no official-content fingerprint, and release evidence limited to one skill. All three were fixed in the single permitted revision cycle. The affected hook counterexamples, native-capability self/live checks, 43-check health suite, full 155-artifact digest validation, and release gate passed afterward; no recursive reviewer loop was run.

## Desktop activation boundary

- Project `AGENTS.md` and symlink-projected skills are read for a new task; an already-running task is not hot-reload evidence.
- `.codex/config.toml`, profiles, and hooks should be validated in a new task, and a Desktop restart is the reliable boundary for application-level configuration changes.
- Source files and symlinked skills require no compilation. The `codex-frontend-design` plugin remains deliberately uninstalled in the main profile until direct-skill projections are migrated, because enabling both identities simultaneously would create duplicate routing.
