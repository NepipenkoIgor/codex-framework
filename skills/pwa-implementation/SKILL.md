---
name: pwa-implementation
description: PWA features — service workers, caching strategies, manifest, install prompts, offline shell, background sync, push notifications with VAPID keys, and Workbox integration
metadata:
  version: 1.8
  argument-hint: "framework (Next.js/React/Vue), offline requirements, push notification needs, caching strategy"
---

Implement $ARGUMENTS.

## Tool Integration

- **browser automation** — capture screenshots for visual verification and regression testing

## Web App Manifest

```json
{
  "name": "My Application", "short_name": "MyApp",
  "start_url": "/", "display": "standalone",
  "background_color": "#ffffff", "theme_color": "#2563eb",
  "icons": [
    { "src": "/icons/icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any" },
    { "src": "/icons/icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any" },
    { "src": "/icons/icon-maskable-192.png", "sizes": "192x192", "type": "image/png", "purpose": "maskable" },
    { "src": "/icons/icon-maskable-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ]
}
```

Rules: `name` max 45 chars, `short_name` max 12 chars. Provide `any` + `maskable` at 192px and 512px. Maskable safe zone is center 80%. Include `shortcuts` + `screenshots` for richer install UI.

HTML: `<link rel="manifest">`, `<meta name="theme-color">`, `<meta name="apple-mobile-web-app-capable" content="yes">`, `<link rel="apple-touch-icon">`.

## Service Worker Lifecycle

```typescript
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => navigator.serviceWorker.register('/sw.js', { scope: '/' }));
}
```

```typescript
const CACHE_NAME = 'app-cache-v1';
const PRECACHE_URLS = ['/', '/offline.html', '/styles/main.css', '/scripts/main.js'];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((c) => c.addAll(PRECACHE_URLS)));
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});
```

Always call `skipWaiting()` + `clients.claim()`. Version cache names. Precache only critical assets.

## Caching Strategies

| Resource Type | Strategy | Cache Duration |
|---------------|----------|---------------|
| App shell HTML | Network-first, offline fallback | Until new SW |
| Hashed assets (*.abc123.js) | Cache-first | Indefinite |
| Unhashed static assets | Stale-while-revalidate | 24 hours |
| API data (lists) | Network-first, 3s timeout | 5-30 min |
| Images (CDN) | Cache-first | 30 days |
| Fonts | Cache-first | 1 year |

## Workbox Integration

```typescript
import { precacheAndRoute, cleanupOutdatedCaches } from 'workbox-precaching';
import { registerRoute, NavigationRoute, createHandlerBoundToURL } from 'workbox-routing';
import { NetworkFirst, CacheFirst, StaleWhileRevalidate } from 'workbox-strategies';
import { ExpirationPlugin } from 'workbox-expiration';

precacheAndRoute(self.__WB_MANIFEST);
cleanupOutdatedCaches();

registerRoute(new NavigationRoute(createHandlerBoundToURL('/index.html'), {
  denylist: [/^\/api\//, /^\/auth\//],
}));

registerRoute(
  ({ url }) => url.pathname.startsWith('/api/'),
  new NetworkFirst({ cacheName: 'api', networkTimeoutSeconds: 3,
    plugins: [new ExpirationPlugin({ maxEntries: 50, maxAgeSeconds: 300 })] })
);

registerRoute(
  ({ request }) => request.destination === 'image',
  new CacheFirst({ cacheName: 'images',
    plugins: [new ExpirationPlugin({ maxEntries: 100, maxAgeSeconds: 30 * 24 * 60 * 60 })] })
);
```

## Install Prompt

```typescript
let deferredPrompt: BeforeInstallPromptEvent | null = null;

window.addEventListener('beforeinstallprompt', (e) => {
  e.preventDefault(); deferredPrompt = e; showInstallButton();
});

async function handleInstallClick() {
  if (!deferredPrompt) return;
  deferredPrompt.prompt();
  await deferredPrompt.userChoice;
  deferredPrompt = null; hideInstallButton();
}
```

