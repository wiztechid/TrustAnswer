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
do $$
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
end $$;
rollback;
