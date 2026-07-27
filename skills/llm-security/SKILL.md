---
name: llm-security
description: Design and implement security boundaries for LLM applications handling untrusted content, tools, sensitive data, model access, and consequential actions. Use when model output can influence data access or side effects; do not use for ordinary prompt quality, generic application authentication, or model evaluation alone.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "assets, untrusted inputs, tools, identities, data classes, consequential actions"
---

# LLM Application Security

## Repository Discovery and Threat Model

Generate project stack context, preserve installed pins and inspect the core/provider SDK, model capability, renderer, executor, credential-issuer implementation/configuration, egress, retrieval, storage/logging and deployment as one compatibility chain. Record provider/security capability versions with matching official documentation, including retention, training, residency and fallback behavior or explicitly unresolved assumptions. Then map assets, identities, trust boundaries, untrusted channels, model/provider data handling, retrieval/ingestion, memory, tools, credentials, egress, approval points, logs, and incident response. Include direct prompts, retrieved documents, web/email/files, tool output, images/audio, encoded text, prior conversation, and model-generated plans as untrusted data. Define what compromise means: cross-user access, secret/PII exfiltration, unauthorized write, financial action, publication, code execution, persistence, or denial/cost abuse.

Prompts, delimiters, “sandwich” repetition, regexes, classifiers, and leakage detection are weak signals—not security boundaries. Assume sufficiently capable prompt injection may influence model text. Security comes from deterministic authorization and constrained capabilities outside the model.

## Workflow

1. Inventory assets, principals, untrusted data paths, tools, and side effects.
2. Assign each tool a risk class, credential, resource scope, egress policy, budget, idempotency contract, and approval rule.
3. Separate untrusted-content processing from privileged execution; pass only bounded structured data across the boundary.
4. Enforce identity, tenant/resource authorization, policy, schema, call count, amount/target limits, and approval in the executor.
5. Minimize provider/context data and validate structured outputs at every downstream boundary.
6. Add atomic rate/token/cost budgets, privacy-safe audit evidence, alerts, revocation, and kill switches.
7. Run adversarial tests covering direct/indirect/multimodal injection, obfuscation, horizontal access, exfiltration, and approval bypass.

## Capability and Tool Boundary

The model proposes; trusted code authorizes and executes.

```typescript
async function authorizeAndExecute(call: ToolCall, ctx: AuthenticatedContext) {
  const policy = registry.get(call.name);
  if (!policy) return denied('unknown_tool');

  const params = policy.schema.parse(call.parameters);
  await authorize(ctx.principal, policy.action, params.resourceId, ctx.tenantId);
  await policy.validateTarget(params, ctx);       // ownership, destination, amount, region
  await budgets.consumeAtomically(ctx, policy, params);

  if (policy.risk === 'consequential') {
    const approval = await approvals.requireBoundApproval({
      principal: ctx.principal,
      action: policy.action,
      canonicalParams: params,
      expiresAt: shortExpiry(),
    });
    if (!approval.valid) return denied('approval_required');
  }

  return policy.executeWithLeastPrivilege(params, {
    credential: await credentials.issueScoped(policy.scopes, shortExpiry()),
    idempotencyKey: ctx.idempotencyKey,
    egress: policy.allowedDestinations,
  });
}
```

- Never authorize from model claims, retrieved text, tool output, hidden chain-of-thought, or a user-supplied tenant/resource ID.
- Use separate read/write tools and credentials. Prefer read-only, short-lived, resource-scoped credentials.
- Bind approval to canonical parameters so the model cannot change target/amount after confirmation.
- Isolate code/browser/file execution and restrict network/filesystem destinations independently of prompt instructions.
- Sanitize and label tool results before returning them to the model, but do not trust sanitization to remove every injection.

## Untrusted Content and Retrieval

