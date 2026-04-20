---
name: mobile-implement-reactnative
description: React Native / Expo implementation patterns — Expo Router, MMKV, Reanimated, gesture handler, EAS Update, push notifications, offline storage, performance. Pair with mobile-implement for universal rules.
metadata:
  version: 1.0
  domain: mobile
  keywords: [react native, expo, rn, expo router, react navigation, mmkv, watermelondb, reanimated, gesture handler, eas update, eas build, expo-notifications, flashlist, hermes, zustand mobile, tanstack query mobile]
---

# React Native / Expo Implementation

Pair with `mobile-implement` for universal rules (touch targets, safe areas, offline concepts, security principles).

## Expo vs Bare

- Start with Expo managed unless you need a native module not available as a config plugin
- Use `npx expo prebuild` (continuous native generation) rather than full ejection
- Prefer Expo SDK modules over community alternatives when functionality matches
- SDK 52+ requires New Architecture — verify all deps are compatible before upgrading

## Navigation

### Expo Router (File-Based) — Preferred for New Projects

```
app/
  _layout.tsx           # root layout (providers, auth guard)
  (tabs)/_layout.tsx    # tab navigator
  (tabs)/index.tsx      # home tab
  (tabs)/profile.tsx    # profile tab
  (auth)/login.tsx      # auth stack
  (auth)/register.tsx
  project/[id].tsx      # dynamic route
  modal.tsx             # modal (presented over tabs)
  +not-found.tsx
```

```tsx
// app/_layout.tsx — auth guard at root
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

Navigate: `router.push('/project/123')`, `router.replace('/(auth)/login')`, `router.dismiss()`.
Params: `useLocalSearchParams<{ id: string }>()` — always typed.

> Expo Router v4: `router.navigate()` always pushes. Use `router.dismiss()` to go back, `router.dismissAll()` to return to first screen.

### React Navigation (Imperative)

Type-safe `ParamList` for every navigator. `createNativeStackNavigator` + `createBottomTabNavigator`. Configure `LinkingOptions` for deep linking. Max 3 navigator nesting levels.

## State Management

- **Zustand** (preferred): minimal boilerplate, MMKV persistence via `StateStorage` interface
- **TanStack Query**: server state, caching, background refetch — never store server data in Zustand
- **Redux Toolkit**: only for existing codebases — don't introduce for new projects

```tsx
import { MMKV } from 'react-native-mmkv';
import { StateStorage } from 'zustand/middleware';

const storage = new MMKV();
export const mmkvStorage: StateStorage = {
  getItem: (name) => storage.getString(name) ?? null,
  setItem: (name, value) => storage.set(name, value),
  removeItem: (name) => storage.delete(name),
};

export const useSettingsStore = create(
  persist<SettingsState>(
    (set) => ({ theme: 'light', setTheme: (theme) => set({ theme }) }),
    { name: 'settings', storage: createJSONStorage(() => mmkvStorage) },
  ),
);
```

## Storage

| Store | Use case | Notes |
|---|---|---|
| MMKV | Preferences, small state, Zustand persistence | Sync, ~30× faster than AsyncStorage |
| WatermelonDB | Relational data, offline-first with sync | Reactive queries, background sync |
| expo-sqlite | Direct SQL, migrations | Full SQL, async |
| expo-secure-store | Auth tokens, credentials | Encrypted, 2KB limit, Keychain/EncryptedSharedPrefs |

Rules:
- MMKV over AsyncStorage — always. AsyncStorage is deprecated behavior.
- Never store tokens in MMKV — use `expo-secure-store`
- Clear all storage (including secure store) on logout
- For >2KB secrets: store encryption key in SecureStore, encrypted payload in MMKV

```tsx
import * as SecureStore from 'expo-secure-store';

export const secureTokens = {
  async save(access: string, refresh: string) {
    await Promise.all([
      SecureStore.setItemAsync('access_token', access),
      SecureStore.setItemAsync('refresh_token', refresh),
    ]);
  },
  async getAccess() {
    try { return await SecureStore.getItemAsync('access_token'); }
    catch { return null; } // handle locked device / backup restore
  },
  async clear() {
    await Promise.all([
      SecureStore.deleteItemAsync('access_token'),
      SecureStore.deleteItemAsync('refresh_token'),
    ]);
  },
};
```

## Animations & Gestures

All animations MUST run on the UI thread via `react-native-reanimated`:

```tsx
import Animated, { useSharedValue, useAnimatedStyle, withSpring, withTiming, runOnJS } from 'react-native-reanimated';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';

