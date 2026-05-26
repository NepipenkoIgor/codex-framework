---
name: mobile-test-reactnative
description: React Native / Expo testing — Jest, React Native Testing Library, Detox E2E, native module mocking, navigation testing, offline behavior. Pair with mobile-test for universal patterns.
metadata:
  version: 1.0
  domain: mobile
  keywords: [react native test, jest, rntl, react native testing library, detox, e2e mobile, mock native modules, expo test, navigation testing, msw react native]
---

# React Native Testing

Pair with `mobile-test` for universal patterns (anti-patterns, fixture factories, CI, coverage).

## Setup

- Jest as test runner (ships with React Native and Expo)
- `@testing-library/react-native` (RNTL) for component tests
- Detox for E2E on real devices and simulators
- MSW for API mocking in integration tests

## Component Tests — Jest + RNTL

```tsx
import { render, screen, fireEvent, waitFor } from '@testing-library/react-native';
import { LoginScreen } from './LoginScreen';

describe('LoginScreen', () => {
  it('shows validation error for empty email', async () => {
    render(<LoginScreen onLogin={jest.fn()} />);
    fireEvent.press(screen.getByRole('button', { name: /sign in/i }));
    expect(screen.getByText(/email is required/i)).toBeTruthy();
  });

  it('calls onLogin with credentials when form is valid', async () => {
    const testPassphrase = 'secret123';
    const onLogin = jest.fn().mockResolvedValue(undefined);
    render(<LoginScreen onLogin={onLogin} />);
    fireEvent.changeText(screen.getByLabelText(/email/i), 'alice@test.com');
    fireEvent.changeText(screen.getByLabelText(/password/i), testPassphrase);
    fireEvent.press(screen.getByRole('button', { name: /sign in/i }));
    await waitFor(() => {
      expect(onLogin).toHaveBeenCalledWith({ email: 'alice@test.com', password: testPassphrase });
    });
  });

  it('disables submit button while loading', async () => {
    const testPassphrase = 'secret123';
    render(<LoginScreen onLogin={() => new Promise(() => {})} />);
    fireEvent.changeText(screen.getByLabelText(/email/i), 'alice@test.com');
    fireEvent.changeText(screen.getByLabelText(/password/i), testPassphrase);
    fireEvent.press(screen.getByRole('button', { name: /sign in/i }));
    await waitFor(() => {
      expect(screen.getByRole('button', { name: /signing in/i })).toBeDisabled();
    });
  });
});
```

## Mocking Native Modules

In `jest.setup.ts` — mock all native modules before tests run:

```ts
// react-native-reanimated — always first
require('react-native-reanimated').setUpTests();

// MMKV
jest.mock('react-native-mmkv', () => ({
  MMKV: jest.fn().mockImplementation(() => ({
    getString: jest.fn(),
    set: jest.fn(),
    delete: jest.fn(),
  })),
}));

// expo-secure-store
jest.mock('expo-secure-store', () => ({
  setItemAsync: jest.fn(),
  getItemAsync: jest.fn(),
  deleteItemAsync: jest.fn(),
}));

// expo-notifications
jest.mock('expo-notifications', () => ({
  setNotificationHandler: jest.fn(),
  getPermissionsAsync: jest.fn().mockResolvedValue({ status: 'granted' }),
  requestPermissionsAsync: jest.fn().mockResolvedValue({ status: 'granted' }),
  getExpoPushTokenAsync: jest.fn().mockResolvedValue({ data: 'ExponentPushToken[test]' }),
  addNotificationResponseReceivedListener: jest.fn(() => ({ remove: jest.fn() })),
}));

// react-native-gesture-handler — stub as View
jest.mock('react-native-gesture-handler', () => {
  const { View } = require('react-native');
  return { GestureDetector: View, Gesture: { Pan: jest.fn(() => ({ onUpdate: jest.fn().mockReturnThis(), onEnd: jest.fn().mockReturnThis() })) } };
});
```

