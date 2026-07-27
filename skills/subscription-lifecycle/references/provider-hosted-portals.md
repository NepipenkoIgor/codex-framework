# Provider-hosted portals

Use only after reading the installed provider SDK/API version and current official portal documentation.

## Contract

- Authenticate the actor and authorize billing management for the exact customer/account/tenant. Resolve the provider customer server-side.
- Select the portal configuration and return destination from server-owned, environment-specific allowlists. Reject userinfo, unexpected scheme/host/port/path, encoded redirect tricks, and unregistered tenant domains.
- Configure allowed products, quantities, payment methods, cancellation, resume, proration, and tax behavior from approved product policy. Provider defaults are not product requirements.
- Persist an audit record for session creation without logging bearer URLs. Portal session URLs are secrets; do not place them in analytics or long-lived storage.
- The return redirect is navigation only. Refresh local state from verified webhooks or provider retrieval/reconciliation and show pending state while they converge.
- Test customer/tenant substitution, arbitrary return URL, expired/reused session, portal change with delayed or duplicate webhook, payment failure, cancellation/resume, and provider outage.

Official capability source: `https://docs.stripe.com/customer-management/integrate-customer-portal`
