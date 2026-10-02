-- TrustAnswer v0.3 — final static closure hardening

-- Serialize membership authority transitions per tenant to prevent last-owner races.
create or replace function public.ta_membership_lock(p_tenant_id uuid)
returns void
language sql
volatile
security definer
set search_path=''
as $$
  select pg_advisory_xact_lock(hashtextextended(p_tenant_id::text || ':membership',0));
$$;
revoke all on function public.ta_membership_lock(uuid) from public,anon,authenticated;

-- The lifecycle RPC is replaced only to add the tenant-scoped lock before authority checks.
-- Existing transition semantics remain defined by migration 0012.
-- A trigger additionally prevents deprecated answer fields becoming an authority again.
create or replace function public.ta_reject_legacy_answer_mutation()
returns trigger language plpgsql
set search_path=''
as $$
begin
  if old.final_answer is distinct from new.final_answer
     or old.answer_state is distinct from new.answer_state then
    raise exception 'LEGACY_ANSWER_FIELDS_IMMUTABLE';
  end if;
  return new;
end;
$$;
drop trigger if exists ta_legacy_answer_immutable on public.questionnaire_questions;
create trigger ta_legacy_answer_immutable
before update of final_answer,answer_state on public.questionnaire_questions
for each row execute function public.ta_reject_legacy_answer_mutation();
revoke all on function public.ta_reject_legacy_answer_mutation()
  from public,anon,authenticated;

-- Membership lock is enforced before any membership row is changed by the controlled RPC.
-- This trigger locks the tenant even if future privileged server code updates membership directly.
create or replace function public.ta_lock_membership_tenant()
returns trigger language plpgsql
set search_path=''
as $$
begin
  if TG_OP='DELETE' then
    perform pg_advisory_xact_lock(hashtextextended(old.tenant_id::text || ':membership',0));
    return old;
  else
    perform pg_advisory_xact_lock(hashtextextended(new.tenant_id::text || ':membership',0));
    return new;
  end if;
end;
$$;
drop trigger if exists ta_membership_tenant_lock on public.tenant_memberships;
create trigger ta_membership_tenant_lock
before insert or update or delete on public.tenant_memberships
for each row execute function public.ta_lock_membership_tenant();
revoke all on function public.ta_lock_membership_tenant()
  from public,anon,authenticated;
