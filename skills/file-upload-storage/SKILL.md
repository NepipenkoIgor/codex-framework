---
name: file-upload-storage
description: Implement file upload, storage, and retrieval using AWS S3, Azure Blob, GCS, or local storage for .NET, Node.js, or NestJS backends
metadata:
  version: 1.6
  argument-hint: "storage provider (S3/Azure/GCS), upload type (presigned/server-side), processing needs (image variants/OCR), retention policy"
---

Implement file handling for $ARGUMENTS.

## Documentation

> Use **available docs lookup tools or official docs** when you encounter unknown API syntax, current library versions, or framework-specific configuration. Do not rely on training data for library docs — fetch current docs on demand.

## Storage Selection

| Storage | Best for | Egress fees |
|---------|----------|-------------|
| AWS S3 | General purpose | Yes |
| Cloudflare R2 | Egress-heavy workloads | No |
| Azure Blob / GCS | Native ecosystem | Yes |
| MinIO | Self-hosted S3-compatible | N/A |

## Upload Patterns

### Direct Upload (Presigned URL) -- preferred

1. Client requests upload URL with file metadata (name, type, size)
2. Server validates metadata, generates presigned PUT URL (5-15 min expiry)
3. Client uploads directly to storage (bypasses server, saves bandwidth)
4. Client confirms upload; server validates file in storage, records metadata, triggers processing

Security: enforce content-type + content-length-range in conditions; per-user paths; log generation.

```
Conditions: [
  ["content-length-range", 0, 10485760],
  ["eq", "$Content-Type", "image/jpeg"],
  ["starts-with", "$key", "uploads/user-123/"]
], Expires: 900
```

#### Full Presigned URL Flow (Node.js / S3)

```typescript
// 1. Generate presigned URL
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

async function createUploadUrl(userId: string, contentType: string, contentLength: number) {
  // Validate before generating URL
  const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
  if (!allowedTypes.includes(contentType)) throw new BadRequestError('Unsupported file type');
  if (contentLength > 10 * 1024 * 1024) throw new BadRequestError('File too large (max 10MB)');

  const fileId = crypto.randomUUID();
  const key = `uploads/${userId}/${fileId}`;

  const command = new PutObjectCommand({
    Bucket: env.UPLOAD_BUCKET,
    Key: key,
    ContentType: contentType,
    ContentLength: contentLength,
    Metadata: { 'user-id': userId, 'original-name': 'sanitized' },
  });

  const uploadUrl = await getSignedUrl(s3, command, { expiresIn: 900 });

  // Record pending upload in DB
  await db.file.create({ id: fileId, key, userId, status: 'pending', contentType, size: contentLength });

  return { uploadUrl, fileId, expiresAt: new Date(Date.now() + 900_000) };
}

// 2. Confirm upload (client calls after upload completes)
async function confirmUpload(fileId: string, userId: string) {
  const file = await db.file.findUnique({ where: { id: fileId, userId } });
  if (!file || file.status !== 'pending') throw new NotFoundError();

  // Verify file exists in S3
  const head = await s3.send(new HeadObjectCommand({ Bucket: env.UPLOAD_BUCKET, Key: file.key }));
  if (!head.ContentLength) throw new BadRequestError('File not found in storage');

  // Move to processing
  await db.file.update({ where: { id: fileId }, data: { status: 'processing', size: head.ContentLength } });
  await queue.add('process-file', { fileId });
}
```

#### Presigned URL for Downloads

```typescript
async function getDownloadUrl(fileId: string, userId: string): Promise<string> {
  const file = await db.file.findUnique({ where: { id: fileId } });
  if (!file || !canAccess(userId, file)) throw new NotFoundError();

  const command = new GetObjectCommand({ Bucket: env.STORAGE_BUCKET, Key: file.key });
  return getSignedUrl(s3, command, {
    expiresIn: 3600,
    // Force download with original filename
    ResponseContentDisposition: `attachment; filename="${file.originalName}"`,
  });
}
```

### Server-Side Upload -- for small files (<10MB) needing sync validation

Stream to temp -> validate -> move to permanent. Never buffer entire file in memory.

### Resumable (Large Files)

- **S3 Multipart**: CreateMultipartUpload -> upload parts -> CompleteMultipartUpload. Set lifecycle to auto-abort after 24h.
- **tus Protocol**: open standard, resume after network failure. Use for mobile/unreliable networks.

## Security

### Validation (MANDATORY)