function SwipeableCard({ onDismiss }: { onDismiss: () => void }) {
  const translateX = useSharedValue(0);

  const pan = Gesture.Pan()
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
    <GestureDetector gesture={pan}>
      <Animated.View style={style}>{/* content */}</Animated.View>
    </GestureDetector>
  );
}
```

Rules:
- Never use `Animated` from core RN for interactive animations — JS thread jank
- `withSpring` for interactive/gesture-driven, `withTiming` for simple transitions
- `runOnJS()` to call JS functions from UI thread worklets
- Haptic feedback: `expo-haptics` on meaningful interactions (confirm, error, selection)

## Performance

**FlatList optimization:**
```tsx
<FlatList
  data={data}
  renderItem={useCallback(({ item }) => <MemoizedItem item={item} />, [])}
  keyExtractor={useCallback((item) => item.id, [])}
  getItemLayout={(_, index) => ({ length: ITEM_HEIGHT, offset: ITEM_HEIGHT * index, index })}
  maxToRenderPerBatch={10}
  windowSize={5}
  removeClippedSubviews
/>
```

- Use `FlashList` for 1000+ items (recycled views, ~10× faster than FlatList)
- `React.memo` on all list item components
- `getItemLayout` whenever item height is fixed — enables fast scroll
- Never create inline objects/functions in render: `style={{ flex: 1 }}` → `StyleSheet.create`
- Hermes is default in SDK 49+ — avoid `eval()`, `with` statements, legacy Intl APIs

## OTA Updates (EAS Update)

```tsx
function useOTAUpdates() {
  useEffect(() => {
    const sub = AppState.addEventListener('change', async (state) => {
      if (state !== 'active' || __DEV__) return;
      try {
        const update = await Updates.checkForUpdateAsync();
        if (!update.isAvailable) return;
        await Updates.fetchUpdateAsync();
        if (update.manifest?.extra?.critical) {
          await Updates.reloadAsync();
        } else {
          showUpdateBanner(() => Updates.reloadAsync());
        }
      } catch { /* silent — keep current version */ }
    });
    return () => sub.remove();
  }, []);
}
```

Rules:
- Check on foreground, not just launch
- Never force-reload without user consent for non-critical updates
- Use `runtimeVersion: { policy: 'fingerprint' }` to prevent incompatible JS pushes
- Channels: `staging` for QA, `production` for store builds

## Push Notifications

```tsx
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true, shouldPlaySound: true, shouldSetBadge: true,
  }),
});

async function registerForPush(): Promise<string | null> {
  if (!Device.isDevice) return null; // simulators don't support push
  const { status } = await Notifications.requestPermissionsAsync();
  if (status !== 'granted') return null;
  const token = (await Notifications.getExpoPushTokenAsync({ projectId: 'YOUR_PROJECT_ID' })).data;
  await api.post('/push-tokens', { token, platform: Platform.OS });
  return token;
}

// Navigate on notification tap
Notifications.addNotificationResponseReceivedListener((response) => {
  const route = response.notification.request.content.data?.route;
  if (route) router.push(route);
});
```

> Push notifications removed from Expo Go in SDK 53. Use a development build for testing.

## Audio / Video

- `expo-av` deprecated in SDK 52 — use `expo-video` (video) and `expo-audio` (audio) for new projects

## Done Criteria

- Navigation type-safe with deep linking registered
- All lists: `FlatList` with `getItemLayout` + memoized items; `FlashList` for 1000+
- All animations: `react-native-reanimated` on UI thread — zero core `Animated` for interactions
- Auth tokens in `expo-secure-store` — never MMKV or AsyncStorage
- OTA update check on foreground with graceful fallback
- Push notifications: foreground, background, and killed states handled
- Layout handles phone (320–428px), tablet (768px+), both orientations
- Safe areas applied (notch, home indicator, status bar)
