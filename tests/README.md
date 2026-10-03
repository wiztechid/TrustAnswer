# TrustAnswer Database Security Tests

These tests are designed for an **isolated disposable Supabase/Postgres environment only**.

## Order

1. Apply production migrations in filename order.
2. Create the fictional test auth identities documented in the harness.
3. Execute `tests/sql/rls_execution_harness.sql`.
4. Treat any raised exception as a failed security gate.
5. The harness rolls back its fixture data.

## Important

Passing this public harness is necessary but not sufficient for P0 closure. The private adversarial suite remains authoritative and must include broader bypass attempts that are intentionally not published.

Do not run security fixtures against production.
