-- 2026-09-25
-- Weekly department merit automation foundation.
--
-- Membership is school-wide Core data.
-- Merit rules belong to the discipline domain.
-- Automatic point records carry a deterministic source_key so generation is
-- idempotent and auditable.

create table if not exists core.departments (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (char_length(btrim(code)) between 1 and 40),
  check (char_length(btrim(name)) between 1 and 80)
);

create table if not exists core.department_memberships (
  id uuid primary key default gen_random_uuid(),
  department_id uuid not null references core.departments(id) on delete restrict,
  student_id uuid not null references core.students(id) on delete restrict,
  starts_on date not null,
  ends_on date,
  created_at timestamptz not null default now(),
  unique (department_id, student_id, starts_on),
  check (ends_on is null or ends_on >= starts_on)
);

create index if not exists core_department_memberships_student_idx
  on core.department_memberships (student_id);

create index if not exists core_department_memberships_active_idx
  on core.department_memberships (department_id, starts_on, ends_on);

drop trigger if exists core_departments_touch_updated_at on core.departments;
create trigger core_departments_touch_updated_at
  before update on core.departments
  for each row execute function private.touch_updated_at();

create table if not exists discipline.department_merit_rules (
  id uuid primary key default gen_random_uuid(),
  department_id uuid not null references core.departments(id) on delete restrict,
  points int not null check (points between 1 and 20),
  item_label text not null,
  effective_from date not null,
  effective_to date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  check (char_length(btrim(item_label)) between 1 and 120),
  check (effective_to is null or effective_to >= effective_from)
);

create index if not exists discipline_department_merit_rules_active_idx
  on discipline.department_merit_rules (department_id, effective_from, effective_to)
  where is_active;

-- Mark the origin of records. Existing rows become MANUAL.
alter table public.point_records
  add column if not exists source_type text not null default 'MANUAL',
  add column if not exists source_key text;

alter table public.point_records
  drop constraint if exists point_records_source_type_check;

alter table public.point_records
  add constraint point_records_source_type_check
  check (source_type in ('MANUAL', 'DEPARTMENT_WEEKLY', 'SYSTEM'));

create unique index if not exists point_records_source_key_uq
  on public.point_records (source_key)
  where source_key is not null;

comment on column public.point_records.source_type is
  'Origin of the record. MANUAL for human entry; DEPARTMENT_WEEKLY for automatic weekly department merit.';
comment on column public.point_records.source_key is
  'Deterministic idempotency key for system-generated records.';

-- Transitional RLS: Daniel admins can read the department data needed by the
-- current app. Writes remain server/admin-provisioned; no student browser writes.
alter table core.departments enable row level security;
alter table core.department_memberships enable row level security;
alter table discipline.department_merit_rules enable row level security;

drop policy if exists core_departments_read_discipline_admin on core.departments;
create policy core_departments_read_discipline_admin on core.departments
  for select to authenticated
  using (private.current_admin_role() is not null);

drop policy if exists core_department_memberships_read_discipline_admin on core.department_memberships;
create policy core_department_memberships_read_discipline_admin on core.department_memberships
  for select to authenticated
  using (private.current_admin_role() is not null);

drop policy if exists discipline_department_merit_rules_read_admin on discipline.department_merit_rules;
create policy discipline_department_merit_rules_read_admin on discipline.department_merit_rules
  for select to authenticated
  using (private.current_admin_role() is not null);

grant usage on schema discipline to authenticated;
grant select on core.departments, core.department_memberships to authenticated;
grant select on discipline.department_merit_rules to authenticated;

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

grant execute on function public.ensure_weekly_department_merits(date) to authenticated;

create or replace view public.v_department_merit_status
with (security_invoker = true) as
with current_week as (
  select private.kst_week_start() as week_start
)
select
  cw.week_start,
  d.id as department_id,
  d.code as department_code,
  d.name as department_name,
  m.id as membership_id,
  m.student_id as core_student_id,
  cs.student_no,
  cs.name as student_name,
  c.grade::int as grade,
  c.label as homeroom,
  r.points,
  r.item_label,
  pr.id as point_record_id,
  (pr.id is not null) as generated
from current_week cw
join core.department_memberships m
  on m.starts_on <= cw.week_start
 and (m.ends_on is null or m.ends_on >= cw.week_start)
join core.departments d
  on d.id = m.department_id
 and d.is_active
join discipline.department_merit_rules r
  on r.department_id = d.id
 and r.is_active
 and r.effective_from <= cw.week_start
 and (r.effective_to is null or r.effective_to >= cw.week_start)
join core.students cs
  on cs.id = m.student_id
 and cs.is_active
left join core.academic_terms t
  on t.is_current
left join core.enrollments e
  on e.student_id = cs.id
 and e.term_id = t.id
 and e.left_at is null
left join core.classes c
  on c.id = e.class_id
left join public.point_records pr
  on pr.source_key = 'department-weekly:' || m.id::text || ':' || cw.week_start::text
order by d.name, cs.name;

comment on view public.v_department_merit_status is
  'Current-week expected/generated department merit awards for admin review.';
