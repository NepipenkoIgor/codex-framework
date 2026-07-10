---
name: ai-llm-debug
description: Diagnose AI and LLM failures such as hallucinations, RAG retrieval defects, prompt injection, streaming faults, token truncation, tool-call loops, non-deterministic output, and evaluation regressions. Use when an AI feature produces unreliable, unsafe, slow, or malformed behavior.
metadata:
  version: 1.0
argument-hint: "failure, reproduction, logs or trace, affected pipeline stage"
---

# AI/LLM Debugging

Start with a reproducible trace. Separate the failure into one or more boundaries: input, retrieval, prompt assembly, model call, tool execution, output validation, or downstream side effect. Do not change prompts or model settings before identifying the failing boundary.

## Workflow

1. Record the input, model/provider version, prompt hash, token counts, latency, finish reason, retrieval results, tool calls, and validation result. Redact sensitive content.
2. Classify the failure: hallucination, no/wrong retrieval, stale embedding, injection, truncation, streaming, tool loop, schema failure, non-determinism, evaluation regression, or provider failure.
3. Reproduce with the smallest fixture. Run unstable cases at least three times; security leaks fail on any occurrence.
4. Fix the causal boundary, not a symptom. Examples: re-index stale content, add store-level tenant filtering, reserve response tokens, validate structured output, or add a tool iteration limit.
5. Add a regression case that proves the failed input is now safe and correct.

## Required Checks

- For hallucination: confirm whether the asserted fact appears in retrieved context. Require a grounded no-answer when retrieval misses.
- For RAG: inspect query, embedding version, top-k scores, metadata filters, chunk timestamps, reranking, and tenant scope at the vector-store query.
- For prompt injection: test direct and retrieved-document injections; verify neither leaks a canary nor triggers unauthorized tools.
- For truncation: measure the full context budget and reserve output tokens. Never silently discard context.
- For streaming: check time to first token, proxy buffering, chunk assembly, abort cleanup, and terminal completion handling.
- For tool loops: inspect stopping conditions and failures; cap repeated calls and surface an error after bounded retries.
- For structured output: validate at the boundary and retain the failed raw response only in safe, redacted diagnostics.

## Constraints

- Never let unvalidated model output trigger an irreversible action.
- Never rely on prompt wording alone for authorization or tenant isolation.
- Do not log raw prompts, retrieved documents, or output when they may contain secrets or PII.
- Do not treat an aggregate eval improvement as proof; evaluate the failing slice.

## Deliverable

- Failure classification and evidence
- Failing boundary and root cause
- Minimal remediation
- Regression/eval evidence
- Remaining uncertainty or monitoring needed
