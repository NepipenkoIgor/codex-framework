---
name: react-native-patterns
description: Implement React Native patterns — navigation, platform-specific code, performance, offline support, and native module integration
metadata:
  version: 1.5
  argument-hint: "feature type, platform (Expo/Bare), offline requirements, navigation style"
---

Implement React Native feature for $ARGUMENTS.


## Expo vs Bare

- Start with Expo managed unless you need a native module not available as a config plugin
- Use `npx expo prebuild` (continuous native generation) rather than full ejection
- Prefer Expo SDK modules over community alternatives when functionality matches

## Navigation

### Expo Router (File-Based) -- Preferred for new projects

```
app/
  _layout.tsx           # root layout (providers, auth check)
  (tabs)/_layout.tsx    # tab navigator
  (tabs)/index.tsx      # home tab
  (tabs)/profile.tsx    # profile tab
  (auth)/login.tsx      # auth stack
  (auth)/register.tsx   # auth stack
  settings/[section].tsx # dynamic route
  modal.tsx             # modal (presented over tabs)
  +not-found.tsx
```

#### Root Layout with Auth Guard

```tsx
// app/_layout.tsx
export default function RootLayout() {
  const { isAuthenticated, isLoading } = useAuth();

  if (isLoading) return <SplashScreen />;

  return (
    <Stack screenOptions={{ headerShown: false }}>
      {isAuthenticated ? (
        <>
          <Stack.Screen name="(tabs)" />
          <Stack.Screen name="modal" options={{ presentation: 'modal' }} />
        </>
      ) : (
        <Stack.Screen name="(auth)" />
      )}
    </Stack>
  );
}
```

#### Tab Layout with Icons and Badges

```tsx
// app/(tabs)/_layout.tsx
export default function TabLayout() {
  return (
    <Tabs screenOptions={{ tabBarActiveTintColor: '#007AFF' }}>
      <Tabs.Screen
        name="index"
        options={{
          title: 'Home',
          tabBarIcon: ({ color, size }) => <Ionicons name="home" size={size} color={color} />,
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: 'Profile',
          tabBarIcon: ({ color, size }) => <Ionicons name="person" size={size} color={color} />,
        }}
      />
    </Tabs>
  );
}
```

#### Deep Linking with Expo Router

Expo Router maps file paths to URLs automatically. Configure in `app.json`:

```json
{
  "expo": {
    "scheme": "myapp",
    "plugins": [["expo-router", { "origin": "https://myapp.example.com" }]]
  }
}
```

Navigate programmatically: `router.push('/settings/notifications')`, `router.replace('/(auth)/login')`, `router.back()`.

> **Expo Router v4:** `router.navigate()` always pushes (same behavior as `router.push()`). Use `router.dismiss()` to go back one screen, `router.dismissAll()` to return to the first screen in the stack, and `router.canDismiss()` to check if dismissal is possible.

Use `useLocalSearchParams<{ id: string }>()` for type-safe route params.

### React Navigation (Imperative)

Type-safe `ParamList` types for every navigator. `createNativeStackNavigator` + `createBottomTabNavigator`. Configure `LinkingOptions` for deep linking.

Rules: max 3 navigator nesting levels, always handle "not found" route, type-safe params.

## Deep Linking

Expo Router maps file paths to URLs automatically. Configure `scheme` in `app.json` and `expo-router` plugin with `origin`.

React Navigation: configure `LinkingOptions` with `prefixes` and `config.screens` mapping.

Rules: register URL scheme in `app.json`/native config, set up Universal Links (iOS) and App Links (Android), handle cold-start/background/foreground, validate deep link parameters, test with `npx uri-scheme open`.

## Offline Storage

| Storage | Use case | Sync/Async | Notes |
|---------|----------|------------|-------|
| MMKV | Preferences, tokens, small state | Sync | Use over AsyncStorage |
| WatermelonDB | Relational data, offline-first | Async (reactive) | Reactive queries |
| SQLite (expo-sqlite) | Direct SQL, migrations | Async | Full SQL |
| SecureStore | Credentials, secrets | Async | <2KB/item, encrypted |

