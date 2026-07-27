---
name: observability-design
description: Design logs, metrics, traces, alerts, dashboards and health signals around user journeys, privacy, cost and operational ownership. Use when observability architecture is the requested deliverable; not for implementing a known instrumentation change.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 3.0
  argument-hint: "topology and journeys, traffic/cardinality, data policy, installed telemetry stack, SLO/on-call and cost constraints"
---

Design observability for $ARGUMENTS.

Read instructions, manifests/lockfiles, topology/data flows, ingress/proxies, async boundaries, installed OTel/SDK/collector/backend, existing signals, privacy/retention policy, incidents and on-call ownership. Verify semantic conventions and APIs from installed package/schema/collector capabilities or matching official docs; current OpenTelemetry attributes evolve and remembered names are not authority. Before material mutation, resolve exact task-owned code/config/dashboard/alert targets, owner and write authority/permissions, plus effect-appropriate rollback/recovery.

Start from critical user/business journeys and questions. Define bounded event/metric/span schemas, provenance and owners. Accept inbound trace/correlation context only after parsing and trust-boundary validation; create a new context when invalid and never let caller-controlled IDs become authorization, log injection or unbounded indexed fields. Propagate across HTTP/RPC/messages/jobs with explicit links for fan-out and retries.

Minimize PII/secrets in logs, spans, metrics, baggage, exemplars, replay and dashboards. Hashing identifiers may remain personal/high-cardinality. Use bounded route/operation/status dimensions; keep raw IDs in access-controlled lookup only when policy permits. Estimate series/event/span volume and cost before rollout.

Sampling is an observation policy, not truth. Record head/tail/adaptive rules, biases, dropped data and estimation limits. Do not claim all errors/slow traces are retained unless the end-to-end collector/backend configuration proves it. Retention and alert/escalation thresholds derive from legal/support/SLO/volume/cost and response ownership—not fixed days or minutes.

Health/readiness semantics are local workload contracts. Liveness avoids fragile dependencies; readiness reflects ability to serve this workload and may distinguish critical from optional dependencies. Do not mandate public unauthenticated detailed endpoints or a universal dependency tree.

Define SLIs at caller-visible boundaries, missing-telemetry behavior, alert action/owner/runbook, dashboards for diagnosis and instrumentation health. Validate correlation at ingress/async hops, redaction, cardinality/volume, sampling accounting, collector outage/backpressure, readiness/drain and alert delivery.

Report topology/journeys, schemas, trust/privacy boundaries, cardinality/cost, sampling truth, SLI/alerts/owners, health contracts, installed version evidence, validation and residual blind spots.
