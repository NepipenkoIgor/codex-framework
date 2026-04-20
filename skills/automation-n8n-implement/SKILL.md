---
name: automation-n8n-implement
description: Build n8n workflows including node structures, payload transformations, code nodes, AI steps, API integrations, and retry-safe side effects
metadata:
  version: 1.7
  argument-hint: "node types (HTTP/code/AI/transform), workflow logic, data transformations needed, error handling and retry strategy"
---

Implement $ARGUMENTS.

## Tool Integration

- **browser automation**: capture screenshots for visual verification and regression testing
- docs lookup tools: fetch current n8n docs and API integration patterns before implementing

Platforms and implementation scope:
- n8n
- Webhook workflows
- Scheduled workflows
- Event-driven automations
- External API integrations
- AI-enriched workflows
- Content pipelines
- Lead pipelines
- CRM and SaaS backoffice automations
- Human-in-the-loop automation stages
- Import-ready workflow implementation guidance

Core implementation principles:

- Follow the existing workflow naming, foldering, credential, environment, and payload conventions when extending an existing n8n setup
- Prefer consistency with the current automation system over introducing unrelated patterns
- Implement workflows that are easy to read, debug, operate, and evolve
- Keep triggers, transformations, decisions, AI steps, side effects, and persistence boundaries explicit
- Prefer readable node-level logic over clever but fragile expression-heavy graphs
- Use native n8n nodes where they are sufficient
- Use code nodes intentionally when they materially improve correctness, clarity, reuse, or transformation safety
- Avoid over-engineering and speculative workflow complexity
- Prefer explicit, predictable payload flow between stages
- Preserve source identifiers, correlation ids, and deduplication keys through the workflow where relevant
- Prefer production-safe defaults over happy-path shortcuts
- Design implementation for real operational use, not just demo success

Implementation goals:

- clear trigger setup
- explicit payload normalization
- stable item shapes across stages
- safe branching logic
- reliable API integrations
- validated AI outputs
- retry-safe side effects
- readable expressions and code nodes
- maintainable workflow structure
- good operator ergonomics
- practical importability and long-term maintainability

Implementation workflow:

1. Identify the workflow goal and expected outputs
2. Identify trigger type, entry payload, and execution model
3. Define the workflow stages and node groups
4. Normalize the payload early and keep it stable
5. Implement branching and guard conditions explicitly
6. Implement integrations and external side effects safely
7. Implement persistence, deduplication, and replay protection where needed
8. Implement AI steps with clear prompt boundaries and output validation where relevant
9. Add observability, failure handling, and production-safe behavior
10. Output implementation-ready node plan, expressions, code, and guidance

Problem framing and scope:

- Clarify the desired business outcome before implementing nodes
- Distinguish required logic from optional enrichments
- Prefer explicit assumptions when requirements are incomplete
- Avoid inventing extra workflow scope just to make the implementation look advanced
- Prefer the smallest clean implementation that safely solves the stated problem

Workflow implementation rules:

- Prefer clear stage separation:
    - trigger
    - validate
    - normalize
    - enrich
    - decide
    - persist
    - notify
    - deliver
- Use semantic workflow names and semantic node names
- Keep each major node or stage focused on one responsibility
- Avoid giant workflows when sub-workflows improve reuse or blast-radius control
- Avoid tiny meaningless fragmentation that makes execution tracing harder
- Prefer implementation that can be debugged from the execution graph without guesswork

Trigger implementation:

- Implement the most appropriate trigger for the use case: webhook, cron, app event, polling, manual trigger, child workflow, or imported dataset
- Validate trigger payload assumptions immediately
- Normalize raw inbound data as early as possible
- Distinguish single-item and batch execution deliberately
- Avoid mixing intake validation with business-side effects in the same first step
- Prefer explicit initial Set or Code stages when payload cleanup is needed

Payload normalization:

- Normalize data immediately after ingestion
- Preserve raw source ids and relevant source metadata
- Prefer one stable internal payload shape after normalization
- Distinguish raw payload, normalized payload, AI input payload, and outbound provider payload
- Avoid repeatedly reshaping fields across multiple stages without reason
- Prefer explicit mapping nodes or focused code nodes for non-trivial transformations
- Preserve correlation ids, tenant ids, brand ids, user ids, attempt counters, and timestamps where relevant