- Validate magic bytes -- NEVER trust extension or Content-Type alone
- Allowlist MIME types per context; enforce max size per type (images: 10MB, docs: 50MB, video: 500MB)
- Enforce at presigned URL, web server, and application levels
- Generate UUID filenames server-side; store original name in metadata only

```
JPEG: FF D8 FF | PNG: 89 50 4E 47 | PDF: 25 50 44 46
```

### Virus Scanning

Upload -> quarantine -> scan (ClamAV / GuardDuty / VirusTotal) -> clean: move to permanent | infected: delete + log + alert.

Scan EVERY untrusted upload before making accessible. Update definitions daily.

#### ClamAV Integration Pattern

```typescript
// S3 event trigger -> Lambda/worker -> ClamAV scan -> move or quarantine
import NodeClam from 'clamscan';

async function scanFile(fileId: string) {
  const file = await db.file.findUnique({ where: { id: fileId } });
  const tempPath = await downloadToTemp(file.key);

  const clam = await new NodeClam().init({ clamdscan: { host: env.CLAMAV_HOST, port: 3310 } });
  const { isInfected, viruses } = await clam.scanFile(tempPath);

  if (isInfected) {
    await s3.send(new DeleteObjectCommand({ Bucket: env.UPLOAD_BUCKET, Key: file.key }));
    await db.file.update({ where: { id: fileId }, data: { status: 'infected', metadata: { viruses } } });
    logger.warn('Infected file detected', { fileId, viruses, userId: file.userId });
    // Alert security team
    await alerting.send('infected-file', { fileId, viruses });
  } else {
    // Move from upload bucket to permanent storage
    await s3.send(new CopyObjectCommand({
      CopySource: `${env.UPLOAD_BUCKET}/${file.key}`,
      Bucket: env.STORAGE_BUCKET,
      Key: file.key,
    }));
    await s3.send(new DeleteObjectCommand({ Bucket: env.UPLOAD_BUCKET, Key: file.key }));
    await db.file.update({ where: { id: fileId }, data: { status: 'clean' } });
  }

  await fs.unlink(tempPath);
}
```

Architecture options: ClamAV as sidecar container (low latency), ClamAV as shared service (less memory per pod), S3 event -> SQS -> Lambda with ClamAV layer (serverless). Update virus definitions via cron (`freshclam` daily).

### Storage Security

- Private buckets; serve via presigned GET URLs (1h) or CDN signed URLs
- SSE-S3/KMS encryption; versioning for critical files; access logging
- Serve user uploads from separate domain (prevent XSS); lifecycle policies (IA 30d, Glacier 90d)

## Image Processing Pipeline

```
Original confirmed -> Queue -> Worker:
  Validate -> Strip EXIF -> Auto-orient -> Generate variants
  (thumb 200x200, medium 800w, large 1920w) + blurhash
  -> Optimize (WebP + JPEG fallback) -> Upload variants -> Update metadata
```

Tools: Sharp (Node.js), SkiaSharp (.NET), Cloudinary/Imgix (SaaS).
Blurhash: 4x3 components, store hash string in DB.
Formats: WebP > AVIF > JPEG > PNG (transparency only).

### Image Processing Worker (Node.js / Sharp)

```typescript
import sharp from 'sharp';
import { encode } from 'blurhash';

interface ImageVariant { suffix: string; width: number; height?: number; fit: 'cover' | 'inside' }

const VARIANTS: ImageVariant[] = [
  { suffix: 'thumb', width: 200, height: 200, fit: 'cover' },
  { suffix: 'medium', width: 800, fit: 'inside' },
  { suffix: 'large', width: 1920, fit: 'inside' },
];

async function processImage(fileId: string) {
  const file = await db.file.findUnique({ where: { id: fileId } });
  const buffer = await downloadBuffer(file.key);

  // Strip EXIF, auto-orient
  const base = sharp(buffer).rotate(); // rotate() auto-orients from EXIF
  const metadata = await base.metadata();

  // Generate blurhash from small version
  const thumbForHash = await base.clone().resize(32, 32, { fit: 'inside' }).ensureAlpha().raw().toBuffer();
  const blurhash = encode(new Uint8ClampedArray(thumbForHash), 32, 32, 4, 3);

  // Generate variants in WebP + JPEG fallback
  const variants: Record<string, string> = {};
  for (const v of VARIANTS) {
    for (const format of ['webp', 'jpeg'] as const) {
      const processed = await base.clone()
        .resize(v.width, v.height, { fit: v.fit, withoutEnlargement: true })
        [format]({ quality: format === 'webp' ? 80 : 85 })
        .toBuffer();

      const variantKey = `processed/${file.id}/${v.suffix}.${format}`;
      await uploadBuffer(variantKey, processed, `image/${format}`);
      variants[`${v.suffix}_${format}`] = variantKey;
    }
  }

  await db.file.update({
    where: { id: fileId },
    data: {
      status: 'complete',
      metadata: { blurhash, width: metadata.width, height: metadata.height, variants },
    },
  });
}
```

