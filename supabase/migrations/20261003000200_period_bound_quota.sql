-- TrustAnswer v0.3 — period-bound usage ledger

alter table public.usage_events
  add column period_start timestamptz,
  add column period_end timestamptz;

alter table public.usage_events
  add constraint usage_period_pair_check
  check (
    (period_start is null and period_end is null)
    or
    (period_start is not null and period_end is not null and period_start < period_end)
  );

-- Replace quota RPC with explicit authoritative period supplied by trusted server billing state.
create or replace function public.ta_consume_quota(
  p_tenant_id uuid,
  p_metric text,
  p_quantity integer,
  p_idempotency_key text,
  p_source text,
  p_period_start timestamptz,
  p_period_end timestamptz
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
  v_existing_start timestamptz;
  v_existing_end timestamptz;
begin
  if p_tenant_id is null or length(trim(coalesce(p_metric,'')))=0
     or p_quantity<=0 or length(trim(coalesce(p_idempotency_key,'')))=0
     or p_period_start is null or p_period_end is null or p_period_start>=p_period_end then
    raise exception 'QUOTA_INPUT_INVALID';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(p_tenant_id::text || ':' || p_metric || ':' || p_period_start::text,0)
  );

  select metric,quantity,period_start,period_end
    into v_existing_metric,v_existing_quantity,v_existing_start,v_existing_end
  from public.usage_events
  where tenant_id=p_tenant_id and idempotency_key=p_idempotency_key;

  if found then
    if v_existing_metric<>p_metric or v_existing_quantity<>p_quantity
       or v_existing_start<>p_period_start or v_existing_end<>p_period_end then
      raise exception 'QUOTA_IDEMPOTENCY_CONFLICT';
    end if;
    select coalesce(sum(quantity),0) into v_used
    from public.usage_events
    where tenant_id=p_tenant_id and metric=p_metric
      and period_start=p_period_start and period_end=p_period_end;
    return jsonb_build_object('result','IGNORED_DUPLICATE','used',v_used);
  end if;

  select status,plan_code,
    case when jsonb_typeof(limits->p_metric)='number'
      then (limits->>p_metric)::integer else null end
    into v_status,v_plan,v_limit
  from public.entitlements
  where tenant_id=p_tenant_id
  for update;

  if not found or v_status<>'ACTIVE' then raise exception 'ENTITLEMENT_DENIED'; end if;
  if v_limit is null or v_limit<0 then raise exception 'QUOTA_UNKNOWN'; end if;

  select coalesce(sum(quantity),0) into v_used
  from public.usage_events
  where tenant_id=p_tenant_id and metric=p_metric
    and period_start=p_period_start and period_end=p_period_end;

  if v_used+p_quantity>v_limit then raise exception 'QUOTA_EXCEEDED'; end if;

  insert into public.usage_events(
    tenant_id,metric,quantity,idempotency_key,source,period_start,period_end
  ) values(
    p_tenant_id,p_metric,p_quantity,p_idempotency_key,p_source,p_period_start,p_period_end
  );

  return jsonb_build_object(
    'result','CONSUMED','plan',v_plan,'used',v_used+p_quantity,
    'limit',v_limit,'remaining',v_limit-(v_used+p_quantity),
    'periodStart',p_period_start,'periodEnd',p_period_end
  );
end;
$$;

revoke all on function public.ta_consume_quota(
  uuid,text,integer,text,text,timestamptz,timestamptz
) from public,anon,authenticated;
grant execute on function public.ta_consume_quota(
  uuid,text,integer,text,text,timestamptz,timestamptz
) to service_role;

-- Retire direct execution of the pre-period signature.
revoke all on function public.ta_consume_quota(uuid,text,integer,text,text)
  from public,anon,authenticated,service_role;
