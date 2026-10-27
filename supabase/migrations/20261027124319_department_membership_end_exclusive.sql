-- Membership intervals are [starts_on, ends_on): ending today removes a student today.
CREATE OR REPLACE FUNCTION public.set_department_student_membership(p_department_id uuid, p_student_id uuid, p_active boolean, p_effective_on date DEFAULT private.kst_today())
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_membership_id uuid;
begin
  if not private.current_admin_is_lead() then
    raise exception '선도부장 권한이 필요합니다.';
  end if;

  if p_active and not exists (
    select 1
    from core.departments
    where id = p_department_id
      and is_active
  ) then
    raise exception '활성 부서를 찾을 수 없습니다.';
  end if;

  if p_active and not exists (
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
      and (ends_on is null or ends_on > p_effective_on)
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
      on conflict (department_id,student_id,starts_on) do update set ends_on=null
      returning id into v_membership_id;
    end if;
  else
    select id into v_membership_id
    from core.department_memberships
    where department_id = p_department_id
      and student_id = p_student_id
      and starts_on <= p_effective_on
      and (ends_on is null or ends_on > p_effective_on)
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
$function$;


create or replace view public.v_department_current_members with(security_invoker=true) as
 SELECT m.id AS membership_id,
    m.department_id,
    m.student_id AS core_student_id,
    cs.student_no,
    cs.name AS student_name,
    c.grade::integer AS grade,
    c.label AS homeroom,
    m.starts_on,
    m.ends_on
   FROM core.department_memberships m
     JOIN core.students cs ON cs.id = m.student_id
     LEFT JOIN core.academic_terms t ON t.is_current
     LEFT JOIN core.enrollments e ON e.student_id = cs.id AND e.term_id = t.id AND e.left_at IS NULL
     LEFT JOIN core.classes c ON c.id = e.class_id
  WHERE m.starts_on <= private.kst_today() AND (m.ends_on IS NULL OR m.ends_on > private.kst_today())
  ORDER BY c.grade, c.label, cs.name;

create or replace view public.v_department_merit_admin with(security_invoker=true) as
 SELECT d.id AS department_id,
    d.code,
    d.name,
    d.is_active,
    r.id AS rule_id,
    r.points,
    r.item_label,
    r.effective_from,
    r.effective_to,
    ( SELECT count(*)::integer AS count
           FROM core.department_memberships m
          WHERE m.department_id = d.id AND m.starts_on <= private.kst_today() AND (m.ends_on IS NULL OR m.ends_on > private.kst_today())) AS current_member_count
   FROM core.departments d
     LEFT JOIN LATERAL ( SELECT r_1.id,
            r_1.department_id,
            r_1.points,
            r_1.item_label,
            r_1.effective_from,
            r_1.effective_to,
            r_1.is_active,
            r_1.created_at
           FROM discipline.department_merit_rules r_1
          WHERE r_1.department_id = d.id AND r_1.effective_from <= private.kst_today() AND (r_1.effective_to IS NULL OR r_1.effective_to >= private.kst_today())
          ORDER BY r_1.effective_from DESC
         LIMIT 1) r ON true
  ORDER BY d.name;

create or replace view public.v_department_merit_status with(security_invoker=true) as
 WITH current_week AS (
         SELECT private.kst_week_start() AS week_start
        )
 SELECT cw.week_start,
    d.id AS department_id,
    d.code AS department_code,
    d.name AS department_name,
    m.id AS membership_id,
    m.student_id AS core_student_id,
    cs.student_no,
    cs.name AS student_name,
    c.grade::integer AS grade,
    c.label AS homeroom,
    r.points,
    r.item_label,
    pr.id AS point_record_id,
    pr.id IS NOT NULL AS generated
   FROM current_week cw
     JOIN core.department_memberships m ON m.starts_on <= cw.week_start AND (m.ends_on IS NULL OR m.ends_on > cw.week_start)
     JOIN core.departments d ON d.id = m.department_id AND d.is_active
     JOIN discipline.department_merit_rules r ON r.department_id = d.id AND r.is_active AND r.effective_from <= cw.week_start AND (r.effective_to IS NULL OR r.effective_to >= cw.week_start)
     JOIN core.students cs ON cs.id = m.student_id AND cs.is_active
     LEFT JOIN core.academic_terms t ON t.is_current
     LEFT JOIN core.enrollments e ON e.student_id = cs.id AND e.term_id = t.id AND e.left_at IS NULL
     LEFT JOIN core.classes c ON c.id = e.class_id
     LEFT JOIN point_records pr ON pr.deleted_at is null AND pr.superseded_by_import_id is null AND pr.source_key = ((('department-weekly:'::text || m.id::text) || ':'::text) || cw.week_start::text)
  ORDER BY d.name, cs.name;

CREATE OR REPLACE FUNCTION public.ensure_weekly_department_merits(p_week_start date DEFAULT private.kst_week_start())
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_inserted int := 0;
begin
  if private.current_admin_role() is distinct from 'SEONDO' then
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
    and (m.ends_on is null or m.ends_on > p_week_start)
    and not exists (select 1 from discipline.history_settings h join core.academic_terms t on t.id=h.term_id where h.activated_at is not null and p_week_start+6>=t.starts_on and p_week_start<h.daily_starts_on and ds.grade between h.min_grade and h.max_grade)
    and not exists (
      select 1
      from public.point_records pr
      where pr.source_key = 'department-weekly:' || m.id::text || ':' || p_week_start::text
    )
  on conflict (source_key) where source_key is not null do nothing;

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$function$;


CREATE OR REPLACE FUNCTION private.run_weekly_department_merit_job()
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
    and (m.ends_on is null or m.ends_on > v_week_start)
  on conflict (source_key) where source_key is not null do nothing;

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$function$;
