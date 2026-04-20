---
name: push-notifications
description: Implement push notifications — FCM, APNs, Web Push with VAPID, service workers, notification scheduling, and delivery tracking
metadata:
  version: 1.3
  argument-hint: "platforms (iOS/Android/web), notification types, scheduling needs, delivery tracking requirements"
---

Implement push notification delivery for $ARGUMENTS.


## Platform Overview

| Platform | Payload limit | TTL | Use when |
|----------|--------------|-----|----------|
| FCM | 4KB | 28 days | Android, web, cross-platform (proxies APNs) |
| APNs | 4KB | 30 days | iOS, macOS, watchOS — or via FCM proxy |
| Web Push + VAPID | ~4KB | varies | All modern browsers |

Cross-platform: FCM for mobile + Web Push for browser, unified backend abstraction.

## FCM Implementation

### Server-Side Send (Node.js)

```typescript
import { initializeApp, cert } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';

initializeApp({ credential: cert({ projectId, clientEmail, privateKey: privateKey.replace(/\\n/g, '\n') }) });
const messaging = getMessaging();

async function sendToDevice(token: string, notification: NotificationPayload): Promise<string> {
  try {
    return await messaging.send({
      token,
      notification: { title: notification.title, body: notification.body, imageUrl: notification.imageUrl },
      data: notification.data ?? {},
      android: { priority: 'high', notification: { channelId: notification.channelId ?? 'default', sound: 'default' } },
      apns: { headers: { 'apns-priority': '10' }, payload: { aps: { sound: 'default', badge: notification.badge, 'mutable-content': 1 } } },
      webpush: { notification: { icon: notification.iconUrl ?? '/icons/icon-192.png', actions: notification.actions }, fcmOptions: { link: notification.actionUrl } },
    });
  } catch (error: any) {
    if (['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(error.code))
      await removeStaleToken(token);
    throw error;
  }
}

async function sendToDevices(tokens: string[], notification: NotificationPayload): Promise<BatchResult> {
  const response = await messaging.sendEachForMulticast({ tokens, notification, data: notification.data ?? {} });
  const staleTokens = response.responses
    .map((r, i) => r.error?.code === 'messaging/registration-token-not-registered' ? tokens[i] : null)
    .filter(Boolean) as string[];
  if (staleTokens.length) await removeStaleTokens(staleTokens);
  return { successCount: response.successCount, failureCount: response.failureCount, staleTokensRemoved: staleTokens.length };
}
```

### .NET

```csharp
FirebaseApp.Create(new AppOptions { Credential = GoogleCredential.FromJson(config["Firebase:ServiceAccountJson"]) });

// In service:
try { return await _messaging.SendAsync(message, ct); }
catch (FirebaseMessagingException ex) when (ex.MessagingErrorCode == MessagingErrorCode.Unregistered)
{ await RemoveStaleTokenAsync(token, ct); throw; }
```

### Message Types

| Type | Background behavior | Use when |
|------|---------------------|----------|
| Notification message | System tray (automatic) | Simple user-facing alerts |
| Data-only message | App handles everything | Custom processing, silent sync |
| Combined (notification + data) | System tray + data available | Rich notifications with payload |

Data values must be strings — `JSON.stringify` nested objects.

### Topics and Conditions

```typescript
await messaging.subscribeToTopic([token], 'promotions');
await messaging.send({ topic: 'breaking-news', notification: { title, body } });
await messaging.send({ condition: "'sports' in topics && 'soccer' in topics", notification: { title, body } });
```

Max 5 topics per condition. Topic names: alphanumeric + hyphens + underscores.

## APNs Implementation (Direct)

Use FCM as a proxy for most cases. Direct APNs: `apn` package with token-based auth (.p8 key):

```typescript
const provider = new apn.Provider({ token: { key: APNS_KEY_PATH, keyId: APNS_KEY_ID, teamId: APNS_TEAM_ID }, production: isProd });
const n = new apn.Notification();
n.alert = { title, body }; n.badge = badge; n.sound = 'default';
n.topic = BUNDLE_ID; n.pushType = 'alert'; n.priority = 10; n.expiry = Date.now() / 1000 + 86400;
if (mediaUrl) { n.mutableContent = true; n.payload.mediaUrl = mediaUrl; }
const result = await provider.send(n, deviceToken);
result.failed.filter(f => f.status === '410').forEach(f => removeStaleToken(f.device));
```

APNs errors: `400 BadDeviceToken` + `410 Unregistered` → remove token immediately. `429` → backoff. `403 InvalidProviderToken` → check .p8 key.

Priority: 10 = immediate delivery; 5 = power-friendly (batched). TTL: 0 = deliver now or discard; 86400 = retry 24h.

## Web Push API

```bash
# One-time VAPID key generation
npx web-push generate-vapid-keys
```

