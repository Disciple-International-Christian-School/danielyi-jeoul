-- 2026-09-27
-- Decouple public read contracts from physical legacy discipline student_id columns.
-- Compatibility student_id values are now derived from canonical Core UUID.

create or replace view public.v_point_records
with (security_invoker = true) as
select
  pr.id,
  s.id as student_id,
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
  s.id as student_id,
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
  s.id as student_id,
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

comment on view public.v_point_records is
  'Core UUID-backed point history. student_id is a derived legacy compatibility value.';
comment on view public.v_punishments is
  'Core UUID-backed punishment history. student_id is a derived legacy compatibility value.';
comment on view public.v_reflections is
  'Core UUID-backed reflection workflow. student_id is a derived legacy compatibility value.';
