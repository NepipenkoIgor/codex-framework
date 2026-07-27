---
name: deployment-strategies
description: Design blue-green, canary, rolling, GitOps, feature-flag, or other rollout strategy with compatibility, observation, stop and rollback controls. Use when rollout design is requested; does not execute deployment.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 3.0
  argument-hint: "service/data change, traffic and tenant distribution, SLOs/business signals, capacity, migration and rollback constraints"
---

Design the deployment strategy for $ARGUMENTS.

Read repository/deployment instructions, installed platform/controller capabilities, release artifact model, topology/traffic, observability, data/schema/event/API compatibility, external dependencies and rollback history. Keep this skill read-only; use deployment-validation for an actual release.

Select the least complex strategy that isolates the demonstrated risk. Define stages by audience/tenant/region/instance/traffic as appropriate. Percentages, dwell, thresholds and rollback time come from volume, detection latency, statistical power, business cycles, capacity and harm—not fixed recipes. Low-volume systems may need synthetic transactions, longer observation, targeted cohorts or invariant-based gates because percentages yield too little evidence.

Sequence expand/contract data changes, backward/forward-compatible APIs/events, mixed-version workers and irreversible operations. Rollback code is unsafe if old code cannot read new data or external side effects cannot be reversed. Separate roll-forward, traffic rollback, config/flag rollback and data recovery.

Predefine artifact identity, owners/approvals, promotion/stop signals, missing-telemetry behavior, capacity/drain, provider failure and rollback/recovery. Never stage every file, push main or deploy as part of a design request.

Report strategy and alternatives, compatibility sequence, evidence-derived stages/signals, low-volume evidence plan, capacity/drain, migration/rollback/recovery, approvals and residual irreversible risk.

Read [references/full-guide.md](references/full-guide.md) only for a deployment-strategy-specific deep dive; routine design uses this main workflow alone.
