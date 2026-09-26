-- 2026-09-27
-- Make Core UUID the authoritative identity for G9 section assignment.
-- The legacy integer RPC remains as a compatibility wrapper only.

create or replace function public.assign_current_grade9_section_core(
  p_core_student_id uuid,
  p_section text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_term_id uuid;
  v_class_id uuid;
  v_section text := upper(btrim(p_section));
  v_term_start date;
begin
  if not private.current_admin_is_lead() then
    raise exception '선도부장 권한이 필요합니다.';
  end if;

  if v_section not in ('A', 'B') then
    raise exception 'G9 분반은 A 또는 B만 가능합니다.';
  end if;

  select id, starts_on
  into v_term_id, v_term_start
  from core.academic_terms
  where is_current
  limit 1;

  if v_term_id is null then
    raise exception '현재 학기를 먼저 설정해주세요.';
  end if;

  if not exists (
    select 1
    from public.students s
    where s.core_student_id = p_core_student_id
      and s.deleted_at is null
      and s.grade = 9
  ) then
    raise exception '활성 G9 학생을 찾을 수 없습니다.';
  end if;

  select id
  into v_class_id
  from core.classes
  where term_id = v_term_id
    and grade = 9
    and section = v_section
  limit 1;

  if v_class_id is null then
    raise exception '현재 학기의 G9-% 반을 찾을 수 없습니다.', v_section;
  end if;

  insert into core.enrollments (
    student_id,
    term_id,
    class_id,
    enrolled_at,
    left_at
  )
  values (
    p_core_student_id,
    v_term_id,
    v_class_id,
    (v_term_start::timestamp at time zone 'Asia/Seoul'),
    null
  )
  on conflict (student_id, term_id)
  do update set
    class_id = excluded.class_id,
    left_at = null;
end;
$$;

create or replace function public.assign_current_grade9_section(
  p_student_id int,
  p_section text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_core_student_id uuid;
begin
  select s.core_student_id
  into v_core_student_id
  from public.students s
  where s.id = p_student_id
    and s.deleted_at is null
    and s.grade = 9;

  if v_core_student_id is null then
    raise exception '활성 G9 학생을 찾을 수 없습니다.';
  end if;

  perform public.assign_current_grade9_section_core(
    v_core_student_id,
    p_section
  );
end;
$$;

comment on function public.assign_current_grade9_section_core(uuid, text) is
  'Authoritative G9 section assignment using canonical core.students.id.';
comment on function public.assign_current_grade9_section(int, text) is
  'Legacy compatibility wrapper resolving public.students.id to canonical Core UUID.';

revoke all on function public.assign_current_grade9_section_core(uuid, text)
  from public, anon;
grant execute on function public.assign_current_grade9_section_core(uuid, text)
  to authenticated;

revoke all on function public.assign_current_grade9_section(int, text)
  from public, anon;
grant execute on function public.assign_current_grade9_section(int, text)
  to authenticated;
