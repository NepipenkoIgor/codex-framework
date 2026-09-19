---
name: feature-flags
description: Implement feature-flag evaluation, rollout, kill-switch, stale-client, observability, and cleanup behavior with stable server-authoritative identity and snapshot semantics. Use when repository flag changes are requested; do not use for causal experiment design or inference.
metadata:
  owner: codex-framework
  reviewed: "2026-09-19"
  version: 2.3
  argument-hint: "flag purpose/owner, evaluation identities and attributes, server/client surfaces, rollout/kill-switch/staleness/cleanup"
---

# Feature Flags

1. Read instructions, manifests/lockfiles, installed flag provider/SDK, bootstrap/cache path, auth/tenant model, server and client evaluation surfaces, telemetry and tests. Preserve pins and verify APIs from installed types/config and matching official docs. Keep required discovery separate from completed evidence: never state that a surface was inspected unless task or tool evidence establishes that exact inspection; otherwise mark it pending.
2. Define flag type: release, operational kill switch, permission/entitlement bridge, migration or experiment exposure. Route experiment assignment, power and causal inference to the experiment skill; a flag result is not causal evidence.
3. Record owner, purpose, default and unavailable behavior, evaluation identity/attributes, creation and removal criteria, dependencies and audit sensitivity.

## Evaluation contract

- Derive actor/tenant/resource context from server-validated identity and current authorization. Never trust client-supplied targeting identity or let a UI flag grant server permissions.
- Evaluate related decisions from one explicit snapshot/version per request, job or workflow transition when consistency matters. Define whether long-lived clients keep a snapshot, refresh, or reconnect.
- Keep bucketing stable across devices/services using a documented canonical subject/key and algorithm when provider interoperability requires it; do not invent percentage semantics.
- Kill switches require a safe cached/default state, fast revocation propagation, privileged audited mutation, observability, runbook and tested recovery. “Off” is not automatically safe.
- Handle provider timeout/outage, stale caches, offline clients, renamed/deleted flags, schema/version mismatches and server/client disagreement explicitly.
- Remove temporary branches, tests, configuration and telemetry after rollout/migration acceptance; flags without owner/expiry become permanent hidden states.

## Verification

Completion requires separate executable evidence for every applicable item in this list: identity/tenant isolation, stable rollout assignment, single-snapshot consistency, a concurrent flag-configuration change during evaluation, provider outage, stale/offline client, revocation/kill switch, unauthorized flag mutation, default behavior, dependency cycles, cleanup and both branches. Design prose is not test evidence. Verify server authority for protected actions.

Report flag contract/owner, evaluation and snapshot identities, default/failure/staleness semantics, rollout/kill-switch/rollback, exposure telemetry boundary, cleanup trigger, checks/results and residual client risk.
