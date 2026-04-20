---
name: automation-ai-workflows
description: Design AI-driven automation workflows combining deterministic logic and LLM reasoning API
metadata:
  version: 1.4
  argument-hint: "workflow type (classification/extraction/enrichment/generation), LLM provider (Claude/OpenAI/Gemini), deterministic vs reasoning balance, human-in-loop requirement"
---

Design the AI workflow architecture for $ARGUMENTS.

Applicable to any AI-powered automation workflow, including n8n, Claude API, OpenAI API, Gemini API, and any LLM-driven pipeline involving classification, extraction, summarization, generation, enrichment, routing, or human-in-the-loop review.

Core architecture principles:

- Use AI only where semantic reasoning, summarization, extraction, generation, ranking, routing, or ambiguity handling adds meaningful value
- Prefer deterministic workflow logic where rules, mapping, filtering, validation, or fixed branching already solve the problem
- Separate workflow orchestration from AI reasoning responsibilities
- Separate prompt design from business-side effects
- Keep AI outputs structured, validated, and inspectable
- Prefer production-safe defaults over creative but unstable behavior
- Avoid allowing raw AI free-text to directly trigger irreversible side effects
- Prefer explicit decision boundaries between deterministic logic and model logic
- Prefer explicit fallback paths, review paths, and degraded-mode behavior
- Keep AI usage cost-aware and latency-aware
- Preserve reproducibility, traceability, and operator visibility where relevant
- Design for real-world uncertainty, malformed input, provider failure, and partial context
- Prefer small, clear AI steps over giant magical prompts that try to do everything at once

Architecture goals:

- clear boundaries between rules and AI
- explicit AI responsibilities
- predictable structured outputs
- low hallucination risk
- safe action gating
- human-review capability where needed
- good cost and latency control
- maintainable orchestration
- observable AI decision flow
- implementation-ready workflow structure
- reliable downstream automation behavior

Architecture completeness checklist:

- Identify where AI is truly needed and where deterministic logic is enough
- Identify which workflow stages are classification, extraction, summarization, generation, ranking, validation, or routing
- Identify which workflow stages must remain deterministic and non-AI
- Identify where structured output contracts are required
- Identify where human review is required, optional, or unnecessary
- Identify where AI output could create business risk if incorrect
- Identify where confidence scoring, abstention, or fallback behavior is needed
- Identify cost-sensitive and latency-sensitive workflow stages
- Identify model choice boundaries for simple versus complex reasoning
- Identify input preparation and context assembly needs
- Identify output validation and normalization needs
- Identify idempotency, deduplication, retry, and replay risks around AI-driven stages
- Identify observability, auditability, and operator support needs

Architecture workflow:

1. Identify the business goal and target workflow outcome
2. Identify the major workflow stages and business decisions
3. Separate deterministic workflow stages from AI-powered stages
4. Define what each AI stage must decide, generate, extract, or summarize
5. Define the input contract for each AI stage
6. Define the structured output contract for each AI stage
7. Define validation, fallback, and review behavior
8. Define side-effect boundaries and safety checks
9. Define model usage, cost controls, and latency expectations
10. Map the design into implementation-ready workflow structure

Problem framing and scope:

- Clarify the business outcome before inserting AI into the workflow
- Distinguish core required intelligence from optional nice-to-have enrichment
- Prefer explicit assumptions when requirements are incomplete
- Avoid inventing AI usage just because AI is available
- Prefer workflows that solve the stated problem first and use AI only where it materially improves the result
- Avoid turning deterministic pipelines into fragile AI systems without reason

AI boundary design:

- Explicitly define which parts of the workflow are deterministic and which parts are model-driven
- Use deterministic logic for:
    - schema validation
    - field mapping
    - fixed filters
    - rule-based allow or deny checks
    - idempotency checks
    - deduplication
    - required-field enforcement
    - post-AI validation
    - final action gating
