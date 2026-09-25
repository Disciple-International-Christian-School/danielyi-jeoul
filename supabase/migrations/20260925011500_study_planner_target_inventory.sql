-- 2026-09-25
-- Privacy-safe target inventory for SP -> DICS Core migration verification.
--
-- The study_planner target schema is intentionally default-deny via RLS.
-- This lead-only SECURITY DEFINER function exposes counts only so migration
-- source/target parity can be checked without exposing student plans/comments.

create or replace function public.get_study_planner_target_inventory()
returns table(entity text, row_count bigint)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.current_admin_is_lead() then
    raise exception '선도부장 권한이 필요합니다.';
  end if;

  return query
  select *
  from (
    values
      ('staff',                     (select count(*)::bigint from study_planner.staff)),
      ('external_staff_identities', (select count(*)::bigint from study_planner.external_staff_identities)),
      ('weeks',                     (select count(*)::bigint from study_planner.weeks)),
      ('time_blocks',               (select count(*)::bigint from study_planner.time_blocks)),
      ('entry_windows',             (select count(*)::bigint from study_planner.entry_windows)),
      ('subject_tags',              (select count(*)::bigint from study_planner.subject_tags)),
      ('term_goals',                (select count(*)::bigint from study_planner.term_goals)),
      ('week_plans',                (select count(*)::bigint from study_planner.week_plans)),
      ('week_goals',                (select count(*)::bigint from study_planner.week_goals)),
      ('plan_items',                (select count(*)::bigint from study_planner.plan_items)),
      ('item_records',              (select count(*)::bigint from study_planner.item_records)),
      ('block_records',             (select count(*)::bigint from study_planner.block_records)),
      ('task_templates',            (select count(*)::bigint from study_planner.task_templates)),
      ('teacher_comments',          (select count(*)::bigint from study_planner.teacher_comments))
  ) as inventory(entity, row_count);
end;
$$;

revoke all on function public.get_study_planner_target_inventory() from public;
revoke all on function public.get_study_planner_target_inventory() from anon;
grant execute on function public.get_study_planner_target_inventory() to authenticated;

comment on function public.get_study_planner_target_inventory() is
  'Lead-only aggregate row counts for verifying SP migration parity. Returns no student/staff/content data.';
