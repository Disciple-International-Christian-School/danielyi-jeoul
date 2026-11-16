-- The policy starts when operations records a cutover in discipline.seondo_policy.
create table discipline.seondo_policy (
  singleton boolean primary key default true check (singleton),
  starts_at timestamptz not null
);

create table discipline.seondo_holidays (
  day date primary key,
  label text not null
);

-- KASA 2027 calendar, including substitute holidays. Weekends are calculated separately.
insert into discipline.seondo_holidays (day, label) values
  ('2026-12-25','기독탄신일'),
  ('2027-01-01','신정'), ('2027-02-08','설 연휴'), ('2027-02-09','설 대체공휴일'),
  ('2027-03-01','삼일절'), ('2027-05-03','노동절 대체공휴일'), ('2027-05-05','어린이날'),
  ('2027-05-13','부처님오신날'), ('2027-07-19','제헌절 대체공휴일'), ('2027-08-16','광복절 대체공휴일'),
  ('2027-09-14','추석 연휴'), ('2027-09-15','추석'), ('2027-09-16','추석 연휴'),
  ('2027-10-04','개천절 대체공휴일'), ('2027-10-11','한글날 대체공휴일'),
  ('2027-12-27','기독탄신일 대체공휴일');

create table discipline.seondo_notice_batches (
  id bigint generated always as identity primary key,
  notice_day date not null unique,
  cutoff_at timestamptz not null unique,
  cutoff_by uuid not null,
  published_at timestamptz,
  published_by uuid,
  check (published_at is null or published_at >= cutoff_at)
);

create table discipline.seondo_notice_entries (
  batch_id bigint not null references discipline.seondo_notice_batches(id),
  reflection_id integer not null references public.reflection_records(id),
  core_student_id uuid not null references core.students(id),
  grade integer not null,
  homeroom text,
  student_name text not null,
  item text not null,
  occurred_on date not null,
  pages integer not null check (pages >= 0),
  is_double boolean not null default false,
  due_at timestamptz,
  primary key (batch_id, reflection_id)
);
create index seondo_notice_history_by_reflection on discipline.seondo_notice_entries(reflection_id);
create unique index seondo_single_initial_notice
  on discipline.seondo_notice_entries (reflection_id) where not is_double;

create table discipline.seondo_merit_allocations (
  reflection_id integer not null references public.reflection_records(id),
  merit_id integer not null references public.point_records(id),
  points integer not null check (points > 0),
  primary key (reflection_id, merit_id)
);
create index seondo_merit_allocations_by_merit on discipline.seondo_merit_allocations(merit_id);

create table discipline.seondo_closures (
  kind text not null check (kind in ('WEEKLY','MONTHLY')),
  period_start date not null,
  closes_at timestamptz not null,
  finalized_at timestamptz not null default now(),
  primary key (kind, period_start)
);

create table discipline.seondo_weekly_training (
  week_start date not null,
  core_student_id uuid not null references core.students(id),
  grade integer not null,
  homeroom text,
  student_name text not null,
  weekly_net integer not null,
  reasons text[] not null,
  primary key (week_start, core_student_id)
);

create table discipline.seondo_monthly_committee (
  month_start date not null,
  core_student_id uuid not null references core.students(id),
  grade integer not null,
  homeroom text,
  student_name text not null,
  training_count integer not null check (training_count >= 3),
  primary key (month_start, core_student_id)
);

-- Provision verified school staff and committee accounts here during rollout.
create table discipline.seondo_committee_recipients (
  user_id uuid primary key references auth.users(id) on delete cascade
);

create table discipline.seondo_committee_inbox (
  month_start date not null,
  user_id uuid not null references discipline.seondo_committee_recipients(user_id) on delete cascade,
  delivered_at timestamptz not null default now(),
  primary key (month_start, user_id)
);

alter table discipline.seondo_policy enable row level security;
alter table discipline.seondo_holidays enable row level security;
alter table discipline.seondo_notice_batches enable row level security;
alter table discipline.seondo_notice_entries enable row level security;
alter table discipline.seondo_merit_allocations enable row level security;
alter table discipline.seondo_closures enable row level security;
alter table discipline.seondo_weekly_training enable row level security;
alter table discipline.seondo_monthly_committee enable row level security;
alter table discipline.seondo_committee_recipients enable row level security;
alter table discipline.seondo_committee_inbox enable row level security;

