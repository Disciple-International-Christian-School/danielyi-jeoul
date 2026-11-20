-- Keep first submission deadlines independent of printing/publication.
-- Only definitions and snapshot provenance change; no student record is rewritten.
alter table discipline.seondo_notice_entries
  add column source_batch_id bigint references discipline.seondo_notice_batches(id);
create index seondo_notice_entries_source_batch on discipline.seondo_notice_entries(source_batch_id);
drop index discipline.seondo_single_initial_notice;
create unique index seondo_single_initial_notice
  on discipline.seondo_notice_entries(reflection_id)
  where not is_double and source_batch_id is null;

create or replace function private.seondo_calculate_notice(p_start timestamptz, p_cutoff timestamptz)
returns table(
  reflection_id integer, point_record_id integer, core_student_id uuid,
  student_id integer, student_name text, grade integer, homeroom text,
  item text, occurred_on date, points integer, pages integer,
  due_at timestamptz, allocations jsonb
)
language plpgsql stable set search_path = '' as $function$
declare
  penalty record;
  credit record;
  used_merits jsonb := '{}'::jsonb;
  used_here integer;
  applied integer;
  pages_left integer;
  result_allocations jsonb;
  cutoff_day date := (p_cutoff at time zone 'Asia/Seoul')::date;
begin
  for penalty in
    select r.id as reflection_id, p.id as point_record_id, p.points,
      p.item, p.recorded_at, p.core_student_id, r.due_at as original_due_at,
      greatest(p.created_at, p.recorded_at::timestamp at time zone 'Asia/Seoul') as effective_at,
      s.legacy_student_id, s.grade, s.homeroom, s.name
    from public.point_records p
    join public.reflection_records r on r.point_record_id = p.id
    join public.v_discipline_students s on s.core_student_id = p.core_student_id
    where p.type = 'NEGATIVE'
      and p.deleted_at is null and p.superseded_by_import_id is null
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
    result_allocations := '[]'::jsonb;
    for credit in
      select m.id, m.points - private.seondo_merit_allocated(m.id) as available
      from public.point_records m
      where m.core_student_id = penalty.core_student_id and m.type = 'POSITIVE'
        and m.deleted_at is null and m.superseded_by_import_id is null
        and greatest(m.created_at, m.recorded_at::timestamp at time zone 'Asia/Seoul') >= p_start
        and greatest(m.created_at, m.recorded_at::timestamp at time zone 'Asia/Seoul') < p_cutoff
        and greatest(m.created_at, m.recorded_at::timestamp at time zone 'Asia/Seoul') <= penalty.effective_at
        and private.seondo_merit_valid(
          (greatest(m.created_at, m.recorded_at::timestamp at time zone 'Asia/Seoul')
             at time zone 'Asia/Seoul')::date,
          (penalty.effective_at at time zone 'Asia/Seoul')::date
        )
      order by greatest(m.created_at, m.recorded_at::timestamp at time zone 'Asia/Seoul'), m.id
    loop
      exit when pages_left = 0;
      used_here := coalesce((used_merits->>(credit.id::text))::integer, 0);
      applied := least(pages_left, greatest(credit.available - used_here, 0));
      if applied > 0 then
        used_merits := jsonb_set(used_merits, array[credit.id::text], to_jsonb(used_here + applied), true);
        result_allocations := result_allocations || jsonb_build_array(
          jsonb_build_object('merit_id', credit.id, 'points', applied));
        pages_left := pages_left - applied;
      end if;
    end loop;

    reflection_id := penalty.reflection_id;
    point_record_id := penalty.point_record_id;
    core_student_id := penalty.core_student_id;
    student_id := penalty.legacy_student_id;
    student_name := penalty.name;
    grade := penalty.grade;
    homeroom := penalty.homeroom;
    item := penalty.item;
    occurred_on := penalty.recorded_at;
    points := penalty.points;
    pages := pages_left;
    due_at := penalty.original_due_at;
    allocations := result_allocations;
    return next;
  end loop;
end;
$function$;


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
join discipline.seondo_notice_batches b on b.id = e.batch_id
join public.reflection_records r on r.id = e.reflection_id
join public.point_records pr on pr.id = r.point_record_id
  and pr.deleted_at is null and pr.superseded_by_import_id is null
left join public.v_weekly_scores_core_shadow w on w.core_student_id = e.core_student_id
  and w.week_start = date_trunc('week', e.occurred_on::timestamp)::date
