---
name: prompt-management
description: Manage LLM prompts — versioning, A/B testing, template systems, evaluation pipelines, prompt registries, and deployment workflows
metadata:
  version: 1.1
  argument-hint: "storage backend (file/database), template engine, testing framework, models to track"
---

Implement prompt management infrastructure for $ARGUMENTS.


## Architecture

```
Prompt Source (DB / files / CMS)
  |
  v
Prompt Registry (load, resolve version, cache)
  |
  v
Template Engine (variable injection, partials, conditionals)
  |
  v
Output Schema (structured output enforcement)
  |
  v
LLM Provider (OpenAI, Anthropic, etc.)
  |
  v
Observability (log prompt version, tokens, latency, result quality)
```

## Template Store Patterns

### File-Based (Git-Versioned)

```
prompts/
  summarize/
    v1.md             # prompt text with {{variables}}
    v2.md             # new version
    schema.json       # output schema (Zod or JSON Schema)
    config.yaml       # model, temperature, max_tokens, active version
    test-cases.yaml   # input/output pairs for regression testing
  classify-intent/
    v1.md
    schema.json
    config.yaml
    test-cases.yaml
```

Pros: version control via git, code review for prompt changes, CI integration.
Cons: requires deployment to update prompts, no runtime A/B testing without feature flags.

### Database-Backed

Store templates in DB with columns: `id`, `slug`, `version`, `content`, `model`, `temperature`, `max_tokens`, `output_schema`, `status` (draft/active/archived), `created_at`, `activated_at`. Index on `(slug, status)` for fast active lookups.

Pros: runtime version switching, A/B deployment. Cons: needs admin UI, migration management, cache invalidation.

## Template Engine

### Variable Injection

Use Handlebars with strict mode (fail on undefined variables). Cache compiled templates by `{slug}:v{version}`. Validate all required variables before rendering.

### Template Syntax

```markdown
You are a {{role}} assistant. {{#if context}}Context: {{context}}{{/if}}
{{#each examples}}Example: {{this.input}} → {{this.output}}{{/each}}
Question: {{question}}
```


### Template Rules

- Use Handlebars or Mustache for logic-less templates (conditionals, loops, partials)
- Enable strict mode -- fail on undefined variables rather than silently rendering empty
- Register custom helpers for common transformations (truncate, join, date format)
- Keep templates readable -- complex logic belongs in code, not in templates
- Validate all required variables are provided before rendering

## Version Management

### Version Lifecycle

```
Draft -> Review -> Active -> Archived
           |
           v
        Rejected (back to Draft)
```

### Version Resolution

Implement a registry that loads explicit versions on request or falls back to active version with TTL caching (1 min default). Invalidate cache on version activation.

### Version Migration

Activate new versions atomically: set current active to archived, promote new version to active, invalidate cache. Rollback by promoting most recent archived version.

## A/B Prompt Deployment

### A/B Testing Workflow

Assign users deterministically via hash(slug:userId) % 100 to traffic-weighted variants. Track events with `user_id`, `variant_id`, `prompt_version`, `quality_score`. Require 100+ samples per variant, p < 0.05 for significance, then auto-promote winner.

## Structured Output Enforcement

### Implementation

- Resolve template from registry, render with variables, call LLM with `response_format: { type: 'json_schema', json_schema: zodToJsonSchema(outputSchema) }`
- Always validate output with Zod even when using provider-enforced schemas -- models can still produce invalid JSON
- On schema violation: retry up to 2 times, injecting the validation error into the template variables as `_retry_error` so the LLM can self-correct
- Throw `PromptOutputError` with slug, version, and validation details for observability

## Prompt Caching

### When to Cache

- Identical input produces identical output (deterministic prompts with temperature 0)
- Expensive prompts (large context, slow models)
- Repeated inputs (common questions, standard classifications)

### Cache Implementation

