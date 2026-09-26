-- 2026-09-25
-- Lead-only administration for department memberships and weekly merit rules.
--
-- Operational data is entered through authenticated RPCs and remains in
-- Supabase. No student membership rows or real department rosters belong in Git.

create or replace function public.create_department_with_merit_rule(
  p_code text,
  p_name text,
  p_points int,
  p_item_label text,
  p_effective_from date default private.kst_today()
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_department_id uuid;
begin
  if not private.current_admin_is_lead() then
    raise exception '선도부장 권한이 필요합니다.';
  end if;

  if nullif(btrim(p_code), '') is null
     or nullif(btrim(p_name), '') is null
     or nullif(btrim(p_item_label), '') is null then
    raise exception '부서 코드, 이름, 상점 항목명이 필요합니다.';
  end if;

  if p_points < 1 or p_points > 20 then
    raise exception '주간 상점은 1~20점 범위여야 합니다.';
  end if;

  insert into core.departments (code, name, is_active)
  values (upper(btrim(p_code)), btrim(p_name), true)
  on conflict (code) do update
  set name = excluded.name,
      is_active = true
  returning id into v_department_id;

  -- Close the previously active rule on the day before the new rule begins.
  update discipline.department_merit_rules
  set effective_to = p_effective_from - 1,
      is_active = false
  where department_id = v_department_id
    and is_active
    and effective_from < p_effective_from
    and (effective_to is null or effective_to >= p_effective_from);

  -- If a rule already begins on the same date, update that exact version.
  if exists (
    select 1
    from discipline.department_merit_rules
    where department_id = v_department_id
      and effective_from = p_effective_from
  ) then
    update discipline.department_merit_rules
    set points = p_points,
        item_label = btrim(p_item_label),
        effective_to = null,
        is_active = true
    where department_id = v_department_id
      and effective_from = p_effective_from;
  else
    insert into discipline.department_merit_rules (
      department_id,
      points,
      item_label,
      effective_from,
      is_active
    )
    values (
      v_department_id,
      p_points,
      btrim(p_item_label),
      p_effective_from,
      true
    );
  end if;

  return v_department_id;
end;
$$;

create or replace function public.set_department_student_membership(
  p_department_id uuid,
  p_student_id uuid,
  p_active boolean,
  p_effective_on date default private.kst_today()
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_membership_id uuid;
begin
  if not private.current_admin_is_lead() then
    raise exception '선도부장 권한이 필요합니다.';
  end if;

  if not exists (
    select 1
    from core.departments
    where id = p_department_id
      and is_active
  ) then
    raise exception '활성 부서를 찾을 수 없습니다.';
  end if;

  if not exists (
    select 1
    from core.students
    where id = p_student_id
      and is_active
  ) then
    raise exception '활성 학생을 찾을 수 없습니다.';
  end if;

  if p_active then
    select id into v_membership_id
    from core.department_memberships
    where department_id = p_department_id
      and student_id = p_student_id
      and starts_on <= p_effective_on
      and (ends_on is null or ends_on >= p_effective_on)
    order by starts_on desc
    limit 1;

    if v_membership_id is null then
      insert into core.department_memberships (
        department_id,
        student_id,
        starts_on
      )
      values (
        p_department_id,
        p_student_id,
        p_effective_on
      )
      returning id into v_membership_id;
    end if;
  else
    select id into v_membership_id
    from core.department_memberships
    where department_id = p_department_id
      and student_id = p_student_id
      and starts_on <= p_effective_on
      and (ends_on is null or ends_on >= p_effective_on)
    order by starts_on desc
    limit 1;

    if v_membership_id is null then
      raise exception '현재 활성 소속을 찾을 수 없습니다.';
    end if;

    update core.department_memberships
    set ends_on = greatest(starts_on, p_effective_on)
    where id = v_membership_id;
  end if;

  return v_membership_id;
end;
$$;

create or replace function public.set_department_active(
  p_department_id uuid,
  p_active boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.current_admin_is_lead() then
    raise exception '선도부장 권한이 필요합니다.';
  end if;

  update core.departments
  set is_active = p_active
  where id = p_department_id;

  if not found then
    raise exception '부서를 찾을 수 없습니다.';
  end if;
end;
$$;

-- Admin summary: one row per department with the rule effective today.
create or replace view public.v_department_merit_admin
with (security_invoker = true) as
select
  d.id as department_id,
  d.code,
  d.name,
  d.is_active,
  r.id as rule_id,
  r.points,
  r.item_label,
  r.effective_from,
  r.effective_to,
  (
    select count(*)::int
    from core.department_memberships m
    where m.department_id = d.id
      and m.starts_on <= private.kst_today()
      and (m.ends_on is null or m.ends_on >= private.kst_today())
  ) as current_member_count
from core.departments d
left join lateral (
  select r.*
  from discipline.department_merit_rules r
  where r.department_id = d.id
    and r.effective_from <= private.kst_today()
    and (r.effective_to is null or r.effective_to >= private.kst_today())
  order by r.effective_from desc
  limit 1
) r on true
order by d.name;

create or replace view public.v_department_current_members
with (security_invoker = true) as
select
  m.id as membership_id,
  m.department_id,
  m.student_id as core_student_id,
  cs.student_no,
  cs.name as student_name,
  c.grade::int as grade,
  c.label as homeroom,
  m.starts_on,
  m.ends_on
from core.department_memberships m
join core.students cs
  on cs.id = m.student_id
left join core.academic_terms t
  on t.is_current
left join core.enrollments e
  on e.student_id = cs.id
 and e.term_id = t.id
 and e.left_at is null
left join core.classes c
  on c.id = e.class_id
where m.starts_on <= private.kst_today()
  and (m.ends_on is null or m.ends_on >= private.kst_today())
order by c.grade nulls last, c.label nulls last, cs.name;

revoke all on function public.create_department_with_merit_rule(text, text, int, text, date)
  from public, anon;
grant execute on function public.create_department_with_merit_rule(text, text, int, text, date)
  to authenticated;

revoke all on function public.set_department_student_membership(uuid, uuid, boolean, date)
  from public, anon;
grant execute on function public.set_department_student_membership(uuid, uuid, boolean, date)
  to authenticated;

revoke all on function public.set_department_active(uuid, boolean)
  from public, anon;
grant execute on function public.set_department_active(uuid, boolean)
  to authenticated;

grant select on public.v_department_merit_admin to authenticated;
grant select on public.v_department_current_members to authenticated;
