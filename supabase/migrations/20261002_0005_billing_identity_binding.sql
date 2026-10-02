-- TrustAnswer v0.3 — provider identity binding hardening
-- Server-managed mapping established by trusted checkout/provisioning flow.

create table public.billing_identity_bindings (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  provider text not null check (provider='PADDLE'),
  provider_customer_id text not null,
  provider_subscription_id text,
  binding_state text not null check (binding_state in ('PENDING','ACTIVE','REVOKED')),
  created_at timestamptz not null default now(),
  activated_at timestamptz,
  revoked_at timestamptz,
  primary key (tenant_id,provider),
  unique (provider,provider_customer_id),
  unique (provider,provider_subscription_id)
);

alter table public.billing_identity_bindings enable row level security;
create policy billing_identity_read on public.billing_identity_bindings for select
using (public.ta_is_active_member(tenant_id));

revoke insert,update,delete,truncate,references,trigger
  on public.billing_identity_bindings from anon,authenticated;

create or replace function public.ta_resolve_billing_tenant(
  p_provider text,
  p_customer_id text,
  p_subscription_id text
) returns uuid
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_tenant uuid;
begin
  if p_provider <> 'PADDLE' or p_customer_id is null or p_subscription_id is null then
    return null;
  end if;

  select tenant_id into v_tenant
  from public.billing_identity_bindings
  where provider=p_provider
    and provider_customer_id=p_customer_id
    and provider_subscription_id=p_subscription_id
    and binding_state='ACTIVE';

  return v_tenant;
end;
$$;

revoke all on function public.ta_resolve_billing_tenant(text,text,text)
  from public,anon,authenticated;
grant execute on function public.ta_resolve_billing_tenant(text,text,text)
  to service_role;
