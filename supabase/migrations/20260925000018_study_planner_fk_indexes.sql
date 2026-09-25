-- 2026-09-25
-- Study Planner shadow-schema FK index hardening.

create index if not exists study_planner_block_records_time_block_idx
  on study_planner.block_records (time_block_id);

create index if not exists study_planner_block_records_window_idx
  on study_planner.block_records (window_code)
  where window_code is not null;

create index if not exists study_planner_item_records_window_idx
  on study_planner.item_records (window_code)
  where window_code is not null;

create index if not exists study_planner_plan_items_subject_idx
  on study_planner.plan_items (subject_tag);

create index if not exists study_planner_plan_items_time_block_idx
  on study_planner.plan_items (time_block_id);

create index if not exists study_planner_task_templates_student_idx
  on study_planner.task_templates (student_id)
  where student_id is not null;

create index if not exists study_planner_task_templates_subject_idx
  on study_planner.task_templates (subject_tag);

create index if not exists study_planner_teacher_comments_staff_idx
  on study_planner.teacher_comments (staff_id);

create index if not exists study_planner_term_goals_term_idx
  on study_planner.term_goals (term_id);

create index if not exists study_planner_week_goals_term_goal_idx
  on study_planner.week_goals (term_goal_id)
  where term_goal_id is not null;
