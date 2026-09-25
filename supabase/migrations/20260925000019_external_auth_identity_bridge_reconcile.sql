-- 2026-09-25
-- Reconcile external Supabase Auth identities into version-controlled Core schema.
--
-- Why this exists:
-- A user UUID from another Supabase project is NOT a row in this Core project's
-- auth.users table and therefore cannot be stored as a foreign key to auth.users.
--
-- core.students.auth_user_id is reserved for a login identity provisioned in
-- THIS Core project.
--
-- Legacy/external project identities (for example Study Planner's current
-- Supabase Auth UUID) are stored here as external references.

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

comment on table core.external_auth_identities is
  'Maps canonical DICS students to login identities that belong to external/legacy systems or other Supabase projects.';

comment on column core.external_auth_identities.external_user_id is
  'External identity identifier as text. It is intentionally NOT a foreign key to this project auth.users.';

comment on column core.external_auth_identities.external_login_id is
  'Optional human-facing login identifier such as legacy student_no; never store PIN/password here.';

create index if not exists core_external_auth_identities_student_idx
  on core.external_auth_identities (student_id);

alter table core.external_auth_identities enable row level security;

drop policy if exists core_external_auth_identities_read_lead
  on core.external_auth_identities;

create policy core_external_auth_identities_read_lead
  on core.external_auth_identities
  for select
  to authenticated
  using (private.current_admin_is_lead());

grant select on core.external_auth_identities to authenticated;
