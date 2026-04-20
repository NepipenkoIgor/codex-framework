---
name: mobile-debug
description: Diagnose and fix mobile app bugs — crashes, layout issues, navigation failures, and platform-specific regressions
metadata:
  version: 1.6
  argument-hint: "bug description, platform (iOS/Android/both), framework (RN/Flutter), reproduction steps"
---

Debug $ARGUMENTS.

## Tool Integration

- **ast-grep** — use for structural code pattern search (find function signatures, hook usages, import patterns) — faster and more accurate than Grep for code structure
- **browser automation** — capture screenshots for visual verification and regression testing

## Debugging Priorities

1. Crash / app won't start (highest impact)
2. Build failures (Xcode, Gradle, Metro, Flutter build)
3. Native module / platform channel errors
4. Performance issues (frame drops, jank, memory leaks)
5. UI bugs (layout, navigation, gestures)
6. State and data bugs
7. Device-specific and simulator vs real device differences

## React Native Debugging

### Metro Bundler Issues

- **"Unable to resolve module"**: check node_modules exists, clear cache: `npx expo start --clear` or `npx react-native start --reset-cache`
- **"Watchman crawl failed"**: `watchman watch-del-all && watchman watch-project .`
- **Infinite build loop**: check for circular imports, file save triggers in IDE
- **Port conflict**: kill existing Metro process, or start on different port: `--port 8082`

### Bridge / JSI Errors

- **"Calling synchronously on a non-JSI module"**: module not compatible with new architecture, check for JSI variant
- **"Exception in HostFunction"**: native module throwing in JSI call -- check native stack trace
- **"Cannot read property of undefined" on native module**: module not linked, run `npx expo prebuild` or `pod install`
- **TurboModule registration failures**: check module spec matches native implementation

### Hermes vs JSC

| Issue | Hermes | JSC |
|-------|--------|-----|
| Bytecode errors | Pre-compiled -- "Invalid bytecode" means build mismatch | N/A |
| Debugging | React Native DevTools (press `shift+m` in Metro → Open React Native DevTools) | Safari Web Inspector |
| Proxy support | Full | Full |
| Date handling | Intl built-in (Hermes) | May need polyfill |
| `eval()` | Not supported by default | Supported |
| Stack traces | Symbolicated via source maps | Inline source maps |

- Check Hermes version matches React Native version
- Hermes bytecode errors: clean build (`cd android && ./gradlew clean`)
- Missing Intl on Hermes < 0.12: add `intl` polyfill

### React Native DevTools

React Native DevTools replaces Flipper as the default debugger in RN 0.73+/Expo SDK 52+. Flipper is deprecated and no longer maintained for React Native.

- Open React Native DevTools: press `j` in Metro (RN 0.73 only) or `shift+m` → "Open React Native DevTools"
- Component inspector: component tree, props, state, hooks (replaces Flipper React DevTools plugin)
- Network inspector: check API requests/responses (enable via DevTools settings)
- Console, breakpoints, step-through: full Chrome DevTools protocol
- For legacy projects still on Flipper: `adb reverse tcp:8081 tcp:8081` if Flipper won't connect; consider migrating to React Native DevTools

### LogBox / Red Screen / Yellow Box

| Indicator | Meaning | Action |
|-----------|---------|--------|
| Red screen | Fatal error -- app crashed | Check error message and stack trace |
| Yellow box | Warning -- non-fatal | Often indicates deprecation or perf issue |
| LogBox | Grouped warnings | Filter noise, address real issues |

- Dismiss noise: `LogBox.ignoreLogs(['Warning: ...'])` only for known non-issues
- Red screen in production: check Sentry/Crashlytics for the crash report
- "Invariant Violation": usually a React rendering error -- check component tree

### Native Module Crashes (React Native)

iOS:
- Check Xcode console (Cmd+Shift+C) for native stack trace
- `EXC_BAD_ACCESS`: accessing deallocated memory -- check native module lifecycle
- Missing pod: `cd ios && pod install --repo-update`
- Linking issue: check `Podfile` includes the module, `pod deintegrate && pod install`

Android:
- Check Logcat: `adb logcat *:E` for errors
- `java.lang.UnsatisfiedLinkError`: native library not loaded -- clean build
- `ClassNotFoundException`: ProGuard stripping -- add keep rules
- Gradle sync failure: check `build.gradle` versions, `./gradlew --stacktrace`

### React Native Performance Debugging

