-- 2026-09-25
-- Tighten department-merit read scope to the SEONDO domain.
--
-- Lead-only RPCs remain the only write path. Regular SEONDO accounts may read
-- department status for operational awareness; SASAENG accounts do not need
-- department membership/rule access.

drop policy if exists core_departments_read_discipline_admin on core.departments;
create policy core_departments_read_seondo on core.departments
  for select to authenticated
  using (private.current_admin_role() = 'SEONDO');

drop policy if exists core_department_memberships_read_discipline_admin
  on core.department_memberships;
create policy core_department_memberships_read_seondo
  on core.department_memberships
  for select to authenticated
  using (private.current_admin_role() = 'SEONDO');

drop policy if exists discipline_department_merit_rules_read_admin
  on discipline.department_merit_rules;
create policy discipline_department_merit_rules_read_seondo
  on discipline.department_merit_rules
  for select to authenticated
  using (private.current_admin_role() = 'SEONDO');

-- Reject a rule version that attempts to back-date itself before a newer
-- existing version. Historical rule timelines should be monotonic.
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
  v_latest_start date;
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

  select max(effective_from)
  into v_latest_start
  from discipline.department_merit_rules
  where department_id = v_department_id;

  if v_latest_start is not null
     and p_effective_from < v_latest_start
     and not exists (
       select 1
       from discipline.department_merit_rules
       where department_id = v_department_id
         and effective_from = p_effective_from
     ) then
    raise exception '기존 최신 규칙보다 앞선 날짜로 새 규칙을 추가할 수 없습니다.';
  end if;

  update discipline.department_merit_rules
  set effective_to = p_effective_from - 1,
      is_active = false
  where department_id = v_department_id
    and is_active
    and effective_from < p_effective_from
    and (effective_to is null or effective_to >= p_effective_from);

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

revoke all on function public.create_department_with_merit_rule(text, text, int, text, date)
  from public, anon;
grant execute on function public.create_department_with_merit_rule(text, text, int, text, date)
  to authenticated;
