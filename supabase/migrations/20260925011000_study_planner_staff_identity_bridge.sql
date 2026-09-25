-- 2026-09-25
-- Correct Study Planner staff identity before any live SP data is migrated.
--
-- Existing SP staff IDs belong to the legacy SP Supabase Auth namespace.
-- They must not be treated as foreign keys to DICS Core auth.users.
--
-- Target:
--   study_planner.staff.id           = domain/canonical staff profile UUID
--   study_planner.staff.auth_user_id = optional LOCAL DICS Core Auth UUID
--   study_planner.external_staff_identities = legacy/external auth mapping

do $$
begin
  if exists (select 1 from study_planner.staff limit 1)
     or exists (select 1 from study_planner.teacher_comments limit 1) then
    raise exception 'Study Planner target already contains staff/comment data. Review mapping before changing staff identity semantics.';
  end if;
end $$;

alter table study_planner.staff
  drop constraint if exists staff_id_fkey;

alter table study_planner.staff
  alter column id set default gen_random_uuid();

alter table study_planner.staff
  add column if not exists auth_user_id uuid unique
    references auth.users(id) on delete set null;

comment on column study_planner.staff.id is
  'Study Planner staff profile UUID. Independent from any Auth provider/project.';
comment on column study_planner.staff.auth_user_id is
  'Optional DICS Core LOCAL Auth account. External SP Auth UUIDs must not be stored here.';

create table if not exists study_planner.external_staff_identities (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references study_planner.staff(id) on delete cascade,
  source_system text not null,
  source_project_ref text,
  external_user_id text not null,
  external_login_id text,
  is_active boolean not null default true,
  linked_at timestamptz not null default now(),
  last_verified_at timestamptz,
  unique (source_system, external_user_id),
  unique (source_system, staff_id),
  check (char_length(btrim(source_system)) between 1 and 80),
  check (char_length(btrim(external_user_id)) between 1 and 200)
);

create index if not exists study_planner_external_staff_staff_idx
  on study_planner.external_staff_identities (staff_id);

comment on table study_planner.external_staff_identities is
  'Maps Study Planner staff profiles to legacy/external Auth identities from other projects. Never stores passwords/PINs.';

alter table study_planner.external_staff_identities enable row level security;

-- Shadow target remains default-deny until the SP frontend cut-over.
revoke all on study_planner.external_staff_identities
  from public, anon, authenticated;

create or replace view public.v_study_planner_target_readiness
with (security_invoker = true) as
select
  (select count(*)::int from study_planner.staff) as staff_profiles,
  (select count(*)::int from study_planner.staff where auth_user_id is not null) as local_staff_auth_linked,
  (select count(*)::int from study_planner.external_staff_identities where is_active) as external_staff_auth_linked,
  (select count(*)::int from study_planner.week_plans) as week_plans,
  (select count(*)::int from study_planner.teacher_comments) as teacher_comments;

comment on view public.v_study_planner_target_readiness is
  'Aggregate readiness for the empty Core Study Planner target; contains no PII.';

grant select on public.v_study_planner_target_readiness to authenticated;
