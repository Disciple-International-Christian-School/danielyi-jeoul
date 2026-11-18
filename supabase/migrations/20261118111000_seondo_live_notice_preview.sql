-- Preview newly entered penalties before the print cutoff without freezing pages,
-- creating notice batches, allocating merits, or changing reflection deadlines.
-- Printed/posted entries continue to come exclusively from the frozen batch.
create or replace function public.get_seondo_notice(p_day date)
returns jsonb language sql stable set search_path = '' as $$
  with batch as (
    select b.*
    from discipline.seondo_notice_batches b
    where b.notice_day = p_day
       or (b.published_at is null and p_day = private.kst_today())
    order by (b.notice_day = p_day) desc
    limit 1
  ),
  policy as (
    select starts_at from discipline.seondo_policy where singleton
  ),
  pending as (
    select
      r.id as reflection_id,
      s.name as student_name,
      s.grade,
      s.homeroom,
      p.item,
      p.recorded_at as occurred_on,
      null::integer as pages,
      false as is_double,
      private.seondo_deadline(p_day, s.grade, false) as due_at
    from public.point_records p
    join public.reflection_records r on r.point_record_id = p.id
    join public.v_discipline_students s on s.core_student_id = p.core_student_id
    cross join policy
    where p_day = private.kst_today()
      and not exists (select 1 from batch)
      and p.type = 'NEGATIVE'
      and p.deleted_at is null
      and p.superseded_by_import_id is null
      and not r.submitted
      and greatest(p.created_at, p.recorded_at::timestamp at time zone 'Asia/Seoul') >= policy.starts_at
      and greatest(p.created_at, p.recorded_at::timestamp at time zone 'Asia/Seoul') <= now()
      and not exists (
        select 1 from discipline.seondo_notice_entries e
        where e.reflection_id = r.id and not e.is_double
      )
  ),
  carried as (
    select
      v.id as reflection_id,
      v.student_name,
      v.grade,
      v.homeroom,
      v.item,
      v.recorded_at as occurred_on,
      v.reflection_pages * 2 as pages,
      true as is_double,
      v.double_submit_deadline as due_at
    from public.v_reflections v
    where p_day = private.kst_today()
      and not exists (select 1 from batch)
      and v.is_current_student
      and not v.submitted
      and v.due_at < now()
      and v.reflection_pages > 0
  ),
  live_preview as (
    select * from pending
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
    ), '[]'::jsonb),
    'preview_entries', coalesce((
      select jsonb_agg(jsonb_build_object(
        'reflection_id', p.reflection_id, 'student_name', p.student_name, 'grade', p.grade,
        'homeroom', p.homeroom, 'item', p.item, 'occurred_on', p.occurred_on,
        'pages', p.pages, 'is_double', p.is_double, 'due_at', p.due_at
      ) order by p.grade, p.homeroom, p.student_name, p.reflection_id)
      from live_preview p
    ), '[]'::jsonb)
  )
$$;
