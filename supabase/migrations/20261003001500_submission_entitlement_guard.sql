-- TrustAnswer v0.3 — submission entitlement fail-closed guard

create or replace function public.ta_assert_submission_entitlement(p_tenant_id uuid)
returns void
language plpgsql security definer set search_path=''
as $$
declare v_status text; v_plan text;
begin
 select status,plan_code into v_status,v_plan from public.entitlements where tenant_id=p_tenant_id;
 if not found or v_status<>'ACTIVE' then raise exception 'SUBMISSION_ENTITLEMENT_DENIED'; end if;
 -- Initial commercial contract: export/submission is paid capability.
 if v_plan not in ('SOLO','PRO') then raise exception 'SUBMISSION_FEATURE_DENIED'; end if;
end;
$$;
revoke all on function public.ta_assert_submission_entitlement(uuid) from public,anon,authenticated,service_role;

create or replace function public.ta_create_submission(
 p_tenant_id uuid,p_questionnaire_id uuid,p_evaluation_at timestamptz,
 p_schema_version text,p_validation_contract_version text
) returns uuid
language plpgsql security definer set search_path=''
as $$
declare v_submission uuid:=gen_random_uuid(); v_q record; v_review uuid;
begin
 if p_tenant_id is null or p_questionnaire_id is null or p_evaluation_at is null
    or length(trim(coalesce(p_schema_version,'')))=0
    or length(trim(coalesce(p_validation_contract_version,'')))=0
 then raise exception 'SUBMISSION_INPUT_INVALID'; end if;

 perform public.ta_assert_submission_entitlement(p_tenant_id);
 perform pg_advisory_xact_lock(hashtextextended(p_tenant_id::text||':'||p_questionnaire_id::text||':submission',0));

 if not exists(select 1 from public.questionnaires where tenant_id=p_tenant_id and id=p_questionnaire_id)
 then raise exception 'QUESTIONNAIRE_NOT_FOUND'; end if;

 for v_q in
   select qq.id question_id,qq.raw_question,h.revision_id,ar.answer_text,ar.answer_state
   from public.questionnaire_questions qq
   left join public.question_answer_heads h on h.tenant_id=qq.tenant_id and h.question_id=qq.id
   left join public.question_answer_revisions ar on ar.tenant_id=h.tenant_id and ar.id=h.revision_id
   where qq.tenant_id=p_tenant_id and qq.questionnaire_id=p_questionnaire_id order by qq.id
 loop
   if v_q.revision_id is null then raise exception 'SUBMISSION_ANSWER_HEAD_MISSING'; end if;
   select r.id into v_review from public.reviews r
   where r.tenant_id=p_tenant_id and r.question_id=v_q.question_id
     and r.answer_revision_id=v_q.revision_id and r.decision='APPROVED'
   order by r.created_at desc,r.id desc limit 1;
   if v_review is null then raise exception 'SUBMISSION_CURRENT_REVIEW_MISSING'; end if;
 end loop;

 insert into public.submissions(tenant_id,id,questionnaire_id,evaluation_at,schema_version,validation_contract_version,gate_result)
 values(p_tenant_id,v_submission,p_questionnaire_id,p_evaluation_at,p_schema_version,p_validation_contract_version,'READY');

 for v_q in
   select qq.id question_id,qq.raw_question,h.revision_id,ar.answer_text,ar.answer_state
   from public.questionnaire_questions qq
   join public.question_answer_heads h on h.tenant_id=qq.tenant_id and h.question_id=qq.id
   join public.question_answer_revisions ar on ar.tenant_id=h.tenant_id and ar.id=h.revision_id
   where qq.tenant_id=p_tenant_id and qq.questionnaire_id=p_questionnaire_id order by qq.id
 loop
   select r.id into v_review from public.reviews r
   where r.tenant_id=p_tenant_id and r.question_id=v_q.question_id
     and r.answer_revision_id=v_q.revision_id and r.decision='APPROVED'
   order by r.created_at desc,r.id desc limit 1;
   insert into public.submission_items(
     tenant_id,submission_id,question_id,raw_question_hash,final_answer,
     answer_revision_id,answer_revision_ref,review_ref,snapshot
   ) values(
     p_tenant_id,v_submission,v_q.question_id,encode(digest(v_q.raw_question,'sha256'),'hex'),
     v_q.answer_text,v_q.revision_id,v_q.revision_id::text,v_review::text,
     jsonb_build_object('answerState',v_q.answer_state,'answerRevisionId',v_q.revision_id,'reviewId',v_review)
   );
 end loop;
 return v_submission;
end;
$$;
revoke all on function public.ta_create_submission(uuid,uuid,timestamptz,text,text) from public,anon,authenticated;
grant execute on function public.ta_create_submission(uuid,uuid,timestamptz,text,text) to service_role;
