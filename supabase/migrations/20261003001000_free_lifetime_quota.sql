-- TrustAnswer v0.3 — authoritative FREE lifetime quota
-- FREE quota has no billing period; paid quota remains bound to provider billing period.

create or replace function public.ta_consume_authoritative_quota(
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
  v_start timestamptz;
  v_end timestamptz;
  v_used bigint;
  v_existing_metric text;
  v_existing_quantity integer;
  v_existing_start timestamptz;
  v_existing_end timestamptz;
begin
  if p_tenant_id is null or length(trim(coalesce(p_metric,'')))=0
     or p_quantity<=0 or length(trim(coalesce(p_idempotency_key,'')))=0 then
    raise exception 'QUOTA_INPUT_INVALID';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_tenant_id::text || ':' || p_metric || ':authoritative',0));

  select status,plan_code,
    case when jsonb_typeof(limits->p_metric)='number' then (limits->>p_metric)::integer else null end
  into v_status,v_plan,v_limit
  from public.entitlements where tenant_id=p_tenant_id for update;

  if not found or v_status<>'ACTIVE' then raise exception 'ENTITLEMENT_DENIED'; end if;
  if v_limit is null or v_limit<0 then raise exception 'QUOTA_UNKNOWN'; end if;

  if v_plan='FREE' then
    v_start:=null; v_end:=null;
  else
    select current_period_start,current_period_end into v_start,v_end
    from public.subscriptions where tenant_id=p_tenant_id for update;
    if not found or v_start is null or v_end is null or v_start>=v_end then
      raise exception 'QUOTA_PERIOD_UNKNOWN';
    end if;
  end if;

  select metric,quantity,period_start,period_end
  into v_existing_metric,v_existing_quantity,v_existing_start,v_existing_end
  from public.usage_events
  where tenant_id=p_tenant_id and idempotency_key=p_idempotency_key;

  if found then
    if v_existing_metric<>p_metric or v_existing_quantity<>p_quantity
       or v_existing_start is distinct from v_start or v_existing_end is distinct from v_end then
      raise exception 'QUOTA_IDEMPOTENCY_CONFLICT';
    end if;
    select coalesce(sum(quantity),0) into v_used from public.usage_events
    where tenant_id=p_tenant_id and metric=p_metric
      and period_start is not distinct from v_start and period_end is not distinct from v_end;
    return jsonb_build_object('result','IGNORED_DUPLICATE','used',v_used);
  end if;

  select coalesce(sum(quantity),0) into v_used from public.usage_events
  where tenant_id=p_tenant_id and metric=p_metric
    and period_start is not distinct from v_start and period_end is not distinct from v_end;

  if v_used+p_quantity>v_limit then raise exception 'QUOTA_EXCEEDED'; end if;

  insert into public.usage_events(tenant_id,metric,quantity,idempotency_key,source,period_start,period_end)
  values(p_tenant_id,p_metric,p_quantity,p_idempotency_key,p_source,v_start,v_end);

  return jsonb_build_object(
    'result','CONSUMED','plan',v_plan,'scope',case when v_plan='FREE' then 'LIFETIME' else 'BILLING_PERIOD' end,
    'used',v_used+p_quantity,'limit',v_limit,'remaining',v_limit-(v_used+p_quantity)
  );
end;
$$;

revoke all on function public.ta_consume_authoritative_quota(uuid,text,integer,text,text)
 from public,anon,authenticated;
grant execute on function public.ta_consume_authoritative_quota(uuid,text,integer,text,text) to service_role;

-- Retire the paid-period-only public service entry point.
revoke all on function public.ta_consume_current_quota(uuid,text,integer,text,text)
 from service_role;
