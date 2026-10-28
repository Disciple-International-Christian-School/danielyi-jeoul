# Study Planner → DICS Core Migration Plan

**Language / 언어:** [English](STUDY_PLANNER_MIGRATION_PLAN.md) | [한국어](STUDY_PLANNER_MIGRATION_PLAN.ko.md)

> Working plan, September 25, 2026. Define dependency order, identity mappings, validation, and rollback before copying data. Preserve the source SP service throughout preparation.

## 1. Source and target

Legacy SP owns public.students/staff/terms/weeks/time_blocks/entry_windows/subject_tags/term_goals/week_plans/week_goals/plan_items/item_records/block_records/task_templates/teacher_comments. Its student and staff IDs equal external SP Auth UUIDs.

Core reuses `core.students` and `core.academic_terms`; the learning-domain tables move under study_planner. Do not duplicate student or term masters.

## 2. Identity contracts

Student: verified SP student_no → Core student_no → canonical Core UUID. Preserve the external SP Auth UUID in `core.external_auth_identities`. PINs/passwords are excluded.

Staff: independent `study_planner.staff.id`, optional Core-local `auth_user_id`, and `study_planner.external_staff_identities` for the external SP account. An external project UUID is not a local Auth FK.

## 3. Data-copy dependency order

### Stage A — Preconditions

All source student mappings must be exact or explicitly pending, with zero ambiguous mappings. Obtain source inventory, verify expected-empty/baseline target inventory, confirm the current term and a backup/recovery point, and keep source SP running.

### Stage B — Reference tables

Copy time_blocks, entry_windows, and subject_tags first. Require count parity and preserved PK/code uniqueness.

### Stage C — Academic weeks

Explicitly map legacy terms to Core academic_terms; then copy weeks using verified term/week_no/monday relationships. Never assume the legacy term UUID is the Core term UUID.

### Stage D — Staff

Create independent staff profiles, then external staff identity bridges. Leave local auth_user_id null until Core-local accounts exist.

### Stage E — Student-level roots

Copy term_goals, week_plans, and task_templates only for verified students. Translate every student FK to canonical Core UUID. Do not join on student names.

### Stage F — Plan children

Copy week_goals and plan_items after parent IDs/FKs exist. Preserve source record UUIDs where possible for traceability.

### Stage G — Execution records

Copy item_records and block_records only after 100% parent parity for plan items/week plans.

### Stage H — Comments

Copy teacher_comments last, converting staff FKs to target profile IDs.

## 4. Validation gates

Compare SP `public.v_core_migration_inventory` with Core `public.get_study_planner_target_inventory()` using aggregate counts. Verify student FKs, week-to-Core-term mapping, plan parents, and comment staff. After automatic parity, operators privately sample term goals, weekly plans, items, execution records, and comments in the UI. Do not post sampled identities to Git/issues.

## 5. Cut-over strategy

Keep the source live → shadow copy → parity/read-only verification → Core preview frontend → selected pilot login/workflow → write cut-over → legacy read-only retention → archival/retirement decision.

## 6. Rollback

Before cut-over, source SP remains the operational authority. Do not modify it to fit the target. Roll back/remove only the target batch, retain mappings and error reasons privately, resolve ambiguity, and rerun. Cross-project operations require idempotency because there is no shared transaction.

## 7. Historical blockers, September 25

SP live inventory was pending in the Claude lane. Of 29 pilot students, 28 numbers were enriched and one remained pending due to a name discrepancy. G9-A/B source assignments for 31 students were pending. Core-local student Auth, external student Auth mappings, and copied target content were all zero. This was schema/precondition preparation; live content copy had not started.

## 8. Completion definition

Require verified mappings for every migrated student, count parity, FK checks, sampled UI behavior, verified local/external Auth strategy, no copied PIN/passwords, a frontend using Core student UUIDs, and legacy writes disabled only after a successful pilot. Do not claim integration complete before those gates pass.
