---
name: email-notifications
description: Implement transactional email, push notifications, in-app notifications, and notification preference management FCM
metadata:
  version: 1.4
  argument-hint: "notification type (email/push/in-app), platform (web/mobile/both), provider (SendGrid/Twilio/FCM), template design, preference management"
---

Implement notification functionality for $ARGUMENTS.

## Documentation

> Use available docs lookup tools or official docs when you encounter unknown API syntax, current library versions, or framework-specific configuration. Do not rely on training data for library docs — fetch current docs on demand.

## Notification Channels

| Channel | Use case | Provider examples | Delivery guarantee |
|---------|----------|-------------------|--------------------|
| Transactional email | Receipts, password reset, verification | SendGrid, Postmark, AWS SES, Resend | At-least-once |
| Marketing email | Newsletters, campaigns | Mailchimp, SendGrid Marketing | Best-effort |
| Push notifications | Mobile alerts, web push | Firebase FCM, APNs, OneSignal, web Push API | Best-effort |
| In-app notifications | Activity feed, alerts within the app | Custom implementation | At-least-once |
| SMS | OTP, critical alerts | Twilio, AWS SNS | At-least-once |
| Webhook | System-to-system notifications | Custom implementation | At-least-once with retry |

## Notification Architecture

### Event-Driven Pipeline

```
User Action / System Event
  |
  v
Event Bus (domain event emitted)
  |
  v
Notification Service (resolves recipients, preferences, templates)
  |
  v
Channel Router (routes to email, push, in-app, SMS based on preferences)
  |
  +---> Email Queue ---> Email Worker ---> Provider API ---> Delivery Tracking
  +---> Push Queue  ---> Push Worker  ---> FCM/APNs     ---> Delivery Tracking
  +---> In-App      ---> DB Write     ---> WebSocket/SSE ---> Client
  +---> SMS Queue   ---> SMS Worker   ---> Twilio/SNS   ---> Delivery Tracking
```

### Core Components

1. **Event Listener** — subscribes to domain events, triggers notification creation
2. **Notification Service** — resolves recipients, checks preferences, selects channels
3. **Template Engine** — renders content per channel with user/context data
4. **Channel Router** — dispatches to per-channel queues
5. **Delivery Workers** — per-channel workers that call provider APIs with retry
6. **Tracking Store** — records delivery status, opens, clicks, bounces, complaints
7. **Preference Service** — manages user channel/category/frequency preferences

### Rules

- Never send notifications synchronously in API request handlers
- Every notification passes through the preference check before dispatch
- Every send attempt is logged with status and provider response
- Deduplication by event+recipient+channel within a configurable window (default 5 min)
- Idempotent workers — safe to retry on failure without duplicate delivery

## Transactional Email

### Email Best Practices

- Send via queue/background job — never block HTTP request
- Use a dedicated transactional email provider (not SMTP relay)
- Include plain text version alongside HTML
- Set proper From, Reply-To, and List-Unsubscribe headers
- Use consistent From address and domain — changing it hurts reputation
- Track delivery status: sent, delivered, opened, clicked, bounced, complained
- Rate limit per recipient to prevent spam classification
- Keep email size under 100KB including HTML — large emails get clipped (Gmail clips at 102KB)

### Email Deliverability

SPF (Sender Policy Framework):
- Publish a DNS TXT record authorizing your email provider to send on your behalf
- Format: `v=spf1 include:sendgrid.net include:_spf.google.com ~all`
- Use `~all` (soft fail) during setup, switch to `-all` (hard fail) once verified
- Keep SPF record under 10 DNS lookups

DKIM (DomainKeys Identified Mail):
- Generate a DKIM key pair — provider gives you the public key DNS record
- Add a CNAME or TXT record: `s1._domainkey.yourdomain.com`
- Use 2048-bit keys minimum
- Rotate keys annually — add new key, wait for propagation, remove old key

DMARC (Domain-based Message Authentication):
- Start with monitoring: `v=DMARC1; p=none; rua=mailto:dmarc@yourdomain.com`
- Graduate to quarantine: `p=quarantine; pct=10` then increase percentage
- Final enforcement: `p=reject` — only after monitoring shows clean results
- Aggregate reports reveal unauthorized senders using your domain

