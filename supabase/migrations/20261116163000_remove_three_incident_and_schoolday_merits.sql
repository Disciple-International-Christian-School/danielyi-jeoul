-- Remove the obsolete three-incident training trigger without activating the
-- new calendar-settlement policy or rewriting any existing reflection.
create or replace view public.v_weekly_scores_core_shadow with (security_invoker = true) as
select
  s.id as student_id,
  pr.core_student_id,
  date_trunc('week', pr.recorded_at::timestamp)::date as week_start,
  coalesce(sum(pr.points) filter (where pr.type = 'POSITIVE'), 0)::integer as positive_points,
  coalesce(sum(pr.points) filter (where pr.type = 'NEGATIVE'), 0)::integer as negative_points,
  (coalesce(sum(pr.points) filter (where pr.type = 'NEGATIVE'), 0) -
    coalesce(sum(pr.points) filter (where pr.type = 'POSITIVE'), 0))::integer as net_penalty_points,
  coalesce(count(*) filter (where pr.type = 'NEGATIVE'), 0)::integer as penalty_incident_count,
  (coalesce(sum(pr.points) filter (where pr.type = 'NEGATIVE'), 0) -
    coalesce(sum(pr.points) filter (where pr.type = 'POSITIVE'), 0)) >= 8
    as physical_training_required
from public.point_records pr
join public.students s on s.core_student_id = pr.core_student_id
where pr.deleted_at is null
  and pr.superseded_by_import_id is null
  and pr.recorded_at <= private.kst_today()
group by s.id, pr.core_student_id, date_trunc('week', pr.recorded_at::timestamp)::date;

-- "School day" for merit eligibility and reflection deadlines is a weekday
-- not listed in the Daniel-owned non-attendance calendar. School discretionary
-- closures must be inserted into seondo_holidays before their effective dates.
create or replace function private.seondo_is_school_day(p_day date)
returns boolean language sql stable set search_path = '' as $$
  select extract(isodow from p_day) between 1 and 5
    and not exists (select 1 from discipline.seondo_holidays h where h.day = p_day)
$$;

-- T through T+4 = five SCHOOL days, including the effective merit day.
-- On a non-school-day receipt, T begins on the next school day.
create or replace function private.seondo_merit_valid(p_entered_on date, p_penalty_on date)
returns boolean language sql stable set search_path = '' as $$
  select p_penalty_on >= t.starts_on
    and p_penalty_on <= private.seondo_following_school_day(t.starts_on, 4)
  from (
    select case when private.seondo_is_school_day(p_entered_on)
      then p_entered_on
      else private.seondo_following_school_day(p_entered_on, 1)
    end as starts_on
  ) t
$$;

-- Allocation is chronological: only merits received BEFORE an offense may
-- offset that offense, even when both appear in the same printed notice.
-- Eligible merits carry across calendar weeks and publication batches until
-- fully used, provided the offense falls within the merit's five school days.
create or replace function private.seondo_prepare_notice(p_batch_id bigint, p_cutoff timestamptz, p_start timestamptz)
returns void language plpgsql set search_path = '' as $$
declare
  penalty record;
  credit record;
  pages_left integer;
  applied integer;
  cutoff_day date := (p_cutoff at time zone 'Asia/Seoul')::date;
begin
  for penalty in
    select r.id, p.points, p.item, p.recorded_at, p.core_student_id,
      greatest(p.created_at, p.recorded_at::timestamp at time zone 'Asia/Seoul') as effective_at,
      s.grade, s.homeroom, s.name
    from public.point_records p
    join public.reflection_records r on r.point_record_id = p.id
    join public.v_discipline_students s on s.core_student_id = p.core_student_id
    where p.type = 'NEGATIVE' and p.deleted_at is null and p.superseded_by_import_id is null
      and not r.submitted
      and not exists (
        select 1 from discipline.seondo_notice_entries e
        where e.reflection_id = r.id and not e.is_double
      )
      and greatest(p.created_at, p.recorded_at::timestamp at time zone 'Asia/Seoul') >= p_start
      and greatest(p.created_at, p.recorded_at::timestamp at time zone 'Asia/Seoul') < p_cutoff
    order by p.core_student_id, p.points, p.created_at, p.id
  loop
    pages_left := penalty.points;
    for credit in
      select m.id,
        m.points - coalesce((
          select sum(a.points) from discipline.seondo_merit_allocations a
          where a.merit_id = m.id
        ), 0) as available
      from public.point_records m
      where m.core_student_id = penalty.core_student_id and m.type = 'POSITIVE'
        and m.deleted_at is null and m.superseded_by_import_id is null
        and greatest(m.created_at, m.recorded_at::timestamp at time zone 'Asia/Seoul') >= p_start
        and greatest(m.created_at, m.recorded_at::timestamp at time zone 'Asia/Seoul') < p_cutoff
        and greatest(m.created_at, m.recorded_at::timestamp at time zone 'Asia/Seoul')
            <= penalty.effective_at
        and private.seondo_merit_valid(
          (greatest(m.created_at, m.recorded_at::timestamp at time zone 'Asia/Seoul')
             at time zone 'Asia/Seoul')::date,
          (penalty.effective_at at time zone 'Asia/Seoul')::date
        )
      order by greatest(m.created_at, m.recorded_at::timestamp at time zone 'Asia/Seoul'), m.id
    loop
      exit when pages_left = 0;
      applied := least(pages_left, greatest(credit.available, 0));
      if applied > 0 then
        insert into discipline.seondo_merit_allocations (reflection_id, merit_id, points)
        values (penalty.id, credit.id, applied);
        pages_left := pages_left - applied;
      end if;
    end loop;
    insert into discipline.seondo_notice_entries (
      batch_id, reflection_id, core_student_id, grade, homeroom, student_name,
      item, occurred_on, pages, due_at
    ) values (
      p_batch_id, penalty.id, penalty.core_student_id, penalty.grade, penalty.homeroom,
      penalty.name, penalty.item, penalty.recorded_at, pages_left,
      private.seondo_deadline(cutoff_day, penalty.grade, false)
    );
  end loop;
end;
$$;

revoke all on function private.seondo_is_school_day(date) from public, anon, authenticated;
grant execute on function private.seondo_is_school_day(date) to service_role;