### EXIF Stripping and Metadata Extraction

Always strip EXIF from user uploads before serving (contains GPS location, device info, timestamps). Extract useful metadata (dimensions, orientation) before stripping. Sharp strips EXIF by default when processing. For non-image files, use `exiftool` or equivalent to remove metadata from PDFs and Office docs.

### File Metadata Management

Detect MIME type from magic bytes, not extension:

```typescript
import { fileTypeFromBuffer } from 'file-type';

async function detectFileType(buffer: Buffer) {
  const result = await fileTypeFromBuffer(buffer);
  if (!result) throw new BadRequestError('Unable to detect file type');
  return { mime: result.mime, ext: result.ext };
}
// Note: `file-type` v16+ is ESM-only — incompatible with CJS/NestJS. Pin to v14 or use `magic-bytes.js` as a CJS-compatible alternative.
```

Store metadata in DB: `{ id, key, originalName, mimeType, size, width, height, blurhash, contentHash, status, createdAt, deletedAt }`.

## CDN Integration

- CDN in front of storage; custom domain; `Cache-Control: public, max-age=31536000, immutable`
- Content-hashed URLs for cache-busting; signed URLs for private content
- Purge via API only when content-hash approach is insufficient

### CloudFront with S3 Origin

```
S3 (private) <-- OAC --> CloudFront <-- custom domain --> Client
```

Use Origin Access Control (OAC) so S3 bucket stays private. Configure custom domain with ACM certificate. Set cache behaviors: `/processed/*` with long TTL (1 year, immutable), `/downloads/*` with shorter TTL or no cache.

### Signed URLs for Private Content

```typescript
// npm install @aws-sdk/cloudfront-signer
import { getSignedUrl } from '@aws-sdk/cloudfront-signer';

function getCdnSignedUrl(key: string, expiresInSeconds = 3600): string {
  return getSignedUrl({
    url: `https://cdn.example.com/${key}`,
    keyPairId: env.CLOUDFRONT_KEY_PAIR_ID,
    privateKey: env.CLOUDFRONT_PRIVATE_KEY,
    dateLessThan: new Date(Date.now() + expiresInSeconds * 1000).toISOString(),
  });
}
```

### Cache Headers Strategy

| Content type | Cache-Control | Why |
|---|---|---|
| Processed images (content-hashed path) | `public, max-age=31536000, immutable` | Content never changes at same URL |
| User avatars (non-hashed) | `public, max-age=86400` | May change, 1-day cache acceptable |
| Temporary downloads | `private, no-cache` | Presigned, one-time access |
| Thumbnails | `public, max-age=604800` | 7 days, regenerated rarely |

## File Deduplication

SHA-256 content hash; check before storage; reference counting (delete from storage only at ref count 0).
Skip dedup for: cross-tenant privacy, per-user processing, encrypted files.

### Content-Hash Deduplication Flow

```typescript
import { createHash } from 'crypto';

async function deduplicateUpload(buffer: Buffer, userId: string, originalName: string) {
  const contentHash = createHash('sha256').update(buffer).digest('hex');

  // Check if identical content already exists
  const existing = await db.file.findFirst({
    where: { contentHash, status: 'complete', deletedAt: null },
  });

  if (existing) {
    // Create new metadata record pointing to same storage object
    const newFile = await db.file.create({
      data: { key: existing.key, contentHash, userId, originalName, refCount: 0, status: 'complete' },
    });
    await db.file.update({ where: { id: existing.id }, data: { refCount: { increment: 1 } } });
    return newFile;
  }

  // No duplicate — proceed with normal upload
  return null;
}
```

Reference counting: increment on duplicate reference, decrement on soft delete. Only delete from storage when `refCount === 0` and all referencing records are hard-deleted. Run reference count audit weekly to detect orphans.

## Retention and Cleanup

```
Daily cleanup job:
  -> Presigned URLs >24h with no confirmation -> delete
  -> Incomplete multipart >24h -> abort
  -> Storage objects with no metadata -> quarantine 7d -> delete
  -> deleted_at >30d -> hard delete from storage
