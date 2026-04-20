---
name: saas-onboarding
description: SaaS user onboarding — email verification, magic links, OTP, verification gate middleware, resend rate limiting, welcome flow. Pairs with auth-security for session handling.
metadata:
  version: 1.0
  domain: backend
  keywords: [onboarding, email verification, magic link, OTP, one-time password, verify email, verification token, resend, signup flow, welcome email, account activation, verification gate]
---

# SaaS Onboarding

## Email Verification Token

```typescript
// Generate signed, expiring verification token
import { createHmac, randomBytes } from 'crypto';

function generateVerificationToken(userId: string): { token: string; expiresAt: Date } {
  const raw = randomBytes(32).toString('hex');
  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24h
  // Sign to prevent enumeration — HMAC ties token to userId
  const signature = createHmac('sha256', process.env.EMAIL_TOKEN_SECRET!)
    .update(`${userId}:${raw}:${expiresAt.toISOString()}`)
    .digest('hex');
  const token = `${raw}.${signature}`;
  return { token, expiresAt };
}

async function sendVerificationEmail(userId: string, email: string) {
  // Rate limit: max 3 resends per hour per user
  const recentCount = await redis.incr(`verify:resend:${userId}`);
  if (recentCount === 1) await redis.expire(`verify:resend:${userId}`, 3600);
  if (recentCount > 3) throw new RateLimitError('Too many verification emails. Try again in 1 hour.');

  const { token, expiresAt } = generateVerificationToken(userId);
  await db.verificationTokens.upsert(
    { userId },
    { token: hashToken(token), expiresAt, usedAt: null }
  );

  const verifyUrl = `${process.env.APP_URL}/verify-email?token=${token}&uid=${userId}`;
  await email.send({ to: email, template: 'verify-email', data: { verifyUrl, expiresIn: '24 hours' } });
}

function hashToken(token: string): string {
  return createHmac('sha256', process.env.EMAIL_TOKEN_SECRET!).update(token).digest('hex');
}
```

## Verify Email Handler

```typescript
async function verifyEmail(token: string, userId: string) {
  const record = await db.verificationTokens.findOne({ userId });
  if (!record) throw new InvalidTokenError('Verification token not found');
  if (record.usedAt) throw new ConflictError('Email already verified');
  if (record.expiresAt < new Date()) throw new InvalidTokenError('Verification link expired — request a new one');

  const expectedHash = hashToken(token);
  if (!timingSafeEqual(Buffer.from(record.token), Buffer.from(expectedHash))) {
    throw new InvalidTokenError('Invalid verification token');
  }

  await db.$transaction([
    db.users.update({ id: userId }, { emailVerifiedAt: new Date() }),
    db.verificationTokens.update({ userId }, { usedAt: new Date() }),
  ]);

  await redis.del(`verify:resend:${userId}`); // reset rate limit on success
  await auditLog({ action: 'user.email_verified', actorId: userId });
}
```

## Magic Link (Passwordless Login)

```typescript
async function sendMagicLink(email: string) {
  const user = await db.users.findOne({ email });
  if (!user) {
    // Don't reveal whether email exists — same response either way
    return;
  }

  // Rate limit: max 5 magic links per hour per email
  const key = `magic:${email.toLowerCase()}`;
  const count = await redis.incr(key);
  if (count === 1) await redis.expire(key, 3600);
  if (count > 5) throw new RateLimitError('Too many login attempts. Try again in 1 hour.');

  const token = randomBytes(32).toString('hex');
  const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes

  await db.magicLinks.create({
    userId: user.id,
    tokenHash: hashToken(token),
    expiresAt,
    usedAt: null,
  });

  const loginUrl = `${process.env.APP_URL}/auth/magic?token=${token}`;
  await email.send({ to: email, template: 'magic-link', data: { loginUrl, expiresIn: '15 minutes' } });
}

async function consumeMagicLink(token: string): Promise<User> {
  const tokenHash = hashToken(token);
  const link = await db.magicLinks.findOne({ tokenHash });

  if (!link) throw new InvalidTokenError('Invalid or expired magic link');
  if (link.usedAt) throw new ConflictError('This link has already been used');
  if (link.expiresAt < new Date()) throw new InvalidTokenError('Magic link expired');

  await db.$transaction([
    db.magicLinks.update({ id: link.id }, { usedAt: new Date() }),
    db.users.update({ id: link.userId }, { emailVerifiedAt: new Date() }),
  ]);

  return db.users.findById(link.userId);
}
```

