# automation-n8n-architecture — Extended Patterns (detail file)
# Load on demand — not injected by default

- Use sub-workflows when separation improves reusability, observability, or blast-radius control
- Avoid fragmenting the workflow into meaningless tiny pieces that make debugging harder

Node responsibility design:

- Each major node or node group should have one clear responsibility
- Separate input validation from transformation
- Separate normalization from enrichment
- Separate decisioning from action execution
- Separate provider-specific formatting from domain-level workflow state
- Keep code nodes focused and bounded when they are necessary
- Avoid mixed-purpose nodes that validate, transform, call external APIs, and decide outcomes all at once

Trigger and entrypoint design:

- Identify whether the workflow is triggered by webhook, cron, app event, polling, manual operation, queue intake, form submission, or imported dataset
- Define what the workflow guarantees at entry
- Validate trigger payloads explicitly at the boundary
- Normalize inbound data as early as possible
- Distinguish trusted internal inputs from untrusted external payloads
- Prefer explicit handling for missing, malformed, duplicated, or partial input
- Define whether the workflow is designed for single-item, batch, or mixed execution

State and payload design:

- Keep payload ownership explicit at each stage
- Avoid hidden mutable shared state
- Avoid repeatedly reshaping payloads without reason
- Prefer normalized internal payloads after ingestion
- Distinguish raw inbound payload, normalized workflow payload, AI prompt payload, external request payload, and final output payload
- Prefer stable intermediate shapes between node groups
- Design metadata explicitly for correlation, traceability, retries, and audit
- Preserve source identifiers and execution identifiers where useful

AI workflow architecture:

When designing AI-enriched n8n workflows, follow the automation-ai-workflows skill for AI boundary design, prompt architecture, structured output contracts, validation, confidence and fallback behavior, human-in-the-loop patterns, and cost-aware model selection. This skill focuses on the n8n-specific orchestration concerns:

- Define which n8n node groups handle AI input assembly, prompt execution, output validation, and post-AI side effects
- Track model choice, token usage, and failure modes as part of the n8n workflow observability strategy
- Preserve prompt versioning or prompt identity when reproducibility matters
- Use sub-workflows to isolate AI processing stages when blast-radius control or reuse matters

Branching and decision design:

- Define branching logic explicitly
- Distinguish deterministic conditions from AI-informed decisions
- Keep decision criteria inspectable and debuggable
- Avoid deeply nested branching when workflow partitioning is cleaner
- Prefer explicit no-op or skip paths over silent implicit fallthrough
- Define what happens on low-confidence, empty, invalid, or partial outcomes
- Define when the workflow should stop, continue, retry, escalate, or request review

Persistence and execution history:

- Identify whether the workflow needs durable persistence beyond n8n execution history
- Prefer storing business-relevant records in an external database when traceability or downstream reuse matters
- Distinguish operational execution logs from business state records
- Store correlation ids, source ids, deduplication keys, status, attempt counts, and timestamps where relevant
- Prefer append-friendly audit records for important state transitions
- Avoid relying solely on ephemeral execution memory for critical workflows
- Define which outputs should be persisted, which should be transient, and which should be replayable

Idempotency, deduplication, and replay safety:

- Identify all steps that may be retried, replayed, duplicated, or delivered more than once
- Design idempotency explicitly for webhooks, cron re-runs, retries, manual replays, API callbacks, and side-effecting nodes
- Distinguish item-level idempotency from workflow-run-level idempotency
- Prefer durable deduplication keys where duplicate processing would be harmful
- Avoid assuming exactly-once delivery
- Define replay-safe behavior for create, send, update, publish, enqueue, and notify operations
- Ensure irreversible or user-visible side effects are guarded against duplicate execution

Retries and failure handling:

- Design retries deliberately rather than letting accidental repeated runs define behavior
- Distinguish transient failures from permanent failures
- Define retry ownership clearly for API calls, AI calls, polling steps, database writes, and downstream deliveries
- Avoid retrying malformed input or invalid business state as if it were a transient infrastructure issue
- Prefer bounded retry policies with useful error context
- Define dead-letter, escalation, manual review, or operator intervention paths where appropriate
- Make partial failure behavior explicit
- Define whether failures should stop the whole workflow, skip one item, or move items into a review queue

Rate limits, quotas, and batching:

