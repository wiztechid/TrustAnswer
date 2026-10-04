# TrustAnswer OS — Public SaaS Architecture Contract v0.3

Status: **MIGRATION CANDIDATE — P0 SECURITY GATE DEFINED**

TrustAnswer is a multi-tenant SaaS. The v0.2 evidence-first and fail-closed invariants remain inherited. This public contract intentionally omits proprietary resolver logic and adversarial recipes.

## 1. System boundary

Public flow:

`authenticated user -> tenant context -> questionnaire -> canonical answer/evidence -> validation -> human review -> submission gate -> immutable snapshot/export`

The browser is not authoritative for tenant membership, plan, entitlement, validation result, approval, or submission readiness.

## 2. Logical modules

The former seven workbook sheets become logical application modules:

1. Dashboard
2. Questionnaires
3. Answer Library
4. Evidence Registry
5. Gap Register
6. Review Queue
7. Submission Gate

The database and server-side validation engine are authoritative.

## 3. Multi-tenant identity model

Core entities:

- users — authentication identity is supplied by the auth provider.
- tenants — organization/workspace security boundary.
- tenant_memberships — user-to-tenant relationship with explicit role and lifecycle state.
- customers — tenant-owned customer/prospect records.
- questionnaires — tenant-owned questionnaire context.
- questionnaire_questions — immutable imported question identity plus mutable response workflow.
- canonical_answers and canonical_answer_revisions — tenant-owned reusable claims.
- evidence_records and evidence_revisions — tenant-owned evidence metadata/revisions.
- answer_evidence_bindings — revision-specific claim/evidence relationships.
- gaps — tenant-owned blockers/review issues.
- reviews — context/revision-bound human decisions.
- submissions and submission_items — immutable historical snapshots.
- subscriptions — server-maintained billing state.
- entitlements — server-derived capabilities/limits.
- usage_counters — server-maintained metering.
- webhook_events — idempotency/audit records for verified billing events.

Every tenant-owned row must carry an immutable `tenant_id`. Child records must not infer tenant ownership only through application joins.

## 4. Tenant isolation

Tenant access requires all of:

- authenticated user identity
- active membership in the exact tenant
- operation permitted by role
- row tenant_id equals authorized tenant

RLS is mandatory for every exposed tenant-owned table and is operation-specific for SELECT/INSERT/UPDATE/DELETE.

No request may gain access merely by supplying a tenant_id, customer_id, questionnaire_id, answer_id, evidence_id, review_id, or submission_id.

Service credentials and any role capable of bypassing RLS are server-only and must never be shipped to the browser.

Cross-tenant copy/import is a new explicit operation that creates new tenant-owned identities and triggers revalidation; it is never ordinary read access to another tenant.

## 5. Roles

Initial roles:

- OWNER
- ADMIN
- MEMBER
- REVIEWER

Role assignment itself is privileged. The implementation must prevent self-promotion and unauthorized membership mutation.

Billing authority is not inferred from a UI role alone; server-side entitlement rules remain authoritative.

## 6. Evidence-reference model

MVP stores evidence metadata/reference, not confidential evidence file contents.

Evidence revision fields include:

- tenant_id
- evidence_id
- evidence_revision_id
- title/type/control topic
- source_reference
- source_owner
- effective_at
- known_at
- last_verified/next_review
- freshness state
- shareability
- explicit scope dimensions
- lifecycle/supersession metadata

A source_reference is not proof that the remote document is accessible, current, safe to share, or unchanged. Evidence validity remains an explicit validation decision.

## 7. Point-in-time and revision contract

v0.2 rules remain:

- current truth cannot rewrite historical truth
- approvals bind to exact context and revisions
- evidence identity is revision-specific
- dependency repair does not restore approval
- ambiguous or unknown state cannot pass

Submitted snapshots are append-only/immutable through normal product roles.

## 8. Billing and entitlement architecture

Paddle is the intended Merchant of Record/billing provider.

The browser may initiate checkout but cannot grant capabilities.

Billing flow:

`Paddle signed event -> server verification -> idempotent event record -> subscription state -> derived entitlement -> enforcement`

Subscription/provider identifiers are mapped server-side to exactly one TrustAnswer tenant relationship. Client-supplied price, plan, status, quota, customer ID, or subscription ID is never authoritative.

Entitlements are derived from trusted billing state and an internal plan catalogue. Unknown product/price mappings fail closed.

Billing states must explicitly handle at least trialing, active, past_due, paused, canceled, scheduled changes, duplicate/out-of-order delivery, and reconciliation uncertainty.

A canceled/paused/ineligible subscription cannot retain paid capabilities merely because the browser cached an old plan.

Grace behavior for past_due, if offered, must be explicit policy rather than accidental access.

## 9. Free / Solo / Pro contract

Initial commercial model:

- FREE — bounded evaluation capability
- SOLO — paid individual/small-team capability
- PRO — paid team/workflow capability

Exact quotas are configuration, not client authority.

All quota consumption and entitlement checks for privileged operations occur server-side. Export, paid workflow features, membership limits, questionnaire limits and future AI allowances must not be unlockable by editing browser state.

## 10. API boundary

Public/browser API may perform authorized product operations using the authenticated user context.

Server-only boundary contains:

- billing secrets and webhook verification
- privileged database/service credentials
- entitlement derivation
- submission gate authority
- immutable snapshot creation
- validation/resolver internals
- future AI provider secrets
- administrative reconciliation jobs

Every mutation performs authorization and entitlement checks on the server/database boundary, not only in UI routing.

Object identifiers are treated as untrusted input.

## 11. Submission gate

READY_TO_SEND remains fail-closed.

SaaS migration adds mandatory conditions:

- tenant context valid
- membership active
- authorization valid
- entitlement permits requested operation
- database/security integrity valid

The original answer/evidence/scope/PIT/contradiction/review invariants remain mandatory.

## 12. SaaS security invariants

1. A user identity is not a tenant authorization.
2. Knowing an object ID grants nothing.
3. Tenant ownership is explicit on every tenant-owned row.
4. RLS is mandatory defense-in-depth, not optional application logic.
5. Browser state cannot grant a paid capability.
6. Billing events are untrusted until cryptographically verified.
7. Duplicate or reordered billing events cannot resurrect entitlement.
8. Unknown billing mappings fail closed.
9. Service credentials never enter the browser.
10. Historical submissions cannot be mutated by later tenant, billing, or knowledge changes.
11. Fixing a dependency still requires fresh review where v0.2 requires it.
12. Absence of a denial is never proof of authorization.

## 13. Migration rule

Workbook Engine v0.1 is canceled as the product implementation target.

Architecture v0.2 is retained as the validation-domain parent contract. v0.3 migrates its logical model into a multi-tenant SaaS without weakening any v0.2 safety invariant.

UI/UX implementation is blocked until the v0.3 tenant-isolation and entitlement adversarial gate closes.
