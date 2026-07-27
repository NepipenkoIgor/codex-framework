---
name: mobile-auth
description: Implement mobile client authentication for the repository's installed React Native, Expo, Flutter, or native stack, including PKCE callbacks, secure session persistence, rotation recovery, account isolation, biometrics, and passkeys. Use when mobile sessions, OAuth callbacks, or device credentials are in scope; pair with auth-security for server authorization and do not invent cross-platform APIs.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "installed platform, provider, auth method, callback ownership, session contract"
---

# Mobile Authentication

## Workflow

1. Read repository instructions, manifests, lockfiles, native app identifiers/associated domains, installed auth and secure-storage libraries, server session contract, navigation, caches, and tests. Generate project stack context before version-specific guidance. For an existing project, use only capabilities exposed by the installed platform and treat upgrades as separate migrations. For greenfield with no manifest/lockfile, resolve stable/LTS releases at execution time from configured official sources, check mobile framework/runtime/native/auth-library compatibility as one stack, then treat the generated manifest and lockfile as authority. Before material mutation, resolve exact app/server/configuration targets, owning team, write authority/permissions and effect-appropriate rollback/recovery.
2. Map account/tenant identity, credential types, expiry and rotation, revocation, offline behavior, callback ownership, account switching, and server authorization. Client claims and cached profiles are never authorization evidence.
3. Use the system authorization surface and Authorization Code with PKCE for native OAuth where supported. Create a one-time transaction binding `state`, code verifier/challenge, provider, redirect URI, app instance/session, and intended post-login route. Accept only the exact owned custom scheme or verified universal/app link; consume the transaction once before exchange and reject missing, mismatched, replayed, or cross-app callbacks.
4. Store credentials only with the installed platform's supported secure-storage capability. Keep non-secret account-scoped caches separate. Never put credentials in ordinary preferences, URLs, logs, analytics, crash reports, backups, or screenshots.
5. Serialize refresh per session and account. Persist rotation as an atomic generation/envelope or recoverable pending-to-committed protocol so process death after server rotation cannot restore the superseded refresh credential. On ambiguous timeout, reconcile through the server contract; do not blindly replay a one-time token.
6. On logout, revocation, or account switch, invalidate the exact session generation, cancel in-flight requests/refresh, clear credentials and account-scoped caches/navigation, and prevent late callbacks from restoring the old account. Do not let account B reuse A's key alias, biometric gate, pending OAuth transaction, or cached authorization.
7. Treat biometrics as local user-presence gating, never server authorization. Capability-gate hardware, enrollment, lockout, key invalidation, and fallback using installed APIs. Passkeys require a fresh server challenge and verified relying-party/application association; verify user presence/verification and server-side assertion before establishing a session.

## Verification

Exercise cold start with valid, expired, revoked, absent, and corrupted credentials; concurrent refresh; crash after server rotation but before local replacement; refresh timeout; logout racing with refresh; account A to B switch; callback with wrong state/verifier/redirect/app; callback replay; protected deep link before login; biometric enrollment change/lockout/unavailable hardware; and passkey RP/challenge mismatch.

Assert secure persisted state, server session state, cache/navigation isolation, and network request ownership after restart. Use platform/device integration tests for secure storage, callbacks, biometrics, and passkeys; label simulator/provider paths not exercised with real capabilities.

Return changed files, installed capability/version evidence, callback and session state machines, storage/account boundaries, executed tests, and residual provider/device risks. Do not weaken redirect, PKCE, TLS, attestation, or certificate validation for development convenience.
