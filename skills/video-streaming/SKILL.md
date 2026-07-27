---
name: video-streaming
description: Implement live or on-demand video ingest, multipart upload, transcoding, HLS/DASH packaging, delivery authorization, players, captions, and operations. Use for adaptive media delivery; do not use for ordinary downloadable files or generic multimodal processing.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.1
  argument-hint: "live/VOD, source probes, audience/device workload, latency, storage/CDN, captions and access"
---

# Video Streaming

Read [the encoding, upload and delivery guide](references/full-guide.md) only when concrete multipart, codec, packaging, CDN/player, or provider detail is needed.

## Workflow

1. Inspect repository/media/provider pins, matching installed-version official provider documentation, source probe data, upload path, audience devices/networks, live/VOD latency and seek behavior, content policy, accessibility scope, scale/cost and observability. Before any production containment or mutation, resolve the exact asset/object, catalog, manifest, CDN/cache and signing/credential targets, explicit production authority/permissions, operational owner and recovery/rollback for each action; do not disable, purge, remove or rotate first and justify it later.
2. Only after the target, authority, owner and recovery prerequisites above are resolved, quarantine untrusted input using the authorized reversible containment path. Bound upload bytes and duration, re-probe actual container/streams/codecs after upload, decode within CPU/memory/time limits, reject polyglots/decompression/decoder bombs, and never trust extension or client MIME alone.
3. For multipart upload, persist exact provider upload ID, part number, checksum and the opaque ETag returned by every successful part upload. Complete with the ordered provider-returned ETags, then verify completion/head/checksum according to current provider capability; never calculate multipart ETag as a plain MD5 assumption.
4. Derive codec/rendition ladder, GOP/keyframe alignment, segment/part duration and encoder settings from probed source quality, target device/codec support, network distribution, latency/startup/rebuffer goals, storage/egress/compute cost and measured trials. Do not mandate preset rungs or segment lengths.
5. Make ingest, upload, probe, transcode, caption, package, publish and delete states idempotent/resumable. A manifest becomes visible only with the authorized complete rendition set and rollback path.
6. Design manifest/segment/key/license authorization and CDN caching together. Signed URL/cookie expiry must cover playlist traversal and seeking without granting excessive replay; manifests and mutable live windows need different cache semantics from immutable versioned segments.
7. Test hostile/corrupt input, duplicate/omitted multipart part, completion ambiguity, retry/process death, partial rendition failure, codec fallback, bandwidth downgrade, seek near token expiry, cache leakage, captions/audio-description policy, and representative devices.

## Accessibility Boundary

Determine obligations from media type and approved accessibility policy. Prerecorded video with meaningful audio, live video, audio-only, silent video, user-generated media and decorative media can require different captions, transcripts, audio descriptions, controls and alternatives. Do not claim every asset universally requires one track format or WCAG technique; verify accuracy, synchronization, language metadata, keyboard/focus and player announcements for the scoped media.

## Output

Report source/workload evidence, upload integrity, pipeline/state machine, measured ladder/GOP/segment decisions, authorization/cache/expiry behavior, accessibility scope, device/network/provider tests, costs/SLOs, and unverified capability risk.
