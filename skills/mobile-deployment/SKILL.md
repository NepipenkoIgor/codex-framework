---
name: mobile-deployment
description: Implement repository-side mobile build, signing, beta, store, OTA, and rollout automation with explicit environment and release authority. Use for requested deployment changes; do not publish, promote, or submit externally without explicit authorization.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "installed stack, platforms, environments, release action, rollback constraints"
---

# Mobile Deployment

## Workflow

1. Read repository instructions, manifests, lockfiles, native projects, build flavors/schemes, signing setup, CI, store identifiers, OTA configuration, migrations, and release runbook. Generate stack context first. Existing pins and native toolchains are authority unless migration is in scope; greenfield versions come from current official stable/LTS distribution channels and compatibility checks.
2. Classify the stack by evidence. Use Expo/EAS guidance only when the project exposes compatible Expo/React Native configuration. Use Flutter's supported build/release tooling for Flutter. Use native Xcode/Gradle and repository-selected automation for native or bare projects. Do not infer tooling from a requested brand name.
3. Resolve exact app ID/bundle ID, platform, environment, build flavor, signing identity, artifact, channel/track, and external action. Repository automation does not authorize a build, upload, submission, promotion, staged rollout, OTA publish, or rollback.
4. Separate build, sign, attest, upload, submit, release, and promote stages. Pin toolchains and actions as repository policy requires; protect credentials in the platform secret store; verify artifact identity, provenance, signature, entitlements/permissions, and environment endpoints before upload.
5. Gate production from protected tags/releases or an explicit approval boundary. A push or merge to the default branch must not automatically release to production unless the repository's approved policy expressly requires it.
6. For OTA, bind a signed or otherwise integrity-protected update to an exact app/environment channel and a runtime compatibility identity. Native dependency, native configuration, permission, or runtime-contract changes require a compatible new binary. Verify the installed platform's actual OTA capabilities before adding commands.
7. Design schema/API/config changes for mixed client versions. State forward/backward compatibility, migration ownership, irreversible steps, minimum supported build, feature flag behavior, and server rollback constraints.
8. Define rollout cohorts and stop criteria from product risk and current store/provider capabilities. Do not prescribe fixed percentages or thresholds. Manual downloads, already-updated clients, review delay, and provider rollback semantics limit recovery.

## Release Evidence

Before any authorized external mutation, present the exact target and expected effect. Afterward capture immutable build/version identifiers, artifact checksum/provenance, signing result, upload/submission response, store/OTA status, cohort, and monitoring window. A successful CLI exit is not proof of installability or release.

Test installation/upgrade from supported prior builds, clean install, authentication and backend environment, deep links, notifications, purchases or other critical native capabilities, migration behavior, OTA compatibility rejection, and rollback/feature-disable paths on representative devices. A store rejection leaves production unchanged; preserve the previous approved artifact and produce a corrected submission rather than bypassing policy.

## Done Criteria

- Build and signing are reproducible for the exact installed stack without committed credentials.
- Production mutation requires the declared approval boundary and targets one resolved app/environment/channel/track.
- OTA and binary runtime compatibility are enforced; native changes cannot reach incompatible binaries.
- Mixed-version data/API compatibility and store-rejection recovery are documented and exercised where feasible.
- Rollout and recovery evidence is based on current provider state, with limitations and untested external paths reported.

Return changed files, stack/version evidence, release-state diagram, credential boundaries, exact authorized external actions, verification evidence, recovery plan, and residual provider/store risks.
