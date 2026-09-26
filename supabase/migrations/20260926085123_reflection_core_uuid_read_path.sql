-- 2026-09-26
-- Canonical Core UUID read-path expansion.
--
-- Preserve existing view column order and append canonical identity so older
-- clients remain compatible during the route/read migration.

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
  on s.id = pr.student_id;

comment on view public.v_reflections is
  'Operational reflection projection. Legacy integer student_id remains for compatibility; core_student_id is canonical.';

grant select on public.v_reflections to authenticated;
