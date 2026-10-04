-- TrustAnswer v0.3 — trusted atomic tenant bootstrap
-- Creates workspace + initial OWNER + authoritative FREE entitlement in one transaction.

create or replace function public.ta_bootstrap_tenant(
 p_owner_user_id uuid,
 p_name text
) returns uuid
language plpgsql security definer set search_path=''
as $$
declare v_tenant uuid:=gen_random_uuid();
begin
 if p_owner_user_id is null or length(trim(coalesce(p_name,'')))=0
 then raise exception 'TENANT_BOOTSTRAP_INPUT_INVALID'; end if;
 if not exists(select 1 from auth.users where id=p_owner_user_id)
 then raise exception 'TENANT_BOOTSTRAP_USER_NOT_FOUND'; end if;

 insert into public.tenants(id,name) values(v_tenant,trim(p_name));
 insert into public.tenant_memberships(tenant_id,user_id,role,state)
 values(v_tenant,p_owner_user_id,'OWNER','ACTIVE');
 perform public.ta_provision_free_entitlement(v_tenant);

 if not exists(
   select 1 from public.entitlements
   where tenant_id=v_tenant and plan_code='FREE' and status='ACTIVE'
 ) then raise exception 'TENANT_BOOTSTRAP_ENTITLEMENT_FAILED'; end if;

 return v_tenant;
end;
$$;

revoke all on function public.ta_bootstrap_tenant(uuid,text) from public,anon,authenticated;
grant execute on function public.ta_bootstrap_tenant(uuid,text) to service_role;

-- FREE provisioning is an internal bootstrap primitive, not a general service API.
revoke execute on function public.ta_provision_free_entitlement(uuid) from service_role;
