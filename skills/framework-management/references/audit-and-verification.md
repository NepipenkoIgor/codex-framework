# Framework audit and verification

Read this reference for audits, consolidation, material corpus/config changes, and releases.

## Audit scoring

Score each dimension 1–10 with concrete file or executable evidence:

1. Native ownership: no wrappers around planning, goals, git/GitHub, Browser, plugins, MCP, memory, or agent lifecycle.
2. Routing: precise distinguishable descriptions with positive and negative cases.
3. Skill design: small progressive core, repo-first decisions, no textbook dumps.
4. Coordination: bounded delegation, parent-held contracts, isolated parallel writers.
5. Verification: only checks authorized by the affected target—structural, semantic, safety, reference, profile, staleness, routing, native canary, source digest, or release evidence.
6. Runtime safety: exact targets, task-owned cleanup, approvals preserved, no broad destructive recipes.
7. Maintainability: owner, review date, upstream provenance, deprecation/replacement paths.
8. Token efficiency: minimal always-on instructions, routed skill detail, bounded tool output, native cache/compaction ownership, and provider/native evidence instead of inferred savings.

Report strengths, evidence-backed gaps, priorities, checks, and residual risk. Structural success is not semantic quality.

Falsify native ownership and execution safety: reject prompt/shell wrappers for native state, parallel writers without worktrees, remembered release resolution, preview channels represented as stable, and cache/compaction wrappers represented as optimization. Preserve existing manifest/lockfile pins unless migration is explicitly authorized.

## Verification routing

Resolve commands from the inspected checkout. In this repository, run only applicable tracked checks after meaningful changes:

```bash
python3 scripts/framework-native-capability-check.py --live
python3 scripts/framework-token-budget-check.py --live
bash scripts/framework-skill-governance.sh
bash scripts/framework-version-drift-check.sh
bash scripts/framework-eval.sh
bash scripts/framework-drift-check.sh
bash scripts/surface-parity-check.sh
bash scripts/framework-health.sh
bash scripts/framework-doctor.sh
bash scripts/framework-skill-loader-live-eval.sh
bash scripts/framework-release.sh
```

Use `scripts/framework-live-eval.sh` when routing, profiles, or agent ownership changes and live model use is acceptable. Use `scripts/framework-skill-routing-live-eval.sh` after descriptions, core/packs, consolidation, or retirement mappings change.

Before version-sensitive guidance, run `${CODEX_HOME:-$HOME/.codex}/bin/codex-framework-stack-context project <path>` or the inspected repository's equivalent. Run live resolvers after source changes without persisting remembered snapshots.

For install/update collision handling, use a task-owned fixture that attempts a collision and prove the existing user file remains byte-identical with zero writes.
