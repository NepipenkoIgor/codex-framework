---
name: ai-cost-modeling
description: Estimate and reason about LLM, embedding, inference, and workflow operating costs. Use when ai cost modeling is the primary requested outcome; do not use when it is only incidental to a broader task.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.1
  argument-hint: "feature/workflow, expected volume, model choices, token sizes, retrieval/tools, latency and budget constraints"
---

# AI Cost Modeling

Use this read-only skill for economic estimation, reconciliation and decision support involving model pricing, token budgets, or AI feature operating cost. It does not edit spreadsheets, code, configuration, runtime metering, billing ledgers or production controls. Present required implementation changes as recommendations and hand them to an authorized implementation workflow; do not perform or claim those mutations from this skill.

## When To Use

- New AI feature cost estimates
- Model tier tradeoffs
- RAG, embedding, reranking, or tool-use cost projections
- Budget guardrails for production usage
- Pricing, margin, or plan-limit decisions

Do not use this skill as a substitute for current provider pricing. If exact rates matter, obtain current official pricing and billing definitions for the exact model/version, region, tier, cache semantics, currency and billing period. If that evidence is unavailable, refuse a precise recalculation and report the missing inputs rather than inventing a rate.

## Workflow

1. Define the unit of work: request, conversation, document, workflow run, or monthly active user.
2. Capture assumptions: traffic, retries and regenerated/continued turns, average and tail input/output tokens, cached-input eligibility and billed cache hits/misses, embedding volume, tool/model round trips, tool-result context, and model mix. Keep volatile rates in dated, cited task inputs or product configuration—not reusable skill prose—and label every unsupported provider-field assumption.
3. Split costs by component: prompt, completion, embeddings, reranking, vector database, tool/runtime, storage, and observability.
4. Estimate per-unit cost, monthly cost, and p95/worst-case cost.
5. Model sensitivity: high-volume users, long conversations, low cache hit rate, larger context windows, retry storms, and plausible lower/upper bounds for missing usage or price evidence. State whether the decision changes anywhere in that range.
6. Recommend controls: token budgets, summarization, caching, batching, model tiering, truncation, rate limits, and alerts.
7. State confidence level and what data would improve the estimate.
8. Before a pricing, plan-limit or launch consequence is adopted, require the accountable product/finance approval appropriate to the decision and show whether uncertainty bounds change that decision.

## Quality Bar

- Keep assumptions explicit and auditable.
- Prefer ranges over false precision when inputs are uncertain.
- Separate one-time ingestion costs from recurring inference costs.
- Include non-token costs when material: vector DB storage, background jobs, queues, and telemetry.
- Tie recommendations to product constraints such as latency, accuracy, margin, and plan limits.
- Keep provider-reported usage provenance and exactness. Missing or null usage/cost is unresolved and makes any observed total a lower bound; it is never evidence of zero cost.
- Derive billed legs from distinct reconciled provider request/attempt identities: cached and uncached input, output/reasoning where reported, retries, fallbacks, tool-loop model calls, embeddings/reranking, and provider or application-side tool/runtime charges. A fallback retry represented by one request/attempt must not also be counted as two synthetic legs.

## Anti-Patterns

- Using stale pricing for a decision without checking official docs.
- Reporting only average cost and ignoring p95/worst-case usage.
- Combining prompt, completion, embeddings, and tool costs into one opaque number.
- Ignoring retries, streaming continuation, or failed tool-call loops.
- Treating absent provider usage as zero or applying a cached-input discount to tokens that were not provider-confirmed cache hits.
- Optimizing for cost by silently degrading required quality or safety.

## Verification

- Recalculate totals from the stated assumptions.
- Check the model mix and unit conversions: tokens, requests, users, documents, and months.
- Compare estimate against at least one realistic high-usage scenario.
- Run an explicit sensitivity table over evidence-supported lower and upper bounds for missing provider usage and provider/application tool-runtime charges. For every bound, recompute cost and state whether the margin, pricing, plan-limit, or launch decision flips; merely labeling those components unknown or asking an approver to accept unspecified uncertainty is insufficient.
- If production logs exist, reconcile assumptions against observed token and request counts.
- When provider invoices or billing exports are available, reconcile modeled billed legs and totals to them; explain residual timing, currency, tax or allocation differences instead of forcing equality.
- Reconcile request IDs across retries, fallbacks, tool rounds, cache usage and delayed provider usage so ambiguous/missing legs remain visible instead of being double-counted or dropped.

## Output Contract

Status: done | partial | blocked
Assumptions: [traffic, token sizes, model mix, cache rate]
Cost model: [per unit, monthly, p95/worst case]
Drivers: [largest cost drivers]
Controls: [budget and reliability guardrails]
Verification: [math checks or observed data used]
Notes: [dated official pricing sources, or Not available; unsupported assumptions; pricing uncertainty, missing data, tradeoffs]

When inputs cannot support a value, report per-unit, monthly and tail ranges as `Not available` rather than omitting them or fabricating precision.
