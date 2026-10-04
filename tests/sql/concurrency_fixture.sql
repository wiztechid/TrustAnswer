insert into auth.users(id,aud,role,email,created_at,updated_at) values
('00000000-0000-0000-0000-000000009101','authenticated','authenticated','c1@example.invalid',now(),now()),
('00000000-0000-0000-0000-000000009102','authenticated','authenticated','c2@example.invalid',now(),now());
insert into public.tenants(id,name) values
('00000000-0000-0000-0000-000000009000','Concurrency Quota'),
('00000000-0000-0000-0000-000000009100','Concurrency Membership');
select public.ta_provision_free_entitlement('00000000-0000-0000-0000-000000009000');
select public.ta_consume_authoritative_quota('00000000-0000-0000-0000-000000009000','questions',24,'seed-24','concurrency');
insert into public.tenant_memberships(tenant_id,user_id,role,state) values
('00000000-0000-0000-0000-000000009100','00000000-0000-0000-0000-000000009101','OWNER','ACTIVE'),
('00000000-0000-0000-0000-000000009100','00000000-0000-0000-0000-000000009102','OWNER','ACTIVE');
