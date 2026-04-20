---
name: auth-security
description: Implement authentication and authorization including OAuth2 with PKCE, JWT with refresh rotation, session management, RBAC, ABAC, MFA (TOTP/WebAuthn), passkeys, and API key management
metadata:
  version: 2.0
  argument-hint: "auth method (OAuth2/JWT/passkeys/MFA), target service or endpoint, RBAC/ABAC requirements"
---

Implement $ARGUMENTS with secure authentication and authorization patterns.

## Tool Integration

- **Type diagnostics**: run available diagnostics tools after every code change to catch type errors before completion
- docs lookup tools: fetch current library docs before implementing — never rely on training data alone

## Documentation

> Use available docs lookup tools or official docs when you encounter unknown API syntax, current library versions, or framework-specific configuration. Do not rely on training data for library docs — fetch current docs on demand.

## Authentication Patterns

### Token-based (JWT)

- Short-lived access tokens (15–30 min) + long-lived refresh tokens (7–30 days)
- Store refresh tokens server-side (database) with rotation on use
- Access tokens in memory only (never localStorage) — use httpOnly cookies or Authorization header
- Include minimal claims: sub, roles, exp, iat, jti
- Validate signature, expiration, issuer, and audience on every request
- Use asymmetric signing (RS256/ES256) for distributed systems; HS256 only for single-service

**Refresh rotation with reuse detection**: issue new access + refresh token on each refresh, invalidate old token, store family chain. On invalidated token reuse — revoke entire family, force re-login, log security event.

### Session-based

- Server-side session store (Redis, DB) — never in-memory for production
- Secure cookie: httpOnly, secure, sameSite=strict/lax, path=/
- Regenerate session ID after login (prevent session fixation). Idle timeout 30 min, absolute 24h
- Bind session to user agent + IP range for hijacking detection. Store only user ID and roles

### OAuth2 / OpenID Connect

- Authorization Code + PKCE for SPAs, mobile, server apps. Never Implicit flow (deprecated)
- Validate state (CSRF) and nonce (replay). BFF pattern for SPAs — server handles tokens, sends httpOnly cookie

```
const codeVerifier = crypto.randomBytes(32).toString('base64url');
const codeChallenge = crypto.createHash('sha256').update(codeVerifier).digest('base64url');
```

BFF: server handles OAuth2 flow + stores tokens; frontend gets httpOnly session cookie; BFF proxies API calls with access token.

### API Key Authentication

- 256-bit random keys, store hashed (SHA-256/bcrypt), show only at creation
- Prefix: `sk_live_`, `sk_test_`; display prefix + last 4 chars
- Metadata: created_at, last_used, scopes, expiry, label; rate limit per key not IP

## Authorization Patterns

### RBAC

- Roles = collections of permissions. Check permissions, not roles: `hasPermission('orders:write')` not `isAdmin()`
- Support role hierarchy. Store roles in DB; cache with event-driven invalidation

.NET:
```csharp
services.AddAuthorizationBuilder()
    .AddPolicy("CanManageOrders", policy =>
        policy.Requirements.Add(new PermissionRequirement("orders:manage")));
// PermissionHandler: check userPermissions.Contains(requirement.Permission)
```

NestJS:
```typescript
@UseGuards(AuthGuard, PermissionGuard)
@RequirePermissions('orders:write')
@Post('/orders')
// PermissionGuard: reflector.get permissions, check every(p => userPermissions.includes(p))
```

### ABAC

Use when RBAC is insufficient (multi-tenant, resource ownership, time/geo). Policy: subject + resource + action + environment. Example: `ALLOW if subject.role == "manager" AND resource.department == subject.department`. Combine with RBAC for layered access.

### Row-Level Security

Filter queries by tenant/owner at the data access layer. Enforce at DB level (PostgreSQL RLS). Inject tenant context via middleware. Include tenant_id in all tenant-scoped indexes.

## MFA

**TOTP**: 160-bit secret, Base32 encoded; SHA-1, 6 digits, 30s interval (RFC 6238). Accept ±1 interval for clock drift. Store encrypted secret. Provide 8 hashed single-use recovery codes.

**WebAuthn/Passkeys**: store credential public key, ID, sign count. Verify sign count increments. `user_verification: preferred` (2FA), `required` (passwordless). Support cross-device auth.

**SMS/Email OTP**: 6-digit, 5–10 min validity, single-use, stored hashed. Max 3 active codes/user, 5 sends/hour. SMS = weakest factor (SIM swap risk) — fallback only.

**Enrollment**: generate secret/challenge → user verifies → store credential, mark active → display recovery codes (one-time).

## Token Storage

| Storage | Security | Use for |
|---------|----------|---------|
| localStorage/sessionStorage | XSS-vulnerable | AVOID for tokens |
| httpOnly cookie (Secure, SameSite, explicit Domain) | Immune to XSS, CSRF risk | Refresh tokens |
| In-memory (context/signal/ref) | Not XSS-accessible, lost on refresh | Access tokens + silent refresh |

