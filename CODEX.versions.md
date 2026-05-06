# CODEX Versions Policy

Target framework and runtime versions for Codex framework guidance.

This file is the source of truth for modern stack targets. Skills should describe practical implementation patterns, but they should not be the only place where target versions live.

## Core Rules

- Prefer the latest stable major version for new work unless the project explicitly pins an older supported major.
- Before substantial framework-specific work, detect the project's installed version from lock files, package manifests, SDK files, or build config.
- If the project is below the target major, mention the version drift and recommend an upgrade path before adding more code that deepens the old-version dependency.
- Do not silently rewrite an existing app to a new major during an unrelated feature. Create or recommend a focused migration branch when the upgrade has breaking changes.
- When project facts conflict with this file, obey the project for the current change and report the drift as residual risk.
- For unstable or fast-moving frameworks, verify current official docs before making broad migration claims.

## Target Versions

| Stack | Target | Minimum / notes | Official guide |
|---|---:|---|---|
| Next.js | 16.x | Node.js 20.9+, TypeScript 5.1+ | https://nextjs.org/docs/app/guides/upgrading/version-16 |
| React | 19.2+ | Prefer React Compiler-aware patterns; avoid defensive memoization by default | https://react.dev/blog |
| Node.js | 20.9+ | Use project LTS policy when stricter | https://nodejs.org/en/about/previous-releases |
| TypeScript | 5.1+ | Follow framework-specific minimums when higher | https://www.typescriptlang.org/docs/handbook/release-notes/overview.html |

## Next.js 16 Defaults

Use these as the default guidance for new Next.js App Router work:

- Turbopack is the default bundler for `next dev` and `next build`; remove redundant `--turbo` / `--turbopack` flags during migrations unless the project needs an explicit opt-out.
- Request-time APIs are async only: `cookies()`, `headers()`, `draftMode()`, `params`, and `searchParams` must be awaited where applicable.
- `proxy.ts` is the default request interception file. `middleware.ts` is deprecated and should be kept only for explicit Edge runtime cases or existing apps not yet migrated.
- Cache Components use `cacheComponents: true` and the `"use cache"` directive. Removed flags include `experimental.ppr`, route-level `experimental_ppr`, and `experimental.dynamicIO`.
- `revalidateTag()` should include a cache profile such as `revalidateTag(tag, 'max')`; use `updateTag()` in Server Actions when users must see their own writes immediately.
- `next/image` has stricter defaults: configure local query-string patterns, expected qualities, and remote patterns explicitly when needed.
- `next lint`, runtime config objects, and legacy App Router compatibility paths should not be introduced in new work.

## Upgrade Pressure

When a project is on Next.js 15.x:

1. Continue the requested work using the project's current conventions if the change is narrow.
2. Avoid introducing new `middleware.ts` usage unless the project requires Edge runtime.
3. Type new App Router pages with async `params` and `searchParams` so the code is forward-compatible.
4. Prefer cache APIs that map cleanly to Next.js 16.
5. Recommend a dedicated migration branch using the official codemod and upgrade guide.

When a project is on Next.js 14.x or older:

1. Treat the version gap as architectural risk for substantial feature work.
2. Prefer migration planning before broad App Router, auth, caching, or routing changes.
3. Flag security and maintenance risk when middleware/auth behavior is involved.