Never prompt on first visit — wait for engagement. Respect dismiss for 30 days. On iOS: show manual "Add to Home Screen" instructions.

## Offline Experience

- Precache the app shell; serve for all navigation requests (SPA)
- Show offline indicator banner (`role="alert"`, non-blocking)
- Disable network-dependent actions with clear messaging
- Queue offline actions for background sync; show cached data with "last updated" timestamp

```tsx
function useOnlineStatus() {
  // Note: navigator.onLine is unreliable (returns true for captive portals).
  // For production, supplement with a fetch probe to a known endpoint.
  const [isOnline, setIsOnline] = useState(navigator.onLine);
  useEffect(() => {
    const on = () => setIsOnline(true), off = () => setIsOnline(false);
    window.addEventListener('online', on); window.addEventListener('offline', off);
    return () => { window.removeEventListener('online', on); window.removeEventListener('offline', off); };
  }, []);
  return isOnline;
}
```

## Background Sync

```typescript
// In app: queue action and register sync
await db.add('actions', { type: 'create-task', payload, timestamp: Date.now() });
const reg = await navigator.serviceWorker.ready;
await reg.sync.register('sync-actions');

// In SW: process queue
self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-actions') event.waitUntil(processQueuedActions());
});
```

## Push Notifications

1. Generate VAPID keys: `npx web-push generate-vapid-keys`
2. Subscribe: `registration.pushManager.subscribe({ userVisibleNotification: true, applicationServerKey })`
3. Send subscription to server for storage
4. SW handles `push` event: `self.registration.showNotification(title, options)`
5. SW handles `notificationclick`: focus existing tab or open new window

Never request permission on first visit. Handle `pushsubscriptionchange` for token rotation.

## Update Flow

```typescript
registration.addEventListener('updatefound', () => {
  const newWorker = registration.installing;
  newWorker?.addEventListener('statechange', () => {
    if (newWorker.state === 'installed' && navigator.serviceWorker.controller)
      showUpdateNotification();
  });
});

// Apply on user action
function applyUpdate() {
  navigator.serviceWorker.getRegistration().then((r) => r?.waiting?.postMessage({ type: 'SKIP_WAITING' }));
}
navigator.serviceWorker.addEventListener('controllerchange', () => window.location.reload());

// In SW
self.addEventListener('message', (e) => { if (e.data?.type === 'SKIP_WAITING') self.skipWaiting(); });
```

Never force-reload without consent. Auto-check every 60 min. Clear stale caches in activate.

## Framework-Specific Setup

### Next.js PWA

Use `@ducanh2912/next-pwa` — the maintained fork (`next-pwa` is abandoned and App Router-incompatible). Consider `@serwist/next` as a more actively maintained alternative with better Workbox integration.

```typescript
// next.config.ts
import withPWAInit from '@ducanh2912/next-pwa';
const withPWA = withPWAInit({
  dest: 'public', disable: process.env.NODE_ENV === 'development',
  register: true, skipWaiting: true,
  runtimeCaching: [
    { urlPattern: /^https:\/\/api\./, handler: 'NetworkFirst',
      options: { cacheName: 'api-cache', networkTimeoutSeconds: 3, expiration: { maxEntries: 50, maxAgeSeconds: 300 } } },
    { urlPattern: /\.(?:png|jpg|jpeg|svg|gif|webp|avif)$/, handler: 'CacheFirst',
      options: { cacheName: 'image-cache', expiration: { maxEntries: 100, maxAgeSeconds: 30 * 24 * 60 * 60 } } },
  ],
});
export default withPWA({ /* next.js config */ });
```

App Router dynamic manifest via `app/manifest.ts` (`MetadataRoute.Manifest`). Update prompt via `workbox-window` Workbox class listening for `waiting` event → `wb.messageSkipWaiting()`. Install prompt: client-only component loaded with `dynamic(..., { ssr: false })`.

### React (Vite) PWA

