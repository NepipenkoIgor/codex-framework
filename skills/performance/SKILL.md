---
name: performance
description: Diagnose and optimize measured end-to-end frontend, backend, network, memory, startup, and build performance without changing correctness or privacy. Use when measured application performance is primary; route database query/index design and AI operating-cost estimation to their dedicated skills.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.0
  argument-hint: "user-visible symptom/SLO, workload, environment/build, baseline traces, suspected component and constraints"
---

Analyze and optimize $ARGUMENTS.

## Measure before changing

Read instructions, manifests/lockfiles, architecture and critical path, existing telemetry/profiles/benchmarks, production environment and tests. Define the user-visible outcome or service objective, representative workload, data volume, concurrency, device/network/build mode, warm/cold state and measurement method. Capture repeatable baseline distributions and resource/cost data before selecting a fix.

Profiles and traces may contain URLs, queries, headers, identifiers, payloads, source maps and customer data. Minimize collection, use approved environments, redact/tokenize sensitive values, restrict access/retention and never attach raw PII/secrets to issues or benchmark artifacts.

## Localize the bottleneck

Trace the critical path across client rendering/network, server queues/runtime, database/cache, provider calls, filesystem, memory/GC and deployment limits. Distinguish latency, throughput, responsiveness, memory, startup, bundle and cost. Falsify hypotheses with flamegraphs, query plans, browser/server traces, allocation data or controlled experiments.

Before material mutation, resolve the owning component/team and write authority and define a reversible change or configuration rollback tied to regression criteria. Then optimize the measured constraint with the smallest safe change. Preserve correctness, authorization, consistency, accessibility, failure behavior and observability. Do not apply memoization, virtualization, caching, concurrency, indexes, compression, preload/prefetch or architecture changes by default.

Framework patterns are capability-sensitive:

- Verify the installed Next.js router/version and generated output before adding a preload, prefetch, image/script or server/client optimization; support and semantics differ by component/router/runtime.
- Angular `OnPush` is not a universal optimization. Use the installed change-detection/signals model and profile actual update paths; preserve input mutation and async behavior.
- Cache only with defined key isolation, freshness, invalidation, bounds and failure behavior. Parallelism requires backpressure and downstream capacity.
- Database indexes require representative plans, write/storage cost and deployment/rollback analysis.

Preserve installed pins and verify profiler/framework syntax from local tooling or matching official docs. Check applicable runtime engine requirements, peer dependencies, compiler/framework, adapters, test runner and deployment compatibility as one unit before selecting a version-sensitive technique. For greenfield stacks, use `scripts/framework-stack-context.py`.

## Verification and output

Repeat equivalent before/after measurements with uncertainty or run-to-run variation, inspect regressions in correctness, memory, cost and tail behavior, then run focused and affected tests/build checks. Prefer caller-visible p50/p95/p99 or appropriate distributions over one best run. Clean task-owned profiling sessions and sanitize retained artifacts.

Report workload/environment, baseline, evidence locating the cause, change, before/after distributions, correctness/resource tradeoffs, actual checks, rollback evidence and explicit residual production-scale uncertainty even when local or staging measurements improve.

Read [references/performance-detail.md](references/performance-detail.md) only when measurement identifies a deeper platform-specific profiling, bundle, memory-leak or Core Web Vitals investigation; routine diagnosis should use this main workflow alone. When asked which optional references a routine task needs, answer exactly `No optional reference files must be loaded.` without naming an unused path.
