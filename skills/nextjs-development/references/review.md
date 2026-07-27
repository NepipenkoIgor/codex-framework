# Next.js review notes

Use only for an explicit review. Do not edit files; the main workflow remains authoritative.

Trace affected request and render paths, then report only evidence-backed findings with severity and file/line references. Prioritize:

- server/client boundary leaks, serialization, hydration, and unnecessary client surface;
- trusted-server validation and actor/tenant/resource authorization for Actions and handlers;
- cache freshness, invalidation, replay, and user-specific data isolation;
- runtime/engine/peer compatibility with the pinned stack;
- redirects, not-found/error/loading behavior and caller-visible failure states;
- query fan-out, streaming, bundle and deployment-runtime regressions;
- missing focused, affected, build, auth, cache, or deployment evidence.

Do not flag the absence of a fashionable API by itself. A finding needs a violated repository/product contract, executable counterexample, or current installed-line capability mismatch.
