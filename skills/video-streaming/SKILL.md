---
name: video-streaming
description: Implement video streaming — adaptive bitrate (HLS/DASH), player setup, transcoding, thumbnail generation, CDN delivery, and access control
metadata:
  version: 1.5
  argument-hint: "protocol (HLS/DASH), player library, transcoding needs, access control (public/private), CDN"
---

Implement video streaming for $ARGUMENTS.

## Tool Integration

- **browser automation** — capture screenshots for visual verification and regression testing

## Platform Decision

| Platform | Trade-offs | Cost | Complexity |
|----------|-----------|------|------------|
| Mux | Best DX, managed transcoding, analytics, signed URLs | Per-minute pricing (encoding + delivery) | Low |
| Cloudinary | Good for mixed media (images + video), URL-based transforms | Per-credit pricing, can get expensive at scale | Low-Medium |
| Self-hosted (FFmpeg + S3 + CDN) | Full control, no vendor lock-in | Infrastructure cost only | High |
| AWS MediaConvert + CloudFront | AWS-native, scalable, pay-per-minute | Per-minute encoding + CloudFront delivery | Medium-High |
| Bunny Stream | Budget-friendly, simple API, built-in CDN | Per-minute storage + bandwidth | Low |


## Adaptive Bitrate Streaming

### HLS (HTTP Live Streaming)

- Industry standard, supported by all browsers (via hls.js for non-Safari) and mobile devices natively
- Segments video into small `.ts` or `.fmp4` chunks (2-10 seconds each)
- Master playlist (`.m3u8`) references variant playlists at different bitrates
- Client automatically switches quality based on network conditions
- Use HLS for: web applications, mobile apps, general-purpose streaming

### DASH (Dynamic Adaptive Streaming over HTTP)

- Open standard (ISO/IEC 23009-1), no licensing fees
- Uses `.mpd` manifest and `.m4s` segments
- Better DRM integration with Widevine
- Use DASH for: DRM-required content, applications needing Widevine, Android-first products

### When to use which

| Scenario | Protocol | Why |
|----------|----------|-----|
| General web/mobile | HLS | Universal support, simple |
| DRM with Widevine | DASH or HLS with fMP4 | Widevine requires CENC |
| Apple ecosystem | HLS | Native support, required for App Store |
| Low latency (<3s) | LL-HLS or LL-DASH | Reduced segment duration + partial segments |
| Legacy browsers | Progressive MP4 | Fallback for no-JS environments |

### Resolution Ladder (Encoding Presets)

| Label | Resolution | Bitrate (video) | Bitrate (audio) | Use case |
|-------|-----------|-----------------|-----------------|----------|
| 240p | 426x240 | 400 kbps | 64 kbps | Mobile on 3G |
| 360p | 640x360 | 800 kbps | 96 kbps | Mobile on 4G |
| 480p | 854x480 | 1.4 Mbps | 128 kbps | Standard mobile |
| 720p | 1280x720 | 2.8 Mbps | 128 kbps | Desktop default |
| 1080p | 1920x1080 | 5 Mbps | 192 kbps | Full HD |
| 1440p | 2560x1440 | 8 Mbps | 192 kbps | High-end |
| 4K | 3840x2160 | 14 Mbps | 256 kbps | Premium content |

Rules: Always include 360p + 720p; skip upscaling; use 2-pass encoding; segment duration: 6s VOD, 2-4s low-latency

## Video Player Setup

### Video.js (Primary)

```typescript
import videojs from 'video.js';
import 'video.js/dist/video-js.css';

const player = videojs('my-video', {
  controls: true,
  autoplay: false,
  preload: 'metadata',
  fluid: true,
  responsive: true,
  playbackRates: [0.5, 1, 1.25, 1.5, 2],
  sources: [{ src: 'https://stream.example.com/video.m3u8', type: 'application/x-mpegURL' }],
  html5: { vhs: { overrideNative: true, enableLowInitialPlaylist: true } },
});

player.on('error', (e) => { /* handle playback errors */ });
player.on('ended', () => { /* track completion */ });
```

- Built-in HLS via VHS, plugins (quality selector, thumbnails, analytics), full a11y

### Alternative players

