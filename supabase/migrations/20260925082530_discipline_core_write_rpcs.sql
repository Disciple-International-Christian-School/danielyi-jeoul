-- 2026-09-25
-- Canonical Core UUID write entrypoints.
--
-- Existing business-rule RPCs remain the single implementation of discipline
-- rules. These wrappers resolve canonical Core UUID -> legacy student integer
-- only for the transition period.

create or replace function public.create_point_record_core(
  p_core_student_id uuid,
  p_type public.point_type,
  p_item text,
  p_points int,
  p_entered_by_name text,
  p_recorded_at date,
  p_reflection_submitted boolean default false
)
returns int
language plpgsql
set search_path = ''
as $$
declare
  v_legacy_student_id int;
begin
  select s.id
  into v_legacy_student_id
  from public.students s
  where s.core_student_id = p_core_student_id
    and s.deleted_at is null;

  if v_legacy_student_id is null then
    raise exception 'Core 학생에 연결된 생활지도 학생 행을 찾을 수 없습니다.';
  end if;

  return public.create_point_record(
    v_legacy_student_id,
    p_type,
    p_item,
    p_points,
    p_entered_by_name,
    p_recorded_at,
    p_reflection_submitted
  );
end;
$$;

create or replace function public.create_punishment_core(
  p_core_student_id uuid,
  p_types text[],
  p_start_date date,
  p_end_date date,
  p_entered_by_name text
)
returns int
language plpgsql
set search_path = ''
as $$
declare
  v_legacy_student_id int;
begin
  select s.id
  into v_legacy_student_id
  from public.students s
  where s.core_student_id = p_core_student_id
    and s.deleted_at is null;

  if v_legacy_student_id is null then
    raise exception 'Core 학생에 연결된 생활지도 학생 행을 찾을 수 없습니다.';
  end if;

  return public.create_punishment(
    v_legacy_student_id,
    p_types,
    p_start_date,
    p_end_date,
    p_entered_by_name
  );
end;
$$;

comment on function public.create_point_record_core(uuid, public.point_type, text, int, text, date, boolean) is
  'Canonical Core UUID write entrypoint. Delegates discipline validation to create_point_record during legacy transition.';

comment on function public.create_punishment_core(uuid, text[], date, date, text) is
  'Canonical Core UUID write entrypoint. Delegates punishment validation to create_punishment during legacy transition.';

revoke all on function public.create_point_record_core(uuid, public.point_type, text, int, text, date, boolean)
  from public, anon;
grant execute on function public.create_point_record_core(uuid, public.point_type, text, int, text, date, boolean)
  to authenticated;

revoke all on function public.create_punishment_core(uuid, text[], date, date, text)
  from public, anon;
grant execute on function public.create_punishment_core(uuid, text[], date, date, text)
  to authenticated;
