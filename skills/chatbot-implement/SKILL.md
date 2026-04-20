---
name: chatbot-implement
description: Build conversational AI interfaces — conversation state management, history windows, streaming responses in UI, tool call orchestration, multi-turn context, and handoff to human agents
metadata:
  version: 1.2
  argument-hint: "chatbot platform (web/mobile/Telegram), features (streaming/tools/agent handoff), context window size, UI framework (React/Vue), persistence requirement"
---

Implement $ARGUMENTS.


Stacks in scope:
- React + Vercel AI SDK (useChat, useCompletion)
- React + Anthropic SDK (custom)
- .NET + SignalR (Blazor chat)
- Node.js / NestJS backends

## Conversation State Management

### Message Schema

```typescript
interface Message {
  id: string;
  role: 'user' | 'assistant' | 'system' | 'tool';
  content: string;
  createdAt: Date;
  metadata?: {
    model?: string;
    tokens?: { input: number; output: number };
    toolCalls?: ToolCall[];
    citations?: Citation[];
  };
}

interface Conversation {
  id: string;
  messages: Message[];
  createdAt: Date;
  updatedAt: Date;
  title?: string; // Auto-generated from first message
  metadata?: Record<string, unknown>;
}
```

### Session Tracking
- Generate conversation ID on first message (`crypto.randomUUID()`)
- Persist to database: conversations table + messages table (1:many)
- Auto-title from first user message (LLM summarization or first 50 chars)
- Support conversation resume: load history by ID

## History Window Strategies

### Sliding Window
Keep last N messages. Simple, predictable token usage:
```typescript
function slidingWindow(messages: Message[], maxMessages: number = 20): Message[] {
  const system = messages.filter(m => m.role === 'system');
  const recent = messages.filter(m => m.role !== 'system').slice(-maxMessages);
  return [...system, ...recent];
}
```

### Token-Based Truncation
```typescript
function tokenTruncate(messages: Message[], maxTokens: number): Message[] {
  const system = messages.filter(m => m.role === 'system');
  const rest = messages.filter(m => m.role !== 'system');
  let tokenCount = system.reduce((sum, m) => sum + estimateTokens(m.content), 0);
  const kept: Message[] = [];
  for (let i = rest.length - 1; i >= 0; i--) {
    const tokens = estimateTokens(rest[i].content);
    if (tokenCount + tokens > maxTokens) break;
    tokenCount += tokens;
    kept.unshift(rest[i]);
  }
  return [...system, ...kept];
}
```

### Summarization
When history exceeds budget, summarize older messages:
```typescript
async function summarizeHistory(messages: Message[]): Promise<string> {
  const oldMessages = messages.slice(0, -10); // Keep last 10 intact
  const summary = await llm.generate({
    system: 'Summarize this conversation concisely, preserving key decisions and context.',
    user: oldMessages.map(m => `${m.role}: ${m.content}`).join('\n'),
  });
  return summary.text;
}
// Insert as system message: { role: 'system', content: `Previous conversation summary: ${summary}` }
```

## Streaming Responses

### React + Vercel AI SDK

```typescript
'use client';
import { useChat } from '@ai-sdk/react';

export function Chat() {
  const { messages, input, handleInputChange, handleSubmit, isLoading, error, stop, reload } = useChat({
    api: '/api/chat',
    onError: (err) => toast.error(err.message),
  });

  return (
    <div className="flex flex-col h-full">
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.map((m) => (
          <div key={m.id} className={m.role === 'user' ? 'text-right' : 'text-left'}>
            <div className={`inline-block rounded-lg px-4 py-2 max-w-[80%] ${
              m.role === 'user' ? 'bg-blue-500 text-white' : 'bg-gray-100'
            }`}>
              <Markdown>{m.content}</Markdown>
            </div>
          </div>
        ))}
        {isLoading && <TypingIndicator />}
      </div>
      <form onSubmit={handleSubmit} className="border-t p-4 flex gap-2">
        <input value={input} onChange={handleInputChange} placeholder="Type a message..."
          className="flex-1 rounded-lg border px-4 py-2" disabled={isLoading} />
        {isLoading ? (
          <button type="button" onClick={stop}>Stop</button>
        ) : (
          <button type="submit">Send</button>
        )}
      </form>
    </div>
  );
}
```

