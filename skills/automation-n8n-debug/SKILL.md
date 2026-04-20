---
name: automation-n8n-debug
description: Diagnose and fix n8n workflow failures including broken executions, malformed payloads, failed AI steps, webhook issues, and production incidents
metadata:
  version: 1.7
  argument-hint: "workflow name/ID, error type (execution failure/malformed payload/webhook issue), affected nodes, production vs dev environment"
---

Debug $ARGUMENTS.

## Tool Integration

- **ast-grep** — use for structural code pattern search (find function signatures, expression patterns) — faster and more accurate than Grep for code structure
- **browser automation** — capture screenshots for visual verification and regression testing

Platforms and debugging scope:
- n8n
- Webhook workflows
- Scheduled workflows
- Polling workflows
- Event-driven automations
- API integration failures
- AI-enriched workflow failures
- Content pipelines
- Lead pipelines
- CRM and backoffice automations
- Human-in-the-loop automation stages
- Production incident debugging
- Execution replay and duplicate-processing incidents

Core debugging principles:

- Start with evidence, not assumptions
- Debug from trigger to side effect in the actual execution path
- Prefer root-cause isolation over symptom patching
- Distinguish data problems, logic problems, integration problems, execution problems, and operational problems
- Keep payload tracing explicit across workflow stages
- Prefer the smallest safe fix that resolves the actual failure mode
- Preserve replay safety, idempotency, and side-effect safety when proposing fixes
- Avoid “works on one test run” fixes that break real-world reruns or retries
- Prefer explicit diagnostics over vague advice
- Design fixes that improve operability, not just immediate success
- Treat duplicate side effects, missing side effects, and silent partial failures as high-priority risks
- Never assume AI output, provider response shape, or upstream payload stability without verifying it

Debugging goals:

- find the real failure boundary
- isolate the first broken assumption
- identify payload shape mismatches
- identify broken expressions and mapping errors
- identify unstable branching logic
- identify unsafe retries and duplicate side effects
- identify provider-specific request or auth issues
- identify AI prompt and output handling failures
- identify timing, scheduling, polling, and concurrency issues
- produce implementation-ready corrective actions
- improve reliability and observability after the fix

Debugging workflow:

1. Identify the expected business outcome
2. Identify what actually happened
3. Locate the first stage where behavior diverged from expectations
4. Inspect trigger conditions, payload shape, and execution path
5. Inspect transformations, expressions, branching, and code nodes
6. Inspect integration requests, responses, auth boundaries, and retry behavior
7. Inspect AI prompt inputs, outputs, and validation boundaries where relevant
8. Inspect idempotency, deduplication, replay, and concurrency behavior
9. Propose the smallest safe fix
10. Recommend guardrails, observability improvements, and replay-safe remediation steps

Problem framing and incident mindset:

- Clarify the expected workflow outcome before proposing fixes
- Distinguish “workflow failed loudly” from “workflow succeeded incorrectly”
- Distinguish user-visible failure, silent data corruption, duplicate side effect, skipped side effect, and delayed execution
- Prefer explicit assumptions when execution evidence is incomplete
- Avoid inventing failure causes without tracing the actual path
- Treat partial success as a potentially dangerous failure mode when external side effects are involved

Failure classification:

Classify failures into one or more of these categories before proposing a fix:

- trigger failure
- malformed input
- missing field or null handling failure
- expression failure
- code node logic failure
- branch condition failure
- AI prompt failure
- AI malformed output
- output validation failure
- provider auth failure
- provider request formatting failure
- provider response parsing failure
- rate-limit or quota failure
- timeout or transient infrastructure failure
- deduplication failure
- idempotency failure
- replay safety failure
- concurrency or overlap failure
- scheduling or polling window failure
- persistence mismatch
- human-review state failure
- observability gap
- operator error or misconfiguration

Execution tracing rules:

- Trace the real execution path, not the intended diagram
- Identify the exact node where behavior first becomes invalid
- Inspect inbound and outbound item shape at each critical stage
- Distinguish empty item stream from malformed item stream
- Distinguish node success status from business correctness
- Prefer concrete payload evidence over guessing from node names
- Preserve correlation ids, source ids, event ids, and run identifiers when analyzing multi-stage flows

```
// Payload trace pattern: inspect item shape at each stage of a failed execution
//
// Stage 1 — Webhook intake (raw):
// { body: { id: "evt_123", email: "USER@EXAMPLE.COM", items: [{ sku: "A1", qty: 2 }] } }
//
// Stage 2 — After normalization (Set node):
// { source_id: "evt_123", email: "user@example.com", items: [{ sku: "A1", qty: 2 }] }
//
// Stage 3 — After Code node (BUG: items becomes undefined):
// { source_id: "evt_123", email: "user@example.com", total: NaN }
//                                                      ^^^ root cause
//
// Diagnosis: Code node accesses $json.line_items instead of $json.items
// The field was renamed in normalization but the code node uses the old name.
//
// Fix: update Code node to reference $json.items:
//   const items = $input.first().json.items ?? [];
//   const total = items.reduce((sum, i) => sum + (i.qty * i.price), 0);
```