Expressions and mapping:

- Keep n8n expressions readable
- Avoid dense inline expressions when a named transform stage is clearer
- Prefer simple Set nodes for straightforward field mapping
- Prefer Code nodes for non-trivial transformation, grouping, deduplication, ranking, or normalization logic
- Avoid duplicating expressions across multiple branches when the data can be normalized once
- Prefer explicit defaults and null-safe handling
- Avoid brittle field access that assumes upstream payloads are always complete

Code node guidance:

- Use JavaScript suited for n8n Code nodes
- Keep code nodes focused and bounded
- Write code that is readable, deterministic, and safe for repeated execution
- Avoid hidden side effects inside code nodes unless explicitly intended
- Return stable item shapes
- Validate assumptions inside code when upstream data may be incomplete
- Prefer explicit helper functions inside the code node when logic is non-trivial
- Avoid overbuilding generic frameworks inside code nodes
- Prefer code that can be copy-pasted directly into n8n with minimal modification

```javascript
// n8n Code Node: Deduplicate and normalize incoming leads with error handling
const seen = new Set();
const results = [];

for (const item of $input.all()) {
  try {
    const email = item.json.email?.toLowerCase().trim();
    if (!email) {
      results.push({
        json: { ...item.json, _status: "skipped", _reason: "missing_email" },
      });
      continue;
    }
    if (seen.has(email)) {
      results.push({
        json: { ...item.json, _status: "skipped", _reason: "duplicate" },
      });
      continue;
    }
    seen.add(email);
    results.push({
      json: {
        source_id: item.json.id ?? null,
        email,
        name: item.json.name?.trim() || null,
        company: item.json.company?.trim() || null,
        _status: "processed",
      },
    });
  } catch (error) {
    results.push({
      json: { ...item.json, _status: "error", _reason: error.message },
    });
  }
}

return results;
```

Branching and decision implementation:

- Implement branching explicitly with readable conditions
- Distinguish deterministic conditions from AI-informed decisions
- Prefer shallow, understandable branching structures
- Add explicit skip, stop, or no-op paths when relevant
- Avoid ambiguous fallthrough behavior
- Define how the workflow behaves on empty, invalid, partial, or low-confidence outcomes
- Prefer explicit review or retry paths for risky decisions

AI implementation rules:

When implementing AI-enriched workflows:

- Use AI only where reasoning, generation, extraction, summarization, classification, or enrichment actually adds value
- Do not route deterministic mapping or filtering through an LLM
- Separate prompt construction from side-effect execution
- Prefer structured outputs with explicit JSON expectations
- Shape inputs deterministically before sending them to the model
- Validate AI outputs before downstream actions
- Handle invalid, partial, empty, or low-confidence outputs explicitly
- Preserve model identity, attempt count, token-sensitive context decisions, and relevant prompt metadata where needed
- Prefer cheaper or smaller models when high-end reasoning is unnecessary
- Avoid allowing raw AI free-text output to directly trigger irreversible side effects

Prompt implementation:

- Define system instructions, task instructions, source content, and runtime context separately
- Prefer reusable prompt templates when multiple steps share behavior
- Keep prompts focused and bounded
- Avoid bloated prompts with uncontrolled context stuffing
- Define the output contract before finalizing the prompt
- Prefer JSON outputs for downstream automation when structure matters
- Include explicit field instructions, validation expectations, and error handling expectations when appropriate
- Ensure downstream nodes consume validated fields rather than raw text blobs when structure matters

AI output validation:

- Validate required fields before use
- Validate enums, arrays, scores, flags, and identifiers before side effects
- Reject, retry, or route to review when output contract is broken
- Prefer explicit cleanup and normalization after AI output
- Avoid silently tolerating malformed AI responses when correctness matters
- Define fallback behavior when the AI provider fails or returns unusable output

External API integration rules:

