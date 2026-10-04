# Paddle Server Boundary v0.3

Status: **IMPLEMENTED AS PUBLIC-SAFE CORE / INTEGRATION EXECUTION PENDING**

The webhook transport uses Paddle's official Node SDK for signature verification and passes the unmodified raw request body. Verified subscription events are normalized before reaching entitlement logic.

## Implemented invariants

- raw body verified before trust
- subscription events only
- duplicate event IDs ignored
- older occurred_at cannot overwrite newer accepted state
- distinct same-time events trigger reconciliation rather than arbitrary ordering
- unresolved tenant/provider identity triggers reconciliation
- unknown/inactive plan mapping fails closed
- past_due, paused and canceled do not receive paid entitlement in the initial policy
- active/trialing may receive the mapped plan only when mapping is trusted and reconciliation is clear
- checkout UI is outside the authority chain

## Important implementation requirement

The production BillingStore must make verified-event insertion and subscription-state mutation transactional/idempotent at the database boundary. The in-memory harness is not a substitute for that database guarantee.

## Scheduled changes

A future scheduled cancellation/pause does not immediately rewrite the provider status. The effective provider state remains authoritative until the scheduled change takes effect; local access policy must not invent an earlier cancellation.

## Remaining gate

- wire real server endpoint/raw-body handling
- implement transactional database BillingStore
- execute signed webhook fixtures/sandbox tests
- execute all billing adversarial cases
- implement periodic provider reconciliation
