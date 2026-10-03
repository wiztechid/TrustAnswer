-- TrustAnswer v0.3 quota security invariants
begin;

do $$
begin
  if has_function_privilege(
    'authenticated',
    'public.ta_consume_quota(uuid,text,integer,text,text)',
    'EXECUTE'
  ) then raise exception 'QUOTA-I01: quota RPC exposed to authenticated client'; end if;
end $$;

do $$
declare bad text;
begin
  select string_agg(privilege_type,',') into bad
  from information_schema.role_table_grants
  where grantee='authenticated'
    and table_schema='public'
    and table_name='usage_events'
    and privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE');
  if bad is not null then
    raise exception 'QUOTA-I02: usage ledger client mutation privilege: %',bad;
  end if;
end $$;

rollback;
