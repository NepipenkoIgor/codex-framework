---
name: account-verification
description: Implement email or phone ownership verification, delivered one-time codes or links, TOTP enrollment checks, and account-recovery challenges with enumeration resistance and atomic consumption. Use when proving control of a contact channel or authenticator; do not use for general login/session authorization, onboarding journeys, or identity-document proofing.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 3.0
  argument-hint: "purpose, channel/authenticator, subject and destination, assurance/risk policy, delivery provider, recovery effect"
---

# Account Verification

Implement `$ARGUMENTS` only after naming what is proved: control of an email address, phone number, TOTP secret, recovery channel, or another authenticator. These are not interchangeable with legal identity proof or authorization, and product onboarding remains outside this skill.

## Workflow

1. Inspect instructions, manifests/lockfiles, runtime compatibility, the installed cryptographic randomness and safe-comparison APIs, the pinned TOTP algorithm/configuration when applicable, current account/auth/session and pending-destination models, normalized destinations, delivery provider/webhook and outbox behavior, verification storage and its transaction/conditional-write capability, rate limiting, recovery and factor enrollment, audit events, message templates, privacy policy, and tests as one compatibility unit. Preserve pins and verify provider/library APIs from installed capability, matching official documentation, and the applicable RFC.
2. Define purpose, subject/account, normalized destination or authenticator, initiating actor/session, assurance, code/token entropy and representation, expiry, attempt/send/resend policy, single-use effect, and post-verification authorization. Expiry and thresholds are risk/product inputs, not universal constants.
3. Resist enumeration across status, body, timing, delivery side effects visible to the caller, and rate-limit behavior. Internally retain enough classified evidence to operate and investigate without exposing whether an account or destination exists.
4. Generate secrets with approved randomness, store only a verifier or securely protected secret appropriate to the mechanism, and bind it to purpose, subject, destination/authenticator, initiation context, challenge generation/version, and expiry. A code for email change cannot verify login, another address, or another account.
5. Create/resend atomically. Define whether resend invalidates prior challenges or creates a bounded generation set; a delayed older delivery must not unexpectedly validate after replacement. Deduplicate delivery intent with an outbox/provider key and reconcile ambiguous provider success.
6. Consume in one transaction/conditional write: load active bound challenge, compare safely, atomically increment failed attempts or mark consumed, then apply the intended verification/recovery effect exactly once. Parallel correct submissions and expiry races must have one winner.
7. Distinguish mechanisms: delivered email/phone codes prove current channel access and inherit delivery interception/SIM/email risks; TOTP is locally generated from a bound secret and requires an explicitly verified pinned algorithm, timestep/window, clock and replay policy; recovery is an authentication path and must not be weaker than the account's risk policy.
8. On success rotate sessions/tokens or require reauthentication/step-up where the verified change affects account security. Notify old and new channels where policy requires, audit without storing codes/tokens, and authorize changes such as contact replacement separately.
9. Verify nonexistent and existent responses including caller-visible timing, destination normalization, brute force distributed across multiple rotating IPs, attempt binding, delayed/out-of-order delivery, concurrent resend/submit, two correct submissions, reuse of an already consumed code, expiry boundary, provider timeout/retry, TOTP replay/clock window, recovery bypass, cross-purpose/account/destination token use, session rotation, and audit evidence. Explicitly submit a stolen but otherwise valid emailed code outside the required current-authorization or initiation context and prove it cannot take over or mutate the account. Add an executable assertion that each required old/new-channel security notification is emitted once with the safe destination/effect context and no secret or account-enumeration leak. Production rollout remains blocked until this security suite passes and provider, session, recovery-effect, and security-notification outcomes are read back or reconciled.

## Required counterexamples

- Email OTP, SMS OTP, TOTP, recovery code, and magic link have different threat and state models; do not reuse one generic recipe blindly.
- A resend racing with submit must not allow an invalidated older generation to win unexpectedly.
- Attempt counters must be atomic and bound to the challenge/account/purpose—not only IP or code value.
- A valid code does not authorize changing another user's destination or bypassing current-session checks.
- Do not hard-code digit count, expiration, send limits, or attempt limits as universal values.

## Output

Report proof purpose and assurance, installed/provider evidence, challenge binding and state machine, enumeration/rate policy, delivery/resend reconciliation, atomic attempt/consume behavior, recovery/session effects, tests/results, external provider evidence, and residual account-takeover risk from channel interception, support recovery, or re-proofing processes.

Record the exact installed versions, official provider/library pages, applicable RFC section or behavior, and the resulting capability decision near the implementation or configuration. Do not substitute remembered defaults or a generic current-version claim.

## Provenance

- NIST authenticator, OTP, recovery, and session guidance: https://pages.nist.gov/800-63-4/sp800-63b/authenticators/
- RFC 6238 TOTP validation policy: https://www.rfc-editor.org/info/rfc6238/
- OWASP forgot-password enumeration and token guidance: https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html
- OWASP MFA and OTP handling: https://cheatsheetseries.owasp.org/cheatsheets/Multifactor_Authentication_Cheat_Sheet.html
