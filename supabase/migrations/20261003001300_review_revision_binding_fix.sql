-- TrustAnswer v0.3 — fix review binding so historical reviews do not pin the mutable HEAD.

alter table public.reviews drop constraint if exists reviews_answer_revision_fk;

-- Exact immutable revision identity, including question identity, is the historical anchor.
alter table public.question_answer_revisions
  add constraint question_answer_revision_identity_unique
  unique(tenant_id,question_id,id);

alter table public.reviews add constraint reviews_answer_revision_fk
 foreign key(tenant_id,question_id,answer_revision_id)
 references public.question_answer_revisions(tenant_id,question_id,id);

-- Current-head validation remains an INSERT-time rule; later head movement does not rewrite history.
create or replace function public.ta_require_review_current_head()
returns trigger language plpgsql set search_path=''
as $$
begin
 if new.answer_revision_id is null then raise exception 'REVIEW_REVISION_REQUIRED'; end if;
 if not exists(
   select 1 from public.question_answer_heads h
   where h.tenant_id=new.tenant_id and h.question_id=new.question_id
     and h.revision_id=new.answer_revision_id
 ) then raise exception 'REVIEW_NOT_CURRENT_HEAD'; end if;
 return new;
end;
$$;
