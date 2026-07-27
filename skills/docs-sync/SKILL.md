---
name: docs-sync
description: Synchronize repository documentation, generated API artifacts, examples, diagrams, setup guides, and migration history with authoritative implementation sources. Use when documentation sync or creation is requested; not as a substitute for changing the underlying contract.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.0
  argument-hint: "changed behavior/files, requested docs, authoritative source/generator, audiences and migration compatibility"
---

Synchronize documentation for $ARGUMENTS.

## Find the source of truth

Read instructions, requested change/diff, existing docs structure, generators and checked-in generated artifacts, API/schema/config/CLI sources, tests and release/migration conventions. Before mutation, resolve the exact authoritative source files and generated/documentation targets, ownership and write authority, then preserve a clean regeneration or reversible diff as the rollback path. Determine for each fact whether authority is code annotations, schema/IDL, configuration, generated output, a manual spec or an external system. Do not hand-edit a generated artifact when its source and regeneration path exist; update the authoritative source and regenerate with the repository command.

If the user asks to create missing documentation, create it in the repository's established location and style. If creation was not requested and the task is audit-only, report the gap. Do not expand a focused sync into a giant README, universal API cookbook or new documentation system.

## Synchronize current and historical truth

- Update only affected current contracts: endpoints, schemas, auth/permissions, errors, defaults, examples, configuration, commands, data flows and operational behavior.
- Validate examples against the implementation/schema and use placeholders rather than secrets or environment-specific values.
- For a removed endpoint, remove it from the authoritative current API specification when it is no longer served. Preserve deprecation/removal rationale, dates/versions and migration guidance in changelog, migration or versioned historical docs according to repository policy. Do not keep a dead endpoint in the current spec merely as history, and do not erase migration history.
- For generated clients/specs, record generator/tool version from installed manifests/locks and verify a clean regeneration. Treat generator upgrades separately.
- Keep diagrams small and grounded in actual components/flows; update or create them only when useful to the requested audience.

Existing pins and commands remain authority. Verify version-specific syntax locally or in matching official docs. For greenfield examples, use `scripts/framework-stack-context.py` rather than remembered current majors.

## Verification and output

Run the authoritative generator and docs lint/link/schema/example checks, inspect generated diffs for unrelated churn, and compare documented behavior with focused implementation/tests. Report source-of-truth mapping, docs created/updated/removed, generated provenance, current-spec versus migration-history handling, commands/results, and facts still blocked on external or unverified behavior.
