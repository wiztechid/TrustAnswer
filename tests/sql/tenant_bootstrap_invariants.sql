-- TrustAnswer v0.3 — trusted tenant bootstrap adversarial runtime checks
begin;

insert into auth.users(id,aud,role,email,created_at,updated_at)
values('00000000-0000-0000-0000-000000005001','authenticated','authenticated','bootstrap@example.invalid',now(),now());

-- BOOT-I01 valid trusted bootstrap creates exactly tenant + OWNER + DB-authoritative FREE.
do $boot$
declare tid uuid; expected jsonb; actual jsonb;
begin
 select limits into expected from public.internal_plan_catalog where plan_code='FREE' and active=true;
 tid:=public.ta_bootstrap_tenant('00000000-0000-0000-0000-000000005001','  Bootstrap Workspace  ');
 if not exists(select 1 from public.tenants where id=tid and name='Bootstrap Workspace')
 then raise exception 'BOOT-I01: tenant missing/name not normalized'; end if;
 if not exists(select 1 from public.tenant_memberships where tenant_id=tid and user_id='00000000-0000-0000-0000-000000005001' and role='OWNER' and state='ACTIVE')
 then raise exception 'BOOT-I01: owner membership missing'; end if;
 select limits into actual from public.entitlements where tenant_id=tid and plan_code='FREE' and status='ACTIVE';
 if actual is distinct from expected then raise exception 'BOOT-I01: FREE limits not catalog-derived'; end if;
end $boot$;

-- BOOT-I02 invalid user fails before tenant creation.
do $boot$
declare before_n bigint;
begin
 select count(*) into before_n from public.tenants;
 begin
  perform public.ta_bootstrap_tenant('00000000-0000-0000-0000-000000005099','Ghost');
  raise exception 'BOOT-I02: nonexistent user accepted';
 exception when others then
  if sqlerrm='BOOT-I02: nonexistent user accepted' then raise; end if;
  if sqlerrm<>'TENANT_BOOTSTRAP_USER_NOT_FOUND' then raise; end if;
 end;
 if (select count(*) from public.tenants)<>before_n then raise exception 'BOOT-I02: orphan tenant created'; end if;
end $boot$;

-- BOOT-I03 blank name rejected.
do $boot$
begin
 begin
  perform public.ta_bootstrap_tenant('00000000-0000-0000-0000-000000005001','   ');
  raise exception 'BOOT-I03: blank name accepted';
 exception when others then
  if sqlerrm='BOOT-I03: blank name accepted' then raise; end if;
  if sqlerrm<>'TENANT_BOOTSTRAP_INPUT_INVALID' then raise; end if;
 end;
end $boot$;

-- BOOT-I04 FREE authority failure rolls back tenant and membership atomically.
do $boot$
declare before_t bigint; before_m bigint;
begin
 select count(*) into before_t from public.tenants;
 select count(*) into before_m from public.tenant_memberships;
 update public.internal_plan_catalog set active=false where plan_code='FREE';
 begin
  perform public.ta_bootstrap_tenant('00000000-0000-0000-0000-000000005001','Must Roll Back');
  raise exception 'BOOT-I04: bootstrap survived missing FREE authority';
 exception when others then
  if sqlerrm='BOOT-I04: bootstrap survived missing FREE authority' then raise; end if;
  if sqlerrm<>'FREE_PLAN_AUTHORITY_MISSING' then raise; end if;
 end;
 if (select count(*) from public.tenants)<>before_t or (select count(*) from public.tenant_memberships)<>before_m
 then raise exception 'BOOT-I04: partial bootstrap escaped rollback'; end if;
 update public.internal_plan_catalog set active=true where plan_code='FREE';
end $boot$;

-- BOOT-I05 browser cannot invoke bootstrap or primitive.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000005001',true);
do $boot$
begin
 begin
  perform public.ta_bootstrap_tenant('00000000-0000-0000-0000-000000005001','Browser Escape');
  raise exception 'BOOT-I05: authenticated bootstrap execute accepted';
 exception when insufficient_privilege then null;
 end;
 begin
  perform public.ta_provision_free_entitlement('00000000-0000-0000-0000-000000000001');
  raise exception 'BOOT-I05: authenticated FREE primitive accepted';
 exception when insufficient_privilege then null;
 end;
end $boot$;
reset role;

-- BOOT-I06 service role may bootstrap but cannot invoke FREE primitive directly.
set local role service_role;
do $boot$
declare tid uuid;
begin
 tid:=public.ta_bootstrap_tenant('00000000-0000-0000-0000-000000005001','Service Bootstrap');
 if not exists(select 1 from public.entitlements where tenant_id=tid and plan_code='FREE' and status='ACTIVE')
 then raise exception 'BOOT-I06: service bootstrap failed'; end if;
 begin
  perform public.ta_provision_free_entitlement(tid);
  raise exception 'BOOT-I06: service direct FREE primitive accepted';
 exception when insufficient_privilege then null;
 end;
end $boot$;
reset role;

rollback;
