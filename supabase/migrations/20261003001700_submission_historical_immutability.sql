-- TrustAnswer v0.3 — historical submission rows are immutable at the database layer.

create or replace function public.ta_reject_historical_submission_mutation()
returns trigger language plpgsql set search_path=''
as $$
begin
 raise exception 'HISTORICAL_SUBMISSION_IMMUTABLE';
end;
$$;
revoke all on function public.ta_reject_historical_submission_mutation() from public,anon,authenticated,service_role;

drop trigger if exists ta_submission_immutable on public.submissions;
create trigger ta_submission_immutable
before update or delete on public.submissions
for each row execute function public.ta_reject_historical_submission_mutation();

drop trigger if exists ta_submission_item_immutable on public.submission_items;
create trigger ta_submission_item_immutable
before update or delete on public.submission_items
for each row execute function public.ta_reject_historical_submission_mutation();

comment on column public.submission_items.answer_revision_ref is
 'Legacy compatibility snapshot only; non-authoritative. Authority is answer_revision_id FK.';
comment on column public.submission_items.review_ref is
 'Legacy compatibility snapshot only; non-authoritative. Review authority is exact review captured by ta_create_submission and snapshot.';