- **hls.js** (~40KB) — lightweight, custom UI; check `Hls.isSupported()` first; skip on Safari (plays HLS natively); handle fatal errors with `hls.startLoad()` (network) / `hls.recoverMediaError()` (media)
- **Shaka Player** — DASH + HLS, built-in DRM (Widevine/FairPlay/PlayReady); use when multi-protocol or DRM required
- **Native `<video>`** — MP4 fallback for short clips (<5 min) or internal tools; no ABR

## Video Upload Flow

### Chunked Upload with Progress

```typescript
interface VideoUploadConfig {
  file: File;
  chunkSize: number;       // 5MB default
  onProgress: (percent: number) => void;
  onComplete: (videoId: string) => void;
  onError: (error: Error) => void;
  signal?: AbortSignal;
}

async function uploadVideo(config: VideoUploadConfig): Promise<void> {
  // Step 1: Initialize upload -- get upload ID and presigned URLs
  const { uploadId, parts } = await api.post('/api/videos/upload/init', {
    fileName: config.file.name,
    fileSize: config.file.size,
    contentType: config.file.type,
  });

  // Step 2: Upload chunks in parallel (max 3 concurrent)
  const chunkCount = Math.ceil(config.file.size / config.chunkSize);
  let completedChunks = 0;

  const uploadChunk = async (index: number) => {
    const start = index * config.chunkSize;
    const end = Math.min(start + config.chunkSize, config.file.size);
    const chunk = config.file.slice(start, end);

    await fetch(parts[index].presignedUrl, {
      method: 'PUT',
      body: chunk,
      signal: config.signal,
    });

    completedChunks++;
    config.onProgress(Math.round((completedChunks / chunkCount) * 100));
  };

  // Parallel upload with concurrency limit
  const pool = new Set<Promise<void>>();
  for (let i = 0; i < chunkCount; i++) {
    const p = uploadChunk(i).then(() => { pool.delete(p); });
    pool.add(p);
    if (pool.size >= 3) await Promise.race(pool);
  }
  await Promise.all(pool);

  // Step 3: Complete upload -- trigger processing
  const { videoId } = await api.post('/api/videos/upload/complete', {
    uploadId,
    parts: parts.map((p, i) => ({ partNumber: i + 1, eTag: p.eTag })),
  });

  config.onComplete(videoId);
}
```

Validate `file.type` and `file.size` (max 5GB); always re-validate server-side.

## Transcoding

### FFmpeg Basics

```typescript
import ffmpeg from 'fluent-ffmpeg';

// Transcode to HLS with multiple quality levels
function transcodeToHLS(inputPath: string, outputDir: string): Promise<void> {
  return new Promise((resolve, reject) => {
    ffmpeg(inputPath)
      .outputOptions([
        '-preset fast',
        '-g 48', '-keyint_min 48', '-sc_threshold 0',
        '-hls_time 6', '-hls_playlist_type vod',
        '-hls_segment_filename', `${outputDir}/%v/segment_%03d.ts`,
        '-master_pl_name master.m3u8',
        '-map 0:v:0', '-map 0:a:0', '-map 0:v:0', '-map 0:a:0', '-map 0:v:0', '-map 0:a:0',
        '-var_stream_map', 'v:0,a:0 v:1,a:1 v:2,a:2',
        // 360p
        '-filter:v:0', 'scale=640:360', '-b:v:0', '800k', '-maxrate:v:0', '856k', '-bufsize:v:0', '1200k',
        // 720p
        '-filter:v:1', 'scale=1280:720', '-b:v:1', '2800k', '-maxrate:v:1', '2996k', '-bufsize:v:1', '4200k',
        // 1080p
        '-filter:v:2', 'scale=1920:1080', '-b:v:2', '5000k', '-maxrate:v:2', '5350k', '-bufsize:v:2', '7500k',
      ])
      .output(`${outputDir}/master.m3u8`)
      .on('progress', (progress) => { /* report progress.percent */ })
      .on('end', resolve)
      .on('error', reject)
      .run();
  });
}
```

### Codec Selection

| Codec | Browser support | Quality/size | Encoding speed | Use when |
|-------|----------------|-------------|----------------|----------|
| H.264 (AVC) | Universal | Good | Fast | Default, maximum compatibility |
| H.265 (HEVC) | Safari, some Android | 25-50% smaller than H.264 | Slow | Apple ecosystem, bandwidth savings |
| VP9 | Chrome, Firefox, Edge | Similar to H.265 | Slow | YouTube-style, royalty-free |
| AV1 | Modern browsers | 30-50% smaller than H.264 | Very slow | Future-proof, cost savings at scale |

