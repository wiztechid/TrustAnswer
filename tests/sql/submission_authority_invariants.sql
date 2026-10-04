-- TrustAnswer v0.3 — submission authority adversarial runtime checks
begin;

insert into auth.users(id,aud,role,email,created_at,updated_at)
values('00000000-0000-0000-0000-000000006001','authenticated','authenticated','submit-owner@example.invalid',now(),now());
insert into public.tenants(id,name) values('00000000-0000-0000-0000-000000006000','Submission Test');
insert into public.tenant_memberships(tenant_id,user_id,role,state)
values('00000000-0000-0000-0000-000000006000','00000000-0000-0000-0000-000000006001','OWNER','ACTIVE');
insert into public.customers(tenant_id,id,name)
values('00000000-0000-0000-0000-000000006000','00000000-0000-0000-0000-000000006010','Customer');
insert into public.questionnaires(tenant_id,id,customer_id,title)
values('00000000-0000-0000-0000-000000006000','00000000-0000-0000-0000-000000006020','00000000-0000-0000-0000-000000006010','Questionnaire');
insert into public.questionnaire_questions(tenant_id,id,questionnaire_id,raw_question)
values('00000000-0000-0000-0000-000000006000','00000000-0000-0000-0000-000000006030','00000000-0000-0000-0000-000000006020','Do you encrypt?');

-- FREE cannot submit.
insert into public.entitlements(tenant_id,plan_code,status,limits)
values('00000000-0000-0000-0000-000000006000','FREE','ACTIVE','{"questions":25}'::jsonb);
do $sub$
begin
 begin
  perform public.ta_create_submission('00000000-0000-0000-0000-000000006000','00000000-0000-0000-0000-000000006020',now(),'v1','v1');
  raise exception 'SUB-I01: FREE submission accepted';
 exception when others then
  if sqlerrm='SUB-I01: FREE submission accepted' then raise; end if;
  if sqlerrm<>'SUBMISSION_FEATURE_DENIED' then raise; end if;
 end;
end $sub$;

-- Paid but no answer head must fail.
update public.entitlements set plan_code='SOLO',status='ACTIVE',limits='{"questions":500}' where tenant_id='00000000-0000-0000-0000-000000006000';
do $sub$
begin
 begin
  perform public.ta_create_submission('00000000-0000-0000-0000-000000006000','00000000-0000-0000-0000-000000006020',now(),'v1','v1');
  raise exception 'SUB-I02: missing head accepted';
 exception when others then
  if sqlerrm='SUB-I02: missing head accepted' then raise; end if;
  if sqlerrm<>'SUBMISSION_ANSWER_HEAD_MISSING' then raise; end if;
 end;
end $sub$;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000006001',true);
select public.ta_append_question_answer_revision('00000000-0000-0000-0000-000000006000','00000000-0000-0000-0000-000000006030','Yes v1','SUPPORTED',null);
reset role;

-- Current head without review must fail.
do $sub$
begin
 begin
  perform public.ta_create_submission('00000000-0000-0000-0000-000000006000','00000000-0000-0000-0000-000000006020',now(),'v1','v1');
  raise exception 'SUB-I03: missing review accepted';
 exception when others then
  if sqlerrm='SUB-I03: missing review accepted' then raise; end if;
  if sqlerrm<>'SUBMISSION_CURRENT_REVIEW_MISSING' then raise; end if;
 end;
end $sub$;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000006001',true);
insert into public.reviews(tenant_id,question_id,reviewer_user_id,decision,context_fingerprint,answer_revision_id)
select h.tenant_id,h.question_id,'00000000-0000-0000-0000-000000006001','APPROVED','ctx-v1',h.revision_id
from public.question_answer_heads h where h.tenant_id='00000000-0000-0000-0000-000000006000';
select public.ta_append_question_answer_revision('00000000-0000-0000-0000-000000006000','00000000-0000-0000-0000-000000006030','Yes v2','SUPPORTED',null);
reset role;