- **Frame drops**: use Performance Monitor (shake menu > Perf Monitor), check JS and UI FPS
- **JS thread bottleneck**: heavy computation in JS -- move to native or use `InteractionManager`
- **Bridge/JSI traffic**: use React Native DevTools Network inspector or Systrace to check bridge/JSI calls
- **Large re-render**: React Native DevTools Components panel -- find components rendering unnecessarily
- **Memory leak**: Xcode Instruments (Allocations) or Android Profiler (Memory) -- look for growing heap

## Flutter Debugging

### Widget Inspector and DevTools

- Open DevTools: `dart devtools` or via IDE (VS Code Flutter panel)
- Widget Inspector: visual tree, layout constraints, render objects
- Performance overlay: `WidgetsApp.showPerformanceOverlay = true`
- Network profiler: track HTTP requests and responses
- Memory profiler: heap snapshots, allocation tracking

### Common Flutter Errors

**Layout Overflow**:
- "A RenderFlex overflowed by N pixels": widget exceeds parent bounds
- Fix: wrap in `Expanded`, `Flexible`, `SingleChildScrollView`, or constrain with `ConstrainedBox`
- Check `Column`/`Row` children -- unbounded children in scrollable parents

**setState in Disposed Widget**:
- "setState() called after dispose()": async callback fires after widget unmounted
- Fix: check `mounted` before setState, or cancel async operation in `dispose()`
- Better: use Riverpod/Bloc -- state lives outside widget lifecycle

**Platform Channel Failures**:
- "MissingPluginException": plugin not registered -- `flutter clean && flutter pub get`
- "PlatformException": native code threw -- check native logs (Xcode/Logcat)
- Type mismatch: Dart `int` vs native `Integer` -- check argument types match

**Hot Reload Issues**:
- State not updating: hot reload preserves state -- use Hot Restart (`Shift+R`) to reset
- "Reload rejected": syntax error or breaking change -- check console for error
- Widgets not rebuilding: check `const` constructors are correct, state mutation triggers `notifyListeners()`

**Dart Analyzer Errors**:
- Strict null safety violations: check nullable types, add null checks or `!` assertion
- Implicit cast failures: use explicit casts or type-safe patterns
- Deprecated API usage: check migration guide for the package version

### Flutter Performance Debugging

- **Jank (frame drops)**: enable Performance Overlay, check for red bars in UI thread
- **Expensive build**: use `const` constructors, `RepaintBoundary`, avoid rebuilding subtrees
- **Shader compilation jank**: `--cache-sksl` applies only to Skia rendering. Impeller (default on iOS since Flutter 3.10, Android API 29+ since Flutter 3.27) precompiles shaders at build time -- no runtime shader jank. For Impeller perf analysis, use `flutter run --profile` and inspect the Raster thread in Flutter DevTools Performance tab.
- **Image decoding jank**: use `precacheImage()`, resize images before display
- **isolate for heavy computation**: move parsing, sorting, or image processing to `Isolate.run()`

### Flutter Memory Leak Detection

- Use DevTools Memory tab: take snapshots before/after action
- Check for: streams not closed, controllers not disposed, listeners not removed
- Common leaks: `StreamSubscription` without cancel, `AnimationController` without dispose
- Use `debugDumpApp()` to print widget tree for unmounted widget detection

## Build Failures (Both Platforms)

### Xcode Build Failures

| Error | Cause | Fix |
|-------|-------|-----|
| "No such module" | Pod not installed or outdated | `cd ios && pod install --repo-update` |
| "Signing requires a development team" | Code signing not configured | Set team in Xcode > Signing & Capabilities |
| "Could not find module for target" | Swift module cache stale | Clean build: Cmd+Shift+K, clean derived data |
| "Undefined symbols" | Linking error, missing library | Check Build Phases > Link Binary With Libraries |
| "The sandbox is not in sync" | Podfile.lock mismatch | `pod deintegrate && pod install` |
| Minimum deployment target | iOS version too low for a dependency | Raise `IPHONEOS_DEPLOYMENT_TARGET` in Podfile |

### Gradle Build Failures

