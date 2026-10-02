# TrustAnswer — Current Status

Last updated: 2026-10-02

## Current phase

**SaaS Architecture v0.3 Migration — P0 SECURITY GATE DEFINED / NOT YET CLOSED**

TrustAnswer has migrated in product direction from a paid workbook to a multi-tenant membership SaaS.

Core promise remains:

> Never treat a security questionnaire response as ready to send unless its required support and review are valid.

## Commercial model under implementation

- FREE — bounded evaluation/activation tier
- SOLO — $19/month target
- PRO — $49/month target
- annual billing may use approximately two months of discount
- AI is not required at launch
- confidential evidence files are not hosted in MVP; metadata/reference is stored instead

## Architecture inheritance

Architecture v0.2 remains the parent validation contract. Its evidence-first, revision-bound, point-in-time, scope, contradiction, approval, immutable-snapshot and fail-closed rules are inherited unchanged.

The former seven workbook sheets are now seven logical SaaS modules backed by the database and private validation engine.

## New v0.3 P0 boundaries

- multi-tenant database ownership
- tenant membership/roles
- RLS for exposed tenant-owned data
- server-only privileged credentials
- Paddle billing state
- server-derived entitlements
- usage/quota enforcement
- evidence-reference model
- API trust boundary
- cross-tenant and subscription-bypass adversarial testing

## Current gate

Do **not** build UI/UX yet.

Next implementation target:

1. relational schema and migrations
2. RLS policies and authorization helpers
3. auth/membership lifecycle
4. Paddle webhook ingestion + idempotency
5. entitlement resolver
6. evidence-reference domain
7. server-side validation API boundary
8. execute cross-tenant + entitlement adversarial suite
9. rerun inherited private v0.2 acceptance suite

Only after all P0 tests are green may v0.3 freeze and UI work begin.
