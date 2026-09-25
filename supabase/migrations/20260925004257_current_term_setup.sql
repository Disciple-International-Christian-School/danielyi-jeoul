-- 2026-09-25
-- Current academic-term provisioning for DICS Core.
--
-- The workflow deliberately does NOT guess G9-A / G9-B membership.
-- Non-G9 active students can be enrolled from the already verified legacy
-- grade field; G9 remains pending until an authorized lead assigns A/B.

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

  -- Standard single-section classes for every grade except G9.
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

  -- G9 is explicitly split.
  insert into core.classes (term_id, grade, section, label)
  values
    (v_term_id, 9, 'A', 'G9-A'),
    (v_term_id, 9, 'B', 'G9-B')
  on conflict (term_id, grade, section) do nothing;

  v_classes_created := v_classes_created + row_count;

  -- Existing verified grade values are sufficient for non-G9 placement.
  -- G9 is intentionally excluded until section data is confirmed.
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
  v_term_id uuid;
  v_core_student_id uuid;
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

  select core_student_id
  into v_core_student_id
  from public.students
  where id = p_student_id
    and deleted_at is null
    and grade = 9;

  if v_core_student_id is null then
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
    student_id, term_id, class_id, enrolled_at, left_at
  )
  values (
    v_core_student_id,
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

create or replace view public.v_core_setup_status
with (security_invoker = true) as
with current_term as (
  select *
  from core.academic_terms
  where is_current
  limit 1
)
select
  t.id as term_id,
  t.code as term_code,
  t.name as term_name,
  t.starts_on,
  t.ends_on,
  (select count(*)::int from core.classes c where c.term_id = t.id) as class_count,
  (select count(*)::int from core.enrollments e where e.term_id = t.id and e.left_at is null) as enrollment_count,
  (
    select count(*)::int
    from public.students s
    where s.deleted_at is null and s.grade = 9
  ) as grade9_total,
  (
    select count(*)::int
    from public.students s
    join core.enrollments e
      on e.student_id = s.core_student_id
     and e.term_id = t.id
     and e.left_at is null
    join core.classes c
      on c.id = e.class_id
     and c.grade = 9
    where s.deleted_at is null and s.grade = 9
  ) as grade9_assigned,
  (
    select count(*)::int
    from public.students s
    where s.deleted_at is null
      and s.grade = 9
      and not exists (
        select 1
        from core.enrollments e
        where e.student_id = s.core_student_id
          and e.term_id = t.id
          and e.left_at is null
      )
  ) as grade9_pending
from current_term t;

create or replace view public.v_grade9_current_assignments
with (security_invoker = true) as
select
  s.id as student_id,
  s.core_student_id,
  s.name as student_name,
  s.grade,
  c.section,
  c.label as homeroom
from public.students s
join core.academic_terms t
  on t.is_current
left join core.enrollments e
  on e.student_id = s.core_student_id
 and e.term_id = t.id
 and e.left_at is null
left join core.classes c
  on c.id = e.class_id
where s.deleted_at is null
  and s.grade = 9
order by s.name;

grant execute on function public.initialize_current_academic_term(text, text, date, date) to authenticated;
grant execute on function public.assign_current_grade9_section(int, text) to authenticated;
grant select on public.v_core_setup_status, public.v_grade9_current_assignments to authenticated;
