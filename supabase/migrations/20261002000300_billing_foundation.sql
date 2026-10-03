-- TrustAnswer SaaS v0.3 — billing/entitlement foundation
-- Provider webhook verification occurs in server code before writes reach these tables.

create table public.plan_catalog (
  plan_code text primary key,
  provider text not null check (provider='PADDLE'),
  provider_price_id text not null unique,
  active boolean not null default true,
  entitlements jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.plan_catalog enable row level security;
revoke all on public.plan_catalog from anon, authenticated;

alter table public.webhook_events
  add column tenant_id uuid references public.tenants(id) on delete set null,
  add column provider_event_type text,
  add column provider_object_id text,
  add column processed_at timestamptz,
  add column processing_error_code text;

create index webhook_events_object_order_idx
  on public.webhook_events(provider, provider_object_id, occurred_at);

alter table public.subscriptions
  add column last_event_id text,
  add column last_event_occurred_at timestamptz,
  add column entitlement_state text not null default 'UNKNOWN',
  add column cancel_at timestamptz,
  add column current_period_end timestamptz;

-- Provider identity may not map ambiguously across tenants.
create unique index subscriptions_provider_customer_unique
  on public.subscriptions(provider,provider_customer_id)
  where provider_customer_id is not null;

-- Server-side usage ledger. Append-only to application roles.
create table public.usage_events (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  id uuid not null default gen_random_uuid(),
  metric text not null,
  quantity integer not null check (quantity > 0),
  occurred_at timestamptz not null default now(),
  idempotency_key text not null,
  source text not null,
  primary key (tenant_id,id),
  unique (tenant_id,idempotency_key)
);

alter table public.usage_events enable row level security;
create policy usage_events_read on public.usage_events for select
using (public.ta_is_active_member(tenant_id));
revoke insert, update, delete, truncate, references, trigger
  on public.usage_events from anon, authenticated;

-- No billing table receives a client mutation grant.
-- Entitlement derivation is performed only after a verified provider event or reconciliation.
