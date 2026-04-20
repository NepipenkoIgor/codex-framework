---
name: offline-sync-design
description: Design offline-first sync architecture — conflict resolution, CRDTs, local-first storage, sync protocols, and network recovery
metadata:
  version: 1.4
  argument-hint: "platform (web/mobile), data type (documents/relational), conflict frequency, sync frequency"
---

Design offline sync architecture for $ARGUMENTS.


## Core Principles

- Local-first: app works entirely offline as the default state
- Server is the eventual consistency target, not the primary data source
- Every write goes to local storage first, then syncs when online
- Conflicts are inevitable -- design for them, don't prevent them

## Architecture

```
User Action -> Local Database -> Optimistic UI Update -> Sync Queue
  -> Network Available? -> Yes: Push/Pull + Conflict Resolution -> Apply resolved state
                        -> No: Queue changes, retry when online
```

## Local Database Selection

| Technology | Platform | Best for | Query support |
|------------|----------|----------|---------------|
| SQLite (expo-sqlite) | Mobile | Complex queries, large datasets | Full SQL |
| WatermelonDB | React Native | High performance, sync-ready | Query builder |
| PouchDB | Web, Mobile | CouchDB sync, small datasets | Map/reduce |
| IndexedDB (via Dexie.js) | Web (PWA) | Structured browser storage | Index-based |
| MMKV | Mobile | Key-value preferences | Key lookup |

Decision: RN + complex queries -> WatermelonDB/SQLite. PWA -> IndexedDB via Dexie. CouchDB sync -> PouchDB. Key-value -> MMKV.

### Schema Pattern

Every synced table needs: `id`, `server_id` (nullable), `is_synced` (boolean), `last_modified_at` (timestamp), `created_at`, `updated_at`.

## Conflict Resolution Strategies

### Last Write Wins (LWW)

Simplest: most recent write by timestamp wins. Use for non-critical data (preferences, settings, drafts) where latest value is genuinely correct. Risk: earlier writes silently discarded; clock skew can cause unexpected results.

### Field-Level Merge

Merge at field level: non-conflicting fields apply from each side, conflicting fields use LWW per field. Use when records have independent fields (user profile, settings) and different devices typically edit different fields.

### CRDTs (Conflict-Free Replicated Data Types)

Mathematically guaranteed convergence across replicas regardless of operation order.

| CRDT | Use case |
|------|----------|
| G-Counter | Increment-only (views, likes) |
| PN-Counter | Increment/decrement (cart quantity) |
| LWW-Register | Single value, last write wins |
| OR-Set | Add/remove set items (tags) |
| RGA | Ordered list with insert/delete |

Use CRDTs when multiple users edit the same data concurrently and conflicts must resolve automatically. Libraries: Automerge, Yjs, json-joy.

### Manual Resolution

Present conflicts to the user. Use for critical data (financial records, legal documents) where automated resolution would produce wrong results.

### Strategy Per Data Type

| Data type | Strategy |
|-----------|---------|
| User preferences | LWW |
| Todo items | Field-level merge |
| Collaborative docs | CRDT (Yjs/Automerge) |
| Shopping cart | PN-Counter + OR-Set |
| Chat messages | Append-only (no conflicts) |
| Financial records | Manual resolution |

## Sync Queue Design

```
SyncQueue { id, table_name, record_id, operation (create/update/delete), payload, priority, status (pending/syncing/failed/completed), attempts, max_attempts, error, created_at }
```

Processing rules:
- Order: creates before updates, updates before deletes
- Deduplicate: merge multiple updates to the same record
- Respect dependencies: parent records sync before children
- Retry with exponential backoff: 1s, 2s, 4s, 8s, 16s
- Dead letter after max attempts
- Clean up completed items periodically (24h retention)

## Example

### Sync Queue with Conflict Resolution (React Native + WatermelonDB)

