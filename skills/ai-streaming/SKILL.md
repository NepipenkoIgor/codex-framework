---
name: ai-streaming
description: Implement LLM streaming responses — SSE, token-by-token rendering, streaming state management, backpressure, and cancellation
metadata:
  version: 1.4
  argument-hint: "provider (OpenAI/Anthropic/other), client type (browser/Node.js/Edge), UI framework (React/Vue/vanilla), cancellation/backpressure handling required"
---

Implement LLM streaming for $ARGUMENTS.

## Tool Integration

- **Type diagnostics**: run available diagnostics tools after every code change to catch type errors before completion
- docs lookup tools: fetch current library docs before implementing — never rely on training data alone

## Documentation

> Use available docs lookup tools or official docs for current Vercel AI SDK, OpenAI SDK, Anthropic SDK, and framework-specific streaming docs. Do not rely on training data for library configuration syntax.

## Provider SSE Patterns

> Use available docs lookup tools or official docs to fetch current OpenAI and Anthropic SDK docs for streaming API syntax.

### Raw SSE Consumption

```typescript
async function* consumeSSE(url: string, body: object, signal?: AbortSignal): AsyncGenerator<string> {
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Accept': 'text/event-stream' },
    body: JSON.stringify(body),
    signal,
  });
  if (!response.ok) throw new Error(`SSE request failed: ${response.status}`);

  const reader = response.body!.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop() ?? '';
      for (const line of lines) {
        if (line.startsWith('data: ')) {
          const data = line.slice(6);
          if (data === '[DONE]') return;
          yield data;
        }
      }
    }
  } finally {
    reader.releaseLock();
  }
}
```

## Abort and Cancel

```typescript
class StreamController {
  private controller: AbortController | null = null;
  start(): AbortSignal { this.controller = new AbortController(); return this.controller.signal; }
  cancel(): void { this.controller?.abort(); this.controller = null; }
  get isActive(): boolean { return this.controller !== null && !this.controller.signal.aborted; }
}
```

Rules:
- Always forward `req.signal` abort to the LLM provider call to stop token generation
- Catch `AbortError` separately from real errors — abort is intentional, not a failure
- Clean up ReadableStream readers on cancel to prevent memory leaks

## Error Handling and Retry

| Error | Recovery |
|-------|----------|
| Network timeout (30s no data) | Retry from start |
| Rate limit (429) | Wait Retry-After, then retry |
| Server error (500) | Retry with backoff (max 2 retries) |
| Malformed SSE event | Skip event, continue stream |
| User abort | Clean up, show partial result |

## Backpressure Handling

Throttle token rendering at 16ms (one frame at 60fps) to prevent UI jank from rapid token emission. Buffer tokens and flush on interval rather than rendering each token immediately.

## Streaming JSON (Partial Structured Output)

For structured output, accumulate the full buffer and attempt partial JSON parsing on each chunk. When the stream completes, validate with Zod.

> Use available docs lookup tools or official docs to fetch current Vercel AI SDK `streamObject` and `useObject` docs for structured streaming.

## Framework Integration

### Next.js (Vercel AI SDK)

> Use available docs lookup tools or official docs to fetch current `ai` and `ai/react` docs for `streamText`, `useChat`, `useCompletion`.

Server route returns `result.toDataStreamResponse()`. Client uses `useChat()` from `ai/react` — handles streaming, abort, and error automatically.

### Angular

```typescript
@Injectable({ providedIn: 'root' })
export class AiStreamService {
  private readonly destroyRef = inject(DestroyRef);
  readonly chunks = signal<string[]>([]);
  readonly isStreaming = signal(false);
  readonly fullText = computed(() => this.chunks().join(''));

  async streamPost(prompt: string) {
    this.chunks.set([]);
    this.isStreaming.set(true);
    const controller = new AbortController();
    this.destroyRef.onDestroy(() => controller.abort());

    const response = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt }),
      signal: controller.signal,
    });

    const reader = response.body!.getReader();
    const decoder = new TextDecoder();
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        this.chunks.update(c => [...c, decoder.decode(value, { stream: true })]);
      }
    } finally {
      reader.releaseLock();
      this.isStreaming.set(false);
    }
  }
}
```

Use `@microsoft/fetch-event-source` for POST-based SSE (native `EventSource` only supports GET). Integrate `AbortController` with `DestroyRef`.

### Vue / Nuxt

Use a composable with `ref<string[]>([])` for chunks, `computed` for `fullText`, `AbortController` ref, and `onUnmounted` cleanup. Nuxt server route: `sendStream(event, readableStream)`.

> Use available docs lookup tools or official docs to fetch current `@ai-sdk/vue` `useChat` docs.

### SvelteKit

Use `$state<string[]>([])` for chunks, `$derived(chunks.join(''))` for `fullText`, and `$state<AbortController>()` for the controller. Server endpoint: `+server.ts` returning `new Response(readableStream, { headers: { 'Content-Type': 'text/event-stream' } })`.

> Use available docs lookup tools or official docs to fetch current `@ai-sdk/svelte` docs.

### Blazor (.NET 8+)

Use `IAsyncEnumerable<string>` from minimal API endpoint with `Results.Stream(...)`. Client reads via `HttpClient.GetStreamAsync()` + `StreamReader`. For real-time: SignalR `IAsyncEnumerable<string>` hub method.

Use `@attribute [StreamRendering]` on Blazor components for progressive rendering.

## Anti-Patterns

- Not forwarding client disconnect to the LLM provider — generation continues after abort, wasting tokens
- Not cleaning up ReadableStream readers on cancel — reader lock prevents GC
- Ignoring backpressure — appending tokens every render cycle causes layout thrash
- Not handling partial JSON for structured output — display never updates until stream ends

## Done Criteria

- Tokens render incrementally as they arrive
- User can cancel mid-stream with immediate effect
- Client disconnect stops LLM generation on the server
- Errors handled with retry for transient failures
- Backpressure managed (throttled rendering)
- Structured output streamed with partial rendering
