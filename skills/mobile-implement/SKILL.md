---
name: mobile-implement
description: Build cross-platform mobile features — state management, offline storage, push notifications, gestures, animations, deep linking, OTA updates, and platform channels
metadata:
  version: 1.5
  argument-hint: "platform (React Native/Flutter/native), feature scope, state management, offline requirements, platform channels needed"
---

Implement mobile feature for $ARGUMENTS.

## Tool Integration

- **Type diagnostics**: run available diagnostics tools after every code change to catch type errors before completion
- docs lookup tools: fetch current library docs before implementing — never rely on training data alone


## Framework Selection

| Aspect | React Native / Expo | Flutter |
|--------|-------------------|---------|
| Language | TypeScript/JavaScript | Dart |
| UI paradigm | Native views via bridge/JSI | Custom rendering engine (Skia) |
| Hot reload | Fast Refresh | Hot Reload + Hot Restart |
| Navigation | Expo Router, React Navigation | GoRouter (built on Navigator 2.0) |
| State | Zustand, Redux, TanStack Query | Riverpod, Bloc, Provider |
| Offline storage | MMKV, WatermelonDB | Hive, Drift (sqflite), shared_preferences |
| Testing | Jest + Detox | flutter_test + integration_test |
| Best for | Teams with React/web experience | Performance-critical, custom UI, single codebase |

## React Native / Expo

Start with Expo managed; use `npx expo prebuild` vs full ejection. SDK 52+ requires New Architecture — verify deps; use development builds if incompatible.

### Navigation

**Expo Router** (file-based): Use for new projects; max 3 nesting levels; always handle "not found" route.

**React Navigation** (imperative): Define `ParamList`, use `createNativeStackNavigator`/`createBottomTabNavigator`, configure `LinkingOptions`. Set up Universal Links (iOS) and App Links (Android).

### State Management

**Zustand** (preferred): minimal boilerplate, MMKV persistence. **Redux Toolkit** for existing codebases. **TanStack Query** for server state. Keep client state separate from server state.

### Storage

**MMKV** for preferences (sync, ~30MB). **WatermelonDB/SQLite** for relational data (async). **expo-secure-store** for secrets (<2KB/item). Never store sensitive data in MMKV/AsyncStorage.

### Animations & Gestures

Use **react-native-reanimated** (UI thread): `useSharedValue`, `useAnimatedStyle`, `withSpring`, `withTiming`. Gesture-driven via `react-native-gesture-handler`. Haptic feedback: `expo-haptics`. Complex vectors: `lottie-react-native`. State machines: `rive-react-native`. Reanimated v4: use `Gesture.Pan()`, `Gesture.Tap()` directly with `useAnimatedStyle`.

```typescript
import Animated, { useSharedValue, useAnimatedStyle, withSpring } from 'react-native-reanimated';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';

function SwipeableCard({ onDismiss }: { onDismiss: () => void }) {
  const translateX = useSharedValue(0);
  const gesture = Gesture.Pan()
    .onUpdate((e) => { translateX.value = e.translationX; })
    .onEnd((e) => {
      if (Math.abs(e.translationX) > 150) {
        translateX.value = withSpring(e.translationX > 0 ? 500 : -500, {}, () => runOnJS(onDismiss)());
      } else {
        translateX.value = withSpring(0);
      }
    });
  const style = useAnimatedStyle(() => ({ transform: [{ translateX: translateX.value }] }));
  return (
    <GestureDetector gesture={gesture}>
      <Animated.View style={[styles.card, style]}><Text>Swipe</Text></Animated.View>
    </GestureDetector>
  );
}
```

### Audio / Video (React Native)

> **Deprecation:** `expo-av` was deprecated in SDK 52. Use `expo-video` (stable SDK 52+) for video playback and `expo-audio` (stable SDK 53+) for audio in new projects. `expo-av` will continue to work but will not receive new features.

### OTA Updates (EAS Update)

- Use `runtimeVersion` policy to prevent incompatible JS updates
- Check for updates on app foreground, not just on launch
- Never force-reload without user consent for non-critical updates
- Set `fallbackToCacheTimeout` to prevent blocking app launch

### Push Notifications (React Native)

Use `expo-notifications`; request permission after explaining value; handle all states (foreground/background/killed); navigate on tap; refresh token on launch; set channels (Android)

**@testing-library/react-native** for component tests. **Detox** for E2E (iOS/Android simulators). Add `testID` props for E2E selectors. Mock native modules in unit tests. Test offline behavior.

## Flutter

### Project Structure

Clean Architecture: `lib/ → app/ (routing, theme) → features/ (auth, home: presentation/domain/data) → shared/ (widgets, providers, utils)`

**GoRouter**: Type-safe routes with `pathParameters` and `queryParameters`. Use `ShellRoute` for persistent navigation. Use `redirect` for auth guards. Register deep linking in platform files.

### State Management (Flutter)

**Riverpod** (preferred for new projects):

