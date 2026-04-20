---
name: websocket-realtime
description: Implement real-time features using WebSocket, Server-Sent Events (SSE), SignalR, or Socket.IO
metadata:
  version: 2.2
  argument-hint: "transport (WebSocket/SSE/SignalR), framework, data type (messages/updates/events), scalability needs"
---

Implement real-time functionality for $ARGUMENTS using the appropriate transport.

## Tool Integration

- **Language diagnostics**: run available diagnostics tools after every code change to catch type errors before completion
- docs lookup tools: fetch current library docs before implementing — never rely on training data alone

## Documentation

> Use available docs lookup tools or official docs when you encounter unknown API syntax, current library versions, or framework-specific configuration. Do not rely on training data for library docs — fetch current docs on demand.

## Transport Selection

| Use case | Transport | Why |
|----------|-----------|-----|
| Bidirectional, low-latency | WebSocket | Full duplex, binary support |
| Server → client only, simple | SSE | HTTP-based, auto-reconnect, simple |
| .NET full-stack | SignalR | Abstracts transport, built-in fallback |
| Node.js with rooms/namespaces | Socket.IO | Rooms, broadcasting, fallback |
| High-throughput binary data | WebSocket + binary frames | No JSON overhead |
| Mobile with unreliable network | Socket.IO or SignalR | Built-in reconnection and fallback |

Decision: need client → server messages → WebSocket/Socket.IO | server push only → SSE | .NET project → SignalR | need rooms/broadcasting → Socket.IO/SignalR | binary protocol → native WebSocket | unreliable network → Socket.IO/SignalR.

## WebSocket Connection Lifecycle

1. Client sends HTTP upgrade with auth credentials
2. Server validates auth, accepts (HTTP 101) or rejects (401/403)
3. Connection established → server registers in connection store
4. Server sends initial state snapshot (catch-up since last known sequence)
5. Heartbeat/ping-pong starts (server pings every 30s, client responds within 10s)
6. Bidirectional message exchange with sequence numbers
7. Network interruption → client detects via missed pong → reconnection loop
8. Intentional close → client sends close frame (1000) → server acknowledges
9. Server cleanup: removes from store, updates presence, notifies subscribers

Close codes: 1000 (normal, don't reconnect) | 1001 (going away, reconnect immediately) | 1006 (abnormal, reconnect with backoff) | 1008 (policy violation, don't reconnect) | 1011 (server error, reconnect with backoff) | 4000 (auth expired, refresh token then reconnect) | 4001 (auth invalid, redirect to login) | 4002 (rate limited, reconnect after Retry-After) | 4003 (server at capacity, extended backoff).

## Authentication

**Ticket-based (recommended):** client calls `POST /ws/ticket` with Authorization header → server issues one-time UUID ticket (5 min TTL) → client connects with `?ticket=<ticket>` → server validates (exists, not expired, not used), deletes ticket.

**Token in first message:** token not in URL (not logged by proxies); server must buffer/reject until auth completes; 5-second auth timeout then close.

**Cookie-based:** works automatically on same domain; requires CSRF protection — validate Origin header.

Browser WebSocket API does NOT support custom headers — server-to-server or proxy/BFF only.

## Message Protocol Design

```typescript
interface WsMessage {
  type: string;      // namespaced: "chat.message", "presence.update"
  id: string;        // UUID/ULID for dedup and ack
  seq?: number;      // server-assigned, monotonically increasing per channel
  timestamp: number; // Unix ms
  payload: unknown;
}

type ServerMessage =
  | { type: 'chat.message'; payload: ChatMessage }
  | { type: 'presence.update'; payload: PresenceUpdate }
  | { type: 'system.reconnect'; payload: { reason: string; delay: number } }
  | { type: 'error'; payload: { code: string; message: string } };
```

Rules: namespace types with dots (`domain.action`); every message has `id` for dedup; server assigns `seq` for ordering; validate incoming with Zod before processing.

## Message Ordering and Delivery

Server assigns monotonically increasing sequence number per channel/room. Clients track last received seq. On reconnect: client sends `lastSeq`, server replays missed messages. Gap detection: receive seq 42 after 40 → request fill for 41.

Delivery guarantees: **at-most-once** (fire and forget — cursor positions, typing) | **at-least-once** (server retries until ack, client deduplicates by id — chat, notifications) | **exactly-once** (dedup by id + at-least-once — financial transactions, state mutations).

## Heartbeat and Reconnection

Heartbeat: server pings every 30s via WebSocket protocol-level ping/pong (opcode 0x9/0xA); client responds within 10s; adjust interval: 10s (collaboration), 30s (notifications), 60s (dashboards); dead connections detected within interval + timeout (40s default).

