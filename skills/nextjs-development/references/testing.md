# Next.js testing notes

Use only when the installed runner must exercise a Next.js-specific boundary. The main workflow and repository test configuration remain authoritative.

1. Inspect the runner, environment, aliases, existing render/server helpers, generated types, and nearby tests.
2. Test pure domain code without framework mocks. Test Client Components through observable behavior. Use integration or runtime-capable tests for Server Components, Actions, Route Handlers, cache and request APIs when a unit mock would erase the risk.
3. Mock only the Next.js module and export crossed by the subject. Do not install blanket mocks for every `next/*` module.
4. Cover unauthorized input, validation, replay, redirect/not-found behavior, cache invalidation, fresh-load/hydration, and side-effect failure where relevant.
5. Run the manifest-defined focused and affected commands plus the manifest's type-check and build command categories. If a category is genuinely unavailable or inapplicable, report the repository evidence instead of silently omitting it.

Choose Vitest, Jest, Playwright, or another harness from the repository. Verify mock shape against the installed types; examples from another Next.js line are not authority.
