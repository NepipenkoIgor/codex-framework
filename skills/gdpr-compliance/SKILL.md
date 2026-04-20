---
name: gdpr-compliance
description: GDPR/privacy compliance for SaaS — subject access requests (SAR), right to erasure, data export, consent logging, cookie consent, data retention policies. Not legal advice — engineering patterns only.
metadata:
  version: 1.0
  domain: backend
  keywords: [GDPR, privacy, SAR, subject access request, right to erasure, right to be forgotten, data export, consent, cookie consent, data retention, PII, CCPA, data deletion, privacy request]
---

# GDPR Compliance

> Engineering patterns only. Always have legal review your privacy policy and DPA.

## Subject Access Request (SAR) — Data Export

```typescript
// Export all PII for a user across all tables
async function handleSAR(userId: string, requestedBy: string) {
  await auditLog({ action: 'privacy.sar_requested', actorId: requestedBy, meta: { subjectId: userId } });

  const data = await collectUserData(userId);
  const exportFile = await generateExportFile(data);

  // Deliver securely — password-protected zip or signed URL (short TTL)
  const signedUrl = await storage.createSignedUrl(exportFile, { expiresIn: '7d' });
  await email.send({ to: data.user.email, template: 'sar-ready', data: { downloadUrl: signedUrl } });

  await auditLog({ action: 'privacy.sar_delivered', actorId: requestedBy, meta: { subjectId: userId } });
}

async function collectUserData(userId: string) {
  // Collect from every table that stores PII — keep this list current
  const [user, profile, orders, events, auditLogs, sessions] = await Promise.all([
    db.users.findById(userId),
    db.profiles.findOne({ userId }),
    db.orders.findMany({ userId }),
    db.analyticsEvents.findMany({ userId }, { limit: 10000 }),
    db.auditLogs.findMany({ actorId: userId }),
    db.sessions.findMany({ userId }),
  ]);

  return { user, profile, orders, events, auditLogs, sessions };
}

async function generateExportFile(data: UserData): Promise<string> {
  const json = JSON.stringify(data, null, 2);
  const path = `exports/sar-${data.user.id}-${Date.now()}.json`;
  await storage.upload(path, Buffer.from(json), { contentType: 'application/json' });
  return path;
}
```

## Right to Erasure (Right to be Forgotten)

```typescript
async function handleErasureRequest(userId: string, requestedBy: string) {
  const user = await db.users.findById(userId);

  // Pre-erasure checks
  const openInvoices = await db.invoices.findMany({ userId, status: 'open' });
  if (openInvoices.length > 0) {
    throw new ConflictError('Cannot erase account with outstanding invoices — resolve billing first');
  }

  await auditLog({ action: 'privacy.erasure_requested', actorId: requestedBy, meta: { subjectId: userId } });

  await db.$transaction(async (tx) => {
    // Anonymize rather than delete where records must be retained (billing, legal)
    await tx.orders.updateMany({ userId }, {
      // Keep order for accounting — remove PII
      customerName: '[deleted]',
      customerEmail: '[deleted]',
      shippingAddress: null,
    });

    // Hard delete where no retention requirement
    await tx.sessions.deleteMany({ userId });
    await tx.analyticsEvents.deleteMany({ userId });
    await tx.profiles.deleteMany({ userId });
    await tx.verificationTokens.deleteMany({ userId });
    await tx.magicLinks.deleteMany({ userId });

    // Anonymize the user record itself — preserve ID for FK integrity
    await tx.users.update({ id: userId }, {
      email: `deleted-${userId}@erased.invalid`,
      name: '[deleted]',
      passwordHash: null,
      emailVerifiedAt: null,
      deletedAt: new Date(),
    });
  });

  // Cancel active subscriptions
  if (user.stripeCustomerId) {
    const subscriptions = await stripe.subscriptions.list({ customer: user.stripeCustomerId });
    await Promise.all(subscriptions.data.map(sub =>
      stripe.subscriptions.cancel(sub.id)
    ));
  }

  // Remove from external services
  await Promise.allSettled([
    analytics.deleteUser(userId),
    emailProvider.unsubscribe(user.email),
    redis.del(`user:${userId}:*`), // clear all user cache keys
  ]);

  await auditLog({ action: 'privacy.erasure_completed', actorId: requestedBy, meta: { subjectId: userId } });
}
```

