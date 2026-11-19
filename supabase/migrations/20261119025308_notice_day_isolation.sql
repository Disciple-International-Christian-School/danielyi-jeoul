-- Date-isolate printed notices, preserve historical draft snapshots and block
-- unsafe cross-day cutoff/publication. No data rows or point ledgers are updated.
-- A stale unpublished draft must be reviewed separately before a new cutoff.
create or replace function public.get_seondo_notice(p_day date)
returns jsonb language sql stable set search_path = '' as $function$
  with batch as (
    select b.* from discipline.seondo_notice_batches b
    where b.notice_day = p_day
    limit 1
  ),
  policy as (select starts_at from discipline.seondo_policy where singleton),
  current_preview as (
    select c.reflection_id, c.point_record_id, c.core_student_id, c.student_id,
      c.student_name, c.grade, c.homeroom, c.item, c.occurred_on,
      c.points, c.pages, false as is_double, c.due_at
    from policy,
      lateral private.seondo_calculate_notice(policy.starts_at, now()) c
    where p_day = private.kst_today()
      and not exists (select 1 from batch)
      and c.pages > 0
  ),
  -- A previous day's unpublished draft is not a published first notice.
  -- Carry its still-open initial obligations as ordinary pages (not 2x).
  -- Keep the original frozen draft untouched for historical reprinting.
  unpublished_initial as (
    select e.reflection_id, r.point_record_id, e.core_student_id,
      s.id as student_id, e.student_name, e.grade, e.homeroom,
      e.item, e.occurred_on, pr.points, e.pages, false as is_double,
      private.seondo_deadline(p_day, e.grade, false) as due_at
    from discipline.seondo_notice_entries e
    join discipline.seondo_notice_batches b on b.id = e.batch_id
    join public.reflection_records r on r.id = e.reflection_id
    join public.point_records pr on pr.id = r.point_record_id
      and pr.deleted_at is null and pr.superseded_by_import_id is null
    join public.students s on s.core_student_id = e.core_student_id
    join public.v_discipline_students ds on ds.core_student_id = e.core_student_id
    where p_day = private.kst_today()
      and not exists (select 1 from batch)
      and b.notice_day < p_day and b.published_at is null
      and not e.is_double and not r.submitted and e.pages > 0
  ),
  carried as (
    select v.id as reflection_id, v.point_record_id, v.core_student_id,
      v.student_id, v.student_name, v.grade, v.homeroom, v.item,
      v.recorded_at as occurred_on, v.points,
      v.reflection_pages * 2 as pages, true as is_double,
      v.double_submit_deadline as due_at
    from public.v_reflections v
    where p_day = private.kst_today()
      and not exists (select 1 from batch)
      and v.is_current_student and not v.submitted
      and v.due_at < now() and v.reflection_pages > 0
      and not exists (
        select 1 from discipline.seondo_notice_entries ue
        join discipline.seondo_notice_batches ub on ub.id = ue.batch_id
        where ue.reflection_id = v.id
          and not ue.is_double and ub.published_at is null
      )
  ),
  preview as (
    select * from current_preview
    union all
    select * from unpublished_initial
    union all
    select * from carried
  )
  select jsonb_build_object(
    'notice_day', p_day::text,
    'blocked_by_unpublished_day', (
      select min(b.notice_day)::text
      from discipline.seondo_notice_batches b
      where b.published_at is null and b.notice_day < p_day
        and p_day = private.kst_today()
    ),
    'active', coalesce((select starts_at <= now() from policy), false),
    'managed_date', coalesce((select (starts_at at time zone 'Asia/Seoul')::date <= p_day
      from policy), false),
    'batch', (select jsonb_build_object('day', b.notice_day, 'cutoff_at', b.cutoff_at,
      'published_at', b.published_at) from batch b),
    'entries', coalesce((
      select jsonb_agg(jsonb_build_object(
        'reflection_id', e.reflection_id,
        'point_record_id', r.point_record_id,
        'core_student_id', e.core_student_id,
        'student_id', s.id,
        'points', p.points,
        'student_name', e.student_name, 'grade', e.grade,
        'homeroom', e.homeroom, 'item', e.item, 'occurred_on', e.occurred_on,
        'pages', e.pages, 'is_double', e.is_double, 'due_at',
          case when b.published_at is null and b.notice_day = private.kst_today() and not e.is_double
            then private.seondo_deadline(b.notice_day, e.grade, false)
            else e.due_at end
      ) order by e.grade, e.homeroom, e.student_name, e.reflection_id)
      from discipline.seondo_notice_entries e
      join batch b on b.id = e.batch_id
      join public.reflection_records r on r.id = e.reflection_id
      join public.point_records p on p.id = r.point_record_id
      join public.students s on s.core_student_id = e.core_student_id
      where e.pages > 0
    ), '[]'::jsonb),
    'preview_entries', coalesce((
      select jsonb_agg(jsonb_build_object(
        'reflection_id', c.reflection_id, 'point_record_id', c.point_record_id,
        'core_student_id', c.core_student_id, 'student_id', c.student_id,
        'points', c.points, 'student_name', c.student_name, 'grade', c.grade,
        'homeroom', c.homeroom, 'item', c.item, 'occurred_on', c.occurred_on,
        'pages', c.pages, 'is_double', c.is_double, 'due_at', c.due_at
      ) order by c.grade, c.homeroom, c.student_name, c.reflection_id)
      from preview c
    ), '[]'::jsonb)
  )
$function$;

CREATE OR REPLACE FUNCTION private.seondo_notice_action_at(p_publish boolean, p_time timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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

  select * into current_batch from discipline.seondo_notice_batches
    where published_at is null order by notice_day limit 1;
  if found and current_batch.notice_day <> local_day then
    raise exception '이전 날짜(%)의 출력 마감 초안이 게시 대기 중입니다. 현재 날짜(%)에 이전 명단을 확정하거나 게시할 수 없습니다. 해당 초안은 별도 검토가 필요합니다.', current_batch.notice_day, local_day;
  end if;
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
$function$;