```typescript
// sync-engine.ts
import NetInfo from '@react-native-community/netinfo';
import { database } from './database';

interface SyncQueueItem {
  id: string;
  table: string;
  recordId: string;
  operation: 'create' | 'update' | 'delete';
  payload: Record<string, unknown>;
  attempts: number;
  createdAt: number;
}

class SyncEngine {
  private syncing = false;

  async enqueue(item: Omit<SyncQueueItem, 'id' | 'attempts' | 'createdAt'>) {
    await database.write(async () => {
      await database.get<SyncQueue>('sync_queue').create((rec) => {
        rec.table = item.table;
        rec.recordId = item.recordId;
        rec.operation = item.operation;
        rec.payload = JSON.stringify(item.payload);
        rec.attempts = 0;
        rec.createdAt = Date.now();
      });
    });
    this.trySync();
  }

  async trySync() {
    const { isConnected } = await NetInfo.fetch();
    if (!isConnected || this.syncing) return;
    this.syncing = true;

    try {
      const pending = await database
        .get<SyncQueue>('sync_queue')
        .query(Q.sortBy('created_at', Q.asc))
        .fetch();

      for (const item of pending) {
        try {
          const serverRecord = await api.sync(item.table, item.operation, JSON.parse(item.payload));

          // Field-level merge on conflict
          if (serverRecord._conflict) {
            const local = JSON.parse(item.payload);
            const merged = fieldLevelMerge(local, serverRecord.server, serverRecord.base);
            await api.sync(item.table, 'update', merged);
          }

          await database.write(() => item.destroyPermanently());
        } catch (err) {
          if (item.attempts >= 5) {
            await database.write(() => item.update((r) => { r.status = 'dead_letter'; }));
          } else {
            await database.write(() => item.update((r) => { r.attempts += 1; }));
          }
        }
      }
    } finally {
      this.syncing = false;
    }
  }
}

function fieldLevelMerge(
  local: Record<string, unknown>,
  server: Record<string, unknown>,
  base: Record<string, unknown>,
): Record<string, unknown> {
  const merged = { ...server };
  for (const key of Object.keys(local)) {
    const localChanged = local[key] !== base[key];
    const serverChanged = server[key] !== base[key];
    if (localChanged && !serverChanged) {
      merged[key] = local[key]; // local wins for non-conflicting fields
    }
    // server wins for conflicting fields (both changed)
  }
  return merged;
}
```

## Optimistic Updates

1. Update local DB immediately with `isSynced: false`
2. UI updates instantly from local DB
3. Queue for server sync
4. Trigger sync if online
5. On conflict: apply resolution strategy, update local DB
6. On permanent failure: notify user, keep local state, offer manual retry

## Network State Detection

React Native: `NetInfo.addEventListener` -- check `isConnected && isInternetReachable`. Web: `navigator.onLine` + online/offline events (verify with health check endpoint). On reconnect: trigger full sync. Debounce transitions (500ms) to avoid flapping.

## Backend Sync Patterns

### Delta Sync (Pull-Based)

Client sends `lastSyncAt` timestamp, server returns created/updated/deleted records since then. Efficient for most use cases.

### Supabase Realtime

Subscribe to `postgres_changes` with scope filter. On INSERT/UPDATE/DELETE events, update local DB. Handle conflicts when local has unsynced changes.

### Firebase Offline

Enable `enableIndexedDbPersistence`. Reads work from cache, writes queue automatically. Use `metadata.hasPendingWrites` to show sync status.

## Sync Status UI

| State | Icon | Color | Label |
|-------|------|-------|-------|
| Synced | Checkmark | Green | "All changes saved" |
| Syncing | Spinner | Blue | "Syncing..." |
| Pending | Cloud+arrow | Yellow | "Changes pending" |
| Offline | Cloud+slash | Gray | "Working offline" |
| Error | Warning | Red | "Sync error - tap to retry" |
| Conflict | Two arrows | Orange | "Conflict - tap to resolve" |

Show global status bar + per-record sync indicators on unsynced records.

## Data Integrity

- Checksum verification (SHA-256/CRC32) before and after sync
- Periodic full integrity check against server
- Version local DB schema; run migrations on app startup before data access
- Never delete local data during migration -- transform it

## Bandwidth Optimization

- Send only changed fields (JSON Patch RFC 6902)
- Batch sync: accumulate changes, send 50-200 records per request
- Compress payloads with gzip
- Sync triggers: app launch (full delta), record change (queue), app background (flush), reconnect (full delta), periodic foreground (30-60s)

## Frontend Framework Integration

### Angular Offline Patterns

- `@angular/service-worker`: use `SwUpdate` service for update detection with `inject(SwUpdate)`
- Signal-based network state: `readonly isOnline = signal(navigator.onLine)` with event listeners registered in `effect()` for automatic cleanup
- IndexedDB via `idb` library wrapped in an injectable service for type-safe offline storage
- Sync queue: service storing failed requests in IndexedDB, replaying on `online` event with exponential backoff
- `@angular/pwa` schematic for quick PWA setup: `ng add @angular/pwa` generates manifest, service worker config, and offline shell

### Vue / Nuxt Offline Patterns

