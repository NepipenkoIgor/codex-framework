---
name: prompt-engineering
description: Design deterministic, structured prompts for AI-driven automations — n8n workflows, Claude/OpenAI/Gemini pipelines, AI decision nodes, extraction, classification, and structured JSON outputs
metadata:
  version: 2.2
  argument-hint: "task type (extraction/classification/routing), input schema, output format (JSON), models in use"
---

Design prompts for $ARGUMENTS.

Platforms and scope:
- n8n AI nodes
- Claude API
- OpenAI API
- Gemini API
- AI automation pipelines
- AI workflow decision nodes
- AI classification
- AI extraction
- AI summarization
- AI enrichment
- AI content generation
- AI routing logic

Core prompt engineering principles:

- Prefer deterministic prompts over creative prompts when used in automation
- Design prompts that produce predictable and structured outputs
- Prefer JSON outputs when the result will be consumed by automation systems
- Avoid prompts that rely on ambiguous instructions
- Avoid prompts that rely on hidden assumptions
- Avoid prompts that depend on model creativity when deterministic output is required
- Keep prompts compact and focused
- Separate system instructions from runtime context
- Separate static prompt layers from dynamic prompt layers
- Prefer schema-driven output expectations
- Design prompts that are resilient to malformed input
- Design prompts that are resilient to incomplete context
- Prefer prompts that fail safely rather than hallucinate
- Avoid prompts that allow AI to invent missing facts silently

Prompt architecture goals:

- predictable output structure
- low hallucination risk
- minimal token usage
- clear task boundaries
- explicit output contracts
- reusable prompt templates
- safe integration with automation systems
- reliable downstream parsing

Prompt design workflow:

1. Identify the business task the AI must perform
2. Define the expected output format
3. Define the input data that will be available
4. Identify ambiguous areas that must be constrained
5. Define validation expectations for the output
6. Design system instructions
7. Design task instructions
8. Define the structured output schema
9. Add guardrails against hallucination
10. Ensure the prompt is automation-safe

Prompt structure guidelines:

Prompts should generally contain the following sections:

- system instruction
- task description
- input context
- output contract
- constraints
- failure behavior instructions

Example structure:

System role:
Explain the AI's responsibility.

Task:
Explain the exact operation the AI must perform.

Input:
Define what data will be provided.

Output format:
Define exact JSON schema or structure.

Constraints:
Define rules that limit hallucination and ensure predictable behavior.

Failure behavior:
Define what the AI must do when input is insufficient.

```
// Complete structured prompt template for a lead classification automation step

SYSTEM:
You are a lead classification engine for a B2B SaaS company.
You receive inbound form submissions and classify them.
You must output valid JSON only. No markdown. No explanation outside JSON.

TASK:
Classify the lead into exactly one category.
Extract company information if present.
Assign a confidence score between 0 and 1.

INPUT:
{
  "name": "{{name}}",
  "email": "{{email}}",
  "message": "{{message}}"
}

OUTPUT SCHEMA:
{
  "category": "sales_qualified | product_question | partnership | spam | unknown",
  "confidence": <number between 0 and 1>,
  "company_name": "<string or null>",
  "summary": "<one sentence, max 30 words>",
  "requires_review": <true if confidence < 0.7 or category is unknown>
}

CONSTRAINTS:
- Use only the provided input. Do not invent facts.
- If the message is too short or ambiguous, set category to "unknown" and confidence to 0.3.
- If no company name is mentioned, set company_name to null.
- Do not guess the company from the email domain.
```

Structured output design:

When prompts are used in automation:

- Prefer JSON output
- Explicitly define fields
- Explicitly define types
- Explicitly define allowed values
- Avoid free-form responses when the output feeds downstream automation
- Prefer arrays, objects, and enums over descriptive paragraphs
- Validate that the output can be parsed deterministically

Example JSON schema pattern:

{
"classification": "string",
"confidence": "number",
"reason": "string"
}

Rules:

- No additional fields
- No markdown
- No explanations outside JSON
- Output must be valid JSON

Hallucination prevention:

Prompts must include guardrails:

- If information is missing, return null fields
- If classification is uncertain, lower confidence score
- Do not invent missing data
- Do not fabricate sources
- Do not assume unstated facts
- Use only provided input

Example instruction:

If the input does not contain enough information to answer the task,
return null values rather than inventing data.

Token efficiency:

Prompts used in automation must minimize tokens.

Rules:

- Avoid unnecessary narrative instructions
- Avoid repeated instructions
- Avoid redundant examples unless needed
- Prefer concise structured instructions
- Avoid embedding large irrelevant context

Prompt reuse and templates:

Design prompts so they can be reused.

Separate:

- static instructions
- dynamic runtime context
- task input

Example pattern:

System instructions:
(static)

Task:
(static)

Input data:
(dynamic)

Output format:
(static)

This allows automation pipelines to inject runtime data safely.

AI decision node prompts:

When prompts are used for routing decisions:

- Always output deterministic classification
- Always include a confidence score
- Avoid natural language explanations unless needed
- Prefer enums over free text

Example:

{
"decision": "approve | reject | review",
"confidence": number
}

Extraction prompts:

When extracting structured data:

- explicitly list expected fields
- define field types
- define missing-field behavior
- instruct the model not to guess

Example:

{
"company_name": "string | null",
"email": "string | null",
"phone": "string | null"
}

Summarization prompts:

For summarization tasks:

- specify length limits
- specify tone if required
- specify content focus
- avoid vague instructions like "summarize well"

Example:

Produce a summary under 120 words focusing only on key facts.

Content generation prompts:

When generating text for marketing or content workflows:

- define tone
- define style
- define word count
- define formatting constraints
- avoid vague creative freedom

Example constraints:

- 2 paragraphs maximum
- no emojis
- no hashtags
- plain text only

Prompt validation rules:

Before using a prompt in automation:

- Verify that output format is deterministic
- Verify that output can be parsed reliably
- Verify that hallucination risks are mitigated
- Verify that missing input does not break the prompt
- Verify that the prompt does not rely on model-specific quirks

Common prompt anti-patterns:

Avoid:

- vague prompts
- prompts without output schema
- prompts that mix tasks
- prompts that allow the model to invent missing data
- prompts that rely on formatting like markdown tables
- prompts that produce long narrative output for automation systems
- prompts that embed large irrelevant context

Automation safety rules:

Prompts must not directly trigger irreversible actions.

Example unsafe pattern:

AI output → payment → email → deletion

Instead:

AI output → validation → rule check → action

Always design prompts so their outputs can be validated before side effects.

AI cost awareness:

Prompt design must consider cost.

Rules:

- avoid long prompts
- avoid unnecessary examples
- avoid large context windows
- prefer short deterministic prompts
- prefer smaller models when reasoning complexity is low

When to use AI:

Use AI when:

- classification requires semantic reasoning
- summarization requires contextual compression
- extraction requires natural language parsing
- generation requires creative transformation

Do not use AI when:

- deterministic rules solve the task
- simple parsing solves the task
- mapping or filtering solves the task
- regex or schema validation solves the task

Output behavior:

When the user asks for prompts, provide:

- system instructions
- task instructions
- input schema
- output schema
- guardrails
- example output when useful
- explanation of why the prompt is structured this way

Output requirements:

- Start with a short prompt design summary
- Provide the final prompt
- Provide the expected JSON output schema when applicable
- Explain guardrails and hallucination protection
- Explain how the prompt integrates safely into automation workflows
- Mention assumptions when input context is incomplete
- Prefer production-ready prompts over theoretical prompt engineering advice
