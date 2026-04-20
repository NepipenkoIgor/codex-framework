---
name: fullstack-nextjs-implement
description: Next.js 15 App Router full-stack — Server Components, Server Actions, Route Handlers, middleware, auth, DB access, caching
metadata:
  version: 2.0
  domain: frontend
  keywords: [nextjs, next.js, app router, server components, server actions, rsc, ssr, isr, metadata, next/image, next/font, route handlers, middleware, next-auth, auth.js, full-stack]
---

# Frontend Implement — Next.js (Full-Stack)

Pair with `frontend-implement` for universal rules. Next.js is a full-stack framework — this skill covers both UI and server-side concerns.

## App Router File Conventions

- `layout.tsx` — persistent shell across child routes. Never fetch per-request data here.
- `page.tsx` — route entry point. Default export always a Server Component unless opted out.
- `loading.tsx` — Suspense fallback. Required for any route with async data.
- `error.tsx` — error boundary. Must be `"use client"`. Receives `error` + `reset` props.
- `not-found.tsx` — rendered when `notFound()` is called from within the segment.
- `route.ts` — Route Handler. Export named HTTP methods: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`.
- `middleware.ts` — runs before every request in its matcher scope. Runs on Edge runtime.

## Server vs Client Components

- Default to Server Components — zero client JS unless browser APIs or interactivity needed.
- `"use client"` at the lowest leaf — never at layout or page level without reason.
- Server Components can import Client Components. Client → Server import is invalid — pass as `children` props instead.
- Never put secrets, DB calls, or business logic in Client Components.

## Server Actions (Mutations)

- Mark with `"use server"` — file-level or inline per function.
- Use for all in-app mutations — replaces API round-trips for same-origin changes.
- Always validate input with `zod` inside the action before touching DB — treat params as untrusted.
- After mutation call `revalidatePath('/path')` or `revalidateTag('tag')`.
- Pair with `useActionState` for error state, `useOptimistic` for instant UI response.
- Never expose secrets or raw DB errors in Server Action return values — client receives them.

## Route Handlers (API Endpoints)

- Use for: external webhooks, third-party clients, file upload streams, non-browser callers.
- Never duplicate a Server Action with a Route Handler for the same in-app mutation.
- Always validate request body with `zod` before processing.
- Return `NextResponse.json(data, { status })` — never plain `Response` without explicit status.
- Protect with auth check at the top: `const session = await auth(); if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })`.

## Middleware

- `middleware.ts` at project root — matches routes via `config.matcher`.
- Use for: auth redirects, locale detection, A/B flag injection, security headers.
- Never do DB calls in middleware — Edge runtime, no Node.js APIs, latency-sensitive.
- Always return `NextResponse.next()` or `NextResponse.redirect()` — never return undefined.
- Keep middleware fast: < 5ms budget. Anything heavier belongs in a Route Handler or Server Component.

## Auth (next-auth / Auth.js v5)

- Use `auth()` helper from `@/auth` in Server Components and Route Handlers — never roll custom session parsing.
- Protect pages: call `auth()` at top of Server Component, redirect to `/login` if null.
- Protect Route Handlers: check `auth()` at the top, return 401 immediately if unauthenticated.
- Use `auth` middleware export for route-level protection via matcher — reduces per-page boilerplate.
- Never store sensitive user data in the JWT beyond what the UI needs — keep tokens lean.

## Database Access

- Access DB only from Server Components, Server Actions, and Route Handlers — never from Client Components.
- Use Prisma or Drizzle — always parameterized, never string-concatenated queries.
- Never call `prisma.$connect()` / `prisma.$disconnect()` in request handlers — use singleton pattern with global caching in development.
- Wrap multi-step mutations in transactions — never allow partial failure to leave inconsistent state.

```ts
// Prisma singleton for development (prevents connection pool exhaustion)
const globalForPrisma = global as unknown as { prisma: PrismaClient }
export const prisma = globalForPrisma.prisma ?? new PrismaClient()
if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma
```

## Caching Model (Next.js 15)

- **fetch is uncached by default** — explicit opt-in required for every call:
  - `{ cache: 'force-cache' }` — cache indefinitely, purge on demand.
  - `{ next: { revalidate: N } }` — ISR: revalidate every N seconds.
  - `{ cache: 'no-store' }` — always fresh (dynamic).
- Never omit cache config — always state intent explicitly.
- `revalidateTag('tag')` preferred over `revalidatePath` for shared data across routes.

## Metadata & SEO

- Every page exports `metadata` or `generateMetadata` — title, description, OpenGraph image required.
- Dynamic metadata: `export async function generateMetadata({ params }): Promise<Metadata>`.
- Required OpenGraph: `title`, `description`, `images: [{ url, width, height }]`.

## Asset Optimization

- Always `next/image` `<Image>` — never `<img>`. Set `priority` on LCP image.
- Always `next/font` — never `@import` Google Fonts in CSS. Declare in `fonts.ts`, apply CSS variable on `<html>`.

## Hard Rules

- Never `getServerSideProps` / `getStaticProps` — Pages Router, invalid in App Router.
- Never omit cache config on fetch.
- Never `NEXT_PUBLIC_*` for secrets — inlined into client bundle at build time.
- Never DB calls in middleware — Edge runtime only.
- Never `"use client"` on a layout without documented reason.
- Never raw DB queries in Client Components or pages — Server Components and Actions only.
- Never expose DB errors or stack traces in Server Action return values or Route Handler responses.

## Done Criteria

- Zero `<img>` tags — all `next/image`.
- Zero `@import` font statements — all `next/font`.
- Every `fetch()` has explicit cache config.
- Every page exports `metadata` or `generateMetadata`.
- All mutations go through Server Actions or Route Handlers — no client-side direct DB access.
- All Server Actions validate input with zod before touching DB.
- All protected routes check `auth()` and redirect/return 401 if unauthenticated.
- LSP reports zero errors.
