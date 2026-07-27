---
name: backend-architecture
description: Design read-only backend boundaries, contracts, data ownership, consistency, scaling, security, resilience, and migration for a concrete system. Use for cross-cutting design or material boundary change; route scoped code implementation to backend-implement.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.1
  argument-hint: "system/change, current stack, quality attributes, scale, data/consistency, compatibility and migration constraints"
---

# Backend Architecture

Read [the full pattern guide](references/full-guide.md) only for the selected platform or alternative. Stay read-only.

1. Map current request/event/job flows, data authority, auth/tenant boundaries, integrations, deployment units, SLOs, costs and operational pain from repository/runtime evidence.
2. Rank quality attributes and invariants before choosing topology or technology. Generate stack context for version-sensitive capability and preserve existing pins.
3. Define contracts, ownership, consistency, failure/partial-outage behavior, timeout/cancellation, concurrency/idempotency, backpressure, security and observability.
4. Compare the smallest viable boundary change with at least one simpler alternative; reject complexity with evidence.
5. Design mixed-version compatibility, incremental migration, data reconciliation, canary, rollback and removal of transitional paths.

Output current/proposed boundaries, evidence and assumptions, decision drivers/alternatives, API/event/data/auth contracts, capacity and failure model, migration/rollback, executable evaluation criteria and residual risk. Do not edit code, infrastructure, schemas or external systems.
