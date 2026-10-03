-- TrustAnswer v0.3 — authoritative quota runtime adversarial checks
begin;

insert into public.tenants(id,name) values
('00000000-0000-0000-0000-000000008000','Free Quota Test'),
('00000000-0000-0000-0000-000000008100','Paid Quota Test');

select public.ta_provision_free_entitlement('00000000-0000-0000-0000-000000008000');

-- FREE: 25 lifetime allowed.
select public.ta_consume_authoritative_quota(
 '00000000-0000-0000-0000-000000008000','questions',25,'free-25','test'
);
do $quota$
begin
 if not exists(select 1 from public.usage_events where tenant_id='00000000-0000-0000-0000-000000008000' and metric='questions' and quantity=25 and period_start is null and period_end is null)
 then raise exception 'QUOTA-I01: FREE usage not lifetime-scoped'; end if;
end $quota$;

-- Duplicate must not consume again.
select public.ta_consume_authoritative_quota(
 '00000000-0000-0000-0000-000000008000','questions',25,'free-25','test'
);
do $quota$
declare n bigint;
begin
 select coalesce(sum(quantity),0) into n from public.usage_events where tenant_id='00000000-0000-0000-0000-000000008000' and metric='questions';
 if n<>25 then raise exception 'QUOTA-I02: duplicate consumed usage'; end if;
end $quota$;

-- 26th lifetime question must fail.
do $quota$
begin
 begin
   perform public.ta_consume_authoritative_quota(
    '00000000-0000-0000-0000-000000008000','questions',1,'free-26','test');
   raise exception 'QUOTA-I03: 26th FREE question was accepted';
 exception when others then
   if sqlerrm='QUOTA-I03: 26th FREE question was accepted' then raise; end if;
   if sqlerrm<>'QUOTA_EXCEEDED' then raise; end if;
 end;
end $quota$;

-- Paid entitlement without authoritative subscription period must fail.
insert into public.entitlements(tenant_id,plan_code,status,limits)
values('00000000-0000-0000-0000-000000008100','SOLO','ACTIVE','{"questions":500}'::jsonb);
do $quota$
begin
 begin
   perform public.ta_consume_authoritative_quota(
    '00000000-0000-0000-0000-000000008100','questions',1,'paid-no-period','test');
   raise exception 'QUOTA-I04: paid quota accepted without billing period';
 exception when others then
   if sqlerrm='QUOTA-I04: paid quota accepted without billing period' then raise; end if;
   if sqlerrm<>'QUOTA_PERIOD_UNKNOWN' then raise; end if;
 end;
end $quota$;

rollback;
