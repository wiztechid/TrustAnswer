-- TrustAnswer v0.3 — trusted checkout binding token foundation
-- Browser may carry only an opaque one-time token; tenant identity is resolved server-side.

create table public.checkout_binding_tokens (
 token_hash text primary key,
 tenant_id uuid not null references public.tenants(id),
 created_by uuid not null references auth.users(id),
 expires_at timestamptz not null,
 consumed_at timestamptz,
 created_at timestamptz not null default now(),
 check(expires_at>created_at)
);
alter table public.checkout_binding_tokens enable row level security;
revoke all on public.checkout_binding_tokens from public,anon,authenticated;

create or replace function public.ta_issue_checkout_binding(
 p_tenant_id uuid,p_actor_user_id uuid,p_token_hash text,p_expires_at timestamptz
) returns void
language plpgsql security definer set search_path=''
as $$
begin
 if p_tenant_id is null or p_actor_user_id is null
    or length(trim(coalesce(p_token_hash,'')))<32 or p_expires_at<=now()
 then raise exception 'CHECKOUT_BINDING_INPUT_INVALID'; end if;
 if not exists(select 1 from public.tenant_memberships
   where tenant_id=p_tenant_id and user_id=p_actor_user_id and state='ACTIVE' and role in ('OWNER','ADMIN'))
 then raise exception 'CHECKOUT_BINDING_FORBIDDEN'; end if;
 insert into public.checkout_binding_tokens(token_hash,tenant_id,created_by,expires_at)
 values(p_token_hash,p_tenant_id,p_actor_user_id,p_expires_at);
end;
$$;
revoke all on function public.ta_issue_checkout_binding(uuid,uuid,text,timestamptz) from public,anon,authenticated;
grant execute on function public.ta_issue_checkout_binding(uuid,uuid,text,timestamptz) to service_role;

create or replace function public.ta_consume_checkout_binding(
 p_token_hash text,p_provider_customer_id text,p_provider_subscription_id text
) returns uuid
language plpgsql security definer set search_path=''
as $$
declare v public.checkout_binding_tokens%rowtype;
begin
 if length(trim(coalesce(p_token_hash,'')))<32
    or length(trim(coalesce(p_provider_customer_id,'')))=0
    or length(trim(coalesce(p_provider_subscription_id,'')))=0
 then raise exception 'CHECKOUT_BINDING_INPUT_INVALID'; end if;

 select * into v from public.checkout_binding_tokens
 where token_hash=p_token_hash for update;
 if not found then raise exception 'CHECKOUT_BINDING_UNKNOWN'; end if;
 if v.consumed_at is not null then raise exception 'CHECKOUT_BINDING_ALREADY_CONSUMED'; end if;
 if v.expires_at<=now() then raise exception 'CHECKOUT_BINDING_EXPIRED'; end if;

 insert into public.billing_identity_bindings(
   tenant_id,provider,provider_customer_id,provider_subscription_id,binding_state,activated_at
 ) values(
   v.tenant_id,'PADDLE',p_provider_customer_id,p_provider_subscription_id,'ACTIVE',now()
 );

 update public.checkout_binding_tokens set consumed_at=now() where token_hash=p_token_hash;
 return v.tenant_id;
end;
$$;
revoke all on function public.ta_consume_checkout_binding(text,text,text) from public,anon,authenticated;
grant execute on function public.ta_consume_checkout_binding(text,text,text) to service_role;
