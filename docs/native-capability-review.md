# Native capability review mechanism

This mechanism prevents framework maintenance from preserving custom behavior after Codex has gained an authoritative native replacement. It is deliberately scoped to audits, reviews, improvements, consolidation, and releases of this framework; ordinary application tasks do not load or refresh the ledger.

## Required cycle

1. Read the current official Codex manual, the complete changelog delta after the ledger's `changelogReviewedThrough` date, and the latest stable release notes. The installed CLI is runtime evidence, not a substitute for documentation.
2. Compare every relevant native delta with framework instructions, profiles, hooks, rules, scripts, skills, plugins, MCP configuration, and setup behavior.
3. Record one decision per capability: `adopted`, `replaced`, `removed`, `retained`, or `permission-gated`. A retained local mechanism requires a concrete native gap. A permission-gated feature must preserve consent, trust, sign-in, approval, or regional boundaries.
4. Apply safe in-scope removal or replacement during the same task. Update tests and documentation; do not stop at a recommendation when the cleanup is executable.
5. Update `docs/native-capability-ledger.json` with the active Codex version, latest stable tag, changelog boundary, SHA-256 fingerprints of all three fetched official sources, decision, action, and existing repository evidence. A content fingerprint change is a review trigger even when the release tag does not change.
6. Run the static check during iteration and the live check before release:

```bash
python3 scripts/framework-native-capability-check.py
python3 scripts/framework-native-capability-check.py --self-test
python3 scripts/framework-native-capability-check.py --live
```

The static gate rejects a review older than seven days, a CLI mismatch, missing official source types, unsupported decisions, duplicate capability IDs, and missing/external evidence. The live gate additionally fetches the official Codex manual and full changelog, fails when the changelog contains a later dated entry than the ledger boundary, confirms the active CLI appears in that changelog, compares the ledger with the latest stable `openai/codex` GitHub release, and fails on provider/network errors rather than silently accepting remembered data.

The ledger is durable governance evidence, not startup context, a prompt router, or a workflow engine. Release evidence binds it through the repository source digest and a dedicated live gate receipt.
