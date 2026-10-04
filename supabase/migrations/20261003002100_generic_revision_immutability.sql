-- TrustAnswer v0.3 — generic historical revision immutability

create or replace function public.ta_reject_historical_revision_mutation()
returns trigger language plpgsql set search_path=''
as $$
begin
  raise exception 'HISTORICAL_REVISION_IMMUTABLE';
end;
$$;
revoke all on function public.ta_reject_historical_revision_mutation()
from public,anon,authenticated,service_role;

create trigger ta_canonical_revision_immutable
before update or delete on public.canonical_answer_revisions
for each row execute function public.ta_reject_historical_revision_mutation();

create trigger ta_evidence_revision_immutable
before update or delete on public.evidence_revisions
for each row execute function public.ta_reject_historical_revision_mutation();

create trigger ta_question_answer_revision_immutable
before update or delete on public.question_answer_revisions
for each row execute function public.ta_reject_historical_revision_mutation();
