-- Weekly department merits at Monday 00:00 Asia/Seoul (Sunday 15:00 UTC).
-- Keep the authenticated SEONDO RPC as an idempotent recovery path.
create extension if not exists pg_cron with schema pg_catalog;

grant usage on schema cron to postgres;
grant all privileges on all tables in schema cron to postgres;

create or replace function private.run_weekly_department_merit_job()
returns integer
language plpgsql
set search_path = ''
as $function$
declare
  v_week_start date := private.kst_week_start();
  v_inserted integer := 0;
begin
  insert into public.point_records (
    core_student_id,
    type,
    item,
    points,
    entered_by_name,
    recorded_at,
    source_type,
    source_key
  )
  select
    m.student_id,
    'POSITIVE'::public.point_type,
    r.item_label,
    r.points,
    'SYSTEM · DEPARTMENT',
    v_week_start,
    'DEPARTMENT_WEEKLY',
    'department-weekly:' || m.id::text || ':' || v_week_start::text
  from core.department_memberships m
  join core.departments d
    on d.id = m.department_id
   and d.is_active
  join discipline.department_merit_rules r
    on r.department_id = m.department_id
   and r.is_active
   and r.effective_from <= v_week_start
   and (r.effective_to is null or r.effective_to >= v_week_start)
  join public.v_discipline_students ds
    on ds.core_student_id = m.student_id
  where m.starts_on <= v_week_start
    and (m.ends_on is null or m.ends_on >= v_week_start)
  on conflict (source_key) where source_key is not null do nothing;

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$function$;

-- The worker is never exposed through the browser Data API.
revoke all on function private.run_weekly_department_merit_job()
  from public, anon, authenticated, service_role;
grant execute on function private.run_weekly_department_merit_job() to postgres;

comment on function private.run_weekly_department_merit_job() is
  'Generate current KST-week department merits for the postgres-owned Cron job; source_key makes retries idempotent.';

-- This database uses GMT for cron.timezone. Sunday 15:00 UTC is Monday 00:00 KST.
select cron.schedule(
  'department-merits-monday-kst',
  '0 15 * * 0',
  $job$select private.run_weekly_department_merit_job();$job$
);
