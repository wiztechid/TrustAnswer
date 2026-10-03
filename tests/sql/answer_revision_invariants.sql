-- TrustAnswer v0.3 — answer revision authority adversarial runtime checks
begin;

insert into auth.users(id,aud,role,email,created_at,updated_at) values
('00000000-0000-0000-0000-000000007001','authenticated','authenticated','answer-owner@example.invalid',now(),now());

insert into public.tenants(id,name) values
('00000000-0000-0000-0000-000000007000','Answer Test A'),
('00000000-0000-0000-0000-000000007100','Answer Test B');
insert into public.tenant_memberships(tenant_id,user_id,role,state) values
('00000000-0000-0000-0000-000000007000','00000000-0000-0000-0000-000000007001','OWNER','ACTIVE');

insert into public.customers(tenant_id,id,name) values
('00000000-0000-0000-0000-000000007000','00000000-0000-0000-0000-000000007010','Customer');
insert into public.questionnaires(tenant_id,id,customer_id,title) values
('00000000-0000-0000-0000-000000007000','00000000-0000-0000-0000-000000007020','00000000-0000-0000-0000-000000007010','Q');
insert into public.questionnaire_questions(tenant_id,id,questionnaire_id,raw_question) values
('00000000-0000-0000-0000-000000007000','00000000-0000-0000-0000-000000007030','00000000-0000-0000-0000-000000007020','Do you encrypt?'),
('00000000-0000-0000-0000-000000007000','00000000-0000-0000-0000-000000007031','00000000-0000-0000-0000-000000007020','Do you log?');

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000007001',true);

select public.ta_append_question_answer_revision(
 '00000000-0000-0000-0000-000000007000','00000000-0000-0000-0000-000000007030','Yes v1','SUPPORTED',null);
do $ans$
begin
 if not exists(select 1 from public.question_answer_heads where tenant_id='00000000-0000-0000-0000-000000007000' and question_id='00000000-0000-0000-0000-000000007030' and revision_no=1)
 then raise exception 'ANS-I01: first head not revision 1'; end if;
end $ans$;

insert into public.reviews(tenant_id,question_id,reviewer_user_id,decision,context_fingerprint,answer_revision_id)
select h.tenant_id,h.question_id,'00000000-0000-0000-0000-000000007001','APPROVED','ctx-v1',h.revision_id
from public.question_answer_heads h where h.tenant_id='00000000-0000-0000-0000-000000007000' and h.question_id='00000000-0000-0000-0000-000000007030';

-- Advancing HEAD must succeed despite historical review.
select public.ta_append_question_answer_revision(
 '00000000-0000-0000-0000-000000007000','00000000-0000-0000-0000-000000007030','Yes v2','SUPPORTED',null);
do $ans$
begin
 if not exists(select 1 from public.question_answer_heads where tenant_id='00000000-0000-0000-0000-000000007000' and question_id='00000000-0000-0000-0000-000000007030' and revision_no=2)
 then raise exception 'ANS-I02: head did not advance'; end if;
 if (select count(*) from public.reviews where tenant_id='00000000-0000-0000-0000-000000007000')<>1
 then raise exception 'ANS-I03: historical review lost'; end if;
end $ans$;

-- A stale revision can no longer receive a new review.
do $ans$
declare old_rev uuid;
begin
 select id into old_rev from public.question_answer_revisions
 where tenant_id='00000000-0000-0000-0000-000000007000' and question_id='00000000-0000-0000-0000-000000007030' and revision_no=1;
 begin
   insert into public.reviews(tenant_id,question_id,reviewer_user_id,decision,context_fingerprint,answer_revision_id)
   values('00000000-0000-0000-0000-000000007000','00000000-0000-0000-0000-000000007030','00000000-0000-0000-0000-000000007001','APPROVED','stale',old_rev);
   raise exception 'ANS-I04: stale review accepted';
 exception when others then
   if sqlerrm='ANS-I04: stale review accepted' then raise; end if;
   if sqlerrm<>'REVIEW_NOT_CURRENT_HEAD' then raise; end if;
 end;
end $ans$;

-- Current revision from another question cannot be bound to this question's review.
select public.ta_append_question_answer_revision(
 '00000000-0000-0000-0000-000000007000','00000000-0000-0000-0000-000000007031','Log v1','SUPPORTED',null);
do $ans$
declare other_rev uuid;
begin
 select revision_id into other_rev from public.question_answer_heads
 where tenant_id='00000000-0000-0000-0000-000000007000' and question_id='00000000-0000-0000-0000-000000007031';
 begin
   insert into public.reviews(tenant_id,question_id,reviewer_user_id,decision,context_fingerprint,answer_revision_id)
   values('00000000-0000-0000-0000-000000007000','00000000-0000-0000-0000-000000007030','00000000-0000-0000-0000-000000007001','APPROVED','wrong-question',other_rev);
   raise exception 'ANS-I05: cross-question revision accepted';
 exception when others then
   if sqlerrm='ANS-I05: cross-question revision accepted' then raise; end if;
 end;
end $ans$;

reset role;
rollback;