## OTP (6-digit, Time-based)

```typescript
import { totp } from 'otplib';

async function generateOtp(userId: string): Promise<string> {
  const secret = await getUserOtpSecret(userId); // stored per user, not per request
  return totp.generate(secret);
}

async function verifyOtp(userId: string, code: string): Promise<boolean> {
  const secret = await getUserOtpSecret(userId);
  return totp.check(code, secret); // handles ±1 window by default
}

// For email OTP (non-TOTP): generate 6-digit code, store hashed, 10-min TTL
async function sendEmailOtp(userId: string, email: string) {
  const code = Math.floor(100000 + Math.random() * 900000).toString();
  await redis.setex(`otp:${userId}`, 600, hashToken(code)); // 10 min TTL
  await email.send({ to: email, template: 'otp-code', data: { code } });
}

async function verifyEmailOtp(userId: string, code: string) {
  const stored = await redis.get(`otp:${userId}`);
  if (!stored) throw new InvalidTokenError('OTP expired or not found');
  if (!timingSafeEqual(Buffer.from(stored), Buffer.from(hashToken(code)))) {
    throw new InvalidTokenError('Invalid code');
  }
  await redis.del(`otp:${userId}`);
}
```

## Verification Gate Middleware

```typescript
// Blocks unverified users from accessing protected routes
function requireVerifiedEmail(req: Request, res: Response, next: NextFunction) {
  if (!req.user.emailVerifiedAt) {
    return res.status(403).json({
      error: 'EMAIL_NOT_VERIFIED',
      message: 'Please verify your email before continuing.',
      resendUrl: '/api/auth/resend-verification',
    });
  }
  next();
}

// Apply to all routes except: login, signup, verify-email, resend, magic-link
router.use('/api', requireAuth, requireVerifiedEmail);
router.post('/api/auth/resend-verification', requireAuth, resendVerificationHandler);
```

## Welcome Flow

```typescript
// Triggered after first email verification
async function onEmailVerified(userId: string) {
  const user = await db.users.findById(userId);

  // Send welcome email only once
  if (!user.welcomeSentAt) {
    await email.send({ to: user.email, template: 'welcome', data: { user } });
    await db.users.update({ id: userId }, { welcomeSentAt: new Date() });
  }

  // Track activation event
  await analytics.track({ userId, event: 'Email Verified', properties: { method: 'link' } });

  // Trigger onboarding checklist if applicable
  await onboarding.initChecklist(userId);
}
```

## Rules

- Always hash tokens before storing — never store raw token in DB
- Use `timingSafeEqual` for all token comparisons — prevents timing attacks
- Don't reveal whether an email exists during magic link / OTP flows
- Rate limit resend endpoints: email verification (3/hour), magic link (5/hour per email), OTP (5/10min)
- Magic links: 15-minute expiry, single-use
- Email verification links: 24-hour expiry, single-use
- Send verification email on signup — but don't block app access immediately (grace period is UX decision)
- Verification gate middleware must have an explicit bypass list (verify, resend, magic routes)

## Done Criteria

- [ ] Verification tokens are HMAC-signed and hashed before storage — raw token never in DB
- [ ] Resend rate limiting enforced with Redis — not just application-level checks
- [ ] Magic link: 15-min expiry, single-use, email enumeration-safe (same response if user not found)
- [ ] `timingSafeEqual` used for all token comparison — no string equality
- [ ] Verification gate middleware has explicit bypass list and returns structured 403 with resend URL
- [ ] Welcome email sent exactly once (idempotent check on welcomeSentAt)
- [ ] All verification events produce audit log entries
