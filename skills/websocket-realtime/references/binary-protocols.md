# Binary realtime protocols

Choose binary encoding only when measured payload, CPU, bandwidth or interoperability needs justify its schema and tooling cost. Verify the installed serializer/runtime and current official specification; JSON may remain the safer operational choice.

- Define an explicit frame contract with protocol version, message type, stable message ID, tenant/resource or stream scope, declared length/checksum where useful, and payload schema.
- Before allocation or decode, validate minimum header length, declared length against the received buffer, configured payload limit, supported version/type, and compression/decompression bounds.
- Treat binary fields as untrusted. Reject trailing/duplicate data, invalid enum/tag values, malformed UTF or numeric overflow according to the selected codec.
- Preserve unknown-field and old/new schema behavior deliberately. Generated codec code is pinned and reviewed with schema changes.
- Compression can amplify memory/CPU and side channels; enable only with measured benefit and bounded output/resource policy.
- Do not infer ordering or delivery from framing. Apply the main protocol's authorization, sequence/cursor, acknowledgement, idempotency, resume and backpressure contract independently.

Verify truncated/oversized/length-mismatch frames, unsupported versions/types, corrupted and compressed bombs, fuzz/property cases, old/new codec pairs, wrong-tenant scope, duplicate IDs, fragmentation/reassembly and slow-consumer pressure. Compare representative encoded size and end-to-end CPU/latency before adoption.
