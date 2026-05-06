---
name: supabase-patterns
description: Implement Supabase features including RLS policies, edge functions, auth integration, realtime subscriptions, storage buckets, database migrations via Supabase CLI, and PostgREST API patterns
metadata:
  version: 1.4
  argument-hint: "feature (auth/realtime/functions/storage/RLS), data model scope, framework integration"
---

Implement $ARGUMENTS using Supabase as the backend platform.

## Documentation

> Use available docs lookup tools or official docs when you encounter unknown API syntax, current library versions, or framework-specific configuration. Do not rely on training data for library docs — fetch current docs on demand.

## Tool Integration

When structured Supabase tools are available, use them for direct platform operations:
- Query and inspect database tables, schemas, and relationships
- Verify RLS policies by testing queries as different roles
- Check auth configuration and user management settings
- Manage storage buckets and access policies
- Validate edge function deployment status
- Use structured tools for real-time feedback during migration development — verify schema changes took effect

## Project Detection

Detect from: `supabase/` dir with `config.toml`, `@supabase/supabase-js` in package.json, `SUPABASE_URL` env vars, `supabase/migrations/` dir.

## Database and Schema

### Migration Workflow

- Create via `supabase migration new <name>` -- never edit existing migrations
- Apply locally: `supabase db reset` or `supabase migration up`; remote: `supabase db push`
- Regenerate types: `supabase gen types typescript --local > src/types/database.ts`

### Schema Conventions

- UUID PKs: `id uuid default gen_random_uuid() primary key`
- Timestamps: `created_at timestamptz default now() not null`, `updated_at` with moddatetime trigger
- NOT NULL by default; FK with explicit ON DELETE; check constraints for enums

```sql
create table public.projects (
  id uuid default gen_random_uuid() primary key,
  org_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 200),
  status text not null default 'active' check (status in ('active', 'archived', 'deleted')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null
);
create index idx_projects_org_id on public.projects(org_id);
```

## Row-Level Security (RLS)

### Non-Negotiables

- Enable RLS on EVERY table: `alter table public.X enable row level security;`
- Deny-by-default; never bypass in client code; service_role only server-side
- Include tenant/org ID in every policy; test that user A cannot see user B's data

### Policy Patterns

Owner-based:
```sql
create policy "Users view own" on public.projects for select to authenticated
  using (created_by = auth.uid());
create policy "Users create own" on public.projects for insert to authenticated
  with check (created_by = auth.uid());
```

Org-scoped via membership:
```sql
create policy "Org members view" on public.projects for select to authenticated
  using (org_id in (select org_id from public.org_members where user_id = auth.uid()));
```

Role-based (admin-only delete):
```sql
create policy "Admins delete" on public.projects for delete to authenticated
  using (org_id in (select org_id from public.org_members where user_id = auth.uid() and role = 'admin'));
```

### RLS Performance

- Keep policies simple; use `security definer` functions for complex auth logic
- Index columns in policy WHERE clauses; test with `explain analyze`

## Auth Integration (Next.js)

```typescript
// lib/supabase/server.ts -- App Router
import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

export async function createClient() {
  const cookieStore = await cookies();
  return createServerClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    cookies: {
      getAll() { return cookieStore.getAll(); },
      setAll(c) { c.forEach(({ name, value, options }) => cookieStore.set(name, value, options)); },
    },
  });
}

// lib/supabase/client.ts -- browser
import { createBrowserClient } from '@supabase/ssr';
export function createClient() {
  return createBrowserClient(SUPABASE_URL, SUPABASE_ANON_KEY);
}
```

### Proxy / Middleware -- protect routes, refresh session

```typescript
export async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request });
  const supabase = createServerClient(URL, KEY, { cookies: { /* getAll/setAll on request+response */ } });
  const { data: { user } } = await supabase.auth.getUser();
  if (!user && request.nextUrl.pathname.startsWith('/dashboard'))
    return NextResponse.redirect(new URL('/login', request.url));
  return response;
}
```

Use `proxy.ts` for Next.js 16 request interception. Keep `middleware.ts` only for explicit Edge runtime cases or projects not yet migrated.

### Auth Rules

- Use `getUser()` (server-validated) over `getSession()` (client JWT) for auth decisions
- Handle `onAuthStateChange`; store profile data in `public.profiles` linked to `auth.users(id)`
- Auto-create profile via trigger on `auth.users` insert

## Realtime Subscriptions

```typescript
const channel = supabase
  .channel('projects-changes')
  .on('postgres_changes',
    { event: '*', schema: 'public', table: 'projects', filter: `org_id=eq.${orgId}` },
    (payload) => { /* INSERT/UPDATE/DELETE handlers */ }
  ).subscribe();
return () => { supabase.removeChannel(channel); }; // cleanup on unmount
```

- Always filter by tenant scope; RLS applies to realtime
- Use `broadcast` for ephemeral events, `presence` for online status
- Unsubscribe on unmount

### Presence and Broadcast

```typescript
channel.on('presence', { event: 'sync' }, () => { setOnlineUsers(Object.values(channel.presenceState()).flat()); })
  .subscribe(async (status) => { if (status === 'SUBSCRIBED') await channel.track({ user_id: userId }); });
channel.send({ type: 'broadcast', event: 'cursor-move', payload: { x, y, userId } });
```

## Edge Functions

Structure: `supabase/functions/{name}/index.ts` + `_shared/` for utilities.

