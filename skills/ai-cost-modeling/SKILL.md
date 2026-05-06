---
name: ai-cost-modeling
description: Estimate and reason about LLM, embedding, inference, and workflow operating costs.
metadata:
  version: 2.0
  argument-hint: "feature/workflow, expected volume, model choices, token sizes, retrieval/tools, latency and budget constraints"
---

# AI Cost Modeling

Use this skill for tasks involving model pricing, token budgets, or AI feature operating cost.

## When To Use

- New AI feature cost estimates
- Model tier tradeoffs
- RAG, embedding, reranking, or tool-use cost projections
- Budget guardrails for production usage
- Pricing, margin, or plan-limit decisions

Do not use this skill as a substitute for current provider pricing. If exact rates matter, verify current pricing from official provider docs.

## Workflow

1. Define the unit of work: request, conversation, document, workflow run, or monthly active user.
2. Capture assumptions: traffic, retries, average and p95 input tokens, output tokens, embedding volume, tool calls, cache hit rate, and model mix.
3. Split costs by component: prompt, completion, embeddings, reranking, vector database, tool/runtime, storage, and observability.
4. Estimate per-unit cost, monthly cost, and p95/worst-case cost.
5. Model sensitivity: high-volume users, long conversations, low cache hit rate, larger context windows, retry storms.
6. Recommend controls: token budgets, summarization, caching, batching, model tiering, truncation, rate limits, and alerts.
7. State confidence level and what data would improve the estimate.

## Quality Bar

- Keep assumptions explicit and auditable.
- Prefer ranges over false precision when inputs are uncertain.
- Separate one-time ingestion costs from recurring inference costs.
- Include non-token costs when material: vector DB storage, background jobs, queues, and telemetry.
- Tie recommendations to product constraints such as latency, accuracy, margin, and plan limits.

## Anti-Patterns

- Using stale pricing for a decision without checking official docs.
- Reporting only average cost and ignoring p95/worst-case usage.
- Combining prompt, completion, embeddings, and tool costs into one opaque number.
- Ignoring retries, streaming continuation, or failed tool-call loops.
- Optimizing for cost by silently degrading required quality or safety.

## Verification

- Recalculate totals from the stated assumptions.
- Check the model mix and unit conversions: tokens, requests, users, documents, and months.
- Compare estimate against at least one realistic high-usage scenario.
- If production logs exist, reconcile assumptions against observed token and request counts.

## Output Contract

Status: done | partial | blocked
Assumptions: [traffic, token sizes, model mix, cache rate]
Cost model: [per unit, monthly, p95/worst case]
Drivers: [largest cost drivers]
Controls: [budget and reliability guardrails]
Verification: [math checks or observed data used]
Notes: [pricing uncertainty, missing data, tradeoffs]
