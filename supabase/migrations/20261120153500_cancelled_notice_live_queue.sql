-- Omit cancelled source records from notices; never use frozen print rows as a live action queue.
create or replace function public.get_seondo_notice(p_day date)
returns jsonb language sql stable set search_path = '' as $$
  with batch as (
    select b.* from discipline.seondo_notice_batches b where b.notice_day=p_day
  ), policy as (select starts_at from discipline.seondo_policy where singleton),
  live as (
    select to_jsonb(c)-'source_batch_id' as entry
    from private.seondo_open_notice(now()) c
    where p_day=private.kst_today()
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
      and p.deleted_at is null and p.superseded_by_import_id is null
    join public.v_discipline_students s on s.core_student_id=e.core_student_id
    left join public.v_reflections v on v.id=r.id
    left join discipline.seondo_notice_entries canonical on canonical.reflection_id=r.id
      and not canonical.is_double and canonical.source_batch_id is null
    where e.pages>0 and (p_day<>private.kst_today() or not r.submitted)
  )
  select jsonb_build_object(
    'notice_day',p_day::text,
    'blocked_by_unpublished_day',(select min(notice_day)::text from discipline.seondo_notice_batches
      where published_at is null and notice_day<p_day and p_day=private.kst_today()),
    'active',coalesce((select starts_at<=now() from policy),false),
    'managed_date',coalesce((select (starts_at at time zone 'Asia/Seoul')::date<=p_day from policy),false),
    'batch',(select jsonb_build_object('day',notice_day,'cutoff_at',cutoff_at,'published_at',published_at) from batch),
    'entries',coalesce((select jsonb_agg(entry order by (entry->>'grade')::int,entry->>'homeroom',entry->>'student_name',entry->>'reflection_id') from frozen),'[]'::jsonb),
    'live_entries',case when p_day=private.kst_today() then coalesce((select jsonb_agg(entry) from live),'[]'::jsonb) else null end,
    'pending_after_cutoff_count',case when p_day=private.kst_today() and exists(select 1 from batch) then
      (select count(*) from live l where not exists(
        select 1 from discipline.seondo_notice_entries e join batch b on b.id=e.batch_id
        where e.reflection_id=(l.entry->>'reflection_id')::integer)) else 0 end,
    'preview_entries',coalesce((select jsonb_agg(entry order by (entry->>'grade')::int,entry->>'homeroom',entry->>'student_name',entry->>'reflection_id') from live where not exists(select 1 from batch)),'[]'::jsonb)
  )
$$;

