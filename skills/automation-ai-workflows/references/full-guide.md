# AI Workflow Pattern Guide

Load this guide only after the main skill identifies an irreducibly probabilistic step or a selected provider/workflow runtime.

## Decision Record

For each stage record: business outcome, authoritative input, deterministic alternative, reason a model is needed, versioned input/output schema, acceptable abstention/error behavior, downstream consequence, latency/cost source, and recovery owner. Use deterministic code for authorization, validation, mapping, deduplication, fixed routing, policy and side effects.

## Model Boundary

- Keep instructions, untrusted source content and policy data structurally separate. Prompt wording and sanitization do not authorize actions.
- Produce a closed/versioned schema where possible. Validate syntax, business rules, provenance and resource authorization outside the model. A well-formed result may still be false or unauthorized.
- Confidence scores are not calibrated guarantees. Choose review/abstention gates from a labeled evaluation set and product harm, then monitor them by slice; do not copy a universal threshold.
- Preserve input/prompt/model/tool/schema versions and source identities needed for replay without logging secrets or unnecessary personal data.

## Side Effects and Recovery

- Persist the workflow state and idempotency/operation identity before invoking a consequential side effect. Approval binds the authenticated approver, exact normalized target/parameters/version, consequence, expiry and operation.
- Retries are step-specific. After timeout or disconnect, reconcile provider/resource state before retrying an operation that may have succeeded. Replaying an event or checkpoint must not repeat an external action.
- Human rejection, expired approval, invalid model output, provider outage and budget exhaustion are explicit terminal or resumable states, not prompts asking the model what to do.
- A deterministic disable path bypasses the model or routes work to review while retaining audit and recovery state.

## Evaluation and Rollout

Build representative slices for ambiguous/empty/adversarial input, schema failure, indirect injection, provider drift, duplicate triggers, timeout-after-success, approval changes and downstream partial failure. Evaluate task outcome, abstention/review, safety, latency and cost together. Define an authorized cohort/canary rollout plan with gates derived from baseline and product harm, plus tested rollback and in-flight reconciliation; execution belongs to the authorized implementation or deployment owner, not this read-only design skill.

## Provider Capability

Inspect installed SDK types and current official docs for structured output, streaming, tool, retry and usage behavior. Preserve existing pins unless migration is in scope. Keep provider-specific adapters behind the versioned workflow contract.

Official foundations: [NIST AI RMF](https://www.nist.gov/itl/ai-risk-management-framework) and [OWASP LLM Prompt Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html).