## Consent Logging

```typescript
// Record every consent event with full context
interface ConsentRecord {
  userId: string;
  consentType: 'marketing' | 'analytics' | 'functional' | 'terms' | 'privacy_policy';
  granted: boolean;
  version: string;      // policy version user consented to
  method: 'checkbox' | 'api' | 'import';
  ipAddress: string;
  userAgent: string;
  timestamp: Date;
}

async function recordConsent(record: ConsentRecord) {
  // Append-only — never update or delete consent records
  await db.consentLogs.create(record);
}

async function getCurrentConsents(userId: string) {
  // Latest consent per type
  return db.consentLogs.findMany({
    where: { userId },
    orderBy: { timestamp: 'desc' },
    distinct: ['consentType'],
  });
}
```

## Cookie Consent

```typescript
// Server-side consent check before setting non-essential cookies
function applyConsentPolicy(res: Response, consents: ConsentRecord[]) {
  const analyticsConsented = consents.some(c => c.consentType === 'analytics' && c.granted);
  const marketingConsented = consents.some(c => c.consentType === 'marketing' && c.granted);

  if (!analyticsConsented) {
    // Remove/don't set analytics cookies
    res.clearCookie('_ga');
    res.clearCookie('_gid');
    res.clearCookie('ph_*'); // PostHog
  }

  if (!marketingConsented) {
    res.clearCookie('_fbp');
    res.clearCookie('_gcl_au');
  }
}

// Frontend: banner shown until all consent types are explicitly set
// Never pre-check "marketing" or "analytics" boxes — explicit opt-in required
```

## Data Retention Policy

```typescript
// Run as a scheduled job (weekly or monthly)
async function enforceRetentionPolicy() {
  const now = new Date();

  // Sessions: 30 days
  await db.sessions.deleteMany({ updatedAt: { lt: subDays(now, 30) } });

  // Analytics raw events: 13 months (one year + comparison window)
  await db.analyticsEvents.deleteMany({ createdAt: { lt: subMonths(now, 13) } });

  // Audit logs: 7 years (compliance requirement — do NOT delete)
  // Invoices / financial records: 7 years (do NOT delete)

  // Verification tokens: 48 hours after expiry
  await db.verificationTokens.deleteMany({ expiresAt: { lt: subDays(now, 2) } });

  // Erasure requests: anonymize request record after 30 days (keep for compliance proof)
  await db.erasureRequests.updateMany(
    { completedAt: { lt: subDays(now, 30) }, anonymizedAt: null },
    { requestorEmail: '[anonymized]', anonymizedAt: now }
  );

  await auditLog({ action: 'privacy.retention_policy_run', meta: { timestamp: now } });
}
```

## Privacy Request Workflow

```typescript
// Centralized request intake — tracks SLA compliance
async function submitPrivacyRequest(type: 'access' | 'erasure' | 'portability', userId: string) {
  const request = await db.privacyRequests.create({
    type,
    subjectId: userId,
    status: 'pending',
    dueAt: addDays(new Date(), 30), // GDPR: 30-day response SLA
  });

  await notifyDPO({ request }); // Data Protection Officer notification
  return request;
}
```

## Rules

- Audit logs and financial records are EXEMPT from erasure — retain per legal requirements
- Anonymize (replace PII) rather than delete for records needed for accounting integrity
- Consent records are append-only — never mutate or delete
- SAR exports delivered via signed URL (7-day TTL) — never emailed as attachment
- Erasure is irreversible — require explicit confirmation from user before proceeding
- `timingSafeEqual` for any token comparison in privacy flows
- Never log PII in application logs — use userId only, never email or name in logs
- Data retention runs as scheduled job — not on-demand (prevents accidental cascades)
- Pre-erasure check: block if open invoices, active subscription mid-cycle

## Done Criteria

- [ ] SAR export collects PII from ALL tables — no gaps (verify with schema audit)
- [ ] Erasure anonymizes billing records rather than deleting (retains financial integrity)
- [ ] Erasure cancels Stripe subscription and removes from external services
- [ ] Consent records are append-only — no update/delete allowed on consent_logs table
- [ ] Data retention job runs on schedule — not triggered by user actions
- [ ] Privacy request SLA tracking in place (30-day GDPR deadline)
- [ ] All privacy actions produce audit log entries
