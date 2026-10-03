# Billing Adversarial Acceptance Contract v0.3

Status: **TEST CONTRACT DEFINED — EXECUTION PENDING**

Expected outcome for every case is fail-closed unless a verified, current, correctly mapped entitlement explicitly permits the operation.

1. Client edits plan_code to PRO.
2. Client supplies another tenant's provider customer ID.
3. Client supplies another tenant's subscription ID.
4. Invalid/missing webhook signature.
5. Correct-looking JSON with modified raw body.
6. Same verified event delivered twice.
7. Older verified event arrives after newer verified event.
8. Cancellation event replayed after later legitimate reactivation.
9. Activation event replayed after later cancellation.
10. Unknown provider price ID.
11. Known price ID marked inactive internally.
12. Provider subscription maps ambiguously or conflicts with tenant mapping.
13. Checkout success redirect without verified subscription event.
14. Cached PRO UI after server entitlement becomes FREE.
15. Past-due state outside explicit grace policy.
16. Paused/canceled state attempts paid mutation.
17. Missing local subscription row for claimed paid tenant.
18. Local/provider reconciliation disagreement.
19. Duplicate usage event/idempotency key.
20. Quota enforcement attempted only in browser.

## Gate

Billing P0 cannot close from static review. These cases must execute against server webhook/entitlement code plus a test database/provider sandbox or faithful signed-event harness.
