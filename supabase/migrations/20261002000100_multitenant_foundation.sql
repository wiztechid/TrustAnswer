-- TrustAnswer SaaS v0.3 — foundational multi-tenant schema
-- Public-safe migration. Validation resolver internals remain private.

create extension if not exists pgcrypto;

create type public.ta_member_role as enum ('OWNER','ADMIN','MEMBER','REVIEWER');
create type public.ta_membership_state as enum ('ACTIVE','INVITED','SUSPENDED','REMOVED');

create table public.tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now()
);

create table public.tenant_memberships (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.ta_member_role not null,
  state public.ta_membership_state not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (tenant_id,user_id)
);

create or replace function public.ta_is_active_member(p_tenant uuid)
returns boolean language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.tenant_memberships m
    where m.tenant_id=p_tenant and m.user_id=auth.uid() and m.state='ACTIVE'
  );
$$;

create or replace function public.ta_has_role(p_tenant uuid, p_roles public.ta_member_role[])
returns boolean language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.tenant_memberships m
    where m.tenant_id=p_tenant and m.user_id=auth.uid()
      and m.state='ACTIVE' and m.role=any(p_roles)
  );
$$;

-- Direct tenant ownership is repeated on every tenant-owned row.
create table public.customers (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  id uuid not null default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now(),
  primary key (tenant_id,id)
);

create table public.questionnaires (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  id uuid not null default gen_random_uuid(),
  customer_id uuid not null,
  title text not null,
  due_at timestamptz,
  evaluation_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  primary key (tenant_id,id),
  foreign key (tenant_id,customer_id) references public.customers(tenant_id,id)
);

create table public.questionnaire_questions (
  tenant_id uuid not null,
  id uuid not null default gen_random_uuid(),
  questionnaire_id uuid not null,
  raw_question text not null,
  final_answer text,
  answer_state text not null default 'UNKNOWN',
  created_at timestamptz not null default now(),
  primary key (tenant_id,id),
  foreign key (tenant_id,questionnaire_id) references public.questionnaires(tenant_id,id)
);

create table public.canonical_answers (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  id uuid not null default gen_random_uuid(),
  claim_key text not null,
  created_at timestamptz not null default now(),
  primary key (tenant_id,id)
);

create table public.canonical_answer_revisions (
  tenant_id uuid not null,
  id uuid not null default gen_random_uuid(),
  canonical_answer_id uuid not null,
  revision_no integer not null check (revision_no > 0),
  canonical_answer text not null,
  effective_at timestamptz not null,
  known_at timestamptz not null,
  retired_at timestamptz,
  primary key (tenant_id,id),
  unique (tenant_id,canonical_answer_id,revision_no),
  foreign key (tenant_id,canonical_answer_id) references public.canonical_answers(tenant_id,id)
);

create table public.evidence_records (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  id uuid not null default gen_random_uuid(),
  title text not null,
  evidence_type text not null,
  created_at timestamptz not null default now(),
  primary key (tenant_id,id)
);

create table public.evidence_revisions (
  tenant_id uuid not null,
  id uuid not null default gen_random_uuid(),
  evidence_id uuid not null,
  revision_no integer not null check (revision_no > 0),
  source_reference text,
  effective_at timestamptz not null,
  known_at timestamptz not null,
  last_verified timestamptz,
  next_review timestamptz,
  freshness_state text not null default 'UNKNOWN',
  shareability text not null default 'INTERNAL_ONLY',
  lifecycle_state text not null default 'ACTIVE',
  primary key (tenant_id,id),
  unique (tenant_id,evidence_id,revision_no),
  foreign key (tenant_id,evidence_id) references public.evidence_records(tenant_id,id)
);

create table public.answer_evidence_bindings (
  tenant_id uuid not null,
  id uuid not null default gen_random_uuid(),
  canonical_revision_id uuid not null,
  evidence_revision_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (tenant_id,id),
  unique (tenant_id,canonical_revision_id,evidence_revision_id),
  foreign key (tenant_id,canonical_revision_id) references public.canonical_answer_revisions(tenant_id,id),
  foreign key (tenant_id,evidence_revision_id) references public.evidence_revisions(tenant_id,id)
);

create table public.gaps (
  tenant_id uuid not null,
  id uuid not null default gen_random_uuid(),
  question_id uuid not null,
  gap_type text not null,
  severity text not null,
  status text not null default 'OPEN',
  created_at timestamptz not null default now(),
  primary key (tenant_id,id),
  foreign key (tenant_id,question_id) references public.questionnaire_questions(tenant_id,id)
);

create table public.reviews (
  tenant_id uuid not null,
  id uuid not null default gen_random_uuid(),
  question_id uuid not null,
  reviewer_user_id uuid not null references auth.users(id),
  decision text not null default 'PENDING',
  context_fingerprint text not null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (tenant_id,id),
  foreign key (tenant_id,question_id) references public.questionnaire_questions(tenant_id,id)
);

create table public.submissions (
  tenant_id uuid not null,
  id uuid not null default gen_random_uuid(),
  questionnaire_id uuid not null,
  submitted_at timestamptz not null default now(),
  evaluation_at timestamptz not null,
  schema_version text not null,
  validation_contract_version text not null,
  gate_result text not null check (gate_result in ('READY')),
  primary key (tenant_id,id),
  foreign key (tenant_id,questionnaire_id) references public.questionnaires(tenant_id,id)
);

