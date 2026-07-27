---
name: ai-streaming
description: Implement LLM stream transport, decoding, incremental state, cancellation, backpressure, terminal semantics, and reconnect behavior. Use when streaming correctness is primary; do not use for an entire chatbot product or agent architecture.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "installed SDK/protocol, client/server runtime, event schema, abort propagation, terminal and side-effect semantics"
---

# AI Streaming

Run `python3 scripts/framework-stack-context.py project <path>` and inspect the exact core/provider SDK pins, installed types, route runtime, client adapter, proxy/CDN buffering, protocol headers, event schema, target-browser stream support, UI state, tools/side effects and tests as one compatibility chain. Existing pins and matching official SDK/runtime/browser documentation are authority; record the resulting response/decoder capability decision. Use `python3 scripts/framework-stack-context.py latest ai-sdk <other-technologies...>` only for greenfield selection. Treat SDK, protocol, runtime or client migration as separate scope.

Prefer the installed SDK's proven stream encoder/decoder and response method when client and server share its protocol. Current AI SDK docs expose `streamText(...).toUIMessageStreamResponse()` for UI-message streams, but apply only methods present in installed types. Do not parse an SDK-specific data protocol as generic SSE.

## Raw SSE Contract

Use a standards-tested SSE library where practical. A custom decoder must be incremental and covered by byte-level fixtures:

- Decode UTF-8 with a streaming `TextDecoder`; at EOF call the final `decode()` to flush pending bytes.
- Recognize CRLF, lone CR and lone LF even when separators cross chunks. Do not use `buffer.split('\n')` as the protocol parser.
- Accumulate one event until a blank line. Ignore comment lines beginning with `:`; parse the first colon in a field and remove at most one leading space from its value.
- Join multiple `data` fields with newline in order. Handle only intended `event`, `id` and `retry` semantics; unknown fields are ignored. Apply schema/size validation after event assembly.
- Keep decoded event boundaries typed and schema-validated. Isolate volatile SDK response helpers and provider-specific fields behind the one installed response/decoder adapter selected from matching documentation.
- Dispatch only according to the chosen protocol's termination rule. An EOF with an unterminated or malformed event is an interrupted protocol, not silent success. Flush complete text already received, preserve it as partial, and mark the message/generation nonterminal.
- Define explicit terminal, error and heartbeat events. Provider `[DONE]` strings are not universal application protocol.

For newline-delimited JSON or raw text, use a decoder designed and tested for that framing instead. Structured streaming must validate the terminal object; partial objects are preview state, never persisted as authoritative data.

## Abort, Backpressure, and Side Effects

- Propagate the incoming request/client signal through model generation, provider fetch, tool execution and cancellable downstream calls. Cancel readers/writers and remove listeners in `finally`. Treat abort as a distinct interrupted state.
- HTTP disconnect does not prove provider or tool cancellation. Record generation/tool operation identity and terminal state, and reconcile provider/tool outcomes that may have succeeded before abort.
- Do not retry a stream from the beginning after any ambiguous side effect or accepted tool call. Resume only when the provider/application protocol supplies a verified cursor/idempotency contract; otherwise start an explicit new generation after reconciliation.
- Let transport backpressure flow where supported. Batch UI commits according to measured rendering cost and visibility, not a universal frame interval; cap buffers and event sizes and define overflow behavior.
- Configure anti-buffering headers/proxy behavior for the deployed path and verify it. Heartbeat cadence, idle timeout and reconnect policy come from infrastructure/provider contracts, not remembered constants.

## State Model

Track at least request identity, generation identity, status (`connecting`, `streaming`, `completed`, `interrupted`, `error`), assembled content/parts, last verified cursor if supported, terminal metadata and tool-operation states. Only a validated terminal event can produce `completed`. Preserve the last good partial result on decoder/provider failure and keep retry/resume user-visible.

## Verification

- Byte splits inside UTF-8 code points, CRLF pairs and field names/values; LF, CRLF and lone CR; multiline data; comments/heartbeats; unknown fields; empty data; final decoder flush; malformed/oversized and unterminated EOF.
- Slow consumer, bounded buffer, proxy buffering, client abort, server disconnect, provider abort failure, background tab and component unmount.
- Error before first byte, after partial text and after provider/tool success; duplicate/reordered terminal events; resume cursor mismatch; no retry-from-start after ambiguous mutation.
- Unsafe incremental rendering, structured terminal validation, accessible status, persisted partial-versus-complete state and caller-visible reconciliation.
- Focused protocol/unit/integration/browser tests plus deployed header/timing observation. A local `curl` success alone does not prove production streaming.

## Output Contract

- Installed protocol/response method and framing schema
- Decoder, state, terminal and partial-result contracts
- Abort/backpressure/reconnect and side-effect reconciliation
- Byte-level and deployed-path evidence
- Residual provider, proxy and browser risks

Official foundations: [HTML server-sent events parsing](https://html.spec.whatwg.org/multipage/server-sent-events.html), [Streams Standard](https://streams.spec.whatwg.org/), and [AI SDK streamText](https://ai-sdk.dev/docs/reference/ai-sdk-core/stream-text).
