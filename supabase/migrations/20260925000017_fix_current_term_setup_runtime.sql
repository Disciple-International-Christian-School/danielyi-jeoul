-- 2026-09-25
-- Runtime correction for initialize_current_academic_term().
--
-- Migration 16 compiled successfully but attempted to use ROW_COUNT as if it
-- were a PL/pgSQL variable after the G9 class INSERT. ROW_COUNT must be read
-- through GET DIAGNOSTICS. The failed production invocation rolled back fully,
-- so no term/class/enrollment data was partially written.

create or replace function public.initialize_current_academic_term(
  p_code text,
  p_name text,
  p_starts_on date,
  p_ends_on date
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_term_id uuid;
  v_existing_current uuid;
  v_classes_created int := 0;
  v_grade9_classes_created int := 0;
  v_enrollments_created int := 0;
  v_grade9_pending int := 0;
begin
  if not private.current_admin_is_lead() then
    raise exception '선도부장 권한이 필요합니다.';
  end if;

  if nullif(btrim(p_code), '') is null or nullif(btrim(p_name), '') is null then
    raise exception '학기 코드와 이름을 입력해주세요.';
  end if;

  if p_ends_on < p_starts_on then
    raise exception '학기 종료일은 시작일 이후여야 합니다.';
  end if;

  select id into v_existing_current
  from core.academic_terms
  where is_current
  limit 1;

  if v_existing_current is not null then
    select id into v_term_id
    from core.academic_terms
    where id = v_existing_current
      and code = btrim(p_code);

    if v_term_id is null then
      raise exception '이미 다른 현재 학기가 설정되어 있습니다.';
    end if;
  else
    select id into v_term_id
    from core.academic_terms
    where code = btrim(p_code)
    limit 1;

    if v_term_id is null then
      insert into core.academic_terms (
        code, name, starts_on, ends_on, is_current
      )
      values (
        btrim(p_code), btrim(p_name), p_starts_on, p_ends_on, true
      )
      returning id into v_term_id;
    else
      update core.academic_terms
      set name = btrim(p_name),
          starts_on = p_starts_on,
          ends_on = p_ends_on,
          is_current = true
      where id = v_term_id;
    end if;
  end if;

  insert into core.classes (term_id, grade, section, label)
  select
    v_term_id,
    g::smallint,
    '',
    'G' || g::text
  from generate_series(1, 12) g
  where g <> 9
  on conflict (term_id, grade, section) do nothing;

  get diagnostics v_classes_created = row_count;

  insert into core.classes (term_id, grade, section, label)
  values
    (v_term_id, 9, 'A', 'G9-A'),
    (v_term_id, 9, 'B', 'G9-B')
  on conflict (term_id, grade, section) do nothing;

  get diagnostics v_grade9_classes_created = row_count;
  v_classes_created := v_classes_created + v_grade9_classes_created;

  insert into core.enrollments (
    student_id,
    term_id,
    class_id,
    enrolled_at
  )
  select
    ls.core_student_id,
    v_term_id,
    c.id,
    (p_starts_on::timestamp at time zone 'Asia/Seoul')
  from public.students ls
  join core.classes c
    on c.term_id = v_term_id
   and c.grade = ls.grade
   and c.section = ''
  where ls.deleted_at is null
    and ls.core_student_id is not null
    and ls.grade <> 9
  on conflict (student_id, term_id) do nothing;

  get diagnostics v_enrollments_created = row_count;

  select count(*)::int into v_grade9_pending
  from public.students ls
  where ls.deleted_at is null
    and ls.grade = 9
    and ls.core_student_id is not null
    and not exists (
      select 1
      from core.enrollments e
      where e.student_id = ls.core_student_id
        and e.term_id = v_term_id
        and e.left_at is null
    );

  return jsonb_build_object(
    'term_id', v_term_id,
    'classes_created', v_classes_created,
    'enrollments_created', v_enrollments_created,
    'grade9_pending', v_grade9_pending
  );
end;
$$;

grant execute on function public.initialize_current_academic_term(text, text, date, date) to authenticated;
