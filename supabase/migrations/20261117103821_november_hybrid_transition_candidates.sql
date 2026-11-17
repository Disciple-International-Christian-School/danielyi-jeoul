-- Preserve pre-2026-11-16 training decisions as REVIEW CANDIDATES, not approved facts.

create table discipline.seondo_legacy_weekly_candidates (
  week_start date not null check (week_start in (date '2026-10-26', date '2026-11-02', date '2026-11-09')),
  core_student_id uuid not null references core.students(id),
  grade integer not null,
  homeroom text,
  student_name text not null,
  weekly_net integer not null,
  reasons text[] not null,
  primary key (week_start, core_student_id)
);
alter table discipline.seondo_legacy_weekly_candidates enable row level security;
grant select on discipline.seondo_legacy_weekly_candidates to authenticated;
create policy seondo_legacy_review_lead_only on discipline.seondo_legacy_weekly_candidates
 for select to authenticated using (coalesce(private.current_admin_is_lead(),false));

create table discipline.seondo_legacy_review (
  month_start date primary key check (month_start = date '2026-11-01'),
  approved_at timestamptz not null,
  approved_by uuid not null references auth.users(id)
);
alter table discipline.seondo_legacy_review enable row level security;
grant select on discipline.seondo_legacy_review to authenticated;
create policy seondo_legacy_approval_lead_only on discipline.seondo_legacy_review
 for select to authenticated using (coalesce(private.current_admin_is_lead(),false));

-- Snapshot the available source rows as of the November 16 policy boundary.
-- These are candidates derived from DB, not evidence that training was completed.
with event_weeks as (
 select date_trunc('week',p.recorded_at::timestamp)::date week_start,p.core_student_id,
 sum(case when p.type='NEGATIVE' then -p.points else p.points end)::integer net,
 count(*) filter(where p.type='NEGATIVE') negative_count
 from public.point_records p
 where p.recorded_at between date '2026-10-26' and date '2026-11-15'
 and p.created_at < timestamptz '2026-11-16 00:00+09'
 and p.deleted_at is null and p.superseded_by_import_id is null
 group by 1,2
), overdue as (
 select distinct
 date_trunc('week',((r.double_submit_deadline at time zone 'Asia/Seoul')::date+1)::timestamp)::date week_start,
 r.core_student_id
 from public.v_reflections r
 join public.point_records p on p.id=r.point_record_id
 where p.created_at < timestamptz '2026-11-16 00:00+09'
 and p.recorded_at <= date '2026-11-15'
 and ((r.double_submit_deadline at time zone 'Asia/Seoul')::date+1)
    between date '2026-11-01' and date '2026-11-15'
 and (not r.submitted or r.submitted_at > r.double_submit_deadline)
), combined as (
 select coalesce(e.week_start,o.week_start) week_start,
 coalesce(e.core_student_id,o.core_student_id) core_student_id,
 coalesce(e.net,0) net, coalesce(e.negative_count,0) negative_count,
 o.core_student_id is not null overdue
 from event_weeks e full outer join overdue o using(week_start,core_student_id)
 where coalesce(e.week_start,o.week_start) in
   (date '2026-10-26',date '2026-11-02',date '2026-11-09')
)
insert into discipline.seondo_legacy_weekly_candidates
(week_start,core_student_id,grade,homeroom,student_name,weekly_net,reasons)
select c.week_start,s.core_student_id,s.grade,s.homeroom,s.name,c.net,
 array_remove(array[
  case when c.net <= -8 then '구규정: 주간 NET -8점 이하' end,
  case when c.negative_count >= 3 then '구규정: 벌점 3회 이상' end,
  case when c.overdue then '구규정: 2배 반성문 미제출' end
 ],null)
from combined c join public.v_discipline_students s on s.core_student_id=c.core_student_id
where c.net <= -8 or c.negative_count>=3 or c.overdue;

-- Only after staff reconcile and explicitly approve the snapshot:
-- 1) insert accepted legacy rows into discipline.seondo_weekly_training
-- 2) write discipline.seondo_legacy_review approval row
-- Until then the November monthly closure deliberately remains blocked.
-- Weekly November 16+ results continue using the TWO new reasons.

