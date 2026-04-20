# Native WebSocket (ws library -- Node.js)

```typescript
import { WebSocketServer, WebSocket } from 'ws';
import { createServer } from 'http';

interface UserContext { id: string; roles: string[] }
const connMeta = new WeakMap<WebSocket, UserContext>(); // type-safe per-connection metadata

const server = createServer();
const wss = new WebSocketServer({ noServer: true });

// Auth on upgrade
server.on('upgrade', (req, socket, head) => {
  authenticateRequest(req)
    .then((user) => {
      wss.handleUpgrade(req, socket, head, (ws) => {
        connMeta.set(ws, user);
        wss.emit('connection', ws, req);
      });
    })
    .catch(() => {
      socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
      socket.destroy();
    });
});

wss.on('connection', (ws, req) => {
  const user = connMeta.get(ws)!;
  setupHeartbeat(ws);
  roomManager.join(`user:${user.id}`, ws);

  ws.on('message', (data) => {
    const msg = JSON.parse(data.toString());
    const parsed = messageSchema.safeParse(msg);
    if (!parsed.success) {
      ws.send(JSON.stringify({ type: 'error', payload: { message: 'Invalid message' } }));
      return;
    }
    handleMessage(ws, parsed.data);
  });

  ws.on('close', () => {
    roomManager.disconnected(ws);
    presenceManager.setOffline(user.id);
  });
});

server.listen(8080);
```