- Identify third-party API rate limits, LLM throughput limits, token budgets, email send limits, and platform quotas
- Distinguish workflow concurrency from provider capacity
- Prefer batching where it reduces cost and rate pressure safely
- Avoid unbounded fan-out behavior
- Define throttling, spacing, queueing, or backoff behavior where relevant
- Consider noisy-tenant or large-batch behavior if the workflow operates across multiple brands, customers, or datasets
- Design protections against runaway loops and runaway cost

External integration boundaries:

- Keep provider-specific details close to the integration boundary
- Validate outbound request shape before sending
- Normalize provider responses before passing them deeper into the workflow
- Avoid scattering provider-specific assumptions across unrelated node groups
- Define timeout, retry, fallback, and degraded-mode behavior explicitly
- Distinguish sync request-response integrations from async callback or polling integrations
- Use dedicated integration stages when one provider has multiple related operations

Webhook architecture:

- Validate inbound signatures, secrets, tokens, or shared credentials where relevant
- Distinguish public intake endpoints from trusted internal callbacks
- Prefer immediate acknowledgment for webhook intake when downstream processing may be slow
- Consider append-only intake records for important webhook-driven workflows
- Avoid heavy synchronous work in webhook response paths when eventual processing is acceptable
- Design replay safety and duplicate delivery handling explicitly
- Preserve raw event references when forensic debugging may matter

Scheduled and polling workflows:

- Define polling frequency based on business need and quota constraints
- Avoid over-polling where event-driven alternatives are better
- Track cursor state, last-processed markers, or window boundaries explicitly
- Design backfill, catch-up, and overlap behavior deliberately
- Ensure time-window logic is stable and replay-safe
- Distinguish first-run bootstrapping from incremental runs
- Avoid duplicate ingestion caused by loose time filters without deduplication

Human-in-the-loop workflows:

- Identify where human approval, review, editing, or override is required
- Distinguish automated recommendation from human-authorized action
- Preserve draft states, review reasons, and reviewer actions where relevant
- Avoid coupling human delay directly to fragile in-memory workflow execution when long delays are expected
- Prefer durable state checkpoints before handing off to humans
- Define resume behavior clearly after approval or rejection

Content and publishing workflows:

For content pipelines, separate source ingestion, summarization, generation, review, and publishing stages. Preserve source metadata, prevent duplicate publication, define auto-publish versus manual-approval boundaries, and separate channel-neutral content from channel-specific formatting.

Lead and CRM workflows:

For lead automation, separate ingestion, enrichment, scoring, qualification, routing, and outreach stages. Preserve source-of-truth identifiers, prevent duplicate contact creation, define merge and conflict behavior, and avoid automated outreach from unvalidated AI assumptions.

Concurrency and workload control:

- Identify whether multiple executions may operate on the same record, lead, customer, post, or document at once
- Define collision handling where concurrent updates may produce duplicate or inconsistent actions
- Prefer explicit locking markers, processing states, or external coordination when correctness requires it
- Avoid hidden race conditions caused by polling overlap, manual reruns, or webhook duplication
- Distinguish item concurrency from workflow concurrency
- Design with provider quotas and shared resources in mind

Observability and operator experience:

- Prefer predictable logging, metrics, alerts, and run visibility
- Follow existing logging and monitoring conventions where available
- Avoid noisy logging that hides the important events
- Emit contextual information useful for debugging: source id, workflow id, item id, brand id, user id, correlation id, provider response code, retry count
- Avoid leaking secrets or sensitive payloads into logs
- Design workflows so failures can be localized quickly
- Prefer explicit status checkpoints at major stages

Secrets and credential hygiene:

- Use n8n credentials and environment configuration appropriately
- Avoid hardcoding secrets, tokens, or provider credentials in nodes
- Distinguish environment-specific configuration from workflow logic
- Keep privileged operations narrow and auditable
- Prefer service credentials only where necessary
- Avoid routing sensitive credentials through unnecessary intermediate payloads
- Design credential ownership and rotation assumptions explicitly when relevant

Data validation and contracts:

- Validate untrusted input at the boundary
- Normalize data before major branching or AI steps
- Prefer explicit field requirements and fallback handling
- Keep payload shape stable after normalization
- Validate AI output before side effects
- Validate external API response assumptions before downstream use
- Distinguish transport validation from business-rule validation
- Prefer explicit typed or schema-shaped payload descriptions when giving implementation guidance

Cost-aware architecture:

- Identify expensive nodes: LLM calls, scraping, enrichment APIs, OCR, embeddings, external searches, media generation
- Avoid repeated expensive work when cached or persisted outputs can be reused safely
- Prefer deterministic filtering before costly AI processing
- Batch or gate AI usage where possible
- Define when cheaper models or non-AI logic are sufficient
- Consider fallback modes when budget, quota, or provider availability becomes constrained
- Design for cost visibility, not just functionality