-- New-policy physical-training accrual begins Nov 16 even though
-- existing reflection obligations use their historical notice/deadline terms.
CREATE OR REPLACE FUNCTION private.seondo_finalize(p_now timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  policy_start timestamptz;
  period record;
begin
  select starts_at into policy_start from discipline.seondo_policy where singleton for update;
  if policy_start is null or p_now < policy_start then return; end if;

  for period in
    select s.week_start, (((s.week_start + 6) + time '23:59') at time zone 'Asia/Seoul') as closes_at
    from (
      select series.d::date as week_start from generate_series(
        date_trunc('week', policy_start at time zone 'Asia/Seoul'),
        date_trunc('week', p_now at time zone 'Asia/Seoul'), interval '7 days'
      ) series(d)
    ) s
    where (((s.week_start + 6) + time '23:59') at time zone 'Asia/Seoul') <= p_now
      and not exists (select from discipline.seondo_closures c where c.kind = 'WEEKLY' and c.period_start = s.week_start)
    order by s.week_start
  loop
    insert into discipline.seondo_weekly_training (week_start, core_student_id, grade, homeroom, student_name, weekly_net, reasons)
    with scores as (
      select p.core_student_id, sum(case when p.type = 'NEGATIVE' then -p.points else p.points end)::integer as net
      from public.point_records p
      where p.recorded_at between period.week_start and period.week_start + 6
        and p.created_at <= period.closes_at and p.deleted_at is null and p.superseded_by_import_id is null
      group by p.core_student_id
    ), deadlines as (
      select r.core_student_id, r.submitted_at, r.submitted, r.double_submit_deadline,
        case when r.seondo_managed then r.double_submit_deadline
        else (((r.double_submit_deadline at time zone 'Asia/Seoul')::date + 1)::timestamp at time zone 'Asia/Seoul')
        end as training_at
      from public.v_reflections r
    ), overdue as (
      select distinct d.core_student_id from deadlines d
      where d.training_at >= greatest(timestamptz '2026-11-16 00:00+09', period.week_start::timestamp at time zone 'Asia/Seoul')
        and d.training_at <= period.closes_at
        and (not d.submitted or d.submitted_at > d.double_submit_deadline)
    )
    select period.week_start, s.core_student_id, s.grade, s.homeroom, s.name, coalesce(p.net, 0),
      array_remove(array[
        case when p.net <= -8 then '주간 상벌NET -8점 이하' end,
        case when o.core_student_id is not null then '2배 반성문 기한 내 미제출' end
      ], null)
    from public.v_discipline_students s
    left join scores p on p.core_student_id = s.core_student_id
    left join overdue o on o.core_student_id = s.core_student_id
    where p.net <= -8 or o.core_student_id is not null;

    insert into discipline.seondo_closures (kind, period_start, closes_at, finalized_at)
    values ('WEEKLY', period.week_start, period.closes_at, p_now);
  end loop;

  for period in
    select s.month_start,
      (((s.month_start + interval '1 month')::date - 1 + time '23:59') at time zone 'Asia/Seoul') as closes_at
    from (
      select series.d::date as month_start from generate_series(
        date_trunc('month', policy_start at time zone 'Asia/Seoul'),
        date_trunc('month', p_now at time zone 'Asia/Seoul'), interval '1 month'
      ) series(d)
    ) s
    where (((s.month_start + interval '1 month')::date - 1 + time '23:59') at time zone 'Asia/Seoul') <= p_now
      and not exists (select from discipline.seondo_closures c where c.kind = 'MONTHLY' and c.period_start = s.month_start)
      and (s.month_start <> date '2026-11-01' or exists (
        select 1 from discipline.seondo_legacy_review approval
        where approval.month_start = date '2026-11-01' and approval.approved_at is not null
      ))
    order by s.month_start
  loop
    insert into discipline.seondo_monthly_committee (month_start, core_student_id, grade, homeroom, student_name, training_count)
    select period.month_start, s.core_student_id, s.grade, s.homeroom, s.name, count(*)::integer
    from discipline.seondo_weekly_training t join public.v_discipline_students s on s.core_student_id = t.core_student_id
    where t.week_start + 6 >= period.month_start and t.week_start + 6 < period.month_start + interval '1 month'
      and s.grade between 7 and 12
    group by s.core_student_id, s.grade, s.homeroom, s.name
    having count(*) >= 3;

    insert into discipline.seondo_closures (kind, period_start, closes_at, finalized_at)
    values ('MONTHLY', period.month_start, period.closes_at, p_now);
  end loop;

  insert into discipline.seondo_committee_inbox (month_start, user_id, delivered_at)
  select c.period_start, r.user_id, p_now
  from discipline.seondo_closures c cross join discipline.seondo_committee_recipients r
  where c.kind = 'MONTHLY' and c.period_start >= date_trunc('month', p_now at time zone 'Asia/Seoul')::date - interval '1 month'
  on conflict do nothing;
end;
$function$;

-- Avoid a misleading zero training count before the first finalized Sunday.
create or replace view public.v_student_summary with (security_invoker = true) as
WITH policy AS (
         SELECT (EXISTS ( SELECT
                   FROM discipline.seondo_policy
                  WHERE seondo_policy.starts_at <= now())) AS active,
            ( SELECT max(seondo_closures.period_start) AS max
                   FROM discipline.seondo_closures
                  WHERE seondo_closures.kind = 'WEEKLY'::text) AS latest_week,
            ( SELECT max(seondo_closures.period_start) AS max
                   FROM discipline.seondo_closures
                  WHERE seondo_closures.kind = 'MONTHLY'::text) AS latest_month
        ), month_counts AS (
         SELECT seondo_weekly_training.core_student_id,
            count(*)::integer AS training_count
           FROM discipline.seondo_weekly_training
          WHERE date_trunc('month'::text, (seondo_weekly_training.week_start + 6)::timestamp without time zone) = date_trunc('month'::text, private.kst_today()::timestamp without time zone)
          GROUP BY seondo_weekly_training.core_student_id
        )
 SELECT s.id,
    s.name,
    s.grade,
    s.created_at,
    s.updated_at,
    s.positive_points,
    s.negative_points,
    s.weekly_penalty_points,
    s.monthly_penalty_points,
    s.weekly_record_count,
    s.punishment,
        CASE
            WHEN p.active THEN array_remove(array_remove(s.statuses, '체력훈련 대상'::text), '징계위원회 대상'::text) || array_remove(ARRAY[
            CASE
                WHEN w.core_student_id IS NOT NULL OR (p.latest_week IS NULL AND s.physical_training_required) THEN '체력훈련 대상'::text
                ELSE NULL::text
            END,
            CASE
                WHEN m.core_student_id IS NOT NULL THEN '징계위원회 대상'::text
                ELSE NULL::text
            END], NULL::text)
            ELSE s.statuses
        END AS statuses,
    s.core_student_id,
    s.student_no,
    s.homeroom,
    s.weekly_positive_points,
    s.weekly_net_penalty_points,
        CASE
            WHEN p.active THEN w.core_student_id IS NOT NULL OR (p.latest_week IS NULL AND s.physical_training_required)
            ELSE s.physical_training_required
        END AS physical_training_required,
    s.settlement_period_id,
    s.settlement_period_label,
    s.settlement_starts_on,
    s.settlement_positive_points,
    s.settlement_penalty_points,
    s.settlement_net_penalty_points,
        CASE
            WHEN p.active THEN COALESCE(mc.training_count, 0)
            ELSE s.physical_training_weeks
        END AS physical_training_weeks,
        CASE
            WHEN p.active THEN m.core_student_id IS NOT NULL
            ELSE s.committee_required
        END AS committee_required,
        CASE
            WHEN p.active THEN COALESCE(w.reasons, ARRAY[]::text[])
            ELSE s.physical_training_reasons
        END AS physical_training_reasons
   FROM v_student_summary_core_shadow s
     CROSS JOIN policy p
     LEFT JOIN discipline.seondo_weekly_training w ON w.week_start = p.latest_week AND w.core_student_id = s.core_student_id
     LEFT JOIN discipline.seondo_monthly_committee m ON m.month_start = p.latest_month AND m.core_student_id = s.core_student_id
     LEFT JOIN month_counts mc ON mc.core_student_id = s.core_student_id;
