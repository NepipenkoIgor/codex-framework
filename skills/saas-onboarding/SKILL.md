---
name: saas-onboarding
description: Implement resumable product onboarding, activation milestones, progressive setup, checklists, lifecycle messaging, and completion analytics. Use when guiding an authenticated user or organization to first value; do not use for email verification, magic links, organization invitations, or generic analytics strategy.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  domain: product
  keywords: [product onboarding, activation, first value, checklist, setup wizard, resumable progress, lifecycle messaging]
---

# SaaS Product Onboarding

## Repository and Product Discovery

Inspect the existing user/org lifecycle, product analytics taxonomy, required setup dependencies, permissions, billing gates, saved drafts, notification channels, accessibility patterns, and evidence for the product's activation moment. Before material mutation, resolve exact task-owned targets, acting authority/permissions and owner, plus progress-schema/content/rollout rollback or recovery. Do not invent a universal checklist: define first value and required milestones with product evidence.

## Workflow

1. Define the activation outcome and measurable milestones separately from vanity completion.
2. Classify steps as required, optional, skippable, role-specific, organization-wide, or dependent on an external system.
3. Model durable progress on the server with versioned step identifiers and idempotent transitions; derive UI state from authoritative domain facts where possible.
4. Build the smallest resumable path to first value with save/continue, back/skip, error recovery, deep links, accessibility, and multi-device behavior.
5. Emit consent-aware viewed/started/completed/skipped/failed events with stable names and no unnecessary PII.
6. Test fresh account, invited member, returning user, partial failure, changed onboarding version, permission loss, and already-complete states.

## State and Concurrency

- Key progress by the correct subject: user, organization, workspace, or a combination. Never let one member overwrite an organization-wide step without authorization.
- Use idempotent commands and optimistic concurrency/version checks for transitions.
- Store schema/version and migration behavior so new steps do not reset completed users unexpectedly.
- Treat external integrations as resumable jobs with status and retry evidence, not a blocking browser request. Before enabling retries, derive a concrete attempts or elapsed-time ceiling from the onboarding operation deadline, provider rate/timeout contract, idempotency and unknown-outcome reconciliation, queue visibility/lease, downstream capacity, and observed recovery behavior; unresolved inputs block retry enablement rather than becoming a future unspecified policy.
- Completion is derived from required domain outcomes; a dismissed modal is not activation.

## Experience Boundaries

- Prefer progressive disclosure and contextual setup over a forced tour.
- Keep optional steps skippable and make consequences clear.
- Support keyboard, focus, labels, validation summaries, reduced motion, zoom, and screen-reader state changes.
- Do not trap existing users in onboarding after a deploy; always provide a safe application route and recovery path.
- Lifecycle messages respect consent, locale, time zone, frequency limits, and idempotency.

## Verification

Use exact test/type-check/build commands only after deriving them from repository manifests or documented harnesses. Never claim a check ran or passed without its command output; when execution evidence is absent, report `Not run` and keep completion unproven.

- Start on one device/session and resume on another; authoritative progress is consistent.
- Race two step completions and replay events; transitions and analytics remain idempotent.
- Fail an external integration midway; the user can retry/resume without losing prior work.
- Change onboarding version/steps; completed and in-progress users migrate according to policy.
- Verify invited/non-admin members see only authorized steps and cannot mutate organization-wide setup.
- Test initial load, refresh, deep link, skip/back, keyboard/focus, error recovery, and already-activated paths.

## Output Contract

Report the activation definition, subject and milestone model, required/optional dependency graph, persistence/version migration, UI states, analytics and lifecycle events, authorization/accessibility behavior, executed resume/race/failure tests, and residual product assumptions requiring validation.

## Done Criteria

- First value and activation are measurable domain outcomes.
- Progress is durable, resumable, authorized, versioned, and idempotent.
- Optional work is skippable and failures are recoverable.
- Analytics distinguishes exposure, progress, completion, skip, and failure without duplicating events.
- Fresh-load, resume, concurrency, migration, permission, and accessibility tests pass.