Default H.264; add VP9/AV1 for modern browsers; use hardware encoding; use AAC audio

## Thumbnail Extraction

### FFmpeg Thumbnail Generation

```typescript
// Extract single thumbnail at timestamp
async function extractThumbnail(inputPath: string, timestamp: number, outputPath: string): Promise<void> {
  return new Promise((resolve, reject) => {
    ffmpeg(inputPath).seekInput(timestamp).frames(1).size('640x360')
      .output(outputPath).on('end', resolve).on('error', reject).run();
  });
}

// Generate selection set: evenly spaced across duration
async function generateThumbnailSet(inputPath: string, outputDir: string, count = 8): Promise<string[]> {
  const { duration } = await getVideoMetadata(inputPath);
  const interval = duration / (count + 1);
  const paths: string[] = [];
  for (let i = 1; i <= count; i++) {
    const path = `${outputDir}/thumb_${i}.jpg`;
    await extractThumbnail(inputPath, interval * i, path);
    paths.push(path);
  }
  return paths;
}
```

Generate sprite sheet with FFmpeg, pair with WebVTT mapping time ranges to xywh regions for timeline hover preview

## Mux Integration

### Upload API

```typescript
import Mux from '@mux/mux-node';

const mux = new Mux({ tokenId: process.env.MUX_TOKEN_ID!, tokenSecret: process.env.MUX_TOKEN_SECRET! });

// Create direct upload URL (client uploads directly to Mux)
async function createDirectUpload(options?: { passthrough?: string }): Promise<{ uploadUrl: string; uploadId: string }> {
  const upload = await mux.video.uploads.create({
    cors_origin: process.env.APP_URL,
    new_asset_settings: {
      playback_policy: ['signed'],
      encoding_tier: 'smart',
      mp4_support: 'standard',
      passthrough: options?.passthrough,
    },
  });
  return { uploadUrl: upload.url, uploadId: upload.id };
}

// Get playback URL
function getPlaybackUrl(playbackId: string): string {
  return `https://stream.mux.com/${playbackId}.m3u8`;
}

// Generate signed playback URL for private videos
function getSignedPlaybackUrl(playbackId: string, expiresIn: number = 3600): string {
  const token = mux.jwt.signPlaybackId(playbackId, {
    type: 'video',
    expiration: `${expiresIn}s`,
  });
  return `https://stream.mux.com/${playbackId}.m3u8?token=${token}`;
}
```

Verify `mux-signature` header. Handle events: `video.asset.ready`, `video.asset.errored`, `video.upload.asset_created`, `video.asset.live_stream_completed`

## Live Streaming Basics

### RTMP Ingest -> HLS Output

```
Broadcaster (OBS, mobile app)
  -- RTMP --> Ingest Server (Mux, AWS IVS, self-hosted Nginx-RTMP)
  -- Transcode --> Multiple quality levels
  -- Package --> HLS/DASH segments
  -- Deliver --> CDN --> Viewers (HLS playback)
```

### Latency Modes

| Mode | Latency | Use case |
|------|---------|----------|
| Standard HLS | 15-30s | VOD-like experience, most reliable |
| Low-latency HLS (LL-HLS) | 2-5s | Interactive streams, Q&A |
| WebRTC | <1s | Real-time interaction, video calls |

### Mux Live Streaming

```typescript
// Create a live stream
const liveStream = await mux.video.liveStreams.create({
  playback_policy: ['public'],
  new_asset_settings: { playback_policy: ['public'] },
  latency_mode: 'low', // 'standard' | 'low' | 'reduced'
  reconnect_window: 60,
});

