-- 2026-09-26
-- Shadow Core-UUID score calculations for parity validation before replacing
-- the legacy integer-key scoring views.

create or replace view public.v_weekly_scores_core_shadow
with (security_invoker = true) as
select
  s.id as student_id,
  pr.core_student_id,
  (date_trunc('week', pr.recorded_at::timestamp without time zone))::date as week_start,
  coalesce(sum(pr.points) filter (where pr.type='POSITIVE'), 0)::int as positive_points,
  coalesce(sum(pr.points) filter (where pr.type='NEGATIVE'), 0)::int as negative_points,
  (
    coalesce(sum(pr.points) filter (where pr.type='NEGATIVE'), 0)
    - coalesce(sum(pr.points) filter (where pr.type='POSITIVE'), 0)
  )::int as net_penalty_points,
  coalesce(count(*) filter (where pr.type='NEGATIVE'), 0)::int as penalty_incident_count,
  (
    coalesce(count(*) filter (where pr.type='NEGATIVE'), 0) >= 3
    or (
      coalesce(sum(pr.points) filter (where pr.type='NEGATIVE'), 0)
      - coalesce(sum(pr.points) filter (where pr.type='POSITIVE'), 0)
    ) >= 8
  ) as physical_training_required
from public.point_records pr
join public.students s
  on s.core_student_id = pr.core_student_id
where pr.deleted_at is null
group by
  s.id,
  pr.core_student_id,
  (date_trunc('week', pr.recorded_at::timestamp without time zone))::date;

create or replace view public.v_weekly_penalties_core_shadow
with (security_invoker = true) as
select
  s.id as student_id,
  pr.core_student_id,
  (date_trunc('week', pr.recorded_at::timestamp without time zone))::date as week_start,
  sum(pr.points)::int as penalty_points,
  count(*)::int as record_count
from public.point_records pr
join public.students s
  on s.core_student_id = pr.core_student_id
where pr.type='NEGATIVE'
  and pr.deleted_at is null
group by
  s.id,
  pr.core_student_id,
  (date_trunc('week', pr.recorded_at::timestamp without time zone))::date;

create or replace view public.v_settlement_scores_core_shadow
with (security_invoker = true) as
with period_students as (
  select
    sp.id as period_id,
    sp.label as period_label,
    sp.starts_on,
    coalesce(sp.ends_on, private.kst_today()) as effective_end,
    sp.ends_on,
    ds.legacy_student_id as student_id,
    ds.core_student_id,
    ds.student_no,
    ds.name as student_name,
    ds.grade,
    ds.homeroom
  from public.settlement_periods sp
  cross join public.v_discipline_students ds
),
period_totals as (
  select
    ps.period_id,
    ps.core_student_id,
    coalesce(sum(pr.points) filter (where pr.type='POSITIVE'), 0)::int as positive_points,
    coalesce(sum(pr.points) filter (where pr.type='NEGATIVE'), 0)::int as negative_points
  from period_students ps
  left join public.point_records pr
    on pr.core_student_id = ps.core_student_id
   and pr.deleted_at is null
   and pr.recorded_at between ps.starts_on and ps.effective_end
  group by ps.period_id, ps.core_student_id
),
period_weekly as (
  select
    ps.period_id,
    ps.core_student_id,
    (date_trunc('week', pr.recorded_at::timestamp without time zone))::date as week_start,
    coalesce(sum(pr.points) filter (where pr.type='POSITIVE'), 0)::int as positive_points,
    coalesce(sum(pr.points) filter (where pr.type='NEGATIVE'), 0)::int as negative_points,
    coalesce(count(*) filter (where pr.type='NEGATIVE'), 0)::int as penalty_incident_count
  from period_students ps
  join public.point_records pr
    on pr.core_student_id = ps.core_student_id
   and pr.deleted_at is null
   and pr.recorded_at between ps.starts_on and ps.effective_end
  group by
    ps.period_id,
    ps.core_student_id,
    (date_trunc('week', pr.recorded_at::timestamp without time zone))::date
),
training_counts as (
  select
    pw.period_id,
    pw.core_student_id,
    count(*) filter (
      where pw.penalty_incident_count >= 3
         or (pw.negative_points - pw.positive_points) >= 8
    )::int as physical_training_weeks
  from period_weekly pw
  group by pw.period_id, pw.core_student_id
)
select
  ps.period_id,
  ps.period_label,
  ps.starts_on,
  ps.ends_on,
  ps.effective_end,
  ps.ends_on is null as is_open,
  ps.student_id,
  ps.core_student_id,
  ps.student_no,
  ps.student_name,
  ps.grade,
  ps.homeroom,
  pt.positive_points,
  pt.negative_points,
  (pt.negative_points - pt.positive_points) as net_penalty_points,
  coalesce(tc.physical_training_weeks, 0) as physical_training_weeks,
  (
    coalesce(tc.physical_training_weeks, 0) >= 3
    or (pt.negative_points - pt.positive_points) >= 20
  ) as committee_required
