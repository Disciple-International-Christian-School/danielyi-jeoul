-- 2026-09-25
-- External identity bridge for DICS apps that still live in separate Supabase
-- projects during the consolidation period.
--
-- core.students.auth_user_id is intentionally reserved for auth.users in THIS
-- DICS Core Supabase project. UUIDs from another Supabase project cannot be
-- referenced by that FK even when their textual UUID format is identical.
--
-- Example transition:
--   SP external auth UUID
--      -> core.external_auth_identities
--      -> core.students.id
--
-- Later, after the student account is provisioned/migrated into DICS Core Auth:
--   core.students.auth_user_id
--      -> local auth.users.id

create table if not exists core.external_auth_identities (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references core.students(id) on delete cascade,

  source_system text not null,
  source_project_ref text,
  external_user_id text not null,
  external_login_id text,

  is_active boolean not null default true,
  linked_at timestamptz not null default now(),
  last_verified_at timestamptz,
  notes text,

  unique (source_system, external_user_id),
  unique (source_system, student_id),

  check (char_length(btrim(source_system)) between 1 and 80),
  check (char_length(btrim(external_user_id)) between 1 and 200)
);

create index if not exists core_external_auth_identities_student_idx
  on core.external_auth_identities (student_id);

comment on table core.external_auth_identities is
  'Temporary/transition mapping from auth identities in external app Supabase projects to canonical core.students.id.';
comment on column core.external_auth_identities.source_system is
  'Stable logical source name such as STUDY_PLANNER.';
comment on column core.external_auth_identities.source_project_ref is
  'Optional external Supabase project ref for migration provenance; not a credential.';
comment on column core.external_auth_identities.external_user_id is
  'External auth/user identifier stored as text because it belongs to another project and cannot be an FK to local auth.users.';
comment on column core.external_auth_identities.external_login_id is
  'Optional external login identifier such as the existing SP student_no; never store PIN/password here.';

alter table core.external_auth_identities enable row level security;

drop policy if exists core_external_auth_identities_read_lead on core.external_auth_identities;
create policy core_external_auth_identities_read_lead on core.external_auth_identities
  for select to authenticated
  using (private.current_admin_is_lead());

grant select on core.external_auth_identities to authenticated;

create or replace view public.v_core_identity_readiness
with (security_invoker = true) as
select
  count(*)::int as core_students,
  count(*) filter (where student_no is not null)::int as student_no_assigned,
  count(*) filter (where auth_user_id is not null)::int as local_auth_linked,
  (
    select count(*)::int
    from core.external_auth_identities x
    where x.is_active
  ) as external_auth_linked
from core.students;

comment on view public.v_core_identity_readiness is
  'Aggregate identity migration readiness without exposing external identifiers.';

grant select on public.v_core_identity_readiness to authenticated;
