-- TrustAnswer v0.3 — billing period propagation
-- Replaces resolved billing commit with period-aware signature.

create or replace function public.ta_commit_resolved_billing_event_v2(
  p_event_id text,
  p_event_type text,
  p_occurred_at timestamptz,
  p_payload_hash text,
  p_customer_id text,
  p_subscription_id text,
  p_price_id text,
  p_provider_status text,
  p_entitlement_state text,
  p_plan_code text,
  p_limits jsonb,
  p_period_start timestamptz,
  p_period_end timestamptz
) returns text
language plpgsql
security definer
set search_path=''
as $$
declare
  v_tenant uuid;
  v_result text;
begin
  if (p_period_start is null) <> (p_period_end is null)
     or (p_period_start is not null and p_period_start>=p_period_end) then
    raise exception 'BILLING_PERIOD_INVALID';
  end if;

  v_tenant:=public.ta_resolve_billing_tenant('PADDLE',p_customer_id,p_subscription_id);
  if v_tenant is null then return 'RECONCILE'; end if;

  v_result:=public.ta_commit_billing_event(
    v_tenant,p_event_id,p_event_type,p_occurred_at,p_payload_hash,
    p_customer_id,p_subscription_id,p_price_id,p_provider_status,
    p_entitlement_state,p_plan_code,p_limits
  );

  if v_result='APPLIED' then
    update public.subscriptions
    set current_period_start=p_period_start,
        current_period_end=p_period_end
    where tenant_id=v_tenant
      and last_event_id=p_event_id;
  end if;

  return v_result;
end;
$$;

revoke all on function public.ta_commit_resolved_billing_event_v2(
 text,text,timestamptz,text,text,text,text,text,text,text,jsonb,timestamptz,timestamptz
) from public,anon,authenticated;
grant execute on function public.ta_commit_resolved_billing_event_v2(
 text,text,timestamptz,text,text,text,text,text,text,text,jsonb,timestamptz,timestamptz
) to service_role;

revoke all on function public.ta_commit_resolved_billing_event(
 text,text,timestamptz,text,text,text,text,text,text,text,jsonb
) from public,anon,authenticated,service_role;
