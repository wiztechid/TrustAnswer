-- TrustAnswer v0.3 — inherited v0.2 immutability + answer revision ledger

-- Revision rows are append-only. Existing generic policies from migration 0001 are removed.
drop policy if exists canonical_answer_revisions_update on public.canonical_answer_revisions;
drop policy if exists canonical_answer_revisions_delete on public.canonical_answer_revisions;
drop policy if exists evidence_revisions_update on public.evidence_revisions;
drop policy if exists evidence_revisions_delete on public.evidence_revisions;

revoke update,delete,truncate on public.canonical_answer_revisions from authenticated;
revoke update,delete,truncate on public.evidence_revisions from authenticated;

create table public.question_answer_revisions (
  tenant_id uuid not null,
  id uuid not null default gen_random_uuid(),
  question_id uuid not null,
  revision_no integer not null check (revision_no>0),
  answer_text text not null,
  answer_state text not null,
  canonical_revision_id uuid,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  primary key (tenant_id,id),
  unique (tenant_id,question_id,revision_no),
  foreign key (tenant_id,question_id)
    references public.questionnaire_questions(tenant_id,id),
  foreign key (tenant_id,canonical_revision_id)
    references public.canonical_answer_revisions(tenant_id,id)
);

alter table public.question_answer_revisions enable row level security;
create policy question_answer_revisions_read
  on public.question_answer_revisions for select
  using (public.ta_is_active_member(tenant_id));
create policy question_answer_revisions_insert
  on public.question_answer_revisions for insert
  with check (
    created_by=auth.uid()
    and public.ta_has_role(
      tenant_id,ARRAY['OWNER','ADMIN','MEMBER']::public.ta_member_role[]
    )
  );

-- No client UPDATE/DELETE: answers evolve by creating a new revision.
revoke update,delete,truncate,references,trigger
  on public.question_answer_revisions from anon,authenticated;

-- The mutable convenience columns on questionnaire_questions are no longer authoritative.
comment on column public.questionnaire_questions.final_answer is
  'Deprecated convenience field; authoritative answer text is question_answer_revisions.';
comment on column public.questionnaire_questions.answer_state is
  'Deprecated convenience field; authoritative state is question_answer_revisions.';

-- Prevent tenant ownership laundering on all current tenant-owned application tables.
create or replace function public.ta_reject_tenant_id_change()
returns trigger language plpgsql
set search_path=''
as $$
begin
  if old.tenant_id is distinct from new.tenant_id then
    raise exception 'TENANT_ID_IMMUTABLE';
  end if;
  return new;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array[
    'tenant_memberships','customers','questionnaires','questionnaire_questions',
    'canonical_answers','canonical_answer_revisions','evidence_records','evidence_revisions',
    'answer_evidence_bindings','gaps','reviews','submissions','submission_items',
    'subscriptions','entitlements','usage_events','billing_identity_bindings',
    'question_answer_revisions'
  ] loop
    execute format('drop trigger if exists ta_tenant_immutable on public.%I',t);
    execute format(
      'create trigger ta_tenant_immutable before update of tenant_id on public.%I
       for each row execute function public.ta_reject_tenant_id_change()',t
    );
  end loop;
end $$;

revoke all on function public.ta_reject_tenant_id_change()
  from public,anon,authenticated;
