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

do $
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
end $;
rollback;
