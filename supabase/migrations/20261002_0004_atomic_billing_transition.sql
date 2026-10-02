-- TrustAnswer v0.3 — atomic billing transition RPC foundation
-- Server/service-role only. Webhook signature verification occurs before invocation.

create or replace function public.ta_commit_billing_event(
  p_tenant_id uuid,
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
set search_path = ''
as $$
declare
  v_last_at timestamptz;
  v_last_id text;
begin
  if p_event_id is null or p_subscription_id is null or p_customer_id is null or p_occurred_at is null then
    raise exception 'BILLING_INPUT_MISSING';
  end if;

  -- Serialize all transitions for one tenant.
  perform pg_advisory_xact_lock(hashtextextended(p_tenant_id::text, 0));

  if exists (
    select 1 from public.webhook_events
    where provider='PADDLE' and event_id=p_event_id and processing_state='COMPLETED'
  ) then
    return 'IGNORED_DUPLICATE';
  end if;

  select last_event_occurred_at,last_event_id into v_last_at,v_last_id
  from public.subscriptions where tenant_id=p_tenant_id for update;

  if v_last_at is not null and p_occurred_at < v_last_at then
    insert into public.webhook_events(
      provider,event_id,tenant_id,occurred_at,provider_event_type,provider_object_id,
      signature_verified,processing_state,payload_hash,processed_at
    ) values (
      'PADDLE',p_event_id,p_tenant_id,p_occurred_at,p_event_type,p_subscription_id,
      true,'STALE',p_payload_hash,now()
    ) on conflict (provider,event_id) do nothing;
    return 'STALE';
  end if;

  if v_last_at is not null and p_occurred_at = v_last_at and coalesce(v_last_id,'') <> p_event_id then
    insert into public.webhook_events(
      provider,event_id,tenant_id,occurred_at,provider_event_type,provider_object_id,
      signature_verified,processing_state,payload_hash,processed_at,processing_error_code
    ) values (
      'PADDLE',p_event_id,p_tenant_id,p_occurred_at,p_event_type,p_subscription_id,
      true,'RECONCILE',p_payload_hash,now(),'AMBIGUOUS_SAME_TIME_EVENTS'
    ) on conflict (provider,event_id) do nothing;

    update public.entitlements
      set status='UNKNOWN',plan_code='FREE',limits='{}'::jsonb,derived_at=now()
      where tenant_id=p_tenant_id;
    return 'RECONCILE';
  end if;

  insert into public.webhook_events(
    provider,event_id,tenant_id,occurred_at,provider_event_type,provider_object_id,
    signature_verified,processing_state,payload_hash,processed_at
  ) values (
    'PADDLE',p_event_id,p_tenant_id,p_occurred_at,p_event_type,p_subscription_id,
    true,'COMPLETED',p_payload_hash,now()
  )
  on conflict (provider,event_id) do update
    set processing_state='COMPLETED', processed_at=excluded.processed_at;

  insert into public.subscriptions(
    tenant_id,provider,provider_customer_id,provider_subscription_id,provider_price_id,
    provider_status,provider_event_at,last_event_id,last_event_occurred_at,
    entitlement_state,updated_at
  ) values (
    p_tenant_id,'PADDLE',p_customer_id,p_subscription_id,p_price_id,
    p_provider_status,p_occurred_at,p_event_id,p_occurred_at,p_entitlement_state,now()
  )
  on conflict (tenant_id) do update set
    provider_customer_id=excluded.provider_customer_id,
    provider_subscription_id=excluded.provider_subscription_id,
    provider_price_id=excluded.provider_price_id,
    provider_status=excluded.provider_status,
    provider_event_at=excluded.provider_event_at,
    last_event_id=excluded.last_event_id,
    last_event_occurred_at=excluded.last_event_occurred_at,
    entitlement_state=excluded.entitlement_state,
    updated_at=excluded.updated_at;

  insert into public.entitlements(tenant_id,plan_code,status,limits,derived_at)
  values (p_tenant_id,p_plan_code,p_entitlement_state,p_limits,now())
  on conflict (tenant_id) do update set
    plan_code=excluded.plan_code,
    status=excluded.status,
    limits=excluded.limits,
    derived_at=excluded.derived_at;

  return 'APPLIED';
end;
$$;

revoke all on function public.ta_commit_billing_event(
  uuid,text,text,timestamptz,text,text,text,text,text,text,text,jsonb
) from public, anon, authenticated;
grant execute on function public.ta_commit_billing_event(
  uuid,text,text,timestamptz,text,text,text,text,text,text,text,jsonb
) to service_role;
