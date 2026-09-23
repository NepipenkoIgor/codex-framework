---
name: observability-design
description: Design logs, metrics, traces, alerts, dashboards and health signals around user journeys, privacy, cost and operational ownership. Use when observability architecture is the requested deliverable; not for implementing a known instrumentation change.
metadata:
  owner: codex-framework
  reviewed: "2026-09-19"
  version: 3.1
  argument-hint: "topology and journeys, traffic/cardinality, data policy, installed telemetry stack, SLO/on-call and cost constraints"
---

Design observability for $ARGUMENTS.

Read instructions, manifests/lockfiles, topology/data flows, ingress/proxies, async boundaries, installed OTel/SDK/collector/backend, existing signals, privacy/retention policy, incidents and on-call ownership. Keep required discovery separate from completed evidence: never claim a topology, flow or boundary was inspected unless task or tool evidence establishes that exact inspection; otherwise mark it pending. Verify semantic conventions and APIs from installed package/schema/collector capabilities or matching official docs; current OpenTelemetry attributes evolve and remembered names are not authority. Before material mutation, resolve exact task-owned code/config/dashboard/alert targets, owner and write authority/permissions, plus effect-appropriate rollback/recovery.

Start from critical user/business journeys and questions. Define bounded event/metric/span schemas, provenance and owners. Accept inbound trace/correlation context only after parsing and trust-boundary validation; create a new context when invalid and never let caller-controlled IDs become authorization, log injection or unbounded indexed fields. Propagate across HTTP/RPC/messages/jobs with explicit links for fan-out and retries.

Minimize PII/secrets in logs, spans, metrics, baggage, exemplars, replay and dashboards. Hashing identifiers may remain personal/high-cardinality. Use bounded route/operation/status dimensions; keep raw IDs in access-controlled lookup only when policy permits. Estimate series/event/span volume and cost before rollout.

Sampling is an observation policy, not truth. Record head/tail/adaptive rules, biases, dropped data and estimation limits. Do not claim all errors/slow traces are retained unless the end-to-end collector/backend configuration proves it. Retention and alert/escalation thresholds derive from legal/support/SLO/volume/cost and response ownership—not fixed days or minutes.

Health/readiness semantics are local workload contracts. Liveness avoids fragile dependencies; readiness reflects ability to serve this workload and may distinguish critical from optional dependencies. Do not mandate public unauthenticated detailed endpoints or a universal dependency tree.

Define SLIs at caller-visible boundaries, missing-telemetry behavior, alert action/owner/runbook, dashboards for diagnosis and instrumentation health. Validate correlation at ingress/async hops, redaction, cardinality/volume, sampling accounting, collector outage/backpressure, readiness/drain and alert delivery. Add an executable instrumentation-blind-spot case: deliberately suppress or drop one expected trace/metric/log/alert signal at a named boundary and prove the missing-telemetry health signal, sampling/drop accounting, or alert detects the absence without treating silence as success.
Where topology confirms an async hop, specify a safe valid correlation stimulus and the consumer parent/link assertion; for alerts, specify an isolated test trigger and evaluation, routing and intended-receiver receipt assertions. Execute either test only under separate authorization for its exact isolated targets; otherwise mark actual propagation and delivery unverified, not passed or inapplicable.
For each applicable validation, name a safe stimulus or fault, observed boundary or signal, falsifiable acceptance condition and execution status. Cover valid/forged ingress context, representative IDs/traffic against evidenced cardinality and volume bounds, forced sampling/export loss in accounting, collector outage/backpressure visibility, and critical/optional dependency plus drain readiness transitions; mark unknown topology, targets or thresholds pending rather than inventing a pass.

Report topology/journeys, schemas, trust/privacy boundaries, cardinality/cost, sampling truth, SLI/alerts/owners, health contracts, installed version evidence, validation including the missing-telemetry test, and residual blind spots.
