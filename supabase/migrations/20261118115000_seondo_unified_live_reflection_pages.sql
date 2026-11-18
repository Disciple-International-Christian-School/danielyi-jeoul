-- Read-only estimate and official cutoff share the SAME merit allocation algorithm.
-- Preview never persists allocations, reflection pages, deadlines or notice rows.
-- Cutoff uses the returned allocations to freeze the exact same calculation.

-- Narrow definer helper: expose only the already-consumed quantity for a merit.
-- Do not grant authenticated direct SELECT on the allocation ledger.
create or replace function private.seondo_merit_allocated(p_merit_id integer)
returns integer language plpgsql stable security definer set search_path = '' as $function$
begin
  if auth.uid() is null or not exists (
    select 1 from public.admins a
    where a.user_id = auth.uid() and a.is_active and a.role::text = 'SEONDO'
  ) then
    raise exception '선도부 계정 권한이 필요합니다.';
  end if;
  return coalesce((
    select sum(a.points) from discipline.seondo_merit_allocations a
    where a.merit_id = p_merit_id
  ), 0)::integer;
end;
$function$;

revoke all on function private.seondo_merit_allocated(integer)
from public, anon, authenticated;
grant execute on function private.seondo_merit_allocated(integer)
to authenticated, service_role;

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
      p.item, p.recorded_at, p.core_student_id,
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
    due_at := private.seondo_deadline(cutoff_day, penalty.grade, false);
    allocations := result_allocations;
    return next;
  end loop;
end;
$function$;

-- The cutover and read-only preview use identical per-penalty allocation results.
create or replace function private.seondo_prepare_notice(p_batch_id bigint, p_cutoff timestamptz, p_start timestamptz)
returns void language plpgsql set search_path = '' as $function$
declare
  record_row record;
  allocation_row record;
begin
  for record_row in select * from private.seondo_calculate_notice(p_start, p_cutoff) loop
    for allocation_row in
      select t.merit_id, t.points
      from jsonb_to_recordset(record_row.allocations) as t(merit_id integer, points integer)
    loop
      insert into discipline.seondo_merit_allocations (reflection_id, merit_id, points)
      values (record_row.reflection_id, allocation_row.merit_id, allocation_row.points);
    end loop;

    insert into discipline.seondo_notice_entries (
      batch_id, reflection_id, core_student_id, grade, homeroom, student_name,
      item, occurred_on, pages, due_at
    ) values (
      p_batch_id, record_row.reflection_id, record_row.core_student_id,
      record_row.grade, record_row.homeroom, record_row.student_name,
      record_row.item, record_row.occurred_on, record_row.pages, record_row.due_at
    );
  end loop;
end;
$function$;

create or replace function public.get_seondo_notice(p_day date)
returns jsonb language sql stable set search_path = '' as $function$
  with batch as (
    select b.* from discipline.seondo_notice_batches b
    where b.notice_day = p_day
       or (b.published_at is null and p_day = private.kst_today())
    order by (b.notice_day = p_day) desc limit 1
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
  ),
  preview as (
    select * from current_preview
    union all
    select * from carried
  )
  select jsonb_build_object(
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
          case when b.published_at is null and not e.is_double
            then private.seondo_deadline(greatest(b.notice_day, private.kst_today()), e.grade, false)
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

-- Existing endpoint is already restricted by the application session and RLS.
-- Invoker helper reads no records beyond current authorized discipline visibility.
revoke all on function private.seondo_calculate_notice(timestamptz,timestamptz)
  from public, anon;
grant execute on function private.seondo_calculate_notice(timestamptz,timestamptz)
  to authenticated, service_role;