```

Soft delete: set `deleted_at`, retain 30 days, expose trash UI, legal hold overrides retention.

### Retention Policy Implementation

```typescript
// Daily cleanup job (BullMQ / Hangfire / cron)
async function cleanupFiles() {
  // 1. Hard delete files past retention period
  const expired = await db.file.findMany({
    where: { deletedAt: { lt: subDays(new Date(), 30) }, legalHold: false },
  });
  for (const file of expired) {
    if (file.refCount <= 0) {
      await s3.send(new DeleteObjectCommand({ Bucket: env.STORAGE_BUCKET, Key: file.key }));
      // Delete all variants
      for (const variantKey of Object.values(file.metadata?.variants ?? {})) {
        await s3.send(new DeleteObjectCommand({ Bucket: env.STORAGE_BUCKET, Key: variantKey }));
      }
    }
    await db.file.delete({ where: { id: file.id } });
  }

  // 2. Clean up orphaned uploads (presigned URL generated but never confirmed)
  const orphaned = await db.file.findMany({
    where: { status: 'pending', createdAt: { lt: subHours(new Date(), 24) } },
  });
  for (const file of orphaned) {
    await s3.send(new DeleteObjectCommand({ Bucket: env.UPLOAD_BUCKET, Key: file.key }));
    await db.file.delete({ where: { id: file.id } });
  }

  // 3. Abort incomplete multipart uploads
  const { Uploads } = await s3.send(new ListMultipartUploadsCommand({ Bucket: env.UPLOAD_BUCKET }));
  for (const upload of Uploads ?? []) {
    if (upload.Initiated && upload.Initiated < subHours(new Date(), 24)) {
      await s3.send(new AbortMultipartUploadCommand({
        Bucket: env.UPLOAD_BUCKET, Key: upload.Key, UploadId: upload.UploadId,
      }));
    }
  }
}
```

Compliance holds: set `legalHold: true` on files under litigation or audit. Legal hold overrides all retention policies. Only compliance officers can set/remove holds. Log all hold changes for audit trail.

S3 lifecycle rules: configure `IntelligentTiering` or `Transition` to move infrequently accessed files to IA (30 days) and Glacier (90 days). Set `AbortIncompleteMultipartUpload` rule as backup for the cleanup job.

## API Design

```
POST /files/presigned-url    -> { uploadUrl, fileId, expiresAt }
POST /files/{id}/confirm     -> { id, url, name, size, variants, blurhash }
GET  /files/{id}             -> metadata
GET  /files/{id}/download    -> 302 redirect to presigned URL
DELETE /files/{id}           -> 204 (soft delete)
GET  /files?context=&page=   -> paginated list
POST /files/check-duplicate  -> { exists, fileId? }
```

## Frontend Integration

- Drag-and-drop + click-to-browse; client-side type/size validation
- Progress bar (XHR onprogress); image preview; retry with backoff; cancel (AbortController)
- Upload state: idle -> validating -> uploading -> confirming -> processing -> complete / failed
- Multiple files: max 3-5 parallel, individual progress, continue on failure

## Framework-Specific

.NET: `IFormFile` streaming, `AWSSDK.S3` TransferUtility, Hangfire for processing, `nClam` for scanning.
Node.js: multer (disk storage), `@aws-sdk/client-s3`, Sharp, BullMQ queue, clamscan. Note: `multer` has compatibility issues with Express 5 and Bun — for modern Node.js consider `busboy` or native `Request.formData()`.

## Anti-Patterns

- Files in DB BLOB columns; trusting MIME without magic bytes; public buckets
- No size limits; same domain for user uploads; sync image processing in request
- No orphan cleanup; buffering entire file; client filenames as storage keys
- Long presigned expiry (24h+); no virus scanning; hard-deleting immediately

## Output Format

```
Storage:       [provider]
Upload:        [presigned / server-side / chunked / tus]
Scanning:      [ClamAV / GuardDuty / none]
CDN:           [provider]
Image:         [variants, formats, blurhash]
Security:      [magic bytes, presigned expiry, content-type enforcement]
Cleanup:       [orphan cleanup, soft delete retention, lifecycle]
Dedup:         [SHA-256 content hash]
```

## Done Criteria

- Upload works with progress; magic byte validation; size enforced at all levels
- Private bucket with signed URLs; image variants async; virus scanning
- Orphan cleanup on schedule; presigned URL pattern for large files
- CDN configured; soft delete with retention; dedup when applicable
