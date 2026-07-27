---
name: email-notifications
description: Implement reliable transactional or marketing email with authorized recipients, preferences, durable dedupe, templates, provider ambiguity, authentication, bounces/complaints, suppression, privacy, and observability. Use for email delivery behavior; do not use for push or in-app feeds.
metadata:
  owner: backend
  reviewed: "2026-07-27"
  version: 2.1
  argument-hint: "event/classification, provider and authenticated domain, recipient authority/preferences, templates/locales, retries/suppression"
---

# Email Notifications

1. Inspect event/job/outbox, provider/version, sender domains/auth status, templates/locales, recipient authority, preferences/consent, suppression, webhook verification, privacy and operational evidence.
2. Define stable event/message identity and recipient/tenant/resource authorization, transactional versus marketing classification, legal basis/preferences/unsubscribe, template/version/locale, latency/retention and provider contract.
3. Persist durable handoff when loss violates the contract. Claim/deduplicate before send; provider timeout may occur after acceptance, so reconcile by stable provider/client identity instead of blindly retrying.
4. Bound retries by transient/permanent classification. Process signed raw webhook events idempotently and tolerate duplicates/reordering across accepted/delivered/deferred/bounced/complained/unsubscribed states. Keep suppression authoritative.
5. Authenticate sender domains using current provider DNS guidance and verify actual deployed DNS/provider status; configuration files alone are not proof.
6. Escape untrusted content, provide safe links, minimize PII/secrets in templates/logs/previews and define provider region/retention.

Test wrong recipient/tenant, preference and unsubscribe, duplicate/concurrent events, provider timeout-after-accept, transient/permanent failure, hard/soft bounce, complaint, duplicate/reordered/forged webhook, locale fallback and suppression recovery. Sandbox evidence must not send to unintended recipients.

Report event/classification/recipient contract, domain auth evidence, dedupe/retry/ambiguity, preferences/suppression, templates/privacy, checks/results and residual provider/delivery risk.
