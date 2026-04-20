---
name: frontend-test
description: Write unit and component tests for frontend code with behavior-focused coverage
metadata:
  version: 2.0
  argument-hint: "component/module, framework, test type, target behavior"
---

Write tests for $ARGUMENTS.

## Tool Integration

- Use the repository's existing test framework.
- Run available diagnostics after meaningful code changes.

## Testing Principles

- Prefer behavior-driven tests over implementation-detail tests.
- Test user-visible states and interactions.
- Cover loading, error, empty, success, and accessibility behavior where relevant.
- Avoid brittle snapshots for complex interactive views.

## Priority Areas

- forms and validation
- state transitions
- async rendering and retries
- conditional rendering
- keyboard and accessibility behavior

## Output Requirements

- Add the smallest meaningful test coverage for the changed behavior.
- Follow the repo's existing test style.
- State what behavior is still not covered.
