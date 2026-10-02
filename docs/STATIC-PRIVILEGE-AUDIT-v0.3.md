# Static Privilege Audit v0.3

Status: **PATCHED — LIVE DATABASE VERIFICATION PENDING**

Static review of the first multi-tenant migration found a privilege-hardening gap: RLS policies were restrictive, but authorization helpers and server-authoritative tables also need explicit SQL privilege boundaries.

## Patch

The follow-up migration:

- revokes PUBLIC/anon execution of SECURITY DEFINER authorization helpers
- grants helper execution only to authenticated/server roles
- revokes client mutation privileges on membership state
- revokes client mutation privileges on subscription and entitlement state
- revokes all client privileges on webhook event ledger
- revokes client mutation privileges on immutable submission state
- revokes UPDATE/DELETE on append-oriented reviews
- keeps tenant creation/management server-authoritative
- removes anonymous table access across the public schema

## Why both RLS and grants

RLS controls which rows a permitted SQL operation can affect. SQL privileges control whether the role may perform the operation at all. TrustAnswer requires both for privileged/server-authoritative domains.

## Remaining execution gate

Static hardening is not proof of runtime isolation. The migrations still require execution against an isolated Supabase/Postgres environment followed by the RLS acceptance suite.
