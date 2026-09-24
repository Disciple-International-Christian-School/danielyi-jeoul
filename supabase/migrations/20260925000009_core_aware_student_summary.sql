-- 2026-09-25
-- Daniel's Scale operational summary on top of DICS Core + NET scoring.
--
-- This replaces the old calendar-month / raw-penalty-only dashboard logic.
-- Until the final UUID cut-over, "id" remains the legacy integer student id so
-- existing routes keep working. core_student_id is exposed alongside it.

create or replace view public.v_current_settlement
with (security_invoker = true) as
select
  id,
  label,
  starts_on,
  ends_on,
  created_at
from public.settlement_periods
where ends_on is null;

create or replace view public.v_student_summary
with (security_invoker = true) as
with lifetime as (
  select
    s.legacy_student_id as student_id,
    coalesce(sum(pr.points) filter (where pr.type = 'POSITIVE'), 0)::int as positive_points,
    coalesce(sum(pr.points) filter (where pr.type = 'NEGATIVE'), 0)::int as negative_points
  from public.v_discipline_students s
  left join public.point_records pr
    on pr.student_id = s.legacy_student_id
   and pr.deleted_at is null
  group by s.legacy_student_id
),
weekly as (
  select
    ws.student_id,
    ws.positive_points,
    ws.negative_points,
    ws.net_penalty_points,
    ws.penalty_incident_count,
    ws.physical_training_required
  from public.v_weekly_scores ws
  where ws.week_start = private.kst_week_start()
),
settlement as (
  select
    ss.student_id,
    ss.period_id,
    ss.period_label,
    ss.starts_on,
    ss.positive_points,
    ss.negative_points,
    ss.net_penalty_points,
    ss.physical_training_weeks,
    ss.committee_required
  from public.v_settlement_scores ss
  where ss.is_open
),
refl as (
  select
    pr.student_id,
    bool_or(not r.submitted and r.due_at >= now()) as has_missing,
    bool_or(not r.submitted and r.due_at < now()) as has_double
  from public.reflection_records r
  join public.point_records pr
    on pr.id = r.point_record_id
   and pr.deleted_at is null
  group by pr.student_id
),
active_pun as (
  select distinct on (student_id)
    student_id,
    types,
    violated_at
  from public.punishments
  where start_date <= private.kst_today()
    and end_date >= private.kst_today()
  order by student_id, start_date desc, id desc
),
weeks3 as (
  select student_id, count(*)::int as qualifying_weeks
  from public.v_weekly_penalties
  where week_start in (
      private.kst_week_start(),
      private.kst_week_start() - 7,
      private.kst_week_start() - 14
    )
    and penalty_points >= 5
  group by student_id
)
select
  ds.legacy_student_id as id,
  ds.core_student_id,
  ds.student_no,
  ds.name,
  ds.grade,
  ds.homeroom,

  -- Lifetime raw totals: never netted or rewritten.
  coalesce(lt.positive_points, 0)::int as positive_points,
  coalesce(lt.negative_points, 0)::int as negative_points,

  -- Current week.
  coalesce(w.positive_points, 0)::int as weekly_positive_points,
  coalesce(w.negative_points, 0)::int as weekly_penalty_points,
  coalesce(w.net_penalty_points, 0)::int as weekly_net_penalty_points,
  coalesce(w.penalty_incident_count, 0)::int as weekly_record_count,
  coalesce(w.physical_training_required, false) as physical_training_required,

  -- Current admin-controlled settlement period.
  st.period_id as settlement_period_id,
  st.period_label as settlement_period_label,
  st.starts_on as settlement_starts_on,
  coalesce(st.positive_points, 0)::int as settlement_positive_points,
  coalesce(st.negative_points, 0)::int as settlement_penalty_points,
  coalesce(st.net_penalty_points, 0)::int as settlement_net_penalty_points,
  coalesce(st.physical_training_weeks, 0)::int as physical_training_weeks,
  coalesce(st.committee_required, false) as committee_required,

  -- Temporary backward-compatibility alias. Frontend should migrate to the
  -- explicit settlement_* fields and stop calling this "monthly".
  coalesce(st.negative_points, 0)::int as monthly_penalty_points,

  case
    when ap.student_id is not null then array_to_string(ap.types, ', ')
  end as punishment,

  array_remove(array[
    case when coalesce(w.physical_training_required, false)
      then '체력훈련 대상' end,
    case when coalesce(st.committee_required, false)
      then '징계위원회 대상' end,
    case when coalesce(r.has_missing, false)
      then '반성문 미제출' end,
    case when coalesce(r.has_double, false)
      then '반성문 2배 제출 대상' end,
    -- Existing dorm sanction workflow remains raw-weekly-penalty based until
    -- the 선도부/사생회 policy is separately revised.
    case when coalesce(w.negative_points, 0) >= 5 and ap.student_id is null
      then '처분 선택 필요' end,
    case when coalesce(w3.qualifying_weeks, 0) >= 3
      then '귀가금지 조건 충족' end
  ], null)
  || case
       when ap.student_id is null then array[]::text[]
       when ap.violated_at is not null then array['귀가금지']
       else ap.types
     end as statuses,

  -- Legacy timestamps continue to come from the compatibility row until the
  -- discipline FK cut-over is complete.
  ls.created_at,
  ls.updated_at

from public.v_discipline_students ds
join public.students ls
  on ls.id = ds.legacy_student_id
left join lifetime lt
  on lt.student_id = ds.legacy_student_id
left join weekly w
  on w.student_id = ds.legacy_student_id
left join settlement st
  on st.student_id = ds.legacy_student_id
left join refl r
  on r.student_id = ds.legacy_student_id
left join active_pun ap
  on ap.student_id = ds.legacy_student_id
left join weeks3 w3
  on w3.student_id = ds.legacy_student_id;

create or replace view public.v_dashboard_counts
with (security_invoker = true) as
select
  (select count(*) from public.v_student_summary)::int as students,
  (select count(*) from public.v_student_summary
    where physical_training_required)::int as weekly_targets,
  (select count(*) from public.v_student_summary
    where committee_required)::int as committee_targets,
  (select count(*) from public.v_reflections
    where status = 'MISSING')::int as missing_reflections,
  (select count(*) from public.v_reflections
    where status = 'DOUBLE')::int as double_reflections,
  (select count(distinct student_id)
   from public.punishments
   where start_date <= private.kst_today()
     and end_date >= private.kst_today())::int as active_punishments;