XSS: CSP headers, output encoding, httpOnly cookies, SRI. CSRF: SameSite=Strict (strongest), SameSite=Lax (safe default), or double-submit cookie.

## Rate Limiting for Auth Endpoints

| Endpoint | Rate Limit | Lockout |
|----------|-----------|---------|
| POST /auth/login | 5/min per account, 20/min per IP | Lock 15 min after 10 failures |
| POST /auth/register | 3/min per IP | Block IP 30 min after 10 |
| POST /auth/forgot-password | 3/min per email | Silently throttle |
| POST /auth/verify-mfa | 3/min per session | Invalidate after 5 failures |
| POST /auth/refresh | 10/min per user | Revoke all after 30 failures |

Sliding window or token bucket, Redis with TTL, return 429 + Retry-After. Never reveal account existence through rate limit behavior.

## Security Non-Negotiables

- Passwords: bcrypt (cost 12+) or Argon2id
- Rate limit + account lockout with exponential backoff
- Log all auth events
- Constant-time comparison for tokens (`crypto.timingSafeEqual`)
- Sanitize errors (never reveal email existence), CSRF on all mutations
- Force password change on compromise, invalidate all sessions on password change

## Framework-Specific Implementation

### .NET 8+

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o => {
        o.TokenValidationParameters = new TokenValidationParameters {
            ValidateIssuer = true, ValidateAudience = true, ValidateLifetime = true,
            ValidateIssuerSigningKey = true, ClockSkew = TimeSpan.FromSeconds(30),
            ValidIssuer = config["Jwt:Issuer"], ValidAudience = config["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(config["Jwt:Key"]!))
        };
    });
// HS256 requires a minimum 256-bit (32-byte) key. Validate at startup:
//   var key = config["Jwt:Key"] ?? throw new InvalidOperationException("Jwt:Key not set");
//   if (Encoding.UTF8.GetByteCount(key) < 32) throw new InvalidOperationException("Jwt:Key must be at least 32 bytes");
// For distributed systems, prefer RS256 with RsaSecurityKey to avoid sharing the signing secret.

builder.Services.AddAuthorizationBuilder()
    .AddPolicy("CanManageOrders", p => p.Requirements.Add(new PermissionRequirement("orders:manage")))
    .SetFallbackPolicy(new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build());

app.UseAuthentication();
app.UseAuthorization();
var api = app.MapGroup("/api").RequireAuthorization();
```

### Node.js / NestJS

Custom NestJS guards with `@nestjs/jwt`, bcrypt or argon2, `@nestjs/throttler` with Redis store. Passport.js is optional/legacy for JWT flows — prefer custom guards for new NestJS projects.

```typescript
@Injectable()
export class JwtAuthGuard implements CanActivate {
  async canActivate(context: ExecutionContext): Promise<boolean> {
    const token = this.extractToken(context.switchToHttp().getRequest());
    try {
      context.switchToHttp().getRequest().user = await this.jwtService.verifyAsync(token, {
        secret: this.config.get('JWT_SECRET'), algorithms: ['HS256'],
      });
      return true;
    } catch { throw new UnauthorizedException(); }
  }
}
// Note: HS256 shares the signing secret across all services — acceptable for single-service deployments.
// For distributed systems, use RS256 with publicKey from environment:
//   this.jwtService.verifyAsync(token, { publicKey: this.config.get('JWT_PUBLIC_KEY'), algorithms: ['RS256'] })
```

### Next.js App Router — Auth.js (NextAuth v5)

```typescript
// auth.ts
export const { handlers, signIn, signOut, auth } = NextAuth({
  providers: [GitHub, Credentials({ async authorize(credentials) { return verifyCredentials(credentials) ?? null; } })],
  callbacks: {
    authorized({ auth, request: { nextUrl } }) {
      const isProtected = nextUrl.pathname.startsWith('/dashboard');
      if (isProtected && !auth?.user) return Response.redirect(new URL('/login', nextUrl));
      return true;
    },
  },
});
// middleware.ts: export { auth as middleware }; export const config = { matcher: [...] };
// Server Component/Action: const session = await auth(); if (!session) redirect('/login');
```

Use `unstable_update` to refresh session data after profile/role changes without re-login.

### Blazor

```razor
@page "/admin"
@attribute [Authorize(Roles = "Admin")]
<AuthorizeView>
    <Authorized><p>Welcome, @context.User.Identity?.Name</p></Authorized>
    <NotAuthorized><RedirectToLogin /></NotAuthorized>
</AuthorizeView>
```

Blazor Server: uses `CascadingAuthenticationState` with server-side session — no token storage needed. Blazor WASM: store tokens client-side, use `AuthorizationMessageHandler`. Register `AddCascadingAuthenticationState()` (.NET 8+ required; for .NET 6/7, use `<CascadingAuthenticationState>` wrapper component instead).

### Angular

```typescript
@Injectable({ providedIn: 'root' })
export class AuthService {
  readonly accessToken = signal<string | null>(null);
  readonly user = signal<User | null>(null);
  readonly isAuthenticated = computed(() => !!this.accessToken());
  readonly roles = computed(() => this.user()?.roles ?? []);
}