- Keep provider-specific request formatting near the integration boundary
- Validate outbound payloads before sending
- Normalize provider responses immediately after receipt
- Avoid scattering provider-specific assumptions across the workflow
- Set explicit timeout, retry, and degraded-mode behavior where relevant
- Distinguish synchronous integrations from async or callback-based integrations
- Preserve provider request ids and response ids where relevant for support and debugging
- Avoid duplicate outbound actions on retries without idempotency protection

Webhook implementation:

- Validate signatures, shared secrets, tokens, or provider-specific verification requirements where relevant
- Distinguish public intake endpoints from trusted internal callbacks
- Prefer early acknowledgment when long processing is expected and architecture allows it
- Preserve raw event ids, delivery ids, and source references where relevant
- Implement duplicate delivery handling explicitly
- Avoid heavy synchronous work in the response path when eventual processing is acceptable
- Prefer append-friendly persistence or intake records when webhook events are important business inputs

Scheduled and polling implementation:

- Implement polling windows deliberately
- Preserve cursor state, last-seen timestamps, or page tokens explicitly
- Avoid loose time-window logic that causes duplicate ingestion without deduplication
- Distinguish first-run backfill from incremental runs
- Define overlap windows and replay behavior explicitly
- Respect third-party quotas and rate limits
- Prefer batch-safe processing and bounded concurrency

Persistence and business state:

- Persist business-relevant data outside n8n execution memory when traceability or downstream use matters
- Distinguish workflow execution state from business state
- Store correlation ids, deduplication keys, source ids, statuses, attempts, and timestamps where relevant
- Prefer append-friendly event or audit-style persistence when traceability matters
- Avoid relying on transient in-flight workflow state for long-running processes
- Define which outputs are transient, durable, replayable, or auditable

Idempotency, deduplication, and replay safety:

- Implement idempotency explicitly for webhooks, cron jobs, retries, manual reruns, AI replays, and external side-effect steps
- Distinguish item-level deduplication from run-level deduplication
- Prefer durable deduplication keys when duplicate processing would be harmful
- Avoid assuming exactly-once delivery
- Guard create, send, publish, notify, and update side effects against accidental duplication
- Ensure manual reruns do not blindly repeat irreversible actions without checks
- Define replay-safe behavior for every side-effecting stage

Retry and failure implementation:

- Design retry logic intentionally
- Distinguish transient infrastructure errors from permanent invalid-input or invalid-state errors
- Prefer bounded retry behavior with useful context
- Avoid retrying obviously bad payloads as if they were transient failures
- Define whether one failed item stops the run, is skipped, or is moved into review
- Prefer explicit error routing for high-value or risky workflows
- Preserve failure reason, provider context, retry count, and correlation data where relevant
- Add manual review or escalation checkpoints when correctness matters more than blind automation

Rate limits, quotas, and cost control:

- Identify expensive nodes and protect them deliberately
- Filter early before costly AI or enrichment steps
- Batch where safe and valuable
- Avoid unbounded fan-out
- Add throttling, spacing, or backoff where required
- Design for provider quotas and large-batch behavior
- Protect against runaway loops, runaway retries, and runaway AI cost
- Prefer cheaper deterministic logic when it fully solves the need

Human-in-the-loop implementation:

- Use durable checkpoints before handing work to humans
- Distinguish draft generation from approved action
- Preserve review state, reviewer input, timestamps, and reasons where relevant
- Avoid long fragile waiting states that depend on in-memory execution if delays may be long
- Define resume behavior clearly on approval, rejection, timeout, or override
- Prefer explicit review queues or external status storage when needed

Content workflow implementation:

For content pipelines, separate ingestion, normalization, summarization, generation, review, formatting, and publishing stages. Preserve source metadata, generate channel-neutral content before channel-specific formatting, distinguish draft/approved/published/failed states, and prevent duplicate publication.

Lead and CRM workflow implementation:

For lead workflows, separate ingestion, normalization, enrichment, scoring, qualification, routing, and outreach stages. Preserve source-of-truth identifiers, prevent duplicate contact creation, define update-versus-create behavior, and avoid automated outreach from unvalidated AI output.

