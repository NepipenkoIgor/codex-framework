# Binary Protocol Patterns

## When to Use Binary

- High-frequency updates (60+ messages/sec): game state, sensor data, live audio/video metadata
- Large payloads where JSON overhead matters (>10KB per message)
- Bandwidth-constrained environments (mobile data, IoT)

## ArrayBuffer with DataView

```typescript
// Binary message format: [type: uint8][seq: uint32][payloadLength: uint32][payload: bytes]
// Header: 9 bytes total

// Encoding
function encodeMessage(type: number, seq: number, payload: Uint8Array): ArrayBuffer {
  const buffer = new ArrayBuffer(9 + payload.byteLength);
  const view = new DataView(buffer);
  view.setUint8(0, type);              // message type (0-255)
  view.setUint32(1, seq, false);       // sequence number (big-endian)
  view.setUint32(5, payload.byteLength, false); // payload length
  new Uint8Array(buffer, 9).set(payload);
  return buffer;
}

// Decoding
function decodeMessage(buffer: ArrayBuffer): { type: number; seq: number; payload: Uint8Array } {
  const view = new DataView(buffer);
  return {
    type: view.getUint8(0),
    seq: view.getUint32(1, false),
    payload: new Uint8Array(buffer, 9, view.getUint32(5, false)),
  };
}

// WebSocket binary mode
ws.binaryType = 'arraybuffer';
ws.onmessage = (event) => {
  if (event.data instanceof ArrayBuffer) {
    const msg = decodeMessage(event.data);
    // handle binary message
  }
};
```

## Protocol Buffers (Protobuf)

- Define message schemas in `.proto` files -- shared between client and server
- Compile to TypeScript/JavaScript with `protobufjs` or `ts-proto`
- 2-10x smaller than JSON for structured data
- Schema evolution with field numbers -- add fields without breaking existing clients
- Use when message structure is stable and performance matters

```protobuf
syntax = "proto3";

message WsEnvelope {
  uint32 type = 1;
  uint64 sequence = 2;
  uint64 timestamp = 3;
  bytes payload = 4;
}

message CursorPosition {
  string user_id = 1;
  string document_id = 2;
  float x = 3;
  float y = 4;
}
```

## MessagePack

- JSON-compatible binary format -- schema-less like JSON but binary-encoded
- Smaller than JSON, no `.proto` files needed
- Good middle ground: easier than Protobuf, more compact than JSON
- Libraries: `@msgpack/msgpack` (JS), `MessagePack` (.NET)

## When JSON Is Fine

- Chat messages, notifications, presence updates
- Low-frequency updates (<10 messages/second)
- When debuggability matters more than bandwidth
