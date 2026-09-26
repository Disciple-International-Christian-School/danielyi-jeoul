-- 2026-09-26
-- Core UUID shadow implementation for the student summary contract.

create or replace view public.v_student_summary_core_shadow
with (security_invoker = true) as
with lifetime as (
  select
    ds.core_student_id,
    coalesce(sum(pr.points) filter (where pr.type='POSITIVE'), 0)::int as positive_points,
    coalesce(sum(pr.points) filter (where pr.type='NEGATIVE'), 0)::int as negative_points
  from public.v_discipline_students ds
  left join public.point_records pr
    on pr.core_student_id=ds.core_student_id
   and pr.deleted_at is null
  group by ds.core_student_id
),
weekly as (
  select
    ws.core_student_id,
    ws.positive_points,
    ws.negative_points,
    ws.net_penalty_points,
    ws.penalty_incident_count,
    ws.physical_training_required
  from public.v_weekly_scores_core_shadow ws
  where ws.week_start=private.kst_week_start()
),
settlement as (
  select
    ss.core_student_id,
    ss.period_id,
    ss.period_label,
    ss.starts_on,
    ss.positive_points,
    ss.negative_points,
    ss.net_penalty_points,
    ss.physical_training_weeks,
    ss.committee_required
  from public.v_settlement_scores_core_shadow ss
  where ss.is_open
),
refl as (
  select
    pr.core_student_id,
    bool_or((not r.submitted) and r.due_at >= now()) as has_missing,
    bool_or((not r.submitted) and r.due_at < now()) as has_double
  from public.reflection_records r
  join public.point_records pr
    on pr.id=r.point_record_id
   and pr.deleted_at is null
  group by pr.core_student_id
),
active_pun as (
  select distinct on (p.core_student_id)
    p.core_student_id,
    p.types,
    p.violated_at
  from public.punishments p
  where p.start_date <= private.kst_today()
    and p.end_date >= private.kst_today()
  order by p.core_student_id, p.start_date desc, p.id desc
),
weeks3 as (
  select
    wp.core_student_id,
    count(*)::int as qualifying_weeks
  from public.v_weekly_penalties_core_shadow wp
  where wp.week_start = any(array[
    private.kst_week_start(),
    private.kst_week_start() - 7,
    private.kst_week_start() - 14
  ])
    and wp.penalty_points >= 5
  group by wp.core_student_id
)
select
  ds.legacy_student_id as id,
  ds.name,
  ds.grade,
  ls.created_at,
  ls.updated_at,
  coalesce(lt.positive_points, 0) as positive_points,
  coalesce(lt.negative_points, 0) as negative_points,
  coalesce(w.negative_points, 0) as weekly_penalty_points,
  coalesce(st.negative_points, 0) as monthly_penalty_points,
  coalesce(w.penalty_incident_count, 0) as weekly_record_count,
  case
    when ap.core_student_id is not null then array_to_string(ap.types, ', ')
    else null::text
  end as punishment,
  (
    array_remove(array[
      case when coalesce(w.physical_training_required, false) then '체력훈련 대상'::text else null::text end,
      case when coalesce(st.committee_required, false) then '징계위원회 대상'::text else null::text end,
      case when coalesce(r.has_missing, false) then '반성문 미제출'::text else null::text end,
      case when coalesce(r.has_double, false) then '반성문 2배 제출 대상'::text else null::text end,
      case when coalesce(w.negative_points, 0) >= 5 and ap.core_student_id is null then '처분 선택 필요'::text else null::text end,
      case when coalesce(w3.qualifying_weeks, 0) >= 3 then '귀가금지 조건 충족'::text else null::text end
    ], null::text)
    ||
    case
      when ap.core_student_id is null then array[]::text[]
      when ap.violated_at is not null then array['귀가금지'::text]
      else ap.types
    end
  ) as statuses,
  ds.core_student_id,
  ds.student_no,
  ds.homeroom,
  coalesce(w.positive_points, 0) as weekly_positive_points,
  coalesce(w.net_penalty_points, 0) as weekly_net_penalty_points,
  coalesce(w.physical_training_required, false) as physical_training_required,
  st.period_id as settlement_period_id,
  st.period_label as settlement_period_label,
  st.starts_on as settlement_starts_on,
  coalesce(st.positive_points, 0) as settlement_positive_points,
  coalesce(st.negative_points, 0) as settlement_penalty_points,
  coalesce(st.net_penalty_points, 0) as settlement_net_penalty_points,
  coalesce(st.physical_training_weeks, 0) as physical_training_weeks,
  coalesce(st.committee_required, false) as committee_required
from public.v_discipline_students ds
join public.students ls
  on ls.id=ds.legacy_student_id
left join lifetime lt
  on lt.core_student_id=ds.core_student_id
left join weekly w
  on w.core_student_id=ds.core_student_id
left join settlement st
  on st.core_student_id=ds.core_student_id
left join refl r
  on r.core_student_id=ds.core_student_id
left join active_pun ap
  on ap.core_student_id=ds.core_student_id
left join weeks3 w3
  on w3.core_student_id=ds.core_student_id;

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
  from public.v_student_summary l
  full join public.v_student_summary_core_shadow c
    on c.id=l.id
)
select
  (select count(*)::int from public.v_student_summary) as legacy_rows,
  (select count(*)::int from public.v_student_summary_core_shadow) as core_rows,
  (select count(*)::int from compared where mismatch) as mismatches;

comment on view public.v_student_summary_core_parity is
  'Aggregate parity check between current student summary and Core UUID shadow implementation.';

grant select on public.v_student_summary_core_shadow to authenticated;
grant select on public.v_student_summary_core_parity to authenticated;
