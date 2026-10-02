-- TrustAnswer v0.3 RLS execution harness
-- Run only against an isolated disposable Supabase/Postgres test database.
-- Requires migrations 0001..0003 already applied.
--
-- This harness validates public security invariants without embedding private exploit recipes.

begin;

-- Fixed fictional UUIDs keep failures reproducible.
-- Test auth users must exist in auth.users before this harness is run:
-- A_OWNER  = 00000000-0000-0000-0000-000000000101
-- A_MEMBER = 00000000-0000-0000-0000-000000000102
-- A_REVIEW = 00000000-0000-0000-0000-000000000103
-- B_OWNER  = 00000000-0000-0000-0000-000000000201

insert into auth.users(id,aud,role,email,created_at,updated_at) values
('00000000-0000-0000-0000-000000000101','authenticated','authenticated','a-owner@example.invalid',now(),now()),
('00000000-0000-0000-0000-000000000102','authenticated','authenticated','a-member@example.invalid',now(),now()),
('00000000-0000-0000-0000-000000000103','authenticated','authenticated','a-review@example.invalid',now(),now()),
('00000000-0000-0000-0000-000000000201','authenticated','authenticated','b-owner@example.invalid',now(),now());

insert into public.tenants(id,name) values
('00000000-0000-0000-0000-000000001000','NimbusDesk Test Tenant A'),
('00000000-0000-0000-0000-000000002000','OtherCo Test Tenant B');

insert into public.tenant_memberships(tenant_id,user_id,role,state) values
('00000000-0000-0000-0000-000000001000','00000000-0000-0000-0000-000000000101','OWNER','ACTIVE'),
('00000000-0000-0000-0000-000000001000','00000000-0000-0000-0000-000000000102','MEMBER','ACTIVE'),
('00000000-0000-0000-0000-000000001000','00000000-0000-0000-0000-000000000103','REVIEWER','ACTIVE'),
('00000000-0000-0000-0000-000000002000','00000000-0000-0000-0000-000000000201','OWNER','ACTIVE');

insert into public.customers(tenant_id,id,name) values
('00000000-0000-0000-0000-000000001000','00000000-0000-0000-0000-000000001101','Customer A1'),
('00000000-0000-0000-0000-000000002000','00000000-0000-0000-0000-000000002101','Customer B1');

insert into public.questionnaires(tenant_id,id,customer_id,title) values
('00000000-0000-0000-0000-000000001000','00000000-0000-0000-0000-000000001201','00000000-0000-0000-0000-000000001101','A questionnaire'),
('00000000-0000-0000-0000-000000002000','00000000-0000-0000-0000-000000002201','00000000-0000-0000-0000-000000002101','B questionnaire');

insert into public.questionnaire_questions(tenant_id,id,questionnaire_id,raw_question) values
('00000000-0000-0000-0000-000000001000','00000000-0000-0000-0000-000000001301','00000000-0000-0000-0000-000000001201','Do you encrypt data at rest?'),
('00000000-0000-0000-0000-000000002000','00000000-0000-0000-0000-000000002301','00000000-0000-0000-0000-000000002201','Do you test backups?');

-- Helper to emulate an authenticated Supabase JWT identity locally.
create or replace function pg_temp.as_user(p_uid uuid)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub',p_uid::text,true);
  perform set_config('request.jwt.claim.role','authenticated',true);
  execute 'set local role authenticated';
end $$;

create or replace function pg_temp.as_privileged()
returns void language plpgsql as $$
begin
  reset role;
  perform set_config('request.jwt.claim.sub','',true);
  perform set_config('request.jwt.claim.role','',true);
end $$;

-- A_OWNER sees A, never B.
select pg_temp.as_user('00000000-0000-0000-0000-000000000101');
do $$
begin
  if (select count(*) from public.customers) <> 1 then
    raise exception 'RLS-A01: owner visibility mismatch';
  end if;
  if exists(select 1 from public.customers where id='00000000-0000-0000-0000-000000002101') then
    raise exception 'RLS-A02: cross-tenant read leak';
  end if;
end $$;

-- MEMBER can create in A but cannot forge B tenant ownership.
insert into public.customers(tenant_id,name)
values ('00000000-0000-0000-0000-000000001000','Member-created A customer');

do $
declare denied boolean := false;
begin
  begin
    insert into public.customers(tenant_id,name)
    values ('00000000-0000-0000-0000-000000002000','forged B customer');
  exception
    when insufficient_privilege or check_violation then denied := true;
  end;
  if not denied then raise exception 'RLS-A03: forged tenant insert unexpectedly succeeded'; end if;
end $;

-- REVIEWER cannot mutate ordinary tenant data.
select pg_temp.as_privileged();
select pg_temp.as_user('00000000-0000-0000-0000-000000000103');
do $
declare denied boolean := false;
begin
  begin
    insert into public.customers(tenant_id,name)
    values ('00000000-0000-0000-0000-000000001000','reviewer write');
  exception
    when insufficient_privilege or check_violation then denied := true;
  end;
  if not denied then raise exception 'RLS-A04: reviewer ordinary write unexpectedly succeeded'; end if;
end $;

-- Client cannot mutate server-authoritative billing/submission relations.
do $
declare denied boolean := false;
begin
  begin
    insert into public.entitlements(tenant_id,plan_code,status)
    values ('00000000-0000-0000-0000-000000001000','PRO','ACTIVE');
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'RLS-A05: client entitlement write unexpectedly succeeded'; end if;
end $;

-- Membership removal is effective on the next statement/request context.
select pg_temp.as_privileged();
update public.tenant_memberships
set state='REMOVED'
where tenant_id='00000000-0000-0000-0000-000000001000'
  and user_id='00000000-0000-0000-0000-000000000102';

select pg_temp.as_user('00000000-0000-0000-0000-000000000102');
do $$
begin
  if exists(select 1 from public.customers where tenant_id='00000000-0000-0000-0000-000000001000') then
    raise exception 'RLS-A06: removed member retained access';
  end if;
end $$;

select pg_temp.as_privileged();

-- Composite tenant-safe FK rejects a Tenant A questionnaire pointing to Tenant B customer.
do $
declare denied boolean := false;
begin
  begin
    insert into public.questionnaires(tenant_id,customer_id,title)
    values (
      '00000000-0000-0000-0000-000000001000',
      '00000000-0000-0000-0000-000000002101',
      'cross-tenant parent attempt'
    );
  exception when foreign_key_violation then denied := true;
  end;
  if not denied then raise exception 'RLS-A07: composite FK allowed cross-tenant parent'; end if;
end $;

-- Structural checks: all public base tables in TrustAnswer's current surface have RLS enabled.
do $$
declare bad text;
begin
  select string_agg(c.relname,', ' order by c.relname) into bad
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind='r'
    and c.relname in (
      'tenants','tenant_memberships','customers','questionnaires','questionnaire_questions',
      'canonical_answers','canonical_answer_revisions','evidence_records','evidence_revisions',
      'answer_evidence_bindings','gaps','reviews','submissions','submission_items',
      'subscriptions','entitlements','webhook_events','plan_catalog','usage_events'
    )
    and not c.relrowsecurity;
  if bad is not null then raise exception 'RLS-A08: RLS disabled on %',bad; end if;
end $$;

rollback;