```typescript
serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  const body = await req.json();
  if (!body.orderId) return new Response(JSON.stringify({ error: 'Invalid' }), { status: 400, headers: corsHeaders });

  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const { data, error } = await supabase.from('orders').update({ status: 'processed' }).eq('id', body.orderId).select().single();
  if (error) throw error;
  return new Response(JSON.stringify(data), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
});
```

Rules: validate inputs; service_role only in edge functions; CORS headers for browser calls; deploy with `supabase functions deploy`.

## Storage

```sql
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 5242880, array['image/jpeg', 'image/png', 'image/webp']);

-- RLS: users upload/update own folder, public read
create policy "Upload own" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
```

```typescript
const { data } = await supabase.storage.from('avatars')
  .upload(`${userId}/avatar.${ext}`, file, { cacheControl: '3600', upsert: true });
const { data: { publicUrl } } = supabase.storage.from('avatars').getPublicUrl(filePath);
```

## Type-Safe Queries

```typescript
import type { Database } from '@/types/database';
const supabase = createClient<Database>(URL, KEY);

const { data } = await supabase.from('projects')
  .select('id, name, status, created_at')
  .eq('org_id', orgId).order('created_at', { ascending: false });
```

- Use `.select('col1, col2')` not `select('*')`; `.single()` for one row; `.maybeSingle()` for optional
- Paginate with `.range(from, to)`; use `.count('exact')` for totals
- Use `.rpc()` for complex atomic operations via database functions

## Framework-Specific Integration

### Next.js App Router
- `@supabase/ssr`: `createServerClient()` in Server Components and Route Handlers using `cookies()`
- Proxy: `proxy.ts` refreshing session with `supabase.auth.getUser()` on every request in Next.js 16; keep `middleware.ts` only for Edge runtime or pre-migration projects
- Server Action: create Supabase client per-request with cookie access for mutations
- Client Component: `createBrowserClient()` from `@supabase/ssr` for real-time and auth state
- Real-time in Client Component: `useEffect` + `supabase.channel().on('postgres_changes', ...).subscribe()`
- Type generation: `npx supabase gen types typescript --project-id $REF > database.types.ts`

### Nuxt 3
- `@nuxtjs/supabase` module: `useSupabaseClient()`, `useSupabaseUser()` auto-imported
- Server route: `serverSupabaseClient(event)` for server-side queries with RLS
- Middleware: `defineNuxtRouteMiddleware` checking `useSupabaseUser()` for protected routes
- Real-time: composable wrapping `useSupabaseClient().channel('room').on(...)` with `onUnmounted` cleanup
- SSR auth: module handles cookie-based session automatically

### Angular + Supabase
- `@supabase/supabase-js` client in injectable service initialized from environment config
- Signal-based auth: wrap `supabase.auth.onAuthStateChange()` callback updating `signal<User | null>(null)`
- RLS-aware queries in service returning `signal()` updated by subscription callbacks
- Real-time with `inject(DestroyRef)` cleanup: `destroyRef.onDestroy(() => channel.unsubscribe())`
- Auth guard: functional `CanActivateFn` checking `supabase.auth.getSession()` result
- Storage: `supabase.storage.from('avatars').upload(path, file)` in upload service

### SvelteKit + Supabase
- `@supabase/ssr`: `createServerClient()` in `hooks.server.ts` using `cookies.get/set/remove`
- `createBrowserClient()` in `+layout.ts` for client-side operations
- Auth: `+layout.server.ts` load function via `locals.supabase.auth.getSession()`
- Form actions: `+page.server.ts` with `locals.supabase.auth.signInWithPassword()` for login
- Real-time with runes: `$effect()` subscribing to channel, cleanup returned automatically
- RLS: cookie-based auth passed via `createServerClient` in server load functions

### Vue (non-Nuxt)
- Composable: `useSupabase()` returning typed client via `provide/inject` pattern
- Auth composable: `useSupabaseUser()` with `ref<User | null>()` + `onAuthStateChange` listener
- `provide(SUPABASE_KEY, client)` in app setup, `inject(SUPABASE_KEY)` in composables
- Real-time: `useSubscription(channel, table)` composable with `onUnmounted` cleanup

### Blazor (.NET 8+)
- `supabase-csharp` NuGet (`Supabase.Client`) for server-side auth and database operations
- `Supabase.Gotrue` for auth: `client.Auth.SignIn(email, password)` in minimal API endpoints
- Minimal API proxy: endpoints calling Supabase from server (never expose service_role key to client)
- JS interop for real-time: `supabase.channel('room').on('postgres_changes', ...)` via JS module
- `IHttpClientFactory` for direct PostgREST calls when C# client is insufficient
- Auth flow: Blazor form -> minimal API -> Supabase auth -> JWT cookie -> subsequent requests

## Anti-Patterns

- Using `service_role` key in client-side code — bypasses all RLS; only use server-side
- Using `getSession()` for auth decisions — returns a cached JWT without server validation; use `getUser()` instead
- Subscribing to realtime without filters — receives all table changes across all tenants, bypassing RLS scoping
- Not indexing columns used in RLS policy `USING` clauses — policies run on every row access and cause full scans

## Output Format

```
Feature:          [what was built]
Tables:           [new or modified]
RLS Policies:     [per table and operation]
Auth:             [integration approach]
Realtime/Storage/Edge Functions: [if applicable]
Types:            [regenerated]
```

## Done Criteria

- RLS on every table with deny-by-default; unauthorized access returns empty, not errors
- Types regenerated and used; auth middleware configured
- Realtime scoped and cleaned up; storage has RLS policies
- Edge functions validate inputs; migrations are forward-safe
- No service_role key exposed to client
