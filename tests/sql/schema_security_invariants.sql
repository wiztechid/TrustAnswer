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
      'billing_identity_bindings'
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
      'billing_identity_bindings'
    )
    and cmd in ('INSERT','UPDATE','DELETE','ALL');
  if bad is not null then raise exception 'DB-I04: client-facing mutation policy exists: %',bad; end if;
end $$;

-- Revision anchors are append-only to authenticated clients.
do $
declare bad text;
begin
  select string_agg(table_name||':'||privilege_type,', ' order by table_name,privilege_type) into bad
  from information_schema.role_table_grants
  where grantee='authenticated' and table_schema='public'
    and table_name in ('canonical_answer_revisions','evidence_revisions','question_answer_revisions')
    and privilege_type in ('UPDATE','DELETE','TRUNCATE');
  if bad is not null then raise exception 'DB-I05: mutable revision anchor: %',bad; end if;
end $;

-- Tenant ownership trigger must cover every mutable tenant-owned application table.
do $
declare bad text;
begin
  with required(name) as (values
    ('tenant_memberships'),('customers'),('questionnaires'),('questionnaire_questions'),
    ('canonical_answers'),('canonical_answer_revisions'),('evidence_records'),('evidence_revisions'),
    ('answer_evidence_bindings'),('gaps'),('reviews'),('submissions'),('submission_items'),
    ('subscriptions'),('entitlements'),('usage_events'),('billing_identity_bindings'),
    ('question_answer_revisions')
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
end $;

rollback;
