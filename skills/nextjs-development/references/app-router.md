# App Router capability notes

Use this reference only after the main workflow establishes the installed Next.js line, target route, runtime, auth boundary, and existing repository pattern.

## Boundary choices

- Prefer a Server Component when data can remain server-side and the installed APIs support the required request/cache behavior.
- Add a Client Component only for browser state, effects, event handlers, or client-only libraries; keep the boundary as small as the interaction allows.
- Choose a Server Action for a mutation only when its invocation, authorization, progressive-enhancement, deployment, and test boundaries fit. A Route Handler or existing service/API may be the correct contract.
- Treat Route Handler and Action input as untrusted. Validate with the repository's established validator and authorize the exact actor, tenant, and resource in trusted server code.
- Select ORM/query access from the repository; do not introduce Prisma, Drizzle, or another data layer merely because an example uses it.

## Requests, caching, and runtime

Derive static/dynamic rendering, cache, revalidation, request APIs, proxy/middleware, and runtime selection from the installed capability and product freshness/security contract. Make cache behavior explicit when ambiguity would change correctness, but do not add redundant options everywhere. Measure latency in the real deployment instead of enforcing a corpus-wide threshold.

Use `loading.tsx`, error boundaries, metadata, and image components when the route's UX, discoverability, failure, or asset contract calls for them. They are not per-page universal requirements.

## Verification

Exercise fresh request, cached request, invalidation, replay, unauthorized/cross-tenant input, side-effect failure, and the selected deployment runtime where affected. Run manifest-defined focused tests, affected tests, type checks, and production build; interpret and rerun failures before completion.
