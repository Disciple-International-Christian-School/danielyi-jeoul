-- 2026-09-25
-- School-wide identity foundation for Daniel's Scale.
-- Real student_no / homeroom values are backfilled only in Supabase, never committed to git.

alter table public.students
  add column if not exists student_no text,
  add column if not exists homeroom text;

comment on column public.students.student_no is
  'School-wide student identifier used to link the same student across DICS systems. Real values are not stored in git.';
comment on column public.students.homeroom is
  'Operational class/section label such as 9-A. Real roster assignments are not stored in git.';

create unique index if not exists students_student_no_uq
  on public.students (student_no)
  where student_no is not null;

create index if not exists students_homeroom_idx
  on public.students (grade, homeroom)
  where deleted_at is null;

alter table public.students
  add constraint students_student_no_format
  check (
    student_no is null
    or (
      char_length(btrim(student_no)) between 1 and 20
      and student_no = btrim(student_no)
    )
  );

alter table public.students
  add constraint students_homeroom_format
  check (
    homeroom is null
    or (
      char_length(btrim(homeroom)) between 1 and 30
      and homeroom = btrim(homeroom)
    )
  );
