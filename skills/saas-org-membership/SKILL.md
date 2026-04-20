---
name: saas-org-membership
description: B2B SaaS org/workspace layer — invitations, member roles, seat billing triggers, owner transfer, org deletion cascade. Pairs with auth-security for permission enforcement.
metadata:
  version: 1.0
  domain: backend
  keywords: [org, workspace, organization, membership, invitation, invite, member role, seat, seat count, owner transfer, team member, org deletion, workspace member, RBAC org]
---

# SaaS Org & Membership

## Data Model

```sql
-- Core org tables
CREATE TABLE organizations (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  slug        TEXT UNIQUE NOT NULL,
  plan        TEXT NOT NULL DEFAULT 'free',  -- free | pro | enterprise
  seat_limit  INT,                            -- null = unlimited
  owner_id    UUID REFERENCES users(id) NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE memberships (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      UUID REFERENCES organizations(id) ON DELETE CASCADE,
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  role        TEXT NOT NULL CHECK (role IN ('owner','admin','member','viewer')),
  invited_by  UUID REFERENCES users(id),
  joined_at   TIMESTAMPTZ DEFAULT now(),
  UNIQUE(org_id, user_id)
);

CREATE TABLE invitations (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      UUID REFERENCES organizations(id) ON DELETE CASCADE,
  email       TEXT NOT NULL,
  role        TEXT NOT NULL DEFAULT 'member',
  token       TEXT UNIQUE NOT NULL,           -- signed, server-side generated
  invited_by  UUID REFERENCES users(id),
  expires_at  TIMESTAMPTZ NOT NULL,           -- 7 days
  accepted_at TIMESTAMPTZ,
  UNIQUE(org_id, email)
);
```

## Invitation Flow

```typescript
// Send invitation
async function inviteMember(orgId: string, email: string, role: Role, invitedBy: string) {
  const existing = await db.memberships.findOne({ orgId, user: { email } });
  if (existing) throw new ConflictError('User is already a member');

  const seatCount = await db.memberships.count({ orgId });
  const org = await db.organizations.findById(orgId);
  if (org.seatLimit && seatCount >= org.seatLimit) {
    throw new SeatLimitError('Seat limit reached — upgrade plan to invite more members');
  }

  const token = crypto.randomBytes(32).toString('hex');
  const invitation = await db.invitations.upsert(
    { orgId, email },
    { role, token, invitedBy, expiresAt: addDays(new Date(), 7), acceptedAt: null }
  );

  await email.send({ to: email, template: 'org-invitation', data: { org, token, inviterName } });
  await auditLog({ action: 'member.invited', orgId, actorId: invitedBy, meta: { email, role } });
}

// Accept invitation
async function acceptInvitation(token: string, userId: string) {
  const invite = await db.invitations.findOne({ token });
  if (!invite || invite.expiresAt < new Date()) throw new InvalidTokenError('Invitation expired');
  if (invite.acceptedAt) throw new ConflictError('Invitation already used');

  await db.$transaction([
    db.memberships.create({ orgId: invite.orgId, userId, role: invite.role, invitedBy: invite.invitedBy }),
    db.invitations.update({ id: invite.id }, { acceptedAt: new Date() }),
  ]);

  await auditLog({ action: 'member.joined', orgId: invite.orgId, actorId: userId });
  // Trigger seat billing update
  await billing.syncSeatCount(invite.orgId);
}
```

## Role Hierarchy & Permission Check

```typescript
const ROLE_RANK = { owner: 4, admin: 3, member: 2, viewer: 1 };

function canManage(actorRole: Role, targetRole: Role): boolean {
  return ROLE_RANK[actorRole] > ROLE_RANK[targetRole]; // must outrank, not equal
}

async function assertOrgPermission(userId: string, orgId: string, minRole: Role) {
  const membership = await db.memberships.findOne({ userId, orgId });
  if (!membership) throw new ForbiddenError('Not a member of this organization');
  if (ROLE_RANK[membership.role] < ROLE_RANK[minRole]) {
    throw new ForbiddenError(`Requires ${minRole} role or higher`);
  }
  return membership;
}

// Usage
await assertOrgPermission(req.userId, orgId, 'admin'); // throws if viewer/member
```

