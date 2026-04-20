---
name: mobile-review
description: Review mobile code for architecture, performance, security, accessibility, and platform-specific issues
metadata:
  version: 2.4
  argument-hint: "PR URL or file paths, platform (iOS/Android/both), review focus (performance/UX/security)"
---

Review $ARGUMENTS.


Severity: CRITICAL (security/data/outage) > HIGH (perf/reliability) > MEDIUM (maintainability) > LOW (style).

## React Native Review Dimensions

### Component Architecture

- Oversized screens mixing UI, state, navigation, and API calls
- Missing separation: screen (layout) vs component (reusable) vs hook (logic)
- Inline component definitions inside render (causes remount on every render)
- Missing `React.memo` on FlatList render items
- Props drilling through 3+ layers without context or composition
- Missing error boundaries -- single component crash takes down entire app
- Side effects in render path (API calls, storage access)

### Hook Patterns

- Missing cleanup in useEffect (subscriptions, timers, listeners)
- Stale closures from missing dependencies in useEffect
- Business logic in useEffect instead of event handlers
- Excessive useState when useReducer would be cleaner
- Custom hooks not extracting reusable logic from screens
- Missing loading/error/empty state handling in data hooks

### Navigation Structure

- Deeply nested navigators (>3 levels) -- hard to deep link and maintain
- Missing TypeScript param list types for navigators
- Unhandled deep link routes (no catch-all/not-found screen)
- Navigation actions in render path (should be in event handlers)
- Missing auth guard redirect logic
- Screen not resetting state on focus/blur when it should

### Native Module Safety

- Native module calls without try-catch (can crash if module unavailable)
- Platform-specific code without `Platform.OS` check
- Direct Linking/NativeModules usage instead of Expo SDK equivalents
- Missing null checks on native module return values
- Config plugin not handling edge cases (existing Podfile entries, Gradle conflicts)
- Missing TurboModule spec (`NativeModule.ts`): New Architecture modules require a typed spec; check Fabric compatibility for custom UI components and flag interop layer overhead when mixing old and new modules

### Bundle Size

- Full library imports instead of tree-shaken: `import _ from 'lodash'` vs `import map from 'lodash/map'`
- Large assets bundled directly instead of downloaded on demand
- Unused dependencies in package.json
- Multiple libraries for same purpose (two HTTP clients, two state managers)
- Development-only code in production bundle (debug logging)
- Missing Hermes -- significantly larger bundle without it

### New Architecture Compliance

- JSI/TurboModule conformance: check that native modules expose a typed spec (`NativeModule.ts`) and are registered via the new module system
- Fabric renderer compatibility: custom UI components must implement the Fabric component spec; legacy components using the old bridge renderer will not work in New Architecture without an interop layer
- Interop layer overhead: mixing New Architecture modules with legacy bridge modules through the interop layer adds latency and should be minimized -- flag any non-migrated modules for upgrade
- Animation running on JS thread instead of native (Reanimated/native driver)

## Flutter Review Dimensions

### Widget Composition

- Deeply nested widget trees (>10 levels without extraction)
- Stateful widgets where stateless + provider would suffice
- Missing `const` constructors on stateless widgets (prevents rebuild optimization)
- `build()` method doing computation instead of delegating to providers/services
- Widget splitting too aggressive (single Text widget in its own file) or not enough (500-line build)

### State Management Patterns

- Direct setState with complex state (should use Riverpod/Bloc)
- Provider without proper scoping (global state for screen-local data)
- Riverpod providers watching too many dependencies (causes excessive rebuilds)
- Bloc events without clear naming (generic "LoadData" vs specific "FetchUserProjects")
- Missing `AsyncValue.when()` handling (no loading/error states)
- State not disposed when navigating away
- Provider in new Flutter code (post-2023) is legacy -- recommend Riverpod migration for maintainability and better performance

### Platform Channel Contracts

- Missing error handling on method channel calls
- Type mismatches between Dart and native code
- No timeout on platform channel calls (can hang indefinitely)
- Missing platform check before calling platform-specific channel
- Large data passed through channel without streaming

### BuildContext Usage

- Using BuildContext after async gap (widget may be unmounted)
- Accessing inherited widgets in initState (not yet available)
- Passing BuildContext across isolates (not possible)
- Using context in callbacks without mounted check

### Key Management

- Missing keys on list items (causes incorrect state preservation)
- Using index as key when list can be reordered
- GlobalKey overuse (expensive, usually avoidable)
- ValueKey with non-unique values

## Both Platforms -- Performance

### List Virtualization

- ScrollView/Column with many children instead of FlatList/ListView.builder
- FlatList without `getItemLayout` when item heights are fixed
- Missing `keyExtractor` (RN) or unique keys (Flutter) on list items
- No pagination for large datasets -- loading all items in memory
- Missing `removeClippedSubviews` (RN) for off-screen optimization
- `ListView` with all children pre-built instead of `ListView.builder` (Flutter)

