# TrustAnswer — Current Status

Last updated: 2026-10-04

## Product direction
TrustAnswer is a multi-tenant SaaS validator for security questionnaires. Core promise: **Never send a security answer you cannot prove.** AI is not authoritative and is not required for MVP.

## Architecture status
**SaaS Architecture v0.3 — P0 authority foundations and Paddle webhook boundary closed; product integration remains pending.**

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

### 7. Paddle webhook HTTP boundary — P0 CLOSED / FROZEN
Runtime/CI-proven:
- Web-standard POST adapter preserves the unparsed raw request body and exact Paddle-Signature header;
- official Paddle SDK verifies the signature before any store mutation;
- only supported subscription events enter the billing processor;
- checkout binding handle is accepted only as normalized 64-hex non-secret material;
- SHA-256 payload identity is derived from the same verified raw body;
- TypeScript is a thin router: replay, ordering, reconciliation, plan mapping, entitlement, and atomic transition authority remain in PostgreSQL;
- concrete RPC-backed store and minimal server-only PostgREST transport are wired;
- service-role and Paddle secrets stay inside the deployment composition;
- RECONCILE and storage failures return retryable non-2xx responses rather than false acknowledgement;
- raw-body, transport, store, deployment, and HTTP adapter regression suites are executed by Boundary CI.

A hosting-framework route still needs to call the Web-standard adapter at deployment time, but it must not reimplement billing authority or parse the body first.

### 8. Authority concurrency — P0 CLOSED / FROZEN
Boundary CI #217 and #219 prove real two-session PostgreSQL races:
- FREE quota at 24/25 permits exactly one concurrent final consumption and finishes at 25;
- two ACTIVE OWNERs concurrently removing their own authority permit exactly one transition and finish with one ACTIVE OWNER.
These are runtime serialization proofs, not source-order checks.

### 9. Generic historical revision immutability — P0 CLOSED / FROZEN
Boundary CI #249 proves canonical answer, evidence, and question-answer historical revision rows reject privileged UPDATE and DELETE at the database trigger layer while append of a new question-answer revision remains legal. Browser grants/RLS are therefore not the sole immutability boundary.

### 10. Reproducible dependency installation — P0 CLOSED / FROZEN
Boundary CI #257/#258 proves the committed npm lockfile installs cleanly with `npm ci --ignore-scripts`; #259/#260 confirms the local dependency/environment ignore boundary introduces no regression. The temporary lockfile bootstrap workflow has been removed after producing the committed lockfile.

### 11. GitHub → Cloudflare Worker deployment boundary — P0 CLOSED / FROZEN
Boundary CI #229 proves the thin Worker route delegates only the Paddle webhook path to the frozen Web-standard raw-body adapter. Boundary CI #231 additionally proves the pinned Wrangler toolchain can compile/bundle the Worker with a real deploy dry-run. Runtime secrets remain environment-only and no billing authority moved into the hosting layer.

## Current migrations
Migrations are sequential through:
`20261003002100_generic_revision_immutability.sql`

## CI status
Latest verified run at this checkpoint: **Boundary CI #260 — SUCCESS**.
It includes migrations from zero plus schema security, billing identity, DB-derived entitlement, quota authority, answer revision, submission authority, tenant bootstrap, checkout binding, atomic initial billing, RLS execution, and the TypeScript billing boundary suites through raw-body HTTP adaptation.

## Frozen areas
Do not modify without a concrete defect:
- Answer → Review → Entitlement → Submission chain
- Trusted tenant + FREE bootstrap
- Trusted Paddle identity authority foundation
- Paddle webhook HTTP boundary
- Membership and quota authority concurrency
- Generic historical revision immutability
- Reproducible dependency installation
- GitHub → Cloudflare Worker deployment boundary

## Next execution priorities
1. Port the remaining v0.2 adversarial validator suite to the SaaS engine before product UI.
2. Keep AI and confidential evidence-file hosting out of MVP until their gates are met.

## Public/private boundary
Public repository may contain public-safe architecture, migrations, contracts, and defensive tests. Private moat/adversarial recipes beyond what is necessary for regression safety must not be published.
