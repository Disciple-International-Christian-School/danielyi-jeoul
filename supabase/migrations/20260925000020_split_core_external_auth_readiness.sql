-- 2026-09-25
-- Refine Core migration readiness by separating Core-local Auth from
-- external/legacy Auth identities.

create or replace view public.v_core_migration_readiness
with (security_invoker = true) as
with current_term as (
  select id
  from core.academic_terms
  where is_current
  limit 1
),
active_students as (
  select *
  from core.students
  where is_active
)
select
  (select count(*) from core.students)::int as core_total,
  (select count(*) from active_students)::int as active_students,
  (select count(*) from active_students where student_no is not null)::int as student_no_assigned,
  (select count(*) from active_students where auth_user_id is not null)::int as auth_linked,
  (
    select count(distinct eai.student_id)
    from core.external_auth_identities eai
    join active_students s on s.id = eai.student_id
    where eai.is_active
  )::int as external_auth_linked,
  (select count(*) from core.academic_terms)::int as term_count,
  (select count(*) from core.academic_terms where is_current)::int as current_term_count,
  (select count(*) from core.classes)::int as class_count,
  (
    select count(distinct e.student_id)
    from core.enrollments e
    join current_term t on t.id = e.term_id
    join active_students s on s.id = e.student_id
    where e.left_at is null
  )::int as current_enrollment_count,
  (
    select count(*)
    from public.students ls
    where ls.deleted_at is null
      and ls.core_student_id is not null
  )::int as daniel_bridge_count;

create or replace view public.v_core_student_readiness
with (security_invoker = true) as
with current_term as (
  select id
  from core.academic_terms
  where is_current
  limit 1
),
external_auth as (
  select distinct student_id
  from core.external_auth_identities
  where is_active
)
select
  cs.id as core_student_id,
  cs.student_no,
  cs.name,
  ls.grade,
  (cs.student_no is not null) as has_student_no,
  (cs.auth_user_id is not null) as has_auth_link,
  (ea.student_id is not null) as has_external_auth_link,
  (e.student_id is not null) as has_current_enrollment,
  c.label as homeroom,
  case
    when cs.student_no is not null
     and e.student_id is not null
     and (cs.auth_user_id is not null or ea.student_id is not null)
    then 'READY'
    when cs.student_no is not null
      or cs.auth_user_id is not null
      or ea.student_id is not null
      or e.student_id is not null
    then 'PARTIAL'
    else 'CORE_ONLY'
  end as readiness_status
from core.students cs
join public.students ls
  on ls.core_student_id = cs.id
left join current_term t on true
left join core.enrollments e
  on e.student_id = cs.id
 and e.term_id = t.id
 and e.left_at is null
left join core.classes c
  on c.id = e.class_id
left join external_auth ea
  on ea.student_id = cs.id
where cs.is_active
order by ls.grade, cs.name;
