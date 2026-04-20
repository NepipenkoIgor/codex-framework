---
name: e2e-test
description: Write end-to-end tests using Playwright for web applications
metadata:
  version: 1.11
  argument-hint: "critical user flows: auth, CRUD, workflows, forms, routing, error/empty states"
---

Write end-to-end tests for $ARGUMENTS using Playwright.


## Philosophy and Strategy

- Cover critical user paths first — auth, core CRUD, business workflows, form validation, routing, error states, empty states
- Test what the user sees and does, not internal state
- Prefer stable locators: role > label/placeholder/text > test-id > CSS (last resort)
- No arbitrary sleeps — wait for selectors, network idle, or specific conditions
- Every test independently runnable; no ordering dependencies
- Fewer reliable tests over many flaky ones

**Skip E2E for:** unit-level logic, every form field variation, styling details, third-party widget internals.

## Page Object Pattern

- One class per page/major component encapsulating selectors and actions
- Expose user-intent methods (`login`, `submitForm`) not raw clicks
- Assertions in test files only, not page objects

```
e2e/
  pages/login.page.ts  dashboard.page.ts
  fixtures/auth.fixture.ts
  tests/auth.spec.ts  dashboard.spec.ts
  playwright.config.ts
```

```typescript
// e2e/pages/login.page.ts
export class LoginPage {
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
  readonly errorMessage: Locator;

  constructor(private page: Page) {
    this.emailInput = page.getByLabel('Email');
    this.passwordInput = page.getByLabel('Password');
    this.submitButton = page.getByRole('button', { name: 'Sign in' });
    this.errorMessage = page.getByRole('alert');
  }

  async goto() { await this.page.goto('/login'); }
  async login(email: string, password: string) {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }
}
```

## Authentication Handling

- Log in once, save storage state to file; reuse via `storageState` in config or fixtures
- Avoid UI login in every test — use API login or stored state
- Test the login flow itself in a dedicated spec only

```typescript
// auth.setup.ts — run once
setup('authenticate', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('admin@example.com');
  await page.getByLabel('Password').fill('password');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page).toHaveURL('/dashboard');
  await page.context().storageState({ path: '.auth/user.json' });
});

// playwright.config.ts
projects: [
  { name: 'setup', testMatch: /.*\.setup\.ts/ },
  { name: 'chromium', use: { ...devices['Desktop Chrome'], storageState: '.auth/user.json' }, dependencies: ['setup'] },
  { name: 'mobile-chrome', use: { ...devices['Pixel 5'], storageState: '.auth/user.json' }, dependencies: ['setup'] },
],
```

## Test Isolation and Data

- Each test creates its own data or controls its seed data
- Use API calls in `beforeEach`/`afterEach` for setup/teardown
- Use unique identifiers (UUIDs, timestamps) to prevent parallel-run collisions
- Clean up created data in `afterEach` when tests mutate persistent state

## Waiting Strategies

- `page.waitForSelector`, `page.waitForURL`, `page.waitForResponse`, `locator.waitFor()`
- `expect(locator).toBeVisible()` and other auto-retrying assertions
- `page.waitForLoadState('networkidle')` only when truly needed
- Never `page.waitForTimeout()` — investigate the root cause instead

## API Mocking

Use **real backend** for integration, persistence, cross-service behavior in staging CI.

Use `page.route()` when testing specific API errors, slow responses/timeouts, frontend isolation, or hard-to-reproduce edge cases.

```typescript
// Error state
await page.route('**/api/products', (route) =>
  route.fulfill({ status: 500, contentType: 'application/json', body: '{"error":"Server error"}' })
);

// Delay to test loading state
await page.route('**/api/**', async (route) => {
  await new Promise((r) => setTimeout(r, 100));
  await route.fulfill({ json: { items: [] } });
});
```

## Advanced Patterns

**Visual regression**: `expect(page).toHaveScreenshot('name.png', { maxDiffPixelRatio: 0.01 })` — capture at stable states, store baselines in VCS, update deliberately.

**Accessibility**: `@axe-core/playwright` — `new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa']).analyze()`. Test keyboard-only navigation through critical flows.

**Multi-tab/popup**: `context.waitForEvent('page')` to capture new tabs. Test OAuth popups, file downloads, print dialogs.

**File upload**: `page.setInputFiles()` for inputs; `page.dispatchEvent` for drag-and-drop.

**Parallel execution**: fully independent tests, unique data per worker (append worker index), configure sharding for CI.

## Flaky Test Prevention

- Mock dates when time-dependent; avoid relying on list order unless explicitly sorted
- Use strict locators; fail fast on ambiguous matches
- `test.slow()` for genuinely slow flows — never inflate global timeout
- Investigate and fix flaky tests immediately; never add retry as a band-aid

## Configuration