- `@vueuse/core` `useOnline()` composable for reactive network state -- returns a `Ref<boolean>` that updates on connectivity changes
- IndexedDB: `idb-keyval` for simple key-value or Dexie.js for structured queries, wrapped in a composable like `useOfflineStore()` for reactive access
- Sync queue composable: `useOfflineQueue()` storing pending mutations in IndexedDB, flushing in `watch(isOnline, ...)` when connectivity returns
- Nuxt: `@vite-pwa/nuxt` module for service worker and offline shell; `useState('isOnline')` for SSR-safe network state that hydrates correctly on the client
- Optimistic updates: `useMutation()` pattern -- update UI immediately via reactive state, queue server sync in background, roll back on permanent failure

### SvelteKit Offline Patterns

- Network state with runes: `let isOnline = $state(navigator.onLine)` with `$effect()` listening to `online`/`offline` window events for automatic tracking and cleanup
- IndexedDB: `idb` library in client-only code, guarded by `browser` check from `$app/environment` to prevent SSR errors
- Service worker: `$service-worker` module (`build`, `files`, `version`) for custom service worker with offline caching and precache manifest
- Sync queue: `$state` array of pending mutations, flushed in `$effect` when `isOnline` transitions to `true` -- queue persists to IndexedDB for survival across app restarts
- `@vite-pwa/sveltekit` for Workbox-based offline shell with automatic precaching and runtime caching strategies

### Blazor Offline Patterns

- Blazor WASM PWA: `service-worker.published.js` with custom `onFetch` handler for offline caching strategies (cache-first for assemblies, network-first for API routes)
- Local storage via `IJSRuntime.InvokeAsync<string>("localStorage.getItem", key)` for simple key-value persistence
- IndexedDB via JS interop: `Blazored.LocalStorage` for convenience or custom JS module for full IndexedDB access with structured data
- `NavigatorOnLine` check: `IJSRuntime.InvokeAsync<bool>("eval", "navigator.onLine")` with JS event forwarding via `DotNetObjectReference` for real-time connectivity tracking
- Sync queue: C# `Queue<PendingMutation>` persisted to localStorage via JS interop, flushed on reconnect detection via the online event callback
- `.NET 8 WASM` offline assembly caching via `blazor.boot.json` manifest -- each `dotnet publish` generates a new version hash for automatic cache invalidation

### Next.js Offline Patterns

- `@ducanh2912/next-pwa` (maintained fork) for service worker generation and offline shell with Workbox runtime caching
- `navigator.onLine` in Client Component with `useState` and `useEffect` listening to `online`/`offline` events for network state tracking
- IndexedDB: `idb` or Dexie.js in Client Components only -- never access IndexedDB in Server Components or Server Actions
- Server Action queue: store failed Server Actions in IndexedDB with action name and payload, retry on reconnect using `navigator.onLine` event
- `workbox-background-sync` for automatic retry of failed `fetch` requests via the Background Sync API in the service worker

### Cross-Framework Patterns

- Conflict resolution strategies: Last-Write-Wins (LWW) for preferences and settings, field-level merge for profile data, CRDT (Yjs, Automerge) for collaborative documents
- Sync status UI: pending count badge on sync indicator, animated spinner during active sync, error toast with retry action on permanent failure
- Background Sync API: `registration.sync.register('sync-mutations')` in the service worker for OS-managed retry of queued mutations when connectivity returns
- Storage quota: `navigator.storage.estimate()` to check available space before caching large datasets -- warn users when approaching limits and prioritize essential data

## Anti-Patterns

- Wall clock time for conflict resolution without NTP sync -- clock skew causes incorrect last-write-wins outcomes
- Storing sync queue only in memory -- queued changes are lost when the app is killed
- No conflict resolution strategy -- concurrent offline edits silently overwrite each other on sync
- Syncing on every keystroke -- drains battery and saturates the sync queue with partial states

## Output Format

```
Local Database:    [SQLite / WatermelonDB / IndexedDB]
Conflict Strategy: [LWW / Field-level / CRDT / Manual]
Sync Transport:    [REST delta / Supabase Realtime / Firebase offline]
Sync Direction:    [Bidirectional / Push-only / Pull-only]
Bandwidth:         [Delta sync, batch ops, compressed payloads]
UI:                [Global status bar, per-record indicators, conflict dialog]
```

## Done Criteria

- Conflict resolution produces deterministic results per strategy
- Sync failures retry with exponential backoff
- Data integrity verified with checksums after sync
