-- TrustAnswer SaaS v0.3 — privilege hardening
-- Applies after 20261002_0001_multitenant_foundation.sql.

-- Authorization helpers are callable only by authenticated requests and privileged server roles.
revoke all on function public.ta_is_active_member(uuid) from public, anon;
revoke all on function public.ta_has_role(uuid, public.ta_member_role[]) from public, anon;
grant execute on function public.ta_is_active_member(uuid) to authenticated, service_role;
grant execute on function public.ta_has_role(uuid, public.ta_member_role[]) to authenticated, service_role;

-- Server-authoritative relations: remove direct client mutation privileges even if a future
-- RLS policy is accidentally added. SELECT remains intentionally available only where RLS
-- policies already authorize tenant membership.
revoke insert, update, delete, truncate, references, trigger
  on public.tenant_memberships from anon, authenticated;

revoke insert, update, delete, truncate, references, trigger
  on public.subscriptions from anon, authenticated;

revoke insert, update, delete, truncate, references, trigger
  on public.entitlements from anon, authenticated;

revoke all on public.webhook_events from anon, authenticated;

revoke insert, update, delete, truncate, references, trigger
  on public.submissions from anon, authenticated;

revoke insert, update, delete, truncate, references, trigger
  on public.submission_items from anon, authenticated;

-- Reviews are append-oriented from the client: no UPDATE/DELETE path.
revoke update, delete, truncate, references, trigger
  on public.reviews from anon, authenticated;

-- Tenant rows themselves are server-created/managed in v0.3.
revoke insert, update, delete, truncate, references, trigger
  on public.tenants from anon, authenticated;

-- Defense against accidental anonymous table access. Authenticated access remains subject
-- to explicit RLS policies and table privileges.
revoke all on all tables in schema public from anon;
