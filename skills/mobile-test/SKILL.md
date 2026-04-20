---
name: mobile-test
description: Write unit, widget, integration, and E2E tests for mobile apps
metadata:
  version: 1.7
  argument-hint: "feature/screen to test, test type (unit/widget/E2E), framework (RN/Flutter), device targets"
---

Write tests for $ARGUMENTS.

## Tool Integration

- **Type diagnostics**: run available diagnostics tools after every code change to catch type errors before completion
- docs lookup tools: fetch current library docs before implementing — never rely on training data alone

## React Native Testing

### Test Runner and Libraries

- Jest as test runner (ships with React Native and Expo)
- React Native Testing Library (RNTL) for component tests
- Detox for E2E tests on real devices and simulators
- MSW (Mock Service Worker) for API mocking in integration tests

### Component Tests (Jest + RNTL)

```tsx
import { render, screen, fireEvent, waitFor } from '@testing-library/react-native';
import { LoginScreen } from './LoginScreen';

describe('LoginScreen', () => {
  it('shows validation errors for empty email', async () => {
    render(<LoginScreen onLogin={jest.fn()} />);
    fireEvent.press(screen.getByRole('button', { name: /sign in/i }));
    expect(screen.getByText(/email is required/i)).toBeTruthy();
  });

  it('calls onLogin with credentials when form is valid', async () => {
    const onLogin = jest.fn().mockResolvedValue(undefined);
    render(<LoginScreen onLogin={onLogin} />);

    fireEvent.changeText(screen.getByLabelText(/email/i), 'alice@test.com');
    fireEvent.changeText(screen.getByLabelText(/password/i), 'secret123');
    fireEvent.press(screen.getByRole('button', { name: /sign in/i }));

    await waitFor(() => {
      expect(onLogin).toHaveBeenCalledWith({ email: 'alice@test.com', password: 'secret123' });
    });
  });

  it('disables submit button while loading', async () => {
    render(<LoginScreen onLogin={() => new Promise(() => {})} />);

    fireEvent.changeText(screen.getByLabelText(/email/i), 'alice@test.com');
    fireEvent.changeText(screen.getByLabelText(/password/i), 'secret123');
    fireEvent.press(screen.getByRole('button', { name: /sign in/i }));

    await waitFor(() => {
      expect(screen.getByRole('button', { name: /signing in/i })).toBeDisabled();
    });
  });
});
```

### Mocking Native Modules

Mock async-storage, MMKV, react-native-reanimated, gesture-handler (stub as View), expo-notifications, and platform channels in jest.setup.ts. Call `require('react-native-reanimated').setUpTests()` after mocking reanimated.

### Navigation Testing

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

### Snapshot Testing (Use Sparingly)

Only for stable, presentational components (icons, badges, static cards). Never snapshot entire screens or interactive components.

```tsx
it('renders badge with correct style for warning variant', () => {
  const { toJSON } = render(<Badge variant="warning" label="Pending" />);
  expect(toJSON()).toMatchSnapshot();
});
```

### Detox E2E Tests

Use `device.launchApp()` and `device.reloadReactNative()` in setup. Interact via `element(by.id/text).typeText().tap()`, then `waitFor().toBeVisible().withTimeout()` for assertions. Test happy path and error cases with real UI.

## Flutter Testing

### Flutter Unit Tests

Use `@GenerateMocks()` to generate mocks, mock repository dependencies in `setUp()`, then `when().thenAnswer()` for success paths and `when().thenThrow()` for errors. Assert with `expect()` and `throwsA()`.

### Widget Tests

```dart
group('LoginScreen', () {
  testWidgets('shows validation error for empty email', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(find.text('Email is required'), findsOneWidget);
  });

  testWidgets('submits form with valid data', (tester) async {
    bool loginCalled = false;
    await tester.pumpWidget(MaterialApp(
      home: LoginScreen(onLogin: (_, __) async { loginCalled = true; }),
    ));
    await tester.enterText(find.byKey(const Key('email-field')), 'alice@test.com');
    await tester.enterText(find.byKey(const Key('password-field')), 'secret123');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(loginCalled, isTrue);
  });

  // loading state: pass a delayed Future as onLogin, tap submit,
  // then pump() (not pumpAndSettle) and assert CircularProgressIndicator appears
});
```

