begin;
insert into public.tenants(id,name) values
('00000000-0000-0000-0000-000000009200','Revision Immutability');
insert into public.canonical_answers(tenant_id,id,claim_key) values
('00000000-0000-0000-0000-000000009200','00000000-0000-0000-0000-000000009210','claim');
insert into public.canonical_answer_revisions(
 tenant_id,id,canonical_answer_id,revision_no,canonical_answer,effective_at,known_at
) values(
 '00000000-0000-0000-0000-000000009200',
 '00000000-0000-0000-0000-000000009211',
 '00000000-0000-0000-0000-000000009210',
 1,'original',now(),now()
);
insert into public.evidence_records(tenant_id,id,title,evidence_type) values
('00000000-0000-0000-0000-000000009200','00000000-0000-0000-0000-000000009220','Evidence','DOC');
insert into public.evidence_revisions(tenant_id,id,evidence_id,revision_no,effective_at,known_at) values
('00000000-0000-0000-0000-000000009200','00000000-0000-0000-0000-000000009221','00000000-0000-0000-0000-000000009220',1,now(),now());

insert into auth.users(id,aud,role,email,created_at,updated_at) values
('00000000-0000-0000-0000-000000009201','authenticated','authenticated','immutability@example.invalid',now(),now());
insert into public.customers(tenant_id,id,name) values
('00000000-0000-0000-0000-000000009200','00000000-0000-0000-0000-000000009230','Customer');
insert into public.questionnaires(tenant_id,id,customer_id,title) values
('00000000-0000-0000-0000-000000009200','00000000-0000-0000-0000-000000009231','00000000-0000-0000-0000-000000009230','Questionnaire');
insert into public.questionnaire_questions(tenant_id,id,questionnaire_id,raw_question) values
('00000000-0000-0000-0000-000000009200','00000000-0000-0000-0000-000000009232','00000000-0000-0000-0000-000000009231','Question?');
insert into public.question_answer_revisions(
 tenant_id,id,question_id,revision_no,answer_text,answer_state,created_by
) values(
 '00000000-0000-0000-0000-000000009200',
 '00000000-0000-0000-0000-000000009233',
 '00000000-0000-0000-0000-000000009232',
 1,'answer v1','SUPPORTED','00000000-0000-0000-0000-000000009201'
);

do $immut$
begin
 begin
  update public.canonical_answer_revisions
  set canonical_answer='changed'
  where id='00000000-0000-0000-0000-000000009211';
  raise exception 'IMMUTABILITY_TEST_FAILED';
 exception when others then
  if sqlerrm='IMMUTABILITY_TEST_FAILED' then raise; end if;
  if sqlerrm<>'HISTORICAL_REVISION_IMMUTABLE' then raise; end if;
 end;
 begin
  delete from public.canonical_answer_revisions where id='00000000-0000-0000-0000-000000009211';
  raise exception 'IMMUTABILITY_TEST_FAILED';
 exception when others then
  if sqlerrm='IMMUTABILITY_TEST_FAILED' then raise; end if;
  if sqlerrm<>'HISTORICAL_REVISION_IMMUTABLE' then raise; end if;
 end;
 begin
  update public.evidence_revisions set freshness_state='FRESH'
  where id='00000000-0000-0000-0000-000000009221';
  raise exception 'IMMUTABILITY_TEST_FAILED';
 exception when others then
  if sqlerrm='IMMUTABILITY_TEST_FAILED' then raise; end if;
  if sqlerrm<>'HISTORICAL_REVISION_IMMUTABLE' then raise; end if;
 end;
 begin
  delete from public.evidence_revisions where id='00000000-0000-0000-0000-000000009221';
  raise exception 'IMMUTABILITY_TEST_FAILED';
 exception when others then
  if sqlerrm='IMMUTABILITY_TEST_FAILED' then raise; end if;
  if sqlerrm<>'HISTORICAL_REVISION_IMMUTABLE' then raise; end if;
 end;
 begin
  update public.question_answer_revisions set answer_text='rewritten'
  where id='00000000-0000-0000-0000-000000009233';
  raise exception 'IMMUTABILITY_TEST_FAILED';
 exception when others then
  if sqlerrm='IMMUTABILITY_TEST_FAILED' then raise; end if;
  if sqlerrm<>'HISTORICAL_REVISION_IMMUTABLE' then raise; end if;
 end;
 begin
  delete from public.question_answer_revisions
  where id='00000000-0000-0000-0000-000000009233';
  raise exception 'IMMUTABILITY_TEST_FAILED';
 exception when others then
  if sqlerrm='IMMUTABILITY_TEST_FAILED' then raise; end if;
  if sqlerrm<>'HISTORICAL_REVISION_IMMUTABLE' then raise; end if;
 end;
end $immut$;
insert into public.question_answer_revisions(
 tenant_id,id,question_id,revision_no,answer_text,answer_state,created_by
) values(
 '00000000-0000-0000-0000-000000009200',
 '00000000-0000-0000-0000-000000009234',
 '00000000-0000-0000-0000-000000009232',
 2,'answer v2','SUPPORTED','00000000-0000-0000-0000-000000009201'
);
do $append$
begin
 if not exists(
  select 1 from public.question_answer_revisions
  where tenant_id='00000000-0000-0000-0000-000000009200'
    and question_id='00000000-0000-0000-0000-000000009232'
    and revision_no=2 and answer_text='answer v2'
 ) then raise exception 'APPEND_TEST_FAILED'; end if;
end $append$;
rollback;