- Preserve provenance and trust labels through ingestion, retrieval, summaries, citations, and memory.
- Retrieved content may supply facts, never policy or authority. Do not concatenate it into privileged instructions.
- Where feasible, quarantine content-reading from privileged action-taking: an unprivileged component extracts a constrained schema; the privileged path validates that schema without ingesting raw hostile instructions.
- Ingestion checks source authorization, content type/size, malware, tenant namespace, poisoning/replacement controls, and deletion lifecycle.
- Treat links, images, OCR, metadata, invisible markup, code comments, and encoded/Unicode text as possible instruction carriers.

## Data and Output Controls

- Minimize prompts and logs; apply provider retention/training/residency settings required by policy.
- Use structured schemas and deterministic downstream validation. Never execute or render model-generated code/HTML/SQL/URLs without the destination-specific security boundary.
- Apply DLP/classification based on actual data classes and recipient authorization; regex alone is neither complete nor precise.
- Prompt secrecy is not the primary boundary. Secrets and privileged instructions must not be present where disclosure would create authority.
- Grounding/content classifiers can block or flag output, but cannot grant tool permission.

## Abuse, Budget, and Observability

- Enforce rate, concurrency, context, token, tool-call, and monetary budgets atomically by tenant/user/feature.
- Record model/provider, data-source provenance, policy decisions, tool name/resource class, approval, usage exactness, and outcome without raw secrets/prompts by default.
- Alert on repeated denied cross-resource access, approval mismatch, new egress destinations, injection clusters, budget spikes, and guardrail drift.
- Provide scoped credential revocation, tool disablement, retrieval-source quarantine, and incident replay from sanitized evidence.

## Verification

- Submit a direct user prompt injection that requests policy override, secret disclosure, or a privileged action; deterministic authorization, tool, data and egress boundaries deny the capability even if model text follows the instruction.
- A retrieved page/email/document asks the model to expose secrets or transfer/delete data; deterministic executor denies it.
- A legitimate document containing phrases such as “system:” or “ignore previous instructions” remains processable as data.
- Unicode, encoded, multilingual, split, and multimodal injections obtain no additional capability.
- A user requests another tenant's order/resource through a valid tool schema; authorization denies horizontal access.
- High-risk parameters change after approval; execution requires a new bound approval.
- Compromise the model output entirely in a test harness; filesystem/network/tool scopes still contain the blast radius.
- Place a uniquely identifiable, non-sensitive canary behind each protected secret/data boundary and drive an adversarial request through the actual model, tool, renderer and egress path; executable evidence must show no canary appears in model output, tool arguments, outbound requests, rendered content or logs.
- Submit unsafe model-generated HTML and URL payloads to the actual renderer/navigation boundary and SQL/code payloads to each database, interpreter, browser, file or execution boundary; sanitization, scheme/origin policy, deterministic validation, isolation and authorization prevent execution or contain it to the exact allowed sandbox.
- Duplicate and replay a consequential tool request under one stable idempotency identity; executable evidence must show one authorized persisted outcome and no repeated side effect.
- Race token/tool/cost budgets; atomic ceilings hold and missing provider usage is not recorded as zero.

## Output Contract

Report assets and trust boundaries, threat scenarios, principal/resource authorization, tool risk registry, credential/egress isolation, approval binding, untrusted-content path, renderer/output boundaries, provider/security capability versions and residency/fallback assumptions, data minimization/DLP, budgets, audit/incident controls, adversarial results, and residual risks that cannot be eliminated by prompting or filtering.

## Official Provenance

- OWASP LLM Prompt Injection Prevention Cheat Sheet: `https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html`
- OWASP GenAI LLM01 Prompt Injection: `https://genai.owasp.org/llmrisk/llm01-prompt-injection/`

Re-check current OWASP guidance and provider security/data-processing documentation for version-sensitive controls.

## Done Criteria

- Untrusted content cannot directly grant authority or invoke side effects.
- Every tool call is independently authenticated, resource-authorized, schema/target validated, scoped, budgeted, and audited.
- Consequential actions require approval bound to exact parameters.
- Model compromise tests demonstrate bounded capabilities and egress.
- Adversarial, horizontal-access, replay, race, and incident-control tests pass with residual risk documented.
