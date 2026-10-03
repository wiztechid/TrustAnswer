-- TrustAnswer v0.3 — authoritative question-answer revision head and exact bindings

create table public.question_answer_heads (
  tenant_id uuid not null,
  question_id uuid not null,
  revision_id uuid not null,
  revision_no integer not null check (revision_no>0),
  updated_at timestamptz not null default now(),
  primary key(tenant_id,question_id),
  foreign key(tenant_id,question_id) references public.questionnaire_questions(tenant_id,id),
  foreign key(tenant_id,revision_id) references public.question_answer_revisions(tenant_id,id),
  unique(tenant_id,question_id,revision_id)
);
alter table public.question_answer_heads enable row level security;
create policy question_answer_heads_read on public.question_answer_heads for select
using(public.ta_is_active_member(tenant_id));
revoke insert,update,delete,truncate,references,trigger on public.question_answer_heads from anon,authenticated;

-- Existing client INSERT is retired; revision numbering/head advancement are one atomic server operation.
drop policy if exists question_answer_revisions_insert on public.question_answer_revisions;
revoke insert on public.question_answer_revisions from authenticated;

create or replace function public.ta_append_question_answer_revision(
 p_tenant_id uuid,p_question_id uuid,p_answer_text text,p_answer_state text,p_canonical_revision_id uuid default null
) returns uuid
language plpgsql security definer set search_path=''
as $$
declare v_actor uuid:=auth.uid(); v_next integer; v_id uuid:=gen_random_uuid();
begin
 if v_actor is null then raise exception 'AUTH_REQUIRED'; end if;
 if not public.ta_has_role(p_tenant_id,ARRAY['OWNER','ADMIN','MEMBER']::public.ta_member_role[]) then
   raise exception 'ANSWER_WRITE_FORBIDDEN';
 end if;
 if not exists(select 1 from public.questionnaire_questions where tenant_id=p_tenant_id and id=p_question_id) then
   raise exception 'QUESTION_NOT_FOUND';
 end if;

 perform pg_advisory_xact_lock(hashtextextended(p_tenant_id::text||':'||p_question_id::text||':answer-head',0));
 select coalesce(max(revision_no),0)+1 into v_next from public.question_answer_revisions
 where tenant_id=p_tenant_id and question_id=p_question_id;

 insert into public.question_answer_revisions(
   tenant_id,id,question_id,revision_no,answer_text,answer_state,canonical_revision_id,created_by
 ) values(p_tenant_id,v_id,p_question_id,v_next,p_answer_text,p_answer_state,p_canonical_revision_id,v_actor);

 insert into public.question_answer_heads(tenant_id,question_id,revision_id,revision_no)
 values(p_tenant_id,p_question_id,v_id,v_next)
 on conflict(tenant_id,question_id) do update
 set revision_id=excluded.revision_id,revision_no=excluded.revision_no,updated_at=now();

 return v_id;
end;
$$;
revoke all on function public.ta_append_question_answer_revision(uuid,uuid,text,text,uuid) from public,anon;
grant execute on function public.ta_append_question_answer_revision(uuid,uuid,text,text,uuid) to authenticated;

-- Reviews bind to the exact answer revision reviewed.
alter table public.reviews add column answer_revision_id uuid;
alter table public.reviews add constraint reviews_answer_revision_fk
 foreign key(tenant_id,question_id,answer_revision_id)
 references public.question_answer_heads(tenant_id,question_id,revision_id);

-- New reviews must carry an exact revision; legacy rows may remain null during migration.
create or replace function public.ta_require_review_current_head()
returns trigger language plpgsql set search_path=''
as $$
begin
 if new.answer_revision_id is null then raise exception 'REVIEW_REVISION_REQUIRED'; end if;
 if not exists(
   select 1 from public.question_answer_heads h
   where h.tenant_id=new.tenant_id and h.question_id=new.question_id and h.revision_id=new.answer_revision_id
 ) then raise exception 'REVIEW_NOT_CURRENT_HEAD'; end if;
 return new;
end;
$$;
create trigger ta_review_current_head before insert on public.reviews
for each row execute function public.ta_require_review_current_head();
revoke all on function public.ta_require_review_current_head() from public,anon,authenticated;

-- Submission items use an exact answer revision FK; retire free-form answer_revision_ref.
alter table public.submission_items add column answer_revision_id uuid;
alter table public.submission_items add constraint submission_answer_revision_fk
 foreign key(tenant_id,answer_revision_id) references public.question_answer_revisions(tenant_id,id);

-- HEAD tenant ownership is immutable.
create trigger ta_tenant_immutable before update of tenant_id on public.question_answer_heads
for each row execute function public.ta_reject_tenant_id_change();
