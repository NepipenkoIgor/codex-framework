---
name: threat-modeling
description: Model design-time assets, actors, trust boundaries, data flows, attacker capabilities, abuse cases, mitigations, and residual risk. Use when the requested deliverable is a threat model; use security-audit for evidence-backed exploit review of implemented code.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.0
  argument-hint: "system/change, actors, assets/data classifications, deployment/data flows, trust assumptions and attacker goals"
---

Produce a read-only threat model for $ARGUMENTS.

## Establish the design

Read repository instructions, architecture/specs, entry points, identities/roles, data classifications, deployment/network topology, external dependencies, administrative/support/recovery flows and relevant implementation evidence. Inspect pinned platform/provider capabilities and matching official documentation when a control is version-sensitive; record unavailable controls and migration assumptions instead of remembering current behavior. State scope, security objectives, assumptions, unknowns and out-of-scope systems. Do not modify code or claim an exploitable defect; route source-to-sink vulnerability auditing to `security-audit`.

Model assets and consequences before controls: customer/business data, credentials/keys, money/actions, availability, integrity, privacy, tenant separation, audit evidence and supply chain. Draw or describe data flows across processes/stores/actors and mark trust boundaries, privilege transitions, authentication/authorization decisions, persistence, external calls and recovery paths.

## Enumerate abuse paths

Define realistic attacker capabilities and goals. Walk each flow and lifecycle state for spoofing, tampering, repudiation, disclosure, denial and privilege escalation as useful prompts—not a substitute for reasoning. Include cross-tenant access, confused deputy, replay, race/TOCTOU, duplicate delivery, resource exhaustion, poisoned input/content, compromised dependency/provider, insider/admin/support misuse, account/device recovery, backup/restore, deletion/retention and degraded dependencies where relevant.

Trace multi-step abuse paths with prerequisites, assets, trust-boundary crossings, existing controls, detection/recovery and impact. Rank with stated likelihood, impact and confidence in this deployment; do not derive severity from taxonomy labels.

Choose preventive, detective, response and recovery controls at the design boundary. Assign owners only when known and translate important threats into testable negative acceptance criteria, telemetry/alerting, rollout and residual-risk decisions. Controls must identify where they execute and which trusted identity/data they use.

## Output

Report scope/assumptions, actors/assets, data-flow diagram or structured flows, trust boundaries, attacker capabilities, abuse cases/paths, existing and proposed controls, priority/confidence, verification tasks, owners/decision gaps and residual risks. Name focused-test, affected-test, type-check and build categories when the repository fixture supplies them; exact command names come from the manifest, no package manager is invented, and unexecuted checks are labeled. Label repository evidence versus hypothesis and link model revisions to architecture changes or incidents.
