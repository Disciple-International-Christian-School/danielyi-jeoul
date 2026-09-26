-- 2026-09-26
-- Promote the Core-UUID student summary while preserving the exact prior
-- implementation as a legacy shadow for ongoing parity verification.

do $$
declare
  v_definition text;
begin
  select pg_get_viewdef('public.v_student_summary'::regclass, true)
  into v_definition;

  execute
    'create or replace view public.v_student_summary_legacy_shadow '
    || 'with (security_invoker = true) as '
    || v_definition;
end $$;

create or replace view public.v_student_summary
with (security_invoker = true) as
select
  id,
  name,
  grade,
  created_at,
  updated_at,
  positive_points,
  negative_points,
  weekly_penalty_points,
  monthly_penalty_points,
  weekly_record_count,
  punishment,
  statuses,
  core_student_id,
  student_no,
  homeroom,
  weekly_positive_points,
  weekly_net_penalty_points,
  physical_training_required,
  settlement_period_id,
  settlement_period_label,
  settlement_starts_on,
  settlement_positive_points,
  settlement_penalty_points,
  settlement_net_penalty_points,
  physical_training_weeks,
  committee_required
from public.v_student_summary_core_shadow;

create or replace view public.v_student_summary_core_parity
with (security_invoker = true) as
with compared as (
  select
    coalesce(l.id, c.id) as student_id,
    (
      l.id is null
      or c.id is null
      or l.name is distinct from c.name
      or l.grade is distinct from c.grade
      or l.positive_points is distinct from c.positive_points
      or l.negative_points is distinct from c.negative_points
      or l.weekly_penalty_points is distinct from c.weekly_penalty_points
      or l.monthly_penalty_points is distinct from c.monthly_penalty_points
      or l.weekly_record_count is distinct from c.weekly_record_count
      or l.punishment is distinct from c.punishment
      or l.statuses is distinct from c.statuses
      or l.core_student_id is distinct from c.core_student_id
      or l.student_no is distinct from c.student_no
      or l.homeroom is distinct from c.homeroom
      or l.weekly_positive_points is distinct from c.weekly_positive_points
      or l.weekly_net_penalty_points is distinct from c.weekly_net_penalty_points
      or l.physical_training_required is distinct from c.physical_training_required
      or l.settlement_period_id is distinct from c.settlement_period_id
      or l.settlement_positive_points is distinct from c.settlement_positive_points
      or l.settlement_penalty_points is distinct from c.settlement_penalty_points
      or l.settlement_net_penalty_points is distinct from c.settlement_net_penalty_points
      or l.physical_training_weeks is distinct from c.physical_training_weeks
      or l.committee_required is distinct from c.committee_required
    ) as mismatch
  from public.v_student_summary_legacy_shadow l
  full join public.v_student_summary c
    on c.id=l.id
)
select
  (select count(*)::int from public.v_student_summary_legacy_shadow) as legacy_rows,
  (select count(*)::int from public.v_student_summary) as core_rows,
  (select count(*)::int from compared where mismatch) as mismatches;

grant select on public.v_student_summary_legacy_shadow to authenticated;