```typescript
// Browser subscription
const subscription = await registration.pushManager.subscribe({
  userVisibleNotification: true,
  applicationServerKey: urlBase64ToUint8Array(process.env.NEXT_PUBLIC_VAPID_KEY!),
});
await fetch('/api/push/subscribe', { method: 'POST', body: JSON.stringify({ endpoint: subscription.endpoint, keys: { p256dh: ..., auth: ... } }) });

// Service worker: push event → showNotification, notificationclick → clients.openWindow
// Server send:
webpush.setVapidDetails('mailto:push@yourdomain.com', VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY);
await webpush.sendNotification(subscription, JSON.stringify({ title, body, actionUrl, tag, actions }), { TTL: 86400, urgency: 'normal' });
// 404/410 → remove stale subscription
```

Handle `pushsubscriptionchange` service worker event — subscriptions silently expire.

## Device Registration

```sql
CREATE TABLE push_device_tokens (
  id UUID PRIMARY KEY, user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
  token TEXT NOT NULL, subscription_data JSONB,  -- Web Push keys
  device_id TEXT, app_version TEXT, os_version TEXT, device_model TEXT,
  last_active_at TIMESTAMPTZ DEFAULT now(), created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, token)
);
CREATE INDEX idx_push_tokens_user ON push_device_tokens (user_id);
CREATE INDEX idx_push_tokens_last_active ON push_device_tokens (last_active_at);
```

Registration endpoint: upsert by `(userId, token)`, update `lastActiveAt`.

Multi-device: user may have multiple tokens (phone, tablet, browser). Send to ALL active tokens. Prune inactive >60 days (daily job). On logout: remove current device token only.

FCM token refresh: listen to `onTokenRefresh`, re-register new token, unregister old one.

## Rich Notifications

**Images**: FCM → `notification.imageUrl`; APNs → `mutableContent: true` + Notification Service Extension downloads `mediaUrl`. JPEG/PNG, max 1MB.

**Action buttons**: FCM Android → `clickAction`; APNs → `aps.category` (register `UNNotificationCategory` in app); Web Push → `actions` array with `action`, `title`, `icon`.

**Deep links**: include both custom scheme (`myapp://orders/123`) and universal link (`https://app.example.com/orders/123`) in data payload.

**Silent push** (background sync): FCM → data-only, `android.priority: 'high'`; APNs → `content-available: 1`, `apns-push-type: background`, priority 5. iOS throttles and may not wake force-quit apps — don't rely on it for critical delivery.

## Delivery Tracking

```sql
CREATE TABLE push_delivery_logs (
  notification_id UUID, user_id UUID, platform TEXT,
  status TEXT DEFAULT 'pending',  -- pending, sent, delivered, opened, failed
  provider_message_id TEXT, sent_at TIMESTAMPTZ, delivered_at TIMESTAMPTZ,
  opened_at TIMESTAMPTZ, failed_at TIMESTAMPTZ, error_code TEXT
);
```

Track opens via deep link handler (`POST /api/push/track-open`). Metrics: delivery rate >95%, open rate >10%, opt-out <1%/month, error rate <2%.

## Notification Preferences

```sql
CREATE TABLE push_notification_preferences (
  user_id UUID NOT NULL, category TEXT NOT NULL, enabled BOOLEAN DEFAULT true,
  UNIQUE (user_id, category)
);
```

| Category | Default | Can disable? |
|----------|---------|-------------|
| Security (login, 2FA) | Enabled | No |
| Transactional (receipts) | Enabled | No |
| Activity (mentions, updates) | Enabled | Yes |
| Marketing (promotions) | Disabled | Yes |

Check preferences before sending (security always bypasses). Quiet hours: respect user timezone, check current time vs configured range. Frequency cap: max 5/hour, 20/day — Redis TTL counters. Collapse related notifications with `tag` (Web Push) or `collapse_key` (FCM).

## Error Handling

| Error | Action |
|-------|--------|
| Invalid token / Unregistered (400/404/410) | Remove immediately, do not retry |
| Rate limited (429) | Backoff + respect Retry-After |
| Server error (500/503) | Exponential backoff, max 3 retries |
| Auth error (401/403) | Alert ops, do not retry |
| Payload too large | Log, do not retry |

```typescript
function isPermanentError(err: any): boolean {
  return [400, 404, 410].includes(err.statusCode) ||
    ['messaging/invalid-registration-token', 'messaging/registration-token-not-registered'].includes(err.code);
}
```

## Anti-Patterns

- No deduplication — rapid events trigger duplicate notifications
- Same retry strategy for all error types — permanent failures need removal, not retry
- Not handling token refresh — tokens change; stale tokens accumulate silently
- No frequency capping — notification fatigue leads to unsubscribes and uninstalls
- Relying on silent push for critical delivery — iOS throttles and drops background notifications

## Workflow

1. Choose platforms; generate credentials (FCM service account, APNs .p8, VAPID keys)
2. Implement device registration endpoint with upsert and `lastActiveAt` tracking
3. Build notification send functions with platform-specific formatting
4. Add error handling with stale token cleanup
5. Implement delivery tracking table and analytics
6. Add preference management with category opt-in/out and quiet hours
7. Add frequency capping; queue push sending via background worker
8. Test on real devices per platform

Done: ✓ tokens registered/refreshed ✓ stale tokens cleaned on errors + daily ✓ preferences respected per category ✓ quiet hours + frequency capping ✓ platform-specific payload formatting ✓ delivery tracked (sent/delivered/opened/failed) ✓ push sending async via queue ✓ tested on real devices
