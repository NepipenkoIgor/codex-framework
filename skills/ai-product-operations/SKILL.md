---
name: ai-product-operations
description: Operational layer for AI SaaS — usage metering, token billing, per-user quotas, model fallbacks, cost dashboards, latency SLOs
metadata:
  version: 1.0
  domain: ai-saas
  agents: [builder-backend, architect, builder-frontend]
---

# AI Product Operations Skill

## Scope

Use when building: usage-based billing, token metering, per-user AI quotas, model fallback chains, AI cost dashboards, latency SLOs, AI product analytics.

## Usage Metering

- Capture token usage at the service layer — never in the LLM client wrapper
- Store per request: `user_id, org_id, feature_id, model_id, input_tokens, output_tokens, latency_ms, cost_usd, timestamp, request_id`
- Table: `ai_usage_events(id, user_id, org_id, feature, model, input_tokens, output_tokens, latency_ms, cost_usd, created_at)`
- Always record the model that actually served the request (may differ from requested after fallback)

## Token → Credit → Invoice

- Define credit multipliers per model in config, not code
- Store `credit_balance` on org/subscription record
- Deduct credits atomically (DB transaction) BEFORE the AI call — reject if insufficient
- Roll back deduction if call fails with non-quota error
- Emit `usage.metered` event for billing webhook (Stripe usage records)

## Per-User Quota Enforcement

- Enforce at 3 levels: requests-per-minute, tokens-per-day, credits-per-billing-period
- Use Redis for rpm/rpd counters with TTL = window size: `INCR ai:quota:{user_id}:{window}` + `EXPIRE`
- Return HTTP 429 with `Retry-After` header and remaining quota in response body
- Quota config in DB (overridable per plan/org) — never hardcoded

## Model Fallback Chains

- Define fallback order in config using capability tiers, for example `[high-capability-model, fast-fallback-model, low-cost-fallback-model]`
- Trigger on: HTTP 429, HTTP 503, timeout >30s, context length exceeded
- Never fall back silently — emit `model.fallback` event with original model + reason
- Log which model served each request for cost attribution

## Latency SLOs

- Define P95 targets per feature: e.g. chat < 3s, background analysis < 30s
- Track `latency_ms` on every usage event row
- For streaming: track time-to-first-token separately from total latency
- Alert when P95 exceeds SLO → error tracking + notification

## Cost Dashboard

- Per-user and per-org spend: daily/weekly/monthly views
- Break down by model and feature
- Show credit burn rate vs. plan limit — warn at 80% consumed
- Flag top-spending users (fraud detection + upsell signals)

## AI Product Analytics Events

Emit on every AI interaction:
- `ai.request.started` — feature, model_requested, user_id
- `ai.request.completed` — + tokens_used, latency_ms, cost_usd, model_served
- `ai.request.failed` — + error_code, retried (bool)
- `ai.quota.exceeded` — user_id, quota_type, window, limit, current
- `ai.model.fallback` — original_model, fallback_model, reason

## Checklist

- [ ] Token usage stored per request with model attribution
- [ ] Credit deduction atomic and pre-call
- [ ] Quota enforced at rpm + daily + billing-period
- [ ] Fallback chain configured, not hardcoded
- [ ] Fallback events emitted (never silent)
- [ ] Time-to-first-token tracked for streaming features
- [ ] Cost dashboard shows per-user/per-org breakdown
- [ ] All 5 analytics events wired up