export const authGuard: CanActivateFn = (route, state) => {
  const auth = inject(AuthService);
  return auth.isAuthenticated() ? true : inject(Router).createUrlTree(['/login'], { queryParams: { returnUrl: state.url } });
};

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const token = inject(AuthService).accessToken();
  const authReq = token ? req.clone({ setHeaders: { Authorization: `Bearer ${token}` } }) : req;
  return next(authReq).pipe(
    catchError((err: HttpErrorResponse) => {
      if (err.status === 401) { inject(AuthService).accessToken.set(null); inject(Router).navigateByUrl('/login'); }
      return throwError(() => err);
    })
  );
};
```

Use `APP_INITIALIZER` to hydrate auth state from refresh token cookie on bootstrap. Use `canMatch` guard to prevent downloading lazy modules for unauthorized users.

### Vue / Nuxt

```typescript
// Nuxt — nuxt-auth-utils for cookie-based sessions
export default defineEventHandler(async (event) => {
  const user = await verifyCredentials(email, password);
  await setUserSession(event, { user });
});
// Protect pages: definePageMeta({ middleware: 'auth' })
// middleware/auth.ts: const { loggedIn } = useUserSession(); if (!loggedIn.value) return navigateTo('/login')
```

Vue (non-Nuxt): Pinia auth store with `ref<string | null>(null)` for access token (never localStorage). Axios interceptors for token attachment + refresh on 401.

### SvelteKit

```typescript
// hooks.server.ts: validate session cookie, set event.locals.user
// +page.server.ts: if (!locals.user) redirect(302, '/login');
// actions: cookies.set('session', sessionId, { httpOnly: true, secure: true, sameSite: 'lax' });
```

Form actions include automatic CSRF protection (SvelteKit rejects POST from foreign origins). Auth state in `event.locals` server-side only.

### Frontend Principles (React / Angular / Vue)

- Access token in memory, refresh token in httpOnly cookie (BFF preferred)
- Silent refresh timer: `token_expiry - 60s`
- Redirect to login on 401, clear all auth state on logout
- Hydrate auth state on page load via `/auth/refresh` or `/auth/me`

## Enterprise SSO

### SAML 2.0

SP-initiated: user → SP generates AuthnRequest → IdP → signed SAML Response → SP validates → session.

Node.js: `node-saml` or `passport-saml` v4+ (`saml2-js` is unmaintained). .NET: `Sustainsys.Saml2` with `MetadataLocation` + `LoadMetadata = true` for auto cert rotation.

**Certificate management**: support multiple active certs during rotation. Set reminders 30 days before expiry. Publish SP metadata at `/saml/metadata` for metadata exchange.

### OIDC Discovery

Fetch `/.well-known/openid-configuration` for endpoints. Use `jwks-rsa` with 24h cache + refresh-on-miss for JWKS rotation. Always validate `iss` claim matches expected issuer exactly.

### Group/Role Mapping

Map IdP groups to app roles on every login (not just first). Handle group removal by syncing and removing revoked roles. Audit role changes. Resolve nested groups (LDAP `LDAP_MATCHING_RULE_IN_CHAIN`, Entra ID transitive memberOf). Cache with 15 min TTL.

JIT provisioning: create user on first SSO login, assign default roles from group mapping.

### Federated Logout

SAML SLO: SP-initiated LogoutRequest → IdP notifies all SPs. OIDC: redirect to `end_session_endpoint` with `id_token_hint`. Back-channel logout: IdP → SP server endpoint directly (more reliable). For microservices: short TTL (5 min) or shared Redis deny list for revocation propagation.

## Anti-Patterns

- Checking roles instead of permissions (`if (user.role === 'admin')`) -- breaks on role proliferation
- Symmetric JWT secret shared across services -- one compromised service decodes all tokens
- Refresh tokens without rotation and reuse detection -- stolen tokens grant indefinite access
- TOTP without rate-limited verification -- brute-forceable within the 30-second window
- CSRF token not bound to session -- tokens become transferable across sessions

## Workflow

1. Identify requirements (password, OAuth2, API keys, MFA)
2. Choose token strategy (JWT + refresh rotation, session, BFF)
3. Implement: register, login, refresh, logout endpoints
4. Add authorization (roles, permissions, policies, RLS), rate limiting, MFA, event logging
5. Test attack vectors: token theft, CSRF, session fixation, brute force

## Structured Output Contract
- **Status**: `done` | `partial` | `blocked`
- **Changed**: `[file.ext: +lines/-lines, ...]` — list every modified file
- **Notes**: blockers or non-obvious decisions only — omit if none

Do NOT return prose summaries or recaps.
