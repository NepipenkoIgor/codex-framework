---
name: visual-regression
description: Implement visual regression testing with Playwright screenshot comparison, Percy, Chromatic, or BackstopJS
metadata:
  version: 1.2
  argument-hint: "test framework (Playwright/Cypress), tool (Percy/Chromatic/BackstopJS), pages to test"
---

Implement visual regression testing for $ARGUMENTS.


## Playwright Visual Comparison

```typescript
import { test, expect } from '@playwright/test';

test('homepage matches baseline', async ({ page }) => {
  await page.goto('/');
  await page.waitForLoadState('networkidle');
  await expect(page).toHaveScreenshot('homepage.png', {
    maxDiffPixelRatio: 0.01,
    animations: 'disabled',
    mask: [page.locator('.dynamic-content'), page.locator('[data-testid="timestamp"]')],
  });
});

test('dashboard - empty state', async ({ page }) => {
  await page.route('**/api/data', route => route.fulfill({ json: { items: [] } }));
  await page.goto('/dashboard');
  await expect(page).toHaveScreenshot('dashboard-empty.png');
});

test('dashboard - loaded state', async ({ page }) => {
  await page.goto('/dashboard');
  await page.waitForSelector('[data-testid="data-table"]');
  await expect(page).toHaveScreenshot('dashboard-loaded.png');
});

// Component-level screenshot
test('button variants', async ({ page }) => {
  await page.goto('/storybook/button');
  const button = page.getByRole('button', { name: 'Submit' });
  await expect(button).toHaveScreenshot('button-default.png');
  await button.hover();
  await expect(button).toHaveScreenshot('button-hover.png');
});
```

## Configuration

```typescript
// playwright.config.ts
export default defineConfig({
  expect: {
    toHaveScreenshot: {
      maxDiffPixelRatio: 0.01,    // 1% pixel difference allowed
      threshold: 0.2,              // per-pixel color diff threshold
      animations: 'disabled',      // freeze CSS animations
    },
  },
  projects: [
    {
      name: 'visual-desktop',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1280, height: 720 } },
      testMatch: /.*\.visual\.spec\.ts/,
    },
    {
      name: 'visual-mobile',
      use: { ...devices['iPhone 13'] },
      testMatch: /.*\.visual\.spec\.ts/,
    },
  ],
  snapshotPathTemplate: '{testDir}/__screenshots__/{testFilePath}/{arg}{-projectName}{ext}',
});
```

## Masking Dynamic Content

```typescript
// Mask elements that change between runs
await expect(page).toHaveScreenshot('page.png', {
  mask: [
    page.locator('[data-testid="avatar"]'),      // user avatars
    page.locator('time'),                          // timestamps
    page.locator('.ad-banner'),                    // external content
    page.locator('[data-testid="random-hero"]'),   // A/B test content
  ],
});

// Style-based masking for complex cases
await page.addStyleTag({ content: '.chart-canvas { visibility: hidden !important; }' });
await expect(page).toHaveScreenshot('dashboard-no-charts.png');
```

## Responsive Breakpoints

```typescript
const breakpoints = [
  { name: 'mobile', width: 375, height: 812 },
  { name: 'tablet', width: 768, height: 1024 },
  { name: 'desktop', width: 1280, height: 720 },
  { name: 'wide', width: 1920, height: 1080 },
];

for (const bp of breakpoints) {
  test(`pricing page - ${bp.name}`, async ({ page }) => {
    await page.setViewportSize({ width: bp.width, height: bp.height });
    await page.goto('/pricing');
    await expect(page).toHaveScreenshot(`pricing-${bp.name}.png`);
  });
}
```

## Dark Mode Testing

```typescript
test('settings page - light mode', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'light' });
  await page.goto('/settings');
  await expect(page).toHaveScreenshot('settings-light.png');
});

test('settings page - dark mode', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.goto('/settings');
  await expect(page).toHaveScreenshot('settings-dark.png');
});
```

## CI Integration

```yaml
# .github/workflows/visual-regression.yml
name: Visual Regression
on: pull_request
jobs:
  visual-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npx playwright install --with-deps chromium
      - run: npx playwright test --project=visual-desktop --project=visual-mobile
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: visual-diff
          path: test-results/
          retention-days: 7
```

Update baselines: `npx playwright test --update-snapshots`. Review every update in PR diff.

## Percy Integration

```typescript
import percySnapshot from '@percy/playwright';

test('homepage', async ({ page }) => {
  await page.goto('/');
  await page.waitForLoadState('networkidle');
  await percySnapshot(page, 'Homepage', {
    widths: [375, 768, 1280],
    minHeight: 1024,
    percyCSS: '.dynamic-content { visibility: hidden !important; }',
  });
});
```

## Storybook + Chromatic

```bash
npx chromatic --project-token=$CHROMATIC_TOKEN --exit-zero-on-changes
```

Chromatic auto-captures every story. Review visual diffs in Chromatic UI. Accept/reject per component. TurboSnap: only test stories affected by code changes.

## Best Practices

- Store baselines in VCS — they are the source of truth
- Run visual tests on a single browser (Chrome) to avoid cross-browser noise
- Disable animations globally for deterministic screenshots
- Mask time-dependent, user-dependent, and random content
- Use `networkidle` or explicit waits — never arbitrary timeouts
- Full-page screenshots for layout verification, element screenshots for components
- Review baseline updates as carefully as code changes
- Run visual tests separately from functional E2E (faster feedback)

## Anti-Patterns

- Screenshots without masking dynamic content (timestamps, avatars, A/B slots) — constant false positives
- Too strict threshold (0.001) — fonts render differently across OS and CI
- Running on multiple browsers — exponential baseline maintenance with no proportional benefit
- Testing with live data — results change per environment; use mocked or seeded fixtures

## Tool Integration

- **browser automation**: `browser_navigate` → `browser_take_screenshot` → `browser_close` for quick visual verification during development
- docs lookup tools: Check latest Playwright screenshot API options

Done: ✓ baselines for critical pages and component states ✓ responsive breakpoints covered ✓ dark/light mode tested ✓ dynamic content masked ✓ animations disabled for consistency ✓ CI pipeline with artifact upload on failure ✓ baseline update process documented ✓ thresholds tuned to avoid false positives
