# Frontend Integration Patterns

## Connection Manager (React)

```typescript
const WebSocketContext = createContext<WebSocketManager | null>(null);

function WebSocketProvider({ children }: PropsWithChildren) {
  const { user } = useAuth();
  const [state, setState] = useState<'connecting' | 'connected' | 'reconnecting' | 'disconnected'>('disconnected');
  const managerRef = useRef<WebSocketManager | null>(null);

  useEffect(() => {
    if (!user) return;
    const manager = new WebSocketManager({
      url: 'wss://api.example.com/ws',
      getTicket: () => api.getWsTicket(),
      onStateChange: setState,
    });
    manager.connect();
    managerRef.current = manager;
    return () => { manager.disconnect(); managerRef.current = null; };
  }, [user?.id]);

  return (
    <WebSocketContext.Provider value={managerRef.current}>
      {children}
    </WebSocketContext.Provider>
  );
}

// Hook for subscribing to message types
function useWsEvent<T>(type: string, handler: (payload: T) => void) {
  const manager = useContext(WebSocketContext);
  useEffect(() => {
    if (!manager) return;
    return manager.on(type, handler);
  }, [manager, type, handler]);
}
```

## Connection Manager (Angular -- Signal-Based)

```typescript
import { Injectable, signal, computed, inject, DestroyRef, effect } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

type ConnectionState = 'connecting' | 'connected' | 'reconnecting' | 'disconnected';

@Injectable({ providedIn: 'root' })
export class WebSocketService {
  private ws: WebSocket | null = null;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private attempt = 0;

  private readonly _state = signal<ConnectionState>('disconnected');
  private readonly handlers = new Map<string, Set<(payload: any) => void>>();

  readonly state = this._state.asReadonly();
  readonly isConnected = computed(() => this._state() === 'connected');

  connect(url: string, ticket: string): void {
    this._state.set('connecting');
    this.ws = new WebSocket(`${url}?ticket=${ticket}`);
    this.ws.onopen = () => { this._state.set('connected'); this.attempt = 0; };
    this.ws.onmessage = (e) => {
      const msg = JSON.parse(e.data);
      this.handlers.get(msg.type)?.forEach((fn) => fn(msg.payload));
    };
    this.ws.onclose = (e) => {
      if (e.code === 1000 || e.code === 4001) { this._state.set('disconnected'); return; }
      this._state.set('reconnecting');
      this.scheduleReconnect(url);
    };
  }

  on<T>(type: string, handler: (payload: T) => void): () => void {
    if (!this.handlers.has(type)) this.handlers.set(type, new Set());
    this.handlers.get(type)!.add(handler);
    return () => this.handlers.get(type)?.delete(handler);
  }

  send(type: string, payload: unknown): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({ type, payload, id: crypto.randomUUID() }));
    }
  }

  disconnect(): void {
    this.ws?.close(1000, 'Client disconnect');
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
  }

  private scheduleReconnect(url: string): void {
    const delay = Math.min(1000 * 2 ** this.attempt, 30000) * (0.5 + Math.random() * 0.5);
    this.reconnectTimer = setTimeout(() => { this.attempt++; this.connect(url, ''); }, delay);
  }
}

// Component usage -- auto-cleanup with DestroyRef
@Component({ /* ... */ })
export class LiveFeedComponent {
  private ws = inject(WebSocketService);
  private destroyRef = inject(DestroyRef);

  messages = signal<ChatMessage[]>([]);
  connectionState = this.ws.state; // read signal directly in template

  constructor() {
    const unsub = this.ws.on<ChatMessage>('chat.message', (msg) => {
      this.messages.update((prev) => [...prev, msg]);
    });
    this.destroyRef.onDestroy(() => unsub());
  }
}
```

### RxJS `webSocket` (legacy / interop)

```typescript
import { webSocket } from 'rxjs/webSocket';

// Use when integrating with existing RxJS-heavy code
const ws$ = webSocket<WsMessage>('wss://api.example.com/ws');
ws$.pipe(
  filter((msg) => msg.type === 'chat.message'),
  takeUntilDestroyed(),
).subscribe((msg) => handle(msg));
```

Prefer the signal-based service for new code. Use `webSocket()` only when existing codebase is RxJS-heavy and migration is not in scope.

## Connection Manager (Blazor -- SignalR Client)

