---
name: code-reuse
description: Find duplication, consolidate patterns, and improve reuse boundaries without over-abstracting.
metadata:
  version: 2.0
  argument-hint: "scope, duplicate pattern, language/framework, desired refactor depth"
---

# Code Reuse

Use this skill when the task is about duplication, shared utilities, or extracting stable abstractions.

## When To Use

- Duplicated business logic, validation, formatting, queries, UI patterns, or test fixtures
- Refactors that should reduce repeated code without changing behavior
- Review work where repeated patterns create maintenance risk
- Deciding whether to extract a helper, component, service, hook, schema, or package

## Workflow

1. Identify duplicate candidates with `rg`, structural search, or nearby-file inspection.
2. Classify duplication: accidental copy/paste, intentional similarity, domain variation, or framework boilerplate.
3. Compare behavior and ownership. Extract only when the variants truly share a stable responsibility.
4. Look for existing helpers, components, schemas, services, fixtures, or package boundaries before adding new ones.
5. Choose the smallest reuse shape: function, component, hook, schema, service method, test helper, or documented pattern.
6. Refactor incrementally and preserve behavior.
7. Run targeted tests or type checks that cover all touched call sites.

## Quality Bar

- Prefer KISS over clever abstraction.
- DRY applies to repeated knowledge, not merely repeated lines.
- Keep shared code named by domain responsibility, not vague implementation details.
- Keep ownership clear so shared code does not become a dumping ground.
- Make call sites simpler after extraction; if call sites become harder to read, reconsider.

## Anti-Patterns

- Abstracting two examples that are likely to diverge.
- Creating a generic utility with boolean flags for unrelated behavior.
- Moving domain-specific behavior into a global helper.
- Hiding validation, auth, persistence, or UI semantics behind vague shared code.
- Changing behavior while claiming a reuse-only refactor.

## Verification

- Check all call sites compile and still express the intended behavior.
- Run targeted tests for each affected variant.
- Compare before/after public contracts and UI/API behavior.
- Confirm the abstraction does not introduce circular dependencies or layer violations.

## Output Contract

Status: done | partial | blocked
Duplication found: [pattern and locations]
Decision: [extract/reuse existing/leave duplicated]
Changed: [files]
Verification: [tests, type checks, review]
Notes: [ownership or divergence risks]