create table public.submission_items (
  tenant_id uuid not null,
  submission_id uuid not null,
  id uuid not null default gen_random_uuid(),
  question_id uuid not null,
  raw_question_hash text not null,
  final_answer text not null,
  answer_revision_ref text,
  canonical_revision_ref text,
  evidence_revision_refs jsonb not null default '[]'::jsonb,
  review_ref text not null,
  snapshot jsonb not null,
  primary key (tenant_id,id),
  foreign key (tenant_id,submission_id) references public.submissions(tenant_id,id),
  foreign key (tenant_id,question_id) references public.questionnaire_questions(tenant_id,id)
);

-- Billing tables are not client-writable. Provider state is ingested server-side.
create table public.subscriptions (
  tenant_id uuid primary key references public.tenants(id) on delete cascade,
  provider text not null check (provider='PADDLE'),
  provider_customer_id text,
  provider_subscription_id text unique,
  provider_price_id text,
  provider_status text not null default 'UNKNOWN',
  provider_event_at timestamptz,
  reconciled_at timestamptz,
  updated_at timestamptz not null default now()
);

create table public.entitlements (
  tenant_id uuid primary key references public.tenants(id) on delete cascade,
  plan_code text not null default 'FREE',
  status text not null default 'UNKNOWN',
  limits jsonb not null default '{}'::jsonb,
  derived_at timestamptz not null default now()
);

create table public.webhook_events (
  provider text not null,
  event_id text not null,
  occurred_at timestamptz,
  received_at timestamptz not null default now(),
  signature_verified boolean not null default false,
  processing_state text not null default 'RECEIVED',
  payload_hash text not null,
  primary key (provider,event_id)
);

-- RLS: all exposed tenant-owned tables default deny unless explicit policies exist.
alter table public.tenants enable row level security;
alter table public.tenant_memberships enable row level security;
alter table public.customers enable row level security;
alter table public.questionnaires enable row level security;
alter table public.questionnaire_questions enable row level security;
alter table public.canonical_answers enable row level security;
alter table public.canonical_answer_revisions enable row level security;
alter table public.evidence_records enable row level security;
alter table public.evidence_revisions enable row level security;
alter table public.answer_evidence_bindings enable row level security;
alter table public.gaps enable row level security;
alter table public.reviews enable row level security;
alter table public.submissions enable row level security;
alter table public.submission_items enable row level security;
alter table public.subscriptions enable row level security;
alter table public.entitlements enable row level security;
alter table public.webhook_events enable row level security;

create policy tenant_read on public.tenants for select
using (public.ta_is_active_member(id));

create policy membership_read on public.tenant_memberships for select
using (public.ta_is_active_member(tenant_id));

-- Membership writes intentionally have no browser RLS policy: privileged server operation only.

-- Standard tenant data: active members may read; only owner/admin/member may mutate.
do $$
declare t text;
begin
  foreach t in array array[
    'customers','questionnaires','questionnaire_questions','canonical_answers',
    'canonical_answer_revisions','evidence_records','evidence_revisions',
    'answer_evidence_bindings','gaps'
  ] loop
    execute format('create policy %I on public.%I for select using (public.ta_is_active_member(tenant_id))',t||'_read',t);
    execute format('create policy %I on public.%I for insert with check (public.ta_has_role(tenant_id, ARRAY[''OWNER'',''ADMIN'',''MEMBER'']::public.ta_member_role[]))',t||'_insert',t);
    execute format('create policy %I on public.%I for update using (public.ta_has_role(tenant_id, ARRAY[''OWNER'',''ADMIN'',''MEMBER'']::public.ta_member_role[])) with check (public.ta_has_role(tenant_id, ARRAY[''OWNER'',''ADMIN'',''MEMBER'']::public.ta_member_role[]))',t||'_update',t);
    execute format('create policy %I on public.%I for delete using (public.ta_has_role(tenant_id, ARRAY[''OWNER'',''ADMIN'']::public.ta_member_role[]))',t||'_delete',t);
  end loop;
end $$;

create policy reviews_read on public.reviews for select using (public.ta_is_active_member(tenant_id));
create policy reviews_insert on public.reviews for insert
with check (
  reviewer_user_id=auth.uid()
  and public.ta_has_role(tenant_id, ARRAY['OWNER','ADMIN','REVIEWER']::public.ta_member_role[])
);
-- Review mutation/deletion intentionally omitted; decisions are append-oriented.

create policy submissions_read on public.submissions for select using (public.ta_is_active_member(tenant_id));
create policy submission_items_read on public.submission_items for select using (public.ta_is_active_member(tenant_id));
-- Submission creation is server-authoritative; no client insert/update/delete policies.

create policy subscriptions_read on public.subscriptions for select using (public.ta_is_active_member(tenant_id));
create policy entitlements_read on public.entitlements for select using (public.ta_is_active_member(tenant_id));
-- Billing and webhook writes are server-only. webhook_events has no browser policies.

revoke all on public.webhook_events from anon, authenticated;
