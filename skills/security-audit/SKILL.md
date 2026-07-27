---
name: security-audit
description: Perform a read-only, evidence-based security audit of application, API, data, infrastructure, and supply-chain execution paths. Use when findings and risk assessment are requested; use plugin-security-review for Codex plugin/skill/agent bundles and a remediation skill when fixes are requested.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.0
  argument-hint: "scope and trust boundaries, deployment context, identities/data, threat model, available runtime evidence"
---

Audit $ARGUMENTS without modifying code, configuration, dependencies, services, accounts, or data.

## Establish scope and threat context

Read repository instructions, manifests/lockfiles, entry points, authentication/authorization, data flows, deployment configuration, infrastructure policy, tests and relevant generated schemas. Map actors, assets, trust boundaries, external inputs, privileges, secrets, network paths, storage/retention, and consequential actions. State what code and runtime evidence is unavailable.

Preserve installed version context and verify version-specific security behavior using local configuration/types or official documentation matching the pin. Check applicable runtime engine constraints, peer dependencies, compiler/framework, security middleware/provider adapters, test runner and deployment compatibility together. For any version-sensitive command, API or control selected from repository evidence, record the installed type, CLI help, configuration schema or matching documentation that proves support; if no concrete capability is supplied, state the evidence required and do not invent one. Current CVE, advisory and platform claims require current authoritative sources and exact package/artifact/version evidence; do not infer exposure from a product name.

## Trace exploitability

Prioritize authorization bypass, tenant/data exposure, injection, unsafe file/URL handling, credential/session compromise, destructive or financial actions, supply-chain execution, insecure deserialization, SSRF and sensitive logging. Trace controllable source through validation, authorization and transformations to a reachable sink. Record existing defenses and whether they are active in the deployed path.

Security controls depend on context:

- CSRF matters for credentialed cross-site requests and browser credential behavior; it is not a universal token checkbox.
- CSP is defense-in-depth shaped by actual script/style/frame/connect needs, nonces/hashes and browser delivery; one universal policy is not automatically compatible or sufficient.
- Encryption claims require asset, threat, key ownership, rotation, backup, restore and access-control context. “Encrypted at rest” does not imply authorized use or secure clients.
- Rate limits require subject/key, endpoint cost/harm, distributed state, burst and failure semantics. Absence of a fixed threshold is not itself a vulnerability.
- CORS, cookies, TLS/HSTS, OAuth/OIDC, JWT, password hashing, logging, uploads, egress and CI permissions must be assessed against their real deployment and attacker path.

Use scanners only as leads. Confirm code reachability, configuration, exploit preconditions and caller-visible impact. Do not expose secrets while investigating; report secret type and location with redacted evidence and rotation impact.

## Severity and output

Assign severity from demonstrated impact, exploitability, privileges/preconditions, affected scope, existing controls and confidence—not keywords or checklist membership. Each actionable finding must explicitly state confidence and include severity, file/line or exact configuration, source-to-sink path, attack scenario, evidence, affected deployments/data, active existing controls, and a reproduction or explicitly missing executable check, plus bounded remediation and verification. Unsupported concerns remain hypotheses or missing-evidence notes.

Order findings by risk. If none are substantiated, say so and list residual unaudited boundaries. Do not claim security from configuration presence, scanner success, encryption labels or passing tests.