Rules: MMKV over AsyncStorage always. WatermelonDB/SQLite for relational data. expo-secure-store for sensitive data (never MMKV/AsyncStorage for tokens). Clear user storage on logout.

MMKV as Zustand persistence: implement `StateStorage` interface with `getString`/`set`/`delete`.

### MMKV Setup with Zustand

```tsx
import { MMKV } from 'react-native-mmkv';
import { StateStorage } from 'zustand/middleware';

const storage = new MMKV();

export const mmkvStorage: StateStorage = {
  getItem: (name) => storage.getString(name) ?? null,
  setItem: (name, value) => storage.set(name, value),
  removeItem: (name) => storage.delete(name),
};

// Usage in Zustand store
export const useSettingsStore = create(
  persist<SettingsState>(
    (set) => ({ theme: 'light', setTheme: (theme) => set({ theme }) }),
    { name: 'settings', storage: createJSONStorage(() => mmkvStorage) },
  ),
);
```

### WatermelonDB for Offline-First Relational Data

Use for apps that need offline CRUD with background sync. Define models extending `Model`, use `@field`, `@date`, `@relation` decorators. Sync with backend via `synchronize()` pull/push protocol.

```typescript
// Sync pattern — pull changes from server, push local changes
await synchronize({
  database,
  pullChanges: async ({ lastPulledAt }) => {
    const response = await api.get(`/sync?last_pulled_at=${lastPulledAt}`);
    return { changes: response.changes, timestamp: response.timestamp };
  },
  pushChanges: async ({ changes }) => {
    await api.post('/sync', { changes });
  },
});
```

Rules: keep sync payload small (delta only), handle conflict resolution server-side (last-write-wins or merge), run sync on app foreground and after connectivity restored.

## OTA Updates (EAS Update)

Configure `runtimeVersion` policy and `updates.url` in `app.json`. Check for updates on app foreground (not just launch). Never force-reload without consent for non-critical updates. Use EAS Update channels for staging/production separation.

### Update Flow with User Consent

```typescript
import * as Updates from 'expo-updates';
import { useEffect } from 'react';
import { AppState } from 'react-native';

function useOTAUpdates() {
  useEffect(() => {
    const subscription = AppState.addEventListener('change', async (state) => {
      if (state !== 'active' || __DEV__) return;
      try {
        const update = await Updates.checkForUpdateAsync();
        if (!update.isAvailable) return;
        await Updates.fetchUpdateAsync();
        // Non-critical: show banner; critical: reload immediately
        if (update.manifest?.extra?.critical) {
          await Updates.reloadAsync();
        } else {
          showUpdateBanner(() => Updates.reloadAsync());
        }
      } catch (e) {
        // Silent fail — user keeps current version
        console.warn('OTA update check failed:', e);
      }
    });
    return () => subscription.remove();
  }, []);
}
```

### Channel Strategy

```json
{
  "expo": {
    "updates": { "url": "https://u.expo.dev/project-id" },
    "runtimeVersion": { "policy": "fingerprint" }
  }
}
```

Channels: `staging` for QA builds, `production` for store builds. Publish: `eas update --channel production --message "fix: resolve crash on checkout"`. Rollback: `eas update:rollback --channel production` to revert to previous update.

## Push Notifications (Expo)

Request permission only after explaining value. Register token with `Notifications.getExpoPushTokenAsync`. Handle foreground display with `setNotificationHandler`. Navigate on notification tap via `addNotificationResponseReceivedListener`. Refresh token on launch, remove stale tokens on API errors. Set Android notification channels.

### Full Setup

