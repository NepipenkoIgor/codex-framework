---
name: firebase-patterns
description: Implement Firebase features including Firestore data modeling, security rules, Cloud Functions, auth integration, hosting, FCM push notifications, and Firestore indexes
metadata:
  version: 1.5
  argument-hint: "Firestore schema, Cloud Functions, security rules, auth flows, notifications"
---

Implement $ARGUMENTS using Firebase as the backend platform.

## Documentation

> Use available docs lookup tools or official docs when you encounter unknown API syntax, current library versions, or framework-specific configuration. Do not rely on training data for library docs — fetch current docs on demand.

## Tool Integration

When structured Firebase tools are available: inspect Firestore collections/indexes, verify security rules, check auth provider settings, monitor Cloud Functions, manage hosting. Use to confirm rules deployed, functions active, indexes built.

## Documentation

> Use **available docs lookup tools or official docs** for current Firebase SDK, Firestore, Cloud Functions, and FCM docs. Do not rely on training data for API syntax or configuration.

## Project Detection

Detect from: `firebase.json`, `firebase`/`firebase-admin` in package.json, `FIREBASE_PROJECT_ID` env vars, `.firebaserc`, `firestore.rules`/`storage.rules`.

## Firestore Data Modeling

- Documents self-contained for common read patterns; denormalize data read together
- Keep documents under 100KB; use subcollections for unbounded data (messages, logs)
- Use document references (paths) for relationships, not embedded full objects
- Arrays for small bounded lists (<100 items); subcollections for unbounded
- Low-write counters: `FieldValue.increment(1)`; high-write (>1/s): sharded counters

```typescript
// users/{userId}
interface UserDoc { displayName: string; email: string; orgId: string; role: 'admin' | 'member' | 'viewer'; createdAt: Timestamp; updatedAt: Timestamp; }
// orgs/{orgId}/projects/{projectId}
interface ProjectDoc { name: string; status: 'active' | 'archived'; createdBy: string; createdAt: Timestamp; }
```

## Security Rules

