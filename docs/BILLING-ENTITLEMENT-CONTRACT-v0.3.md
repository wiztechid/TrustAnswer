# Billing & Entitlement Resolver Contract v0.3

Status: **FOUNDATION DEFINED — WEBHOOK IMPLEMENTATION PENDING**

## Authority chain

`raw webhook bytes -> signature verification -> event idempotency -> trusted provider identity -> tenant mapping -> ordering/reconciliation -> subscription state -> internal plan mapping -> entitlement`

No browser value is authoritative anywhere in this chain.

## Required rules

1. Signature verification uses the exact raw request body before JSON transformation.
2. An event is processed at most once by provider event ID.
3. Duplicate delivery returns success without duplicating side effects.
4. Arrival order is not treated as event truth.
5. Older events cannot overwrite a newer accepted provider state solely because they arrived later.
6. Provider customer/subscription identity maps unambiguously to one tenant.
7. Unknown price/product mapping yields UNKNOWN/BLOCKED entitlement, never a paid default.
8. Unknown provider status yields fail-closed entitlement.
9. Cancellation timing distinguishes scheduled cancellation from already-canceled state.
10. Past-due grace, if later enabled, must be explicit policy with an expiry; no implicit grace.
11. Reconciliation with the provider is required when event history is missing, contradictory, or uncertain.
12. Entitlement is derived from trusted server state; it is not stored from client claims.
13. Quota/usage mutations are server-side and idempotent.
14. Downgrade/cancellation invalidates stale cached paid capability on the next privileged server operation.
15. Checkout success UI is not proof of subscription activation.

## Initial plan model

Public commercial codes:

- FREE
- SOLO
- PRO

Provider price IDs are configuration and must never be accepted from the browser as proof of plan.

## Entitlement uncertainty

When local state and provider state disagree or cannot be ordered safely:

`entitlement_state = UNKNOWN`

Privileged paid operations fail closed until reconciliation resolves the state.

## Webhook processing boundary

The public repository may contain transport/signature verification and high-level state contracts. Proprietary anti-bypass tests and sensitive operational secrets remain private.