grant select on discipline.seondo_policy, discipline.seondo_holidays,
  discipline.seondo_notice_batches, discipline.seondo_notice_entries, discipline.seondo_closures,
  discipline.seondo_weekly_training, discipline.seondo_monthly_committee to authenticated;
create policy seondo_policy_read on discipline.seondo_policy for select to authenticated using (true);
create policy seondo_holidays_read on discipline.seondo_holidays for select to authenticated
  using ((select private.current_admin_role()) is not null);
create policy seondo_notice_batches_read on discipline.seondo_notice_batches for select to authenticated
  using ((select private.current_admin_role()) is not null);
create policy seondo_notice_entries_read on discipline.seondo_notice_entries for select to authenticated
  using ((select private.current_admin_role()) is not null);
create policy seondo_closures_read on discipline.seondo_closures for select to authenticated
  using ((select private.current_admin_role()) is not null);
create policy seondo_weekly_training_read on discipline.seondo_weekly_training for select to authenticated
  using ((select private.current_admin_role()) is not null);
create policy seondo_monthly_committee_read on discipline.seondo_monthly_committee for select to authenticated
  using ((select private.current_admin_role()) is not null);

create function private.seondo_following_school_day(p_date date, p_count integer)
returns date language plpgsql stable set search_path = '' as $$
declare
  next_day date := p_date;
  remaining integer := p_count;
begin
  while remaining > 0 loop
    next_day := next_day + 1;
    if extract(isodow from next_day) <= 5
       and not exists (select from discipline.seondo_holidays h where h.day = next_day) then
      remaining := remaining - 1;
    end if;
  end loop;
  return next_day;
end;
$$;

create function private.seondo_deadline(p_posted_on date, p_grade integer, p_double boolean)
returns timestamptz language sql stable set search_path = '' as $$
  select case when p_grade between 1 and 6 then
    (private.seondo_following_school_day(p_posted_on, case when p_double then 2 else 1 end) + time '08:20')
  when p_double then
    (private.seondo_following_school_day(p_posted_on, 1) + time '17:00')
  else (p_posted_on + time '17:00')
  end at time zone 'Asia/Seoul'
$$;

-- Five weekdays, including the day entered. Holiday skipping applies to school deadlines only.
create function private.seondo_merit_valid(p_entered_on date, p_cutoff_on date)
returns boolean language sql immutable set search_path = '' as $$
  select p_entered_on <= p_cutoff_on and p_cutoff_on <= (
    select max(weekday) from (
      select p_entered_on + d.i as weekday from generate_series(0, 7) as d(i)
      where extract(isodow from p_entered_on + d.i) <= 5
      order by d.i limit 5
    ) weekdays
  )
$$;

create function private.seondo_prepare_notice(p_batch_id bigint, p_cutoff timestamptz, p_start timestamptz)
returns void language plpgsql set search_path = '' as $$
declare
  penalty record;
  credit record;
  pages_left integer;
  applied integer;
  cutoff_day date := (p_cutoff at time zone 'Asia/Seoul')::date;
