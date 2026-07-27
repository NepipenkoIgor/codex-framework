---
name: chatbot-implement
description: Implement a conversational AI product boundary including trusted conversation state, streaming UI, tools and approvals, persistence, safe rendering, cancellation, and human handoff. Use when the end-to-end chat experience is primary; do not use for transport-only streaming or agent-system architecture.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "installed AI/UI SDK, authoritative history, tools and side effects, persistence, rendering, handoff and privacy requirements"
---

# Chatbot Implementation

Run `python3 scripts/framework-stack-context.py project <path>` and inspect manifests/lockfiles, installed AI core and UI-adapter types, React/client runtime, provider adapter, server route/runtime, protocol, model/provider configuration, conversation ownership, persistence, tool contracts, auth, rendering and tests as one compatibility chain. Existing pins and matching official documentation for that installed line are authority; keep version-specific SDK mechanics behind one recorded adapter/migration seam, and treat migration as separate scope. For greenfield selection use `python3 scripts/framework-stack-context.py latest ai-sdk <other-technologies...>` and verify the generated manifest and current [AI SDK documentation](https://ai-sdk.dev/docs).

## Trust Boundary

- The browser submits an authenticated conversation ID plus the new user-authored content and allowed attachment references. Load authoritative prior messages server-side. If the installed UI protocol requires a message array, validate its full structure and reconcile it against server-owned history; never forward client-supplied `system`, `tool`, approval, tool-result, or forged assistant roles to the model or executor.
- Construct system/developer instructions, active tools, tool schemas, resource context and provider/model selection on the trusted server from authorized application policy. Prompt text cannot grant access.
- Validate request size, content parts, attachment ownership/type and metadata. In an installed AI SDK line that exposes them, apply `validateUIMessages()` to the reconciled UI protocol and `convertToModelMessages()` to trusted messages before `streamText`; verify both signatures in installed types and do not cast raw JSON to model-message types.
- Authorize conversation read/write by user and tenant on every request. Use server-generated stable identities for conversation, message, generation and tool operations; define concurrency/version behavior for two tabs and regenerate/edit flows.

## Installed AI SDK Capability

Current AI SDK lines may expose `useChat` with caller-owned input state, `sendMessage`, and a transport object rather than the older internally managed `input`/`handleSubmit` API. Use only the hook, transport, status, message-parts and reconnect APIs present in installed `@ai-sdk/*` types and matching docs. Likewise, return the `streamText` response method exposed by the installed core line; current docs describe `toUIMessageStreamResponse()`, while older pins may differ. Verify the actual client/server protocol together.

## Tools, Approval, and Mutations

1. Define a server-owned allowlist with strict input/output schemas, resource-scoped authorization, bounded provider/tool execution, secret redaction and audit identity.
2. Treat model tool arguments as untrusted. Resolve tenant, actor and protected resource data from authenticated server context rather than model fields.
3. Approval is a server record binding actor, tenant, tool, exact normalized parameters/resource version, consequence, expiry and one-time operation identity. A client approval flag or matching tool name is insufficient; parameter changes invalidate approval.
4. Make consequential tools idempotent and reconcilable. A disconnect or timeout after provider success is an unknown outcome, not permission to rerun. Persist acceptance/result state and query the authoritative provider/resource before retry.
5. Abort model generation and cancellable tool/provider work from the request signal, but do not claim that abort rolls back an accepted external mutation.

## Conversation and Rendering

- Derive context from provider limits and product requirements. Preserve instruction provenance, unresolved tool/result pairs and recent user intent; summaries and retrieved memory are untrusted derived data with source/version, tenant/user partition, retention and repair behavior.
- Persist partial assistant output separately from a terminal message. On disconnect/error mark generation interrupted; resume/regenerate only through an explicit installed protocol and operation identity.
- Render structured message parts deliberately. Sanitize Markdown/HTML with an allowlist, reject unsafe URLs/protocols, isolate untrusted embeds/code and avoid executing model-generated markup, script, component names or tool UI instructions.
- Human handoff contains the minimum authorized transcript/summary, provenance, attempted actions and consent required by the destination. Label model-generated summaries and avoid inventing confidence thresholds.

## Workflow and Verification

1. Map authoritative history, request/response protocol, model/provider, tools, approval/mutation state, persistence, privacy, rendering, handoff and failure states.
2. Implement the smallest compatible installed SDK boundary and server-owned trust reconstruction.
3. Test forged `system`/`tool`/assistant messages, injected approval/results, cross-tenant conversation/attachment IDs, oversized/invalid parts, missing tool results and concurrent tabs.
4. Test streamed success, abort/disconnect, reconnect if supported, provider success followed by lost response, duplicate tool delivery, stale approval/changed parameters and handoff failure.
5. Test unsafe Markdown/HTML/URLs, citations/attachments, accessibility, partial terminal state and persisted caller-visible outcome. Run focused repository tests, type/build checks and deployed-protocol inspection before claiming completion.

## Output Contract

- Client/server protocol and installed SDK capability evidence
- Conversation/auth/history and rendering trust boundaries
- Tool approval, idempotency, abort and reconciliation contracts
- Persistence, privacy, handoff and test evidence
- Residual provider, reconnect, external-mutation and moderation risks

Official sources: [AI SDK chatbot guide](https://ai-sdk.dev/docs/ai-sdk-ui/chatbot), [useChat reference](https://ai-sdk.dev/docs/reference/ai-sdk-ui/use-chat), [message validation](https://ai-sdk.dev/docs/reference/ai-sdk-core/validate-ui-messages), and [streamText](https://ai-sdk.dev/docs/reference/ai-sdk-core/stream-text).
