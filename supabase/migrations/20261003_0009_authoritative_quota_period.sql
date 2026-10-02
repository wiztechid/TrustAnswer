-- TrustAnswer v0.3 — database-authoritative quota period
alter table public.subscriptions
  add column current_period_start timestamptz;

alter table public.subscriptions
  add constraint subscription_period_check
  check (
    (current_period_start is null and current_period_end is null)
    or
    (current_period_start is not null and current_period_end is not null
      and current_period_start < current_period_end)
  );

create or replace function public.ta_consume_current_quota(
  p_tenant_id uuid,
  p_metric text,
  p_quantity integer,
  p_idempotency_key text,
  p_source text
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_start timestamptz;
  v_end timestamptz;
begin
  select current_period_start,current_period_end into v_start,v_end
  from public.subscriptions
  where tenant_id=p_tenant_id
  for update;

  if not found or v_start is null or v_end is null or v_start>=v_end then
    raise exception 'QUOTA_PERIOD_UNKNOWN';
  end if;

  return public.ta_consume_quota(
    p_tenant_id,p_metric,p_quantity,p_idempotency_key,p_source,v_start,v_end
  );
end;
$$;

revoke all on function public.ta_consume_current_quota(uuid,text,integer,text,text)
  from public,anon,authenticated;
grant execute on function public.ta_consume_current_quota(uuid,text,integer,text,text)
  to service_role;

-- Caller must use the DB-resolved period wrapper.
revoke all on function public.ta_consume_quota(
  uuid,text,integer,text,text,timestamptz,timestamptz
) from public,anon,authenticated,service_role;
