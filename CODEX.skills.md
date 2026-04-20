# AI Codex Skill Injection Rules

Codex uses explicit, generated task briefs instead of hidden hook-based injection.
This file defines how the framework chooses the smallest useful skill set for a task.

## Principles

- Start from the routed role, then narrow by stack and feature signals.
- Prefer 1 primary skill plus 1-3 supporting skills.
- Mechanical low-reasoning work should skip broad skill injection.
- Reviewers and architects should load audit or design variants, not implementor-only guidance.
- Stack-specific skills refine the base domain skill; they do not replace it.
- Skills must stay provider-agnostic and Codex-native. Avoid embedding Claude-only model names, hook assumptions, or tool-internal commands when a capability-path description will do.

## Injection Order

For any non-trivial task, choose skills in this order:

1. Role baseline
2. Stack-specific skills
3. Feature-specific skills
4. Task extras

If two skills overlap heavily, keep the more specific one.

## Role Baselines

### `builder-frontend`

- `frontend-implement`
- `accessibility-implement`

### `builder-backend`

- `backend-implement`
- `api-design`

Use `data-validation-design` and `audit-logging` whenever the task adds or changes request boundaries.

### `builder`

- `frontend-implement`
- `backend-implement`

### `builder-fullstack`

- `frontend-implement`
- `backend-implement`
- `api-design`

### `builder-mobile`

- `mobile-implement`
- `accessibility-implement`

### `builder-automation`

- `automation-ai-workflows`
- `llm-security`

Use `automation-n8n-implement` for n8n work and `rag-pipeline` for retrieval systems.

### `builder-infra`

- `devops-ci`
- `infrastructure-as-code`
- `deployment-validation`

### `fixer`

- `frontend-debug` or `backend-debug`

Choose the domain that actually owns the defect. Add only one secondary skill unless the bug is cross-system.

### `refactorer`

- `frontend-refactor` or `backend-refactor`

Use both only for true cross-layer refactors.

### `reviewer`

- `frontend-review` or `backend-review`
- `security-audit`

Add `ui-consistency-audit` for UI changes and `performance` for backend/runtime risk.

### `tester`

- `frontend-test` or `backend-test`

Add `e2e-test` only when the change is user-flow or browser verification heavy.

### `architect`

- `frontend-architecture` or `backend-architecture`
- `api-design`

Use both architecture skills for cross-system work.

### `auditor`

- `security-audit`
- `dependency-audit`

Use `plugin-security-review` when the audit scope is plugins or prompt-pack extensions.

### `framework-manager`

- `framework-management`

## Stack-Specific Skills

Add these only when the repo or task indicates the stack clearly.

### Frontend stacks

- React: `frontend-implement-react`
- Vue: `frontend-implement-vue`
- Angular: `frontend-implement-angular`
- Next.js full-stack: `fullstack-nextjs-implement`

### Backend stacks

- .NET: `backend-implement-dotnet`
- NestJS: `backend-implement-nestjs`
- Node service without NestJS: `backend-implement-node`
- Python service: `backend-implement-python`

### Tests

- React tests: `frontend-test-react`
- Vue tests: `frontend-test-vue`
- Angular tests: `frontend-test-angular`
- .NET tests: `backend-test-dotnet`
- NestJS tests: `backend-test-nestjs`
- Node tests: `backend-test-node`
- Python tests: `backend-test-python`
- Next.js full-stack tests: `fullstack-nextjs-test`
- React Native tests: `mobile-test-reactnative`
- Flutter tests: `mobile-test-flutter`

### Mobile

- React Native / Expo: `mobile-implement-reactnative`
- Flutter: `mobile-implement-flutter`

## Feature Skills

Add only the ones directly implied by the repo or task.

- Auth/session/passkeys: `auth-security`
- Billing/Stripe: `payment-integration`
- SaaS onboarding/billing/org flows: `saas-onboarding`, `saas-billing-portal`, `saas-org-membership`, `saas-starter`
- Supabase: `supabase-patterns`
- Firebase: `firebase-patterns`
- Realtime: `websocket-realtime`
- Search: `search-implementation`
- Uploads/storage: `file-upload-storage`
- Queues/background jobs: `background-jobs`, `message-queue-patterns`
- Caching: `caching-strategy`
- Forms: `advanced-forms`
- State-heavy frontend: `state-management`
- Design system work: `design-system-implement` or `design-system-architecture`
- Accessibility audits: `accessibility-audit`
- Responsive UI: `responsive-design`
- SEO work: `seo-optimization` or `seo-audit`
- Internationalization: `i18n-implementation`
- Analytics: `analytics-implementation`
- Error tracking/observability: `error-tracking`, `observability-design`
- RAG/vector search: `rag-pipeline`, `vector-database`
- Streaming AI responses: `ai-streaming`
- Prompt-heavy automation: `prompt-engineering`, `prompt-management`
- n8n: `automation-n8n-architecture`, `automation-n8n-implement`, `automation-n8n-debug`, `n8n-test`
- GDPR/compliance: `gdpr-compliance`, `audit-logging`

## Task Extras

- New API endpoint: add `data-validation-design` and `audit-logging`
- Review of UI code: add `ui-consistency-audit`
- Performance issue: add `performance`
- Dependency or plugin audit: add `dependency-audit` or `plugin-security-review`
- Browser-visible change: add `verify` after implementation
- Documentation drift after code changes: add `docs-sync`

## Low-Reasoning Fast Path

When the task is obviously mechanical and low-risk, use only the routed baseline and skip broader stack or feature injection.

Examples:

- copy change in one component
- token swap in CSS
- rename of a known symbol
- narrow config key update
- targeted test fix with known failing file

## Brief Contract

Generated task briefs should list:

- route
- model and reasoning tier
- stack summary
- primary and supporting skills
- project commands
- spec path and counts when available
- verification expectations

That brief becomes the explicit Codex replacement for Claude-style hidden injection.
