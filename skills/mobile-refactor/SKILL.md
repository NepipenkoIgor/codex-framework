---
name: mobile-refactor
description: Refactor existing React Native and Expo mobile code for maintainability, performance, and modern patterns — hook extraction, New Architecture adoption, navigation migration, state management cleanup
metadata:
  version: 1.3
  argument-hint: "target screen/component, refactor goal, framework (RN/Flutter), performance/pattern focus"
---

Refactor $ARGUMENTS.


## Tool Integration

- **ast-grep** — use for structural code pattern search (find function signatures, hook usages, import patterns) — faster and more accurate than Grep for code structure
- **docs lookup tools** — check latest React Native, Expo, and library docs before refactoring
- **Type diagnostics** — verify type-safety after refactoring

## Documentation

> Use **available docs lookup tools or official docs** for current React Native, Expo, and mobile framework docs before refactoring — patterns and best practices evolve rapidly.

Platforms in scope:
- React Native (bare + Expo managed/dev-client)
- Expo SDK (latest patterns)

## Core Principles

- Preserve existing behavior unless explicitly asked to change
- Prefer safe, incremental refactoring over large rewrites
- Follow existing project conventions unless clearly harmful
- Reduce duplication, complexity, and platform-specific branching
- Keep components focused — separate UI, state, navigation, and data concerns

## Refactoring Patterns

### Component Modernization

Class → functional:
- Extract state to `useState`/`useReducer`
- Extract lifecycle to `useEffect` with proper deps
- Extract methods to custom hooks where reusable
- Convert HOCs to hooks (`withNavigation` → `useNavigation`)
- Replace `React.createRef` with `useRef`

Anti-patterns to fix:
- Inline styles → StyleSheet.create or styled-components/NativeWind
- Anonymous functions in render (re-renders) → `useCallback`
- Large components (>200 lines) → extract sub-components + hooks
- Direct `AsyncStorage` calls in components → data layer/hook abstraction
- Hardcoded dimensions → `useWindowDimensions` / responsive utilities

### Hook Extraction

Extract reusable logic into custom hooks:
- API calls → `useQuery`/`useMutation` (TanStack Query) or custom `useFetch`
- Form state → `useForm` (React Hook Form)
- Permissions → `usePermissions` wrapping expo-permissions
- Location/camera/sensors → dedicated hooks with cleanup
- Deep linking → `useLinking` patterns
- App state (foreground/background) → `useAppState`

### Navigation Migration

React Navigation upgrades:
- v5 → v6: `screenOptions` prop, typed `useNavigation<StackNavigationProp<ParamList>>()`
- Typed navigation: define `RootStackParamList`, use `NativeStackScreenProps`
- Deep linking config: extract to `linking` config object
- Tab/drawer nesting: flatten where possible
- Screen options: move from component to navigator definition

### State Management Cleanup

- Prop drilling (>3 levels) → context or state library
- Redux boilerplate → Redux Toolkit slices, or migrate to Zustand/Jotai
- Untyped stores → full TypeScript with selector types
- Mixed state approaches → consolidate to one pattern
- Server state in global store → extract to TanStack Query

### Performance Refactoring

- FlatList: extract `renderItem`, add `keyExtractor`, use `getItemLayout` for fixed heights
- `React.memo` on expensive list items with proper comparison
- Image loading → `expo-image` (replaces RN Image, FastImage)
- Heavy computation → `useMemo` with correct deps
- Animated API → `react-native-reanimated` worklets (runs on UI thread)
- InteractionManager for post-animation work
- Hermes: ensure enabled, remove `intl` polyfills if Hermes handles them

### Expo SDK Migration

- `expo-constants` → `expo-device` + `expo-application` where appropriate
- `expo-app-loading` (deprecated) → `expo-splash-screen`
- Bare workflow → Expo Dev Client (CNG)
- `expo-file-system` for file operations (replaces rn-fetch-blob)
- EAS Build migration from classic build

### New Architecture Adoption

- Enable Fabric renderer: update `react-native.config.js`
- TurboModules: migrate native modules to new spec
- Bridgeless mode: remove bridge dependencies
- Codegen: add typed native component specs
- Test: verify all third-party libs support New Architecture

### Platform-Specific Code

- `Platform.select` / `.ios.tsx` / `.android.tsx` — consolidate where platforms diverged unnecessarily
- Extract platform differences to a single adapter layer
- Replace platform checks scattered in UI with platform-aware components

## Process

1. **Audit** — read the target code, identify refactoring opportunities, list them
2. **Plan** — prioritize by impact (performance > maintainability > style), present to user
3. **Execute** — refactor incrementally, verify types compile after each change
4. **Verify** — run tests, check for regressions, run on both platforms if applicable

## Anti-Patterns to Avoid During Refactoring

- Don't extract hooks that are only used once (premature abstraction)
- Don't migrate state management without user approval (breaking change)
- Don't upgrade React Navigation major versions without migration plan
- Don't enable New Architecture if third-party native modules don't support it yet
- Don't remove `Platform.OS` checks without verifying behavior is identical

## Done Criteria

- [ ] Types compile without errors
- [ ] No `any` types introduced
- [ ] Existing tests pass (or updated for new structure)
- [ ] No runtime behavior changes (unless explicitly requested)
- [ ] StyleSheet over inline styles
- [ ] Hooks extracted for reusable logic
- [ ] Performance: no new unnecessary re-renders
