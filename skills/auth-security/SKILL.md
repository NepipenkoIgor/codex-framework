---
name: auth-security
description: Implement authentication, session and token lifecycle, OAuth/OIDC, API credentials, MFA/passkeys, and resource-level authorization. Use when repository behavior establishes or consumes an authenticated principal or permission decision; do not use for contact verification alone, mobile-only credential storage, or a security audit without implementation.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 3.0
  argument-hint: "actors, clients, authenticators, session/token model, resources/actions, assurance and recovery policy"
---

# Authentication and Authorization

Implement `$ARGUMENTS` from the application's threat, assurance, and trust boundaries rather than fixed lifetimes, algorithms, attempt counts, or framework recipes.

## Workflow

1. Inspect repository instructions, manifests/lockfiles, installed auth library/provider and configuration, issuer/discovery metadata, client/runtime, credential/token/session stores, cookie and proxy topology, authorization/data and database schema, key/secret management, recovery, audit events, deployment runtime, and tests as one compatibility unit. Preserve supported pins and verify APIs and discovery behavior against installed types/config plus matching official standards/provider documentation. Record the exact verified provider/library/protocol behavior, version and source; upgrades are separate migrations.
2. Map actors, authenticators, clients, redirect origins, issuers/audiences, session and token boundaries, trust elevation, protected resources/actions, tenants, and compromise/recovery paths. Select controls from the required assurance and risk policy; examples are not defaults.
3. Authenticate in trusted code and authorize every operation against the current actor, tenant, action, and resource. UI routes, roles/claims, gateway headers, or a valid token do not by themselves prove object/function authorization. Revalidate high-risk or stale authorization where policy requires.
4. For cookie sessions, issue unpredictable server-verifiable identifiers, rotate on authentication and privilege changes, enforce transport/cookie scope, idle/absolute/revocation policy, and invalidate old sessions atomically. IP and user-agent changes are risk signals; hard binding can break legitimate mobility or create denial of service unless a documented threat model justifies it.
5. Apply CSRF defenses to unsafe requests authenticated by ambient credentials, including relevant cookie, client-certificate, or automatically attached browser credentials. SameSite and Origin/Fetch Metadata checks are defense-in-depth; bearer credentials explicitly attached by non-browser clients have a different CSRF boundary. XSS and session theft remain separate risks.
6. For OAuth/OIDC, use the flow and current BCP required for the client, bind authorization responses to the initiating session, validate exact redirect, issuer, audience, state and OIDC nonce where applicable, and keep tokens scoped to the intended client/resource. Token refresh rotation/reuse response follows provider capability and policy; do not transplant one token-family recipe universally.
7. For passwords, OTP, passkeys, recovery, and API credentials, use current standards and approved cryptography/provider libraries. Bind enrollment/recovery to an authenticated or equivalently verified subject, make secrets single-view or nonrecoverable where appropriate, rate-limit by attack surface without enabling account enumeration, and audit factor changes.
8. WebAuthn verification validates challenge, origin, RP ID, credential, signature, user presence/verification policy, and backup flags as applicable. Signature counters are a clone-detection signal: some authenticators keep zero or sync credentials, so a non-increment alone is not a universal rejection rule.
9. Make key, token, session, role, authenticator, and recovery transitions atomic and concurrency-safe. Define revocation propagation, compromise response, active-session visibility, step-up, logout, password/factor change, and administrator support authority.
10. Verify login/federation callback, session fixation and rotation races—including proof that a pre-authentication identifier cannot survive login or privilege elevation—concurrent refresh descendants, replay of a consumed predecessor, revoked/consumed successor credentials, logout/revocation, CSRF across applicable unsafe methods, request content types and ambient-credential modes, XSS-sensitive storage, cross-tenant/object/function authorization, passkey zero/synced counters and synced backup flags, factor enrollment/removal/recovery, enumeration/timing, rate limits, key rotation, and deployment/proxy behavior.

## Stop conditions and counterexamples

- Stop if issuer/client/redirect, credential authority, tenant/resource authorization, recovery identity proof, key ownership, or safe test boundary is unresolved.
- Do not encode remembered access/refresh/session durations, password cost, attempt thresholds, OTP shape, or IP ranges as universal security policy.
- Rotating a session or refresh token without an atomic old-to-new transition can create parallel valid credentials or lock out the legitimate client.
- CSRF middleware on every mutation is not equivalent to correct ambient-credential scope, and SameSite alone is not proof.
- Authentication success never replaces authorization of the exact resource and action.

## Output

Report installed/provider evidence, threat and assurance decisions, principal/session/token/credential lifecycle, CSRF boundary, authorization enforcement points, recovery and compromise behavior, migrations/config changes, attack tests and results, external provider changes, and any unverified browser/proxy/provider boundary.

## Provenance

- OAuth 2.0 Security Best Current Practice: https://www.rfc-editor.org/rfc/rfc9700.html
- WebAuthn Level 3 counter and backup semantics: https://www.w3.org/TR/webauthn-3/
- NIST authenticator and session guidance: https://pages.nist.gov/800-63-4/sp800-63b.html
- OWASP CSRF guidance: https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html
