---
name: load-testing
description: Design and run authorized load, stress, spike, soak, and capacity tests with representative traffic, tail-latency correctness, system telemetry, abort controls, isolated data, and cleanup. Use when concurrency/throughput must be measured; do not target third parties or production without explicit authority.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 1.5
  argument-hint: "authorized target/window/ceiling, workload and SLOs, dependencies/data/cleanup, abort contacts and telemetry"
---

# Load Testing

1. Resolve exact target owner/environment/build, explicit authorization, traffic/data ceiling, window, contacts, dependency/provider allowances, abort conditions and cleanup responsibility before generating load. Production/third-party testing requires explicit scope.
2. Inspect pinned tool, topology, SLOs, real traffic distributions and cardinality, autoscaling, caches, queues, dependencies and telemetry. Preserve tool/runtime pins and verify APIs from installed capability and matching official documentation. For explicitly authorized greenfield harness creation only, resolve stable/LTS runtime/tool releases from official sources, verify cross-stack compatibility, generate manifest/lockfile and make them authoritative.
3. Model weighted journeys, arrival/concurrency/think-time distributions, auth/session/data uniqueness and success assertions. Validate correctness at low load before ramping gradually; do not copy fixed VU, duration or percentile thresholds.
4. Monitor generator and every system/dependency layer while running. Abort automatically on correctness, error, saturation, cost or safety thresholds. Treat generator or uncontrolled dependency saturation as an invalid capacity result.
5. Avoid coordinated omission: use an arrival model or corrected measurements appropriate to the workload and include queue/wait time. Report p50/p90/p95/p99/max or approved tails with counts, errors, throughput, saturation and variance across repeated steady-state runs.
6. Tag synthetic task-owned data, avoid real PII, isolate external providers, clean up and verify cleanup even after abort. Preserve raw results/config/build/telemetry for reproducibility.

Test ramp, steady, recovery and relevant spike/soak behavior; distinguish cold/warm state. Correlate bottlenecks rather than inferring from latency alone.

Report authorization/target/build, workload/data model, ramp/abort/cleanup, tool/generator capacity, repeated distributions and coordinated-omission handling, system telemetry, bottleneck evidence, uncertainty and residual risk.
