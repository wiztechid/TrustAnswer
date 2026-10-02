# Quota Authority v0.3

Quota periods are database-authoritative.

Application code supplies only tenant, metric, quantity, idempotency key and source. It cannot choose a billing period. The database resolves current_period_start/current_period_end from trusted subscription state and fails closed when the period is unknown.

This prevents quota reset by inventing a new period boundary.

Concurrency is serialized per tenant+metric+period and the entitlement row is checked inside the same transaction path.

Status: **STATIC HARDENED / TWO-SESSION RUNTIME TEST PENDING**.