begin
  for penalty in
    select r.id, p.points, p.item, p.recorded_at, p.core_student_id, s.grade, s.homeroom, s.name
    from public.point_records p
    join public.reflection_records r on r.point_record_id = p.id
    join public.v_discipline_students s on s.core_student_id = p.core_student_id
    where p.type = 'NEGATIVE' and p.deleted_at is null and p.superseded_by_import_id is null
      and not r.submitted
      and not exists (select from discipline.seondo_notice_entries e where e.reflection_id = r.id and not e.is_double)
      and greatest(p.created_at, p.recorded_at::timestamp at time zone 'Asia/Seoul') >= p_start
      and greatest(p.created_at, p.recorded_at::timestamp at time zone 'Asia/Seoul') < p_cutoff
    order by p.core_student_id, p.points, p.created_at, p.id
  loop
    pages_left := penalty.points;
    for credit in
      select m.id, m.points - coalesce((
        select sum(a.points) from discipline.seondo_merit_allocations a where a.merit_id = m.id
      ), 0) as available
      from public.point_records m
      where m.core_student_id = penalty.core_student_id and m.type = 'POSITIVE'
        and m.deleted_at is null and m.superseded_by_import_id is null
        and greatest(m.created_at, m.recorded_at::timestamp at time zone 'Asia/Seoul') >= p_start
        and greatest(m.created_at, m.recorded_at::timestamp at time zone 'Asia/Seoul') < p_cutoff
        and private.seondo_merit_valid(
          greatest(m.recorded_at, (m.created_at at time zone 'Asia/Seoul')::date), cutoff_day
        )
      order by greatest(m.recorded_at, (m.created_at at time zone 'Asia/Seoul')::date), m.created_at, m.id
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
      batch_id, reflection_id, core_student_id, grade, homeroom, student_name, item, occurred_on, pages, due_at
    ) values (
      p_batch_id, penalty.id, penalty.core_student_id, penalty.grade, penalty.homeroom, penalty.name,
      penalty.item, penalty.recorded_at, pages_left, private.seondo_deadline(cutoff_day, penalty.grade, false)
    );
  end loop;
end;
$$;

-- Both actions are idempotent. A single draft holds the cutoff while the notice is printed.
create function private.seondo_notice_action_at(p_publish boolean, p_time timestamptz)
returns void language plpgsql set search_path = '' as $$
declare
  local_day date;
  policy_start timestamptz;
  action_time timestamptz;
  current_batch discipline.seondo_notice_batches%rowtype;
begin
  if auth.uid() is null or not coalesce(private.current_admin_is_lead(), false) then
    raise exception '선도부장 권한이 필요합니다.';
  end if;
  select starts_at into policy_start from discipline.seondo_policy where singleton for update;
  action_time := coalesce(p_time, clock_timestamp());
  local_day := (action_time at time zone 'Asia/Seoul')::date;
  if policy_start is null or action_time < policy_start then
    raise exception '새 선도부 규정의 적용 시각이 도래하지 않았습니다.';
  end if;

  select * into current_batch from discipline.seondo_notice_batches where published_at is null;
  if not found then
    select * into current_batch from discipline.seondo_notice_batches where notice_day = local_day;
  end if;
  if current_batch.published_at is not null then return; end if;

  if not p_publish then
    if current_batch.id is null then
      insert into discipline.seondo_notice_batches (notice_day, cutoff_at, cutoff_by)
      values (local_day, action_time, auth.uid()) returning * into current_batch;
      perform private.seondo_prepare_notice(current_batch.id, action_time, policy_start);
      -- Snapshot open double submissions at the same cutoff as the new cases.
      insert into discipline.seondo_notice_entries (
        batch_id, reflection_id, core_student_id, grade, homeroom, student_name, item, occurred_on, pages, is_double, due_at
      )
      select current_batch.id, v.id, v.core_student_id, v.grade, v.homeroom, v.student_name, v.item,
        v.recorded_at, v.reflection_pages * 2, true, v.double_submit_deadline
      from public.v_reflections v
      where v.is_current_student and not v.submitted and v.due_at < current_batch.cutoff_at and v.reflection_pages > 0
      on conflict do nothing;
    end if;
    return;
  end if;
  if current_batch.id is null then raise exception '먼저 출력 기준을 확정해 주세요.'; end if;
  if (action_time at time zone 'Asia/Seoul')::time >= time '17:00' and exists (
    select from discipline.seondo_notice_entries
    where batch_id = current_batch.id and not is_double and grade >= 7 and pages > 0
  ) then
    raise exception '중고등 당일 제출 기한인 17시 전에 게시를 확정해 주세요.';
  end if;

  update discipline.seondo_notice_entries e set due_at = private.seondo_deadline(local_day, e.grade, false)
    where e.batch_id = current_batch.id and not e.is_double;
  update public.reflection_records r
    set due_at = e.due_at, submission_deadline = (e.due_at at time zone 'Asia/Seoul')::date
    from discipline.seondo_notice_entries e
    where e.batch_id = current_batch.id and e.reflection_id = r.id and not e.is_double and e.pages > 0;

  update discipline.seondo_notice_batches
    set notice_day = local_day, published_at = action_time, published_by = auth.uid() where id = current_batch.id;