```tsx
import * as Notifications from 'expo-notifications';
import * as Device from 'expo-device';
import { router } from 'expo-router';

// Configure foreground behavior — must be outside component
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: true,
  }),
});

// Android channels — call once at app startup
if (Platform.OS === 'android') {
  Notifications.setNotificationChannelAsync('default', {
    name: 'Default',
    importance: Notifications.AndroidImportance.HIGH,
    vibrationPattern: [0, 250, 250, 250],
  });
}

async function registerForPushNotifications(): Promise<string | null> {
  if (!Device.isDevice) return null; // push does not work on simulators

  const { status: existing } = await Notifications.getPermissionsAsync();
  let finalStatus = existing;
  if (existing !== 'granted') {
    const { status } = await Notifications.requestPermissionsAsync();
    finalStatus = status;
  }
  if (finalStatus !== 'granted') return null;

  const token = (await Notifications.getExpoPushTokenAsync({ projectId: 'your-project-id' })).data;
  await api.post('/push-tokens', { token, platform: Platform.OS });
  return token;
}

// Navigate on notification tap
function useNotificationNavigation() {
  useEffect(() => {
    const sub = Notifications.addNotificationResponseReceivedListener((response) => {
      const data = response.notification.request.content.data;
      if (data?.screen) router.push(data.screen as string);
    });
    return () => sub.remove();
  }, []);
}
```

> **Push notifications in Expo Go:** Push notification testing was removed from Expo Go in SDK 53. Use a development build (`npx expo run:ios` / `npx expo run:android`) or a real device with EAS Build for push notification development and testing.

### FCM/APNs Configuration

Expo managed workflow: configure `googleServicesFile` (Android) and push notification capability (iOS) in `app.json`. For bare workflow, use `@react-native-firebase/messaging` with native FCM/APNs setup. Always send to Expo Push API for managed, or directly to FCM/APNs for bare.

## Performance

### FlatList Optimization

```tsx
<FlatList
  data={data}
  renderItem={useCallback(({ item }) => <MemoizedItem item={item} />, [])}
  keyExtractor={useCallback((item: Item) => item.id, [])}
  getItemLayout={(_, index) => ({ length: ITEM_HEIGHT, offset: ITEM_HEIGHT * index, index })}
  maxToRenderPerBatch={10}
  windowSize={5}
  removeClippedSubviews={true}
/>
```

Use `React.memo` for list items, `getItemLayout` for fixed heights, `FlashList` for 1000+ items.

### Hermes Engine

Hermes is the default JS engine for React Native (enabled by default in Expo SDK 49+). Benefits: faster startup (bytecode precompilation), lower memory, smaller bundle. Verify Hermes is active: `global.HermesInternal != null`. Avoid Hermes-incompatible patterns: `with` statements, `eval()` in strict mode, some legacy Intl APIs (use `expo-localization` or polyfills).

### General Performance Rules

- Avoid inline object/array creation in props: `style={{ flex: 1 }}` creates new object every render -- use `StyleSheet.create` or stable references
- Use `useCallback` for callbacks passed to memoized children
- Avoid complex computation in render -- move to `useMemo` or background (worklet)
- Profile with Flipper or React DevTools Profiler before optimizing
- Monitor JS thread FPS: any drop below 60fps in JS thread means layout/computation is too heavy

### Animations -- react-native-reanimated

All animations must use `useSharedValue` + `useAnimatedStyle` (runs on UI thread). Use `withSpring` for interactive elements, `withTiming` for simple transitions.

## Gestures

Use `react-native-gesture-handler` with `Gesture.Pan()`, `.onUpdate()`, `.onEnd()`. Combine with `react-native-reanimated` for 60fps gesture-driven animations.

### Swipe-to-Delete