```csharp
@implements IAsyncDisposable
@inject NavigationManager Nav

<div class="@(_state == "connected" ? "" : "opacity-50")">
    @if (_state == "reconnecting")
    {
        <div class="bg-amber-100 p-2 text-sm">Reconnecting...</div>
    }
    @foreach (var msg in _messages)
    {
        <p>@msg.User: @msg.Text</p>
    }
</div>

@code {
    private HubConnection? _hub;
    private string _state = "disconnected";
    private readonly List<ChatMessage> _messages = new();

    protected override async Task OnInitializedAsync()
    {
        _hub = new HubConnectionBuilder()
            .WithUrl(Nav.ToAbsoluteUri("/hubs/chat"), options =>
            {
                options.AccessTokenProvider = () => Task.FromResult(GetAccessToken());
            })
            .WithAutomaticReconnect(new[] { TimeSpan.Zero, TimeSpan.FromSeconds(2),
                TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(30) })
            .Build();

        _hub.On<ChatMessage>("ReceiveMessage", (msg) =>
        {
            _messages.Add(msg);
            InvokeAsync(StateHasChanged); // Marshal to UI thread
        });

        _hub.Reconnecting += (_) => { _state = "reconnecting"; InvokeAsync(StateHasChanged); return Task.CompletedTask; };
        _hub.Reconnected += (_) => { _state = "connected"; InvokeAsync(StateHasChanged); return Task.CompletedTask; };
        _hub.Closed += (_) => { _state = "disconnected"; InvokeAsync(StateHasChanged); return Task.CompletedTask; };

        await _hub.StartAsync();
        _state = "connected";
    }

    private async Task SendMessage(string text) =>
        await _hub!.InvokeAsync("SendMessage", "room-1", text);

    public async ValueTask DisposeAsync()
    {
        if (_hub is not null) await _hub.DisposeAsync();
    }
}
```

### Blazor Server vs WASM SignalR

| Aspect | Blazor Server | Blazor WASM |
|--------|--------------|-------------|
| Default connection | Already has a SignalR circuit | No built-in WS connection |
| Additional hub | New `HubConnection` alongside the circuit | New `HubConnection` (same as any .NET client) |
| Auth tokens | Cookie or circuit-level auth | Bearer token via `AccessTokenProvider` |
| `StateHasChanged` | Called from hub callbacks via `InvokeAsync` | Same -- always marshal to render thread |
| Reconnection | Circuit handles its own reconnection; app hub needs separate reconnect | App hub reconnection only |

Key rules:
- Always wrap hub callbacks with `InvokeAsync(StateHasChanged)` -- hub events arrive on a non-UI thread
- Always implement `IAsyncDisposable` to dispose the `HubConnection`
- Use `WithAutomaticReconnect` with escalating delays
- In Blazor Server, the component already lives on the server -- avoid duplicate data fetching between hub and component lifecycle

## Connection Manager (SvelteKit)

```typescript
// lib/websocket.svelte.ts -- Svelte 5 runes
import { onDestroy } from 'svelte';

type ConnectionState = 'connecting' | 'connected' | 'reconnecting' | 'disconnected';

export function createWebSocket(url: string, getTicket: () => Promise<string>) {
  let state = $state<ConnectionState>('disconnected');
  let ws: WebSocket | null = null;
  let attempt = 0;
  let timer: ReturnType<typeof setTimeout> | null = null;
  const handlers = new Map<string, Set<(payload: any) => void>>();

  async function connect() {
    state = 'connecting';
    const ticket = await getTicket();
    ws = new WebSocket(`${url}?ticket=${ticket}`);
    ws.onopen = () => { state = 'connected'; attempt = 0; };
    ws.onmessage = (e) => {
      const msg = JSON.parse(e.data);
      handlers.get(msg.type)?.forEach((fn) => fn(msg.payload));
    };
    ws.onclose = (e) => {
      if (e.code === 1000 || e.code === 4001) { state = 'disconnected'; return; }
      state = 'reconnecting';
      const delay = Math.min(1000 * 2 ** attempt++, 30000) * (0.5 + Math.random() * 0.5);
      timer = setTimeout(connect, delay);
    };
  }

  function on<T>(type: string, handler: (payload: T) => void): () => void {
    if (!handlers.has(type)) handlers.set(type, new Set());
    handlers.get(type)!.add(handler);
    return () => handlers.get(type)?.delete(handler);
  }

  function send(type: string, payload: unknown) {
    if (ws?.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type, payload, id: crypto.randomUUID() }));
    }
  }

  function disconnect() {
    ws?.close(1000, 'Client disconnect');
    if (timer) clearTimeout(timer);
  }

  return {
    get state() { return state; },
    connect, disconnect, on, send,
  };
}

// Component usage -- +page.svelte
<script lang="ts">
  import { createWebSocket } from '$lib/websocket.svelte';
  import { onDestroy } from 'svelte';

  const ws = createWebSocket('wss://api.example.com/ws', fetchTicket);
  ws.connect();

  let messages = $state<ChatMessage[]>([]);
  const unsub = ws.on<ChatMessage>('chat.message', (msg) => {
    messages = [...messages, msg];
  });

  onDestroy(() => { unsub(); ws.disconnect(); });
</script>

{#if ws.state === 'reconnecting'}
  <div class="bg-amber-100 p-2 text-sm">Reconnecting...</div>
{/if}
{#each messages as msg}
  <p>{msg.user}: {msg.text}</p>
{/each}
```

### SvelteKit Server Hook (WebSocket via Adapter)

SvelteKit does not natively support WebSocket in dev server. For production, use adapter-node with a custom server entry or a separate WS process. The client patterns above work with any WebSocket server URL.

