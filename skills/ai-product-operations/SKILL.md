---
name: ai-product-operations
description: Design and implement production AI controls including usage metering, quota and credit settlement, compatible fallback, evaluation-gated cohort rollout, version attribution, drift response, and in-flight rollback reconciliation. Use when model calls have entered production and need an operational control plane; do not use to design an evaluation study, forecast unit economics, or build general observability.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.1
  domain: ai-saas
---

# AI Product Operations

## Repository Discovery

Generate stack context, then inspect the exact core/provider SDK pins and matching official provider documentation, provider adapters, served models, request/idempotency identifiers, streaming lifecycle/protocol, usage fields and their exactness, current ledger/billing schema, organization/user authorization, retries/timeouts, context budgeting, fallback tool/modality compatibility, deployment-runtime constraints and existing telemetry as one capability chain. Reuse established monetary and event boundaries. Treat SDK/model migration as a separate rollout. Never render missing provider usage or cost as zero.

## Workflow

1. Define the metered unit, authority, lifecycle, and reconciliation source for each feature.
2. Separate admission limits from final billing: reserve capacity, execute once under an idempotency key, settle authoritative usage, then release or reconcile the reservation.
3. Make request, token, concurrency, and credit policies explicit per organization, user, and feature.
4. Define fallback compatibility before ordering models: supported modalities/tools/schema, context capacity, data region, latency, and user-visible attribution.
5. Retain immutable raw provider usage with source/request provenance, then produce a versioned normalized record that identifies the exact provider-usage adapter version; instrument started/completed/failed/fallback/reconciled events with usage provenance and exactness. Version the rollout adapter independently and attach its version to exposure and routing decisions. Later adapter changes must not rewrite historical raw evidence.
6. Exercise timeout-after-provider-success, replay, missing usage, partial stream, quota race, fallback incompatibility, and delayed reconciliation.
7. Define evaluation-gated rollout, cohort/canary exposure, model/prompt/tool version attribution, drift slices, deterministic disable/rollback, and reconciliation of in-flight work. Keep provider usage/fallback/rollout adapters versioned and keep thresholds, cohorts and gates in provenance-linked versioned product policy/configuration. Thresholds come from product harm, baseline and SLO evidence rather than universal numbers.

## Usage and Ledger Contract

Store immutable usage events keyed by provider request ID and internal idempotency key:

```text
request_id, provider_request_id, org_id, user_id, feature_id,
model_requested, model_served, input_units, output_units,
usage_status(exact|estimated|missing), cost_status(exact|estimated|missing),
cost_usd, latency_ms, time_to_first_token_ms, occurred_at
```

Use an idempotent `reserve -> settle -> release/reconcile` ledger:

- admission creates or reuses a bounded reservation under the request idempotency key;
- provider completion settles once from authoritative usage when available;
- ambiguous timeouts remain pending and reconcile by provider request ID instead of refunding blindly;
- replayed completion/usage events are no-ops after the first settlement;
- missing usage remains `missing` and produces a lower-bound cost view, never a fabricated zero.

Do not deduct and then “roll back on error”: a crash or timeout-after-success makes that sequence financially incorrect.

## Quota and Concurrency Safety

- Enforce atomic window limits with one Redis script/transaction or a database constraint; never separate `INCR` and `EXPIRE` operations.
- Scope policies by organization, user, feature, and credential as required; authorization is checked independently of quota.
- Return bounded retry information without exposing another tenant's usage.
- Use request and token ceilings before the call, then settle actual consumption afterward.
- Reconcile ledger, provider records, and invoice exports; alert on missing, duplicated, or stale pending entries.

## Fallback Policy

Fallback is an explicit product decision, not a generic retry. Retry the same provider/model only when the operation is idempotent and the failure class is safe. Switch models only when the fallback satisfies the feature contract. Context-length failure first invokes the product's bounded-context strategy; silently choosing a model with a different context or tool/schema behavior is forbidden.

Emit the original model, served model, trigger, compatibility decision, and any user-visible degradation. Consequential or materially lower-quality fallback may require user confirmation instead of automatic execution.

## SLO and Cost Views

- Define SLOs from product journeys and measured baselines, not universal example numbers.
- Track time to first token and total completion separately for streams.
- Attribute costs by actual served model and feature, with exact/estimated/missing coverage visible.
- Show lower/upper or unresolved spend when usage is incomplete; alert on reconciliation lag and unexpected burn rate.
- Keep analytics events free of prompts, secrets, and unnecessary personal data.
- Correlate quality, refusal/abstention, safety, latency, usage exactness and cost by served model/prompt/tool version and product slice. A cost improvement cannot mask a quality or safety regression.
- Roll back routing/configuration through a tested deterministic control while preserving auditable in-flight usage and side-effect reconciliation; do not assume a model rollback reverses completed actions.

## Verification

- Simulate provider success followed by client timeout and retry; prove one settlement.
- Replay usage and billing events; prove ledger idempotency.
- Race concurrent requests against the last available quota; prove the limit is not exceeded.
- Return null provider usage; prove dashboards and margins do not display zero cost.
- Interrupt a stream after partial provider output/usage; prove reservation settlement and reconciliation use authoritative provider evidence, do not double charge or treat the partial response as a complete success, and preserve the caller-visible failure state.
- Trigger context overflow; prove bounded-context handling precedes only a contract-compatible fallback.
- Reconcile a delayed provider record and prove invoice/export totals converge.
- Replay pinned historical fixtures through the recorded provider-usage and rollout adapter versions, then through an explicitly migrated version; prove semantic changes are attributable and historical raw evidence is unchanged.
- Canary a compatible model or prompt change on representative slices; prove evaluation and operational gates, drift detection, deterministic disable/rollback and caller-visible recovery without hardcoded global thresholds.

## Output Contract

Report the discovered request/billing boundaries, provider-usage and rollout adapter versions, metering schema, reservation and settlement state machine, quota scopes, fallback compatibility matrix, SLOs, dashboards, reconciliation/alerts, executed failure cases, and residual assumptions about provider usage authority.

## Done Criteria

- Every provider operation has one stable idempotency key and usage provenance.
- Reservations settle/release/reconcile without double charge or blind refund.
- Missing usage/cost is represented as unknown, not zero.
- Quotas are atomic and tenant-scoped.
- Fallbacks preserve the declared feature contract and are attributable.
- Failure/replay/reconciliation tests pass against the repository's authoritative stores.
