-- 2026-09-26
-- Move remaining read/operational joins from legacy integer student_id to
-- canonical core_student_id while preserving public column contracts.

create or replace view public.v_point_records
with (security_invoker = true) as
select
  pr.id,
  pr.student_id,
  s.name as student_name,
  pr.type,
  pr.item,
  pr.points,
  pr.recorded_at,
  pr.entered_by_name,
  pr.created_at,
  r.id as reflection_id,
  r.submitted as reflection_submitted,
  r.submission_deadline as reflection_deadline,
  r.submitted_at as reflection_submitted_at,
  case
    when r.id is null then null::text
    when r.submitted then 'SUBMITTED'
    when r.due_at < now() then 'DOUBLE'
    else 'MISSING'
  end as reflection_status,
  r.due_at as reflection_due_at,
  pr.core_student_id
from public.point_records pr
join public.students s
  on s.core_student_id = pr.core_student_id
left join public.reflection_records r
  on r.point_record_id = pr.id
where pr.deleted_at is null;

create or replace view public.v_punishments
with (security_invoker = true) as
select
  p.id,
  p.student_id,
  s.name as student_name,
  s.grade,
  p.types,
  p.start_date,
  p.end_date,
  p.entered_by_name,
  (p.violated_at is not null) as violated,
  p.created_at,
  p.core_student_id
from public.punishments p
join public.students s
  on s.core_student_id = p.core_student_id;

create or replace view public.v_reflections
with (security_invoker = true) as
select
  r.id,
  r.point_record_id,
  pr.student_id,
  s.name as student_name,
  s.grade,
  pr.item,
  pr.points,
  pr.recorded_at,
  r.submitted,
  r.submission_deadline,
  r.submitted_at,
  case
    when r.submitted then 'SUBMITTED'
    when r.due_at < now() then 'DOUBLE'
    else 'MISSING'
  end as status,
  r.due_at,
  r.deadline_change_reason,
  case
    when s.grade between 1 and 6 then 'ELEMENTARY'::public.discipline_scope
    when s.grade between 7 and 9 then 'MIDDLE'::public.discipline_scope
    else 'HIGH'::public.discipline_scope
  end as assigned_scope,
  pr.core_student_id
from public.reflection_records r
join public.point_records pr
  on pr.id = r.point_record_id
 and pr.deleted_at is null
join public.students s
  on s.core_student_id = pr.core_student_id;

create or replace view public.v_daily_discipline_notice
with (security_invoker = true) as
select
  pr.id as point_record_id,
  pr.recorded_at,
  ds.legacy_student_id as student_id,
  ds.core_student_id,
  ds.student_no,
  ds.name as student_name,
  ds.grade,
  ds.homeroom,
  pr.item,
  pr.points,
  r.id as reflection_id,
  r.submitted as reflection_submitted,
  r.due_at as reflection_due_at,
  case
    when r.id is null then null::text
    when r.submitted then 'SUBMITTED'
    when r.due_at < now() then 'DOUBLE'
    else 'MISSING'
  end as reflection_status
from public.point_records pr
join public.v_discipline_students ds
  on ds.core_student_id = pr.core_student_id
left join public.reflection_records r
  on r.point_record_id = pr.id
where pr.deleted_at is null
  and pr.type='NEGATIVE';

create or replace view public.v_dashboard_counts
with (security_invoker = true) as
select
  (select count(*)::int from public.v_student_summary) as students,
  (select count(*)::int from public.v_student_summary where physical_training_required) as weekly_targets,
  (select count(*)::int from public.v_reflections where status='MISSING') as missing_reflections,
  (select count(*)::int from public.v_reflections where status='DOUBLE') as double_reflections,
  (
    select count(distinct p.core_student_id)::int
    from public.punishments p
    where p.start_date <= private.kst_today()
      and p.end_date >= private.kst_today()
  ) as active_punishments,
  (select count(*)::int from public.v_student_summary where committee_required) as committee_targets;

create or replace function public.extend_reflection_to_21(
  p_reflection_id int,
  p_reason text
)
returns timestamptz
language plpgsql
set search_path = ''
as $$
declare
  v_grade int;
  v_recorded_at date;
  v_submitted boolean;
  v_target timestamptz;
begin
  if private.current_admin_role() <> 'SEONDO' then
    raise exception '선도부 관리자만 반성문 마감을 변경할 수 있습니다.';
  end if;

  select s.grade, pr.recorded_at, r.submitted
  into v_grade, v_recorded_at, v_submitted
  from public.reflection_records r
  join public.point_records pr
    on pr.id = r.point_record_id
  join public.students s
    on s.core_student_id = pr.core_student_id
  where r.id = p_reflection_id;

  if v_grade is null then
    raise exception '반성문 기록을 찾을 수 없습니다.';
  end if;

  if v_grade between 1 and 6 then
    raise exception '초등부 반성문은 익일 등교 제출 규칙을 사용합니다.';
  end if;

  if v_submitted then
    raise exception '이미 제출된 반성문입니다.';
  end if;

  v_target := (v_recorded_at + time '21:00') at time zone 'Asia/Seoul';

  update public.reflection_records
  set due_at = v_target,
      deadline_changed_by = auth.uid(),
      deadline_change_reason = nullif(btrim(p_reason), '')
  where id = p_reflection_id;

  return v_target;
end;
$$;

grant execute on function public.extend_reflection_to_21(int, text) to authenticated;