Trigger debugging:

- Verify whether the trigger actually fired under the expected conditions
- Inspect webhook payload, cron timing, polling cursor, app event boundary, or child workflow input
- Distinguish trigger misfire from downstream logic failure
- Validate signature verification, auth headers, query params, and trigger configuration when relevant
- Inspect whether batch and single-item assumptions are mismatched at entry
- Confirm whether the workflow is processing new events, duplicated events, stale events, or no events

Payload debugging:

- Inspect raw inbound payload before normalization
- Inspect normalized payload after cleanup or Set or Code stages
- Identify missing fields, unexpected nesting, wrong array shape, incorrect types, null propagation, and stale metadata
- Distinguish source payload issue from transformation issue
- Avoid fixing downstream nodes when the real problem is early malformed normalization
- Prefer stable normalized payloads over repeated ad hoc reshaping across branches
- Preserve source ids and deduplication fields when fixing mappings

Expression debugging:

- Validate every critical n8n expression against real execution data
- Check null safety, optional chaining assumptions, string versus array assumptions, and item indexing assumptions
- Identify brittle field access paths
- Distinguish empty string, null, undefined, false, and zero correctly
- Avoid dense inline expressions when a transform stage would make correctness easier to verify
- Prefer explicit field derivation when expression complexity is hiding the real bug

Code node debugging:

- Read the code node as production logic, not as a helper snippet
- Verify expected input shape and returned item shape
- Check for accidental mutation, dropped metadata, array flattening mistakes, incorrect return format, and unsafe assumptions
- Inspect logic for deduplication, grouping, ranking, filtering, and aggregation errors
- Distinguish code runtime errors from silent logical corruption
- Prefer focused fixes over rewriting the whole node unless the current logic is structurally unsafe
- Ensure code fixes remain replay-safe and idempotent where relevant

Branching and decision debugging:

- Verify the actual condition that routed execution
- Distinguish deterministic branch bugs from AI-driven decision bugs
- Inspect whether low-confidence, empty, or malformed results are falling through incorrectly
- Check Switch, IF, and merge behavior against real item streams
- Confirm whether skip paths, stop paths, and no-op paths are explicit and functioning
- Avoid silent fallthrough logic that makes failures look like success
- Prefer making decision criteria inspectable and testable after the fix

AI debugging rules:

When AI is involved:

- Inspect the exact prompt inputs, not just the prompt template
- Distinguish model failure from bad prompt construction
- Distinguish malformed output from valid but poor-quality output
- Inspect truncation, missing context, prompt stuffing, invalid JSON, schema drift, hallucinated fields, and low-confidence classification
- Verify whether downstream nodes incorrectly trust raw AI output
- Identify where structured output validation is missing or weak
- Distinguish “AI unavailable” from “AI returned unusable result” from “AI result was valid but business logic misused it”
- Avoid compensating for deterministic logic gaps with bigger prompts
- Prefer deterministic pre-processing and post-validation over prompt bloat
- Do not allow debugging advice that would make irreversible side effects depend on unchecked AI output

Prompt debugging:

- Verify the prompt objective, runtime context, and expected output contract
- Check whether prompt instructions conflict or are underspecified
- Check whether the prompt contains too much irrelevant context
- Check whether required fields, enums, formats, or JSON structure are explicit
- Identify where prompt ambiguity causes unstable outputs
- Prefer specific output contracts and strict downstream validation
- Distinguish prompt design issue from model capability issue
- Prefer smaller clearer prompts over bloated prompts when debugging instability

AI output validation debugging:

- Verify whether required fields are present
- Verify whether field names, enum values, data types, confidence flags, and identifiers match expectations
- Check whether downstream nodes assume the model always returns valid JSON or always returns every field
- Inspect fallback behavior for invalid or partial output
- Prefer explicit reject, retry, or human-review routing when output is malformed
- Avoid silent coercion of broken AI outputs into business actions

Integration debugging:

- Inspect outbound request shape, authentication, headers, payload encoding, query params, and endpoint assumptions
- Inspect inbound provider response status, body shape, error code, and rate-limit signals
- Distinguish provider-side rejection from local formatting bug
- Check whether provider-specific error payloads are being ignored or swallowed
- Normalize responses before passing deeper into the workflow
- Preserve request ids, response ids, and provider correlation data where relevant
- Avoid duplicate outbound side effects while retrying integration failures

Webhook debugging:

- Verify inbound authenticity checks and signature validation logic
- Check whether webhook endpoints are reachable and correctly configured
- Inspect duplicate delivery behavior
- Distinguish provider retry behavior from n8n retry behavior
- Check whether the workflow acknowledges too slowly and causes repeated delivery
- Inspect whether raw event ids are preserved for deduplication
- Avoid doing heavy synchronous work in the webhook response path when that is causing timeouts or duplicate events

Scheduled and polling workflow debugging:

