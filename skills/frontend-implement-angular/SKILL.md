---
name: frontend-implement-angular
description: Angular 19 signals, standalone, functional patterns — no NgModules, no class guards, always OnPush
metadata:
  version: 1.1
  domain: frontend
  keywords: [angular, signals, signal, computed, effect, resource, standalone, inject, rxjs, takeUntilDestroyed, functional guards, angular 19, input signal, output signal]
---

# Frontend Implement — Angular

Pair with `frontend-implement` for universal rules.

## Signals

- Use `signal()` for mutable local state, `computed()` for derived values, `effect()` only for side effects (DOM, analytics, logging)
- Never mutate state inside `effect()` — use `linkedSignal()` for derived writable state instead
- Use `input()` and `input.required()` for component inputs — never `@Input()` decorator
- Use `output()` for component outputs — never `@Output() EventEmitter`
- Use `model()` for two-way binding — never `@Input()`/`@Output()` pair for the same value

## Async Data

- Use `resource()` for promise-based async data fetching linked to signals
- Use `rxResource()` when the data source is an Observable
- Expose resource state via `.value()`, `.status()`, `.error()` signals — never subscribe manually to resource internals

## Templates — Control Flow

- Always use new control flow: `@if/@else`, `@for (track required)`, `@switch`
- Never use `*ngIf`, `*ngFor`, `*ngSwitch` — structural directives are legacy
- `@for` must always have a `track` expression — never `track $index` unless items have no identity

## Dependency Injection

- Always use `inject()` function — never constructor parameter injection for new code
- Place `inject()` calls at the top of the constructor body or in field initializers — never inside methods

## Components

- Always `standalone: true` — never NgModule-based components for new code
- Always `changeDetection: ChangeDetectionStrategy.OnPush` — never Default for new components
- Use `DestroyRef` + `takeUntilDestroyed()` for all RxJS subscriptions — never manual unsubscribe in ngOnDestroy

## Guards and Interceptors

- Always functional: `export const myGuard: CanActivateFn = (route, state) => { ... }`
- Never class-based guards (`implements CanActivate`) or class-based interceptors

## RxJS Discipline

- Prefer signals over `BehaviorSubject` for local component state
- When RxJS is needed: always `takeUntilDestroyed()`, never manual subscription tracking
- Use `toSignal()` to bridge Observables into signal world at component boundary
- Use `toObservable()` only when passing a signal value to an RxJS pipeline

## Server-Side Rendering (Angular SSR)

Angular 17+ has built-in SSR via `@angular/ssr` — not a separate framework, enabled with `ng add @angular/ssr`.

- Always guard browser APIs: `if (isPlatformBrowser(this.platformId))` — never access `window`/`document`/`localStorage` at class field level or constructor
- Inject `PLATFORM_ID` via `inject(PLATFORM_ID)` — use `isPlatformBrowser()` / `isPlatformServer()` from `@angular/common`
- Use `provideClientHydration(withEventReplay())` in `app.config.ts` — required for full hydration with event replay
- Use `TransferState` to pass server-fetched data to client — prevents double-fetching on hydration
- Mark components that cannot be hydrated with `ngSkipHydration` attribute — only as last resort
- Never use `setTimeout`/`setInterval` unconditionally in SSR — guard with `isPlatformBrowser()` or use `afterNextRender()`
- Use `afterNextRender()` for DOM interactions that must run after hydration — replaces `ngAfterViewInit` for SSR-safe DOM access
- `resource()` and `rxResource()` are SSR-compatible — prefer over manual HTTP + TransferState for data fetching

## Hard Rules

- Never `*ngIf` or `*ngFor` — use `@if` and `@for`
- Never constructor injection — use `inject()`
- Never class-based guards or interceptors — functional only
- Never NgModules for new code — `standalone: true` always
- Never `ChangeDetectionStrategy.Default` for new components — OnPush always
- Never subscribe without `takeUntilDestroyed()` cleanup
- Never `@Input()`/`@Output()` decorators — use `input()`/`output()`/`model()`

## Done Criteria

- No `*ngIf`/`*ngFor`/`*ngSwitch` in any template
- No constructor injection in any new service or component
- All subscriptions use `takeUntilDestroyed()`
- All components are `standalone: true` with `OnPush`
- All `@for` blocks have a non-index `track` expression
- LSP reports zero errors