end;
$$;

create function private.seondo_notice_action(p_publish boolean)
returns void language sql security definer set search_path = '' as $$
  select private.seondo_notice_action_at(p_publish, null)
$$;

create function public.seondo_notice_action(p_publish boolean)
returns void language sql set search_path = '' as $$
  select private.seondo_notice_action(p_publish)
$$;

create function public.get_seondo_notice(p_day date)
returns jsonb language sql stable set search_path = '' as $$
  with batch as (
    select b.* from discipline.seondo_notice_batches b
    where b.notice_day = p_day or (b.published_at is null and p_day = private.kst_today())
    order by (b.notice_day = p_day) desc limit 1
  )
  select jsonb_build_object(
    'active', coalesce((select starts_at <= now() from discipline.seondo_policy where singleton), false),
    'managed_date', coalesce((select (starts_at at time zone 'Asia/Seoul')::date <= p_day
      from discipline.seondo_policy where singleton), false),
    'batch', (select jsonb_build_object('day', b.notice_day, 'cutoff_at', b.cutoff_at, 'published_at', b.published_at)
      from batch b),
    'entries', coalesce((
      select jsonb_agg(jsonb_build_object(
        'reflection_id', e.reflection_id, 'student_name', e.student_name, 'grade', e.grade,
        'homeroom', e.homeroom, 'item', e.item, 'occurred_on', e.occurred_on,
        'pages', e.pages, 'is_double', e.is_double, 'due_at',
          case when b.published_at is null and not e.is_double
            then private.seondo_deadline(greatest(b.notice_day, private.kst_today()), e.grade, false)
            else e.due_at end
      ) order by e.grade, e.homeroom, e.student_name, e.reflection_id)
      from discipline.seondo_notice_entries e
      join batch b on b.id = e.batch_id
      where e.pages > 0
    ), '[]'::jsonb)
  )
$$;

-- Retain the previous policy on cases before the transition and feed issued cases into
-- the same read path consumed by notice badges, student history and homeroom push.
CREATE OR REPLACE VIEW public.v_reflection_eligible_penalties WITH (security_invoker = true) AS
WITH sequenced AS (
  SELECT pr.id AS point_record_id,
         pr.core_student_id,
         date_trunc('week', pr.recorded_at::timestamp)::date AS week_start,
         pr.recorded_at,
         pr.created_at,
         pr.type,
         pr.points,
         sum(CASE WHEN pr.type = 'POSITIVE' THEN pr.points ELSE -pr.points END) OVER (
           PARTITION BY pr.core_student_id, date_trunc('week', pr.recorded_at::timestamp)
           ORDER BY pr.created_at, pr.id
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
         ) AS net_at_entry
  FROM public.point_records pr
  WHERE pr.deleted_at IS NULL
    AND pr.superseded_by_import_id IS NULL
    AND pr.recorded_at <= private.kst_today()
), with_waiver AS (
  SELECT q.*,
         min(greatest(q.created_at, q.recorded_at::timestamp AT TIME ZONE 'Asia/Seoul'))
           FILTER (WHERE q.type = 'POSITIVE' AND q.net_at_entry >= 0
                    AND (q.created_at AT TIME ZONE 'Asia/Seoul')::date <= q.recorded_at)
           OVER (
             PARTITION BY q.core_student_id, q.recorded_at
             ORDER BY q.created_at, q.point_record_id
             ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING
           ) AS same_day_waiver_at
  FROM sequenced q
)
SELECT q.point_record_id,
       q.core_student_id,
       q.week_start,
       w.positive_points - w.negative_points AS weekly_net,
       least(q.points, -q.net_at_entry)::int AS reflection_pages
FROM with_waiver q
JOIN public.v_weekly_scores_core_shadow w
  ON w.core_student_id = q.core_student_id AND w.week_start = q.week_start
