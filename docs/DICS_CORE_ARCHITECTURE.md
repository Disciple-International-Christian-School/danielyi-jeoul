# DICS Core Integrated Schema

**Language / 언어:** [English](DICS_CORE_ARCHITECTURE.md) | [한국어](DICS_CORE_ARCHITECTURE.ko.md)

> For October 28 eligibility changes and G9 responsibility routing, use [current discipline rules](DISCIPLINE_RULES.md). Earlier designs and snapshots below remain dated historical evidence.

> Target architecture, September 25, 2026. This dated design explains Daniel's transition; later [cut-over evidence](DISCIPLINE_CORE_CUTOVER.md) supersedes transitional status statements.

## 1. One student master

One student has one canonical `core.students.id`. Domain tables reference that UUID; do not create separate study_planner/discipline/computer_lab/assessment student masters.

## 2. Student identity and login identity

`core.students.id` is school identity; `auth.users.id` is login identity. Core students have UUID PK, school number, nullable local Auth FK, name, optional necessary birth_date/gender, and is_active. A student can exist without a login. SP's original `students.id = auth.users.id` must therefore be separated.

## 3. Grades and classes belong to terms

Use students → enrollments → academic_terms/classes. A student can be G9-A in Fall and G10 in a later term without overwriting placement history. Current placement is derived from current-term enrollment.

## 4. Domain ownership

| Schema | Responsibilities |
| --- | --- |
| core | students, academic_terms, classes, enrollments |
| study_planner | term_goals, week_plans, plan_items, progress |
| discipline | point_items, point_records, reflections, punishments, settlement_periods, audit_logs |
| computer_lab | checkins, sessions, device_logs |
| assessment | tests, responses, results |

These are target responsibilities; the actual physical table location is defined by migrations. Every domain student FK should reference `core.students(id)`.

## 5. Public access boundary

Internal schemas expose selected public views/RPCs to the frontend. For example, `core.students` → `public.v_core_current_students` → Daniel's Scale. Exclude DOB/gender from a discipline projection that does not require them.

## 6. Daniel's transition

The original public point/punishment student_id fields referenced integer `public.students.id`. The target is canonical UUID identity for discipline records and reflection joins.

1. Create Core students/terms/classes/enrollments.
2. Promote the existing operational minimal roster: generate a UUID per legacy row and corresponding Core row. Do not reimport private spreadsheets through Git SQL. Enrich numbers/Auth/classes/DOB/gender only from verified sources.
3. Add `public.students.core_student_id` and verify all mappings. Name-only matching is insufficient.
4. Move point/punishment writes, reflection reads, and settlement calculations to UUID FKs after verification.
5. Retire the legacy student master role; preserve only necessary compatibility.

The final physical FK change is recorded in the [cut-over document](DISCIPLINE_CORE_CUTOVER.md); legacy numeric routes and the roster bridge are separate compatibility concerns.

## 7. Study Planner and Auth namespaces

SP and Core run in different Supabase projects. An external SP auth.users UUID cannot directly populate a Core-local Auth FK merely because both are UUID strings.

During migration, external Auth → `core.external_auth_identities` → `core.students.id`. The bridge records source_system, source_project_ref, external_user_id as an external identifier, and canonical student_id. It never stores PIN/password values.

After Core-local login provisioning, Core auth.users → optional `core.students.auth_user_id` → canonical student UUID → domain records. External Auth remains migration provenance; new domain FKs refer to Core students.

## 8. PINs

A student number is a login identifier; a PIN is a credential. Do not create `core.students.pin`. Credential management belongs to Supabase Auth/provisioning.

## 9. Minimum disclosure

Daniel projections normally expose student_id, student_no, name, grade, and homeroom. They do not need birth_date, gender, or auth_user_id. Core can hold more information than any one application may read.

## 10. RLS

The database enforces access. Students access their own identity/domain data in student-facing apps; SEONDO accesses its discipline scope; SASAENG accesses sanction responsibilities; teacher/admin access follows role. Integrated apps should use individual Auth plus domain roles rather than shared accounts.

## 11. Query discipline

Avoid select('*') in production. Select required columns, paginate, aggregate server-side, index access paths, prefer event-driven refresh, and do not poll whole tables.

## 12. Historical foundation checkpoint

The operations-foundation branch had bootstrapped 180 Core UUIDs/bridges; one 2026-FALL term, 13 classes, 144 non-G9 enrollments, 31 G9 placements pending, 28 verified SP numbers, an external Auth bridge, and NET/settlement/reflection/audit foundations. Remaining work at that time was G9 source verification, school numbering policy, and SP Auth mapping. The later discipline cut-over does not by itself prove SP migration completion.
