---
name: process-hygiene
description: Universal process hygiene rules — browser cleanup, dev server lifecycle, API doc sync, and git flow. Applied by all agents automatically.
metadata:
  version: 1.4
  argument-hint: "framework context (Next.js/.NET/etc), API documentation tool (Swagger/OpenAPI)"
  category: cross-cutting
  applies_to: all
---

# Process Hygiene

> **Enforcement:** These rules are reinforced by the framework's role briefs and explicit verification steps. Cleanup is not hook-driven here; it must be stated and completed deliberately.

Universal rules that apply to every agent, every task, without exception.

## Browser Cleanup

Always close browser automation sessions when done. Never leave browser sessions open after a task completes.

## Dev Server Lifecycle

**Rule:** If you invoke any process via `Bash` that starts a server, you must kill it before finishing. No exceptions.

This includes:
- `npm run dev`, `yarn dev`, `next dev`
- `dotnet run`, `dotnet watch`
- `node server.js`, `ts-node index.ts`
- Any command that starts a process listening on a port

**Playwright `webServer` config** — when you configure `webServer` in `playwright.config.ts`, Playwright manages that server's lifecycle automatically. You do NOT need to manually kill it. But if you also started a server separately via Bash to test manually, kill that one.

**How to kill:** `kill $(lsof -ti:PORT)` or `pkill -f "next dev"` or the equivalent stop command.

## API Docs — Non-Optional

If you add, remove, or change any API endpoint (REST, GraphQL, Blazor API controller), updating the Swagger/OpenAPI spec is **not optional**. It must be done before marking the task complete. This includes:
- New routes or controllers
- Changed request/response shapes
- Removed endpoints
- Changed HTTP methods or status codes

## Git Flow — Always Use PRs

Every code change must go through a PR. **Never commit directly to any shared branch** — this includes `main`, `master`, `develop`, `staging`, `release/*`, or any branch that others depend on.

**Branch naming:** `<type>/<short-description>` — e.g. `feat/user-auth`, `fix/login-crash`, `chore/update-deps`. Types mirror Conventional Commits: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `perf`.

**Commit messages:** Conventional Commits format — `<type>(<scope>): <description>`. Lowercase, imperative, under 72 chars. No Co-Authored-By, no AI attribution.

**PR quality checklist — every PR must have:**
1. Clear title (matches commit type, under 70 chars)
2. Summary: what changed and why (not just what)
3. Test plan: how to verify the change works
4. No unrelated changes bundled in — one concern per PR

**Before opening PR:**
- Run lint and tests locally — don't open a PR that's already broken
- Rebase on the target branch, don't merge it in
- Squash fixup commits — history should be clean

**Never:** force-push to shared branches, merge your own PR without review (unless explicitly told to), or open a draft PR and leave it indefinitely.

## Modern Patterns — Always Prefer Current

Never suggest or implement legacy/deprecated patterns when a current idiomatic alternative exists.

**Before implementing any pattern:**
1. Use available docs lookup tools or official docs to verify the current recommended approach for the framework or library version in use
2. Check the project's existing code — if it already uses a modern pattern, match it
3. If you see a legacy pattern in the codebase, do NOT replicate it — use the current approach and note the discrepancy

**Examples of what this means in practice:**
- Next.js: App Router patterns over Pages Router; in Next.js 16, prefer `proxy.ts` over new `middleware.ts` unless Edge runtime is required
- React: hooks and server components over class components and HOC patterns
- .NET: minimal API / top-level statements over legacy controller boilerplate where appropriate
- Auth: platform-native auth (NextAuth v5, ASP.NET Identity) over hand-rolled JWT middleware

**When suggesting a fix or implementation:** if the existing code uses a legacy pattern, flag it as technical debt — don't silently perpetuate it. State the modern alternative.
