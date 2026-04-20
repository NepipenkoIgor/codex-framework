---
name: mobile-implement-flutter
description: Flutter/Dart implementation patterns — GoRouter, Riverpod, Bloc, Drift/Hive, animations, platform channels, push notifications. Pair with mobile-implement for universal rules.
metadata:
  version: 1.0
  domain: mobile
  keywords: [flutter, dart, riverpod, bloc, cubit, gorouter, shellroute, hive, drift, sqflite, flutter_secure_storage, firebase_messaging, flutter_local_notifications, methodchannel, eventchannel, animationcontroller, hero, rive, lottie, cached_network_image, pubspec]
---

# Flutter Implementation

Pair with `mobile-implement` for universal rules (touch targets, safe areas, offline concepts, security principles).

## Project Structure

Clean Architecture — mandatory for maintainable Flutter apps:

```
lib/
  app/              # GoRouter config, theme, app-level providers
  features/
    auth/
      presentation/ # screens, widgets, providers/blocs
      domain/       # entities, repository interfaces, use cases
      data/         # repository implementations, data sources, DTOs
    home/
    profile/
  shared/
    widgets/        # reusable UI components
    providers/      # app-wide Riverpod providers
    utils/          # extensions, helpers
```

Rules:
- Each feature is self-contained — never import from another feature's internals
- Domain layer has zero Flutter dependencies — pure Dart classes only
- Data layer owns all network/storage calls — nothing else touches HTTP or DB directly

## Navigation — GoRouter

Always use GoRouter (Navigator 2.0). Never use imperative `Navigator.push` for app navigation.

```dart
@riverpod
GoRouter router(RouterRef ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      if (!isLoggedIn && !isAuthRoute) return '/auth/login';
      if (isLoggedIn && isAuthRoute) return '/';
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppScaffold(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(
            path: '/project/:id',
            builder: (_, state) => ProjectDetailScreen(
              id: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
    ],
  );
}
```

Rules:
- Always `ShellRoute` for persistent bottom navigation — rebuilds nothing on tab switch
- Auth guard in `redirect` — never inside individual screens
- Type-safe params via `pathParameters` / `queryParameters` — never positional casting
- Max 3 navigator nesting levels
- Register deep linking in `AndroidManifest.xml` and `Info.plist`

## State Management

### Riverpod — Preferred for New Projects

Always use Riverpod with code generation (`@riverpod` annotation + `build_runner`):

```dart
// Async data provider
@riverpod
Future<List<Project>> projects(ProjectsRef ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getProjects();
}

// Mutable state with Notifier
@riverpod
class ProjectFilter extends _$ProjectFilter {
  @override
  String build() => 'all';
  void set(String filter) => state = filter;
}

// Derived/combined provider
@riverpod
List<Project> filteredProjects(FilteredProjectsRef ref) {
  final all = ref.watch(projectsProvider).valueOrNull ?? [];
  final filter = ref.watch(projectFilterProvider);
  return filter == 'all' ? all : all.where((p) => p.status == filter).toList();
}
```

In widgets — always `ConsumerWidget` or `ConsumerStatefulWidget`:

```dart
class ProjectListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(projectsProvider).when(
      data: (projects) => ListView.builder(
        itemCount: projects.length,
        itemBuilder: (_, i) => ProjectTile(project: projects[i]),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => ErrorView(
        message: err.toString(),
        onRetry: () => ref.invalidate(projectsProvider),
      ),
    );
  }
}
```

### Bloc/Cubit — Event-Driven or Existing Codebase

Use `Cubit` for simple state, `Bloc` for complex event flows:

```dart
// Cubit
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.system);
  void toggle() => emit(state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository repository}) : super(AuthInitial()) {
    on<LoginRequested>(_onLogin);
  }

  Future<void> _onLogin(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await _repository.login(event.email, event.password);
      emit(Authenticated(user: user));
    } on AuthException catch (e) {
      emit(AuthError(message: e.message));
    }
  }
}
```

Rules:
- Provide Blocs at route level — not globally unless truly app-wide
- `BlocConsumer` when you need both UI rebuild and side effects from same bloc
- Separate events, states, bloc logic into distinct files for anything >50 lines

## Storage

| Store | Use case | Package |
|---|---|---|
| Key-value preferences | App settings, cached flags | `hive` |
| Relational data | Offline-first, reactive queries, migrations | `drift` |
| Secrets, tokens | Encrypted platform keychain | `flutter_secure_storage` |