## Navigation Testing — Expo Router

```tsx
// Wrap with router context for screens using router hooks
import { renderRouter, screen } from 'expo-router/testing-library';

it('navigates to project detail on item press', async () => {
  renderRouter({
    index: () => <HomeScreen />,
    'project/[id]': () => <ProjectDetailScreen />,
  });
  fireEvent.press(screen.getByText('Project Alpha'));
  await waitFor(() => {
    expect(screen.getByText('Project Alpha Details')).toBeTruthy();
  });
});
```

## Navigation Testing — React Navigation

```tsx
function renderWithNavigation(component: React.ReactElement) {
  return render(<NavigationContainer>{component}</NavigationContainer>);
}

it('navigates from home to details on item press', async () => {
  renderWithNavigation(<AppNavigator />);
  fireEvent.press(screen.getByText('Project Alpha'));
  await waitFor(() => {
    expect(screen.getByText('Project Alpha Details')).toBeTruthy();
  });
});
```

## Offline Behavior

```tsx
it('shows offline banner when disconnected', async () => {
  (NetInfo.fetch as jest.Mock).mockResolvedValue({ isConnected: false });
  render(<AppScreen />);
  await waitFor(() => { expect(screen.getByText(/you are offline/i)).toBeTruthy(); });
});

it('retries request when connection restores', async () => {
  let listener: Function;
  (NetInfo.addEventListener as jest.Mock).mockImplementation((cb) => {
    listener = cb;
    return jest.fn();
  });
  render(<AppScreen />);
  listener!({ isConnected: true });
  await waitFor(() => { expect(fetchSpy).toHaveBeenCalledTimes(2); });
});
```

## Snapshot Testing

Use sparingly — only for stable, purely presentational components:

```tsx
it('renders badge with correct style for warning variant', () => {
  const { toJSON } = render(<Badge variant="warning" label="Pending" />);
  expect(toJSON()).toMatchSnapshot();
});
```

Never snapshot entire screens or interactive components — explicit assertions are better.

## Detox E2E

```ts
describe('Login Flow', () => {
  beforeAll(async () => { await device.launchApp(); });
  beforeEach(async () => { await device.reloadReactNative(); });

  it('logs in with valid credentials', async () => {
    const testPassphrase = 'secret123';
    await element(by.id('email-input')).typeText('alice@test.com');
    await element(by.id('password-input')).typeText(testPassphrase);
    await element(by.id('login-button')).tap();
    await waitFor(element(by.id('home-screen'))).toBeVisible().withTimeout(5000);
  });

  it('shows error on invalid credentials', async () => {
    const invalidPassphrase = 'wrongpass';
    await element(by.id('email-input')).typeText('wrong@test.com');
    await element(by.id('password-input')).typeText(invalidPassphrase);
    await element(by.id('login-button')).tap();
    await waitFor(element(by.text('Invalid credentials'))).toBeVisible().withTimeout(3000);
  });
});
```

Rules:
- Add `testID` props to interactive elements that Detox needs to find
- Always `device.reloadReactNative()` in `beforeEach` — clean state
- Use `waitFor().withTimeout()` — never assume instant rendering
- Test happy path AND error path in every critical flow

## CI

```yaml
jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: 'npm' }
      - run: npm ci && npm test -- --coverage --ci

  detox-e2e:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: 'npm' }
      - run: npm ci && brew tap wix/brew && brew install applesimutils
      - run: npx detox build --configuration ios.sim.release
      - run: npx detox test --configuration ios.sim.release --cleanup --headless
```

## Done Criteria

- Component tests cover all 4 states: loading, error, empty, success
- All native modules mocked in `jest.setup.ts` — no native module errors in unit tests
- Navigation flows tested with router context or `NavigationContainer`
- E2E tests cover critical paths (login, main feature, error state)
- `testID` props on all elements Detox interacts with
