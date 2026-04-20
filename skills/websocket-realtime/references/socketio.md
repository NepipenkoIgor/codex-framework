# Socket.IO (Node.js)

```typescript
import { Server } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import Redis from 'ioredis';

const io = new Server(httpServer, {
  cors: { origin: ALLOWED_ORIGINS },
  pingInterval: 25000,
  pingTimeout: 10000,
  maxHttpBufferSize: 1e6, // 1MB max message size
});

// Redis adapter for multi-server
const pubClient = new Redis(REDIS_URL);
const subClient = pubClient.duplicate();
io.adapter(createAdapter(pubClient, subClient));

// Auth middleware
io.use(async (socket, next) => {
  try {
    const token = socket.handshake.auth.token;
    const user = await validateToken(token);
    socket.data.user = user;
    next();
  } catch {
    next(new Error('Authentication failed'));
  }
});

// Namespace for chat
const chat = io.of('/chat');
chat.on('connection', (socket) => {
  const user = socket.data.user;

  socket.on('join-room', async (roomId: string) => {
    if (await canJoinRoom(user.id, roomId)) {
      socket.join(roomId);
      socket.to(roomId).emit('user-joined', { userId: user.id });
    }
  });

  // Acknowledgment for reliable delivery
  socket.on('message', (data, ack) => {
    const msg = { ...data, userId: user.id, timestamp: Date.now() };
    saveMessage(msg).then(() => {
      socket.to(data.roomId).emit('message', msg);
      ack({ status: 'ok', id: msg.id });
    });
  });

  socket.on('disconnect', () => {
    presenceManager.setOffline(user.id);
  });
});
```

## Key Socket.IO Features

- Namespaces for feature isolation (`/chat`, `/notifications`)
- Rooms for group messaging (`socket.join('room-123')`)
- Acknowledgments for reliable delivery (`socket.emit('msg', data, ack)`)
- Automatic reconnection with configurable backoff
- Binary support via Buffer/ArrayBuffer
- Redis adapter for multi-server: `@socket.io/redis-adapter`
