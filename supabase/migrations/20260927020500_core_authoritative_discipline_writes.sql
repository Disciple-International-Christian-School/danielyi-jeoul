-- 2026-09-27
-- Make canonical Core UUID RPCs the authoritative discipline write path.
-- Legacy integer RPCs remain only as compatibility wrappers.

create or replace function public.create_point_record_core(
  p_core_student_id uuid,
  p_type public.point_type,
  p_item text,
  p_points int,
  p_entered_by_name text,
  p_recorded_at date,
  p_reflection_submitted boolean default false
)
returns int
language plpgsql
set search_path = ''
as $$
declare
  v_legacy_student_id int;
  v_id int;
begin
  if private.current_admin_role() <> 'SEONDO' then
    raise exception '선도부 관리자만 점수를 입력할 수 있습니다.';
  end if;

  select s.id
  into v_legacy_student_id
  from public.students s
  where s.core_student_id = p_core_student_id
    and s.deleted_at is null;

  if v_legacy_student_id is null then
    raise exception 'Core 학생에 연결된 생활지도 학생 행을 찾을 수 없습니다.';
  end if;

  insert into public.point_records (
    student_id,
    core_student_id,
    type,
    item,
    points,
    entered_by_name,
    recorded_at
  )
  values (
    v_legacy_student_id,
    p_core_student_id,
    p_type,
    p_item,
    p_points,
    btrim(p_entered_by_name),
    p_recorded_at
  )
  returning id into v_id;

  if p_type = 'NEGATIVE' and p_reflection_submitted then
    update public.reflection_records
    set submitted = true,
        submitted_at = now()
    where point_record_id = v_id;
  end if;

  return v_id;
end;
$$;

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
set search_path = ''
as $$
declare
  v_core_student_id uuid;
begin
  select s.core_student_id
  into v_core_student_id
  from public.students s
  where s.id = p_student_id
    and s.deleted_at is null;

  if v_core_student_id is null then
    raise exception '학생을 선택해주세요.';
  end if;

  return public.create_point_record_core(
    v_core_student_id,
    p_type,
    p_item,
    p_points,
    p_entered_by_name,
    p_recorded_at,
    p_reflection_submitted
  );
end;
$$;

create or replace function public.create_punishment_core(
  p_core_student_id uuid,
  p_types text[],
  p_start_date date,
  p_end_date date,
  p_entered_by_name text
)
returns int
language plpgsql
set search_path = ''
as $$
declare
  v_legacy_student_id int;
  v_weekly int;
  v_id int;
begin
  if private.current_admin_role() <> 'SASAENG' then
    raise exception '사생회 관리자만 처분을 등록할 수 있습니다.';
  end if;

  select s.id
  into v_legacy_student_id
  from public.students s
  where s.core_student_id = p_core_student_id
    and s.deleted_at is null;

  if v_legacy_student_id is null then
    raise exception 'Core 학생에 연결된 생활지도 학생 행을 찾을 수 없습니다.';
  end if;

  select coalesce(sum(pr.points), 0)::int
  into v_weekly
  from public.point_records pr
  where pr.core_student_id = p_core_student_id
    and pr.type = 'NEGATIVE'
    and pr.deleted_at is null
    and pr.recorded_at >= private.kst_week_start()
    and pr.recorded_at <= private.kst_today();

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

  if exists (
    select 1
    from unnest(p_types) t
    where t not in ('운동금지', '간식금지', '면회금지')
  ) then
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

  insert into public.punishments (
    student_id,
    core_student_id,
    types,
    start_date,
    end_date,
    entered_by_name
  )
  values (
    v_legacy_student_id,
    p_core_student_id,
    p_types,
    p_start_date,
    p_end_date,
    btrim(p_entered_by_name)
  )
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.create_punishment(
  p_student_id int,
  p_types text[],
  p_start_date date,
  p_end_date date,
  p_entered_by_name text
)
returns int
language plpgsql
set search_path = ''
as $$
declare
  v_core_student_id uuid;
begin
  select s.core_student_id
  into v_core_student_id
  from public.students s
  where s.id = p_student_id
    and s.deleted_at is null;

  if v_core_student_id is null then
    raise exception '학생을 선택해주세요.';
  end if;

  return public.create_punishment_core(
    v_core_student_id,
    p_types,
    p_start_date,
    p_end_date,
    p_entered_by_name
  );
end;
$$;

create or replace function public.ensure_weekly_department_merits(
  p_week_start date default private.kst_week_start()
)
returns int
language plpgsql
set search_path = ''
as $$
declare
  v_inserted int := 0;
begin
  if private.current_admin_role() <> 'SEONDO' then
    raise exception '선도부 관리자만 부서활동 주간 상점을 생성할 수 있습니다.';
  end if;

  if p_week_start <> date_trunc('week', p_week_start::timestamp)::date then
    raise exception '주 시작일은 월요일이어야 합니다.';
  end if;

  insert into public.point_records (
    student_id,
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
    ls.id,
    m.student_id,
    'POSITIVE'::public.point_type,
    r.item_label,
    r.points,
    'SYSTEM · DEPARTMENT',
    p_week_start,
    'DEPARTMENT_WEEKLY',
    'department-weekly:' || m.id::text || ':' || p_week_start::text
  from core.department_memberships m
  join core.departments d
    on d.id = m.department_id
   and d.is_active
  join discipline.department_merit_rules r
    on r.department_id = m.department_id
   and r.is_active
   and r.effective_from <= p_week_start
   and (r.effective_to is null or r.effective_to >= p_week_start)
  join public.students ls
    on ls.core_student_id = m.student_id
   and ls.deleted_at is null
  where m.starts_on <= p_week_start
    and (m.ends_on is null or m.ends_on >= p_week_start)
    and not exists (
      select 1
      from public.point_records pr
      where pr.source_key = 'department-weekly:' || m.id::text || ':' || p_week_start::text
    );

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$$;

comment on function public.create_point_record_core(uuid, public.point_type, text, int, text, date, boolean) is
  'Authoritative discipline point write path. Canonical Core UUID is the input identity.';
comment on function public.create_point_record(int, public.point_type, text, int, text, date, boolean) is
  'Legacy compatibility wrapper. Resolves integer student id to canonical Core UUID.';
comment on function public.create_punishment_core(uuid, text[], date, date, text) is
  'Authoritative punishment write path. Canonical Core UUID is the input identity.';
comment on function public.create_punishment(int, text[], date, date, text) is
  'Legacy compatibility wrapper. Resolves integer student id to canonical Core UUID.';

revoke all on function public.create_point_record_core(uuid, public.point_type, text, int, text, date, boolean)
  from public, anon;
grant execute on function public.create_point_record_core(uuid, public.point_type, text, int, text, date, boolean)
  to authenticated;

revoke all on function public.create_point_record(int, public.point_type, text, int, text, date, boolean)
  from public, anon;
grant execute on function public.create_point_record(int, public.point_type, text, int, text, date, boolean)
  to authenticated;

revoke all on function public.create_punishment_core(uuid, text[], date, date, text)
  from public, anon;
grant execute on function public.create_punishment_core(uuid, text[], date, date, text)
  to authenticated;

revoke all on function public.create_punishment(int, text[], date, date, text)
  from public, anon;
grant execute on function public.create_punishment(int, text[], date, date, text)
  to authenticated;

revoke all on function public.ensure_weekly_department_merits(date)
  from public, anon;
grant execute on function public.ensure_weekly_department_merits(date)
  to authenticated;
