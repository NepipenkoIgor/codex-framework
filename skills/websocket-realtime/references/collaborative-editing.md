# Collaborative editing

Select OT, CRDT or a simpler authoritative revision model from the product's conflict, offline, latency, document-size and audit requirements. Do not choose Yjs, Automerge or another library from remembered popularity; verify installed capability and current protocol documentation.

- Authenticate the connection and authorize every document join, update, awareness event and snapshot by server-derived actor, tenant and document. Namespace rooms with opaque server-owned scope; a guessable document ID is not authority.
- Define operation/update identity, causal or version context, validation, maximum document/update/awareness size, rate and backpressure.
- Convergence claims depend on valid operations, compatible schema/runtime and eventual delivery under the chosen algorithm. Partitions, rejected updates and version skew need explicit recovery.
- Persist durable update history or snapshots with compaction, corruption recovery, migration and retention. Ephemeral awareness/presence is separate and must expire/clean up.
- Offline editing, undo/redo and conflict presentation are product features with explicit semantics; a CRDT library does not supply the full contract automatically.
- Reconnect from an authoritative state vector/version, detect history outside retention, and reset from a snapshot when replay is unsafe.

Verify concurrent/offline edits, duplicate/reordered/missing updates, wrong-document and wrong-tenant access, revocation, schema/runtime skew, corrupt update, compaction/snapshot restore, reconnect outside retention, slow consumers, presence cleanup and deterministic user-visible conflict behavior.
