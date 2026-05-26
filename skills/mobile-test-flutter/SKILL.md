---
name: mobile-test-flutter
description: Flutter testing — widget tests, unit tests, Riverpod/Bloc testing, GoRouter testing, golden tests, integration_test E2E. Pair with mobile-test for universal patterns.
metadata:
  version: 1.0
  domain: mobile
  keywords: [flutter test, widget test, integration test, flutter_test, bloc test, riverpod test, providerscope, golden test, mockito, mocktail, pumpWidget, pumpAndSettle, gorouter test]
---

# Flutter Testing

Pair with `mobile-test` for universal patterns (anti-patterns, fixture factories, CI, coverage).

## Unit Tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([AuthRepository])
void main() {
  late MockAuthRepository repository;
  late AuthService sut;

  setUp(() {
    repository = MockAuthRepository();
    sut = AuthService(repository: repository);
  });

  test('login returns user on success', () async {
    when(repository.login(any, any)).thenAnswer((_) async => testUser);
    final result = await sut.login('alice@test.com', 'secret');
    expect(result.email, 'alice@test.com');
  });

  test('login throws AuthException on failure', () async {
    when(repository.login(any, any)).thenThrow(AuthException('Invalid'));
    expect(() => sut.login('wrong', 'wrong'), throwsA(isA<AuthException>()));
  });
}
```

## Widget Tests

```dart
group('LoginScreen', () {
  testWidgets('shows validation error for empty email', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump(); // single frame — no async
    expect(find.text('Email is required'), findsOneWidget);
  });

  testWidgets('submits form with valid credentials', (tester) async {
    const testPassphrase = 'secret123';
    bool loginCalled = false;
    await tester.pumpWidget(MaterialApp(
      home: LoginScreen(onLogin: (_, __) async { loginCalled = true; }),
    ));
    await tester.enterText(find.byKey(const Key('email-field')), 'alice@test.com');
    await tester.enterText(find.byKey(const Key('password-field')), testPassphrase);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle(); // wait for async + animations
    expect(loginCalled, isTrue);
  });

  testWidgets('shows loading indicator while submitting', (tester) async {
    const testPassphrase = 'secret';
    final completer = Completer<void>();
    await tester.pumpWidget(MaterialApp(
      home: LoginScreen(onLogin: (_, __) => completer.future),
    ));
    await tester.enterText(find.byKey(const Key('email-field')), 'alice@test.com');
    await tester.enterText(find.byKey(const Key('password-field')), testPassphrase);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump(); // single frame — don't pumpAndSettle (blocks on completer)
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
});
```

Rules:
- `pump()` for synchronous UI updates (validation errors, immediate state)
- `pumpAndSettle()` for async operations and animations — waits until no more frames
- Never `pumpAndSettle()` when a Future never completes — it hangs
- Use `Key()` for form fields; use `byType`/`byText`/`bySemanticsLabel` for buttons

## Testing Riverpod State

```dart
// Unit test — use ProviderContainer directly
test('projectsProvider fetches and returns projects', () async {
  final container = ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(MockApiClient())],
  );
  addTearDown(container.dispose);

  when(mockApi.getProjects()).thenAnswer((_) async => [testProject]);
  final projects = await container.read(projectsProvider.future);
  expect(projects, [testProject]);
});

// Widget test — use ProviderScope.overrides
testWidgets('ProjectList renders from provider', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectsProvider.overrideWith((_) async => [testProject]),
      ],
      child: const MaterialApp(home: ProjectListScreen()),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Test Project'), findsOneWidget);
});
```

## Testing Bloc/Cubit

```dart
import 'package:bloc_test/bloc_test.dart';

const testPassphrase = 'secret';
const invalidPassphrase = 'wrong';

blocTest<AuthBloc, AuthState>(
  'emits [AuthLoading, Authenticated] on successful login',
  build: () => AuthBloc(repository: MockAuthRepository()),
  setUp: () => when(mockRepo.login(any, any)).thenAnswer((_) async => testUser),
  act: (bloc) => bloc.add(LoginRequested(email: 'alice@test.com', password: testPassphrase)),
  expect: () => [isA<AuthLoading>(), isA<Authenticated>()],
);

blocTest<AuthBloc, AuthState>(
  'emits [AuthLoading, AuthError] on failed login',
  build: () {
    when(mockRepo.login(any, any)).thenThrow(AuthException('Invalid credentials'));
    return AuthBloc(repository: mockRepo);
  },
  act: (bloc) => bloc.add(LoginRequested(email: 'wrong', password: invalidPassphrase)),
  expect: () => [isA<AuthLoading>(), isA<AuthError>()],
  verify: (bloc) => expect((bloc.state as AuthError).message, 'Invalid credentials'),
);
```

## Testing GoRouter Navigation

```dart
testWidgets('tapping project item navigates to detail screen', (tester) async {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(
      path: '/project/:id',
      builder: (_, state) => ProjectDetailScreen(id: state.pathParameters['id']!),
    ),
  ]);

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Project Alpha'));
  await tester.pumpAndSettle();

  expect(find.byType(ProjectDetailScreen), findsOneWidget);
});
```

## Golden Tests (Visual Regression)

```dart
testWidgets('ProfileCard matches golden', (tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: Scaffold(body: ProfileCard(name: 'Alice', role: 'Admin')),
  ));
  await expectLater(
    find.byType(ProfileCard),
    matchesGoldenFile('goldens/profile_card.png'),
  );
});
```

Rules:
- Run `flutter test --update-goldens` to generate/update golden files — commit them
- Review golden diffs in PRs — pixel changes are intentional or regressions
- Pin font rendering for deterministic output (use `--dart-define=CI=true`)
- Separate golden tests from unit/widget tests — run separately in CI

## Testing Platform Channels

```dart
setUp(() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(
      const MethodChannel('com.myapp/battery'),
      (call) async {
        if (call.method == 'getBatteryLevel') return 85;
        return null;
      },
    );
});

test('getBatteryLevel returns mocked value', () async {
  final level = await BatteryService.getBatteryLevel();
  expect(level, 85);
});
```

## Integration Tests

```dart
// test/integration_test/login_test.dart
import 'package:integration_test/integration_test.dart';
import 'package:myapp/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login flow end-to-end', (tester) async {
    const testPassphrase = 'secret123';
    app.main();
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('email-field')), 'alice@test.com');
    await tester.enterText(find.byKey(const Key('password-field')), testPassphrase);
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
```

## CI

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.x', cache: true }
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v4
        with: { file: coverage/lcov.info }

  integration-test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.x', cache: true }
      - run: flutter pub get
      - run: flutter test integration_test/ -d iPhone\ 15
```

## Done Criteria

- Unit tests mock all dependencies via `@GenerateMocks` or `mocktail`
- Widget tests cover loading, error, empty, and success states
- Riverpod providers tested with `ProviderContainer` (unit) and `ProviderScope.overrides` (widget)
- Bloc/Cubit tested with `bloc_test` — all events and expected state transitions
- GoRouter navigation flows verified in widget tests
- Golden files committed and reviewed in CI diffs
- Integration tests cover critical user flows end-to-end
- `flutter analyze` clean before running tests