```tsx
function SwipeableRow({ onDelete, children }: { onDelete: () => void; children: React.ReactNode }) {
  const translateX = useSharedValue(0);
  const DELETE_THRESHOLD = -100;

  const pan = Gesture.Pan()
    .activeOffsetX([-10, 10])
    .onUpdate((e) => { translateX.value = Math.min(0, e.translationX); })
    .onEnd(() => {
      if (translateX.value < DELETE_THRESHOLD) {
        translateX.value = withTiming(-300, {}, () => runOnJS(onDelete)());
      } else {
        translateX.value = withSpring(0);
      }
    });

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: translateX.value }],
  }));

  return (
    <GestureDetector gesture={pan}>
      <Animated.View style={animatedStyle}>{children}</Animated.View>
    </GestureDetector>
  );
}
```

### Drag and Drop

Use `Gesture.Pan()` with `runOnJS` for state updates. Track item positions in shared values. Use `Gesture.Simultaneous()` when combining pan with long press (drag activation). For list reordering, prefer `react-native-draggable-flatlist`.

## Responsive Layouts

Use `useWindowDimensions` (reactive, not static `Dimensions.get`). Design for 320px minimum. Use `flexGrow`/percentage widths. Adapt for tablet: multi-column, sidebar, master-detail. Handle orientation changes. Use `Platform.select()` for platform-specific values.

## Secure Storage

expo-secure-store (Keychain on iOS, EncryptedSharedPreferences on Android). Store only small sensitive values (<2KB). Handle failures gracefully (device Keychain issues). Clear on logout.

### Secure Token Management

```tsx
import * as SecureStore from 'expo-secure-store';

const TOKEN_KEY = 'auth_token';
const REFRESH_KEY = 'refresh_token';

export const secureTokens = {
  async save(access: string, refresh: string) {
    await SecureStore.setItemAsync(TOKEN_KEY, access);
    await SecureStore.setItemAsync(REFRESH_KEY, refresh);
  },
  async getAccess(): Promise<string | null> {
    try { return await SecureStore.getItemAsync(TOKEN_KEY); }
    catch { return null; } // Keychain unavailable (device locked, restored backup)
  },
  async getRefresh(): Promise<string | null> {
    try { return await SecureStore.getItemAsync(REFRESH_KEY); }
    catch { return null; }
  },
  async clear() {
    await SecureStore.deleteItemAsync(TOKEN_KEY);
    await SecureStore.deleteItemAsync(REFRESH_KEY);
  },
};
```

Rules: never store tokens in MMKV or AsyncStorage. Use `SecureStore.WHEN_UNLOCKED` for auth tokens (default). Use `SecureStore.AFTER_FIRST_UNLOCK` for push tokens that need background access. Size limit is 2KB per item -- for larger data, encrypt with a key stored in SecureStore and save encrypted data in MMKV.

## Testing

Component tests: `@testing-library/react-native` -- test behavior, not implementation. E2E: Detox on iOS/Android simulators. Add `testID` props for selectors. Mock native modules in unit tests. Test offline behavior.

## Anti-Patterns

- `Animated` from core RN for interactive animations — JS thread jank; use `react-native-reanimated` on the UI thread
- AsyncStorage for auth tokens or sensitive data — unencrypted; use `expo-secure-store`
- Storing images as base64 in state or props — causes memory explosion on large lists
- `ScrollView` for dynamic or large lists — no virtualization; use `FlatList` or `FlashList`

## Output Format

```
Feature:          [what was built]
Navigation:       [Expo Router / React Navigation]
Deep Linking:     [URL scheme and routes]
Storage:          [MMKV / WatermelonDB / SecureStore]
Animations:       [reanimated patterns]
Performance:      [FlatList optimization, native driver]
Responsive:       [layout adaptation]
Testing:          [unit + E2E coverage]
```

## Done Criteria

- Screens handle loading, error, empty, success states
- Type-safe navigation with deep linking
- Lists use FlatList with `getItemLayout`, memoized render items
- Animations use reanimated on UI thread
- Sensitive data in SecureStore, preferences in MMKV
- Push notifications work in foreground, background, killed states
- Layout works on phone (320-428px), tablet (768px+), both orientations
- OTA updates check on foreground with graceful fallback
- Component tests + E2E tests for critical flows
