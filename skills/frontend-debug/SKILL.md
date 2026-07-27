---
name: frontend-debug
description: Reproduce, localize, and fix a concrete frontend defect across rendering, state, hydration, browser, CSS, and network boundaries. Use when diagnosis plus a repository fix is requested; do not use for backend-only, mobile-native, greenfield, or review-only work.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 3.1
  argument-hint: "symptom and expected behavior, exact URL/build/browser/account/time, reproduction steps and affected framework"
---

# Frontend Debug

Debug and fix `$ARGUMENTS` within the authorized repository scope.

## Reproduce and localize

1. Capture exact expected versus observed behavior, URL/build/commit, browser/device, viewport, role/account, locale, timestamps, data/state, and reproduction sequence.
2. Reproduce from a clean fresh load as well as navigation when initialization, cache, SSR, or hydration may differ. Do not rely on hot-reload state as evidence.
3. Correlate browser console/network/performance evidence with server/provider logs when available. Redact secrets and PII.
4. Trace ownership across rendered DOM/CSS, state and events, effects/watchers, router/cache, request/response, server/client serialization, hydration, and third-party boundaries. State hypotheses and falsifying observations.
5. Establish root cause before changing code, then add a focused regression or reproducible baseline and make the smallest safe fix.

## Capability and production boundaries

- Generate stack context and use installed manifests, lockfiles, runtime config, generated types, browser targets, and matching official documentation. Do not assume current framework APIs.
- Source maps are evidence only when they match the exact deployed artifact/runtime and are access-controlled; stale/local maps can misattribute a production stack.
- A local fix is not production proof. Distinguish local, preview, deployed, authenticated, browser/device, and provider paths.
- If immediate production mitigation is required, first obtain explicit authority for the exact production target and action. Then bound the affected traffic/data, choose a reversible feature flag/rollback/config action with owner and stop condition, preserve evidence, and avoid destructive cache/data actions without explicit authority.

## Common failure classes

- initialization order, stale closure/watch/effect, duplicated derived state, missed cleanup, race or stale response;
- server/client ownership, non-serializable payload, hydration mismatch, browser-only API during server render;
- focus/event propagation, native-control semantics, CSS containing block/stacking/overflow, responsive or font-loading differences;
- authentication/authorization response, cache key/invalidation, timeout/retry ambiguity, provider or CORS boundary.

## Verification and output

- Rerun the exact reproduction, focused regression, and affected repository checks. Test fresh load, failure/retry, and relevant browser/server boundaries.
- For mutations verify caller-visible and persisted outcomes, including duplicate activation or timeout-after-commit where material.
- Report reproduction, root-cause evidence, fix and why it is bounded, commands/results, deployed paths actually verified, mitigation/rollback state, and residual risk.
