---
name: frontend-design-direction
description: Create brief-grounded visual direction for a new or substantially reshaped web interface, including subject-specific art direction, typography, color, layout, motion, copy tone, originality critique, and an implementation handoff. Use when the primary outcome is how the interface should look and feel; do not use for exact supplied-design implementation, design-system engineering, accessibility or consistency audits, routine frontend implementation, or backend work.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 1.0
  argument-hint: "product and audience brief, real content, existing brand or screenshots, fixed constraints, desired deliverable"
---

# Frontend Design Direction

Create an evidence-grounded direction, not a generic style recipe. This skill owns the visual thesis and handoff; the matching frontend or design-system implementation skill owns repository changes.

## Ground the brief

1. Read the user brief, product and audience evidence, real content, existing brand/tokens/components, relevant routes and screenshots, platform constraints, and any explicit accessibility, localization, performance, or browser requirements.
2. State the interface's audience, single primary job, emotional register, non-goals, and fixed constraints. Separate supplied facts from interpretations. Ask only when a missing choice would materially change the direction; otherwise label a reversible assumption.
3. Use only user-provided or repository-authoritative preferences. Do not silently draw on personal memory, invent a brand history, or persist taste notes for future work.
4. Do not infer product capabilities from the domain or audience. Actions such as acknowledge, resolve, export, approve or contact are allowed only when the brief or repository supports them; otherwise mark the decision unresolved instead of designing a fictional flow.

## Form and test the direction

1. Derive visual cues from the subject's real materials, vocabulary, workflows, and content hierarchy. When the brief is open enough to justify exploration, compare a small number of genuinely different directions and choose one with a product-specific rationale.
2. Define a compact system: named color roles with contrast intent, type roles and fallback/licensing/language needs, spatial and grid logic, hierarchy, imagery or illustration treatment, interaction and motion intent, and the one restrained signature element. Do not require a fashionable palette, type pairing, maximalism, minimalism, animation, or novelty for its own sake.
3. Sketch information structure before decoration. Use a concise wireframe or annotated component map when it clarifies hierarchy. Real content beats generic marketing filler; interface copy names what the user recognizes and what an action actually does.
4. Falsify genericity: identify choices that could be pasted onto an unrelated product, recurring AI-design tropes, decoration without semantic purpose, and inaccessible or operationally expensive flourishes. Revise the weak choices while preserving the brief rather than applying a fixed anti-template aesthetic.
5. Define interaction states relevant to the surface: loading, empty, error, success, focus, disabled, responsive, reduced-motion, zoom/text scaling, localization and high-contrast behavior. This is a direction baseline, not a substitute for a WCAG audit.

## Evidence and handoff

- For a text-only brief, return the direction, key alternatives rejected, compact tokens, hierarchy/wireframe, component and content treatment, interaction states, implementation constraints, and explicit assumptions.
- For critique or revision of a rendered interface, inspect the supplied or browser-rendered screenshots at representative viewports. Compare before/after hierarchy, legibility, consistency, responsive behavior, and the brief's distinguishing intent. Do not claim improved visual quality from code or prose alone.
- Identify which choices require user approval, licensed assets or fonts, content work, performance measurement, or accessibility validation. End with residual visual risks and unrendered or untested states, even when the handoff is otherwise complete.
- Hand the approved direction to the sharp implementation owner. Preserve the repository's installed stack and design contracts; do not force a framework, styling system, or dependency upgrade as part of art direction.

Report the evidence used, chosen visual thesis, decisions and rejected alternatives, verification performed, untested visual or browser states, and the exact implementation handoff.