LEFT JOIN public.reflection_records r ON r.point_record_id = q.point_record_id
WHERE q.type = 'NEGATIVE'
  AND q.net_at_entry < 0
  AND NOT EXISTS (
    select from discipline.seondo_policy policy
    where greatest(q.created_at, q.recorded_at::timestamp at time zone 'Asia/Seoul') >= policy.starts_at
  )
  AND CASE
    WHEN q.recorded_at < date '2026-11-11' THEN w.net_penalty_points > 0
    ELSE r.submitted OR q.same_day_waiver_at IS NULL OR q.same_day_waiver_at > r.due_at
  END
UNION ALL
select r.point_record_id, e.core_student_id, date_trunc('week', e.occurred_on::timestamp)::date,
  coalesce(w.positive_points - w.negative_points, 0), e.pages
from discipline.seondo_notice_entries e
join discipline.seondo_notice_batches b on b.id = e.batch_id and b.published_at is not null
join public.reflection_records r on r.id = e.reflection_id
join public.point_records pr on pr.id = r.point_record_id
  and pr.deleted_at is null and pr.superseded_by_import_id is null
left join public.v_weekly_scores_core_shadow w on w.core_student_id = e.core_student_id
  and w.week_start = date_trunc('week', e.occurred_on::timestamp)::date
where not e.is_double and e.pages > 0;

CREATE OR REPLACE VIEW public.v_reflections WITH (security_invoker = true) AS
 SELECT r.id,
    r.point_record_id,
    s.id AS student_id,
    s.name AS student_name,
    s.grade,
    pr.item,
    pr.points,
    pr.recorded_at,
    r.submitted,
    r.submission_deadline,
    r.submitted_at,
        CASE
            WHEN r.submitted THEN 'SUBMITTED'::text
            WHEN r.due_at < now() THEN 'DOUBLE'::text
            ELSE 'MISSING'::text
        END AS status,
    r.due_at,
    r.deadline_change_reason,
        CASE
            WHEN s.grade >= 1 AND s.grade <= 6 THEN 'ELEMENTARY'::discipline_scope
            WHEN s.grade >= 7 AND s.grade <= 8 THEN 'MIDDLE'::discipline_scope
            ELSE 'HIGH'::discipline_scope
        END AS assigned_scope,
    pr.core_student_id,
    e.week_start,
    e.weekly_net,
    ds.homeroom,
    case when issued.batch_id is not null then
      case when issued.grade between 1 and 6 then private.seondo_deadline(issued.notice_day, issued.grade, true)
      else private.seondo_deadline((r.due_at at time zone 'Asia/Seoul')::date, issued.grade, true)
      end
    else (((r.due_at AT TIME ZONE 'Asia/Seoul')::date
      + CASE WHEN (r.due_at AT TIME ZONE 'Asia/Seoul')::time >= TIME '17:00' THEN 1 ELSE 0 END
      + TIME '17:00') AT TIME ZONE 'Asia/Seoul') end AS double_submit_deadline,
    ds.core_student_id IS NOT NULL AS is_current_student,
    e.reflection_pages,
    issued.batch_id is not null as seondo_managed,
    last_notice.notice_day as seondo_notice_day
   FROM reflection_records r
     JOIN point_records pr ON pr.id = r.point_record_id AND pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL
     JOIN v_reflection_eligible_penalties e ON e.point_record_id = pr.id
     JOIN students s ON s.core_student_id = pr.core_student_id
     LEFT JOIN v_discipline_students ds ON ds.legacy_student_id = s.id
     left join lateral (
       select b.id as batch_id, b.notice_day, e.grade
       from discipline.seondo_notice_entries e
       join discipline.seondo_notice_batches b on b.id = e.batch_id and b.published_at is not null
       where e.reflection_id = r.id and not e.is_double
     ) issued on true
     left join lateral (
       select max(b.notice_day) as notice_day
       from discipline.seondo_notice_entries e
       join discipline.seondo_notice_batches b on b.id = e.batch_id and b.published_at is not null
       where e.reflection_id = r.id
     ) last_notice on true;

-- Weekly records are finalized by the due date of the second submission and survive
-- a subsequent late submission. A week belongs to the month in which it closes.
create function private.seondo_finalize(p_now timestamptz)
returns void language plpgsql set search_path = '' as $$
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
      where d.training_at >= greatest(policy_start, period.week_start::timestamp at time zone 'Asia/Seoul')
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
$$;

