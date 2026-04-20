---
name: frontend-implement-vue
description: Vue 3.5 + Nuxt 3 Composition API — script setup, Pinia, composables, SSR-safe patterns
metadata:
  version: 1.0
  domain: frontend
  keywords: [vue, vuejs, nuxt, nuxt3, pinia, composition api, script setup, composables, useTemplateRef, useFetch, useAsyncData, storeToRefs]
---

# Frontend Implement — Vue

Pair with `frontend-implement` for universal rules.

## Component Syntax

- Always `<script setup lang="ts">` — never Options API, never `<script>` without `setup`
- Always TypeScript — never plain JS `.vue` files
- Props: always type-only syntax `defineProps<{ name: string }>()` with `withDefaults()` for defaults
- Emits: always typed `defineEmits<{ change: [value: string] }>()`
- Expose: `defineExpose()` minimal surface only — only what parent genuinely needs

## Reactivity

- `ref()` for primitives and single values, `reactive()` for grouped related state objects
- Never destructure `reactive()` directly — reactivity is lost; use `toRefs()` if destructuring needed
- Vue 3.5: use `useTemplateRef()` for template refs — never `ref<HTMLElement | null>(null)` with matching ref attribute
- Vue 3.5: reactive props destructuring is safe in `<script setup>` — `const { count = 0 } = defineProps<...>()`
- Use `useId()` for generating unique IDs needed for a11y label associations

## Composables

- Name always `useX` — never plain function names for composables
- Always return `ref`s or `reactive` objects — never raw values (caller loses reactivity)
- SSR safety: never access `window`, `document`, `localStorage` at composable root — guard with `onMounted` or `import.meta.client`
- Side effects in composables must clean up in `onUnmounted`

## Pinia

- Always setup syntax: `defineStore('id', () => { ... })` — never options syntax `defineStore('id', { state, getters, actions })`
- Always `storeToRefs()` when destructuring store state or getters — never direct destructuring
- Actions are plain functions in setup store — no special syntax needed
- Never access store outside of setup or a composable (no store usage in plain functions)

## Nuxt 3 Data Fetching

- `useFetch(url)` for straightforward URL-based fetching — auto-deduplicates, SSR-safe
- `useAsyncData(key, () => ...)` for complex/conditional fetching or non-URL sources
- Use `lazy: true` for non-critical below-fold data, `server: false` for client-only data
- Always provide a unique string key to `useAsyncData` — never omit it

## Nuxt 3 Utilities

- `useRuntimeConfig()` for accessing env config — never `process.env` in components or composables
- `useState(key, () => defaultValue)` for SSR-safe shared state across components
- `useCookie(name)` for cookie-backed reactive state — never `document.cookie` directly
- `useRoute()` / `useRouter()` — never import `vue-router` directly in Nuxt

## Hard Rules

- Never Options API — Composition API always
- Never `<script>` without `setup`
- Never destructure `reactive()` without `toRefs()`
- Never destructure Pinia store without `storeToRefs()`
- Never `process.env` in Vue/Nuxt components — use `useRuntimeConfig()`
- Never `window`/`document` at module root — always inside `onMounted` or `import.meta.client` guard

## Done Criteria

- No Options API in any component
- No `<script>` without `setup`
- No raw store destructuring without `storeToRefs()`
- All composables SSR-safe (no bare `window`/`document`)
- No `process.env` references in component or composable files
- LSP reports zero errors
