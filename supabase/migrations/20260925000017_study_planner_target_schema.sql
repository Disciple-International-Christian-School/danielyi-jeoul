-- 2026-09-25
-- DICS Core target schema for Study Planner.
--
-- This is a SHADOW TARGET only.
-- No live SP student data is copied by this migration.
-- The existing SP deployment remains operational in its own Supabase project.
--
-- Integration principles:
-- - student_id always references core.students(id)
-- - academic term comes from core.academic_terms
-- - auth.users remains login identity, not student identity
-- - existing SP UUID primary keys can be preserved during later migration

create schema if not exists study_planner;

-- ---------------------------------------------------------------------------
-- Staff is transitional and auth-backed.
-- A school-wide staff directory can replace this later without changing
-- canonical student identity.
-- ---------------------------------------------------------------------------

create table if not exists study_planner.staff (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  role text not null default 'teacher'
    check (role in ('teacher', 'admin')),
  grades smallint[] not null default '{}',
  created_at timestamptz not null default now()
);

comment on table study_planner.staff is
  'Transitional Study Planner staff profile keyed by Auth UUID. Student identity is handled separately by core.students.';

-- ---------------------------------------------------------------------------
-- Academic time model
-- ---------------------------------------------------------------------------

create table if not exists study_planner.weeks (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null references core.academic_terms(id) on delete cascade,
  week_no smallint not null,
  monday date not null unique,
  plan_due_at timestamptz not null,
  unique (term_id, week_no)
);

comment on column study_planner.weeks.plan_due_at is
  'Next-week planning deadline. Existing SP behavior can be migrated without duplicating the term master.';

create table if not exists study_planner.time_blocks (
  id uuid primary key default gen_random_uuid(),
  day_type text not null check (day_type in ('weekday', 'sat', 'sun')),
  seq smallint not null,
  label text not null,
  starts_at time not null,
  ends_at time not null,
  is_study boolean not null default true,
  unique (day_type, seq),
  check (ends_at > starts_at)
);

create table if not exists study_planner.entry_windows (
  code text primary key,
  label text not null,
  weekday smallint not null check (weekday between 1 and 7),
  covers text not null,
  max_lag_days smallint not null check (max_lag_days >= 0),
  sort smallint not null
);

create table if not exists study_planner.subject_tags (
  code text primary key,
  label_ko text not null,
  label_en text not null,
  color text not null,
  sort smallint not null
);

-- ---------------------------------------------------------------------------
-- Student goals and weekly planning
-- ---------------------------------------------------------------------------

create table if not exists study_planner.term_goals (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references core.students(id) on delete cascade,
  term_id uuid not null references core.academic_terms(id) on delete cascade,
  seq smallint not null check (seq between 1 and 3),
  body text not null,
  unique (student_id, term_id, seq)
);

create table if not exists study_planner.week_plans (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references core.students(id) on delete cascade,
  week_id uuid not null references study_planner.weeks(id) on delete cascade,
  status text not null default 'draft'
    check (status in ('draft', 'submitted', 'late')),
  submitted_at timestamptz,
  retro_kept text,
  retro_blocked text,
  retro_change text,
  comment_ack text,
  created_at timestamptz not null default now(),
  unique (student_id, week_id)
);

create table if not exists study_planner.week_goals (
  id uuid primary key default gen_random_uuid(),
  week_plan_id uuid not null references study_planner.week_plans(id) on delete cascade,
  seq smallint not null check (seq between 1 and 3),
  body text not null,
  term_goal_id uuid references study_planner.term_goals(id) on delete set null,
  unique (week_plan_id, seq)
);

create table if not exists study_planner.plan_items (
  id uuid primary key default gen_random_uuid(),
  week_plan_id uuid not null references study_planner.week_plans(id) on delete cascade,
  on_date date not null,
  time_block_id uuid not null references study_planner.time_blocks(id),
  subject_tag text not null references study_planner.subject_tags(code),
  title text not null,
  done_criteria text,
  est_minutes smallint check (est_minutes between 5 and 300),
  seq smallint not null default 1
);

-- ---------------------------------------------------------------------------
-- Execution records
-- ---------------------------------------------------------------------------

create table if not exists study_planner.item_records (
  plan_item_id uuid primary key references study_planner.plan_items(id) on delete cascade,
  status text not null check (status in ('done', 'partial', 'skipped')),
  actual_minutes smallint check (actual_minutes between 0 and 300),
  from_card boolean not null default false,
  window_code text references study_planner.entry_windows(code),
  recorded_at timestamptz not null default now()
);

create table if not exists study_planner.block_records (
  week_plan_id uuid not null references study_planner.week_plans(id) on delete cascade,
  on_date date not null,
  time_block_id uuid not null references study_planner.time_blocks(id),
  utilization text not null check (utilization in ('full', 'half', 'none')),
  window_code text references study_planner.entry_windows(code),
  recorded_at timestamptz not null default now(),
  primary key (week_plan_id, on_date, time_block_id)
);

-- ---------------------------------------------------------------------------
-- Supporting data
-- ---------------------------------------------------------------------------

create table if not exists study_planner.task_templates (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references core.students(id) on delete cascade,
  subject_tag text not null references study_planner.subject_tags(code),
  pattern text not null,
  est_minutes smallint,
  sort smallint not null default 1
);

create table if not exists study_planner.teacher_comments (
  week_plan_id uuid primary key references study_planner.week_plans(id) on delete cascade,
  staff_id uuid not null references study_planner.staff(id),
  body text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

create index if not exists study_planner_week_plans_week_idx
  on study_planner.week_plans (week_id, status);

create index if not exists study_planner_week_plans_student_idx
  on study_planner.week_plans (student_id);

create index if not exists study_planner_plan_items_plan_idx
  on study_planner.plan_items (week_plan_id);

create index if not exists study_planner_plan_items_date_idx
  on study_planner.plan_items (on_date);

create index if not exists study_planner_week_goals_plan_idx
  on study_planner.week_goals (week_plan_id);

create index if not exists study_planner_block_records_plan_idx
  on study_planner.block_records (week_plan_id);

create index if not exists study_planner_term_goals_student_idx
  on study_planner.term_goals (student_id, term_id);

-- ---------------------------------------------------------------------------
-- RLS foundation
--
-- No frontend is cut over yet. Enable RLS now so empty target tables are not
-- accidentally exposed when APIs are later introduced.
-- ---------------------------------------------------------------------------

alter table study_planner.staff enable row level security;
alter table study_planner.weeks enable row level security;
alter table study_planner.time_blocks enable row level security;
alter table study_planner.entry_windows enable row level security;
alter table study_planner.subject_tags enable row level security;
alter table study_planner.term_goals enable row level security;
alter table study_planner.week_plans enable row level security;
alter table study_planner.week_goals enable row level security;
alter table study_planner.plan_items enable row level security;
alter table study_planner.item_records enable row level security;
alter table study_planner.block_records enable row level security;
alter table study_planner.task_templates enable row level security;
alter table study_planner.teacher_comments enable row level security;

comment on schema study_planner is
  'DICS Core target domain for Study Planner. Existing SP live data remains in the legacy project until verified mapping and migration.';
