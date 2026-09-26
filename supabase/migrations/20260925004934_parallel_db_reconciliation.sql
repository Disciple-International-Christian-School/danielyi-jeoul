-- 2026-09-25
-- Reconcile live-only parallel changes back into version-controlled migrations.
--
-- Background:
-- Parallel development applied current_term_setup / fix_current_term_setup_runtime
-- and lead_audit_view directly to the live Supabase project. This migration
-- records those structural changes in Git without committing student PII.
--
-- It is deliberately idempotent.

-- ---------------------------------------------------------------------------
-- 2026 Fall current term
-- ---------------------------------------------------------------------------

insert into core.academic_terms (
  code,
  name,
  starts_on,
  ends_on,
  is_current
)
values (
  '2026-FALL',
  '2026 Fall',
  date '2026-08-19',
  date '2027-01-21',
  true
)
on conflict (code) do update
set name = excluded.name,
    starts_on = excluded.starts_on,
    ends_on = excluded.ends_on,
    is_current = true;

-- Keep exactly this term current during reconciliation.
update core.academic_terms
set is_current = false
where code <> '2026-FALL'
  and is_current;

-- ---------------------------------------------------------------------------
-- Class shells
--
-- G9 is intentionally split into A/B but students are NOT auto-assigned.
-- The private G9 roster must decide the section.
-- ---------------------------------------------------------------------------

with term as (
  select id
  from core.academic_terms
  where code = '2026-FALL'
)
insert into core.classes (term_id, grade, section, label)
select term.id, v.grade, v.section, v.label
from term
cross join (
  values
    (1::smallint,  ''::text, 'G1'::text),
    (2::smallint,  ''::text, 'G2'::text),
    (3::smallint,  ''::text, 'G3'::text),
    (4::smallint,  ''::text, 'G4'::text),
    (5::smallint,  ''::text, 'G5'::text),
    (6::smallint,  ''::text, 'G6'::text),
    (7::smallint,  ''::text, 'G7'::text),
    (8::smallint,  ''::text, 'G8'::text),
    (9::smallint,  'A'::text, 'G9-A'::text),
    (9::smallint,  'B'::text, 'G9-B'::text),
    (10::smallint, ''::text, 'G10'::text),
    (11::smallint, ''::text, 'G11'::text),
    (12::smallint, ''::text, 'G12'::text)
) as v(grade, section, label)
on conflict (term_id, grade, section) do update
set label = excluded.label;

-- ---------------------------------------------------------------------------
-- Safe enrollment bootstrap
--
-- For grades other than G9, the legacy Daniel roster already has the grade
-- required to determine the only class shell for that grade.
--
-- G9 is intentionally excluded because section A/B cannot be inferred from
-- grade alone.
-- ---------------------------------------------------------------------------

with term as (
  select id
  from core.academic_terms
  where code = '2026-FALL'
),
targets as (
  select
    cs.id as student_id,
    term.id as term_id,
    c.id as class_id
  from public.students ls
  join core.students cs
    on cs.id = ls.core_student_id
   and cs.is_active
  cross join term
  join core.classes c
    on c.term_id = term.id
   and c.grade = ls.grade
   and c.section = ''
  where ls.deleted_at is null
    and ls.grade <> 9
)
insert into core.enrollments (student_id, term_id, class_id)
select student_id, term_id, class_id
from targets
on conflict (student_id, term_id) do update
set class_id = excluded.class_id,
    left_at = null;

-- ---------------------------------------------------------------------------
-- Lead-facing audit projection
-- ---------------------------------------------------------------------------

create or replace view public.v_discipline_audit_logs
with (security_invoker = true) as
select
  l.id,
  l.actor_user_id,
  coalesce(a.display_name, 'SYSTEM / LEGACY') as actor_name,
  a.role as actor_role,
  l.action,
  l.entity_type,
  l.entity_id,
  l.before_data,
  l.after_data,
  l.created_at
from discipline.audit_logs l
left join public.admins a
  on a.user_id = l.actor_user_id
order by l.created_at desc, l.id desc;

comment on view public.v_discipline_audit_logs is
  'Admin-facing audit projection. Real staff identity comes from authenticated admin profile; legacy/system rows remain explicit.';

grant select on public.v_discipline_audit_logs to authenticated;