```typescript
// playwright.config.ts
export default defineConfig({
  baseURL: 'http://localhost:3000',
  use: { trace: 'on-first-retry' },
  timeout: 30_000,     // action timeout
  globalTimeout: 300_000,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 2 : undefined,
  reporter: [['html'], ['list']],
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile-chrome', use: { ...devices['Pixel 5'] } },
    { name: 'mobile-safari', use: { ...devices['iPhone 13'] } },
  ],
});
```

Tag tests with `@smoke`, `@critical` using `test.describe`/grep. Run smoke on every PR, full suite nightly.

## Framework-Specific Patterns

**webServer config** — add to `playwright.config.ts` per framework:
- Next.js: `command: 'npm run dev'`, url `http://localhost:3000`; use `npm run build && npm run start` for production-like
- Angular: `command: 'npx ng serve --port 4200'`, url `http://localhost:4200`
- Nuxt: `command: 'npx nuxi dev --port 3000'`, url `http://localhost:3000`
- SvelteKit: `command: 'npm run build && npm run preview -- --port 4173'` for prod-like, or `npm run dev -- --port 5173`
- Blazor: `command: 'dotnet run --project ./src/App --urls http://localhost:5000'`, `timeout: 30000` (.NET cold start)

All configs: `reuseExistingServer: !process.env.CI`

### Next.js

Server Components render in initial HTML — no hydration wait needed. Test `redirect()` and `notFound()` by checking URL and response status. ISR: test cached content serves, then revalidation triggers. Middleware: set auth cookie before navigating via `context.addCookies()`. Parallel routes: test modal on intercepted nav vs full page on direct navigation.

### Angular

Wait for `app-root` selector, not zone.js timing hacks. Signals: assert rendered output not internal state. Zoneless (`provideExperimentalZonelessChangeDetection`): no zone stabilization needed, wait for actual content. Material/CDK: `.cdk-overlay-container` for dialogs; `.getByRole('option')` inside overlay for autocomplete.

```typescript
test('opens Material dialog', async ({ page }) => {
  await page.goto('/users');
  await page.getByRole('button', { name: 'Add User' }).click();
  const dialog = page.locator('.cdk-overlay-container').getByRole('dialog');
  await expect(dialog).toBeVisible();
  await dialog.getByLabel('Name').fill('Jane Doe');
  await dialog.getByRole('button', { name: 'Save' }).click();
  await expect(dialog).not.toBeVisible();
});
```

### Vue / Nuxt

`useAsyncData` pages: `page.waitForLoadState('networkidle')` before asserting. Page transitions: wait for `expect(page).toHaveURL('/about')`. Vue leave transitions: `page.waitForSelector('.v-enter-active', { state: 'hidden' })`. `@nuxt/test-utils` with `setup({ browser: true })` for integrated testing with `$fetch`.

### SvelteKit

Form actions redirect on success — test via `await expect(page).toHaveURL(...)`. Load function data is SSR-rendered — assert immediately. `use:enhance` prevents full reload — verify URL unchanged. Test progressive enhancement by disabling JS: `browser.newContext({ javaScriptEnabled: false })`. `+error.svelte`: navigate to broken route and check status + heading.

### Blazor

Static SSR: content in initial HTML, no circuit needed. Interactive Server: `page.waitForFunction(() => (window as any).Blazor !== undefined)`. WASM startup: wait for `loading-progress` to disappear and `blazor-error-ui` to be hidden (60s timeout for bundle download). Use `bunit` for component testing; Playwright for full user flows with real SignalR/auth.

SignalR real-time: trigger server event via `page.request.post('/api/test/trigger-...')`, then `page.waitForResponse(r => r.url().includes('_blazor'))`.

## Anti-Patterns

- Testing implementation details through the UI -- tests break on refactors that don't change behavior
- Shared mutable test data -- one test's writes cause unpredictable failures in another
- Adding retry counts to mask flaky tests -- hides real instability, slows CI

## Tool Integration

- **browser automation**: **MANDATORY:** Use browser automation (`available browser automation`) for visual verification of all test scenarios — not optional
- **Type diagnostics**: Type-check test files — catches incorrect `Page`, `Locator`, `expect` usage at write time.

Done: ✓ critical user flows covered ✓ page objects for reusable interactions ✓ stable locators (role/label/test-id) ✓ no arbitrary timeouts ✓ auth state saved once and reused ✓ tests independent and parallel-safe ✓ CI configured with retries, traces, artifact upload ✓ flaky tests investigated and fixed ✓ visual/a11y checks on key screens

## Structured Output Contract
- **Status**: `done` | `partial` | `blocked`
- **Changed**: `[file.ext: +lines/-lines, ...]` — list every modified file
- **Notes**: blockers or non-obvious decisions only — omit if none

Do NOT return prose summaries or recaps.