### API Route (Vercel AI SDK)

```typescript
import { streamText } from 'ai';
import { anthropic } from '@ai-sdk/anthropic';

export async function POST(req: Request) {
  const { messages } = await req.json();
  const result = streamText({
    model: providerModel('high-capability-chat-model'),
    system: 'You are a helpful assistant.',
    messages,
    tools: { /* tool definitions */ },
    maxSteps: 5, // Allow multi-step tool use
  });
  return result.toDataStreamResponse();
}
```

### .NET + SignalR

```csharp
public class ChatHub : Hub
{
    public async IAsyncEnumerable<string> StreamMessage(string userMessage, [EnumeratorCancellation] CancellationToken ct)
    {
        var stream = client.Messages.CreateStreamAsync(new() {
            Model = "high-capability-chat-model", MaxTokens = 4096,
            Messages = [new() { Role = "user", Content = userMessage }],
        }, ct);

        await foreach (var evt in stream.WithCancellation(ct))
        {
            if (evt is ContentBlockDelta { Delta: TextDelta textDelta })
                yield return textDelta.Text;
        }
    }
}
```

## Tool Call Orchestration

### Display Tool Calls in UI
```typescript
{message.toolCalls?.map((tool) => (
  <div key={tool.id} className="bg-gray-50 rounded p-2 text-sm">
    <span className="font-mono text-xs text-gray-500">{tool.name}</span>
    {tool.state === 'loading' && <Spinner />}
    {tool.state === 'done' && <ToolResult result={tool.result} />}
  </div>
))}
```

### User Confirmation for Sensitive Tools
```typescript
const tools = {
  sendEmail: { description: '...', parameters: z.object({ to: z.string(), subject: z.string() }),
    execute: async (params) => {
      // Return pending state — UI shows confirmation dialog
      return { requiresConfirmation: true, action: 'send_email', params };
    },
  },
};
```

## Handoff to Human Agent

### Escalation Triggers
- User explicitly asks for human: "talk to a person", "connect me to support"
- Agent confidence is low after 3+ attempts
- Sensitive topics (billing disputes, account security, legal)
- Agent detects frustration (repeated questions, negative sentiment)

### Context Transfer
```typescript
interface HandoffPayload {
  conversationId: string;
  summary: string; // LLM-generated summary of the conversation so far
  customerInfo: { name: string; email: string; plan: string };
  attemptedSolutions: string[]; // What the AI already tried
  priority: 'low' | 'medium' | 'high' | 'urgent';
  category: string;
}
```

## Error Handling

### Graceful Degradation
- Rate limit (429): show "I'm a bit busy right now. Please try again in a moment."
- Network error: show retry button, preserve unsent message
- Timeout: show "This is taking longer than expected" with cancel option
- Model error: fall back to simpler model or cached response

### Retry with Exponential Backoff
```typescript
async function sendWithRetry(messages: Message[], maxRetries: number = 3): Promise<Response> {
  for (let i = 0; i < maxRetries; i++) {
    try { return await fetch('/api/chat', { method: 'POST', body: JSON.stringify({ messages }) }); }
    catch (err) {
      if (i === maxRetries - 1) throw err;
      await new Promise(r => setTimeout(r, 1000 * Math.pow(2, i)));
    }
  }
  throw new Error('Max retries exceeded');
}
```

## UI Patterns

### Message Rendering
- Markdown support (code blocks, bold, links, lists)
- Code blocks with syntax highlighting and copy button
- Citations: `[1]` links that expand to show source
- Image rendering for multimodal responses
- Typing indicator during streaming (animated dots)

### Input Enhancements
- Auto-resize textarea (grows with content)
- Shift+Enter for newline, Enter to send
- File attachment button (if supported)
- Voice input (Web Speech API)
- Suggested replies / quick actions

## Done Criteria

- [ ] Messages persist across page reloads
- [ ] Streaming renders token-by-token with typing indicator
- [ ] Stop button cancels in-flight requests
- [ ] History window prevents context overflow
- [ ] Tool calls display inline with loading states
- [ ] Error states show user-friendly messages with retry
- [ ] Keyboard accessible (Enter to send, Escape to cancel)
- [ ] Mobile responsive layout
- [ ] Handoff path to human agent implemented (if applicable)
