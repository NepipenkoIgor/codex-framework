# Native capability review mechanism

This mechanism prevents framework maintenance from preserving custom behavior after Codex has gained an authoritative native replacement. It is deliberately scoped to audits, reviews, improvements, consolidation, and releases of this framework; ordinary application tasks do not load or refresh the ledger.

## Required cycle

1. Read the current official Codex manual, the complete changelog delta after the ledger's `changelogReviewedThrough` date, and the latest stable release notes. The installed CLI is runtime evidence, not a substitute for documentation.
2. Compare every relevant native delta with framework instructions, profiles, hooks, rules, scripts, skills, plugins, MCP configuration, and setup behavior.
3. Record one decision per capability: `adopted`, `replaced`, `removed`, `retained`, or `permission-gated`. A retained local mechanism requires a concrete native gap. A permission-gated feature must preserve consent, trust, sign-in, approval, or regional boundaries.
4. When implementation is authorized, apply safe in-scope removal or replacement during the same task and update tests/documentation. For an explicitly read-only, audit-only, or plan-only request, make no mutation and leave certification pending with an exact implementation plan.
5. Update `docs/native-capability-ledger.json` with the active Codex version, baseline and latest stable tags, every stable release after the baseline, each release's mapped capability decisions, the changelog boundary, SHA-256 fingerprints of normalized documentation main content and the stable release snapshot, action, and existing repository evidence. A content fingerprint change is a review trigger even when the release tag does not change.
6. Run the static check during iteration and the live check before release:

```bash
python3 scripts/framework-native-capability-check.py
python3 scripts/framework-native-capability-check.py --self-test
python3 scripts/framework-native-capability-check.py --live
```

The static gate rejects a review older than seven days, a CLI mismatch, missing official source types, unsupported decisions, duplicate capability/release IDs, unmapped releases, and missing/external evidence. The live gate additionally fetches the official Codex manual and full changelog, fails when the changelog contains a later dated entry than the ledger boundary, compares the ledger with the latest stable `openai/codex` GitHub release, enumerates every non-prerelease GitHub release between the baseline and latest tag, and fails when recorded release coverage is incomplete or provider/network evidence is unavailable.

The ledger is durable governance evidence, not startup context, a prompt router, or a workflow engine. Release evidence binds it through the repository source digest and a dedicated live gate receipt.

## Current reviewed delta

The 2026-09-12 review covers every stable release after `rust-v0.149.0` through `rust-v0.154.0` and the changelog through 2026-09-11:

- `0.149.1`: the stable release notes contain no framework-relevant behavior beyond the comparison link. `0.150.1` retained-image accounting in compaction/token budgets stays runtime-owned.
- `0.150.0`: task mentions/messaging, copy/title ergonomics, links, interrupt hooks, and compaction/multi-agent fixes are native; no task or hook lifecycle wrapper is retained.
- `0.151.0`: MCP discovery/result extensions, per-repository plugin catalogs, restored permissions, structured MCP errors, and root-goal subagent accounting are adopted or runtime-owned.
- `0.152.0` and `0.152.1`: per-tool MCP output limits are used only from measurement; planning and async-question tools are availability-gated; cwd/permission/MCP/Guardian fixes remain native.
- `0.153.0`: native local/remote plugin marketplace lifecycle replaces the hooks-only duplicate; recaps, TUI history/reconnection, approval scoping, resume/fork compression fixes, and async questions remain native. Experimental context management stays disabled.
- `0.153.1` through `0.153.4`: the model catalog and Astra default remain native and repository profiles stay unpinned. A user-owned global model pin is reported as an external override, never silently rewritten.
- The 2026-09-08 iOS task mentions, side questions, starting-state selection, delegation/review/queue fixes, and plugin-skill deduplication require no framework wrapper.
- `0.154.0`: native managed worktrees, inline asynchronous questions, Astra catalog exposure, copied-response formatting, permission restoration, MCP OAuth/catalog refresh, startup trust hardening, and background runtime fixes remain native. Existing sessions now refresh plugin tools, skills, and hooks after external plugin changes; global `AGENTS.md` discovery remains run-scoped, so instruction edits require a new run rather than a framework reload wrapper.
- The 2026-09-09 changelog and stable release review changed all three official source fingerprints and advanced the active runtime to `0.154.0`; the ledger records that delta instead of treating source drift as a release-neutral refresh.
- The 2026-09-11 desktop update adds Pets quick chat and Windows Appshots. Both remain native, availability- and permission-gated interaction surfaces; they introduce no framework workflow, polling, context, or screenshot wrapper. The refreshed manual/changelog fingerprints are recorded even though the latest stable CLI remains `0.154.0`.