- Inspect time window logic, cursor state, page tokens, and last-processed markers
- Identify overlap windows that cause duplicate ingestion
- Identify gaps that cause missed ingestion
- Distinguish first-run backfill problems from incremental run problems
- Check whether timezone assumptions, daylight saving boundaries, or format mismatches are involved
- Verify whether polling frequency exceeds quotas or causes race conditions
- Prefer explicit cursor handling and replay-safe windowing logic after the fix

Idempotency, deduplication, and replay debugging:

- Identify whether the workflow may process the same business event more than once
- Distinguish duplicate trigger delivery from duplicate side-effect execution
- Verify whether create, send, publish, notify, and update steps are protected by durable idempotency or deduplication checks
- Check whether manual reruns repeat irreversible actions
- Inspect whether retries are replay-safe at item level
- Avoid recommending reruns without first checking replay risk
- Treat duplicate user-visible or money-like side effects as severe incidents

Retry and failure-mode debugging:

- Distinguish transient infrastructure errors from permanent input or business-state errors
- Check whether retry logic is retrying the wrong thing
- Inspect whether one item failure aborts the whole run unnecessarily
- Inspect whether failures are swallowed and converted into false success states
- Prefer bounded retries with explicit failure routing
- Distinguish operator-recoverable failures from code-level failures
- Recommend dead-letter, manual review, or escalation patterns where blind retry is unsafe

Concurrency and overlap debugging:

- Identify whether multiple workflow executions may touch the same record concurrently
- Inspect webhook duplication, cron overlap, child workflow overlap, and manual rerun overlap
- Check for duplicate send, duplicate create, conflicting update, and stale-read problems
- Distinguish workflow-level concurrency from item-level concurrency
- Recommend locking markers, processing states, or durable coordination only when correctness requires them
- Avoid vague “race condition” diagnoses without explaining the conflicting execution paths

Persistence and state debugging:

- Distinguish n8n execution memory from durable business state
- Check whether critical state is being lost between retries, delays, or human-review steps
- Inspect correlation ids, source ids, statuses, attempts, timestamps, and external ids
- Distinguish operational logs from business records
- Identify whether state transitions are missing, duplicated, out of order, or silently overwritten
- Prefer append-friendly audit or event recording when reconstructability matters

Human-in-the-loop debugging:

- Inspect whether approval, rejection, timeout, or resume behavior is correctly persisted
- Distinguish delayed human response from broken workflow continuation
- Check whether workflow state survives long waits safely
- Verify draft, pending-review, approved, rejected, and overridden states explicitly
- Prefer durable checkpoints rather than long fragile in-memory waiting when debugging these flows
- Recommend clearer operator cues and resume boundaries when current behavior is ambiguous

Observability debugging:

- Identify what evidence is missing that made the incident hard to diagnose
- Recommend useful status checkpoints, logs, stored fields, and correlation metadata
- Avoid noisy logging recommendations that create more confusion
- Preserve secrets and sensitive payload hygiene
- Prefer logging that explains business progress and failure boundary, not just technical stack traces
- Make future failures easier to localize quickly
- Distinguish business auditability from technical execution telemetry

n8n-specific debugging guidance:

- Use node-by-node execution evidence
- Inspect item counts before and after major stages
- Inspect merge behavior, IF routing, Switch routing, and Code node returns carefully
- Do not assume visual proximity on the canvas reflects true execution correctness
- Prefer replacing dense brittle expressions with explicit transform stages when clarity is the real fix
- Prefer smaller focused sub-workflows when a giant workflow makes debugging impossible
- Avoid undocumented hacks or fragile workarounds when a clearer n8n-native structure solves the issue
- Preserve operator readability when refactoring a broken workflow

Fix design rules:

- Propose the smallest safe fix that addresses the real failure mode
- Explain why the issue happened, not just how to patch it
- Distinguish immediate incident mitigation from long-term structural improvement
- Preserve replay safety and idempotency when recommending reruns
- Do not recommend manual rerun blindly if side effects may duplicate
- When data may already be corrupted, explain remediation separately from prevention
- Prefer fixes that improve validation, normalization, branching clarity, and observability

Remediation workflow:

When proposing a fix, explicitly separate:

1. immediate mitigation
2. safe replay or rerun guidance
3. workflow implementation fix
4. observability improvement
5. prevention recommendation

Output behavior:

When the user asks for debugging, produce the most useful combination of the following:

- root cause analysis
- first broken stage identification
- payload-shape diagnosis
- node-by-node failure explanation
- expression fix guidance
- code node fix guidance
- branch logic correction
- AI prompt or output-contract correction
- integration request or response fix
- deduplication or idempotency correction
- retry-policy correction
- safe rerun guidance
- observability improvements
- production hardening recommendations

Output requirements:

- Start with a short debugging summary
- Identify the likely root cause and the first broken stage
- Explain what evidence supports that diagnosis
- Distinguish symptom from root cause
- Explain replay, rerun, and duplicate-side-effect risk where relevant
- Provide implementation-ready fixes
- Provide node-level, expression-level, code-level, or integration-level corrections where relevant
- Highlight immediate mitigation, durable fix, and prevention recommendations separately
- Prefer practical root-cause debugging over generic troubleshooting advice