| Error | Cause | Fix |
|-------|-------|-----|
| "Could not resolve dependency" | Version conflict or missing repo | Check `repositories {}`, run `./gradlew --refresh-dependencies` |
| "Execution failed for task :app:merge*" | Duplicate resources or manifest conflicts | Check for duplicate entries, use `tools:replace` |
| "SDK location not found" | ANDROID_HOME not set | Set in `local.properties` or environment |
| "Unsupported class file major version" | JDK version mismatch | Set `JAVA_HOME` to JDK 17, check `gradle.properties` |
| "OutOfMemoryError" | Gradle heap too small | Set `org.gradle.jvmargs=-Xmx4096m` in `gradle.properties` |
| R8/ProGuard errors | Missing keep rules | Add rules for problematic classes |

### Code Signing Issues

iOS:
- "Provisioning profile doesn't match": re-select profile in Xcode, check bundle ID
- "Certificate not trusted": install Apple WWDR intermediate certificate
- Distribution build fails: use Archive (not Build), check correct provisioning profile type
- "Automatic signing is unable to resolve": check Apple Developer account has required certificates

Android:
- "Keystore not found": check `key.properties` path, `signingConfigs` in `build.gradle`
- "Key with alias not found": verify alias name in keystore
- Upload key vs signing key: use Play App Signing -- upload with upload key, Google signs for distribution

### Dependency Conflicts

CocoaPods (iOS):
- Version conflict: specify version in Podfile, use `pod update <name>`
- "CDN: trunk URL couldn't be downloaded": `pod repo update`
- Pre-built binary incompatible: `pod deintegrate && pod install`
- Flipper conflicts: disable Flipper if causing build issues

Gradle (Android):
- Version resolution: use `resolutionStrategy { force('lib:version') }` in `build.gradle`
- Duplicate class: exclude transitive dependency with `exclude group: 'com.example'`
- AndroidX migration: ensure all dependencies use AndroidX, run `jetifier`

Flutter pub (Dart):
- Version solving failed: check `pubspec.yaml` constraints, run `flutter pub outdated`
- Dependency override: use `dependency_overrides:` in `pubspec.yaml` (temporary only)

## Device-Specific Debugging

### Simulator vs Real Device

| Behavior | Simulator | Real Device |
|----------|-----------|-------------|
| Performance | Faster (host CPU) | Actual performance |
| Push notifications | Not supported (iOS sim) | Full support |
| Camera/sensors | Simulated or unavailable | Real hardware |
| Network | Uses host network | WiFi/cellular |
| Biometrics | Simulated (Face ID menu) | Real biometric hardware |
| App Store flow | Not testable | Full flow via TestFlight/Internal Testing |

- Always test performance on real device -- simulators are not representative
- Test on minimum supported OS version device
- Test on both small (iPhone SE) and large (iPhone 15 Pro Max) screens

### Crash Log Analysis

Crashlytics (Firebase):
- Check non-fatal errors and ANRs alongside crashes
- Use breadcrumbs to trace user actions before crash
- Filter by OS version, device model, app version
- Check crash-free users percentage per release

Sentry:
- Stack traces with source maps (RN) or debug symbols (Flutter)
- Session replay for context
- Release health tracking

Native crash logs:
- iOS: Xcode Organizer > Crashes, `.ips` files, symbolicating with dSYM
- Android: `adb logcat | grep -i 'fatal\|crash\|exception'`, tombstone files
- Strip frames from platform/runtime to find app code in stack trace

## Debugging Workflow

1. Classify the bug: JS/Dart layer, native layer, build system, or platform-specific
2. Reproduce on simulator and device -- note differences
3. Check error logs: Metro console, Xcode console, Logcat, DevTools console
4. For crashes: check Crashlytics/Sentry for stack trace and breadcrumbs
5. For build failures: read the full error message, check dependency versions
6. For performance: profile with platform tools, identify bottleneck thread
7. Apply the smallest safe fix targeting the root cause
8. Test on both platforms after fix
9. Add error handling or test to prevent recurrence

## Output Format

```
Bug Type:         [crash / build failure / performance / UI / state / platform-specific]
Platform:         [iOS / Android / both]
Framework:        [React Native / Flutter]
Root Cause:       [clear explanation]
Fix:              [minimal safe fix]
Verification:     [how to confirm the fix works]
Prevention:       [test or guard to prevent recurrence]
```

## Anti-Patterns

- Testing only on simulator -- touch latency, native permissions, and GPU differ from real devices
- Not checking native logs when JS/Dart stack trace is unhelpful -- crash originates in native layer
- Force-cleaning without understanding the build error -- masks the root cause and breaks reproducibility
- Downgrading dependencies blindly to fix build failures -- introduces regressions without diagnosing the actual conflict
