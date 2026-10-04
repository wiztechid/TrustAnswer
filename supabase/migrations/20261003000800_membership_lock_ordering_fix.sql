-- TrustAnswer v0.3 — close last-active-owner concurrency race
-- The tenant advisory lock must be acquired before authorization-sensitive membership reads/counts.

create or replace function public.ta_change_membership(
  p_tenant_id uuid,
  p_target_user_id uuid,
  p_action public.ta_membership_action,
  p_role public.ta_member_role default null
) returns void
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=auth.uid();
  v_old public.tenant_memberships%rowtype;
  v_new_state public.ta_membership_state;
  v_new_role public.ta_member_role;
  v_owner_count integer;
begin
  -- Serialize all membership authority decisions before any role/count read.
  perform public.ta_membership_lock(p_tenant_id);

  if v_actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.ta_has_role(p_tenant_id,ARRAY['OWNER','ADMIN']::public.ta_member_role[]) then
    raise exception 'MEMBERSHIP_FORBIDDEN';
  end if;

  select * into v_old from public.tenant_memberships
    where tenant_id=p_tenant_id and user_id=p_target_user_id for update;

  if p_action='INVITE' then
    if found then raise exception 'MEMBERSHIP_ALREADY_EXISTS'; end if;
    if p_role is null or p_role='OWNER' then raise exception 'INVITE_ROLE_INVALID'; end if;
    insert into public.tenant_memberships(tenant_id,user_id,role,state)
      values(p_tenant_id,p_target_user_id,p_role,'INVITED');
    insert into public.membership_events(
      tenant_id,target_user_id,actor_user_id,action,to_state,to_role
    ) values(p_tenant_id,p_target_user_id,v_actor,p_action,'INVITED',p_role);
    return;
  end if;

  if not found then raise exception 'MEMBERSHIP_NOT_FOUND'; end if;

  -- Only OWNER may create/change/remove OWNER authority.
  if (v_old.role='OWNER' or p_role='OWNER')
     and not public.ta_has_role(p_tenant_id,ARRAY['OWNER']::public.ta_member_role[]) then
    raise exception 'OWNER_AUTHORITY_REQUIRED';
  end if;

  v_new_state:=v_old.state;
  v_new_role:=v_old.role;

  case p_action
    when 'ACTIVATE' then
      if v_old.state not in ('INVITED','SUSPENDED') then raise exception 'INVALID_MEMBERSHIP_TRANSITION'; end if;
      v_new_state:='ACTIVE';
    when 'CHANGE_ROLE' then
      if v_old.state<>'ACTIVE' or p_role is null then raise exception 'INVALID_MEMBERSHIP_TRANSITION'; end if;
      v_new_role:=p_role;
    when 'SUSPEND' then
      if v_old.state<>'ACTIVE' then raise exception 'INVALID_MEMBERSHIP_TRANSITION'; end if;
      v_new_state:='SUSPENDED';
    when 'REMOVE' then
      if v_old.state='REMOVED' then raise exception 'INVALID_MEMBERSHIP_TRANSITION'; end if;
      v_new_state:='REMOVED';
    else
      raise exception 'INVALID_MEMBERSHIP_ACTION';
  end case;

  if v_old.role='OWNER' and (v_new_role<>'OWNER' or v_new_state<>'ACTIVE') then
    select count(*) into v_owner_count from public.tenant_memberships
      where tenant_id=p_tenant_id and role='OWNER' and state='ACTIVE';
    if v_owner_count<=1 then raise exception 'LAST_ACTIVE_OWNER_REQUIRED'; end if;
  end if;

  update public.tenant_memberships
  set role=v_new_role,state=v_new_state,updated_at=now()
  where tenant_id=p_tenant_id and user_id=p_target_user_id;

  insert into public.membership_events(
    tenant_id,target_user_id,actor_user_id,action,
    from_state,to_state,from_role,to_role
  ) values(
    p_tenant_id,p_target_user_id,v_actor,p_action,
    v_old.state,v_new_state,v_old.role,v_new_role
  );
end;
$$;

revoke all on function public.ta_change_membership(
  uuid,uuid,public.ta_membership_action,public.ta_member_role
) from public,anon;
grant execute on function public.ta_change_membership(
  uuid,uuid,public.ta_membership_action,public.ta_member_role
) to authenticated;