### Golden Tests (Visual Regression)

```dart
testWidgets('ProfileCard matches golden file', (tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: Scaffold(body: ProfileCard(name: 'Alice', role: 'Admin')),
  ));
  await expectLater(find.byType(ProfileCard), matchesGoldenFile('goldens/profile_card.png'));
});
```

Rules: run `flutter test --update-goldens` to generate initial files; review golden diffs in PRs; separate golden tests from unit tests; pin font rendering for deterministic output.

### Testing Riverpod State

```dart
test('counterProvider increments correctly', () {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  expect(container.read(counterProvider), 0);
  container.read(counterProvider.notifier).increment();
  expect(container.read(counterProvider), 1);
});

testWidgets('counter screen reflects provider state', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [counterProvider.overrideWith(() => CounterNotifier()..state = 5)],
      child: const MaterialApp(home: CounterScreen()),
    ),
  );
  expect(find.text('5'), findsOneWidget);
});
```

### Testing Bloc State

```dart
blocTest<AuthBloc, AuthState>(
  'emits [loading, authenticated] on successful login',
  build: () => AuthBloc(repository: MockAuthRepository()),
  act: (bloc) => bloc.add(LoginRequested(email: 'alice@test.com', password: 'secret')),
  expect: () => [AuthLoading(), Authenticated(user: testUser)],
);

blocTest<AuthBloc, AuthState>(
  'emits [loading, error] on failed login',
  build: () {
    final repo = MockAuthRepository();
    when(repo.login(any, any)).thenThrow(AuthException('Invalid'));
    return AuthBloc(repository: repo);
  },
  act: (bloc) => bloc.add(LoginRequested(email: 'wrong', password: 'wrong')),
  expect: () => [AuthLoading(), AuthError(message: 'Invalid')],
);
```

### Testing GoRouter Navigation

Build a `GoRouter` with the routes under test, pass it to `MaterialApp.router(routerConfig: router)`, then drive navigation interactions and assert the target screen type appears after `pumpAndSettle`.

### Testing Platform Channels

Register a mock handler via `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, handler)` in `setUp`, then invoke the service under test and assert the expected value.

### Flutter Integration Tests

Call `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` then `app.main()` and drive the full UI flow with `tester.enterText` / `tester.tap` / `tester.pumpAndSettle` — same interaction API as widget tests but running the full app.

## Cross-Platform Testing Patterns

### Testing Offline Behavior

```tsx
// React Native — mock NetInfo
it('shows offline banner when network is unavailable', async () => {
  (NetInfo.fetch as jest.Mock).mockResolvedValue({ isConnected: false });
  render(<AppScreen />);
  await waitFor(() => { expect(screen.getByText(/you are offline/i)).toBeTruthy(); });
});

it('retries failed request when connection restores', async () => {
  let listener: Function;
  (NetInfo.addEventListener as jest.Mock).mockImplementation((cb) => { listener = cb; return jest.fn(); });
  render(<AppScreen />);
  listener!({ isConnected: true });
  await waitFor(() => { expect(fetchSpy).toHaveBeenCalledTimes(2); });
});
```

Flutter: override `connectivityProvider` with `MockConnectivity` that emits `[ConnectivityResult.none]` and assert the offline indicator appears.

### Testing Deep Link Resolution

```tsx
it('navigates to product screen from deep link', async () => {
  const navigateSpy = jest.fn();
  handleDeepLink('myapp://product/123', { navigate: navigateSpy });
  expect(navigateSpy).toHaveBeenCalledWith('ProductDetail', { id: '123' });
});

it('falls back to home for unknown deep link', () => {
  const navigateSpy = jest.fn();
  handleDeepLink('myapp://unknown', { navigate: navigateSpy });
  expect(navigateSpy).toHaveBeenCalledWith('Home');
});
```

### Testing Analytics Events

Spy on the analytics client in both platforms. Assert screen views fire on mount (`trackScreen`) and interaction events fire on user action (`trackEvent`) with the correct payload.