-- Old approval cannot authorize new head.
do $sub$
begin
 begin
  perform public.ta_create_submission('00000000-0000-0000-0000-000000006000','00000000-0000-0000-0000-000000006020',now(),'v1','v1');
  raise exception 'SUB-I04: stale approval authorized new revision';
 exception when others then
  if sqlerrm='SUB-I04: stale approval authorized new revision' then raise; end if;
  if sqlerrm<>'SUBMISSION_CURRENT_REVIEW_MISSING' then raise; end if;
 end;
end $sub$;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000006001',true);
insert into public.reviews(tenant_id,question_id,reviewer_user_id,decision,context_fingerprint,answer_revision_id)
select h.tenant_id,h.question_id,'00000000-0000-0000-0000-000000006001','APPROVED','ctx-v2',h.revision_id
from public.question_answer_heads h where h.tenant_id='00000000-0000-0000-0000-000000006000';
reset role;

-- Valid exact-bound submission succeeds and snapshot IDs match relational anchors.
do $sub$
declare sid uuid; rid uuid; revid uuid;
begin
 sid:=public.ta_create_submission('00000000-0000-0000-0000-000000006000','00000000-0000-0000-0000-000000006020',now(),'v1','v1');
 select answer_revision_id,(snapshot->>'reviewId')::uuid into revid,rid
 from public.submission_items where tenant_id='00000000-0000-0000-0000-000000006000' and submission_id=sid;
 if revid is distinct from (select revision_id from public.question_answer_heads where tenant_id='00000000-0000-0000-0000-000000006000' and question_id='00000000-0000-0000-0000-000000006030')
 then raise exception 'SUB-I05: snapshot revision mismatch'; end if;
 if not exists(select 1 from public.reviews where tenant_id='00000000-0000-0000-0000-000000006000' and id=rid and answer_revision_id=revid and decision='APPROVED')
 then raise exception 'SUB-I06: snapshot review mismatch'; end if;
end $sub$;

-- BLOCKED entitlement cannot submit even with complete evidence chain.
update public.entitlements set status='BLOCKED' where tenant_id='00000000-0000-0000-0000-000000006000';
do $sub$
begin
 begin
  perform public.ta_create_submission('00000000-0000-0000-0000-000000006000','00000000-0000-0000-0000-000000006020',now(),'v1','v1');
  raise exception 'SUB-I07: BLOCKED submission accepted';
 exception when others then
  if sqlerrm='SUB-I07: BLOCKED submission accepted' then raise; end if;
  if sqlerrm<>'SUBMISSION_ENTITLEMENT_DENIED' then raise; end if;
 end;
end $sub$;

-- service_role must not retain direct table insert.
set local role service_role;
do $sub$
begin
 begin
  insert into public.submissions(tenant_id,questionnaire_id,evaluation_at,schema_version,validation_contract_version,gate_result)
  values('00000000-0000-0000-0000-000000006000','00000000-0000-0000-0000-000000006020',now(),'evil','evil','READY');
  raise exception 'SUB-I08: direct service submission insert accepted';
 exception when insufficient_privilege then null;
 end;
end $sub$;
reset role;


-- Historical snapshots remain immutable even to a privileged database path.
reset role;
do $sub$
declare sid uuid;
begin
 select id into sid from public.submissions
 where tenant_id='00000000-0000-0000-0000-000000006000' limit 1;
 begin
   update public.submissions set schema_version='tampered'
   where tenant_id='00000000-0000-0000-0000-000000006000' and id=sid;
   raise exception 'SUB-I09: historical submission update accepted';
 exception when others then
   if sqlerrm='SUB-I09: historical submission update accepted' then raise; end if;
   if sqlerrm<>'HISTORICAL_SUBMISSION_IMMUTABLE' then raise; end if;
 end;
 begin
   delete from public.submission_items
   where tenant_id='00000000-0000-0000-0000-000000006000' and submission_id=sid;
   raise exception 'SUB-I10: historical submission item delete accepted';
 exception when others then
   if sqlerrm='SUB-I10: historical submission item delete accepted' then raise; end if;
   if sqlerrm<>'HISTORICAL_SUBMISSION_IMMUTABLE' then raise; end if;
 end;
end $sub$;

rollback;
