# Atomic Quota Contract v0.3

Status: **IMPLEMENTED / CONCURRENCY EXECUTION PENDING**

Paid usage is consumed in the database, not checked and incremented separately in application code.

For each tenant + metric, the quota RPC serializes concurrent consumption, locks the current entitlement, calculates usage from the server-only usage ledger, enforces the current limit, and appends usage atomically.

## Fail-closed rules

- missing/non-ACTIVE entitlement -> DENY
- missing or malformed metric limit -> DENY
- limit exceeded -> DENY
- client cannot call quota RPC directly
- client cannot mutate usage ledger
- duplicate idempotency key with identical metric/quantity -> no second consumption
- same idempotency key with different metric/quantity -> conflict

## Runtime gate

A real two-session database test must still prove that concurrent requests near the final quota unit cannot both consume beyond the limit.
