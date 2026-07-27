# Video upload, encoding and delivery guide

Use only the sections required by the selected storage, codec, protocol, provider and player. Verify installed SDK/CLI/API capability against current vendor documentation before copying a field or command.

## Multipart upload integrity

Create an upload for the exact quarantined object key and persist its provider upload ID. Bound part size/count according to current provider capability. For each part, calculate any requested checksum, upload exact bytes, and persist `(upload_id, part_number, byte_range, checksum, returned_etag)` only after success. Retries reuse the same part number and compare returned identity. Complete using the complete ordered list of provider-returned part ETags. Reconcile timeout-after-complete by listing/head/checksum rather than starting another upload blindly. Abort an abandoned upload by exact ID only after resolving the production target, explicit mutation authority/permissions, operational owner, dependent catalog/job effects, retention decision, and recovery or forward-fix; otherwise report it for authorized cleanup without mutating the provider.

Multipart ETags are provider-specific opaque validators and may depend on encryption, checksum mode or implementation. Do not reconstruct them with a universal MD5 formula. Use provider checksum APIs when end-to-end integrity is required.

## Input validation

Treat extension, browser MIME and upload metadata as hints. Store outside the public namespace, cap bytes early, inspect magic/container, probe all streams, and perform a bounded decode sample in a sandbox. Enforce approved container/codec/track count/duration/resolution/frame-rate/bitrate/encryption policies. Reject malformed indexes, extreme dimensions/duration, decompression ratios, parser/decoder crashes, unexpected executable/archive content and unsupported encrypted streams. Patch media libraries and isolate transcoders.

## Ladder and packaging

Start from source probes and playback workload. Never upscale or exceed useful source fidelity. Test candidate codecs/rungs using perceptual/visual quality, encode time, device decode support, startup, switches, rebuffer, bytes and cost on representative content. Derive bitrate/resolution/rate-control choices from those results.

Align independently decodable segment boundaries and rendition timelines. Derive GOP/keyframe and segment/part duration from target latency, encoder scene-cut behavior, CDN request overhead, manifest size, player buffer and seeking. Verify alignment with media tools and real players; do not prescribe universal 2/6-second segments, two-pass encoding, or mandatory 360p/720p rungs.

Choose HLS/DASH/CMAF, codecs, encryption and low-latency extensions only when current encoder, packager, CDN and target players expose compatible capabilities. Provider examples are optional adapters, not architecture defaults.

## Delivery authorization and caching

Version immutable VOD manifests/segments and cache them appropriately. Treat live manifests/windows and authorization-bearing responses as mutable/private unless the CDN design proves safe keying. Include tenant/asset/version/permissions in the authorization decision and keep signing secrets server-side. Rotate a secret only after the main workflow resolves the exact target, authority, owner, dependent caches/sessions and recovery/rollback; reconcile the authorized effect afterward.

Model a playback session across initial manifest, child playlists, segments, seek backward/forward, pause/background and token refresh. Expiry should not break an authorized ordinary seek, while revoked or leaked credentials must have bounded reach. Test cache keys without auth leakage, signed query normalization, range requests, origin shielding, expired manifests with cached segments, and seek across expiry.

## Accessibility and player evidence

Choose caption/subtitle/transcript/audio-description and alternate-media behavior from content type, jurisdiction/product policy and supported player/platform. Validate track accuracy, timing, language/label, default selection, keyboard controls, focus, visible focus, status/error announcements, reduced motion/autoplay policy and fallback when JavaScript or a codec fails.

## Capability sources

- HLS: `https://developer.apple.com/streaming/`
- DASH-IF guidelines: `https://dashif.org/guidelines/`
- AWS S3 multipart completion semantics: `https://docs.aws.amazon.com/AmazonS3/latest/userguide/mpuoverview.html`
- Cloudflare Stream docs: `https://developers.cloudflare.com/stream/`
- Mux video docs: `https://www.mux.com/docs/guides/video`

Use only the provider source matching the repository. Re-check payload, limit, checksum, signing, codec and player capability at execution time.