Warm-up strategy for new domains/IPs:
- Day 1-3: 50 emails/day to engaged recipients
- Day 4-7: 100-500 emails/day
- Week 2-3: 1,000-5,000 emails/day
- Week 4+: full volume
- Monitor bounce rate (<2%), complaint rate (<0.1%), and inbox placement throughout

### Bounce Handling Architecture

```
Provider Webhook (bounce/complaint event)
  |
  v
Webhook Handler (verify signature, persist event)
  |
  v
Bounce Processor
  |
  +---> Hard Bounce: mark email as invalid, suppress future sends
  +---> Soft Bounce: increment counter, retry up to 3 times, then suppress
  +---> Complaint:   mark as complained, suppress ALL future sends, log for audit
```

Bounce types and handling:

| Type | Examples | Action |
|------|----------|--------|
| Hard bounce | Invalid address, domain doesn't exist | Immediately suppress — never send again |
| Soft bounce | Mailbox full, server temporarily unavailable | Retry 3 times over 72 hours, then suppress |
| Complaint (spam) | User clicked "Report Spam" | Immediately suppress, add to suppression list |
| Block | IP/domain blacklisted | Alert ops team, check reputation, review sending patterns |

Suppression list:
- Maintain a per-tenant suppression list of emails that must never receive messages
- Check suppression list BEFORE queuing any email
- Include: hard bounces, complaints, manual unsubscribes, role addresses (noreply@, abuse@)
- Expose admin API to manage suppression list entries
- Sync suppression list with provider's suppression list on a schedule

### Notification Aggregation and Digests

Digest strategy:
- Collect notifications during a time window instead of sending each individually
- User selects frequency: instant, hourly, daily, weekly
- Digest job runs on schedule, groups notifications by category/source
- Render a single email with all grouped notifications
- Include a count summary at the top and individual items below
- Link to in-app notification center for full details

Implementation:

```
NotificationBuffer {
  id: uuid
  user_id: uuid
  channel: enum
  category: string
  payload: jsonb           // notification data for rendering
  digest_key: string       // groups related notifications (e.g., "project:123")
  created_at: timestamp
  digested_at: timestamp   // null until included in a digest
}
```

Digest job workflow:
1. Query buffered notifications where `digested_at IS NULL` grouped by user + frequency
2. For each user: group notifications by category
3. Render digest template with grouped items
4. Send single email/push per user
5. Mark all included notifications as `digested_at = now()`
6. Respect user timezone — deliver daily digest at 9 AM user's local time

### Template System

- Use provider templates or server-side templating (Handlebars, Razor, Nunjucks, MJML)
- Separate template from data — never build HTML strings manually
- Support localization (i18n) from the start — template per locale or i18n keys in template
- Preview templates with sample data before sending
- Inline CSS for email compatibility (use tools like Juice, MJML, or Maizzle)
- Use MJML or similar framework for responsive email HTML — raw HTML is fragile across clients

Template versioning:
- Version templates alongside code — templates are code
- Never modify a template in-place that affects in-flight emails
- Deploy new template version, route new sends to it, keep old version for in-flight
- Store template version in delivery log for debugging

A/B testing for templates:
- Split recipients into cohorts (control and variant) by user ID hash for deterministic assignment
- Track open rate and click-through rate per variant
- Minimum sample size: 1,000 sends per variant before drawing conclusions
- Auto-promote winning variant after statistical significance threshold
- Only test one variable at a time (subject line OR body, not both)

### Standard Email Templates

- Welcome / verification email
- Password reset
- Transaction receipt / confirmation
- Notification digest (daily/weekly summary)
- Alert / warning (account security, billing)
- Invitation (team invite, shared resource)
- Re-engagement (inactive user)

## In-App Notifications

### Data Model

```
Notification {
  id: uuid
  user_id: uuid
  type: enum (info, warning, success, error)
  category: string               // e.g., "billing", "team", "security"
  title: string
  body: string
  action_url: string (optional)
  action_label: string (optional)
  actor_id: uuid (optional)       // user who triggered the notification
  resource_type: string (optional) // e.g., "invoice", "project"
  resource_id: uuid (optional)
  read: boolean (default false)
  seen: boolean (default false)   // seen in notification list vs actually read
  archived: boolean (default false)
  created_at: timestamp
  read_at: timestamp (nullable)
  expires_at: timestamp (nullable)
}
```

### API Endpoints

