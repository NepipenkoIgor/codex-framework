---
name: advanced-animation
description: Implement asset-driven Lottie, WebGL/Three.js, canvas, SVG, scroll or gesture animation beyond routine UI motion. Use for requested advanced animation work; route ordinary transitions to animation-motion.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "effect/assets, installed framework/libraries, target devices, interaction and measured budget"
---

# Advanced Animation

1. Resolve the exact repository, environment, routes/components and assets in scope, the owner and mutation/deployment authority, and a concrete rollback or static fallback before changing files or deployed behavior. Then inspect repository pins, render/hydration boundaries, asset pipeline, CSP, target devices, accessibility policy and representative performance traces. Generate stack context before selecting framework APIs.
2. Define the functional fallback and reduced-motion experience first. Reduced motion may remove, shorten or replace motion while preserving state, meaning, focus and controls; listen for preference changes where appropriate.
3. Treat Lottie JSON, GLTF/GLB, textures, shaders and remote media as untrusted: allowlist origins/types, bound compressed and decoded bytes, nodes/meshes/materials/textures/frames/duration, parse/decode in an isolated path, sanitize external references and fail to a static asset. Do not execute arbitrary expressions/scripts or fetch unbounded dependencies.
4. Derive JS/asset/decoded-memory, frame-time, GPU, CPU, battery and network budgets from the page workload and target device evidence. Bound particles, DPR, geometry, textures, observers and concurrent loops from measurements—not universal FPS, byte or count tables.
5. Use one owned animation lifecycle with cancellation/disposal for RAF, observers, listeners, timelines, WebGL resources and async loads. Pause off-screen/background work and handle context loss.
6. Prefer transform/opacity only when they achieve the effect; measure actual layout/paint/composite cost. Feature-detect view transitions, scroll timelines, WebGL and library APIs, with fallbacks.
7. Angular: preserve the pinned compiler/runtime. Do not introduce deprecated `@angular/animations` guidance where the installed Angular 20.2+ line provides native CSS `animate.enter`/`animate.leave`; use only capabilities in installed docs/types and treat migration separately.

Verify low/high-end representative devices, slow network, unsupported WebGL/API, context loss, hostile/oversized asset, repeated mount/unmount, navigation, reduced motion and keyboard/screen-reader behavior. Report measured traces/budgets, resource cleanup and untested device risk.
