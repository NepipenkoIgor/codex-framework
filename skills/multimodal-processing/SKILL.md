---
name: multimodal-processing
description: Implement image processing, OCR Vision, audio transcription, video processing with FFmpeg, and image generation with DALL-E or Stable Diffusion
metadata:
  version: 1.4
  argument-hint: "input modalities (image/audio/video/text), model provider, output format, scale"
---

Implement multimodal processing for $ARGUMENTS.

## Tool Integration

- **browser automation** — capture screenshots for visual verification and regression testing

## Pipeline Architecture

```
Media Upload -> Quarantine Storage -> Processing Queue -> Processing Worker
  -> Validate -> Moderate -> Process -> Store variants -> Notify
```

### Processing Job Data Model

```
MediaJob {
  id: uuid
  type: enum (image, audio, video, document)
  source_url: string
  status: enum (queued, processing, completed, failed)
  progress: integer (0-100)
  operations: jsonb
  result: jsonb (nullable)
  error: text (nullable)
  attempts: integer
  started_at, completed_at, created_at: timestamptz
}
```

## Image Processing

### Sharp (Node.js)

```typescript
import sharp from 'sharp';

async function processImage(input: Buffer, ops: ImageOperations): Promise<ProcessedImage> {
  let pipeline = sharp(input).rotate().withMetadata({ orientation: undefined });

  if (ops.resize) {
    pipeline = pipeline.resize(ops.resize.width, ops.resize.height, {
      fit: ops.resize.fit ?? 'inside', withoutEnlargement: true,
    });
  }

  const formatMap = { webp: { quality: 80 }, avif: { quality: 65 }, jpeg: { quality: 80, mozjpeg: true } };
  pipeline = pipeline[ops.format ?? 'jpeg'](formatMap[ops.format ?? 'jpeg']);

  const output = await pipeline.toBuffer({ resolveWithObject: true });
  return { buffer: output.data, width: output.info.width, height: output.info.height, format: output.info.format, size: output.info.size };
}

// Generate variants: thumb (200x200 cover), medium (800w), large (1920w)
async function generateImageVariants(input: Buffer): Promise<ImageVariants> {
  const [thumb, medium, large] = await Promise.all([
    processImage(input, { resize: { width: 200, height: 200, fit: 'cover' }, format: 'webp', quality: 75 }),
    processImage(input, { resize: { width: 800 }, format: 'webp', quality: 80 }),
    processImage(input, { resize: { width: 1920 }, format: 'webp', quality: 85 }),
  ]);
  return { thumb, medium, large };
}
```

### Cloudinary (SaaS)

- Upload with `cloudinary.uploader.upload()` with transformation chains
- URL-based transforms via `cloudinary.url()` for on-the-fly resizing
- Enable `moderation: 'aws_rek'` for content moderation

### Blurhash

```typescript
import { encode } from 'blurhash';
const { data, info } = await sharp(input).resize(32, 32, { fit: 'inside' }).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
return encode(new Uint8ClampedArray(data), info.width, info.height, 4, 3);
```

## OCR (Optical Character Recognition)

| Provider | Best for | Languages | Cost |
|----------|----------|-----------|------|
| Google Cloud Vision | General OCR, handwriting | 100+ | Per-image |
| AWS Textract | Forms, tables, structured docs | 6 | Per-page |
| Tesseract.js | Self-hosted, offline | 100+ | Free |

### Google Cloud Vision

```typescript
const [result] = await visionClient.textDetection(imageUrl);
const fullText = result.textAnnotations?.[0]?.description ?? '';
// Individual words with bounding boxes in remaining annotations
```

### AWS Textract — for structured documents (tables, forms)

```typescript
const command = new AnalyzeDocumentCommand({
  Document: { S3Object: { Bucket: bucket, Name: key } },
  FeatureTypes: ['TABLES', 'FORMS'],
});
```

### Tesseract.js — self-hosted, no API cost

```typescript
const { data } = await Tesseract.recognize(imageBuffer, lang);
```

## Audio Transcription

| Provider | Best for | Real-time | Cost |
|----------|----------|-----------|------|
| OpenAI Whisper API | General, high quality | No (batch) | Per-minute |
| Deepgram | Real-time, enterprise | Yes | Per-minute |
| AssemblyAI | Transcription + analysis | Yes | Per-minute |

### OpenAI Whisper API

```typescript
const transcription = await openai.audio.transcriptions.create({
  file: fs.createReadStream(filePath),
  model: 'whisper-1',
  language: options?.language,
  response_format: 'verbose_json',
  timestamp_granularities: ['word', 'segment'],
});
// Returns: text, language, duration, segments[{start, end, text}], words[{start, end, word}]
```

### Deepgram — batch and real-time

Batch: `deepgram.listen.prerecorded.transcribeUrl()` with diarize, paragraphs, utterances.
Real-time: `deepgram.listen.live()` with WebSocket, interim_results.

### Audio Rules

