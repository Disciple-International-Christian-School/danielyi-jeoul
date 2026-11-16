create role anon;
create role authenticated;
create role service_role bypassrls;
create schema auth;
create schema core;
create schema discipline;
create schema private;
create schema cron;
grant usage on schema auth, private, discipline to authenticated, service_role;
create table auth.users (id uuid primary key);
create table core.students (id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
create function private.current_admin_role() returns text language sql stable as $$
  select case when current_setting('test.role',true) = 'lead' then 'SEONDO' else null end
$$;
create function private.current_admin_is_lead() returns boolean language sql stable as $$
  select current_setting('test.role',true) = 'lead'
$$;
create function private.kst_today() returns date language sql stable as $$
  select coalesce(nullif(current_setting('test.today',true),'')::date, (now() at time zone 'Asia/Seoul')::date)
$$;
create function private.reflection_extension_due(p_date date) returns timestamptz language sql immutable as $$
  select (p_date + 1 + time '17:00') at time zone 'Asia/Seoul'
$$;
create function cron.schedule(text,text,text) returns bigint language sql as $$ select 1::bigint $$;
create type public.discipline_scope as enum ('ALL','ELEMENTARY','MIDDLE','HIGH');
create table public.students (id integer primary key, core_student_id uuid not null, grade integer not null, name text, homeroom text);
create table public.point_records (
 id integer primary key, core_student_id uuid not null, created_at timestamptz not null, recorded_at date not null,
 points integer not null, type text not null, item text not null, deleted_at timestamptz, superseded_by_import_id uuid
);
create table public.reflection_records (
 id integer primary key, point_record_id integer references public.point_records(id),
 submitted boolean not null default false, submitted_at timestamptz, due_at timestamptz not null,
 submission_deadline date not null, deadline_change_reason text, deadline_changed_by uuid
);
create view public.v_discipline_students as
  select id as legacy_student_id, core_student_id, name, grade, homeroom from public.students;
create view public.v_weekly_scores_core_shadow as select core_student_id, date_trunc('week',recorded_at::timestamp)::date as week_start,
  sum(case when type = 'POSITIVE' then points else 0 end)::int as positive_points,
  sum(case when type = 'NEGATIVE' then points else 0 end)::int as negative_points,
  sum(case when type = 'NEGATIVE' then points else -points end)::int as net_penalty_points
  from public.point_records where deleted_at is null and superseded_by_import_id is null
  group by 1,2;
create view public.v_student_summary_core_shadow as
select id, name, grade, null::timestamptz as created_at, null::timestamptz as updated_at,
  0 as positive_points, 0 as negative_points, 0 as weekly_penalty_points, 0 as monthly_penalty_points,
  0 as weekly_record_count, null::text as punishment, array[]::text[] as statuses, core_student_id,
  null::text as student_no, homeroom, 0 as weekly_positive_points, 0 as weekly_net_penalty_points,
  false as physical_training_required, null::bigint as settlement_period_id, null::text as settlement_period_label,
  null::date as settlement_starts_on, 0 as settlement_positive_points, 0 as settlement_penalty_points,
  0 as settlement_net_penalty_points, 0 as physical_training_weeks, false as committee_required,
  array[]::text[] as physical_training_reasons
from public.students;
create view public.v_student_summary with (security_invoker=true) as select * from public.v_student_summary_core_shadow;
grant select on all tables in schema public to authenticated, service_role;
