---
name: multimodal-processing
description: Implement ingestion and processing pipelines for user-supplied images, documents, audio, or video, including validation, OCR or transcription, transcoding, moderation, queues, storage, and delivery. Use when media becomes application data; do not use to generate or edit creative raster assets, optimize webpage image rendering alone, or operate adaptive video playback alone.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "media types, sources, outputs, scale, provider and safety constraints"
---

Implement the media-data pipeline in `$ARGUMENTS`.

## Boundaries

- Native `imagegen` owns creative image generation and editing.
- `image-optimization` owns browser image rendering and delivery.
- `video-streaming` owns playback manifests, adaptive bitrate, and player operation.
- This skill owns untrusted-media ingestion, transformation, extraction, moderation, persistence, and application delivery.

## Workflow

1. Generate project stack context and inspect input sources, trust boundary, MIME/signature validation, size/duration/dimension/frame constraints, embedded metadata, PII/biometric/sensitive-content classes, privacy and rights, installed runtime decoder/transcoder capability, existing processor adapters, provider SDK/model and region constraints, downstream consumer schema, retention, and the exact queue payload/concurrency/backlog plus object-storage size/quota/lifecycle capacity limits as one compatibility unit. Provider support is not compatible unless the queue and storage boundaries can accept and retain the selected media contract.
2. Define canonical media identity, accepted formats/capabilities, synchronous versus queued processing, idempotency, intermediate artifacts, provenance, moderation/quarantine, and failure/retry states.
3. Isolate parsers/transcoders with least privilege, bounded CPU/memory/time/output, exact task-owned temporary paths, egress restrictions, malware/decompression-bomb defenses, and metadata minimization.
4. Resolve current provider upload/request, media, duration, page/frame, token/context and output caps plus supported models/formats only when needed from installed SDKs and official documentation. Record consent, rights and source provenance for every outbound provider-processing action. Store the verified capability contract in a versioned processor adapter or runtime configuration that enforces the compatible subset before upload; keep provider model/cap/format matrices out of general application source and reusable skill prose.
5. Make durable state transitions and object writes idempotent. Authorize tenant/subject access to source and every derivative independently.
6. Verify spoofed MIME, malformed/decompression or pixel/frame bomb payload, malicious metadata, duplicate/replay, provider-cap rejection, timeout/crash, partial upload, moderation failure, cross-tenant access, cancellation/cleanup, retention/deletion, and output quality on representative fixtures. Inject classified PII and prove it is minimized or denied independently in logs, metrics, traces, queue payloads, errors and outbound provider requests.

## Output

Report media contracts, trust and rights assumptions, pipeline/state model, resource and safety bounds, provider capability evidence, exact queue and storage capacity-limit decisions, storage/retention, executable fixtures and checks, quality results, and residual external risk.
