# Collaborative Editing Patterns

## Conflict Resolution Approaches

| Approach | Complexity | Best for |
|----------|-----------|----------|
| Last-write-wins (LWW) | Simple | Single-field edits, settings, toggles |
| Operational Transform (OT) | High | Rich text editors (Google Docs approach) |
| CRDT | Medium-High | Text, lists, maps (offline-first, peer-to-peer) |
| Event sourcing + merge | Medium | Document sections, structured data |

## CRDT Overview

CRDTs guarantee convergence -- all replicas reach the same state regardless of message ordering or network partitions.

Relevant CRDT types:
- **G-Counter / PN-Counter**: distributed counters (likes, votes, view counts)
- **LWW-Register**: single value with timestamp-based conflict resolution
- **OR-Set** (Observed-Remove Set): add/remove elements without conflicts
- **RGA** (Replicated Growable Array): ordered list for text editing

Production libraries:
- **Yjs**: excellent, widely used, supports rich text, awareness protocol for cursors
- **Automerge**: Rust-backed, supports JSON-like documents, good for structured data

```typescript
// Yjs collaborative text editing with WebSocket
import * as Y from 'yjs';
import { WebsocketProvider } from 'y-websocket';

const ydoc = new Y.Doc();
const provider = new WebsocketProvider('wss://api.example.com', 'doc-123', ydoc);
const ytext = ydoc.getText('content');

// Changes automatically sync between all connected clients
// Yjs handles conflict resolution, undo/redo, and offline support

// Awareness for cursors and selections
const awareness = provider.awareness;
awareness.setLocalState({
  user: { name: currentUser.name, color: '#e91e63' },
  cursor: { index: 42, length: 0 },
});

awareness.on('change', () => {
  const states = awareness.getStates();
  // Render remote cursors with user names and colors
});
```

## OT Overview

- Server transforms concurrent operations to maintain consistency
- Operations: insert(position, text), delete(position, length), retain(count)
- Server is the authority -- transforms client operations against server history
- More complex than CRDTs but proven at scale (Google Docs)
- Libraries: ShareDB (Node.js), ot.js

## When to Use Which

- Yjs/Automerge (CRDT): new projects, offline-first, simpler mental model
- OT/ShareDB: existing server-authoritative architecture, proven at Google-scale
