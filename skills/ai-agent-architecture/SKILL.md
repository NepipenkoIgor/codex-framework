---
name: ai-agent-architecture
description: Design a product AI-agent system with least-privilege tools, explicit state, approvals, idempotent side effects, memory governance, evaluation, and operational boundaries. Use for architecture decisions; do not use to recreate or configure native Codex orchestration.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 3.1
  argument-hint: "business outcome, users/tenants, tools and side effects, approval authority, memory policy, evaluation and runtime constraints"
---

# AI Agent Architecture

This is a read-only design workflow for product agents. Native Codex planning, skills, models, approvals, sandboxing, plugins, memory, multi-agent communication and subagent lifecycle remain Codex-owned and are explicitly out of scope. Do not design wrappers that reproduce them.

Inspect repository/provider/runtime configuration and generate stack context with `python3 scripts/framework-stack-context.py project <path>`. Verify the exact core and provider SDK pins, runtime, checkpoint/state store, authorization integration and evaluation harness as one capability unit using installed types and matching official documentation. For a greenfield AI SDK selection use `python3 scripts/framework-stack-context.py latest ai-sdk <other-technologies...>`. Existing pins, provider capabilities and organizational policies are authority; migration is separate scope, and volatile provider/version mechanics stay behind explicit adapters.

## Start with the Smallest Agent

1. Define the caller-visible outcome, authoritative data, allowed uncertainty, latency/cost/reliability constraints and executable success/failure examples.
2. Prefer deterministic code or a single model call when sufficient. Add retrieval, tools, planning, checkpoints or delegation only for a measured capability gap. Multi-agent topology is not a quality feature by itself.
3. Model explicit states for accepted work, model decisions, pending approval, tool execution, unknown outcome, reconciliation, completion, cancellation and terminal failure. Set limits from product SLOs, provider constraints, cost policy and evaluation evidence—not arbitrary counts or token budgets.

## Tool and Authorization Boundary

- Tool names/descriptions and schemas aid model selection; they are not a security boundary. Treat model output, retrieved content, memory and summaries as untrusted input.
- At execution, authenticate the actor/service and authorize the exact tenant, resource, action and current version. Derive protected parameters server-side and validate tool input/output schemas. Prompt sanitization or instructions such as “ignore injection” do not replace isolation, least privilege and authorization.
- Give each tool the minimum credentials, network/data scope and duration. Separate read from write capabilities and untrusted content from instructions. Redact secrets and bound returned context without hiding authoritative failure evidence.
- Consequential operations use a durable operation identity and provider/resource idempotency where supported. Serialize or version concurrent changes and reconcile a timeout/disconnect after possible success before retrying. Duplicate tool calls return/reconcile the same operation rather than repeat the side effect.

## Human Approval

Approval is a durable, auditable authorization record binding approver identity/authority, actor, tenant, tool, exact normalized parameters and resource version, consequence preview, expiry and one-time operation identity. Parameter or target changes require new approval. Denial, expiry or unavailable approver fails closed unless a specific deterministic, non-harmful alternative is part of product policy. Never use an `ask_llm` fallback as approval.

## Memory Governance

- Partition memory by tenant, user/subject, purpose and environment. Define consent/legal basis, allowed data classes, provenance/source, confidence/verification state, version, retention, access correction and deletion—including indexes, summaries and derived embeddings.
- Retrieval is evidence, not authority. Reauthorize source data where needed, resist poisoned instructions, preserve citations/provenance and prevent one tenant/user's memory from influencing another.
- Do not persist secrets or chain-of-thought. Store the minimum useful user-visible facts/outcomes; distinguish user statements, verified business facts, model inferences and revoked/stale facts.

## Failure, Observability, and Evaluation

- Propagate cancellation through model and tool work, while recording that accepted external work may still complete. Reconcile unknown outcomes and expose honest partial/pending state.
- Trace decisions, policy version, active tools, approvals, operation IDs, tool outcomes, latency/usage and memory provenance with access controls and redaction. Logs do not become an ungoverned memory store.
- Evaluate representative and adversarial tasks: forged instructions/roles, prompt injection in retrieved/tool content, resource/tenant substitution, stale permission, approval parameter swap, duplicate tool delivery, timeout after provider success, exhausted model/tool/time/cost limits with a bounded terminal or recoverable outcome, poisoned memory, deletion and cross-tenant retrieval. Prefer executable state/outcome checks; model judges may supplement but not certify security.

## Architecture Workflow

1. Map trust, data, identity, side-effect and provider boundaries.
2. Compare the smallest viable deterministic/single-agent/tool-using options and justify every added loop, planner, memory or delegation boundary, including how it can be disabled or removed and whether rollback remains compatible with stored state and in-flight work.
3. Specify state machine, tool contracts, auth, approval, idempotency/reconciliation, memory governance, limits, observability and kill/disable behavior.
4. Define staged evaluation and rollout gates with rollback and human operations for stuck/unknown work. Add executable kill/disable tests proving new work is rejected or diverted while already accepted work completes safely or reaches a visible reconciled state.
5. Mark assumptions, external dependencies and unverified provider behavior explicitly.

## Output Contract

- Outcome, trust/data diagram and smallest recommended architecture
- Executed AI SDK project-detection/stack-context command and result, or the exact `python3 scripts/framework-stack-context.py project <path>` step marked `Not available` when repository/tool execution is withheld
- State, tool/auth, approval and side-effect contracts
- Memory consent/partition/provenance/retention/deletion policy
- Limits derived from evidence, observability and evaluation plan
- Executable kill/disable and rollback cases with trigger/action and asserted outcomes: new work is rejected or deterministically diverted, while accepted or unknown work safely completes, cancels, or reaches a visible reconciled state
- Options, tradeoffs, rollout/rollback and unresolved provider risks

Official guidance: [OWASP LLM Prompt Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html), [NIST AI RMF](https://www.nist.gov/itl/ai-risk-management-framework), and [AI SDK tool calling](https://ai-sdk.dev/docs/ai-sdk-core/tools-and-tool-calling).
