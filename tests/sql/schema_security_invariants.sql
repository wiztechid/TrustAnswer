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
      'webhook_events','submissions','submission_items','plan_catalog','usage_events'
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
      'webhook_events','submissions','submission_items','plan_catalog','usage_events'
    )
    and cmd in ('INSERT','UPDATE','DELETE','ALL');
  if bad is not null then raise exception 'DB-I04: client-facing mutation policy exists: %',bad; end if;
end $$;

rollback;