- `GET /notifications` — paginated list, filter by read/unread/category, sort by created_at desc
- `GET /notifications/unread-count` — badge count, optimized query (COUNT with index)
- `PATCH /notifications/:id/read` — mark as read, set read_at timestamp
- `POST /notifications/mark-all-read` — mark all unread as read for the user
- `DELETE /notifications/:id` — archive or soft-delete
- `GET /notifications/preferences` — user notification preferences
- `PUT /notifications/preferences` — update preferences

### Real-Time Delivery

- Use WebSocket/SSE for instant delivery to connected clients
- Fall back to polling (30s interval) if WebSocket unavailable
- Show badge count on notification bell icon — update in real-time
- Toast/snackbar for high-priority notifications (errors, security alerts)
- Group related notifications in the UI (e.g., "3 new comments on Project X")
- Support "mark as read" on scroll/visibility (IntersectionObserver)

### Badge Count Optimization

- Cache unread count in Redis/memory — do not COUNT(*) on every request
- Increment on new notification, decrement on read, reset on mark-all-read
- Broadcast count updates via WebSocket when count changes
- Stale count is acceptable for 1-2 seconds — eventual consistency is fine

## Push Notifications

### Firebase Cloud Messaging (FCM) — Android + Web

Registration flow:
1. Client requests notification permission from user
2. On grant: get FCM token from Firebase SDK
3. Send token to server, associate with user and device
4. Store token with device metadata (platform, app version, last active)

Sending:
- Use FCM HTTP v1 API (not legacy API)
- Set `notification` for display notifications, `data` for background processing
- Set `android.priority = "high"` for time-sensitive messages
- Set TTL (time_to_live) based on urgency — 0 for instant, 86400 for daily

Token management:
- Refresh tokens on app launch — tokens can change
- Remove invalid tokens when FCM returns `InvalidRegistration` or `NotRegistered`
- Track last_active per token — prune tokens inactive for 60+ days

### Apple Push Notification Service (APNs) — iOS

- Use token-based authentication (JWT) over certificate-based
- Set `apns-push-type` header: `alert`, `background`, `voip`
- Set `apns-priority`: 10 for immediate, 5 for power-friendly
- Handle `410 Gone` response — device token is no longer valid
- Support provisional authorization (iOS 12+) for quiet notifications

### Web Push (Browser)

- Use the Web Push Protocol with VAPID keys
- Generate VAPID key pair (P-256 ECDSA), store private key securely
- Subscribe via `PushManager.subscribe()` with `applicationServerKey`
- Payload must be encrypted (Web Push encryption standard)
- Handle `pushsubscriptionchange` event for token rotation
- Service worker required for receiving push in background
- Respect `Notification.permission` — never re-prompt after denial

### Push notification content rules

- Title: max 50 characters (truncated on most platforms)
- Body: max 150 characters for reliable display
- Include action URL / deep link for navigation
- Use notification channels/categories (Android 8+) for user control
- Collapse notifications of the same type (use `collapse_key` / `thread-id`)
- Silent/data notifications for background sync — no user-visible alert

## Notification Preferences

### User Preference Model

```
NotificationPreference {
  id: uuid
  user_id: uuid
  channel: enum (email, push, in_app, sms)
  category: enum (marketing, transactional, security, activity, billing, team)
  enabled: boolean
  frequency: enum (instant, hourly_digest, daily_digest, weekly_digest)
  quiet_hours_start: time (nullable)  // e.g., 22:00
  quiet_hours_end: time (nullable)    // e.g., 08:00
  timezone: string                     // e.g., "America/New_York"
  updated_at: timestamp
}
```

### Preference Center Implementation

UI requirements:
- Matrix view: categories (rows) x channels (columns)
- Toggle per cell (category + channel combination)
- Frequency selector per category (instant, daily digest, weekly digest)
- Quiet hours configuration with timezone picker
- "Pause all" toggle for temporary muting
- One-click unsubscribe landing page (linked from every email)

Rules:
- Transactional + security notifications cannot be fully disabled (legal/compliance requirement)
- Respect user timezone for digest delivery timing
- Provide one-click unsubscribe in every email (CAN-SPAM, GDPR compliance)
- List-Unsubscribe header with both mailto and https methods (RFC 8058)
- Default preferences: email=enabled for all, push=disabled, in_app=enabled, sms=disabled
- Changes take effect immediately — no "save" required; auto-save on toggle

