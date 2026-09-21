# Project Instructions

The global agreement owns generic behavior. Add only project facts and closer overrides here; never copy or weaken global policy.

This template is optional. Discover facts from authoritative project sources and fill only useful gaps in scope.

## Project contract

- Repository shape: document application/package/workspace boundaries.
- Stack authority: name the manifests and lockfiles that own versions.
- Commands: reference existing scripts/CI for install, development, checks, migrations and release; do not duplicate values.
- Environment map: name local, test, staging, production, and preview targets plus their authority source.
- Mutation boundary: state which environments/accounts/projects may be changed and what requires explicit approval.
- Verification: required provider/runtime/UI/caller evidence, CLI/API/connector identities, and where missing access blocks work.
- Integration/CI: protected branch, project rebase/merge/queue strategy, final-SHA readback, required hosted checks, local equivalents and PR-only checks.
- Batch lifecycle: ticket source/IDs, allowed transitions, evidence-comment format, and meanings such as `In Review` versus `Done`.
- Runtime files: each required ignored file's `copy|symlink|regenerate` method, locator, permissions, check and cleanup owner; never secret values.
- Interactive acceptance: routes, roles, viewports/devices and exact visible Browser/simulator evidence.

## Project-specific rules

- Preserve repository conventions and unrelated work. Record only durable facts or genuine closer exceptions; do not restate global behavior.
- If a closer exception authorizes degraded behavior, it must explicitly define trigger, semantics, provenance, user-visible state, observability, tests, and recovery/removal condition.

<!-- Add project-specific architecture, commands, environment identities, release rules, and closer exceptions here. -->