create function private.get_seondo_settlements(p_kind text, p_period date)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  lead boolean := coalesce(private.current_admin_is_lead(), false);
  result jsonb;
begin
  if auth.uid() is null or p_kind not in ('WEEKLY','MONTHLY') or p_kind is null
    or not (lead or (p_kind = 'MONTHLY' and exists (
      select from discipline.seondo_committee_recipients r where r.user_id = auth.uid()
    ))) then
    raise exception '결산 조회 권한이 필요합니다.';
  end if;

  select jsonb_build_object('period_start', c.period_start, 'closes_at', c.closes_at,
     'delivered_at', i.delivered_at,
     'students', case when p_kind = 'WEEKLY' then coalesce((
      select jsonb_agg(jsonb_build_object('name', t.student_name, 'grade', t.grade, 'homeroom', t.homeroom,
        'net', t.weekly_net, 'reasons', t.reasons) order by t.grade, t.homeroom, t.student_name)
      from discipline.seondo_weekly_training t where t.week_start = c.period_start
     ), '[]'::jsonb) else coalesce((
      select jsonb_agg(jsonb_build_object('name', m.student_name, 'grade', m.grade, 'homeroom', m.homeroom,
        'count', m.training_count) order by m.grade, m.homeroom, m.student_name)
      from discipline.seondo_monthly_committee m where m.month_start = c.period_start
     ), '[]'::jsonb) end)
  into result
  from discipline.seondo_closures c
  left join discipline.seondo_committee_inbox i on i.month_start = c.period_start and i.user_id = auth.uid()
  where c.kind = p_kind and (p_period is null or c.period_start =
    date_trunc(case when p_kind = 'WEEKLY' then 'week' else 'month' end, p_period::timestamp)::date)
    and (lead or i.user_id is not null)
  order by c.period_start desc limit 1;

  return result;
end;
$$;

create function public.get_seondo_settlements(p_kind text, p_period date default null)
returns jsonb language sql stable set search_path = '' as $$
  select private.get_seondo_settlements(p_kind, p_period)
$$;

create function private.can_read_seondo_committee()
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and (private.current_admin_is_lead() or exists (
    select from discipline.seondo_committee_recipients r where r.user_id = auth.uid()
  ))
$$;

create function public.can_read_seondo_committee()
returns boolean language sql stable set search_path = '' as $$
  select private.can_read_seondo_committee()
$$;

-- Client roles may only use explicitly granted functions; the cron function and
-- allocation worker run as the migration owner.
revoke all on function private.seondo_following_school_day(date, integer), private.seondo_deadline(date, integer, boolean),
  private.seondo_merit_valid(date, date), private.seondo_prepare_notice(bigint, timestamptz, timestamptz),
  private.seondo_notice_action(boolean), private.seondo_notice_action_at(boolean, timestamptz), private.seondo_finalize(timestamptz), private.get_seondo_settlements(text, date),
  private.can_read_seondo_committee(), public.seondo_notice_action(boolean), public.get_seondo_notice(date),
  public.get_seondo_settlements(text, date), public.can_read_seondo_committee()
  from public, anon, authenticated;

-- Existing security-invoker views are read by staff/admin/service-role paths.
grant execute on function private.seondo_following_school_day(date, integer),
  private.seondo_deadline(date, integer, boolean)
  to authenticated, service_role;
grant select on discipline.seondo_policy, discipline.seondo_holidays,
  discipline.seondo_notice_batches, discipline.seondo_notice_entries, discipline.seondo_closures,
  discipline.seondo_weekly_training, discipline.seondo_monthly_committee to service_role;

grant execute on function private.seondo_notice_action(boolean), private.get_seondo_settlements(text, date),
  private.can_read_seondo_committee(), public.seondo_notice_action(boolean), public.get_seondo_notice(date),
  public.get_seondo_settlements(text, date), public.can_read_seondo_committee()
  to authenticated;

select cron.schedule('daniels-scale-seondo-settlements', '59 * * * *',
  'select private.seondo_finalize(now())');

