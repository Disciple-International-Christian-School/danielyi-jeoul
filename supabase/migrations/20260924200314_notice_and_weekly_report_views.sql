-- 2026-09-25
-- Print/report projections for daily class notices and weekly discipline review.
-- Views are read-only, security-invoker, and expose only the fields required by
-- the discipline workflow.

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
    when r.id is null then null
    when r.submitted then 'SUBMITTED'
    when r.due_at < now() then 'DOUBLE'
    else 'MISSING'
  end as reflection_status
from public.point_records pr
join public.v_discipline_students ds
  on ds.legacy_student_id = pr.student_id
left join public.reflection_records r
  on r.point_record_id = pr.id
where pr.deleted_at is null
  and pr.type = 'NEGATIVE';

comment on view public.v_daily_discipline_notice is
  'Daily class-notice rows for penalty/reflection communication and printing.';

create or replace view public.v_weekly_discipline_report
with (security_invoker = true) as
select
  private.kst_week_start() as week_start,
  s.id as student_id,
  s.core_student_id,
  s.student_no,
  s.name as student_name,
  s.grade,
  s.homeroom,
  s.weekly_positive_points,
  s.weekly_penalty_points,
  s.weekly_net_penalty_points,
  s.weekly_record_count as penalty_incident_count,
  s.physical_training_required,
  s.settlement_period_id,
  s.settlement_period_label,
  s.settlement_starts_on,
  s.settlement_positive_points,
  s.settlement_penalty_points,
  s.settlement_net_penalty_points,
  s.physical_training_weeks,
  s.committee_required,
  s.statuses
from public.v_student_summary s;

comment on view public.v_weekly_discipline_report is
  'Current-week and open-settlement report projection used for weekend review and printing.';
