-- 2026-09-27
-- public.students is a legacy compatibility bridge only.
-- Browser clients must not create or mutate student master rows.
-- Canonical student provisioning belongs to DICS Core.

drop policy if exists students_write on public.students;
drop policy if exists students_update on public.students;

revoke all privileges on table public.students from anon;
revoke insert, update, delete, truncate, references, trigger
  on table public.students
  from authenticated;

grant select on table public.students to authenticated;

revoke all privileges on sequence public.students_id_seq from anon;
revoke all privileges on sequence public.students_id_seq from authenticated;

comment on table public.students is
  'LEGACY READ-ONLY compatibility bridge for Daniel''s Scale. Canonical student provisioning and master data live in core.students.';