## Connection Manager (Vue / Nuxt -- Composable)

```typescript
// composables/useWebSocket.ts
import { ref, onUnmounted, readonly, type Ref } from 'vue';

type ConnectionState = 'connecting' | 'connected' | 'reconnecting' | 'disconnected';

export function useWebSocket(url: string, getTicket: () => Promise<string>) {
  const state = ref<ConnectionState>('disconnected');
  const handlers = new Map<string, Set<(payload: any) => void>>();
  let ws: WebSocket | null = null;
  let attempt = 0;
  let timer: ReturnType<typeof setTimeout> | null = null;

  async function connect() {
    state.value = 'connecting';
    const ticket = await getTicket();
    ws = new WebSocket(`${url}?ticket=${ticket}`);
    ws.onopen = () => { state.value = 'connected'; attempt = 0; };
    ws.onmessage = (e) => {
      const msg = JSON.parse(e.data);
      handlers.get(msg.type)?.forEach((fn) => fn(msg.payload));
    };
    ws.onclose = (e) => {
      if (e.code === 1000 || e.code === 4001) { state.value = 'disconnected'; return; }
      state.value = 'reconnecting';
      const delay = Math.min(1000 * 2 ** attempt++, 30000) * (0.5 + Math.random() * 0.5);
      timer = setTimeout(connect, delay);
    };
  }

  function on<T>(type: string, handler: (payload: T) => void): () => void {
    if (!handlers.has(type)) handlers.set(type, new Set());
    handlers.get(type)!.add(handler);
    return () => handlers.get(type)?.delete(handler);
  }

  function send(type: string, payload: unknown) {
    if (ws?.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type, payload, id: crypto.randomUUID() }));
    }
  }

  function disconnect() {
    ws?.close(1000, 'Client disconnect');
    if (timer) clearTimeout(timer);
  }

  onUnmounted(() => disconnect());

  return { state: readonly(state), connect, disconnect, on, send };
}

// Component usage -- ChatRoom.vue
<script setup lang="ts">
import { ref } from 'vue';
import { useWebSocket } from '~/composables/useWebSocket';

const { state, connect, on, send } = useWebSocket('wss://api.example.com/ws', fetchTicket);
const messages = ref<ChatMessage[]>([]);

connect();
on<ChatMessage>('chat.message', (msg) => messages.value.push(msg));
</script>

<template>
  <div v-if="state === 'reconnecting'" class="bg-amber-100 p-2 text-sm">Reconnecting...</div>
  <p v-for="msg in messages" :key="msg.id">{{ msg.user }}: {{ msg.text }}</p>
</template>
```

### Nuxt Server Plugin (WebSocket)

```typescript
// server/plugins/websocket.ts -- Nuxt 3 Nitro plugin
import { WebSocketServer } from 'ws';

export default defineNitroPlugin((nitro) => {
  const wss = new WebSocketServer({ noServer: true });

  // Hook into the underlying HTTP server
  nitro.hooks.hook('request', (event) => {
    if (event.path === '/ws' && event.node.req.headers.upgrade === 'websocket') {
      wss.handleUpgrade(event.node.req, event.node.req.socket, Buffer.alloc(0), (ws) => {
        wss.emit('connection', ws, event.node.req);
      });
      event._handled = true;
    }
  });

  wss.on('connection', (ws, req) => {
    // Auth, message handling, room management here
    ws.on('message', (data) => { /* handle */ });
    ws.on('close', () => { /* cleanup */ });
  });
});
```

For production Nuxt, prefer a dedicated WebSocket server or Nitro WebSocket support (experimental in Nitro 2.9+). The composable client pattern above works with any WS endpoint.

## Native WebSocket (Browser)

```typescript
// Browser client -- minimal example
const ws = new WebSocket('wss://api.example.com/ws?ticket=abc123');

ws.onopen = () => console.log('Connected');
ws.onclose = (event) => {
  if (event.code !== 1000) reconnect(); // Non-normal close -- reconnect
};
ws.onerror = () => {}; // onclose always fires after onerror

// Binary mode
ws.binaryType = 'arraybuffer';
ws.onmessage = (event) => {
  if (event.data instanceof ArrayBuffer) {
    handleBinary(event.data);
  } else {
    handleJSON(JSON.parse(event.data));
  }
};

// Clean disconnect on page unload
window.addEventListener('beforeunload', () => {
  ws.close(1000, 'Page unload');
});
```

## Connection State UI

```
Connected:     No indicator (normal state -- do not clutter the UI)
Reconnecting:  Yellow/amber subtle banner -- "Reconnecting..." with attempt count
Disconnected:  Red banner -- "Connection lost. Retrying in Xs" with manual retry button
```

- Do not block the entire UI during reconnection -- let users read existing content
- Queue user actions during disconnect, apply on reconnect (optimistic)
- Show a manual retry button after extended disconnection (>1 min)
- Clean up subscriptions on component unmount -- prevent memory leaks
