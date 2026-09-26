-- 2026-09-27
-- Final discipline identity cut-over.
--
-- point_records and punishments now store only canonical core_student_id.
-- Legacy integer IDs remain available only as derived compatibility values
-- through views and wrapper RPCs.

-- ---------------------------------------------------------------------------
-- 1. Preserve aggregate-only pre-drop evidence
-- ---------------------------------------------------------------------------

insert into discipline.core_cutover_evidence (
  stage,
  point_records_total,
  point_records_core_linked,
  point_records_mismatch,
  punishments_total,
  punishments_core_linked,
  punishments_mismatch,
  weekly_legacy_rows,
  weekly_core_rows,
  weekly_mismatches,
  weekly_penalty_legacy_rows,
  weekly_penalty_core_rows,
  weekly_penalty_mismatches,
  settlement_legacy_rows,
  settlement_core_rows,
  settlement_mismatches,
  summary_legacy_rows,
  summary_core_rows,
  summary_mismatches
)
select
  'PRE_LEGACY_COLUMN_DROP',
  fk.point_records_total,
  fk.point_records_core_linked,
  fk.point_records_mismatch,
  fk.punishments_total,
  fk.punishments_core_linked,
  fk.punishments_mismatch,
  calc.weekly_legacy_rows,
  calc.weekly_core_rows,
  calc.weekly_mismatches,
  calc.weekly_penalty_legacy_rows,
  calc.weekly_penalty_core_rows,
  calc.weekly_penalty_mismatches,
  calc.settlement_legacy_rows,
  calc.settlement_core_rows,
  calc.settlement_mismatches,
  summary.legacy_rows,
  summary.core_rows,
  summary.mismatches
from public.v_discipline_core_fk_readiness fk
cross join public.v_discipline_core_calc_parity calc
cross join public.v_student_summary_core_parity summary;

-- ---------------------------------------------------------------------------
-- 2. Reflection trigger: canonical Core UUID only
-- ---------------------------------------------------------------------------

create or replace function private.create_reflection_for_penalty()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_grade int;
  v_due_at timestamptz;
  v_deadline_date date;
begin
  if new.type = 'NEGATIVE' then
    select s.grade
    into v_grade
    from public.students s
    where s.core_student_id = new.core_student_id;

    if v_grade is null then
      raise exception 'Core 학생의 학년 정보를 찾을 수 없습니다.';
    end if;

    if v_grade between 1 and 6 then
      v_due_at := ((new.recorded_at + 1) + time '08:20') at time zone 'Asia/Seoul';
      v_deadline_date := new.recorded_at + 1;
    else
      v_due_at := (new.recorded_at + time '17:00') at time zone 'Asia/Seoul';
      v_deadline_date := new.recorded_at;
    end if;

    insert into public.reflection_records (
      point_record_id,
      submission_deadline,
      due_at
    )
    values (
      new.id,
      v_deadline_date,
      v_due_at
    )
    on conflict (point_record_id) do nothing;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Canonical Core UUID write implementations
-- ---------------------------------------------------------------------------

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
  v_id int;
begin
  if private.current_admin_role() <> 'SEONDO' then
    raise exception '선도부 관리자만 점수를 입력할 수 있습니다.';
  end if;

  if not exists (
    select 1
    from public.v_discipline_students ds
    where ds.core_student_id = p_core_student_id
  ) then
    raise exception '활성 생활지도 학생을 찾을 수 없습니다.';
  end if;

  insert into public.point_records (
    core_student_id,
    type,
    item,
    points,
    entered_by_name,
    recorded_at
  )
  values (
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
  v_weekly int;
  v_id int;
begin
  if private.current_admin_role() <> 'SASAENG' then
    raise exception '사생회 관리자만 처분을 등록할 수 있습니다.';
  end if;

  if not exists (
    select 1
    from public.v_discipline_students ds
    where ds.core_student_id = p_core_student_id
  ) then
    raise exception '활성 생활지도 학생을 찾을 수 없습니다.';
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
    core_student_id,
    types,
    start_date,
    end_date,
    entered_by_name
  )
  values (
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
  join public.v_discipline_students ds
    on ds.core_student_id = m.student_id
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

-- ---------------------------------------------------------------------------
-- 4. Replace live parity views with preserved pre-drop evidence
-- ---------------------------------------------------------------------------

create or replace view public.v_discipline_core_calc_parity
with (security_invoker = true) as
select
  weekly_legacy_rows,
  weekly_core_rows,
  weekly_mismatches,
  weekly_penalty_legacy_rows,
  weekly_penalty_core_rows,
  weekly_penalty_mismatches,
  settlement_legacy_rows,
  settlement_core_rows,
  settlement_mismatches
from public.v_discipline_core_cutover_evidence_latest;

create or replace view public.v_student_summary_core_parity
with (security_invoker = true) as
select
  summary_legacy_rows as legacy_rows,
  summary_core_rows as core_rows,
  summary_mismatches as mismatches
from public.v_discipline_core_cutover_evidence_latest;

-- ---------------------------------------------------------------------------
-- 5. Make readiness Core-native while preserving the frontend shape
-- ---------------------------------------------------------------------------

create or replace view public.v_discipline_core_fk_readiness
with (security_invoker = true) as
select
  (select count(*)::int from public.point_records) as point_records_total,
  (
    select count(*)::int
    from public.point_records
    where core_student_id is not null
  ) as point_records_core_linked,
  (
    select count(*)::int
    from public.point_records pr
    left join public.students s
      on s.core_student_id = pr.core_student_id
    where s.id is null
  ) as point_records_mismatch,
  (select count(*)::int from public.punishments) as punishments_total,
  (
    select count(*)::int
    from public.punishments
    where core_student_id is not null
  ) as punishments_core_linked,
  (
    select count(*)::int
    from public.punishments p
    left join public.students s
      on s.core_student_id = p.core_student_id
    where s.id is null
  ) as punishments_mismatch;

-- ---------------------------------------------------------------------------
-- 6. Remove pre-cutover legacy calculation shadows
-- ---------------------------------------------------------------------------

drop view if exists public.v_student_summary_legacy_shadow;
drop view if exists public.v_settlement_scores_legacy_shadow;
drop view if exists public.v_weekly_penalties_legacy_shadow;
drop view if exists public.v_weekly_scores_legacy_shadow;

-- ---------------------------------------------------------------------------
-- 7. Remove dual-key synchronization and physical integer FKs
-- ---------------------------------------------------------------------------

drop trigger if exists point_records_sync_core_student on public.point_records;
drop trigger if exists punishments_sync_core_student on public.punishments;

drop function if exists private.sync_discipline_core_student_id();

alter table public.point_records
  drop constraint if exists point_records_student_id_fkey;

alter table public.punishments
  drop constraint if exists punishments_student_id_fkey;

alter table public.point_records
  drop column if exists student_id;

alter table public.punishments
  drop column if exists student_id;

comment on column public.point_records.core_student_id is
  'Canonical DICS Core student UUID. Sole physical student identity for discipline point records.';
comment on column public.punishments.core_student_id is
  'Canonical DICS Core student UUID. Sole physical student identity for punishment records.';
