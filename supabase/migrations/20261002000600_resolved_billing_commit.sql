-- TrustAnswer v0.3 — resolved billing commit wrapper
-- Prevents server adapter from independently choosing tenant_id.

create or replace function public.ta_commit_resolved_billing_event(
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
  p_limits jsonb default '{}'::jsonb
) returns text
language plpgsql
security definer
set search_path=''
as $$
declare
  v_tenant uuid;
begin
  v_tenant := public.ta_resolve_billing_tenant('PADDLE',p_customer_id,p_subscription_id);
  if v_tenant is null then
    return 'RECONCILE';
  end if;

  return public.ta_commit_billing_event(
    v_tenant,p_event_id,p_event_type,p_occurred_at,p_payload_hash,
    p_customer_id,p_subscription_id,p_price_id,p_provider_status,
    p_entitlement_state,p_plan_code,p_limits
  );
end;
$$;

revoke all on function public.ta_commit_resolved_billing_event(
  text,text,timestamptz,text,text,text,text,text,text,text,jsonb
) from public,anon,authenticated;
grant execute on function public.ta_commit_resolved_billing_event(
  text,text,timestamptz,text,text,text,text,text,text,text,jsonb
) to service_role;

-- The lower-level tenant-accepting commit is no longer directly callable by service_role.
-- Only the resolved wrapper (as SECURITY DEFINER owner) should reach it.
revoke execute on function public.ta_commit_billing_event(
  uuid,text,text,timestamptz,text,text,text,text,text,text,text,jsonb
) from service_role;