- Cache key: `prompt:{slug}:v{version}:{hash(variables)}`
- Use Redis with TTL (default 1 hour)
- Hash input variables deterministically for cache key
- Invalidate all cache entries for a slug when version changes: `SCAN prompt:{slug}:*`

Rules:
- Cache only deterministic prompts (temperature 0 or very low)
- Key includes prompt version -- new version invalidates cache
- Set TTL based on how often the underlying data changes
- Invalidate cache when prompt version changes
- Do not cache prompts with user-specific context that changes frequently

## Observability

### Observability

Log: slug, version, model, tokens_input, tokens_output, latency_ms, cache_hit, quality_score. Track metrics: daily volume, avg tokens, avg latency, error rate, cache hit %, quality distribution, adoption %. Implement diff tooling for version comparisons.

## CI Integration

### Prompt Regression Testing

```yaml
# .github/workflows/prompt-tests.yml
name: Prompt Regression Tests
on:
  pull_request:
    paths:
      - 'prompts/**'

jobs:
  test-prompts:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run prompt regression tests
        run: npm run test:prompts
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: prompt-test-results
          path: test-results/prompts/
```

### Test Case Format

```yaml
# prompts/summarize/test-cases.yaml
test_cases:
  - name: "Short article summary"
    variables:
      article: "The Federal Reserve announced a 25 basis point rate cut..."
      max_length: "2 sentences"
    assertions:
      - type: contains
        value: "rate cut"
      - type: max_tokens
        value: 100
      - type: schema_valid
        schema: ./schema.json

  - name: "Empty input handling"
    variables:
      article: ""
      max_length: "2 sentences"
    assertions:
      - type: contains_any
        values: ["no content", "empty", "nothing to summarize"]

  - name: "Long article summary"
    variables:
      article: "{{fixtures/long_article.txt}}"
      max_length: "3 sentences"
    assertions:
      - type: max_tokens
        value: 150
      - type: llm_judge
        criteria: "Does the summary capture the main points of the article?"
        threshold: 0.8
```

### Test Runner

- Load template and test cases for the slug
- For each test case: render template with variables, call LLM, run assertions
- Assertion types: `contains`, `max_tokens`, `schema_valid`, `llm_judge`, `contains_any`
- Return test report with pass/fail per assertion, output text, token usage, and overall pass rate

## Anti-Patterns

- Template injection vulnerabilities -- user input rendered as template syntax
- Caching non-deterministic prompts -- same input returns stale different-era results
- A/B testing without sufficient sample size -- promoting based on noise, not signal
- Not sanitizing variables before injection -- PII leaks into logs or caches

## Implementation Workflow

1. Choose storage pattern: file-based (git) or database-backed
2. Set up template engine with variable injection and strict mode
3. Implement prompt registry with version resolution and caching
4. Add structured output enforcement with schema validation
5. Build version management: create, activate, rollback, archive
6. Add A/B deployment with deterministic user assignment
7. Implement observability: logging, metrics, diff tooling
8. Write test cases for each prompt template
9. Set up CI pipeline for prompt regression testing
10. Build admin UI or CLI for prompt management (if database-backed)

## Output Format

For each prompt management implementation:

```
Store:             [file-based / database-backed]
Template Engine:   [Handlebars / Mustache / custom]
Version Strategy:  [sequential numbering, activation/archival]
Caching:           [Redis with TTL / in-memory / none]
A/B Testing:       [traffic splitting approach]
Output Enforcement:[JSON Schema / Zod / none]
Observability:     [metrics tracked, logging approach]
CI Testing:        [regression test framework]
```

## Done Criteria

- All prompts stored in the registry with version tracking (no hardcoded strings)
- Template rendering validates required variables before calling LLM
- Version activation and rollback work atomically
- Structured output is schema-validated after every LLM call
- Prompt cache reduces redundant LLM calls for deterministic prompts
- Observability logs capture prompt version, tokens, latency, and quality per call
- CI runs regression tests on prompt changes and blocks merge on failure
- A/B experiments assign users deterministically and track quality metrics per variant
