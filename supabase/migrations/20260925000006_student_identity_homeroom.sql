-- 2026-09-25
-- DICS Core student directory foundation.
--
-- IMPORTANT
-- - core.students is the canonical school-wide student identity.
-- - App-specific schemas must reference core.students.id instead of creating
--   independent student master tables.
-- - auth.users is an authentication account, not the student's canonical ID.
-- - Real roster rows, student numbers, birth dates and class assignments are
--   operational data and must be loaded directly into Supabase, never committed
--   to this public repository.
--
-- This migration intentionally keeps public.students as a temporary legacy
-- compatibility table for the existing Daniel's Scale deployment. A later
-- cut-over migration will move discipline foreign keys to core.students UUIDs
-- after roster import and mapping have been verified.

create schema if not exists core;
create schema if not exists discipline;

-- ---------------------------------------------------------------------------
-- Canonical student identity
-- ---------------------------------------------------------------------------

create table if not exists core.students (
  id uuid primary key default gen_random_uuid(),

  -- Human-facing school identifier. This is stable across DICS apps.
  student_no text not null unique,

  -- Authentication is optional. Elementary students or students who have not
  -- yet been provisioned can exist in the directory without an auth account.
  auth_user_id uuid unique references auth.users(id) on delete set null,

  name text not null check (char_length(btrim(name)) between 1 and 80),

  -- Directory-level attributes. Daniel's Scale itself should not expose these
  -- unless operationally necessary.
  birth_date date,
  gender text check (gender is null or gender in ('M', 'F')),

  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  check (
    char_length(btrim(student_no)) between 1 and 20
    and student_no = btrim(student_no)
  )
);

comment on table core.students is
  'Canonical DICS student directory. One row per student across school systems.';
comment on column core.students.id is
  'Canonical student_id used by Study Planner, Discipline, Computer Lab, Assessment, and future DICS apps.';
comment on column core.students.student_no is
  'School-wide human-facing student number. Stable cross-app lookup key.';
comment on column core.students.auth_user_id is
  'Optional login account. Student identity and authentication identity are intentionally separate.';
comment on column core.students.birth_date is
  'Core directory attribute. Do not copy into discipline-domain tables.';
comment on column core.students.gender is
  'Normalized directory value: M/F. Do not copy into discipline-domain tables.';

create index if not exists core_students_name_idx
  on core.students (name);

create index if not exists core_students_auth_user_idx
  on core.students (auth_user_id)
  where auth_user_id is not null;

create index if not exists core_students_active_idx
  on core.students (student_no)
  where is_active;

drop trigger if exists core_students_touch_updated_at on core.students;
create trigger core_students_touch_updated_at
  before update on core.students
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Academic structure: class placement belongs to a term, not to the student row
-- ---------------------------------------------------------------------------

create table if not exists core.academic_terms (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  starts_on date not null,
  ends_on date not null,
  is_current boolean not null default false,
  created_at timestamptz not null default now(),
  check (ends_on >= starts_on),
  check (char_length(btrim(code)) between 1 and 30),
  check (char_length(btrim(name)) between 1 and 80)
);

-- At most one current term across the school directory.
create unique index if not exists core_academic_terms_one_current_uq
  on core.academic_terms ((1))
  where is_current;

create table if not exists core.classes (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null references core.academic_terms(id) on delete cascade,
  grade smallint not null check (grade between 1 and 12),
  section text not null default '',
  label text not null,
  created_at timestamptz not null default now(),
  unique (term_id, grade, section),
  unique (id, term_id),
  check (char_length(label) between 1 and 40),
  check (char_length(section) <= 20)
);

comment on table core.classes is
  'Term-specific classes/homerooms. Example labels: G9-A, G9-B, G11.';

create table if not exists core.enrollments (
  student_id uuid not null references core.students(id) on delete cascade,
  term_id uuid not null references core.academic_terms(id) on delete cascade,
  class_id uuid not null,
  enrolled_at timestamptz not null default now(),
  left_at timestamptz,
  primary key (student_id, term_id),
  foreign key (class_id, term_id)
    references core.classes(id, term_id) on delete restrict,
  check (left_at is null or left_at >= enrolled_at)
);

create index if not exists core_enrollments_class_idx
  on core.enrollments (class_id, student_id);

