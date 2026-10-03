-- TrustAnswer v0.3 — atomic initial Paddle binding runtime checks
begin;
insert into auth.users(id,aud,role,email,created_at,updated_at)
values('00000000-0000-0000-0000-000000003001','authenticated','authenticated','atomic-bind@example.invalid',now(),now());
insert into public.tenants(id,name) values('00000000-0000-0000-0000-000000003000','Atomic Bind');
insert into public.tenant_memberships(tenant_id,user_id,role,state)
values('00000000-0000-0000-0000-000000003000','00000000-0000-0000-0000-000000003001','OWNER','ACTIVE');
insert into public.plan_catalog(plan_code,provider,provider_price_id,active,entitlements)
values('PRO_ATOMIC','PADDLE','pri_atomic',true,'{"questions":2500}'::jsonb);

select public.ta_issue_checkout_binding('00000000-0000-0000-0000-000000003000','00000000-0000-0000-0000-000000003001',repeat('1',64),now()+interval '15 minutes');

-- ATOM-I01 invalid billing period fails before any identity/token mutation.
do $a$
begin
 begin
  perform public.ta_bind_and_commit_provider_subscription(repeat('1',64),'evt_bad','subscription.created',now(),'hash','ctm_bad','sub_bad','pri_atomic','active',now(),now()-interval '1 minute');
  raise exception 'ATOM-I01: invalid initial event accepted';
 exception when others then
  if sqlerrm='ATOM-I01: invalid initial event accepted' then raise; end if;
  if sqlerrm<>'BILLING_PERIOD_INVALID' then raise; end if;
 end;
 if exists(select 1 from public.billing_identity_bindings where provider_customer_id='ctm_bad')
 then raise exception 'ATOM-I01: partial binding escaped'; end if;
 if (select consumed_at from public.checkout_binding_tokens where token_hash=repeat('1',64)) is not null
 then raise exception 'ATOM-I01: failed event consumed handle'; end if;
end $a$;

-- ATOM-I02 valid first event atomically binds, commits entitlement, and consumes handle.
do $a$
declare r text;
begin
 r:=public.ta_bind_and_commit_provider_subscription(repeat('1',64),'evt_ok','subscription.created',now(),'hash-ok','ctm_ok','sub_ok','pri_atomic','active',now(),now()+interval '30 days');
 if r<>'APPLIED' then raise exception 'ATOM-I02: result %',r; end if;
 if not exists(select 1 from public.billing_identity_bindings where tenant_id='00000000-0000-0000-0000-000000003000' and provider_customer_id='ctm_ok' and provider_subscription_id='sub_ok' and binding_state='ACTIVE')
 then raise exception 'ATOM-I02: binding missing'; end if;
 if not exists(select 1 from public.entitlements where tenant_id='00000000-0000-0000-0000-000000003000' and plan_code='PRO_ATOMIC' and status='ACTIVE')
 then raise exception 'ATOM-I02: DB-derived entitlement missing'; end if;
 if (select consumed_at from public.checkout_binding_tokens where token_hash=repeat('1',64)) is null
 then raise exception 'ATOM-I02: handle not consumed'; end if;
end $a$;

-- ATOM-I03 replay cannot reuse consumed handle.
do $a$
begin
 begin
  perform public.ta_bind_and_commit_provider_subscription(repeat('1',64),'evt_replay','subscription.created',now(),'hash-r','ctm_other','sub_other','pri_atomic','active',now(),now()+interval '30 days');
  raise exception 'ATOM-I03: consumed handle replay accepted';
 exception when others then
  if sqlerrm='ATOM-I03: consumed handle replay accepted' then raise; end if;
  if sqlerrm<>'CHECKOUT_BINDING_ALREADY_CONSUMED' then raise; end if;
 end;
end $a$;

-- ATOM-I04 standalone consume primitive is no longer service reachable.
set local role service_role;
do $a$
begin
 begin
  perform public.ta_consume_checkout_binding(repeat('1',64),'ctm_escape','sub_escape');
  raise exception 'ATOM-I04: split consume primitive still service reachable';
 exception when insufficient_privilege then null;
 end;
end $a$;
reset role;
rollback;