Concurrency and execution control:

- Identify whether multiple executions may operate on the same business object concurrently
- Add guards when concurrent execution can cause duplicate sends, duplicate creation, inconsistent updates, or race conditions
- Distinguish workflow concurrency from item concurrency
- Use durable state markers or external locking approaches when correctness requires them
- Avoid hidden race conditions from webhook duplication, cron overlap, or manual reruns
- Respect provider throughput limits and shared resource limits

Observability and operator ergonomics:

- Implement useful status checkpoints across major stages
- Preserve correlation ids, source ids, item ids, workflow ids, brand ids, user ids, request ids, and retry counts where relevant
- Prefer logs and persisted status fields that help diagnose failures quickly
- Avoid noisy logging that hides meaningful events
- Avoid leaking secrets or sensitive payloads into logs
- Design execution traces so an operator can understand what happened without reverse-engineering the whole workflow
- Prefer explicit success, skipped, retrying, failed, and review-needed states

Secrets and configuration:

- Use n8n credentials and environment variables appropriately
- Avoid hardcoding secrets, URLs, API keys, tenant-specific values, or environment-specific values in workflow logic
- Distinguish workflow configuration from business logic
- Keep privileged operations narrow and auditable
- Avoid routing secrets through unnecessary payload fields
- Make configuration requirements explicit when generating implementation guidance

Security and validation:

- Validate all untrusted external inputs
- Avoid trusting inbound headers, query params, form fields, webhook bodies, or third-party responses without checks
- Validate AI outputs before side effects
- Validate external response assumptions before downstream use
- Prefer explicit allowlists, field validation, and state validation for risky operations
- Keep sensitive actions narrow and auditable

n8n-specific implementation guidance:

- Prefer semantic node names with stage prefixes when useful
- Keep node groups visually understandable
- Prefer Set nodes for simple mappings
- Prefer IF or Switch nodes for explicit branch control
- Prefer HTTP Request nodes for integrations where native nodes are unavailable or unsuitable
- Prefer Code nodes for bounded transformation logic, deduplication, ranking, or aggregation
- Use Execute Workflow or sub-workflow patterns when reuse or separation adds real value
- Keep expressions readable and maintainable
- Avoid fragile undocumented hacks or hidden assumptions about execution behavior
- Design implementation so it can be imported, tested, debugged, and maintained safely

Implementation output behavior:

When the user asks for implementation, produce the most useful combination of the following:

- workflow stage breakdown
- node-by-node implementation plan
- recommended node names
- input and output payload shapes for each stage
- Set node mapping guidance
- IF or Switch branching logic
- Code node JavaScript when needed
- HTTP Request configuration guidance
- AI prompt templates and output contract
- retry, deduplication, and replay strategy
- persistence strategy
- operator and observability notes
- import-ready workflow structure guidance when feasible

Code node output requirements:

When writing code for n8n Code nodes:

- Return valid n8n item arrays or item objects in the expected format
- Keep code self-contained unless the user explicitly wants abstractions outside n8n
- Include defensive checks for missing data when relevant
- Preserve important metadata fields
- Prefer readable variable naming
- Avoid unnecessary framework-like abstractions
- Make the code copy-paste ready

Contract output requirements:

For each major stage include:

- purpose
- node type recommendation
- input payload shape
- output payload shape
- validation rules
- side effects
- retry behavior
- deduplication or idempotency strategy
- failure behavior
- observability notes

For each integration include:

- provider or system name
- node type recommendation
- auth boundary
- request shape
- response normalization
- retry strategy
- rate-limit concerns
- replay safety considerations
- failure mode

Output requirements:

- Start with a short implementation summary
- Identify the major workflow stages and recommended node groups
- Provide implementation-ready node-by-node guidance
- Define the normalized payload model and stage transitions
- Provide expressions, mapping strategy, and code node logic where relevant
- Define AI prompt boundaries, output contract, and validation where relevant
- Define retry, deduplication, replay, and side-effect safety considerations
- Define observability, operator workflow, and production safety considerations
- Map the solution into implementation-ready n8n workflow structure
