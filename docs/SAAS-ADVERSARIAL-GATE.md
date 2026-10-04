# SaaS v0.3 — Public Adversarial Security Gate

Status: **P0 TEST CONTRACT DEFINED — NOT YET EXECUTED**

This file publishes attack *classes and expected security outcomes*, not proprietary exploit recipes or internal resolver details.

## A. Cross-tenant isolation gate

The implementation must fail closed against at least these classes:

- direct object reference from Tenant A to an object owned by Tenant B
- forged tenant_id on insert/update
- child-row tenant mismatch
- cross-tenant canonical answer/evidence binding
- cross-tenant review/approval replay
- cross-tenant submission snapshot access
- membership removal followed by stale-session access
- tenant switching with stale object identifiers
- invitation/membership self-promotion
- role downgrade followed by stale privileged action
- service-role credential exposure or browser invocation
- RPC/function/view path that bypasses ordinary table RLS
- bulk/export endpoint leaking rows from another tenant
- error/search/count/analytics response leaking cross-tenant existence
- cross-tenant import that preserves foreign authoritative IDs or approvals

Expected outcome: **DENY / NO DATA / NO SIDE-EFFECT**, with no leakage sufficient to confirm another tenant's protected object.

## B. Subscription and entitlement gate

The implementation must fail closed against at least these classes:

- browser-edited plan or feature flag
- forged price/product/customer/subscription identifier
- unsigned or invalidly signed webhook
- replayed webhook
- duplicate webhook delivery
- out-of-order billing events
- canceled subscription followed by stale paid session
- paused subscription retaining paid mutation capability
- past_due handling outside explicit grace policy
- unknown Paddle price/product mapping
- subscription mapped to the wrong tenant
- checkout for Tenant A attempting to provision Tenant B
- downgrade with stale quota/features
- scheduled cancellation incorrectly revoking too early or retaining too late
- deleted/missing local subscription state
- billing reconciliation disagreement

Expected outcome: paid capabilities exist only when server-derived entitlement explicitly permits them.

## C. Inherited validation gate

The private v0.2 acceptance suite remains mandatory and must be rerun after SaaS migration. SaaS PASS cannot compensate for a regression in evidence, scope, PIT, approval, contradiction, lineage, integrity, or fail-closed behavior.

## D. Release gate

Before UI/UX:

- tenant schema implemented
- RLS enabled and tested on every exposed tenant-owned relation
- privileged functions/views audited
- service credentials server-only
- billing webhook signature verification implemented
- webhook idempotency and event ordering policy implemented
- entitlement derivation server-side
- subscription reconciliation path implemented
- public SaaS security tests green
- private v0.2 suite green
- private v0.3 adversarial suite green

Only then may status change to **SAAS ARCHITECTURE v0.3 — P0 CLOSED / ELIGIBLE FOR UI**.
