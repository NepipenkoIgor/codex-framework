# Server-Sent Events (SSE)

## Server (Node.js/Express)

```typescript
app.get('/events', authenticate, (req, res) => {
  const userId = req.user.id;

  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'X-Accel-Buffering': 'no', // Disable Nginx buffering
  });

  // Initial event
  res.write(`event: connected\ndata: ${JSON.stringify({ userId })}\n\n`);

  // Keep-alive comment every 15s (prevents proxy timeout)
  const keepAlive = setInterval(() => res.write(':keepalive\n\n'), 15_000);

  // Subscribe to events
  const unsubscribe = eventBus.subscribe(`user:${userId}`, (event) => {
    res.write(`id: ${event.id}\nevent: ${event.type}\ndata: ${JSON.stringify(event.payload)}\n\n`);
  });

  // Resume from Last-Event-ID
  const lastEventId = req.headers['last-event-id'];
  if (lastEventId) {
    replayEventsSince(userId, lastEventId).forEach((event) => {
      res.write(`id: ${event.id}\nevent: ${event.type}\ndata: ${JSON.stringify(event.payload)}\n\n`);
    });
  }

  req.on('close', () => {
    clearInterval(keepAlive);
    unsubscribe();
  });
});
```

## Client

```typescript
// Native EventSource -- auto-reconnect built in
const source = new EventSource('/events');
source.addEventListener('notification', (event) => {
  const data = JSON.parse(event.data);
  handleNotification(data);
});
source.onerror = () => updateConnectionState('reconnecting');
// EventSource auto-sends Last-Event-ID on reconnect
```

## SSE Limitations

- Unidirectional: server to client only (use POST requests for client-to-server)
- Max 6 concurrent connections per domain in HTTP/1.1 (not an issue with HTTP/2)
- No binary support -- text/JSON only
- Browser EventSource API does not support custom headers -- use `@microsoft/fetch-event-source` for auth