Reconnection — exponential backoff with jitter: BASE_DELAY 1s, MAX_DELAY 30s, MAX_ATTEMPTS 20; jitter 50-100% of exponential delay; prevents thundering herd on server restart; queue messages during disconnect, flush on reconnect; include last known sequence.

State reconciliation on reconnect: **sequence replay** (short disconnect, small volume — client sends `lastSeq`) | **full snapshot** (long disconnect, complex state — server sends current state) | **timestamp catch-up** (event-sourced — client sends `lastTimestamp`).

## Room and Channel Patterns

Fan-out types: **direct** (specific connection/user — private messages) | **room broadcast** (all in room — chat, collaborative docs) | **user broadcast** (all devices for user — notifications, session sync) | **tenant broadcast** (all for org — system announcements) | **global broadcast** (all clients — maintenance notices).

Room authorization: validate access on join; re-validate on reconnect (permissions may have changed); listen for permission revocation events; force-leave users who lose access.

## Presence Systems

Online if ANY device connected (multi-device aware); away after 5 min inactivity; offline after heartbeat timeout (not immediately). Store presence in Redis with TTL — not in database (ephemeral by nature).

Typing indicators: debounce start, throttle send every 3s, auto-clear after 5s server-side; at-most-once delivery. Cursor sharing: throttle to 50-100ms (10-20 updates/sec); at-most-once; binary encoding recommended; remove after 5s no update.

## Connection Migration During Deployment

New version accepts connections → LB marks old as draining → old sends "reconnect" signal with random 0-5s jitter delay → clients reconnect to new version → old waits drain timeout (30-60s) then stops. Set `terminationGracePeriodSeconds` to match drain timeout. Redis backplane prevents message loss. Clients treat planned reconnect signal as short delay, not full backoff.

## Scaling WebSocket Servers

Sticky sessions: cookie-based, IP hash, or Connection ID routing. WebSocket connections are stateful — must route to same server.

Redis pub/sub backplane: every server subscribes to Redis channels for rooms it has local connections in; each server delivers only to its local connections (avoids duplicates); Redis Cluster for >100K messages/second.

Connection limits: per user: 5-10 | per server: 10,000-50,000 | per connection/sec: 10-100 | message size: 64KB JSON, 1MB binary | rooms per connection: 20-50. Drop low-priority messages at soft buffer limit; disconnect with code 4002 at hard limit.

## Framework-Specific Patterns

### Angular + SignalR

```typescript
@Injectable({ providedIn: 'root' })
export class RealtimeService {
  private readonly destroyRef = inject(DestroyRef);
  readonly connectionState = signal<'connected' | 'disconnected' | 'reconnecting'>('disconnected');
  readonly messages = signal<ChatMessage[]>([]);
  readonly unreadCount = computed(() => this.messages().filter(m => !m.read).length);

  constructor() { this.destroyRef.onDestroy(() => this.connection?.stop()); }

  async connect(hubUrl: string) {
    this.connection = new HubConnectionBuilder()
      .withUrl(hubUrl).withAutomaticReconnect([0, 2000, 5000, 10000, 30000]).build();
    this.connection.onreconnecting(() => this.connectionState.set('reconnecting'));
    this.connection.onreconnected(() => this.connectionState.set('connected'));
    this.connection.onclose(() => this.connectionState.set('disconnected'));
    this.connection.on('ReceiveMessage', (msg: ChatMessage) => this.messages.update(msgs => [...msgs, msg]));
    await this.connection.start();
    this.connectionState.set('connected');
  }
}
```

### React / Next.js + Socket.IO / SSE

Zustand store for real-time state; `useEffect` with cleanup for socket lifecycle; `socket.on('connect')` / `socket.on('disconnect')` / `socket.on('message')` → store updates; cleanup: `return () => { socket.disconnect(); }`.

Next.js SSE Route Handler: `new ReadableStream({ start(controller) { const send = (data) => controller.enqueue(encoder.encode(`data: ${JSON.stringify(data)}\n\n`)); const unsub = eventBus.subscribe(send); request.signal.addEventListener('abort', () => { unsub(); controller.close(); }); } })` → return with `Content-Type: text/event-stream, Cache-Control: no-cache`.

TanStack Query + WebSocket: `useWsEvent('update:key', (data) => queryClient.setQueryData(queryKey, data))`.

### Vue / Nuxt + Socket.IO

Extract into `useWebSocket(url)` composable: `ref` for data/status, `onMounted` to open, `onUnmounted` to close, return `readonly` refs. Or use `useWebSocket` from `@vueuse/core` with `autoReconnect` and `heartbeat` options. Store messages in Pinia, connect socket in store action, push events with `.on('message', msg => messages.push(msg))`.

