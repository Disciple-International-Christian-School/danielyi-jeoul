# Study Planner → DICS Core Migration Runbook

**Language / 언어:** [English](SP_CORE_MIGRATION_RUNBOOK.md) | [한국어](SP_CORE_MIGRATION_RUNBOOK.ko.md)

> Status: preparation
>
> Goal: move Study Planner domain data from the legacy SP Supabase project into the DICS Core project without breaking the existing SP service or duplicating student identity.

## 1. Source and target

Legacy SP project:

    project ref: wqvtgrcwiumglohbybih

Target DICS Core project:

    project ref: jgrzsfomcwfiukkaqtos

Target identity:

    core.students.id
    = canonical student UUID

    core.students.student_no
    = school-wide human identifier

    core.students.auth_user_id
    = optional login UUID provisioned in the DICS Core Supabase project

    core.external_auth_identities
    = legacy/external Auth identities from other projects

Target domain:

    study_planner.*

## 2. Non-negotiable rules

- Do not copy PINs into ordinary tables.
- Do not commit student mappings or PII to Git.
- Do not use name alone as the final identity match.
- Do not shut down legacy SP before target behavior is verified.
- Preserve existing UUID primary keys for SP domain rows where possible.
- Treat Auth UUID as login identity, not canonical student identity.
- Use Core academic terms instead of creating a second term master.
- Every migration phase must have a before/after row-count check.

## 3. Phase A — Source inventory

Collect non-PII counts from live SP:

    students
    staff
    terms
    weeks
    time_blocks
    entry_windows
    subject_tags
    term_goals
    week_plans
    week_goals
    plan_items
    item_records
    block_records
    task_templates
    teacher_comments

Also confirm:

- current schema differs from committed migrations or not,
- active vs inactive student rows,
- known test/developer student_no values,
- orphan FK count,
- current Auth-linked student count.

Output may contain aggregate counts only in Git/Issue.

## 4. Phase B — Identity mapping

For each real SP student:

Source:

    SP student UUID
    student_no
    name
    grade
    homeroom

Target:

    core.students.id
    core.students.student_no
    core.external_auth_identities
    later: core.students.auth_user_id for Core-local Auth

Mapping policy:

1. exclude known test/developer accounts by explicit student_no rule,
2. match using verified school identifier when available,
3. use name/grade/homeroom only as supporting evidence,
4. require manual review for ambiguity,
5. store the confirmed Core UUID in SP bridge column,
6. write student_no into Core only after uniqueness checks,
7. store the legacy SP Auth UUID in core.external_auth_identities,
8. provision core.students.auth_user_id only after the login is recreated/migrated into the Core project's Auth namespace.

Validation:

    mapped real SP students == expected real SP students
    duplicate student_no == 0
    duplicate external SP identity == 0
    duplicate Core-local auth_user_id == 0
    ambiguous rows == 0 before data migration

## 5. Phase C — Reference data

Migrate/reference:

- time_blocks
- entry_windows
- subject_tags

Preserve codes/UUIDs.

Validate exact row counts and unique keys.

## 6. Phase D — Academic time reconciliation

Legacy SP terms must map to core.academic_terms.

For the current production semester:

    2026-FALL
    2026-08-19 ~ 2027-01-21

SP weeks then reference the Core term UUID.

Do not duplicate a semantically identical term in study_planner.

## 7. Phase E — Student-domain data copy

Recommended dependency order:

    term_goals
        ↓
    week_plans
        ↓
    week_goals
    plan_items
        ↓
    item_records
    block_records
    teacher_comments

task_templates can be copied after subject_tags and student mapping.

For student FK conversion:

    legacy SP auth UUID
        ↓ bridge
    core student UUID
        ↓
    study_planner.*.student_id

## 8. Phase F — Data validation

For every table:

- source row count,
- target row count,
- missing FK count,
- duplicate unique-key count.

Behavior checks:

- one mapped student can load existing term goals,
- week plan statuses match,
- plan items preserve dates/time blocks,
- item records preserve status/minutes/from-card/window,
- teacher comments resolve to staff,
- no student can read another student's data after RLS is added.

## 9. Phase G — API/RLS cut-over

Only after copied data validates:

1. during migration, do not treat the external SP Auth UUID as Core auth.uid(),
2. provision/migrate student login identities into DICS Core Auth,
3. implement Study Planner RLS against the resulting Core-local core.students.auth_user_id,
4. expose public views/RPCs as needed,
5. point a staging SP frontend at DICS Core,
6. run side-by-side behavior tests,
7. move production frontend only after verification.

## 10. Phase H — Legacy retirement decision

Do not immediately delete the old SP project.

Recommended progression:

    live source
    → read-only fallback
    → archived backup
    → retirement decision

Retirement requires:

- target data complete,
- Auth flow complete,
- no unexplained count mismatch,
- school workflow tested through at least one normal operating cycle.

## 11. Evidence to preserve for the final development report

For each phase record:

- date/time,
- source counts,
- target counts,
- discovered exception,
- decision,
- migration/commit reference,
- CI result,
- production validation,
- rollback method if relevant.

This keeps the final story evidence-based rather than reconstructed from memory.