- Max 25MB for Whisper API; chunk long audio (>10 min) with overlap
- Support: mp3, mp4, m4a, wav, webm, flac, ogg
- Store both original audio and transcription with timestamps

## Video Processing (FFmpeg)

```typescript
import ffmpeg from 'fluent-ffmpeg';

// Extract metadata
ffmpeg.ffprobe(inputPath, (err, metadata) => {
  // duration, width, height, codec, bitrate, fps, hasAudio, fileSize
});

// Transcode
ffmpeg(inputPath).output(outputPath)
  .videoCodec('libx264').audioCodec('aac')
  .size(`${maxWidth}x?`).videoBitrate(bitrate)
  .on('progress', (p) => { /* p.percent */ })
  .on('end', resolve).on('error', reject).run();

// Extract thumbnail at timestamp
ffmpeg(inputPath).screenshots({ timestamps: [timestamp], filename: 'thumb.jpg', folder: outputPath, size: '640x360' });

// Extract audio track for transcription
ffmpeg(inputPath).noVideo().audioCodec('libmp3lame').audioBitrate('128k').output(outputPath);
```

### Video Pipeline

```
Upload -> Metadata -> Content Moderation (frame sampling) -> Parallel:
  Transcode (H.264 MP4, WebM) | HLS/DASH variants | Thumbnails | Extract audio | Transcribe
  -> Store + CDN delivery
```

## Image Generation

### DALL-E 3

```typescript
const response = await openai.images.generate({
  model: 'dall-e-3', prompt, n: 1,
  size: '1024x1024', quality: 'hd', style: 'natural',
});
// Returns: url, revised_prompt
```

### Stable Diffusion (Stability AI API)

POST to `api.stability.ai` with text_prompts (positive + negative weights), cfg_scale, width, height, steps, seed.

### Generation Rules

- Store prompt + generated image + parameters (seed, model, steps) for reproducibility
- Cache by prompt hash to avoid duplicate generation costs
- Rate limit per user; queue requests (do not process synchronously)
- Run content moderation on generated images before serving

## Content Moderation

```
Media Input -> Pre-Moderation:
  Image: AWS Rekognition / Google Vision Safety
  Text: OpenAI Moderation API
  Video: sample frames + image moderation
  Audio: transcribe + text moderation
-> Safe: proceed | Uncertain: human review | Unsafe: reject + log + alert
```

Categories: nudity/sexual, violence, hate speech, self-harm, illegal, spam, PII.

## Async Queue Patterns

```typescript
const mediaWorker = new Worker('media-processing', async (job) => {
  const { type, sourceUrl, operations } = job.data;
  await job.updateProgress(0);
  switch (type) {
    case 'image': return await processImageJob(sourceUrl, operations, job);
    case 'audio': return await processAudioJob(sourceUrl, operations, job);
    case 'video': return await processVideoJob(sourceUrl, operations, job);
    case 'document': return await processDocumentJob(sourceUrl, operations, job);
  }
}, { connection: redisConnection, concurrency: 3, limiter: { max: 10, duration: 60000 } });
```

### Resource Limits

| Media type | Memory | Concurrency | Timeout |
|------------|--------|-------------|---------|
| Image (<10MB) | 256MB | 5-10 | 30s |
| Image (>10MB) | 512MB | 2-5 | 60s |
| Audio (<100MB) | 512MB | 3-5 | 5 min |
| Video (any) | 1-4GB | 1-2 | 30 min |
| Document OCR | 256MB | 5 | 60s |

- Use separate queues per media type to prevent blocking
- Stream large files; clean up temp files in try/finally

## CDN Delivery

- Store in S3/R2/GCS; serve via CDN with `max-age=31536000, immutable` for hashed URLs
- Serve WebP/AVIF with JPEG fallback; HLS/DASH for adaptive video
- Content-hashed filenames for cache-busting

## Anti-Patterns

- Single queue for all media types — a stuck video job blocks image processing; use separate queues per type
- No magic byte validation on upload — MIME type is user-supplied; validate actual file headers before processing
- Storing only processed variants without the original — reprocessing with new formats or params requires re-upload
- Synchronous transcription for audio >1 min — Whisper API has a 25MB limit and timeouts; always chunk and queue

## Output Format

```
Media Types:   [image, audio, video, document]
Queue:         [BullMQ / Hangfire / SQS]
Image:         [tool, variants, formats, blurhash]
Audio:         [provider, languages, features]
Video:         [tool, output formats, thumbnails]
Moderation:    [provider, categories, flow]
CDN:           [provider]
```

## Done Criteria

- Media processes asynchronously via queue with progress tracking
- Image variants in modern formats (WebP/AVIF) with fallbacks
- OCR extracts text with bounding box data
- Audio transcription produces timestamped text
- Video generates web-compatible formats and thumbnails
- Content moderation runs on all user uploads before public access
- Large files stream without memory exhaustion
- CDN delivers processed media with proper caching
- Temporary files cleaned up; failed jobs retry with backoff and DLQ