- Use AI for:
    - semantic classification
    - fuzzy extraction from natural language
    - summarization
    - ranking when deterministic scoring is insufficient
    - content drafting
    - enrichment from messy text
    - ambiguous routing where rules are brittle
- Avoid using AI for simple transformations that are better handled with rules

AI workflow stage types:

When designing AI workflows, classify each AI stage as one or more of the following:

- classifier
- extractor
- summarizer
- generator
- ranker
- router
- evaluator
- normalizer
- reviewer-assist
- decision-support

For each stage define:
- purpose
- input data
- expected output
- acceptable error tolerance
- fallback behavior
- downstream consumer
- risk level if wrong

Classifier design:

For classification stages:

- Prefer closed-set outputs using enums or fixed labels
- Define confidence behavior explicitly
- Distinguish confident classification from uncertain classification
- Provide abstain or review outcomes when appropriate
- Avoid open-ended category invention unless the business case truly needs it
- Keep labels semantically clear and operationally useful

Extractor design:

For extraction stages:

- Explicitly list fields to extract
- Define expected types and missing-field behavior
- Do not allow the model to guess missing facts
- Prefer null over hallucinated values
- Distinguish hard-required fields from optional fields
- Normalize extracted values before downstream usage
- Keep extraction logic structured and schema-shaped

Summarizer design:

For summarization stages:

- Define the target summary purpose clearly
- Define length boundaries
- Define whether the summary is for machine consumption, human review, or downstream generation
- Preserve source identifiers and relevant factual anchors
- Avoid summaries that introduce unsupported claims
- Prefer factual compression over stylistic creativity unless content marketing is the actual goal

Generator design:

For generation stages:

- Define the target output type clearly
- Define tone, audience, format, and content boundaries explicitly
- Distinguish generation for drafts from generation for automatic publication
- Prefer draft or review flow for public-facing or business-critical content when risk is material
- Avoid direct publishing from weakly controlled generation unless risk is low and constraints are strong
- Preserve reusable prompt inputs and output variants where relevant

Router design:

For routing stages:

- Prefer deterministic routing rules first
- Use AI only when routing depends on nuanced semantic interpretation
- Keep possible destinations explicit
- Include review or fallback destinations for uncertainty
- Avoid free-form routing results
- Prefer finite routing outputs with downstream contract stability

Decision-support versus decision-execution:

- Distinguish AI making a recommendation from AI authorizing an action
- Prefer AI as decision-support for high-risk actions
- Require deterministic checks, policy checks, and validation before decision-execution
- Avoid granting AI unchecked authority over money movement, destructive actions, irreversible publishing, customer-visible commitments, or access changes
- Define explicit approval boundaries for risky workflows

Prompt and context architecture:

- Distinguish static system instructions from runtime task instructions and dynamic context
- Keep prompts compact and bounded
- Prefer context assembly layers before the AI step
- Avoid dumping raw large payloads into prompts without shaping
- Include only relevant source data
- Define output contract before refining the prompt
- Prefer reusable prompt patterns across similar workflow stages
- Track prompt identity or prompt version where reproducibility matters

Structured output requirements:

- Prefer JSON outputs for automation workflows
- Define exact fields, allowed values, and expected types
- Avoid markdown, prose wrappers, or mixed-format outputs when automation consumes the result
- Define whether additional fields are forbidden
- Require explicit nulls or empty arrays where needed instead of omitted unpredictable fields
- Prefer schema-shaped outputs that can be validated deterministically
- Ensure downstream stages consume validated structured outputs rather than raw model text

```json
// Structured output contract with validation schema
{
  "classification": {
    "type": "string",
    "enum": ["lead", "support", "spam", "unknown"]
  },
  "confidence": {
    "type": "number",
    "minimum": 0,
    "maximum": 1
  },
  "extracted_fields": {
    "company_name": "string | null",
    "contact_email": "string | null",
    "intent": "string | null"
  },
  "requires_review": {
    "type": "boolean",
    "description": "true when confidence < 0.7 or classification is unknown"
  }
}
```