Token optimization follows the same native-first rule. Stable request compression, remote compaction, skill search, cached web search, prompt caching, MCP catalog caching, and provider usage events stay at native defaults. The framework may bound only its own persistent instructions, selected skill core, and retained tool output; `scripts/framework-token-budget-check.py` rejects regressions and separately labels native prompt input, raw logged output, per-response usage, and cumulative provider totals without creating a cache or compaction layer.

## 2026-09-14 implementation review

The current official manual, complete changelog interval from the ledger baseline, and stable release notes were reviewed in this task. Latest stable remains 0.154.0 and the latest dated changelog entry remains 2026-09-11; refreshed manual/changelog content fingerprints require renewed evidence, not an invented runtime upgrade. Keep native goal/task/worktree/automation and compaction ownership; remove lifecycle polling regex from safety hooks, retain measured native output limits, and use native non-interactive execution for isolated behavioral evaluation. Development links require explicit opt-in; effective source identity is distinct from release certification and loaded task instructions. No experimental context manager, task queue or memory injection is added.

Pre-merge live revalidation on 2026-09-14 found changed manual/changelog HTML fingerprints. The current manual redirects to the ChatGPT Learn overview and the changelog still ends at 2026-09-11. Reviewed current overview and September entries: Pets, Appshots, source-file access, reusable native input, iOS task mentions, async answers and worktree setup remain native; no added wrapper or capability migration is required. Refreshed fingerprints record the current official source bytes; the CLI remains 0.154.0.

Final 2026-09-14 revalidation: the manual main content is unchanged despite new HTML bytes. The current [changelog](https://learn.chatgpt.com/docs/changelog) now includes historical CLI release details, including the already-reviewed 0.154.0 release, Python SDK 0.154.0 and CI-only Cygwin build/source artifacts. The latest dated boundary remains 2026-09-11 and the stable CLI release fingerprint is unchanged. Local searches found no SDK ExternalMessage/HookMetadata/history-selector integration or Cygwin voice build code. Retain native CLI operation; external SDK messages do not grant user authority, returned history selection is not model-context selection, and late-attached event streams can be partial. No SDK transport, transcript replay or voice toolchain is added. Both deltas and current source fingerprints are recorded in the ledger.

## 2026-09-16 implementation delta

Ledger schema 3 fingerprints documentation main content (text, semantic block boundaries and link/image destinations) instead of deployment-specific HTML/assets. Changes to meaningful content or links still invalidate review; a missing main element fails closed. Script/style/site chrome changes alone no longer cause false release drift. The complete stable interval after 0.149.0 still contains twelve releases ending at 0.154.0. September14 adds the GPT-5.5 October14 retirement notice; active framework profiles remain unpinned and no automatic user model migration is performed.

Remove the shell command parser and hook installer, the branch-name ban and prompt-level lifecycle/wait quotas. Use native approvals, worktrees and attached waits. Add automatic evidence-based tester/developer challenge through native profiles and global guidance, with no scheduler, replay, memory injection or agent-spawn wrapper. Default installation makes a durable independent release clone; temporary task worktree cleanup cannot break it. Policy lint explicitly does not certify runtime reviewer independence. New behavior evidence remains separate from the unchanged skill-corpus attestations.

## 2026-09-18 implementation delta

The release review first covered Codex CLI `0.155.0` and the complete stable interval after the ledger baseline including the Python SDK `python-v0.154.0` release family. Experimental voice remains permission-gated. Native task hide/archive/delete and managed-worktree ownership are adopted through task ergonomics; Touch ID MCP verification, daemon update/recovery, and Bedrock credential commands remain native, target-scoped, and permission-gated. The framework does not add credential caching, provider Browser fallback, or downloaded-file substitution.

The same-day refresh covers `rust-v0.155.1`, whose provider-compatibility fix restores disabled reasoning summaries as the native default for new local TUI sessions while preserving explicit settings. The framework keeps that behavior runtime-owned and adds no provider or reasoning-summary router. The former manual overview URL now redirects; the recorded canonical source is the current official CLI manual. A final live refresh found the official changelog's new dated `2026-09-18` entry for that release and records its canonical main-content fingerprint. Goals, local memories, Computer Use/IAB, attached waits, approvals, and family-wide token diagnostics are now explicit native decisions with deterministic counterexamples rather than new wrappers.

The capability checker accepts the official `rust-v*` and `python-v*` stable release families and requires unique, chronological `publishedAt` coverage while still requiring the current and latest CLI runtime to match the `rust-v*` release. CI is pinned to `0.155.1`, so local currency evidence and deterministic runners validate the same runtime. Historical release-evidence receipts remain bound to the CLI version that generated them and are not rewritten as fresh certification.
