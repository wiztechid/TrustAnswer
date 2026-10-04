# Multi-Tenant RLS Acceptance Contract v0.3

Status: **IMPLEMENTATION CONTRACT ADDED — DATABASE EXECUTION PENDING**

This public-safe contract accompanies the foundational SQL migration. It states expected outcomes without publishing private exploit recipes.

## Required database-level checks

1. User A, active in Tenant A, can read Tenant A ordinary records.
2. User A cannot read Tenant B ordinary records by known UUID.
3. User A cannot insert a Tenant B row by supplying Tenant B tenant_id.
4. User A cannot change a Tenant A row's tenant_id to Tenant B.
5. Composite foreign keys reject a child whose parent belongs to another tenant.
6. Removed/suspended membership immediately loses ordinary tenant access on the next database request.
7. REVIEWER cannot gain ordinary write privileges merely through review authority.
8. MEMBER cannot delete protected records where deletion is owner/admin-only.
9. Browser roles cannot write memberships.
10. Browser roles cannot write subscription, entitlement, webhook, submission, or immutable submission-item state.
11. Browser roles cannot create a review on behalf of another reviewer_user_id.
12. Cross-tenant answer/evidence bindings fail at both RLS and relational-integrity boundaries.
13. Cross-tenant questionnaire/customer relationships fail relational integrity.
14. Cross-tenant gap/question relationships fail relational integrity.
15. Cross-tenant submission/question relationships fail relational integrity.
16. No exposed tenant-owned table exists without RLS.
17. No SECURITY DEFINER helper uses caller-controlled search_path.
18. No service-role or privileged credential is present in client/public source.

## Fail-closed interpretation

A missing policy is not treated as feature breakage to be bypassed; it is DENY until an explicit reviewed policy exists.

## Gate

These checks must be executed against an actual Supabase/Postgres test environment before tenant isolation can be marked P0 CLOSED.