### One-Click Unsubscribe

Email header:
```
List-Unsubscribe: <mailto:unsubscribe@yourdomain.com?subject=unsubscribe>, <https://yourdomain.com/unsubscribe?token=...>
List-Unsubscribe-Post: List-Unsubscribe=One-Click
```

Landing page:
- Accept the unsubscribe token (JWT or signed URL with user_id + category)
- Show confirmation: "You've been unsubscribed from [category]"
- Offer link to full preference center for granular control
- No login required — the token is the authentication

## Rate Limiting and Throttling

Per-recipient limits:
- Max 1 email per type per hour (e.g., max 1 password reset email per hour)
- Max 5 push notifications per hour per user
- Max 10 in-app notifications per hour per user
- Max 1 SMS per type per 5 minutes

Per-sender limits:
- Track sends per minute/hour against provider rate limits
- Implement token bucket or sliding window rate limiter
- Queue excess messages and drain at the allowed rate
- Alert when approaching provider limits (80% threshold)

Throttling for bulk sends:
- Never send bulk campaigns at full speed — stagger over hours
- Monitor provider feedback during send — slow down on soft bounces
- Segment large lists into batches of 500-1,000 with delays between batches

## Framework-Specific Implementation

### .NET / ASP.NET Core

- Use `IHostedService` or Hangfire for background notification workers
- `IEmailSender` interface for provider abstraction
- FluentEmail or MailKit for SMTP; provider SDKs for SendGrid/Postmark
- SignalR for real-time in-app notification delivery
- EF Core for notification storage; Redis for unread counts and rate limiting

### Node.js / NestJS

- BullMQ for notification job queues with Redis
- `@nestjs/bullmq` for NestJS integration (`@nestjs/bull` wraps the legacy `bull` package which is in maintenance mode — use `@nestjs/bullmq` instead)
- Nodemailer or provider SDKs (SendGrid, Postmark, Resend)
- Socket.IO or SSE for real-time in-app delivery
- Handlebars or MJML for email templates

### Frontend

- Notification bell component with unread badge (count from API or WebSocket)
- Notification dropdown/panel with infinite scroll or paginated list
- Toast/snackbar system for real-time alerts
- Mark as read on click/view (IntersectionObserver for auto-mark)
- Preference center as a settings page with matrix toggle UI

## Anti-Patterns

- No suppression list — hard bounces get you blacklisted; sending to opted-out users is a compliance violation
- Ignoring SPF/DKIM/DMARC — emails land in spam regardless of content quality
- Mixing transactional and marketing on the same IP/domain — marketing reputation degrades transactional delivery
- Single notification table without archival — grows unbounded, queries slow over time
- Sending digests at midnight server time instead of user's local timezone
- No deduplication — rapid events trigger duplicate notifications

## Output Format

After implementing notifications, report:

```
Notification Implementation
============================
Channels:    email, push, in-app (list implemented channels)
Provider:    SendGrid / Postmark / FCM / custom (list providers)
Queue:       Bull / Hangfire / custom (background processing)
Real-time:   WebSocket / SSE / SignalR / polling

Templates:
  - welcome-email (HTML + plain text)
  - password-reset (HTML + plain text)
  - daily-digest (HTML + plain text)

Deliverability:
  - SPF: configured / needs DNS record
  - DKIM: configured / needs DNS record
  - DMARC: configured / needs DNS record

Preference Center:
  - Categories: marketing, transactional, security, activity
  - Channels: email, push, in-app
  - Frequency: instant, daily, weekly
  - Unsubscribe: one-click header + landing page

Rate Limiting:
  - Per-recipient: 1/type/hour email, 5/hour push
  - Per-sender: within provider limits

Bounce Handling:
  - Hard bounce: suppress immediately
  - Soft bounce: retry 3x then suppress
  - Complaint: suppress + alert

Files Changed:
  A  src/notifications/notification.service.ts
  A  src/notifications/email.worker.ts
  A  src/templates/welcome.mjml
  M  src/config/env.ts (added email provider config)
```

## Done Criteria

- Bounce handling suppresses invalid addresses automatically
- SPF/DKIM/DMARC configured or documented for setup
- Push notification tokens are managed with cleanup for stale devices
