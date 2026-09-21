-- daniels-scale: business logic (helpers, views, triggers, RPCs)
-- Ported from danielyi-jeoul/artifacts/api-server/src/routes/school.ts with fixes:
--   * week/month windows in Asia/Seoul (the Express version used UTC)
--   * adds the two statuses missing from the Express build:
--     처분 선택 필요 (spec §14) and 귀가금지 조건 충족 (spec §16)
-- Helper functions live in `private` so they never surface under /rest/v1/rpc.
-- NOTE: plpgsql bodies store schema references as text — always schema-qualify.

-- ---------------------------------------------------------------- date helpers (Asia/Seoul, weeks start Monday)
create or replace function private.kst_today()
returns date
language sql
stable
as $$ select (now() at time zone 'Asia/Seoul')::date $$;

create or replace function private.kst_week_start()
returns date
language sql
stable
as $$ select date_trunc('week', (now() at time zone 'Asia/Seoul'))::date $$;

create or replace function private.kst_month_start()
returns date
language sql
stable
as $$ select date_trunc('month', (now() at time zone 'Asia/Seoul'))::date $$;

grant usage on schema private to authenticated;
grant execute on function private.kst_today(), private.kst_week_start(), private.kst_month_start() to authenticated;

-- ---------------------------------------------------------------- triggers
-- 선생님 재량 벌점: 1–5 only, server-enforced (spec §8).
create or replace function private.validate_point_record()
returns trigger
language plpgsql
as $$
begin
  if new.type = 'NEGATIVE' and new.item = '선생님 재량 벌점'
     and (new.points < 1 or new.points > 5) then
    raise exception '선생님 재량 벌점은 1~5점만 선택할 수 있습니다.';
  end if;
  return new;
end;
$$;

create trigger point_records_validate
  before insert or update on public.point_records
  for each row execute function private.validate_point_record();

-- Every NEGATIVE record gets a reflection row, deadline = entry day (spec §10).
create or replace function private.create_reflection_for_penalty()
returns trigger
language plpgsql
as $$
begin
  if new.type = 'NEGATIVE' then
    insert into public.reflection_records (point_record_id, submission_deadline)
    values (new.id, new.recorded_at)
    on conflict (point_record_id) do nothing;
  end if;
  return new;
end;
$$;

create trigger point_records_create_reflection
  after insert on public.point_records
  for each row execute function private.create_reflection_for_penalty();

-- 선생님 재량 벌점 must never carry a fixed score (spec §19).
create or replace function private.validate_point_item()
returns trigger
language plpgsql
as $$
begin
  if new.name = '선생님 재량 벌점' and (new.is_fixed or new.fixed_points is not null) then
    raise exception '선생님 재량 벌점은 고정 점수를 사용할 수 없습니다.';
  end if;
  return new;
end;
$$;

create trigger point_items_validate
  before insert or update on public.point_items
  for each row execute function private.validate_point_item();

-- ---------------------------------------------------------------- views (all security_invoker)
-- Per-student per-week penalty totals. History stays queryable forever because
-- records are soft-deleted, never removed (spec §12).
create view public.v_weekly_penalties
with (security_invoker = true) as
select
  pr.student_id,
  date_trunc('week', pr.recorded_at::timestamp)::date as week_start,
  sum(pr.points)::int as penalty_points,
  count(*)::int as record_count
from public.point_records pr
where pr.type = 'NEGATIVE' and pr.deleted_at is null
group by pr.student_id, date_trunc('week', pr.recorded_at::timestamp)::date;

create view public.v_reflections
with (security_invoker = true) as
select
  r.id,
  r.point_record_id,
  pr.student_id,
  s.name as student_name,
  s.grade,
  pr.item,
  pr.points,
  pr.recorded_at,
  r.submitted,
  r.submission_deadline,
  r.submitted_at,
  case
    when r.submitted then 'SUBMITTED'
    when r.submission_deadline < private.kst_today() then 'DOUBLE'
    else 'MISSING'
  end as status
from public.reflection_records r
join public.point_records pr on pr.id = r.point_record_id and pr.deleted_at is null
join public.students s on s.id = pr.student_id;

create view public.v_point_records
with (security_invoker = true) as
select
  pr.id,
  pr.student_id,
  s.name as student_name,
  pr.type,
  pr.item,
  pr.points,
  pr.recorded_at,
  pr.entered_by_name,
  pr.created_at,
  r.id as reflection_id,
  r.submitted as reflection_submitted,
  r.submission_deadline as reflection_deadline,
  r.submitted_at as reflection_submitted_at,
  case
    when r.id is null then null
    when r.submitted then 'SUBMITTED'
    when r.submission_deadline < private.kst_today() then 'DOUBLE'
    else 'MISSING'
  end as reflection_status
