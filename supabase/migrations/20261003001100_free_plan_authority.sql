-- TrustAnswer v0.3 — authoritative FREE plan provisioning
-- FREE limits are database-owned and lifetime-scoped.

create table public.internal_plan_catalog (
  plan_code text primary key,
  active boolean not null default true,
  limits jsonb not null,
  quota_scope text not null check (quota_scope in ('LIFETIME','BILLING_PERIOD'))
);
alter table public.internal_plan_catalog enable row level security;
revoke all on public.internal_plan_catalog from public,anon,authenticated;

insert into public.internal_plan_catalog(plan_code,active,limits,quota_scope)
values('FREE',true,'{"questions":25}'::jsonb,'LIFETIME');

create or replace function public.ta_provision_free_entitlement(p_tenant_id uuid)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare v_limits jsonb;
begin
  select limits into v_limits from public.internal_plan_catalog
  where plan_code='FREE' and active=true and quota_scope='LIFETIME';
  if not found then raise exception 'FREE_PLAN_AUTHORITY_MISSING'; end if;

  insert into public.entitlements(tenant_id,plan_code,status,limits,derived_at)
  values(p_tenant_id,'FREE','ACTIVE',v_limits,now())
  on conflict (tenant_id) do nothing;
end;
$$;
revoke all on function public.ta_provision_free_entitlement(uuid) from public,anon,authenticated;
grant execute on function public.ta_provision_free_entitlement(uuid) to service_role;