where not e.is_double and e.source_batch_id is null and e.pages > 0;

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
       join discipline.seondo_notice_batches b on b.id = e.batch_id
       where e.reflection_id = r.id and not e.is_double and e.source_batch_id is null
     ) issued on true
     left join lateral (
       select max(b.notice_day) as notice_day
       from discipline.seondo_notice_entries e
       join discipline.seondo_notice_batches b on b.id = e.batch_id
       where e.reflection_id = r.id
     ) last_notice on true;

-- Second submission follows the first deadline's school day, never today's date.
create or replace function private.seondo_second_deadline(p_first timestamptz, p_grade integer)
returns timestamptz language sql stable set search_path = '' as $$
  select (private.seondo_following_school_day((p_first at time zone 'Asia/Seoul')::date, 1)
    + case when p_grade <= 6 then time '08:20' else time '17:00' end) at time zone 'Asia/Seoul'
$$;
revoke all on function private.seondo_second_deadline(timestamptz,integer) from public, anon;
grant execute on function private.seondo_second_deadline(timestamptz,integer) to authenticated, service_role;

-- One live queue supplies preview and cutoff, including never-printed older records.
create or replace function private.seondo_open_notice(p_time timestamptz)
returns table(reflection_id integer, point_record_id integer, core_student_id uuid,
  student_id integer, student_name text, grade integer, homeroom text, item text,
  occurred_on date, points integer, pages integer, is_double boolean, due_at timestamptz,
  first_due_at timestamptz, double_due_at timestamptz, source_batch_id bigint)
language sql stable set search_path = '' as $$
  with pending as (
    select c.reflection_id, c.point_record_id, c.core_student_id, c.student_id,
      c.student_name,c.grade,c.homeroom,c.item,c.occurred_on,c.points,c.pages,
      c.due_at as first_due_at,
      private.seondo_second_deadline(c.due_at,c.grade) as double_due_at,
      null::bigint as source_batch_id
    from discipline.seondo_policy policy,
      lateral private.seondo_calculate_notice(policy.starts_at,p_time) c
    where c.pages>0
    union all
    select v.id,v.point_record_id,v.core_student_id,v.student_id,v.student_name,
      v.grade,v.homeroom,v.item,v.recorded_at,v.points,v.reflection_pages,v.due_at,
      case when v.seondo_managed then private.seondo_second_deadline(v.due_at,v.grade)
        else v.double_submit_deadline end,
      (select e.batch_id from discipline.seondo_notice_entries e
       where e.reflection_id=v.id and not e.is_double and e.source_batch_id is null)
    from public.v_reflections v
    where v.is_current_student and not v.submitted and v.reflection_pages>0
      and (v.seondo_managed or v.due_at<p_time)
  )
  select p.reflection_id,p.point_record_id,p.core_student_id,p.student_id,p.student_name,
    p.grade,p.homeroom,p.item,p.occurred_on,p.points,
    p.pages * case when p.first_due_at<p_time then 2 else 1 end,
    p.first_due_at<p_time,
    case when p.first_due_at<p_time then p.double_due_at else p.first_due_at end,
    p.first_due_at,p.double_due_at,p.source_batch_id
  from pending p
$$;
revoke all on function private.seondo_open_notice(timestamptz) from public, anon;
grant execute on function private.seondo_open_notice(timestamptz) to authenticated, service_role;