### Image Handling

- No image caching library (default Image fetches every time)
- Missing width/height on network images (causes layout shift)
- Full-resolution images loaded for thumbnails
- Base64 images in state/props (memory explosion)
- No placeholder/skeleton while images load
- Missing `cacheWidth`/`cacheHeight` on Flutter Image (decodes at display size)

### Lazy Loading

- All screens/features loaded at app start
- Heavy initialization in main/root widget (should defer)
- No code splitting or deferred imports for feature modules
- Prefetching data for screens the user may never visit

### Memory Leaks

- Event listeners not removed on unmount/dispose
- Timers/intervals not cleared on cleanup
- Subscriptions (RxDart, streams, observables) not cancelled
- AnimationController not disposed (Flutter)
- Global state holding references to unmounted widget data
- Large closures capturing entire component scope

## Both Platforms -- Security

### Secure Storage

- Auth tokens in AsyncStorage/shared_preferences (not encrypted)
- Sensitive data in MMKV/Hive without encryption
- API keys hardcoded in source code
- Credentials logged to console
- User data not cleared on logout

### Certificate Pinning

- No certificate pinning for sensitive API endpoints
- Pinning to leaf certificate (breaks on renewal) instead of public key or intermediate CA
- Missing fallback when pinned certificate rotates
- Pinning disabled in debug builds but no protection in release

### Root/Jailbreak Detection

- No detection for rooted/jailbroken devices when handling sensitive data (banking, healthcare)
- Detection only at launch (can be bypassed with runtime hook)
- Hard block instead of graceful degradation (some users have rooted devices for legitimate reasons)
- Detection logic easily bypassed (simple file check instead of multiple signals)

### Data at Rest

- SQLite databases without encryption for sensitive data
- File system storage without app sandbox verification
- Backup inclusion of sensitive data (Android `allowBackup: true`)
- Clipboard data not cleared after paste (sensitive fields)

## Both Platforms -- Accessibility

### VoiceOver / TalkBack

- Interactive elements without accessibility labels
- Images without `accessibilityLabel` (RN) or `Semantics` (Flutter)
- Custom gestures with no accessible alternative (swipe-only actions need button fallback)
- Decorative images not hidden from screen reader (`accessibilityElementsHidden` / `excludeSemantics`)
- Incorrect traversal order (screen reader reads elements in wrong sequence)
- Missing `accessibilityRole` (RN) or `Semantics` role (Flutter)

### Semantic Labels

- Generic labels: "button" instead of "Add to cart button"
- Missing state announcements: "selected", "expanded", "loading"
- Dynamic content not announced (`accessibilityLiveRegion` / `liveRegion`)
- Form fields without associated labels
- Error messages not announced to screen reader

### Touch Targets

- Interactive elements smaller than 44x44pt (Apple) / 48x48dp (Android)
- Touch targets overlapping (wrong element receives tap)
- No visible focus indicator for keyboard/switch control navigation
- Insufficient spacing between adjacent touch targets

## Both Platforms -- Responsive Design

### Phone / Tablet / Foldable

- Fixed widths that break on tablets or foldables
- No tablet layout (same phone layout stretched to 11")
- Missing split view / master-detail for tablets
- Grid not adapting column count to screen width
- Font sizes not scaling with system accessibility settings
- Landscape orientation not handled (content cut off or unusable)

### Safe Areas

- Content behind status bar, notch, or home indicator
- Fixed bottom bar not accounting for home indicator
- Keyboard avoidance not implemented (inputs hidden behind keyboard)
- System UI overlap on Android (navigation bar, status bar)

## Both Platforms -- Offline Handling

- No offline state detection or indicator
- Cached data not used when offline (blank screen)
- Failed requests not queued for retry when connection returns
- Stale data displayed without freshness indicator
- No conflict resolution for data edited offline then synced
- Missing optimistic UI with rollback on sync failure

## Review Workflow

1. Identify the framework (React Native / Flutter) and project conventions
2. Scan for critical issues first: crashes, security, data loss
3. Check component/widget architecture and state management
4. Review navigation structure and deep linking
5. Check list performance and memory patterns
6. Review accessibility (VoiceOver/TalkBack, labels, touch targets)
7. Check security: storage, pinning, detection, data at rest
8. Review responsive behavior: phone, tablet, orientation, safe areas
9. Check offline handling and error states
10. Note platform-specific issues (iOS vs Android differences)
11. Compile findings in structured format

## Output

Group findings by severity (highest first). Each: severity, file:line, issue, fix with code example. Note platform-specific implications (iOS vs Android).

## Tool Integration

- **ast-grep**: use for structural code pattern search (find function signatures, class usages, import patterns) — faster and more accurate than Grep for code structure