from public.point_records pr
join public.students s on s.id = pr.student_id
left join public.reflection_records r on r.point_record_id = pr.id
where pr.deleted_at is null;

create view public.v_punishments
with (security_invoker = true) as
select
  p.id,
  p.student_id,
  s.name as student_name,
  s.grade,
  p.types,
  p.start_date,
  p.end_date,
  p.entered_by_name,
  (p.violated_at is not null) as violated,
  p.created_at
from public.punishments p
join public.students s on s.id = p.student_id;

-- Dashboard/list rows: cumulative + windowed totals and derived statuses.
-- 상점 and 벌점 are separate columns, never netted (spec §34).
create view public.v_student_summary
with (security_invoker = true) as
with stats as (
  select
    s.id as student_id,
    coalesce(sum(pr.points) filter (where pr.type = 'POSITIVE'), 0)::int as positive_points,
    coalesce(sum(pr.points) filter (where pr.type = 'NEGATIVE'), 0)::int as negative_points,
    coalesce(sum(pr.points) filter (
      where pr.type = 'NEGATIVE' and pr.recorded_at >= private.kst_week_start()
        and pr.recorded_at <= private.kst_today()), 0)::int as weekly_penalty_points,
    coalesce(count(*) filter (
      where pr.type = 'NEGATIVE' and pr.recorded_at >= private.kst_week_start()
        and pr.recorded_at <= private.kst_today()), 0)::int as weekly_record_count,
    coalesce(sum(pr.points) filter (
      where pr.type = 'NEGATIVE' and pr.recorded_at >= private.kst_month_start()
        and pr.recorded_at <= private.kst_today()), 0)::int as monthly_penalty_points
  from public.students s
  left join public.point_records pr on pr.student_id = s.id and pr.deleted_at is null
  group by s.id
),
refl as (
  select
    pr.student_id,
    bool_or(not r.submitted and r.submission_deadline >= private.kst_today()) as has_missing,
    bool_or(not r.submitted and r.submission_deadline < private.kst_today()) as has_double
  from public.reflection_records r
  join public.point_records pr on pr.id = r.point_record_id and pr.deleted_at is null
  group by pr.student_id
),
active_pun as (
  select distinct on (student_id) student_id, types, violated_at
  from public.punishments
  where start_date <= private.kst_today() and end_date >= private.kst_today()
  order by student_id, start_date desc, id desc
),
-- 귀가금지 조건 충족: ≥5 penalty points in each of the 3 most recent weeks
-- (current week and the two before it) — spec §16.
weeks3 as (
  select student_id, count(*)::int as qualifying_weeks
  from public.v_weekly_penalties
  where week_start in (private.kst_week_start(),
                       private.kst_week_start() - 7,
                       private.kst_week_start() - 14)
    and penalty_points >= 5
  group by student_id
)
select
  s.id,
  s.name,
  s.grade,
  s.created_at,
  s.updated_at,
  st.positive_points,
  st.negative_points,
  st.weekly_penalty_points,
  st.monthly_penalty_points,
  st.weekly_record_count,
  case when ap.student_id is not null then array_to_string(ap.types, ', ') end as punishment,
  array_remove(array[
    case when st.weekly_record_count >= 3 or st.weekly_penalty_points >= 8 then '체력훈련 대상' end,
    case when st.monthly_penalty_points >= 20 then '징계위원회 대상' end,
    case when coalesce(r.has_missing, false) then '반성문 미제출' end,
    case when coalesce(r.has_double, false) then '반성문 2배 제출 대상' end,
    case when st.weekly_penalty_points >= 5 and ap.student_id is null then '처분 선택 필요' end,
    case when coalesce(w3.qualifying_weeks, 0) >= 3 then '귀가금지 조건 충족' end
  ], null)
  || case
       when ap.student_id is null then array[]::text[]
       when ap.violated_at is not null then array['귀가금지']
       else ap.types
     end as statuses
from public.students s
join stats st on st.student_id = s.id
left join refl r on r.student_id = s.id
left join active_pun ap on ap.student_id = s.id
left join weeks3 w3 on w3.student_id = s.id
where s.deleted_at is null;

create view public.v_dashboard_counts
with (security_invoker = true) as
select
  (select count(*) from public.students where deleted_at is null)::int as students,
  (select count(*) from public.v_student_summary
    where weekly_penalty_points >= 5 or '체력훈련 대상' = any (statuses))::int as weekly_targets,
  (select count(*) from public.v_reflections where status = 'MISSING')::int as missing_reflections,
  (select count(*) from public.v_reflections where status = 'DOUBLE')::int as double_reflections,
  (select count(distinct student_id) from public.punishments
    where start_date <= private.kst_today() and end_date >= private.kst_today())::int as active_punishments;