Security and boundary hygiene:

- Validate all external inputs
- Avoid trusting inbound headers, query params, webhook payloads, or third-party responses without validation
- Avoid leaking secrets or internal operational details into outputs
- Prefer explicit authorization and access checks when internal tools or review endpoints are involved
- Keep sensitive actions narrow and auditable
- Define trust boundaries explicitly instead of assuming internal systems are safe by default

Anti-patterns to avoid:

- Avoid giant single-workflow god-automations
- Avoid mixing ingestion, AI reasoning, external side effects, and persistence in one opaque node chain
- Avoid uncontrolled nested branching that becomes unreadable
- Avoid hiding all logic in large code nodes when clearer node-level structure is possible
- Avoid duplicated transformation logic across multiple branches without reason
- Avoid direct irreversible side effects from unvalidated AI outputs
- Avoid unbounded retries and unbounded loops
- Avoid workflow designs that cannot be replayed safely
- Avoid hardcoded environment-specific values inside business logic
- Avoid speculative complexity the workflow does not need

n8n-specific design guidance:

- Prefer explicit node grouping through naming conventions and logical stage separation
- Prefer reusable sub-workflows when shared behavior is real and stable
- Use code nodes intentionally, not as the default for everything
- Keep expressions readable and avoid overly dense inline logic when a dedicated transformation stage is clearer
- Prefer clear item shape transitions and explicit Set or mapping stages
- Design with importability, maintainability, and operator readability in mind
- Avoid producing architecture that depends on fragile undocumented node behavior
- Prefer stable execution paths over visually clever but brittle graphs

```json
// Example n8n workflow structure: Webhook trigger -> Normalize -> Classify -> Route -> Deliver
{
  "nodes": [
    {
      "name": "Webhook: Intake",
      "type": "n8n-nodes-base.webhook",
      "parameters": { "path": "intake", "httpMethod": "POST" },
      "position": [250, 300]
    },
    {
      "name": "Set: Normalize Payload",
      "type": "n8n-nodes-base.set",
      "parameters": {
        "values": {
          "string": [
            { "name": "source_id", "value": "={{ $json.body.id }}" },
            { "name": "email", "value": "={{ $json.body.email?.toLowerCase().trim() }}" },
            { "name": "message", "value": "={{ $json.body.content || '' }}" }
          ]
        }
      },
      "position": [450, 300]
    },
    {
      "name": "AI: Classify Intent",
      "type": "@n8n/n8n-nodes-langchain.openAi",
      "parameters": { "model": "gpt-4o-mini", "prompt": "Classify intent..." },
      "position": [650, 300]
    },
    {
      "name": "Switch: Route by Intent",
      "type": "n8n-nodes-base.switch",
      "parameters": {
        "rules": [
          { "value": "support", "output": 0 },
          { "value": "sales", "output": 1 },
          { "value": "spam", "output": 2 }
        ]
      },
      "position": [850, 300]
    }
  ]
}
```

Implementation mapping:

- Translate the architecture into implementation-ready workflows, node groups, sub-workflows, triggers, transformations, decisions, integrations, and persistence boundaries
- Prefer concrete node-stage guidance over abstract theory
- Make clear which parts are ingestion-path, normalization-path, AI-path, side-effect-path, review-path, and persistence-path
- Make clear where validation happens, where orchestration happens, where AI happens, where external delivery happens, and where logging or persistence happens
- Prefer architecture output that can be turned directly into n8n implementation tasks and workflow builds

Contract output requirements:

For each major stage include:

- purpose
- trigger or entry condition
- input payload shape
- output payload shape
- validation rules
- side effects
- retry behavior
- idempotency or deduplication strategy
- observability notes
- failure handling behavior

For each integration include:
- provider or system name
- purpose
- auth boundary
- request shape
- response normalization
- retry strategy
- rate-limit concerns
- failure mode
- replay safety considerations

Output requirements:

- Start with a short automation architecture summary
- Identify the major workflow phases, node groups, and boundaries
- Define the recommended trigger model, payload model, branching model, and side-effect model
- Define the recommended AI usage, prompt boundaries, and structured output handling where relevant
- Define the recommended persistence, deduplication, retry, and replay strategy
- Define the recommended observability, operator workflow, and production safety considerations
- Map the design into implementation-ready n8n workflow structure