```dart
// Provider for async data
@riverpod
Future<List<Project>> projects(ProjectsRef ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getProjects();
}

// Notifier for mutable state
@riverpod
class ProjectFilter extends _$ProjectFilter {
  @override
  String build() => 'all';
  void setFilter(String filter) => state = filter;
}

// In widget
class ProjectListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);
    return projectsAsync.when(
      data: (projects) => ListView.builder(
        itemCount: projects.length,
        itemBuilder: (context, i) => ProjectTile(project: projects[i]),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => ErrorWidget(error: err, onRetry: () => ref.invalidate(projectsProvider)),
    );
  }
}
```

**Bloc**: Use `Cubit` for simple state, `Bloc` for event-driven. Separate events/states/logic. Use `BlocProvider` for DI, `BlocBuilder`/`BlocConsumer` for UI.

**Hive** for preferences (typed, sync read). **Drift** for relational data (migrations, reactive, async). **flutter_secure_storage** for secrets. Never shared_preferences for sensitive data.


**AnimationController + Tween** for custom animations. **Hero** for shared element transitions. **AnimatedContainer/AnimatedOpacity/AnimatedSwitcher** for implicit animations. **Rive** for state machines. **Lottie** for vector animations. Combine **GestureDetector** with **AnimationController** for gesture-driven animations.

**firebase_messaging** for FCM (Android + iOS). **flutter_local_notifications** for display. Request permission on iOS. Handle: `onMessage` (foreground), `onMessageOpenedApp` (background tap), `getInitialMessage` (killed tap). Store and refresh token on `onTokenRefresh`.

**MethodChannel** for native code access, **EventChannel** for streaming events. Prefer platform-adaptive widgets; use `Platform.isIOS/isAndroid` for conditional behavior.

**flutter_test** for widgets/units, **integration_test** for E2E. Use `pumpWidget`, `tap`, `enterText`, `find.byType` for widget tests. Mock with `mockito`/`mocktail`. Test Riverpod state with `ProviderScope.overrides`.

**Safe areas**: React Native use `SafeAreaView` from context library; Flutter use `SafeArea` widget. **Tablet**: Detect width >= 768 (tablet), master-detail layout, 3-4 grid columns, 44x44pt touch targets. **Orientation**: Support both unless feature-locked; adapt layout; persist scroll position.

**React Native lists**: `FlatList` with `getItemLayout`, `keyExtractor`, memoized `renderItem`; `FlashList` for 1000+. **Flutter lists**: `ListView.builder`, `SliverList` for complex layouts; use `const` constructors. **Images**: React Native `expo-image` or `react-native-fast-image`; Flutter `cached_network_image`. Dispose controllers/streams, avoid base64 in state, use pagination, profile with platform tools.

Register URL scheme (`myapp://`), Universal Links (iOS), App Links (Android). Handle links when cold-started, backgrounded, foregrounded. Validate parameters before navigation. Test on both platforms.

Store tokens/secrets in platform keychain/keystore only. React Native: `expo-secure-store`; Flutter: `flutter_secure_storage`. Size limit ~2KB per item. Clear on logout; handle keychain failures gracefully.

Avoid: JS thread animations (use Reanimated/AnimationController), AsyncStorage for secrets (use SecureStore), ignoring safe areas, base64 images in state, leaking listeners/subscriptions.

## Implementation Workflow

1. Detect project setup: React Native (Expo/bare) or Flutter, existing patterns
2. Set up navigation with typed params and deep linking
3. Implement the feature screen with loading, error, and empty states
4. Add offline storage where data should persist
5. Set up push notifications if required
6. Optimize lists and heavy widgets
7. Add animations using native-thread animation APIs
8. Handle responsive layout for phone, tablet, and orientation
9. Write unit/widget tests for key interactions
10. Add E2E tests for critical flows

## Output Format

```
Feature:          [what was built]
Platform:         [React Native (Expo/bare) / Flutter]
Navigation:       [router and screen structure]
Deep Linking:     [URL scheme and route mapping]
State:            [Zustand / Riverpod / Bloc / etc.]
Storage:          [MMKV / Hive / Drift / SecureStore -- what and why]
Animations:       [Reanimated / AnimationController / Rive / Lottie]
Performance:      [list optimization, memoization, native thread usage]
Push:             [notification setup and handling, if applicable]
Responsive:       [phone/tablet/orientation adaptation]
Testing:          [unit/widget tests and E2E coverage]
```

## Done Criteria

- Screens handle loading, error, empty, and success states
- Navigation is type-safe with deep linking support
- Lists use lazy rendering with optimized scroll performance
- Animations run on native/UI thread (not JS/main thread)
- Sensitive data in platform keychain/keystore, preferences in fast key-value store
- Push notifications work in foreground, background, and killed states
- Layout works on phone (320-428px), tablet (768px+), and both orientations
- Safe areas handled for all device types (notch, home indicator, status bar)
- Deep links navigate to correct screen with validated parameters
- Component/widget tests cover key interactions; E2E tests cover critical flows
