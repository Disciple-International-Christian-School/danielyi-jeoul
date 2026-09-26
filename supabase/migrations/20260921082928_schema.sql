-- daniels-scale: core schema
-- Ported from the Replit Drizzle schema (danielyi-jeoul/lib/db/src/schema),
-- with FKs added and admins keyed to auth.users.

create schema if not exists private;

create type public.point_type as enum ('POSITIVE', 'NEGATIVE');
create type public.admin_role as enum ('SEONDO', 'SASAENG');

-- shared updated_at stamper
create or replace function private.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------- admins
create table public.admins (
  id serial primary key,
  user_id uuid not null unique references auth.users (id) on delete cascade,
  display_name text not null default '관리자',
  role public.admin_role not null default 'SEONDO',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger admins_touch_updated_at
  before update on public.admins
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------- students
-- Spec §4: name + grade only. Never add PII columns.
create table public.students (
  id serial primary key,
  name text not null check (char_length(name) between 1 and 40),
  grade int not null check (grade between 1 and 6),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index students_name_idx on public.students (name);
create index students_grade_idx on public.students (grade);

create trigger students_touch_updated_at
  before update on public.students
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------- point_items
create table public.point_items (
  id serial primary key,
  name text not null check (char_length(name) between 1 and 80),
  type public.point_type not null,
  fixed_points int check (fixed_points between 0 and 100),
  is_fixed boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger point_items_touch_updated_at
  before update on public.point_items
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------- point_records
-- `item` is a text snapshot (not an FK) so renaming/deactivating an item never
-- rewrites history. `entered_by_name` is typed manually by the admin (spec §6);
-- never auto-filled from the session.
create table public.point_records (
  id serial primary key,
  student_id int not null references public.students (id),
  type public.point_type not null,
  item text not null check (char_length(item) between 1 and 80),
  points int not null check (points between 1 and 100),
  entered_by_name text not null check (char_length(entered_by_name) between 1 and 40),
  recorded_at date not null,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index point_records_student_idx on public.point_records (student_id);
create index point_records_date_idx on public.point_records (recorded_at);

create trigger point_records_touch_updated_at
  before update on public.point_records
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------- reflection_records
-- One reflection per NEGATIVE point record; created by trigger (see logic
-- migration). Deadline = the penalty entry day (spec §10). "2배 제출 대상" is
-- derived at read time, never stored, so it flips at midnight without a job.
create table public.reflection_records (
  id serial primary key,
  point_record_id int not null unique references public.point_records (id) on delete cascade,
  submitted boolean not null default false,
  submitted_at timestamptz,
  submission_deadline date not null
);

-- ---------------------------------------------------------------- punishments
-- violated_at null = no violation recorded. Violation => 귀가금지 status (derived).
create table public.punishments (
  id serial primary key,
  student_id int not null references public.students (id),
  types text[] not null check (array_length(types, 1) between 1 and 2),
  start_date date not null,
  end_date date not null,
  entered_by_name text not null check (char_length(entered_by_name) between 1 and 40),
  violated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date >= start_date)
);

create index punishments_student_dates_idx on public.punishments (student_id, start_date, end_date);

create trigger punishments_touch_updated_at
  before update on public.punishments
  for each row execute function private.touch_updated_at();
