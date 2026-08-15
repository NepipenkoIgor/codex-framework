---
name: ai-llm-debug
description: Diagnose AI and LLM failures such as hallucinations, RAG retrieval defects, prompt injection, streaming faults, token truncation, tool-call loops, non-deterministic output, and evaluation regressions. Use when an AI feature produces unreliable, unsafe, slow, or malformed behavior.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 1.0
  argument-hint: "failure, reproduction, logs or trace, affected pipeline stage"
---

# AI/LLM Debugging

Start with a reproducible trace. Separate the failure into one or more boundaries: input, retrieval, prompt assembly, model call, tool execution, output validation, or downstream side effect. Do not change prompts or model settings before identifying the failing boundary. Generate stack context and verify the installed core/provider SDK pins, types, route runtime, proxy, decoder, configuration and applicable persistence schema as one compatibility chain against matching official documentation before interpreting version-specific messages, finish reasons, errors or stream events; migration is separate scope.

## Workflow

1. Record the input, model/provider version, prompt hash, token counts, latency, finish reason, retrieval results, tool calls, and validation result. Redact sensitive content.
2. Classify the failure: hallucination, no/wrong retrieval, stale embedding, injection, truncation, streaming, tool loop, schema failure, non-determinism, evaluation regression, or provider failure.
3. Reproduce with the smallest fixture. Choose repeated trials from the observed nondeterminism and confidence needed to distinguish the regression. Make the verification gate explicit: any observed cross-tenant disclosure, secret exposure, prompt-injection side effect, or other security leak immediately fails the entire verification, regardless of aggregate quality metrics.
4. Fix the causal boundary, not a symptom. Examples: re-index stale content, add store-level tenant filtering, reserve response tokens, validate structured output, or add a tool iteration limit.
5. Add a regression case that proves the failed input is now safe and correct.

## Required Checks

- For hallucination: confirm whether the asserted fact appears in retrieved context. Require a grounded no-answer when retrieval misses.
- For RAG: inspect query, embedding version, top-k scores, metadata filters, chunk timestamps, reranking, and tenant scope at the vector-store query.
- For prompt injection: test direct and retrieved-document injections; verify neither leaks a canary nor triggers unauthorized tools.
- For truncation: measure the full context budget and reserve output tokens. Never silently discard context.
- For provider/model: separate local assembly from provider request rejection, model behavior, finish reason, rate/capability limits, safety response, SDK parsing and upstream outage using request IDs and redacted raw boundary evidence.
- For streaming: check framing/decoder behavior, time to first event, proxy buffering, chunk assembly, abort cleanup, partial-versus-terminal completion and whether provider/tool work continued after disconnect.
- For tool loops: inspect stopping conditions and failures; cap repeated calls and surface an error after bounded retries.
- For structured output: validate at the boundary and retain the failed raw response only in safe, redacted diagnostics.

## Constraints

- Never let unvalidated model output trigger an irreversible action.
- Never rely on prompt wording alone for authorization or tenant isolation.
- Any observed cross-tenant disclosure, secret exposure, prompt-injection side effect or other security leak immediately fails verification even if aggregate quality metrics pass.
- Do not log raw prompts, retrieved documents, or output when they may contain secrets or PII.
- Do not treat an aggregate eval improvement as proof; evaluate the failing slice.

## Deliverable

- Failure classification and evidence
- Failing boundary and root cause
- Minimal remediation
- Regression/eval evidence
- Explicit confirmation that the any-security-leak fail-closed gate was applied
- Remaining uncertainty or monitoring needed