-- ---------------------------------------------------------------------------
-- Core RLS
--
-- This repository currently knows Daniel's Scale admin identities through
-- public.admins. That is a transitional authorization source. When DICS Core
-- gains school-wide staff/role tables, these policies can switch to that shared
-- role service without changing the canonical student IDs.
-- ---------------------------------------------------------------------------

alter table core.students enable row level security;
alter table core.academic_terms enable row level security;
alter table core.classes enable row level security;
alter table core.enrollments enable row level security;

drop policy if exists core_students_read_self_or_discipline_admin on core.students;
create policy core_students_read_self_or_discipline_admin on core.students
  for select to authenticated
  using (
    auth_user_id = (select auth.uid())
    or private.current_admin_role() is not null
  );

drop policy if exists core_terms_read_authenticated on core.academic_terms;
create policy core_terms_read_authenticated on core.academic_terms
  for select to authenticated
  using (true);

drop policy if exists core_classes_read_authenticated on core.classes;
create policy core_classes_read_authenticated on core.classes
  for select to authenticated
  using (true);

drop policy if exists core_enrollments_read_self_or_discipline_admin on core.enrollments;
create policy core_enrollments_read_self_or_discipline_admin on core.enrollments
  for select to authenticated
  using (
    private.current_admin_role() is not null
    or student_id = (
      select s.id
      from core.students s
      where s.auth_user_id = (select auth.uid())
      limit 1
    )
  );

-- No INSERT/UPDATE/DELETE policies are created for authenticated users yet.
-- Roster provisioning is an administrative operation executed through trusted
-- migration/import tooling, not from a student browser.

grant usage on schema core to authenticated;
grant select on core.students, core.academic_terms, core.classes, core.enrollments
  to authenticated;

-- ---------------------------------------------------------------------------
-- Current-student projection
--
-- Public is used as the app-facing API schema. The underlying master remains in
-- core. The view intentionally exposes only what discipline operations need.
-- birth_date and gender are not projected here.
-- ---------------------------------------------------------------------------

create or replace view public.v_core_current_students
with (security_invoker = true) as
select
  s.id as student_id,
  s.student_no,
  s.name,
  c.grade::int as grade,
  c.label as homeroom,
  s.is_active
from core.students s
left join core.academic_terms t
  on t.is_current
left join core.enrollments e
  on e.student_id = s.id
 and e.term_id = t.id
 and e.left_at is null
left join core.classes c
  on c.id = e.class_id
where s.is_active;

comment on view public.v_core_current_students is
  'App-facing current student directory projection; intentionally excludes birth_date and gender.';

-- ---------------------------------------------------------------------------
-- Daniel's Scale legacy bridge
--
-- public.students was the original app-local master table and still owns the
-- integer FKs used by the current production point/reflection/punishment tables.
-- It is now deprecated as a source of truth. Each legacy row must be mapped to
-- exactly one core.students row before discipline-domain FK cut-over.
-- ---------------------------------------------------------------------------

-- Legacy table originally allowed only grades 1-6. During the bridge it must
-- represent G1-G12 records until all discipline foreign keys move to Core.
alter table public.students
  drop constraint if exists students_grade_check;

alter table public.students
  add constraint students_grade_check
  check (grade between 1 and 12);

alter table public.students
  add column if not exists core_student_id uuid
    references core.students(id) on delete restrict;

create unique index if not exists legacy_students_core_student_uq
  on public.students (core_student_id)
  where core_student_id is not null;

comment on table public.students is
  'LEGACY compatibility table for Daniel''s Scale. Canonical student data lives in core.students.';
comment on column public.students.core_student_id is
  'Temporary bridge to core.students during integrated-schema migration.';

-- Existing app pages may continue to use legacy integer IDs until the final
-- discipline cut-over. Once a row is mapped, name/grade/class come from Core.
create or replace view public.v_discipline_students
with (security_invoker = true) as
select
  ls.id as legacy_student_id,
  cs.student_id as core_student_id,
  cs.student_no,
  coalesce(cs.name, ls.name) as name,
  coalesce(cs.grade, ls.grade) as grade,
  cs.homeroom,
  (ls.deleted_at is null) as legacy_active
from public.students ls
left join public.v_core_current_students cs
  on cs.student_id = ls.core_student_id
where ls.deleted_at is null;

comment on view public.v_discipline_students is
  'Temporary Daniel''s Scale compatibility projection while integer legacy IDs are mapped to core UUID student IDs.';
