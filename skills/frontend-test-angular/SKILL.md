---
name: frontend-test-angular
description: Add behavior-focused Angular unit, component, harness, signal, HTTP, and integration tests using the repository's installed runner and supported TestBed APIs. Use when executable Angular test coverage is requested; do not use for feature implementation alone.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.2
  domain: frontend
  keywords: [angular, testing, testbed, vitest, jasmine, karma, signal, harness, http]
---

# Frontend Test — Angular

Run `python3 scripts/framework-stack-context.py project <path>` and inspect `angular.json`, package/lock files, Angular core, TypeScript, every applicable base/app/test `tsconfig`, test target/builder, Zone-versus-zoneless configuration, setup, installed DOM emulator, existing spies/timers, HTTP client/testing providers and their ordering, the target's production HTTP/provider configuration, and nearby tests as one compatibility unit. Checking the installed HTTP testing providers and ordering is unconditional even when the requested behavior has no HTTP boundary; that check does not by itself require adding an HTTP test. Preserve the installed runner and conventions, and verify version-sensitive APIs against installed types plus matching Angular and runner documentation. Current new Angular CLI projects use Vitest, but an existing Karma/Jasmine, Jest, Web Test Runner or other supported setup is authority; migration is separate scope.

## Test Contract

- Test caller-visible behavior through the template, accessible queries, outputs, router/HTTP boundary and public service API. Avoid private members, implementation-only call order and third-party DOM internals; use component harnesses where available.
- Configure the smallest TestBed. Use plain construction only when no Angular injection context/lifecycle is required. Set inputs through the supported component/fixture API and synchronize model-to-view using APIs exposed by the installed Angular line.
- Do not prescribe `detectChanges()` after every operation. Establish the actual change-detection mode, auto-detection, signals and async boundary, then drive and await the user-observable state.
- `TestBed.flushEffects()` is deprecated in current Angular in favor of `TestBed.tick()`. Use whichever synchronization API the installed types support and verify its semantics; do not confuse `TestBed.tick()` with the Zone-dependent `tick()` function. Preserve the installed runner's timer/async model and never mix incompatible fake and real async controls.
- For HTTP tests, configure the production client/features first and `provideHttpClientTesting()` afterward so the testing backend overrides it. Use `HttpTestingController` to expect/flush/error requests and verify no unexpected requests. Never allow real network, credentials, production endpoints or service workers from unit/component tests.

## Workflow

1. Identify behavior and boundary: render/state, user event, output, router, HTTP, timer, signal/effect, resource or third-party component.
2. Reuse repository helpers and runner syntax. Mock at external boundaries; do not replace the unit under test with its own mock.
3. Cover success plus meaningful failure/race: loading, empty, server error, explicit timeout and caller-visible timeout outcome, cancellation, stale result, retry/duplicate, permission state and cleanup as applicable. Assert request and component state after timeout rather than inferring it from retry exhaustion.
4. For HTTP, assert method, URL/query/body/headers only where contractually relevant; flush each request deterministically and verify none remain.
5. Run the narrow authoritative test command, then affected suite/type/build checks. Diagnose environment limitations rather than weakening assertions.

## Verification

- Tests fail for the intended regression before/falsification fixture where safe and pass after the implementation under test.
- No live network or leaked timers/subscriptions/fixtures: explicitly destroy each Angular fixture or reset TestBed through the installed supported lifecycle, verify `HttpTestingController` has no pending requests, drain/verify timers, and prove no fixture/provider state leaks into the next test.
- Signal/effect/resource behavior is synchronized through installed supported APIs, including stale async completion and destruction.
- OnPush/default/zoneless behavior, accessibility-facing output and error paths are observed rather than inferred from internals.

## Output Contract

- Behaviors and boundaries covered
- Installed Angular/runner/TestBed capability evidence
- Files changed and commands/results
- Uncovered browser/E2E or migration boundary

Official sources: [Angular testing overview](https://angular.dev/guide/testing), [TestBed API](https://angular.dev/api/core/testing/TestBedStatic), and [HTTP testing](https://angular.dev/guide/http/testing).