```typescript
// Post-AI deterministic validation gate
function validateAIOutput(raw: unknown): ValidatedResult | ReviewRequired {
  const parsed = OutputSchema.safeParse(raw);
  if (!parsed.success) return { action: "review", reason: "malformed_output" };

  const { classification, confidence, extracted_fields } = parsed.data;
  if (confidence < 0.7 || classification === "unknown") {
    return { action: "review", reason: "low_confidence", data: parsed.data };
  }
  if (classification === "lead" && !extracted_fields.contact_email) {
    return { action: "review", reason: "missing_required_field", data: parsed.data };
  }
  return { action: "proceed", data: parsed.data };
}
```

Validation architecture:

- Validate AI outputs before any downstream side effect
- Distinguish schema validation from business validation
- Reject malformed output explicitly
- Normalize fields before downstream use
- Define what happens on partial output, low confidence, invalid enum, or unexpected field
- Prefer explicit retry, fallback, or review routing instead of silent tolerance
- Use deterministic validators and policy gates after AI output
- Never assume AI outputs are safe just because they are well-formed JSON

Confidence, abstention, and fallback design:

- Define when the model may abstain
- Define what low-confidence means operationally
- Prefer review-required or fallback-required states when uncertainty matters
- Avoid forcing the model to pretend certainty where evidence is weak
- Define degraded-mode behavior when model output is invalid or unavailable
- Provide deterministic fallback where feasible
- Consider secondary-model or simplified fallback only when justified
- Prefer human review over unsafe automation in ambiguous high-risk cases

Human-in-the-loop design:

- Identify which stages benefit from review, approval, editing, or override
- Distinguish fully automated flow from draft-assisted flow
- Use human review for:
    - public publishing with material reputational risk
    - important external messaging
    - legal or financial interpretation
    - ambiguous extraction with significant downstream consequences
    - high-impact routing decisions
- Preserve draft, pending-review, approved, rejected, edited, and overridden states where relevant
- Avoid long fragile wait states without durable checkpoints
- Define clear resume behavior after review

Side-effect safety:

- Separate AI output from action execution
- Place validation, policy checks, and business-rule checks between AI and side effects
- Treat these as high-risk side effects:
    - sending external messages
    - publishing content
    - creating or updating CRM records
    - opening tickets
    - triggering downstream workflows
    - financial or access-related changes
- Avoid direct AI-to-action pipelines without deterministic guardrails
- Design explicit no-send, no-publish, no-update safety states when validation fails

Cost-aware AI architecture:

- Identify expensive stages and gate them with deterministic pre-filters
- Avoid sending low-value or duplicate inputs into LLM calls
- Prefer cheaper models for simple classification, extraction, or rewriting tasks when acceptable
- Reserve stronger models for ambiguity, synthesis, or higher-value reasoning
- Batch or cache where safe and useful
- Define when to skip AI entirely
- Track token usage, latency, and model choice where cost visibility matters
- Prefer architecture improvements before simply switching to bigger models

Latency-aware architecture:

- Distinguish interactive from background workflows
- Keep latency-sensitive paths short and bounded
- Avoid chaining multiple AI calls synchronously if one staged result is enough
- Use async or deferred processing where user-facing latency does not require immediate completion
- Distinguish “fast enough” classification from “deep reasoning” stages
- Prefer background generation for heavier content pipelines when appropriate

Model selection guidance:

- Use smaller or cheaper models for:
    - simple classification
    - straightforward extraction
    - basic normalization
    - lightweight rewriting
- Use stronger models for:
    - ambiguous multi-factor reasoning
    - nuanced summarization
    - higher-stakes drafting
    - complex semantic routing
    - quality-sensitive synthesis
- Avoid overusing premium models for tasks solvable by deterministic logic or simpler models
- Tie model choice to error tolerance, value of the decision, latency needs, and cost limits

Multi-stage AI pipeline design:

When a workflow uses multiple AI stages:

- Prefer decomposing tasks instead of one giant prompt when decomposition improves control
- Separate classify, extract, summarize, and generate stages when their output contracts differ materially
- Avoid chaining AI outputs blindly without validation
- Keep each stage’s responsibility narrow and inspectable
- Preserve stage metadata and outputs for debugging and quality monitoring
- Avoid unnecessary multi-step AI chains when one bounded stage is enough

Evaluation and quality control:

- Define what “good enough” means for each AI stage
- Distinguish correctness, usefulness, formatting compliance, and business safety
- Preserve representative examples or test cases where relevant
- Track recurring failure patterns: malformed JSON, wrong label, hallucinated field, weak summary, unsafe generation
- Design prompts and validation together, not separately
- Prefer production feedback loops over theoretical perfection

AI incident and failure design:

- Assume AI providers may fail, timeout, rate-limit, or produce malformed output
- Define explicit behavior for:
    - provider unavailable
    - provider timeout
    - invalid output
    - partial output
    - low-confidence output
    - contradictory output
- Distinguish retriable failure from review-required failure
- Avoid retry storms for bad prompts or invalid business context
- Prefer clear failure states and operator visibility
- Preserve replay safety and avoid duplicate side effects when rerunning AI-driven flows

Observability and traceability:

- Preserve source identifiers, workflow ids, item ids, prompt ids, model ids, attempt counts, timestamps, and confidence indicators where useful
- Distinguish technical execution logs from business decision records
- Avoid logging sensitive raw prompt data unnecessarily
- Make AI decisions inspectable after the fact
- Prefer observability that explains:
    - what input the model received
    - what structured output it produced
    - what validation result occurred
    - what downstream action happened or was blocked
- Design for operator comprehension, not just raw log volume

Security and trust boundaries:

- Avoid exposing secrets or privileged context unnecessarily to the model
- Minimize sensitive data in prompts where possible
- Distinguish public content, internal data, and sensitive business data
- Avoid trusting model output as if it were verified truth
- Use explicit policy boundaries before privileged actions
- Keep risky privileged operations narrow and auditable

Anti-patterns to avoid:

- Avoid using AI where deterministic logic already solves the problem
- Avoid giant prompts that mix classification, extraction, scoring, generation, and action instructions in one blob
- Avoid free-form text outputs when automation expects structure
- Avoid direct AI-to-side-effect pipelines without validation
- Avoid forcing certainty from incomplete inputs
- Avoid cost-heavy multi-step LLM chains with no measurable value
- Avoid uncontrolled context stuffing
- Avoid replacing workflow architecture with “ask the model everything”
- Avoid making business correctness depend on prompt cleverness alone
- Avoid hiding business rules inside the prompt when they should be deterministic policy checks

Implementation mapping:

- Translate the architecture into implementation-ready workflow stages, AI stages, validation stages, and side-effect boundaries
- Prefer concrete stage guidance over abstract AI theory
- Make clear which parts are deterministic preprocessing, AI reasoning, deterministic validation, human review, and external action
- Make clear how AI output moves into safe downstream execution
- Prefer architecture output that can be turned directly into n8n builds, API calls, prompts, validators, and review flows

Contract output requirements:

For each AI stage include:

- purpose
- AI stage type
- input contract
- context assembly rules
- model recommendation level
- output contract
- validation rules
- confidence or abstention behavior
- fallback behavior
- human review behavior
- downstream consumer
- side-effect risk if wrong
- observability notes

For each non-AI stage surrounding AI include:

- purpose
- deterministic rules performed
- payload shape
- validation responsibility
- action gating responsibility
- replay and idempotency notes

Output requirements:

- Start with a short AI workflow architecture summary
- Identify where AI should be used and where deterministic logic should remain
- Define the major AI and non-AI workflow stages
- Define input contracts, output contracts, and validation boundaries for each AI stage
- Define confidence, fallback, and review behavior
- Define side-effect safety boundaries and action gating rules
- Define model usage, cost, and latency considerations
- Define observability and operational considerations
- Map the design into implementation-ready workflow structure
