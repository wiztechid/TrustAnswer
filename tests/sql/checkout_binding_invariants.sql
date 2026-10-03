-- TrustAnswer v0.3 — checkout binding adversarial runtime checks
begin;

insert into auth.users(id,aud,role,email,created_at,updated_at) values
('00000000-0000-0000-0000-000000004001','authenticated','authenticated','bind-owner@example.invalid',now(),now()),
('00000000-0000-0000-0000-000000004002','authenticated','authenticated','bind-member@example.invalid',now(),now());
insert into public.tenants(id,name) values
('00000000-0000-0000-0000-000000004000','Bind A'),
('00000000-0000-0000-0000-000000004100','Bind B');
insert into public.tenant_memberships(tenant_id,user_id,role,state) values
('00000000-0000-0000-0000-000000004000','00000000-0000-0000-0000-000000004001','OWNER','ACTIVE'),
('00000000-0000-0000-0000-000000004000','00000000-0000-0000-0000-000000004002','MEMBER','ACTIVE'),
('00000000-0000-0000-0000-000000004100','00000000-0000-0000-0000-000000004001','OWNER','ACTIVE');

-- BIND-I01 owner-issued opaque token resolves exact tenant and binds once.
select public.ta_issue_checkout_binding(
 '00000000-0000-0000-0000-000000004000','00000000-0000-0000-0000-000000004001',
 repeat('a',64),now()+interval '15 minutes');
do $bind$
declare tid uuid;
begin
 tid:=public.ta_consume_checkout_binding(repeat('a',64),'ctm_A','sub_A');
 if tid<>'00000000-0000-0000-0000-000000004000' then raise exception 'BIND-I01: wrong tenant resolved'; end if;
 if not exists(select 1 from public.billing_identity_bindings where tenant_id=tid and provider_customer_id='ctm_A' and provider_subscription_id='sub_A' and binding_state='ACTIVE')
 then raise exception 'BIND-I01: exact billing identity missing'; end if;
end $bind$;

-- BIND-I02 replay is rejected.
do $bind$
begin
 begin
  perform public.ta_consume_checkout_binding(repeat('a',64),'ctm_X','sub_X');
  raise exception 'BIND-I02: token replay accepted';
 exception when others then
  if sqlerrm='BIND-I02: token replay accepted' then raise; end if;
  if sqlerrm<>'CHECKOUT_BINDING_ALREADY_CONSUMED' then raise; end if;
 end;
end $bind$;

-- BIND-I03 unknown token rejected.
do $bind$
begin
 begin
  perform public.ta_consume_checkout_binding(repeat('z',64),'ctm_Z','sub_Z');
  raise exception 'BIND-I03: unknown token accepted';
 exception when others then
  if sqlerrm='BIND-I03: unknown token accepted' then raise; end if;
  if sqlerrm<>'CHECKOUT_BINDING_UNKNOWN' then raise; end if;
 end;
end $bind$;

-- BIND-I04 MEMBER cannot obtain trusted token even through service boundary.
do $bind$
begin
 begin
  perform public.ta_issue_checkout_binding('00000000-0000-0000-0000-000000004000','00000000-0000-0000-0000-000000004002',repeat('b',64),now()+interval '15 minutes');
  raise exception 'BIND-I04: MEMBER issuance accepted';
 exception when others then
  if sqlerrm='BIND-I04: MEMBER issuance accepted' then raise; end if;
  if sqlerrm<>'CHECKOUT_BINDING_FORBIDDEN' then raise; end if;
 end;
end $bind$;

-- BIND-I05 expired token rejected without consumption.
insert into public.checkout_binding_tokens(token_hash,tenant_id,created_by,expires_at,created_at)
values(repeat('c',64),'00000000-0000-0000-0000-000000004000','00000000-0000-0000-0000-000000004001',now()-interval '1 minute',now()-interval '2 minutes');
do $bind$
begin
 begin
  perform public.ta_consume_checkout_binding(repeat('c',64),'ctm_C','sub_C');
  raise exception 'BIND-I05: expired token accepted';
 exception when others then
  if sqlerrm='BIND-I05: expired token accepted' then raise; end if;
  if sqlerrm<>'CHECKOUT_BINDING_EXPIRED' then raise; end if;
 end;
 if (select consumed_at from public.checkout_binding_tokens where token_hash=repeat('c',64)) is not null
 then raise exception 'BIND-I05: expired token consumed'; end if;
end $bind$;

-- BIND-I06 duplicate provider identity fails and leaves second token reusable/unconsumed.
select public.ta_issue_checkout_binding('00000000-0000-0000-0000-000000004100','00000000-0000-0000-0000-000000004001',repeat('d',64),now()+interval '15 minutes');
do $bind$
begin
 begin
  perform public.ta_consume_checkout_binding(repeat('d',64),'ctm_A','sub_OTHER');
  raise exception 'BIND-I06: duplicate customer identity accepted';
 exception when unique_violation then null;
 end;
 if (select consumed_at from public.checkout_binding_tokens where token_hash=repeat('d',64)) is not null
 then raise exception 'BIND-I06: failed binding consumed token'; end if;
 if exists(select 1 from public.billing_identity_bindings where tenant_id='00000000-0000-0000-0000-000000004100')
 then raise exception 'BIND-I06: partial binding escaped rollback'; end if;
end $bind$;

-- BIND-I07 browser cannot issue/consume or access token table.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000004001',true);
do $bind$
begin
 begin
  perform public.ta_issue_checkout_binding('00000000-0000-0000-0000-000000004000','00000000-0000-0000-0000-000000004001',repeat('e',64),now()+interval '15 minutes');
  raise exception 'BIND-I07: browser issuance accepted';
 exception when insufficient_privilege then null;
 end;
 begin
  perform public.ta_consume_checkout_binding(repeat('e',64),'ctm_E','sub_E');
  raise exception 'BIND-I07: browser consume accepted';
 exception when insufficient_privilege then null;
 end;
end $bind$;
reset role;

rollback;