-- Existing dashboard consumers keep their row shape but use the latest finalized
-- weekly and monthly results after cutover. Raw weekly points remain available.
create or replace view public.v_student_summary with (security_invoker = true) as
with policy as (
  select exists (select from discipline.seondo_policy where starts_at <= now()) as active,
    (select max(period_start) from discipline.seondo_closures where kind = 'WEEKLY') as latest_week,
    (select max(period_start) from discipline.seondo_closures where kind = 'MONTHLY') as latest_month
), month_counts as (
  select core_student_id, count(*)::integer as training_count
  from discipline.seondo_weekly_training
  where date_trunc('month', (week_start + 6)::timestamp) = date_trunc('month', private.kst_today()::timestamp)
  group by core_student_id
)
select s.id, s.name, s.grade, s.created_at, s.updated_at, s.positive_points, s.negative_points,
  s.weekly_penalty_points, s.monthly_penalty_points, s.weekly_record_count, s.punishment,
  case when p.active then array_remove(array_remove(s.statuses, '체력훈련 대상'), '징계위원회 대상') ||
    array_remove(array[
      case when w.core_student_id is not null then '체력훈련 대상' end,
      case when m.core_student_id is not null then '징계위원회 대상' end
    ], null)
  else s.statuses end as statuses,
  s.core_student_id, s.student_no, s.homeroom, s.weekly_positive_points, s.weekly_net_penalty_points,
  case when p.active then w.core_student_id is not null else s.physical_training_required end as physical_training_required,
  s.settlement_period_id, s.settlement_period_label, s.settlement_starts_on, s.settlement_positive_points,
  s.settlement_penalty_points, s.settlement_net_penalty_points,
  case when p.active then coalesce(mc.training_count, 0) else s.physical_training_weeks end as physical_training_weeks,
  case when p.active then m.core_student_id is not null else s.committee_required end as committee_required,
  case when p.active then coalesce(w.reasons, array[]::text[]) else s.physical_training_reasons end as physical_training_reasons
from public.v_student_summary_core_shadow s
cross join policy p
left join discipline.seondo_weekly_training w on w.week_start = p.latest_week and w.core_student_id = s.core_student_id
left join discipline.seondo_monthly_committee m on m.month_start = p.latest_month and m.core_student_id = s.core_student_id
left join month_counts mc on mc.core_student_id = s.core_student_id;

-- Reuse the existing authorized extension operation. For published cases, base
-- the extension on the posting date and the same school calendar as the deadlines.
create or replace function public.extend_reflection_to_next_day(p_reflection_id integer, p_reason text)
returns timestamptz language plpgsql set search_path = '' as $$
declare
  v_rec record;
  v_target timestamptz;
begin
  if auth.uid() is null or private.current_admin_role() is distinct from 'SEONDO' then
    raise exception '선도부 권한이 필요합니다.';
  end if;
  select r.*, pr.recorded_at, s.grade, issued.notice_day into v_rec
  from public.reflection_records r
  join public.point_records pr on pr.id = r.point_record_id
  join public.students s on s.core_student_id = pr.core_student_id
  left join lateral (
    select b.notice_day from discipline.seondo_notice_entries e
    join discipline.seondo_notice_batches b on b.id = e.batch_id
    where e.reflection_id = r.id and not e.is_double and b.published_at is not null
  ) issued on true
  where r.id = p_reflection_id and pr.deleted_at is null and pr.superseded_by_import_id is null;
  if not found then raise exception '반성문 기록을 찾을 수 없습니다.'; end if;
  if v_rec.grade <= 6 then raise exception '초등은 익일 등교 규칙을 사용합니다.'; end if;
  if v_rec.submitted then raise exception '이미 제출됐습니다.'; end if;
  v_target := greatest(v_rec.due_at, case when v_rec.notice_day is not null
    then private.seondo_deadline(v_rec.notice_day, v_rec.grade, true)
    else private.reflection_extension_due(v_rec.recorded_at) end);
  update public.reflection_records
  set due_at = v_target, submission_deadline = (v_target at time zone 'Asia/Seoul')::date,
    deadline_changed_by = auth.uid(), deadline_change_reason = nullif(btrim(p_reason), '')
  where id = p_reflection_id;
  return v_target;
end;
$$;
