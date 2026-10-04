-- TrustAnswer v0.3 billing identity + transaction invariants
-- Disposable test database only.

begin;

-- Binding surface is server-only and unambiguous by unique provider identities.
do $$
declare bad text;
begin
  select string_agg(privilege_type,',') into bad
  from information_schema.role_table_grants
  where grantee='authenticated'
    and table_schema='public'
    and table_name='billing_identity_bindings'
    and privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE');
  if bad is not null then raise exception 'BIND-I01: client mutation privilege: %',bad; end if;
end $$;

do $$
begin
  if has_function_privilege('public','public.ta_resolve_billing_tenant(text,text,text)','EXECUTE')
     or has_function_privilege('anon','public.ta_resolve_billing_tenant(text,text,text)','EXECUTE')
     or has_function_privilege('authenticated','public.ta_resolve_billing_tenant(text,text,text)','EXECUTE')
  then raise exception 'BIND-I02: resolver execution too broad'; end if;
end $$;

-- Atomic billing RPC must remain server-only.
do $$
begin
  if has_function_privilege(
    'authenticated',
    'public.ta_commit_billing_event(uuid,text,text,timestamptz,text,text,text,text,text,text,text,jsonb)',
    'EXECUTE'
  ) then raise exception 'BIND-I03: billing commit exposed to client'; end if;
end $$;

rollback;
