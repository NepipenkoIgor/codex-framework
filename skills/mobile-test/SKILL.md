---
name: mobile-test
description: Design and implement mobile test coverage across unit, component/widget, integration, and device-level flows. Use for framework-neutral mobile test strategy or cross-platform behavior; use the React Native or Flutter specialization for tool-specific setup.
metadata:
  version: 2.0
  argument-hint: "platform, behavior, test level, device/lifecycle states, CI constraints"
  owner: mobile
  reviewed: "2026-07-26"
---

# Mobile Testing Baseline

Test observable behavior at the lowest layer that provides sufficient confidence. Do not duplicate the same assertion across every layer.

## Test Matrix

| Layer | Best for |
|---|---|
| Unit | reducers, parsing, validation, sync/conflict rules |
| Component/widget | rendering, interaction, accessibility, loading/error/empty states |
| Integration | storage, networking, navigation, permissions, native boundaries |
| Device E2E | critical user journeys and platform lifecycle behavior |

## Required State Coverage

Select the states affected by the change: cold start, restored session, foreground/background, interruption, permission denied/revoked, offline/reconnect, slow/failing network, process death, deep link, notification tap, rotation/resize, text scaling, and reduced motion.

## Rules

- Assert user-visible results rather than implementation details.
- Use deterministic clocks, IDs, network fixtures, and data factories.
- Mock only external or platform boundaries; keep application behavior real.
- Give device tests stable accessibility identifiers and isolate test accounts/data.
- Never hide flakiness with retries alone; identify and remove the race or nondeterminism.
- Keep platform-specific assertions explicit rather than weakening them into a lowest-common-denominator test.

## Workflow

1. Inspect the existing test stack and CI device coverage. Resolve the owners and write authority for affected apps, test accounts/data, devices and external systems, plus rollback/recovery ownership for any material mutation; isolated accounts do not by themselves prove ownership.
2. Derive a behavior/state matrix from acceptance criteria.
3. Allocate each behavior to the cheapest sufficient layer.
4. Implement fixtures and boundary controls before the assertions.
5. Run focused tests, then the repository's affected suite and platform build.
6. Record untested devices, OS versions, lifecycle states, or external services.

## Output Contract

- Behavior/state matrix
- Tests added by layer and platform
- Commands and results
- Flake controls and fixtures
- Remaining device or lifecycle coverage gaps
