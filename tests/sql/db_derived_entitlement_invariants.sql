-- TrustAnswer v0.3 — DB-derived entitlement adversarial runtime checks
-- Disposable database only.

begin;

insert into auth.users(id,aud,role,email,created_at,updated_at) values
('00000000-0000-0000-0000-000000009901','authenticated','authenticated','billing-test@example.invalid',now(),now());

insert into public.tenants(id,name) values
('00000000-0000-0000-0000-000000009000','Billing Test Tenant');

insert into public.billing_identity_bindings(
 tenant_id,provider,provider_customer_id,provider_subscription_id,state
) values (
 '00000000-0000-0000-0000-000000009000','PADDLE','ctm_db_auth','sub_db_auth','ACTIVE'
);

insert into public.plan_catalog(plan_code,provider,provider_price_id,active,entitlements) values
('PRO','PADDLE','pri_pro_active',true,'{"question_limit":2500,"team_review":true}'::jsonb),
('SOLO','PADDLE','pri_solo_inactive',false,'{"question_limit":500}'::jsonb);

-- Active known price + valid period derives PRO and catalog limits in DB.
select public.ta_commit_provider_billing_event(
 'evt_db_1','subscription.updated','2026-10-03T00:01:00Z','h1',
 'ctm_db_auth','sub_db_auth','pri_pro_active','active',
 '2026-10-01T00:00:00Z','2026-11-01T00:00:00Z'
);
do $bill$
begin
 if not exists(select 1 from public.entitlements where tenant_id='00000000-0000-0000-0000-000000009000' and plan_code='PRO' and status='ACTIVE' and limits='{"question_limit":2500,"team_review":true}'::jsonb)
 then raise exception 'BILL-I01: known active mapping not derived from catalog'; end if;
end $bill$;

-- Unknown price must fail closed.
select public.ta_commit_provider_billing_event(
 'evt_db_2','subscription.updated','2026-10-03T00:02:00Z','h2',
 'ctm_db_auth','sub_db_auth','pri_forged_pro','active',
 '2026-10-01T00:00:00Z','2026-11-01T00:00:00Z'
);
do $bill$
begin
 if not exists(select 1 from public.entitlements where tenant_id='00000000-0000-0000-0000-000000009000' and plan_code='FREE' and status='UNKNOWN' and limits='{}'::jsonb)
 then raise exception 'BILL-I02: unknown price did not fail closed'; end if;
end $bill$;

-- Inactive catalog price must fail closed.
select public.ta_commit_provider_billing_event(
 'evt_db_3','subscription.updated','2026-10-03T00:03:00Z','h3',
 'ctm_db_auth','sub_db_auth','pri_solo_inactive','active',
 '2026-10-01T00:00:00Z','2026-11-01T00:00:00Z'
);
do $bill$
begin
 if not exists(select 1 from public.entitlements where tenant_id='00000000-0000-0000-0000-000000009000' and plan_code='FREE' and status='UNKNOWN')
 then raise exception 'BILL-I03: inactive price did not fail closed'; end if;
end $bill$;

-- Active/trialing without a complete provider period may not become paid.
select public.ta_commit_provider_billing_event(
 'evt_db_4','subscription.updated','2026-10-03T00:04:00Z','h4',
 'ctm_db_auth','sub_db_auth','pri_pro_active','active',null,null
);
do $bill$
begin
 if not exists(select 1 from public.entitlements where tenant_id='00000000-0000-0000-0000-000000009000' and plan_code='FREE' and status='UNKNOWN')
 then raise exception 'BILL-I04: active without period became paid'; end if;
end $bill$;

-- Blocked provider states must strip paid plan/limits.
select public.ta_commit_provider_billing_event(
 'evt_db_5','subscription.updated','2026-10-03T00:05:00Z','h5',
 'ctm_db_auth','sub_db_auth','pri_pro_active','past_due',
 '2026-10-01T00:00:00Z','2026-11-01T00:00:00Z'
);
do $bill$
begin
 if not exists(select 1 from public.entitlements where tenant_id='00000000-0000-0000-0000-000000009000' and plan_code='FREE' and status='BLOCKED' and limits='{}'::jsonb)
 then raise exception 'BILL-I05: blocked status retained paid entitlement'; end if;
end $bill$;

rollback;