-- ---------------------------------------------------------------- RPCs (security invoker — RLS applies)
-- Insert a point record; the reflection row is created by trigger and
-- optionally marked submitted in the same call ("같은 날 반성문 제출" checkbox).
create or replace function public.create_point_record(
  p_student_id int,
  p_type public.point_type,
  p_item text,
  p_points int,
  p_entered_by_name text,
  p_recorded_at date,
  p_reflection_submitted boolean default false
)
returns int
language plpgsql
as $$
declare
  v_id int;
begin
  if not exists (select 1 from public.students
                 where id = p_student_id and deleted_at is null) then
    raise exception '학생을 선택해주세요.';
  end if;

  insert into public.point_records (student_id, type, item, points, entered_by_name, recorded_at)
  values (p_student_id, p_type, p_item, p_points, p_entered_by_name, p_recorded_at)
  returning id into v_id;

  if p_type = 'NEGATIVE' and p_reflection_submitted then
    update public.reflection_records
    set submitted = true, submitted_at = now()
    where point_record_id = v_id;
  end if;

  return v_id;
end;
$$;

create or replace function public.update_point_record(
  p_id int,
  p_item text,
  p_points int,
  p_entered_by_name text,
  p_recorded_at date,
  p_reflection_submitted boolean default null
)
returns int
language plpgsql
as $$
declare
  v_record public.point_records%rowtype;
begin
  update public.point_records
  set item = p_item, points = p_points,
      entered_by_name = p_entered_by_name, recorded_at = p_recorded_at
  where id = p_id and deleted_at is null
  returning * into v_record;

  if v_record.id is null then
    raise exception '기록을 찾을 수 없습니다.';
  end if;

  if v_record.type = 'NEGATIVE' and p_reflection_submitted is not null then
    update public.reflection_records
    set submitted = p_reflection_submitted,
        submitted_at = case when p_reflection_submitted then now() end
    where point_record_id = v_record.id;
  end if;

  return v_record.id;
end;
$$;

-- Punishment registration with the weekly 5+/10+ rules (spec §14–15, §18).
-- The 사생회 admin always chooses manually; the server only validates.
create or replace function public.create_punishment(
  p_student_id int,
  p_types text[],
  p_start_date date,
  p_end_date date,
  p_entered_by_name text
)
returns int
language plpgsql
as $$
declare
  v_weekly int;
  v_id int;
begin
  if not exists (select 1 from public.students
                 where id = p_student_id and deleted_at is null) then
    raise exception '학생을 선택해주세요.';
  end if;

  select coalesce(sum(points), 0) into v_weekly
  from public.point_records
  where student_id = p_student_id and type = 'NEGATIVE' and deleted_at is null
    and recorded_at >= private.kst_week_start()
    and recorded_at <= private.kst_today();

  if v_weekly < 5 then
    raise exception '이번 주 벌점이 5점 이상인 학생만 처분을 등록할 수 있습니다.';
  end if;
  if p_types is null or array_length(p_types, 1) is null then
    raise exception '처분을 선택해주세요.';
  end if;
  if (select count(*) from unnest(p_types))
     <> (select count(distinct t) from unnest(p_types) t) then
    raise exception '처분 유형이 중복되었습니다.';
  end if;
  if exists (select 1 from unnest(p_types) t
             where t not in ('운동금지', '간식금지', '면회금지')) then
    raise exception '처분 유형을 확인해주세요.';
  end if;
  if v_weekly >= 10 and array_length(p_types, 1) <> 2 then
    raise exception '처분 2개를 선택해주세요.';
  end if;
  if v_weekly < 10 and array_length(p_types, 1) <> 1 then
    raise exception '처분을 1개만 선택할 수 있습니다.';
  end if;
  if p_end_date < p_start_date then
    raise exception '처분 종료일은 시작일 이후여야 합니다.';
  end if;

  insert into public.punishments (student_id, types, start_date, end_date, entered_by_name)
  values (p_student_id, p_types, p_start_date, p_end_date, p_entered_by_name)
  returning id into v_id;

  return v_id;
end;
$$;

-- Violation is recorded manually by an authorized admin (spec §17).
create or replace function public.set_punishment_violation(p_id int, p_violated boolean)
returns void
language plpgsql
as $$
begin
  update public.punishments
  set violated_at = case when p_violated then now() end
  where id = p_id;
  if not found then
    raise exception '처분을 찾을 수 없습니다.';
  end if;
end;
$$;
