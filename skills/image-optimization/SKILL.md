---
name: image-optimization
description: Implement responsive image delivery, framework optimizers, upload transformation, caching, priority hints, and untrusted-image defenses. Use when image loading or processing is the primary outcome; do not use for generic performance analysis or file storage alone.
metadata:
  owner: codex-framework
  reviewed: "2026-09-09"
  version: 2.1
  argument-hint: "installed framework, image sources, privacy, transformations, performance budget, upload threat model"
---

# Image Optimization

For existing projects, generate stack context with `python3 scripts/framework-stack-context.py project <path>` and inspect manifests, lockfiles, framework and React versions, image-component types, loader/optimizer configuration, deployment image service/runtime, CSP, cache headers, emitted HTML/network behavior and tests as one compatibility unit. Installed capabilities are authority. For greenfield work, use `python3 scripts/framework-stack-context.py latest <technologies...>` to resolve the selected stable frameworks and LTS runtime; do not encode a remembered major.

## Delivery Contract

- Preserve intrinsic dimensions or aspect ratio to prevent layout shift; derive responsive candidates from actual layout breakpoints and measured demand.
- Use modern formats only after content negotiation/decoder support and visual-quality validation. Keep an appropriate fallback.
- Prioritize only measured critical images. In Next.js, verify the installed `<Image>` API: releases may expose `preload`, `priority`, or different fetch-priority behavior. Do not infer that a property is supported or unsupported from the task wording or newer examples; decide from stack-context output, installed types and matching official documentation. Apply only proven properties and inspect emitted HTML/network priority; do not combine competing preload mechanisms blindly.
- Cache public immutable variants by content/transform identity. Private or tenant-bound images require authorization-aware delivery and cache partitioning; never let a shared CDN/browser key ignore the authenticated subject, entitlement, or signed-transform policy.

## Optimizer and Upload Trust Boundary

1. Treat remote source URLs and transform parameters as attacker-controlled. Allowlist schemes/hosts/ports/path patterns, resolve and validate every redirect, reject credentials and disallowed address classes after DNS resolution, and prevent DNS-rebinding/internal metadata access. Bound redirect count, connect/read time, decoded pixels, dimensions, frames, CPU, memory, output size, and concurrency.
2. Decode with a maintained isolated library/process and fail closed on malformed or decompression-bomb inputs. Re-encode rather than trusting embedded active content.
3. Handle SVG as active content, not an ordinary raster. Prefer controlled static SVG assets; otherwise sanitize with a purpose-built current policy, constrain external references/scripts, and serve with safe content type/disposition and CSP appropriate to the rendering mode.
4. Strip metadata when privacy or size requires it, while explicitly preserving orientation/color information needed for correct rendering. Do not expose GPS, device, author, or tenant-sensitive metadata.
5. Bind uploads and derived variants to authorized actor/tenant/object, generated names, quarantine/scan state, retention, and deletion. An uploaded MIME type or extension is not proof.

## Workflow

1. Measure representative pages: LCP candidate, dimensions, transfer/decode cost, cache behavior, and user/network segments. Define a repository-owned performance/quality budget rather than universal byte thresholds.
2. Choose browser-native markup, installed framework image component, or a trusted transformation service based on required formats, auth, deployment, and threat model.
3. Configure source and transform allowlists, responsive sizes, cache keys/partitioning, failure fallback, observability, and invalidation.
4. Implement upload normalization and metadata policy if user content is in scope.
5. Verify emitted markup, requested variants, content negotiation, quality, authorization, and optimizer failure behavior in the deployed path.

## Verification

- Representative viewport/DPR/network matrix; LCP and noncritical images; no-JS/failure fallback; layout stability; visual comparison; cache hit/miss/invalidation.
- Private cross-user/tenant requests, revoked access, shared-CDN keys, signed URL expiry, and logout.
- Loopback/private/link-local/metadata hosts, encoded IPs, DNS changes, redirect chains, oversized dimensions, animated/decompression bombs, malformed images, SVG scripts/external references, and metadata leakage.
- Installed Next/framework API and generated HTML/network evidence; production build and focused tests. Report measured before/after values and uncertainty, not generic promises.

## Output Contract

- Measured delivery budget and responsive/priority decisions
- Cache/privacy and optimizer security contract
- Upload/SVG/metadata handling
- Installed framework, React and runtime versions plus official-documentation evidence for the selected image API and deployment path
- Verification results and residual CDN/decoder/browser risk

Official references: [Next.js Image](https://nextjs.org/docs/app/api-reference/components/image), [OWASP SSRF Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html), and [OWASP File Upload](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html).
