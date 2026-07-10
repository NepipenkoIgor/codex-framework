---
name: mobile-auth
description: Implement and review React Native or Expo mobile authentication including secure token storage, biometrics, deep-link OAuth callbacks, refresh rotation, cold-start restoration, logout, and provider SDK integration. Use when mobile sessions, OAuth, passkeys, or device credentials are involved.
metadata:
  version: 1.0
argument-hint: "provider, auth method, platform, Expo or bare workflow"
---

# Mobile Authentication

Use this skill for the client layer. Pair it with `auth-security` for server-side authorization, PKCE, token rotation, and API validation.

## Workflow

1. Map the provider, redirect scheme, token types, expiry behavior, server session contract, and offline/cold-start requirements.
2. Store access and refresh credentials only in platform secure storage: Keychain/Secure Enclave on iOS and encrypted Android keystore-backed storage. Do not place tokens in AsyncStorage, plain MMKV, logs, URLs, analytics, or crash reports.
3. Use Authorization Code with PKCE for OAuth. Register and test exact deep-link callback schemes on both platforms; validate returned state and code before exchanging tokens.
4. Restore a session asynchronously during app start. Keep an explicit loading state and avoid rendering protected content before restoration completes.
5. Refresh once when an authorized request receives an expiry signal. Serialize concurrent refreshes, rotate stored credentials atomically, and force logout on an invalid or reused refresh token.
6. On logout, revoke the remote session when supported, clear secure storage, reset in-memory caches, and invalidate navigation state.

## Biometrics and Device Changes

- Treat biometric unlock as local re-authentication, not an authorization substitute.
- Require a server-valid session after biometric unlock.
- Handle biometric enrollment changes and unavailable hardware by falling back to the approved sign-in path, not by bypassing authentication.
- Never make device identifiers or biometric success values a credential.

## Storage Decision Table

| Data | Storage | Rule |
|---|---|---|
| Access or refresh credential | Keychain/Keystore-backed secure storage | Encrypt at rest and clear on logout |
| Biometric preference | Secure storage or non-sensitive local preference | Never treat it as a credential |
| In-memory access token | Process memory | Clear on logout and app session reset |
| User profile and cached API data | Application cache | Never use as proof of authorization |

## Verification

- Verify protected deep links redirect unauthenticated users to sign-in and return to the intended destination after completion.
- Verify cold start with a valid session, expired access token, revoked refresh token, and no credentials.
- Verify a refresh storm from concurrent requests produces one refresh exchange.
- Verify logout leaves no token in secure storage or app cache.
- Verify an OAuth callback with wrong state, missing code, or another app's URL is rejected.

## Constraints

- Do not trust a client role, entitlement, or expiry claim without server validation.
- Do not use a WebView to capture provider credentials when the provider supports system browser auth.
- Do not weaken certificate, redirect, or PKCE validation to simplify development.

## Deliverable

- Session and callback lifecycle
- Storage and refresh design
- Provider/platform assumptions
- Executed verification and remaining platform-specific risk