create or replace function public.get_seondo_notice(p_day date)
returns jsonb language sql stable set search_path = '' as $$
  with batch as (
    select b.* from discipline.seondo_notice_batches b where b.notice_day=p_day
  ), policy as (select starts_at from discipline.seondo_policy where singleton),
  live as (
    select to_jsonb(c)-'source_batch_id' as entry
    from private.seondo_open_notice(now()) c
    where p_day=private.kst_today() and not exists(select 1 from batch)
  ), frozen as (
    select jsonb_build_object(
      'reflection_id',e.reflection_id,'point_record_id',r.point_record_id,
      'core_student_id',e.core_student_id,'student_id',s.legacy_student_id,
      'points',p.points,'student_name',e.student_name,'grade',e.grade,
      'homeroom',e.homeroom,'item',e.item,'occurred_on',e.occurred_on,
      'pages',case when not e.is_double and e.due_at < case when p_day=private.kst_today() then now() else b.cutoff_at end
        then e.pages*2 else e.pages end,
      'is_double',e.is_double or (e.due_at < case when p_day=private.kst_today() then now() else b.cutoff_at end),
      'first_due_at',r.due_at,
      'double_due_at',case when canonical.batch_id is not null
        then private.seondo_second_deadline(r.due_at,e.grade) else v.double_submit_deadline end,
      'due_at',case when not e.is_double and e.due_at < case when p_day=private.kst_today() then now() else b.cutoff_at end
        then private.seondo_second_deadline(e.due_at,e.grade) else e.due_at end
    ) as entry
    from discipline.seondo_notice_entries e join batch b on b.id=e.batch_id
    join public.reflection_records r on r.id=e.reflection_id
    join public.point_records p on p.id=r.point_record_id
    join public.v_discipline_students s on s.core_student_id=e.core_student_id
    left join public.v_reflections v on v.id=r.id
    left join discipline.seondo_notice_entries canonical on canonical.reflection_id=r.id
      and not canonical.is_double and canonical.source_batch_id is null
    where e.pages>0
  )
  select jsonb_build_object(
    'notice_day',p_day::text,
    'blocked_by_unpublished_day',(select min(notice_day)::text from discipline.seondo_notice_batches
      where published_at is null and notice_day<p_day and p_day=private.kst_today()),
    'active',coalesce((select starts_at<=now() from policy),false),
    'managed_date',coalesce((select (starts_at at time zone 'Asia/Seoul')::date<=p_day from policy),false),
    'batch',(select jsonb_build_object('day',notice_day,'cutoff_at',cutoff_at,'published_at',published_at) from batch),
    'entries',coalesce((select jsonb_agg(entry order by (entry->>'grade')::int,entry->>'homeroom',entry->>'student_name',entry->>'reflection_id') from frozen),'[]'::jsonb),
    'preview_entries',coalesce((select jsonb_agg(entry order by (entry->>'grade')::int,entry->>'homeroom',entry->>'student_name',entry->>'reflection_id') from live),'[]'::jsonb)
  )
$$;

create or replace function private.seondo_notice_action_at(p_publish boolean,p_time timestamptz)
returns void language plpgsql set search_path = '' as $$
declare
  local_day date;
  policy_start timestamptz;
  action_time timestamptz;
  current_batch discipline.seondo_notice_batches%rowtype;
begin
  if auth.uid() is null or not coalesce(private.current_admin_is_lead(),false) then
    raise exception '선도부장 권한이 필요합니다.';
  end if;
  select starts_at into policy_start from discipline.seondo_policy where singleton for update;
  action_time:=coalesce(p_time,clock_timestamp());
  local_day:=(action_time at time zone 'Asia/Seoul')::date;
  if policy_start is null or action_time<policy_start then
    raise exception '새 선도부 규정의 적용 시각이 도래하지 않았습니다.';
  end if;
  select * into current_batch from discipline.seondo_notice_batches where notice_day=local_day;
  if current_batch.published_at is not null then return; end if;
  if not p_publish then
    if current_batch.id is null then
      insert into discipline.seondo_notice_batches(notice_day,cutoff_at,cutoff_by)
      values(local_day,action_time,auth.uid()) returning * into current_batch;
      perform private.seondo_prepare_notice(current_batch.id,action_time,policy_start);
      -- Carry copies have explicit provenance and cannot conflict with the one canonical initial.
      -- Existing initial pages and allocations are reused, never charged a second time.
      insert into discipline.seondo_notice_entries(batch_id,reflection_id,core_student_id,
        grade,homeroom,student_name,item,occurred_on,pages,is_double,due_at,source_batch_id)
      select current_batch.id,c.reflection_id,c.core_student_id,c.grade,c.homeroom,
        c.student_name,c.item,c.occurred_on,c.pages,c.is_double,c.due_at,c.source_batch_id
      from private.seondo_open_notice(action_time) c
      where c.source_batch_id is distinct from current_batch.id
      on conflict(batch_id,reflection_id) do nothing;
    end if;
    return;
  end if;
  if current_batch.id is null then raise exception '먼저 출력 기준을 확정해 주세요.'; end if;
  if (action_time at time zone 'Asia/Seoul')::time>=time '17:00' and exists(
    select 1 from discipline.seondo_notice_entries e
    join public.reflection_records r on r.id=e.reflection_id
    where e.batch_id=current_batch.id and not e.is_double and e.grade>=7 and e.pages>0
      and r.due_at>=action_time
  ) then raise exception '중고등 당일 제출 기한인 17시 전에 게시를 확정해 주세요.'; end if;
  -- Printing/publication acknowledges a snapshot; it does not restart any submission clock.
  update discipline.seondo_notice_batches set published_at=action_time,published_by=auth.uid()
  where id=current_batch.id;
end;
$$;
