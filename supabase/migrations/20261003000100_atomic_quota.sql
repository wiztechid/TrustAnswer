-- TrustAnswer v0.3 — atomic quota consumption
-- Service-role only. Quota authority is current DB entitlement, never browser state.

create or replace function public.ta_consume_quota(
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
  v_status text;
  v_plan text;
  v_limit integer;
  v_used bigint;
  v_existing_metric text;
  v_existing_quantity integer;
begin
  if p_tenant_id is null or length(trim(coalesce(p_metric,'')))=0
     or p_quantity <= 0 or length(trim(coalesce(p_idempotency_key,'')))=0 then
    raise exception 'QUOTA_INPUT_INVALID';
  end if;

  -- Serialize quota mutations for this tenant+metric.
  perform pg_advisory_xact_lock(hashtextextended(p_tenant_id::text || ':' || p_metric, 0));

  select metric,quantity into v_existing_metric,v_existing_quantity
  from public.usage_events
  where tenant_id=p_tenant_id and idempotency_key=p_idempotency_key;

  if found then
    if v_existing_metric<>p_metric or v_existing_quantity<>p_quantity then
      raise exception 'QUOTA_IDEMPOTENCY_CONFLICT';
    end if;
    select coalesce(sum(quantity),0) into v_used
      from public.usage_events
      where tenant_id=p_tenant_id and metric=p_metric;
    return jsonb_build_object('result','IGNORED_DUPLICATE','used',v_used);
  end if;

  select status,plan_code,
    case
      when jsonb_typeof(limits->p_metric)='number'
      then (limits->>p_metric)::integer
      else null
    end
  into v_status,v_plan,v_limit
  from public.entitlements
  where tenant_id=p_tenant_id
  for update;

  if not found or v_status<>'ACTIVE' then
    raise exception 'ENTITLEMENT_DENIED';
  end if;

  if v_limit is null or v_limit < 0 then
    raise exception 'QUOTA_UNKNOWN';
  end if;

  select coalesce(sum(quantity),0) into v_used
  from public.usage_events
  where tenant_id=p_tenant_id and metric=p_metric;

  if v_used + p_quantity > v_limit then
    raise exception 'QUOTA_EXCEEDED';
  end if;

  insert into public.usage_events(tenant_id,metric,quantity,idempotency_key,source)
  values(p_tenant_id,p_metric,p_quantity,p_idempotency_key,p_source);

  return jsonb_build_object(
    'result','CONSUMED',
    'plan',v_plan,
    'used',v_used+p_quantity,
    'limit',v_limit,
    'remaining',v_limit-(v_used+p_quantity)
  );
end;
$$;

revoke all on function public.ta_consume_quota(uuid,text,integer,text,text)
  from public,anon,authenticated;
grant execute on function public.ta_consume_quota(uuid,text,integer,text,text)
  to service_role;
