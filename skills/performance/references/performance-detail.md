# Performance investigation detail

Load this reference only after the main workflow has measured and localized a deeper platform-specific bottleneck. Preserve installed versions and verify tool/API syntax from the local runtime or matching official documentation.

## Browser and frontend

- Capture a representative production-like trace with build mode, device/CPU/network profile, cache state and navigation path recorded. Redact URLs, headers, payloads and identifiers before retaining or sharing artifacts.
- Attribute LCP, INP, CLS and startup time to network, server response, resource discovery/priority, main-thread work, rendering and layout. Do not select a preload, prefetch, lazy-load, memoization or change-detection fix from the metric name alone.
- Use bundle output from the installed builder to distinguish transferred, parsed/executed and duplicated code. Verify route/client/server boundaries before moving imports.
- For memory, compare equivalent heap/allocation snapshots around a repeatable lifecycle and prove retained ownership. A growing heap during warmup is not automatically a leak.
- Confirm framework capability from the installed router/compiler/runtime. In particular, do not assume a Next.js preload/prefetch API or that Angular `OnPush` improves the profiled path.

## Backend and data

- Split latency across queueing, application CPU, GC, database, cache, network/provider and serialization. Use distributions and concurrency representative of the service objective.
- Review query plans with realistic parameters and cardinality. Index or query changes must include write amplification, storage, locking, rollout and rollback.
- For concurrency, identify downstream capacity, connection pools, rate limits, backpressure, cancellation and retry amplification before increasing parallelism.
- For caching, define tenant/auth key isolation, freshness, invalidation, capacity/eviction, stampede handling and outage behavior. Measure hit distribution and stale-result risk.

## Measurement quality

- Compare like-for-like builds, hardware, data, load, cache state and telemetry overhead.
- Use multiple runs or sufficient request samples and report median/tail behavior plus variation; avoid a single best run.
- Check correctness, error/timeout rate, memory, CPU, network and cost alongside the target metric.
- Preserve a reproducible benchmark or trace recipe and label any extrapolation to production.

## Artifact safety

Collect the minimum data required. Prefer synthetic or approved sanitized workloads. Restrict artifact access and retention, strip secrets and PII, and clean task-owned profiler sessions or temporary captures after verification.