// Stream key: liveStream.stream_key (give to broadcaster)
// Playback: https://stream.mux.com/{liveStream.playback_ids[0].id}.m3u8
```

## Video Analytics

### Events to Track

| Event | When | Data |
|-------|------|------|
| `video.play` | Play button pressed | videoId, timestamp, quality |
| `video.pause` | Pause or leave viewport | videoId, watchedDuration, currentTime |
| `video.seek` | User seeks | videoId, fromTime, toTime |
| `video.quality_change` | ABR quality switch | videoId, fromQuality, toQuality, reason |
| `video.buffer` | Buffering starts/stops | videoId, bufferDuration, currentTime |
| `video.error` | Playback error | videoId, errorType, errorMessage |
| `video.complete` | Reached 95%+ of duration | videoId, totalWatchTime, completionRate |
| `video.engagement` | Every 10s of playback | videoId, currentTime, quality |

Collect `video.engagement` every 10s; aggregate to 5s buckets; display as colored bar under timeline. Mux provides built-in QoE, engagement, and real-time analytics.

## Accessibility

Use WebVTT format (`.vtt`) universally supported. Use `kind="captions"` for hearing-impaired, `kind="subtitles"` for translations. Auto-generate with Whisper API, then human-review for accuracy. Store alongside video with language metadata.

Provide separate audio track with `kind="descriptions"` for visually impaired users. Required for WCAG 2.1 Level AA.

Standard: space/enter (play/pause), arrows (seek), M (mute), F (fullscreen), C (captions), 0-9 (seek %). Video.js/Shaka provide by default.

## Performance

Use `preload="none"` for below-fold, `preload="metadata"` for above-fold. Generate poster from representative frame; serve WebP+JPEG fallback with blurhash placeholder. Link preload for critical manifest.

## DRM Basics

### When DRM is Needed

Use for: premium paid/licensed/exclusive content. Skip for: marketing/UGC/free educational (signed URLs suffice)

### DRM Systems

| DRM | Platform | Protocol |
|-----|----------|----------|
| Widevine | Chrome, Firefox, Edge, Android | DASH + CENC |
| FairPlay | Safari, iOS, macOS | HLS |
| PlayReady | Edge (legacy), Windows, Xbox | DASH + CENC |

Multi-DRM: detect browser, request license from provider (BuyDRM, PallyCon, Axinom); use DASH+CENC for Widevine/PlayReady, HLS+FairPlay for Apple

1-4 hour expiry signed URLs provide sufficient access control without DRM complexity; supported by Mux, CloudFront, most CDNs

iOS: AVPlayer (HLS native), `react-native-video` wraps both platforms. Background playback: iOS `audio` mode session, Android foreground Service. PiP: Web `requestPictureInPicture()`, native on iOS/Android. Offline: download HLS segments, encrypted + local license for DRM.

Avoid: single MP4 without ABR, synchronous transcoding in API handlers, discarding original after encoding, all quality levels for <30s clips, hls.js on Safari, upscaling, hardcoded CDN URLs, missing captions.

## Implementation Workflow

1. Choose platform (Mux, self-hosted, etc.) based on requirements and budget
2. Implement upload flow (chunked upload with progress tracking)
3. Set up transcoding pipeline (managed or FFmpeg-based) with resolution ladder
4. Configure adaptive streaming (HLS manifest with multiple quality levels)
5. Set up video player (Video.js, hls.js, or native) with quality selection
6. Generate thumbnails and sprite sheets for preview
7. Add captions support (VTT format, auto-generation with review)
8. Implement access control (signed URLs or DRM)
9. Add analytics (play, pause, seek, quality change, completion)
10. Configure CDN with proper caching for segments and manifests
11. Test on mobile devices (iOS Safari, Android Chrome) and slow networks

## Output Format

```
Platform:          [Mux / Cloudinary / self-hosted / AWS MediaConvert]
Streaming:         [HLS / DASH / progressive MP4]
Player:            [Video.js / hls.js / Shaka / native]
Upload:            [chunked with progress / direct to platform]
Transcoding:       [managed / FFmpeg pipeline]
Resolution Ladder: [quality levels with bitrates]
Thumbnails:        [extraction method, sprite sheet for preview]
Access Control:    [signed URLs / DRM / public]
Captions:          [VTT format, auto-generation approach]
Analytics:         [events tracked, engagement heatmap]
CDN:               [provider and caching strategy]
```

## Done Criteria

- Video uploads with chunked upload, progress tracking, and cancel support
- Transcoding produces multiple quality levels (at minimum 360p + 720p + 1080p)
- HLS manifest serves adaptive bitrate with automatic quality switching
- Player handles errors gracefully (network, codec, DRM)
- Thumbnails generated at representative timestamps
- Sprite sheet enables hover preview on timeline
- Captions available in at least the primary language
- Signed URLs or DRM prevent unauthorized access to paid content
- Analytics track play, pause, seek, buffering, completion, and quality changes
- CDN delivers segments with proper cache headers
- Playback works on Chrome, Safari, Firefox, iOS Safari, and Android Chrome
- Mobile: background playback and PiP supported where required