## Seat-Based Billing Sync

```typescript
async function syncSeatCount(orgId: string) {
  const count = await db.memberships.count({ orgId });
  const org = await db.organizations.findById(orgId);

  if (org.stripeSubscriptionId) {
    await stripe.subscriptions.update(org.stripeSubscriptionId, {
      items: [{ id: org.stripeSeatsItemId, quantity: count }],
      proration_behavior: 'always_invoice',
    });
  }

  await auditLog({ action: 'billing.seats_synced', orgId, meta: { count } });
}

// Call syncSeatCount after: member joined, member removed, invitation accepted
```

## Owner Transfer

```typescript
async function transferOwnership(orgId: string, newOwnerId: string, currentOwnerId: string) {
  const newMember = await db.memberships.findOne({ orgId, userId: newOwnerId });
  if (!newMember) throw new NotFoundError('New owner must be an existing member');

  await db.$transaction([
    db.memberships.update({ orgId, userId: currentOwnerId }, { role: 'admin' }),
    db.memberships.update({ orgId, userId: newOwnerId }, { role: 'owner' }),
    db.organizations.update({ id: orgId }, { ownerId: newOwnerId }),
  ]);

  await auditLog({ action: 'org.owner_transferred', orgId, actorId: currentOwnerId,
    meta: { previousOwner: currentOwnerId, newOwner: newOwnerId } });
}
```

## Member Removal

```typescript
async function removeMember(orgId: string, targetUserId: string, actorId: string) {
  const actor = await assertOrgPermission(actorId, orgId, 'admin');
  const target = await db.memberships.findOne({ orgId, userId: targetUserId });

  if (!target) throw new NotFoundError('Member not found');
  if (target.role === 'owner') throw new ForbiddenError('Cannot remove the org owner');
  if (!canManage(actor.role, target.role)) throw new ForbiddenError('Insufficient role');

  await db.memberships.delete({ orgId, userId: targetUserId });
  await billing.syncSeatCount(orgId);
  await auditLog({ action: 'member.removed', orgId, actorId, meta: { removedUserId: targetUserId } });
}
```

## Org Deletion Cascade

```typescript
async function deleteOrganization(orgId: string, ownerId: string) {
  // Cancel subscription first — before data deletion
  const org = await db.organizations.findById(orgId);
  if (org.stripeSubscriptionId) {
    await stripe.subscriptions.cancel(org.stripeSubscriptionId, { prorate: false });
  }

  // Cascade handled by DB ON DELETE CASCADE for: memberships, invitations
  // Explicitly handle: user-owned data, uploaded files, external webhooks
  await storage.deleteOrgFiles(orgId);
  await webhooks.deregisterOrgEndpoints(orgId);
  await db.organizations.delete({ id: orgId }); // cascades memberships/invitations

  await auditLog({ action: 'org.deleted', orgId, actorId: ownerId });
  // Do NOT delete users — they may belong to other orgs
}
```

## Rules

- Owner is always the last role standing — never leave an org without an owner
- Role changes require actor to outrank target (admin cannot change another admin's role)
- Always sync seat count after membership changes when stripe subscription exists
- Invitation tokens: 32-byte random hex, 7-day expiry, single-use
- Org slug is unique and immutable after creation — used in URLs
- Cascade order: cancel billing → delete files → delete DB rows (prevent orphaned charges)
- Never delete users on org deletion — users exist independently of orgs

## Done Criteria

- [ ] Invitation sends email, stores hashed token, enforces seat limit before sending
- [ ] Accept invitation is idempotent — re-accepting an accepted token returns 409 not 500
- [ ] Role checks use rank comparison — admin cannot elevate another admin to owner
- [ ] Owner transfer is atomic — no gap where org has zero owners
- [ ] Seat count syncs to Stripe after every membership change
- [ ] Org deletion cancels subscription before deleting data
- [ ] All membership changes produce audit log entries with actor, action, and target