### Testing Accessibility Labels

```tsx
// React Native
it('has accessible labels on interactive elements', () => {
  render(<ProductCard product={mockProduct} />);
  expect(screen.getByLabelText('Add Product Alpha to cart')).toBeTruthy();
});
```

```dart
// Flutter
testWidgets('has correct semantic labels', (tester) async {
  await tester.pumpWidget(MaterialApp(home: ProductCard(product: testProduct)));
  final semantics = tester.getSemantics(find.byType(ProductCard));
  expect(semantics, matchesSemantics(label: 'Product Alpha, \$29.99'));
});
```

### Testing Push Notifications and Background Tasks

- Mock the notification SDK (expo-notifications, firebase_messaging); verify foreground, background, and killed-state handling; test deep link extraction from payload; test permission request flow
- `expo-background-fetch` is deprecated in SDK 53 — use `expo-background-task` (BGTaskScheduler on iOS, WorkManager on Android)
- Mock background task APIs and verify handlers process data correctly; test error handling and that tasks are registered with correct identifiers and constraints

## CI Integration

### React Native (GitHub Actions)

```yaml
jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: 'npm' }
      - run: npm ci && npm test -- --coverage --ci
      - uses: actions/upload-artifact@v4
        with: { name: coverage, path: coverage/ }

  detox-e2e:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: 'npm' }
      - run: npm ci && brew tap wix/brew && brew install applesimutils
      - run: npx detox build --configuration ios.sim.release
      - run: npx detox test --configuration ios.sim.release --cleanup --headless
      - uses: actions/upload-artifact@v4
        if: failure()
        with: { name: detox-artifacts, path: artifacts/ }
```

### Flutter (GitHub Actions)

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.x', cache: true }
      - run: flutter pub get && flutter analyze && flutter test --coverage
```

### Flaky Test Handling

- Retry flaky E2E tests up to 2 times: `--retries 2` (Detox), `--retry` (Flutter)
- Quarantine flaky tests to a separate CI job so they do not block merges
- Fix flaky tests within one sprint — quarantine is temporary

### Coverage

- Generate with `--coverage` (Jest, Flutter); upload to Codecov for PR-level diffs
- Set minimum thresholds per module, not globally; focus on critical path coverage

## Patterns

### Fixture Factories

```typescript
// React Native
function createUser(overrides: Partial<User> = {}): User {
  return { id: '1', name: 'Alice', email: 'alice@test.com', plan: 'free', ...overrides };
}
```

```dart
// Flutter
User createUser({String? id, String? name, String? email}) => User(
  id: id ?? '1', name: name ?? 'Alice', email: email ?? 'alice@test.com',
);
```

### Loading / Empty / Error / Success State Coverage

Every screen test should cover all four states: loading (spinner or skeleton), empty (empty state message), error (error message and retry button), and success (correct data rendering).

### Behavior-Driven Test Names

```
describe('LoginScreen')
  it('shows validation error when email is empty')
  it('disables submit while request is in flight')
  it('navigates to home on successful login')
  it('shows error toast on network failure')
```

Test isolation: each test starts from clean state; use `beforeEach`/`setUp` for fresh instances; mock timers and dates for deterministic behavior.

## Anti-Patterns

- Testing implementation details (internal state, private methods)
- Snapshot testing entire screens — use explicit assertions
- Testing framework behavior (does setState work? does Bloc emit?)
- Over-mocking: tests verify mocks, not code
- Ignoring async operations (missing `await`, missing `pumpAndSettle`)
- Coupling tests to testID/Key when accessible queries exist
- Not cleaning up subscriptions, timers, or listeners
- Skipping E2E tests because they are slow — they catch real integration bugs
- Testing only the happy path — error and edge cases catch the real bugs

## Output Requirements

- Produce concrete production-ready tests
- Use the testing framework already present in the project
- Follow the repository's existing test structure and conventions
- Always run tests after writing them — fix failures before declaring done

For each test suite:
- **Tests added**: list with test name and what behavior it verifies
- **Coverage**: scenarios covered (happy path, error, edge case)
- **Run results**: test execution output (pass/fail)
- **Gaps**: known scenarios not yet covered
