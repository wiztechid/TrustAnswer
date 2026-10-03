-- TrustAnswer v0.3 — atomic first subscription binding + billing transition.
-- One transaction consumes the checkout handle, creates exact provider identity,
-- derives entitlement from DB catalog, and commits the verified provider event.

create or replace function public.ta_bind_and_commit_provider_subscription(
 p_token_hash text,p_event_id text,p_event_type text,p_occurred_at timestamptz,p_payload_hash text,
 p_customer_id text,p_subscription_id text,p_price_id text,p_provider_status text,
 p_period_start timestamptz,p_period_end timestamptz
) returns text
language plpgsql security definer set search_path=''
as $$
declare
 v public.checkout_binding_tokens%rowtype;
 v_plan text:='FREE'; v_limits jsonb:='{}'::jsonb; v_state text:='UNKNOWN'; v_result text;
begin
 if p_event_type<>'subscription.created' then raise exception 'BIND_EVENT_TYPE_INVALID'; end if;
 if length(trim(coalesce(p_token_hash,'')))<32 then raise exception 'CHECKOUT_BINDING_INPUT_INVALID'; end if;
 if (p_period_start is null)<>(p_period_end is null)
    or (p_period_start is not null and p_period_start>=p_period_end) then raise exception 'BILLING_PERIOD_INVALID'; end if;

 select * into v from public.checkout_binding_tokens where token_hash=p_token_hash for update;
 if not found then raise exception 'CHECKOUT_BINDING_UNKNOWN'; end if;
 if v.consumed_at is not null then raise exception 'CHECKOUT_BINDING_ALREADY_CONSUMED'; end if;
 if v.expires_at<=now() then raise exception 'CHECKOUT_BINDING_EXPIRED'; end if;

 insert into public.billing_identity_bindings(
   tenant_id,provider,provider_customer_id,provider_subscription_id,binding_state,activated_at
 ) values(v.tenant_id,'PADDLE',p_customer_id,p_subscription_id,'ACTIVE',now());

 if p_provider_status in ('active','trialing') then
   if p_period_start is not null then
     select plan_code,entitlements into v_plan,v_limits from public.plan_catalog
     where provider='PADDLE' and provider_price_id=p_price_id and active=true;
     if found then v_state:='ACTIVE'; else v_plan:='FREE';v_limits:='{}';v_state:='UNKNOWN'; end if;
   end if;
 elsif p_provider_status in ('past_due','paused','canceled') then v_state:='BLOCKED';
 end if;

 v_result:=public.ta_commit_billing_event(
   v.tenant_id,p_event_id,p_event_type,p_occurred_at,p_payload_hash,p_customer_id,p_subscription_id,
   p_price_id,p_provider_status,v_state,v_plan,v_limits
 );
 if v_result='APPLIED' then
   update public.subscriptions set current_period_start=p_period_start,current_period_end=p_period_end
   where tenant_id=v.tenant_id and last_event_id=p_event_id;
   update public.checkout_binding_tokens set consumed_at=now() where token_hash=p_token_hash;
 else
   raise exception 'INITIAL_BILLING_COMMIT_NOT_APPLIED';
 end if;
 return v_result;
end;
$$;

revoke all on function public.ta_bind_and_commit_provider_subscription(
 text,text,text,timestamptz,text,text,text,text,text,timestamptz,timestamptz
) from public,anon,authenticated;
grant execute on function public.ta_bind_and_commit_provider_subscription(
 text,text,text,timestamptz,text,text,text,text,text,timestamptz,timestamptz
) to service_role;

revoke execute on function public.ta_consume_checkout_binding(text,text,text) from service_role;
