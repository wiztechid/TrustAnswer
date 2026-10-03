# Billing Identity Binding v0.3

Status: **IMPLEMENTED / RUNTIME QC PENDING**

Provider customer/subscription identifiers are not tenant authority by themselves.

A server-managed binding must already exist and be ACTIVE for the exact tuple:

`provider + provider_customer_id + provider_subscription_id -> tenant_id`

Both provider customer ID and subscription ID are globally unique within the provider namespace. Ambiguous or partial mapping returns no tenant and must enter reconciliation.

Client roles may read their own binding through RLS for support/debug visibility, but cannot create, mutate, activate, revoke, or execute the resolver.

This prevents a webhook payload, checkout redirect, or browser request from choosing its tenant merely by supplying identifiers.
