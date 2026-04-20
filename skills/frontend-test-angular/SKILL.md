---
name: frontend-test-angular
description: Angular testing with TestBed, component harnesses, signal-aware testing patterns
metadata:
  version: 1.0
  domain: frontend
  keywords: [angular, testing, testbed, component harness, spectator, jasmine, jest, signal, fixture]
---

# Frontend Test — Angular

Pair with `frontend-test` for universal testing principles.

## Setup

- Use `TestBed.configureTestingModule()` for component and service tests
- Prefer `jest` over `jasmine` for new projects — faster, better error messages
- Use Angular CDK component harnesses for Material components — never query internal DOM of third-party components
- Use `Spectator` library to reduce TestBed boilerplate for straightforward component tests

## Component Testing

- Always call `fixture.detectChanges()` after setup and after state mutations with Default CD
- With `OnPush` components: use `fixture.componentRef.setInput()` to set inputs — triggers CD correctly
- Never access private component properties in tests — test through template output and emitted events
- Use `fixture.debugElement.query(By.css/By.directive)` over native `querySelector` — returns DebugElement

## Signal Testing

- Signals update synchronously — no `detectChanges()` needed for signal reads in unit tests
- For `effect()` testing: use `TestBed.flushEffects()` to flush pending effects synchronously
- For `resource()` testing: use `fakeAsync` + `tick()` or mock the resource loader function

## Service Testing

- Test services directly without TestBed when they have no Angular DI dependencies — plain class instantiation
- Use `TestBed.inject()` to get service instances when DI is needed — never `new ServiceClass()`
- Mock dependencies via `{ provide: MyService, useValue: mockService }` in providers array

## HTTP Testing

- Use `HttpTestingController` from `@angular/common/http/testing`
- Always call `httpMock.verify()` in `afterEach` to catch unexpected requests
- Never mock `HttpClient` directly — always use `HttpTestingController`

## Async Testing

- Use `fakeAsync` + `tick()` for timer-based async — covers setTimeout, setInterval, Promise resolution
- Use `async` + `fixture.whenStable()` for real async (HTTP, actual Promises outside fakeAsync)
- Never mix `fakeAsync` and real async — choose one per test

## Hard Rules

- Never access private component members in tests
- Never query third-party component internals — use harnesses
- Never use `fixture.nativeElement.querySelector` when `By.css` works
- Always `httpMock.verify()` in afterEach
- Never mock `HttpClient` directly

## Done Criteria

- No access to private component properties
- `httpMock.verify()` present in all HTTP test suites
- All `OnPush` components tested via `setInput()` not direct property assignment
- All effects flushed with `TestBed.flushEffects()` before asserting
- Tests pass with no console errors
