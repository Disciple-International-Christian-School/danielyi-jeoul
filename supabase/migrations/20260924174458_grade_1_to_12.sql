-- DICS rosters use grades 1–12 (G1–G12). The original check (1–6) came from
-- the spec draft and rejects most enrolled students.

alter table public.students drop constraint students_grade_check;
alter table public.students
  add constraint students_grade_check check (grade between 1 and 12);
