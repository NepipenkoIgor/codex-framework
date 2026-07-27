---
name: backend-debug
description: Reproduce, localize, and fix a concrete backend defect across API, job, persistence, concurrency, queue, provider, and deployed-runtime boundaries. Use when diagnosis plus a repository fix is requested; do not use for greenfield implementation or review without a defect.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 3.1
  argument-hint: "symptom/expected behavior, exact build/environment/actor/time, endpoint or job, logs and reproduction"
---

# Backend Debug

1. Capture expected versus observed behavior, exact build/runtime/environment, actor/tenant/resource, request/event identity, timestamps and data state. Reproduce through the caller-visible boundary when safe.
2. Correlate sanitized logs/traces/metrics with validation, auth, transaction/query, async/queue/retry and provider evidence. State hypotheses and falsifying observations; establish root cause before editing.
3. Generate stack context and use the deployed/pinned runtime, source maps/symbols/schema and provider contract that match the failing artifact.
4. Add a focused regression or explicit baseline and apply the smallest repository fix. Avoid cleanup or broad auth/retry/transaction changes.
5. Verify the exact reproduction plus invalid/auth/tenant, duplicate/concurrent, rollback, retry and timeout-after-effect paths relevant to the defect. Caller-visible and persisted/effect outcomes are proof; configuration or local command success is not.

Production mitigation requires explicit authority, exact target/build/traffic scope, reversible flag/rollback/config action, evidence preservation, owner, stop condition and recovery. Never clear shared data/caches, disable auth, redrive queues or mutate provider state broadly as incidental debugging.

Report reproduction and evidence, root cause, bounded fix, checks/results, deployed paths actually verified and residual provider/production risk.
