-- 2026-09-25
-- Discipline responsibility scopes for personal admin accounts.
--
-- No real staff/student names are committed here. Existing shared SEONDO
-- account remains ALL + lead for backward compatibility until personal
-- accounts are provisioned.

do $$
begin
  if not exists (select 1 from pg_type where typname = 'discipline_scope') then
    create type public.discipline_scope as enum ('ALL', 'ELEMENTARY', 'MIDDLE', 'HIGH');
  end if;
end $$;

alter table public.admins
  add column if not exists discipline_scope public.discipline_scope,
  add column if not exists is_lead boolean not null default false,
  add column if not exists is_active boolean not null default true;

update public.admins
set discipline_scope = case
  when role = 'SEONDO' then 'ALL'::public.discipline_scope
  else discipline_scope
end
where discipline_scope is null;

-- Legacy shared SEONDO account retains full lead capabilities during migration.
update public.admins
set is_lead = true
where role = 'SEONDO'
  and discipline_scope = 'ALL';

comment on column public.admins.discipline_scope is
  'SEONDO responsibility scope: ELEMENTARY G1-6, MIDDLE G7-9, HIGH G10-12, ALL for lead/shared legacy.';
comment on column public.admins.is_lead is
  'Lead permission for settlement/report coordination. Existing shared SEONDO account remains lead during migration.';
comment on column public.admins.is_active is
  'Soft enable/disable for personal admin accounts.';

create or replace function private.current_admin_scope()
returns public.discipline_scope
language sql
stable
security definer
set search_path = ''
as $$
  select a.discipline_scope
  from public.admins a
  where a.user_id = auth.uid()
    and a.is_active
  limit 1
$$;

create or replace function private.current_admin_is_lead()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select a.is_lead
    from public.admins a
    where a.user_id = auth.uid()
      and a.role = 'SEONDO'
      and a.is_active
    limit 1
  ), false)
$$;

-- Existing helper should ignore disabled accounts.
create or replace function private.current_admin_role()
returns public.admin_role
language sql
stable
security definer
set search_path = ''
as $$
  select a.role
  from public.admins a
  where a.user_id = auth.uid()
    and a.is_active
  limit 1
$$;

-- Settlement ownership belongs to the SEONDO lead.
create or replace function public.start_settlement_period(
  p_starts_on date,
  p_label text
)
returns bigint
language plpgsql
set search_path = ''
as $$
declare
  v_id bigint;
begin
  if not private.current_admin_is_lead() then
    raise exception '선도부장 권한이 필요합니다.';
  end if;

  if exists (select 1 from public.settlement_periods where ends_on is null) then
    raise exception '이미 진행 중인 정산기간이 있습니다.';
  end if;

  insert into public.settlement_periods (label, starts_on)
  values (btrim(p_label), p_starts_on)
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.close_settlement_period(
  p_period_id bigint,
  p_end_date date,
  p_open_next boolean default true,
  p_next_label text default null
)
returns bigint
language plpgsql
set search_path = ''
as $$
declare
  v_period public.settlement_periods%rowtype;
  v_next_id bigint;
begin
  if not private.current_admin_is_lead() then
    raise exception '선도부장 권한이 필요합니다.';
  end if;

  select * into v_period
  from public.settlement_periods
  where id = p_period_id and ends_on is null
  for update;

  if v_period.id is null then
    raise exception '진행 중인 정산기간을 찾을 수 없습니다.';
  end if;

  if p_end_date < v_period.starts_on then
    raise exception '종료일은 시작일보다 빠를 수 없습니다.';
  end if;

  update public.settlement_periods
  set ends_on = p_end_date,
      closed_at = now(),
      closed_by = auth.uid()
  where id = p_period_id;

  if p_open_next then
    insert into public.settlement_periods (label, starts_on)
    values (
      coalesce(nullif(btrim(p_next_label), ''), to_char(p_end_date + 1, 'YYYY-MM-DD') || ' 시작'),
      p_end_date + 1
    )
    returning id into v_next_id;
  end if;

  return v_next_id;
end;
$$;

-- Reflection view now exposes the operational responsibility scope.
create or replace view public.v_reflections
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
    when r.due_at < now() then 'DOUBLE'
    else 'MISSING'
  end as status,
  r.due_at,
  r.deadline_change_reason,
  case
    when s.grade between 1 and 6 then 'ELEMENTARY'::public.discipline_scope
    when s.grade between 7 and 9 then 'MIDDLE'::public.discipline_scope
    else 'HIGH'::public.discipline_scope
  end as assigned_scope
from public.reflection_records r
join public.point_records pr on pr.id = r.point_record_id and pr.deleted_at is null
join public.students s on s.id = pr.student_id;

grant execute on function private.current_admin_scope() to authenticated;
grant execute on function private.current_admin_is_lead() to authenticated;
grant execute on function public.start_settlement_period(date, text) to authenticated;
grant execute on function public.close_settlement_period(bigint, date, boolean, text) to authenticated;
