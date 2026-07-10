---
name: fullstack-nextjs-test
description: Next.js 16 testing — Route Handlers, Server Actions, Server Components, async request APIs, next/navigation mocks, vitest config
metadata:
  version: 2.0
  domain: frontend
  keywords: [nextjs, next.js, testing, route handler test, server action test, server component, vitest, jest, next/navigation mock, next/headers mock, next-auth test]
---

# Full-Stack Next.js Test

Pair with `frontend-test` for universal principles and `frontend-test-react` for Client Component testing.

Prefer current stable Next.js test shapes, but follow the project version under test and report version drift when tests must preserve older behavior.

## Setup

- Use `vitest` with `@vitejs/plugin-react` — configure `environment: 'node'` for server-side tests, `environment: 'jsdom'` for component tests
- Or use `jest` with `next/jest` config: `const nextJest = require('next/jest'); const createJestConfig = nextJest({ dir: './' })`
- Separate test environments per file with `@vitest-environment node` / `@vitest-environment jsdom` docblock comments

## Mocking Next.js Internals

Always mock Next.js modules before importing the code under test:

```ts
// next/navigation — must mock before imports
vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => '/test-path',
  useSearchParams: () => new URLSearchParams(),
  redirect: vi.fn(),
  notFound: vi.fn(),
}))

// next/headers — for Server Components and Server Actions
vi.mock('next/headers', () => ({
  cookies: async () => ({ get: vi.fn(), set: vi.fn(), delete: vi.fn() }),
  headers: async () => new Headers(),
}))

// next/cache
vi.mock('next/cache', () => ({
  refresh: vi.fn(),
  updateTag: vi.fn(),
  revalidatePath: vi.fn(),
  revalidateTag: vi.fn(),
  unstable_cache: vi.fn((fn) => fn),
}))
```

## Testing Route Handlers

Test Route Handlers by constructing a real `Request` and calling the handler directly:

```ts
import { GET, POST } from '@/app/api/users/route'

it('returns 401 without auth', async () => {
  const req = new Request('http://localhost/api/users')
  const res = await GET(req)
  expect(res.status).toBe(401)
})

it('creates user with valid body', async () => {
  const req = new Request('http://localhost/api/users', {
    method: 'POST',
    body: JSON.stringify({ name: 'Igor', email: 'test@test.com' }),
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer valid-token' },
  })
  const res = await POST(req)
  const data = await res.json()
  expect(res.status).toBe(201)
  expect(data.id).toBeDefined()
})
```

- Always test: 401 without token, 400 with invalid body, 201/200 with valid input
- Mock DB calls (Prisma/Drizzle) per test — never hit real DB in Route Handler unit tests
- Use `vi.mock('@/lib/db')` to stub DB module

## Testing Server Actions

Call Server Actions as plain async functions — they are regular async functions with `"use server"` directive:

```ts
import { createUser } from '@/app/actions/users'

it('rejects invalid input', async () => {
  const result = await createUser({ name: '', email: 'bad' })
  expect(result.error).toBeDefined()
})

it('creates user and revalidates', async () => {
  mockPrisma.user.create.mockResolvedValue({ id: '1', name: 'Igor' })
  await createUser({ name: 'Igor', email: 'igor@test.com' })
  expect(revalidatePath).toHaveBeenCalledWith('/users')
})
```

- Mock DB and `revalidatePath`/`revalidateTag` — verify they were called with correct args
- Test validation rejection path — ensure bad input returns error, never throws

## Testing Server Components

Render Server Components as async functions — they return JSX:

```ts
import { render } from '@testing-library/react'
import UserPage from '@/app/users/[id]/page'

it('renders user name', async () => {
  mockPrisma.user.findUnique.mockResolvedValue({ id: '1', name: 'Igor' })
  const jsx = await UserPage({ params: Promise.resolve({ id: '1' }) })
  const { getByText } = render(jsx)
  expect(getByText('Igor')).toBeInTheDocument()
})
```

- Pass `params`, `searchParams` as resolved promises for Next.js 16 App Router components
- Mock all DB calls and `auth()` calls at module level

## Auth Testing

```ts
vi.mock('@/auth', () => ({
  auth: vi.fn(),
}))

// Authenticated request
mockAuth.mockResolvedValue({ user: { id: '1', role: 'admin' } })

// Unauthenticated
mockAuth.mockResolvedValue(null)
```

- Always test both authenticated and unauthenticated paths for protected handlers

## Hard Rules

- Never call real DB in Route Handler or Server Action unit tests — mock at module boundary
- Always mock `next/navigation`, `next/headers`, `next/cache` before importing server code
- Mock request-time APIs as async functions in Next.js 16 code
- Always test 401/403 paths explicitly
- Never test Client Components here — use `frontend-test-react` for those

## Done Criteria

- All Route Handlers tested: auth enforcement, validation rejection, happy path
- All Server Actions tested: validation rejection, DB call, revalidation call
- `next/navigation`, `next/headers`, and `next/cache` mocked in all server-side test files
- App Router `params` and `searchParams` passed as promises in Next.js 16 tests
- No real DB calls in unit tests
- Tests pass with `vitest` or `jest` in node environment