```typescript
// vite.config.ts
VitePWA({
  registerType: 'autoUpdate',
  manifest: { name: 'My React App', short_name: 'ReactApp', /* icons, theme_color */ },
  workbox: {
    globPatterns: ['**/*.{js,css,html,ico,png,svg,woff2}'],
    runtimeCaching: [
      { urlPattern: /^https:\/\/api\./, handler: 'NetworkFirst',
        options: { cacheName: 'api-cache', networkTimeoutSeconds: 3, expiration: { maxEntries: 50, maxAgeSeconds: 300 } } },
    ],
  },
})
```

`generateSW` (default) generates full SW; `injectManifest` mode injects precache manifest into your custom SW — use when you need background sync or custom fetch strategies.

Update badge via `virtual:pwa-register/react`:
```typescript
const { needRefresh: [needRefresh, setNeedRefresh], updateServiceWorker } = useRegisterSW({
  onRegisteredSW(swUrl, registration) { if (registration) setInterval(() => registration.update(), 60 * 60 * 1000); },
});
```

Icon generation: `@vite-pwa/assets-generator` with `minimal2023Preset`.

### Angular

`ng add @angular/service-worker` — generates `ngsw-config.json`. Configure `assetGroups` (prefetch/lazy) and `dataGroups` (freshness/performance strategy). Update prompt via `SwUpdate.versionUpdates` pipe filtered to `VERSION_READY`.

### Blazor PWA (.NET 8+)

`dotnet new blazorwasm --pwa` — generates `service-worker.js`, `service-worker.published.js`, `manifest.webmanifest`.

Customize `onFetch` in `service-worker.published.js` for API network-first; leave `_framework/` cache-first (assemblies). Cache version: `blazor-cache-v${self.assetsManifest.version}` — auto-incremented on each `dotnet publish`. Dev SW is a no-op (no caching). JS interop update flow: `DotNet.invokeMethodAsync('MyApp', 'OnServiceWorkerUpdateAvailable')` → Blazor component shows update banner.

### Vue / Nuxt PWA

**Nuxt 3**: `@vite-pwa/nuxt` module (NOT `@nuxtjs/pwa` — Nuxt 2 only, unmaintained). Configure in `nuxt.config.ts` under `pwa:`. Use `useRegisterSW()` composable from `@vite-pwa/nuxt` for update prompts.

**Vue (Vite)**: `vite-plugin-pwa` with `virtual:pwa-register/vue` → `useRegisterSW()` composable.

### SvelteKit PWA

**Option 1**: `@vite-pwa/sveltekit` Vite plugin — Workbox-powered automatic precaching.

**Option 2**: Custom SW using `$service-worker` module — `build` (hashed `_app/` assets), `files` (static dir), `version` (build hash). Use `browser` from `$app/environment` before registering. Static manifest in `static/` or dynamic via `src/routes/manifest.webmanifest/+server.ts`.

## Anti-Patterns

- Caching authenticated API responses in shared SW cache — responses leak across sessions or users
- Force-reloading on SW update without user consent — destroys unsaved form state and in-progress work
- No cache expiration or size limits — storage grows unbounded; browsers start evicting caches silently
- Caching POST/PUT/DELETE responses — mutations must never be served stale from cache

## Workflow

1. Configure manifest with icons, start_url, display mode
2. Choose framework plugin or custom SW; set up precache
3. Define runtime caching strategies per resource type
4. Implement offline fallback and connectivity indicator
5. Add install prompt (post-engagement, not first visit)
6. Build update detection + notification flow
7. Configure push notifications if needed

Done: ✓ manifest configured with correct icons, start_url, display mode ✓ SW registers and controls page on second visit ✓ critical assets precached; API cached with appropriate strategy ✓ offline fallback served when network unavailable ✓ install prompt after engagement ✓ update notification shown; user controls when to update ✓ Lighthouse PWA audit passes ✓ cache sizes bounded ✓ tested on Chrome, Safari, Firefox