from period_students ps
join period_totals pt
  on pt.period_id=ps.period_id
 and pt.core_student_id=ps.core_student_id
left join training_counts tc
  on tc.period_id=ps.period_id
 and tc.core_student_id=ps.core_student_id;

create or replace view public.v_discipline_core_calc_parity
with (security_invoker = true) as
with weekly_compare as (
  select
    coalesce(l.student_id, c.student_id) as student_id,
    coalesce(l.week_start, c.week_start) as week_start,
    (
      l.student_id is null
      or c.student_id is null
      or l.positive_points is distinct from c.positive_points
      or l.negative_points is distinct from c.negative_points
      or l.net_penalty_points is distinct from c.net_penalty_points
      or l.penalty_incident_count is distinct from c.penalty_incident_count
      or l.physical_training_required is distinct from c.physical_training_required
    ) as mismatch
  from public.v_weekly_scores l
  full join public.v_weekly_scores_core_shadow c
    on c.student_id=l.student_id
   and c.week_start=l.week_start
),
weekly_penalty_compare as (
  select
    coalesce(l.student_id, c.student_id) as student_id,
    coalesce(l.week_start, c.week_start) as week_start,
    (
      l.student_id is null
      or c.student_id is null
      or l.penalty_points is distinct from c.penalty_points
      or l.record_count is distinct from c.record_count
    ) as mismatch
  from public.v_weekly_penalties l
  full join public.v_weekly_penalties_core_shadow c
    on c.student_id=l.student_id
   and c.week_start=l.week_start
),
settlement_compare as (
  select
    coalesce(l.period_id, c.period_id) as period_id,
    coalesce(l.student_id, c.student_id) as student_id,
    (
      l.period_id is null
      or c.period_id is null
      or l.positive_points is distinct from c.positive_points
      or l.negative_points is distinct from c.negative_points
      or l.net_penalty_points is distinct from c.net_penalty_points
      or l.physical_training_weeks is distinct from c.physical_training_weeks
      or l.committee_required is distinct from c.committee_required
    ) as mismatch
  from public.v_settlement_scores l
  full join public.v_settlement_scores_core_shadow c
    on c.period_id=l.period_id
   and c.student_id=l.student_id
)
select
  (select count(*)::int from public.v_weekly_scores) as weekly_legacy_rows,
  (select count(*)::int from public.v_weekly_scores_core_shadow) as weekly_core_rows,
  (select count(*)::int from weekly_compare where mismatch) as weekly_mismatches,
  (select count(*)::int from public.v_weekly_penalties) as weekly_penalty_legacy_rows,
  (select count(*)::int from public.v_weekly_penalties_core_shadow) as weekly_penalty_core_rows,
  (select count(*)::int from weekly_penalty_compare where mismatch) as weekly_penalty_mismatches,
  (select count(*)::int from public.v_settlement_scores) as settlement_legacy_rows,
  (select count(*)::int from public.v_settlement_scores_core_shadow) as settlement_core_rows,
  (select count(*)::int from settlement_compare where mismatch) as settlement_mismatches;

comment on view public.v_discipline_core_calc_parity is
  'Aggregate parity check between legacy integer-key calculations and Core UUID shadow calculations.';

grant select on public.v_weekly_scores_core_shadow to authenticated;
grant select on public.v_weekly_penalties_core_shadow to authenticated;
grant select on public.v_settlement_scores_core_shadow to authenticated;
grant select on public.v_discipline_core_calc_parity to authenticated;
