---
name: prompt-management
description: Implement prompt registries, immutable versioning, safe activation and rollback, compatibility checks, experiments, caching, retention, and observability. Use when repository changes to the prompt lifecycle are requested; use prompt-engineering to author a prompt and llm-evaluation to design evaluation.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.0
  argument-hint: "registry/storage, tenants and authorization, providers/models, schemas, rollout and retention requirements"
---

Implement prompt lifecycle infrastructure for $ARGUMENTS.

## Establish the contract

Read repository instructions, manifests, lockfiles, prompt call sites, schemas, authorization, storage, caching, experiments, telemetry, tests, and deployment topology. Preserve installed pins for existing projects and verify provider/framework capabilities against matching official documentation or local generated types. For greenfield work, use `scripts/framework-stack-context.py` to resolve stable/LTS components dynamically and let the manifest and lockfile become authority.

Define immutable prompt identity as a versioned snapshot of prompt layers, variable schema, output schema, tool contract, provider/model settings, locale, safety policy, and relevant feature configuration. Record who created, reviewed, activated, and rolled it back.

## Registry and activation

- Store immutable versions; never edit an active version in place.
- Resolve either an explicit snapshot or a single active pointer. Activation updates the pointer and its compatible configuration atomically, with concurrency control and an auditable transaction/event.
- Rollback selects a known compatible snapshot atomically. Preserve the failed version and evidence; do not infer rollback as “latest archived.”
- Make readers resilient to stale processes and partial outages. Define cache invalidation, propagation, read-after-write expectations, and behavior when registry/cache/provider is unavailable.
- Derive any automated refresh/poll/wait attempt and elapsed-time bounds from registry/cache/provider propagation evidence and operation deadlines; after exhaustion expose a durable unresolved state rather than inventing constants.
- Validate required variables before rendering and prevent untrusted input from being interpreted as template syntax or policy.

Compatibility covers variable and output schemas, callers, tools, model/provider capabilities, token/context limits, safety settings, locale, and deployment runtime. A provider or model change is a compatibility migration with evaluation, rollout, and rollback—not a text-only prompt revision.

## Authorization, privacy, and caching

Authorize administrative writes and runtime reads by actor, tenant, environment, prompt family, and operation. Do not trust a client-provided tenant, version, experiment, or cache key without server-side resolution.

Cache only when reuse semantics are defined. Keys must include every result-affecting boundary, such as tenant and authorization scope, locale, provider/model, immutable prompt and schema versions, feature/experiment state, and a safe digest of approved inputs. Never put raw secrets or PII in keys. A low temperature does not make output deterministic.

Choose expiry and invalidation from source freshness, privacy, revocation, and failure requirements; there is no universal TTL. Prefer versioned keys or indexed invalidation over unbounded production key scans. Define stampede protection, bounded waits, stale-value policy, and deletion propagation.

Apply PII, secret, access, regional, audit, and retention policy to prompt content, inputs, outputs, traces, caches, experiment assignments, eval datasets, and artifacts. Log stable identifiers and redacted metadata rather than raw sensitive payloads by default.

## Evaluation and rollout

- Gate activation on representative evaluation of the exact snapshot. Include schema compatibility, safety, injection, truncation, multilingual/locale, latency, cost, provider failures, and downstream action behavior.
- Assign experiments using a stable approved subject and include tenant/environment boundaries. Persist assignment and exposure before attributing outcomes.
- Choose sample size, metrics, guardrails, statistical method, and stopping rule from power, baseline variance, repeated/correlated observations, harm, and business decision—not fixed counts or a universal p-value.
- Never auto-promote solely because one metric reaches `p < .05`. Inspect practical effect, confidence interval, guardrails, slice harms, multiple comparisons, data quality, and operational readiness; require the configured approval policy.
- Canary progressively with explicit abort criteria, rollback, and monitoring by prompt/model/provider/schema version.

## Verification and output

Test concurrent activation, stale readers, rollback, incompatible callers/models/schemas, tenant isolation, permission denial, locale/provider cache separation, PII redaction/retention, cache invalidation, provider failure, and experiment attribution. Verify persisted and caller-visible outcomes; command success alone is not proof.

Report repository/version evidence, registry schema and atomicity boundary, authorization/privacy model, compatibility matrix, cache semantics, rollout/evaluation decision, focused and affected checks, migration/rollback steps, and residual production or provider risks.