Non-negotiables: deny-by-default, explicit rules per collection, validate all write data, never `allow write: if true` in production, test with Emulator Suite.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAuthenticated() { return request.auth != null; }
    function isOwner(userId) { return request.auth.uid == userId; }
    function isOrgMember(orgId) {
      return isAuthenticated()
        && exists(/databases/$(database)/documents/orgs/$(orgId)/members/$(request.auth.uid));
    }
    function isOrgAdmin(orgId) {
      return isAuthenticated()
        && get(/databases/$(database)/documents/orgs/$(orgId)/members/$(request.auth.uid)).data.role == 'admin';
    }

    match /users/{userId} {
      allow read: if isAuthenticated();
      allow create: if isOwner(userId)
        && request.resource.data.keys().hasAll(['displayName', 'email', 'createdAt'])
        && request.resource.data.displayName is string
        && request.resource.data.displayName.size() <= 100;
      allow update: if isOwner(userId)
        && !request.resource.data.diff(resource.data).affectedKeys().hasAny(['email', 'createdAt']);
    }

    match /orgs/{orgId} {
      allow read: if isOrgMember(orgId);
      allow update: if isOrgAdmin(orgId);
      match /projects/{projectId} {
        allow read: if isOrgMember(orgId);
        allow create: if isOrgMember(orgId) && request.resource.data.createdBy == request.auth.uid;
        allow delete: if isOrgAdmin(orgId);
      }
    }
  }
}
```

Minimize `get()`/`exists()` calls (each costs a read). Use custom claims for frequently checked roles:
```typescript
await getAuth().setCustomUserClaims(userId, { orgId: 'org-123', role: 'admin' });
// In rules: request.auth.token.role == 'admin'
```

## Cloud Functions (v2)

Use `firebase-functions/v2/*`. Set memory/timeout. Validate inputs. One responsibility per function. Idempotency keys for webhook handlers.

```typescript
// HTTP function
export const processWebhook = onRequest(
  { cors: true, region: 'us-central1', memory: '256MiB' },
  async (req, res) => {
    if (req.method !== 'POST') { res.status(405).json({ error: 'Method not allowed' }); return; }
    const { orderId } = req.body;
    if (!orderId || typeof orderId !== 'string') { res.status(400).json({ error: 'Invalid orderId' }); return; }
    await getFirestore().doc(`orders/${orderId}`).update({ status: 'processed', updatedAt: new Date() });
    res.json({ success: true });
  }
);

// Firestore trigger
export const onProjectCreated = onDocumentCreated('orgs/{orgId}/projects/{projectId}', async (event) => {
  if (!event.data) return;
  await getFirestore().doc(`orgs/${event.params.orgId}`).update({ projectCount: FieldValue.increment(1) });
});

// Auth trigger
export const onUserCreated = beforeUserCreated(async (event) => {
  await getFirestore().doc(`users/${event.data.uid}`).set({
    email: event.data.email, displayName: event.data.displayName ?? 'User', createdAt: new Date(),
  });
});

// Scheduled
export const dailyCleanup = onSchedule({ schedule: 'every day 03:00', timeZone: 'UTC' }, async () => {
  const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const stale = await getFirestore().collection('sessions').where('expiresAt', '<', cutoff).limit(500).get();
  const batch = getFirestore().batch();
  stale.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
});
```

## Auth Integration

```typescript
// Client: lib/firebase.ts
const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0];
export const auth = getAuth(app);
export const db = getFirestore(app);

// React auth hook
function useAuth() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    const unsub = onAuthStateChanged(auth, (u) => { setUser(u); setLoading(false); });
    return unsub;
  }, []);
  return { user, loading };
}

// Server: lib/firebase-admin.ts
if (getApps().length === 0) {
  initializeApp({ credential: cert({ projectId, clientEmail, privateKey: pk?.replace(/\\n/g, '\n') }) });
}
export const adminAuth = getAuth();
export const adminDb = getFirestore();
```

## FCM Push Notifications

```typescript
// Client registration
async function requestNotificationPermission() {
  if (await Notification.requestPermission() !== 'granted') return null;
  const token = await getToken(getMessaging(), { vapidKey: process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY });
  await saveTokenToServer(token);
  return token;
}

// Server sending + stale token cleanup
async function sendPush(token: string, title: string, body: string) {
  try { await getMessaging().send({ token, notification: { title, body } }); }
  catch (error: any) {
    if (error.code === 'messaging/registration-token-not-registered') await removeToken(token);
    throw error;
  }
}

// Topic messaging
await getMessaging().subscribeToTopic([userToken], `org-${orgId}`);
await getMessaging().send({ topic: `org-${orgId}`, notification: { title, body } });
```

Background SW (all frameworks, place at public root):
```javascript
// public/firebase-messaging-sw.js
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');
firebase.initializeApp({ /* same config */ });
firebase.messaging().onBackgroundMessage((payload) => {
  const { title, body, icon } = payload.notification ?? {};
  self.registration.showNotification(title ?? 'Notification', { body: body ?? '', icon: icon ?? '/icons/icon-192.png' });
});
```

## Firestore Indexes

Composite indexes required for multi-field filter or filter+sort queries. Define in `firestore.indexes.json`. Deploy: `firebase deploy --only firestore:indexes`. When queries fail with "requires an index", the error includes a creation link.

## Framework-Specific Integration

### Angular + Firebase

`@angular/fire` v7+ with standalone providers in `app.config.ts`. Signal-based auth: `toSignal(authState(auth), { initialValue: null })`. Reactive collections: `toSignal(collectionData(ref, { idField: 'id' }))`. FCM: `inject(Messaging)` with `getToken()` + `onMessage()`.

### SvelteKit + Firebase

Client SDK browser-only: guard with `browser` from `$app/environment`, lazy-init via `getFirebaseClient()`. Auth state via `onAuthStateChanged` in `onMount`. Firestore real-time: `onSnapshot` in `onMount` with cleanup. Server side: `firebase-admin` in `lib/server/firebase-admin.ts` using `$env/static/private`. SSR auth: verify ID token in `hooks.server.ts`, set `event.locals.user`.

### Blazor + Firebase

`FirebaseAdmin` NuGet for server (token verification, Firestore admin). Client uses JS interop with Firebase JS SDK. Expose `firebaseInterop` global with `getIdToken`, `signInWithGoogle`, `signOut`, `onAuthStateChanged`, `subscribeToCollection`. Blazor component calls via `JS.InvokeAsync` and exposes `[JSInvokable]` callback methods. FCM: `firebaseInterop.requestPushToken(vapidKey)` in `OnAfterRenderAsync`.

### Next.js App Router + Firebase

`lib/firebase.ts` (client, browser only) + `lib/firebase-admin.ts` (server, Node.js only) — never cross-import. Server Components use `adminDb` directly. Client Components use `useEffect` + `onAuthStateChanged`. Server Actions verify `__session` cookie via `adminAuth.verifyIdToken()`. Middleware: check `__session` cookie, redirect to `/login` for protected routes. FCM: wrap in `useEffect` in `'use client'` component; `messaging` exported as async fn guarded by `isSupported()`.

### Nuxt 3 + Firebase

Use `nuxt-vuefire` module with `sessionCookie: true` for SSR auth. Auto-imported composables: `useCurrentUser()`, `useFirestore()`, `useDocument()`, `useCollection()`. Admin for Nitro routes: `server/plugins/firebase.ts` initializing `firebase-admin`. FCM: `.client.ts` plugin.

### Vue (non-Nuxt) + Firebase

`vuefire` package with `VueFire` + `VueFireAuth()` plugins. Same `useCurrentUser()`, `useDocument()`, `useCollection()` composables. Initialize `firebase/messaging` in `onMounted`.

## Anti-Patterns

- Deeply nested subcollections (>3 levels) -- queries become impractical
- Unbounded arrays in documents -- document size limit hit as array grows
- `getDoc` in loops instead of `getDocs` with query -- N individual reads
- Missing composite indexes before deploying -- queries fail at runtime, not build time
- Not cleaning up stale FCM tokens -- delivery rate degrades silently over time

## Workflow

1. Detect existing Firebase setup
2. Design Firestore data model: collections, documents, subcollections, references
3. Write security rules for every collection
4. Define composite indexes for multi-field queries
5. Implement client SDK with auth state handling
6. Create Cloud Functions for server-side logic
7. Set up FCM if push notifications required
8. Test security rules with Emulator Suite → `firebase deploy`

Done: ✓ security rules on every collection with deny-by-default ✓ rules tested: unauthorized denied, authorized succeeds ✓ composite indexes defined for multi-field queries ✓ data model efficient: denormalized reads, subcollections for unbounded ✓ auth state managed with loading states ✓ Cloud Functions validate inputs, idempotent where needed ✓ FCM tokens stored per user, stale cleaned up