Rules:
- Never `shared_preferences` for sensitive data — unencrypted
- `flutter_secure_storage` for ALL tokens — Keychain (iOS), EncryptedSharedPreferences (Android)
- `Drift` for relational data: write-ahead logging, reactive streams, compile-time SQL
- Clear all storage including secure storage on logout

```dart
// flutter_secure_storage with Riverpod
@riverpod
class AuthTokens extends _$AuthTokens {
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> build() => _storage.read(key: 'access_token');

  Future<void> save(String access, String refresh) async {
    await Future.wait([
      _storage.write(key: 'access_token', value: access),
      _storage.write(key: 'refresh_token', value: refresh),
    ]);
    state = AsyncData(access);
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: 'access_token'),
      _storage.delete(key: 'refresh_token'),
    ]);
    state = const AsyncData(null);
  }
}
```

## Animations

**Implicit** (value-driven, simple): `AnimatedContainer`, `AnimatedOpacity`, `AnimatedSwitcher`, `TweenAnimationBuilder` — always set `duration` and `curve`.

**Explicit** (full control): `AnimationController` + `Tween` + `CurvedAnimation`:

```dart
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({required this.child, super.key});
  final Widget child;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    duration: const Duration(milliseconds: 300),
    vsync: this,
  )..forward();

  late final _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  late final _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}
```

**Shared element**: `Hero` widget — same `tag` on source and destination.
**Complex**: Rive for state machines, Lottie for vector animations.

Rules:
- Always `dispose()` AnimationControllers — memory leaks crash real devices
- Prefer implicit animations for simple state changes — less boilerplate, same result
- Always specify `curve` — `Curves.easeOut` for enter, `Curves.easeIn` for exit
- Check `MediaQuery.of(context).disableAnimations` and skip animations when true

## Performance

- `const` constructors everywhere possible — Flutter skips rebuild for const widgets entirely
- `ListView.builder` for all lists — never `ListView` with a `children` array
- `SliverList` + `SliverAppBar` for complex scrolling — never `NestedScrollView` unless needed
- `RepaintBoundary` around independently animated widgets — isolates GPU layer
- `cached_network_image` for all network images — caching, placeholder, error state included
- Never store images as base64 in state or props — memory explosion on lists
- Profile with Flutter DevTools (CPU, memory, frame timeline) before optimizing — never guess

```dart
// Wrong — rebuilds all items on any change, no virtualization
ListView(children: items.map((i) => ItemTile(item: i)).toList())

// Correct — only builds visible items
ListView.builder(
  itemCount: items.length,
  itemBuilder: (_, index) => ItemTile(item: items[index]),
)
```

## Push Notifications

```dart
class NotificationService {
  static Future<void> initialize() async {
    // Request permission (iOS)
    await FirebaseMessaging.instance.requestPermission();

    // Foreground display
    FirebaseMessaging.onMessage.listen(_showLocal);

    // Background tap → navigate
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // Terminated tap → navigate on launch
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleTap(initial);

    // Save token
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await api.savePushToken(token);
    FirebaseMessaging.instance.onTokenRefresh.listen(api.savePushToken);
  }

  static void _handleTap(RemoteMessage message) {
    final route = message.data['route'] as String?;
    if (route != null) router.go(route);
  }
}
```

## Platform Channels

For native access when no plugin exists:

```dart
// Method channel — request/response
class BatteryService {
  static const _channel = MethodChannel('com.myapp/battery');

  static Future<int> getBatteryLevel() async {
    try {
      return await _channel.invokeMethod<int>('getBatteryLevel') ?? -1;
    } on PlatformException catch (e) {
      throw BatteryException(e.message ?? 'Unknown');
    }
  }
}

// Event channel — streaming
class SensorService {
  static const _channel = EventChannel('com.myapp/sensor');
  static Stream<double> get stream =>
    _channel.receiveBroadcastStream().map((e) => e as double);
}
```

Rules:
- Check pub.dev before writing a platform channel — a plugin likely exists
- Always handle `PlatformException` — channel calls fail on unsupported platforms
- Use `EventChannel` for continuous data, `MethodChannel` for one-time calls

## Done Criteria

- All screens: loading, error, empty, success states
- GoRouter with auth guard in `redirect` — no unprotected routes
- All state in Riverpod providers or Blocs — no `setState` for business logic
- All tokens in `flutter_secure_storage` — never `hive` or `shared_preferences`
- `ListView.builder` for all lists — never unbounded children array
- All `AnimationController`s disposed in `dispose()`
- `const` constructors on all stateless widgets where possible
- Push notifications handle foreground, background, and terminated states
- `flutter analyze` returns zero errors and warnings
- Safe areas applied on all screens (`SafeArea` widget)
