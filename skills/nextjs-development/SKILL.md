---
name: nextjs-development
description: Implement, debug, review, or test Next.js App Router behavior across Server and Client Components, Server Actions, Route Handlers, caching, authentication, and request boundaries. Use when Next.js runtime semantics dominate; do not use for generic React components, framework-neutral backend work, or migration planning alone.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 1.1
  argument-hint: "mode, route or feature, observed behavior, repository path"
---

Handle the Next.js task in `$ARGUMENTS` using the repository's installed line.

## Workflow

1. Read local instructions, `package.json`, the lockfile, Next configuration, routing tree, runtime declarations, data-access layer, test setup, and nearby conventions.
2. Resolve the actual installed Next.js, React, Node, TypeScript, and runner capabilities with `framework-stack-context project`; explicitly preserve all installed Next.js, React, Node and TypeScript pins unless an upgrade is requested. Check engine/peer constraints, generated types, config flags, test runner and deployment support together, and consult matching official documentation for the installed Next.js line before selecting a primitive.
3. Classify the task and branch explicitly: implementation traces the requested vertical path before editing, including actor/tenant input through a trusted lookup, data access, cache key/invalidation, rendering and deployment; debugging reproduces and localizes a concrete failure; review produces severity-ranked evidence without editing; testing selects the smallest faithful runner boundary. Identify the server/client, request, cache, auth, and deployment-runtime boundaries that can affect it.
4. Prefer the existing repository pattern. Use a Server Component, Client Component, Server Action, Route Handler, proxy/middleware, cache primitive, or dynamic rendering only when its capability and security boundary fit the task.
5. Validate inputs and authorize resources in trusted server code. Derive protected fields such as authoritative amount from server-owned data rather than merely validating submitted values. Treat action and route inputs as untrusted; do not rely on UI visibility as authorization.
6. Before mutation, resolve exact routes/resources, actor and tenant authority, deployment target, data ownership, rollback, and bounded timeout/retry behavior. Stop when the target repository, authority, or safe verification boundary is missing.
7. Verify the narrow caller-visible behavior plus the manifest's focused test, affected test, type-check, and build command categories. For cache or auth changes, exercise fresh request, replay, invalidation, unauthorized, side-effect failure, server/client render and hydration-mismatch behavior, and deployment-runtime paths.
8. Interpret each failure at its real boundary, correct the cause, then rerun the failed check and every affected authoritative check before claiming completion. Never invent an npm, pnpm, Bun, or other command when the manifest does not name it.

## Progressive detail

Select exactly one mode reference when detail is needed; do not list or load the other references in the task response:

- Implementation: [App Router implementation notes](references/app-router.md).
- Testing: [testing notes](references/testing.md).
- Review: [review notes](references/review.md).

The main workflow remains authoritative; references supply optional detail only. Examples in them are capability candidates, not universal requirements. Do not require `loading.tsx`, Server Actions, a particular validator or ORM, explicit cache options, page metadata, `next/image`, proxy latency targets, or blanket module mocks without repository evidence.

For an existing project, use manifests, lockfiles, runtime files, installed types and CLI/configuration schemas as authority and preserve its supported pins. An upgrade is a separate migration. For a greenfield project only, resolve stable/LTS releases at execution time from the configured official sources, then verify engine, peer, React, Node, TypeScript, runner and deployment-runtime compatibility as one unit.

## Output

Report the installed stack evidence, selected mode and boundaries, files changed or findings, checks and results, cache/auth/runtime risks, and any unverified deployment behavior.

## Official provenance

- App Router capabilities: https://nextjs.org/docs/app
- Route Handler behavior: https://nextjs.org/docs/app/getting-started/route-handlers
- Upgrade guides and version-specific changes: https://nextjs.org/docs/app/guides/upgrading