Nuxt SSE server route: `createEventStream(event)` from h3, subscribe to event bus, `stream.push({ data: JSON.stringify(data) })`, unsubscribe in `stream.onClosed()`.

### SvelteKit + WebSocket

`$state` for messages/connectionState; open in `onMount`; close in `onDestroy`; `$derived` for computed values. For shared state: extract to `class RealtimeStore` in `lib/realtime.svelte.ts` using Svelte 5 runes.

SvelteKit has no built-in WebSocket — use socket.io with adapter-node, a managed service (Ably/Pusher/Supabase Realtime), or SSE from `+server.ts` for push-only.

### Blazor + SignalR (.NET 8+)

```razor
@implements IAsyncDisposable
@code {
    private HubConnection? _hub;
    protected override async Task OnInitializedAsync() {
        _hub = new HubConnectionBuilder()
            .WithUrl(Nav.ToAbsoluteUri("/hubs/chat"))
            .WithAutomaticReconnect().Build();
        _hub.On<ChatMessage>("ReceiveMessage", (msg) => {
            _messages.Add(msg);
            InvokeAsync(StateHasChanged); // required for non-UI thread callback
        });
        _hub.Reconnecting += _ => { _connected = false; InvokeAsync(StateHasChanged); return Task.CompletedTask; };
        await _hub.StartAsync();
        _connected = true;
    }
    public async ValueTask DisposeAsync() { if (_hub is not null) await _hub.DisposeAsync(); }
}
```

Interactive Server mode: SignalR is already the transport — use component timers or event subscriptions for server-originated updates without a separate hub. `IAsyncEnumerable<T>` for streaming: `yield return` in a hub method with `[EnumeratorCancellation] CancellationToken`.

## Security

Authenticate on connection (upgrade or first message), not per message. Validate all incoming messages with schema validation (Zod, class-validator). Rate limit messages per connection (token bucket: 10-100 msgs/sec). Never trust client-sent user IDs — use server-side auth context. Sanitize messages before broadcasting (prevent stored XSS). Validate Origin header on upgrade. Set maximum message size. Use WSS (TLS) in production. Re-validate permissions on reconnect.

## Anti-Patterns

No reconnection logic or reconnecting without backoff/jitter | broadcasting to all instead of targeted rooms | connection state only in memory without Redis backplane for multi-server | no heartbeat (dead connections accumulate) | one WebSocket per component (share via context/service) | sending large payloads over WebSocket (use HTTP) | JSON for high-frequency binary data >60 msg/sec | custom collaborative editing protocol (use Yjs/Automerge) | no graceful drain before server shutdown.

## Implementation Workflow

1. Identify direction, frequency, payload size, user count
2. Select transport (WebSocket / SSE / SignalR / Socket.IO)
3. Design typed message protocol with unique IDs and sequence numbers
4. Implement connection authentication
5. Build room/channel management with authorization on join and reconnect
6. Add heartbeat/ping-pong + reconnection with exponential backoff + jitter
7. State reconciliation on reconnect
8. Add presence tracking if needed
9. Redis pub/sub backplane for multi-server
10. Graceful drain for zero-downtime deployments
11. Rate limiting, schema validation, security checks
12. Frontend: shared connection manager (context/service), connection state UI

## Output Format

```
Feature:           [what real-time feature is being built]
Transport:         [WebSocket / SSE / SignalR / Socket.IO]
Protocol:          [JSON / binary / MessagePack / Protobuf]
Auth:              [ticket / first-message / cookie]
Rooms/Channels:    [structure and authorization model]
Presence:          [online status / typing / cursors — if applicable]
Ordering:          [sequence numbers / timestamp / none]
Delivery:          [at-most-once / at-least-once / exactly-once]
Reconnection:      [backoff strategy, state reconciliation approach]
Scaling:           [Redis pub/sub / sticky sessions / single instance]
Heartbeat:         [interval and timeout]
Deployment:        [graceful drain strategy]
```

## Done Criteria

- Connections authenticate properly on establishment
- Reconnection works with exponential backoff and jitter
- State reconciliation restores client view after reconnect
- Messages delivered with the chosen guarantee, ordering preserved within channel
- UI shows connection state without blocking the interface
- Server handles scale-out via Redis pub/sub (if multi-instance)
- Heartbeat detects and cleans up dead connections within 40 seconds
- Rooms enforce authorization on join and reconnect
- Messages validated against schema before processing
- Rate limiting prevents message flooding
- Graceful drain notifies clients before server stops
