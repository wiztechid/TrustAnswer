# TrustAnswer — Current Status

Last updated: 2026-10-03

## Product direction
TrustAnswer is a multi-tenant SaaS validator for security questionnaires. Core promise: **Never send a security answer you cannot prove.** AI is not authoritative and is not required for MVP.

## Architecture status
**SaaS Architecture v0.3 — P0 authority foundations substantially closed; HTTP/product integration still pending.**

The original v0.2 validation constitution remains inherited: absence of a failure signal is never evidence of success.

## Runtime-proven P0 closures

### 1. Multi-tenant / RLS foundation — CLOSED
Disposable Supabase CI applies migrations from zero and executes schema/RLS runtime invariants. Tenant-owned rows use explicit tenant identity, RLS, role checks, immutable tenant ownership, and server-only privileged tables.

### 2. DB-derived billing entitlement — CLOSED
Provider facts are accepted; plan, limits, and entitlement are derived from database catalog authority. Unknown/inactive mappings fail closed. Caller-derived entitlement RPCs are not service reachable.

### 3. Quota authority — CLOSED for current semantics
FREE uses authoritative lifetime quota (25 questions). Paid quota requires authoritative subscription period. Runtime suite proves lifetime enforcement, idempotency, 26th-question denial, and paid-period fail-closed behavior.

### 4. Answer → Review → Submission authority chain — P0 CLOSED / FROZEN
Runtime-proven:
- append-only question answer revisions and authoritative HEAD;
- historical reviews do not pin HEAD;
- review creation requires current exact revision;
- stale approval cannot authorize a newer revision;
- submission requires ACTIVE SOLO/PRO entitlement;
- server-only exact-bound submission creation;
- exact answer revision + approved review snapshot;
- direct service table insertion denied;
- historical submissions/items reject UPDATE/DELETE at DB trigger level;
- legacy text refs are compatibility snapshot only and non-authoritative.

### 5. Trusted tenant + FREE provisioning bootstrap — P0 CLOSED / FROZEN
Atomic trusted bootstrap creates tenant + initial OWNER + authoritative FREE entitlement. Invalid user/input and FREE-authority failure roll back without orphan state. Browser cannot invoke bootstrap or FREE provisioning primitive directly.

### 6. Trusted Paddle identity authority foundation — P0 CLOSED / FROZEN
Runtime-proven:
- opaque non-secret 64-hex checkout binding handle;
- OWNER/ADMIN issuance requirement;
- expiry and one-time semantics;
- exact provider customer + subscription identity binding;
- duplicate identity rollback;
- browser cannot issue/consume;
- verified webhook boundary only permits bootstrap on subscription.created;
- replay/redelivery does not re-consume binding;
- first subscription binding + DB-derived entitlement + billing-event commit are atomic;
- failed initial billing event leaves zero binding and unconsumed handle;
- split consume primitive is retired from service_role;
- legacy caller-derived entitlement RPC remains inaccessible;
- DB-I10 locks the allowed billing RPC surface.

## Important boundary
The **billing identity authority foundation is closed**, but a production HTTP webhook handler/composition has not yet been demonstrated in this repository. Do not claim end-to-end Paddle integration is complete until a real handler composes:
raw request body → Paddle signature verification → trusted normalizer → exact identity lookup / atomic initial binding → billing commit → deterministic HTTP response.

## Current migrations
Migrations are sequential through:
`20261003002000_atomic_initial_billing_binding.sql`

## CI status
Latest verified run at this checkpoint: **Boundary CI #155 — SUCCESS**.
It includes migrations from zero plus schema security, billing identity, DB-derived entitlement, quota authority, answer revision, submission authority, tenant bootstrap, checkout binding, atomic initial billing, RLS execution, and TypeScript/boundary tests.

## Frozen areas
Do not modify without a concrete defect:
- Answer → Review → Entitlement → Submission chain
- Trusted tenant + FREE bootstrap
- Trusted Paddle identity authority foundation

## Next execution priorities
1. Build the production webhook composition/handler around the already-frozen billing authority boundary.
2. Add handler-level tests for raw-body preservation, invalid signature, deterministic success/retry responses, and no side effects before verification.
3. Audit generic historical immutability coverage outside the frozen submission chain.
4. Add true two-session concurrency tests for membership and quota locks.
5. Add package lock and move CI from `npm install` to `npm ci`.
6. Port the remaining v0.2 adversarial validator suite to the SaaS engine before product UI.
7. Keep AI and confidential evidence-file hosting out of MVP until their gates are met.

## Public/private boundary
Public repository may contain public-safe architecture, migrations, contracts, and defensive tests. Private moat/adversarial recipes beyond what is necessary for regression safety must not be published.
