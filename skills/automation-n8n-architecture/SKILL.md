---
name: automation-n8n-architecture
description: Design n8n workflow architecture covering triggers, branching, orchestration, AI-enriched processing, integrations, and retry strategies
metadata:
  version: 1.6
  argument-hint: "trigger type (webhook/schedule/event), workflow complexity (simple/multi-branch), integrations needed, AI step requirements, error handling strategy"
---

Design the automation architecture for $ARGUMENTS.

## Tool Integration

- **browser automation** — capture screenshots for visual verification and regression testing

Platforms and scope in focus:
- n8n
- Webhook-based workflows
- Scheduled workflows
- Event-driven automations
- API integration workflows
- AI-enriched automation flows
- Content generation pipelines
- Lead processing and enrichment flows
- CRM and internal backoffice automations
- Human-in-the-loop review workflows

Core architecture principles:

- Follow existing workflow conventions, naming, folder structure, credential strategy, and environment patterns when extending an existing n8n setup
- Prefer consistency with the current automation estate over introducing unrelated orchestration patterns
- Design workflows that are easy to implement, debug, operate, and evolve
- Keep trigger logic, transformation logic, decision logic, side effects, and integration boundaries explicit
- Separate ingestion, normalization, orchestration, AI processing, validation, storage, notification, and external delivery concerns where appropriate
- Avoid over-engineering and speculative workflow complexity
- Prefer the smallest clean workflow architecture that safely fits the use case
- Prefer explicit, predictable payload flow between nodes
- Keep workflow state transitions visible and reconstructable
- Prefer explicit contracts for inbound payloads, normalized records, AI inputs, AI outputs, external requests, and downstream actions
- Prefer production-safe defaults over convenience shortcuts
- Design for operational clarity, not just successful happy-path demos

Architecture goals:

- clear trigger and execution boundaries
- explicit node responsibilities
- predictable payload shapes
- safe external side effects
- maintainable branching logic
- reliable retries and recovery paths
- implementation-ready node structure
- practical fit for n8n capabilities
- good operator ergonomics
- reasonable extensibility without over-abstraction
- cost-aware AI and integration usage

Architecture completeness checklist:

- Identify trigger sources and event entry paths
- Identify synchronous and asynchronous workflow segments separately
- Identify ingestion, transformation, decision, and side-effect phases separately
- Identify user-facing latency-sensitive steps and deferred background steps separately
- Identify read-heavy, write-heavy, and side-effect-heavy parts separately
- Identify AI-powered steps, prompt assembly needs, and structured output needs where relevant
- Identify webhook, polling, cron, manual trigger, and child workflow boundaries where relevant
- Identify approval or human-review checkpoints where relevant
- Identify deduplication, idempotency, replay, and retry requirements before finalizing the design
- Identify rate limits, token costs, third-party quotas, and batching opportunities
- Identify audit, logging, and execution traceability needs
- Identify credential boundaries and sensitive data handling needs
- Identify operational risk areas before finalizing the design

Architecture workflow:

1. Identify the business goal and core workflow outcomes
2. Identify trigger sources, entry payloads, and execution conditions
3. Define major workflow phases and node groups
4. Define normalized data contracts between phases
5. Define branching rules, guardrails, and failure behavior
6. Define integrations, side effects, and delivery boundaries
7. Define persistence, deduplication, and replay strategy
8. Define AI usage, prompt boundaries, and output validation where relevant
9. Map the workflow into implementation-ready n8n structure
10. Highlight tradeoffs, risks, and recommended next steps

Problem framing and scope:

- Clarify the core business objective before designing nodes
- Distinguish core workflow logic from optional enrichments and downstream effects
- Prefer explicit assumptions when requirements are incomplete
- Avoid inventing product scope just to make the workflow look sophisticated
- Prefer a design that solves the stated automation need first, then extension points second

Workflow architecture:

- Define the trigger, orchestration, processing, persistence, and notification boundaries clearly
- Keep workflows cohesive and responsibilities narrow
- Avoid giant monolithic workflows when child workflows or separated stages improve clarity and reliability
- Avoid hiding major business behavior inside oversized code nodes when native nodes and explicit structure are sufficient
- Prefer semantic workflow and node naming that clearly reflects business behavior
- Prefer explicit handoff points between ingestion, normalization, AI reasoning, and action execution

## Extended Patterns
For complex scenarios, self-load additional patterns:
Read `skills/automation-n8n-architecture/SKILL.detail.md`
Load only when task involves: multi-system orchestration, webhook chains, or error recovery flows spanning >3 nodes
