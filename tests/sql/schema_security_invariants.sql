-- TrustAnswer v0.3 static database invariants
-- Execute after migrations in an isolated test database.

begin;

-- Server-authoritative tables must have no authenticated mutation privileges.
do $$
declare bad text;
begin
  select string_agg(table_name,', ' order by table_name) into bad
  from information_schema.role_table_grants
  where grantee='authenticated'
    and table_schema='public'
    and table_name in (
      'tenants','tenant_memberships','subscriptions','entitlements',
      'webhook_events','submissions','submission_items','plan_catalog','usage_events',
      'billing_identity_bindings','question_answer_heads'
    )
    and privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER');
  if bad is not null then
    raise exception 'DB-I01: authenticated mutation grant on server-authoritative table(s): %',bad;
  end if;
end $$;

-- Reviews may be inserted by authorized reviewers, but never updated/deleted by client roles.
do $$
declare bad text;
begin
  select string_agg(privilege_type,', ') into bad
  from information_schema.role_table_grants
  where grantee='authenticated' and table_schema='public' and table_name='reviews'
    and privilege_type in ('UPDATE','DELETE','TRUNCATE');
  if bad is not null then raise exception 'DB-I02: mutable review privilege: %',bad; end if;
end $$;

-- Authorization helpers must not be executable by PUBLIC or anon.
do $$
begin
  if has_function_privilege('public','public.ta_is_active_member(uuid)','EXECUTE')
     or has_function_privilege('anon','public.ta_is_active_member(uuid)','EXECUTE')
     or has_function_privilege('public','public.ta_has_role(uuid,public.ta_member_role[])','EXECUTE')
     or has_function_privilege('anon','public.ta_has_role(uuid,public.ta_member_role[])','EXECUTE')
  then
    raise exception 'DB-I03: authorization helper execution too broad';
  end if;
end $$;

-- Server-only relations must not accidentally acquire client mutation policies.
do $$
declare bad text;
begin
  select string_agg(tablename||':'||policyname,', ' order by tablename,policyname) into bad
  from pg_policies
  where schemaname='public'
    and tablename in (
      'tenants','tenant_memberships','subscriptions','entitlements',
      'webhook_events','submissions','submission_items','plan_catalog','usage_events',
      'billing_identity_bindings','question_answer_heads'
    )
    and cmd in ('INSERT','UPDATE','DELETE','ALL');
  if bad is not null then raise exception 'DB-I04: client-facing mutation policy exists: %',bad; end if;
end $$;

-- Revision anchors are append-only. Canonical/evidence revisions may be appended by
-- authorized clients; question-answer revisions are stricter and append only through its RPC.
do $inv$
declare bad text;
begin
  select string_agg(table_name||':'||privilege_type,', ' order by table_name,privilege_type) into bad
  from information_schema.role_table_grants
  where grantee='authenticated' and table_schema='public'
    and (
      (table_name in ('canonical_answer_revisions','evidence_revisions')
       and privilege_type in ('UPDATE','DELETE','TRUNCATE'))
      or
      (table_name='question_answer_revisions'
       and privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE'))
    );
  if bad is not null then raise exception 'DB-I05: revision authority drift: %',bad; end if;
end
$inv$;

-- Tenant ownership trigger must cover every mutable tenant-owned application table.
do $inv$
declare bad text;
begin
  with required(name) as (values
    ('tenant_memberships'),('customers'),('questionnaires'),('questionnaire_questions'),
    ('canonical_answers'),('canonical_answer_revisions'),('evidence_records'),('evidence_revisions'),
    ('answer_evidence_bindings'),('gaps'),('reviews'),('submissions'),('submission_items'),
    ('subscriptions'),('entitlements'),('usage_events'),('billing_identity_bindings'),
    ('question_answer_revisions'),('question_answer_heads')
  )
  select string_agg(r.name,', ' order by r.name) into bad
  from required r
  where not exists (
    select 1 from pg_trigger tg
    join pg_class c on c.oid=tg.tgrelid
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname=r.name
      and tg.tgname='ta_tenant_immutable' and not tg.tgisinternal
  );
  if bad is not null then raise exception 'DB-I06: tenant immutability trigger missing: %',bad; end if;
end
$inv$;

-- Membership lifecycle must acquire the tenant lock before role/count decisions.
do $inv$
declare body text;
declare lock_pos integer;
declare owner_count_pos integer;
begin
  select pg_get_functiondef(p.oid) into body
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='ta_change_membership';
  lock_pos:=position('ta_membership_lock(p_tenant_id)' in body);
  owner_count_pos:=position('select count(*) into v_owner_count' in lower(body));
  if lock_pos=0 or owner_count_pos=0 or lock_pos>=owner_count_pos then
    raise exception 'DB-I07: membership lock must precede owner-count decision';
  end if;
end
$inv$;

-- Answer authority RPC exposure must remain narrow: append is authenticated; submission is service-only.
do $inv$
begin
  if has_function_privilege('anon','public.ta_append_question_answer_revision(uuid,uuid,text,text,uuid)','EXECUTE')
     or has_function_privilege('public','public.ta_append_question_answer_revision(uuid,uuid,text,text,uuid)','EXECUTE')
     or not has_function_privilege('authenticated','public.ta_append_question_answer_revision(uuid,uuid,text,text,uuid)','EXECUTE')
  then raise exception 'DB-I08: answer append RPC privilege drift'; end if;

  if has_function_privilege('anon','public.ta_create_submission(uuid,uuid,timestamptz,text,text)','EXECUTE')
     or has_function_privilege('authenticated','public.ta_create_submission(uuid,uuid,timestamptz,text,text)','EXECUTE')
     or has_function_privilege('public','public.ta_create_submission(uuid,uuid,timestamptz,text,text)','EXECUTE')
     or not has_function_privilege('service_role','public.ta_create_submission(uuid,uuid,timestamptz,text,text)','EXECUTE')
  then raise exception 'DB-I09: submission RPC privilege drift'; end if;
end
$inv$;


-- Billing authority must expose only DB-derived provider-fact paths to service_role.
do $inv$
begin
  if not has_function_privilege('service_role',
    'public.ta_commit_provider_billing_event(text,text,timestamptz,text,text,text,text,text,timestamptz,timestamptz)','EXECUTE')
  then raise exception 'DB-I10: normal provider billing RPC unavailable'; end if;

  if not has_function_privilege('service_role',
    'public.ta_bind_and_commit_provider_subscription(text,text,text,timestamptz,text,text,text,text,text,timestamptz,timestamptz)','EXECUTE')
  then raise exception 'DB-I10: atomic initial billing RPC unavailable'; end if;

  if has_function_privilege('service_role',
    'public.ta_consume_checkout_binding(text,text,text)','EXECUTE')
  then raise exception 'DB-I10: split checkout consume primitive exposed'; end if;

  if has_function_privilege('service_role',
    'public.ta_commit_resolved_billing_event_v2(text,text,timestamptz,text,text,text,text,text,text,text,jsonb,timestamptz,timestamptz)','EXECUTE')
  then raise exception 'DB-I10: caller-derived entitlement RPC exposed'; end if;
end
$inv$;

rollback;
