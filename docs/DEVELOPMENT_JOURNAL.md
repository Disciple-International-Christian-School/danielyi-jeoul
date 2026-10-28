# Daniel's Scale — Development Journal

**Language / 언어:** [English](DEVELOPMENT_JOURNAL.md) | [한국어](DEVELOPMENT_JOURNAL.ko.md)

> For October 28 eligibility changes and G9 responsibility routing, use [current discipline rules](DISCIPLINE_RULES.md). Earlier designs and snapshots below remain dated historical evidence.

A living engineering record, begun September 25, 2026. It preserves context, discoveries, decisions, implementation, verification, and next steps for school reporting and retrospective use. Student names, PINs, and original rosters do not belong here. Historical checkpoints and repeated section numbers are retained; later entries supersede earlier transitional states.

## 0. When the problem changed
The first goal was practical: replace paper demerit sheets, track reflections and residential-life sanctions, and find weekly follow-up targets. As requirements grew, each school app defined the same student differently. Establishing one student identity across discipline, Study Planner, computer-lab, and assessment systems became the central integration problem.


### Recorded technical detail


```text
Student in the demerit app
Student in Study Planner
Student in the computer lab
Student in placement assessment

These refer to the same person,
but each app defined student identity differently.
```


## 1. From prototype to operational system

A prototype could demonstrate features, but operation required answers about student ownership, settlement boundaries, exact reflection deadlines, authenticated authorship, retention after graduation or transfer, and cross-app identity. The chosen architecture placed school rules and accountability in PostgreSQL views, RPCs, triggers, and RLS behind Supabase Auth and React/Vite. The result began to model school operations rather than merely expose CRUD forms.


### Recorded technical detail


```text
React/Vite
  ↓
Supabase Auth
  ↓
PostgreSQL
Views / RPC / Triggers / RLS
```


## 2. Redefining student identity

Daniel used serial integers; Study Planner used Auth UUIDs. Both worked locally, but a student and a login account are different entities. Elementary students may have no login, and changing authentication must not change the student PK. `core.students.id` became the canonical UUID; `auth_user_id` is optional; `student_no` is the human identifier. A bridge was added to existing Daniel rows and UUIDs were assigned directly, without automatic name matching. The September 25 checkpoint mapped 180/180 rows: 175 active and 5 inactive. Inactive students with discipline history were retained. A current roster and a durable identity registry serve different purposes.


### Recorded technical detail


```text
public.students.id = serial integer
```


```text
students.id = auth.users.id
```


```text
core.students.id
= canonical student UUID

core.students.auth_user_id
= optional login account

core.students.student_no
= school-wide human-readable student number
```


```text
core_student_id
```


```text
legacy student rows 180
        ↓
Core UUID mapping 180 / 180

active   175
inactive   5
```


## 3. A legacy grade constraint blocked expansion

The prototype's `public.students.grade` constraint allowed only G1–G6 although the operational roster covered G1–G12. The transitional constraint was widened. Long-term grade and class placement remained term-based through `academic_terms`, `classes`, and `enrollments`. This reinforced the need to inspect actual data before migrating prototype assumptions.


### Recorded technical detail


```text
core.academic_terms
core.classes
core.enrollments
```


## 4. Replacing calendar-month settlement

DICS home-leave cycles are usually three weeks but may be two; calendar months were the wrong boundary. An administrator closes the open settlement when the operational event occurs. Not closing it means accumulation continues. `settlement_periods` permits only one open period. Raw merits and demerits remain separate; NET is demerits minus merits. Weekly physical-training eligibility is at least three negative incidents or NET at least 8. Settlement committee eligibility is at least three eligible weeks or NET at least 20.


### Recorded technical detail


```text
OPEN settlement
      ↓
Continue accumulation
      ↓
Actual home leave
      ↓
Administrator closes period
      ↓
Next settlement
```


```text
NET = Demerits - Merits
```


## 5. Reflection deadlines need a time

A date-only deadline could not express G7–G12 same-day 17:00, discretionary 21:00 extensions, or G1–G6 next-school-morning submission. Adding `due_at timestamptz` distinguished a pending submission from an overdue double-submission requirement.


### Recorded technical detail


```text
submission_deadline date
```


```text
due_at timestamptz
```


## 6. Finding the KST date bug

`new Date().toISOString().slice(0, 10)` returns a UTC date. Between 00:00 and 08:59 in Korea it could default the morning workflow to yesterday. Operational defaults were made explicit in `Asia/Seoul`. Timezone is part of the business rule.


### Recorded technical detail


```text
new Date().toISOString().slice(0, 10)
```


```text
Asia/Seoul
```


## 7. Printing completes the workflow

Class announcements, weekly physical-training lists, and teacher reports often end on paper. `v_daily_discipline_notice` and `v_weekly_discipline_report` supplied projections, with date/class filters, grouping, A4 print styles, and hidden navigation. Notices and reports were treated as workflow outputs rather than incidental print buttons.

## 8. Designing for morning batch entry

Paper sheets are entered consecutively in the morning. Continuous entry supports name/number/class search, Enter selection for a single result, retained item/points/date/operator fields, student-only reset, automatic refocus, and six recent saves. Photo OCR was deferred because review UI, privacy, and retention policies were not yet ready; faster manual entry addressed the immediate workload.


### Recorded technical detail


```text
P1 = Fast manual batch entry
P2 = Photo recognition plus human review
```


## 9. Idempotency before scheduling

Weekly department merits needed deterministic results before a scheduler. Membership and effective-date rules drive an idempotent RPC and deterministic source keys. At this checkpoint the frontend ensured missing Monday records on first dashboard access. A scheduler could be added later without changing the duplicate-prevention contract; eventual correctness mattered as much as execution time.


### Recorded technical detail


```text
core.departments
core.department_memberships

discipline.department_merit_rules

point_records.source_type
point_records.source_key
```


```text
ensure_weekly_department_merits()
```


## 10. Individual identities and responsibility scopes

Shared SEONDO/SASAENG accounts could not represent elementary, middle, high-school, and lead responsibilities. `admins.discipline_scope`, `is_lead`, and `is_active` were introduced. The shared SEONDO account retained ALL plus lead during transition. Reflection and notice screens follow scope; weekly reporting and settlement controls require lead access. Settlement RPCs enforce authorization themselves.


### Recorded technical detail


```text
SEONDO
SASAENG
```


```text
admins.discipline_scope
  ELEMENTARY
  MIDDLE
  HIGH
  ALL

admins.is_lead
admins.is_active
```


```text
ALL + lead
```


## 11. Authenticated provenance replaces a typed name

`entered_by_name` is a string, not proof of authorship. DB triggers now set `created_by` and `updated_by` from `auth.uid()`. The old field remains transitional display compatibility. `discipline.audit_logs` records before/after JSON for point records, reflections, punishments, and settlement periods on INSERT/UPDATE/DELETE. Historical authors were not guessed: unknown actors remain null.


### Recorded technical detail


```text
entered_by_name = "..."
```


```text
created_by = auth.uid()
updated_by = auth.uid()
```


```text
unknown = null
```


## 12. CI changed the completion standard

The first `npm ci` → typecheck → Vite build run failed on an unused TypeScript import. Small as it was, the failure changed the working definition of done: write, validate, pass, then proceed. Subsequent frontend changes used PR/push CI.


### Recorded technical detail


```text
npm ci
  ↓
typecheck
  ↓
Vite build
```


```text
Write code
  ↓
Automated validation
  ↓
Pass
  ↓
Next stage
```


## 13. A view replacement exposed an API contract

PostgreSQL rejected a Core-aware `v_student_summary` replacement that changed existing column structure. Existing leading columns and their order were preserved; Core/NET columns were appended. Backward compatibility was treated as a product requirement.

## 14. Coordinating Claude and GPT through GitHub

Study Planner already had a Claude Code workflow. Shared branches and an explicit coordination issue recorded branch, PR, files, DB changes, next steps, and blockers, rather than depending on access to another chat. Claude identified that a new identity bridge view changed the expected view count from four to five. GPT corrected it and documented explicit handling of non-student test accounts rather than relying only on `is_active`. Shared repository state and a handoff contract made the collaboration reproducible.


### Recorded technical detail


```text
main
├─ claude/*
└─ gpt/*
```


## 15. September 25 readiness snapshot

Core identities existed, but the common directory was incomplete: no student numbers or Auth links, terms/classes/enrollments, departments/memberships/rules, or individual provisioning. There were two admin accounts, one active discipline record, and no audit records. The active grade distribution totaled 175. Domain rules had matured faster than shared-directory enrichment.


### Recorded technical detail


```text
Core students                 180
student_no assigned             0
Auth linked                     0

academic terms                  0
current terms                   0
classes                         0
enrollments                     0

departments                     0
department memberships          0
department merit rules          0

admin accounts                  2
active discipline records       1
audit records                   0
```


```text
G1   10
G2    7
G3    9
G4    9
G5   14
G6   15
G7   19
G8   19
G9   31
G10  21
G11  16
G12   5
----------------
Total 175
```


```text
student_no / Auth
academic term / class / enrollment
department memberships / rules
personal admin provisioning
```


## 16. Questions for the next phase

The next work required safe Fall term provisioning; verified G9 A/B placement; SP number/Auth enrichment; reconciliation without name-based identity assumptions; private department membership loading; evidence for integer-FK retirement; and a personal-account rollout without interrupting school operation.

## 17. A reportable engineering narrative

The project moved from a fast prototype through operational-data inspection, compatible migration, Core identity, automation, auditability, and cross-project integration. The substantive contribution is the translation of operational exceptions and accountability requirements into a shared data model. Reports must connect that narrative to evidence and identify the actual contributor's work.

## 18. Current-term provisioning without guessing

The school calendar established 2026-FALL as August 19, 2026 through January 21, 2027. Core had 180 students but no terms, classes, or enrollments. G1–8 and G10–12 could be enrolled from verified grades. G9 required A/B source assignments, so its 31 students were deliberately left pending. Automation stopped at the boundary of available evidence.


### Recorded technical detail


```text
core.students       180
academic_terms        0
classes               0
enrollments           0
```


```text
2026-FALL
starts_on = 2026-08-19
ends_on   = 2027-01-21
```


```text
G1–8     → Enroll automatically from verified current grade
G10–12   → Enroll automatically from verified current grade

G9       → Do not assign automatically
           Assign after verifying A/B roster
```


## 19. A runtime-only database bug

The term RPC migrated and frontend CI passed, but execution failed because `ROW_COUNT` was referenced like an ordinary variable. PL/pgSQL requires `GET DIAGNOSTICS variable = ROW_COUNT`. Statement rollback left terms/classes/enrollments at zero; no partial placement survived. A correction migration, `20260925004655_fix_current_term_setup_runtime.sql`, preserved applied history. Build success and runtime verification are separate quality checks.


### Recorded technical detail


```text
v_classes_created := v_classes_created + row_count
```


```text
GET DIAGNOSTICS variable = ROW_COUNT;
```


```text
terms        0
classes      0
enrollments  0
```


```text
20260925004655_fix_current_term_setup_runtime.sql
```


## 20. Current-term application result

After correction, the same RPC created 13 classes and 144 enrollments for 2026-FALL; 31 G9 students remained pending. Class shells covered G1–8, G9-A/B, and G10–12. Core now represented student → term → class rather than only a UUID registry.


### Recorded technical detail


```text
2026-FALL
2026-08-19 ~ 2027-01-21

classes created        13
enrollments created   144
G9 pending              31
```


```text
G1
G2
G3
G4
G5
G6
G7
G8
G9-A
G9-B
G10
G11
G12
```


```text
non-G9 144 students: enrollment completed
G9      31 students: A/B verification pending
```


```text
Student identity
  ↓
2026 Fall
  ↓
Class
```


## 21. A temporary Core provisioning console

A SEONDO-lead console exposed term code/name/dates, initialization, class/enrollment readiness, pending G9 counts, and individual A/B assignment. Its purpose was interim provisioning until a separate Core Admin application could own students, terms, classes, enrollments, and shared identity. Daniel's Scale should remain focused on discipline.


### Recorded technical detail


```text
Daniel's Scale
→ discipline domain only

DICS Core Admin
→ students / terms / classes / enrollment / shared identity
```


## 22. Updated September 25 readiness

The recorded state was 180 Core students, 175 active, one current term, 13 classes, 144 enrollments, and 31 pending G9 placements. Student numbers, Auth links, departments, memberships, and rules were still empty. Verified data linkage, rather than additional feature breadth, became the next bottleneck.


### Recorded technical detail


```text
Core students                 180
active students               175

current academic term           1
classes                        13
active enrollments            144
G9 pending                     31

student_no assigned             0
Auth linked                     0

departments                     0
department memberships          0
department merit rules          0
```


## 23. Parallel database drift became an operational warning

A repeated readiness query changed from 0/0/0 terms/classes/enrollments to 1/13/144. Live history contained `lead_audit_view`, `current_term_setup`, and its correction before Git fully represented them. Idempotent reconciliation restored the Fall term, class shells, 144 non-G9 enrollments, and lead audit view to version control. Completion now required reproducibility in a fresh environment, not merely a functioning live DB.

## 24. Measuring Core readiness

A projection categorized students as CORE_ONLY, PARTIAL, or READY. READY required canonical UUID, student number, Auth link, and current-term enrollment. The checkpoint showed 180 total, 175 active/bridged, 144 enrolled, and zero number/Auth links; G9 was intentionally pending. The console became a measured integration dashboard.

## 25. Preparing a Study Planner shadow destination

Before copying live SP data, an empty `study_planner` target separated shared student/term masters from learning-domain goals, plans, items, and execution records. It enabled FK, table comparison, and copy-order review without disturbing SP production. Target content was zero. Preparing the destination was distinct from completing migration.

## 26. Integration sequence

Inventory source counts/schema drift; verify student-number/Auth mappings; copy reference data; reconcile terms; copy goals/plans/items/records in dependency order; validate counts/FKs/sample behavior; switch a Core-backed frontend; run a comparison period; then decide archival or retirement. No PII belongs in Git, names alone do not prove identity, and the existing service stays available until validation succeeds.

## 23. SP reconciliation: verifiable partial success

The 29-student pilot was compared with the operational Core bridge, excluding PINs. Results were 28 exact matches, one unmatched, zero ambiguous. Only the 28 verified numbers were applied, leaving 152 of 180 Core identities without a number at that checkpoint. The disputed name stayed pending. Expanding temporary grade-based IDs school-wide still required a separate numbering decision.


### Recorded technical detail


```text
SP source
student_no + name + grade
          ↓
Daniel operational roster
name + grade + core_student_id
```


```text
source rows     29
exact matches   28
unmatched        1
ambiguous        0
```


```text
28 verified: apply first
1 mismatch: pending
```


```text
Core students              180
student_no assigned         28
student_no pending         152
```


## 24. Architecture correction: separate Auth namespaces

The initial assumption that SP Auth UUIDs could populate Core-local `auth_user_id` was wrong: SP and Core are different Supabase projects. External UUIDs belong in `core.external_auth_identities`; only identities provisioned in Core Auth may populate the local FK. Person identity, local login identity, and external identity must remain distinct.


### Recorded technical detail


```text
existing SP auth.users.id
        ↓
core.students.auth_user_id
```


```text
SP Project A
auth.users.id = UUID-A
```


```text
Core Project B
auth.users.id = UUID-B
```


```text
SP external auth UUID
        ↓
core.external_auth_identities
        ↓
core.students.id
```


```text
DICS Core local auth.users.id
        ↓
core.students.auth_user_id
        ↓
core.students.id
```


```text
Person identity
Login account identity
External-system identity
```


## 25. Reconciling migration history

Live history included computer-lab, SP target, and external-identity structures absent or mis-versioned in the integration branch. The original `20260925005111_computer_lab_p0.sql` was recovered from the device-manager repository rather than reconstructed from an approximation. Duplicate draft timestamps were aligned with actual applied versions. Parallel development requires migration-history conflict management as well as source conflict management.


### Recorded technical detail


```text
computer_lab_p0
study_planner_target_schema
external_auth_identity_bridge
...
```


```text
shualoalumin/dics-device-manager
```


```text
20260925005111_computer_lab_p0.sql
```


```text
20260925000015_...
20260925000015_...
20260925000016_...
20260925000016_...
```


```text
20260925004004 lead_audit_view
20260925004257 current_term_setup
20260925004557 core_migration_readiness
20260925004655 fix_current_term_setup_runtime
20260925004934 parallel_db_reconciliation
20260925005111 computer_lab_p0
20260925005238 study_planner_target_schema
20260925005346 external_auth_identity_bridge
20260925005501 study_planner_fk_indexes
20260925005646 external_auth_identity_bridge_reconcile
20260925005951 split_core_external_auth_readiness_v3
```


## 26. A real multi-domain database

The checkpoint had 180 Core students, 175 active, 28 numbered, one term, 13 classes, 144 enrollments, 31 pending G9 placements, 13 SP target tables, and eight computer-lab tables. Both local/external Auth counts and department definitions were zero. Shared schemas existed; full operational domain cut-over did not. Verified identity/data connection was the next stage.


### Recorded technical detail


```text
Core students                 180
active students               175
student_no assigned            28

current term                    1
current classes                13
current enrollments           144
G9 section pending             31

Study Planner target tables    13
Computer Lab tables             8

external auth linked            0
local Core auth linked          0
department definitions          0
```


```text
core.*
discipline.*
study_planner.*
computer_lab.*
```


## 27. Teachers also need external-identity bridges

SP staff Auth UUIDs belong to the external project too. `study_planner.staff.id` became an independent profile UUID, `auth_user_id` an optional Core-local identity, and `external_staff_identities` the provenance bridge. Correcting this before staff/comment data entered the shadow target avoided a later PK-semantics migration.

## 28. Internal role checks do not replace execution privileges

Core provisioning and identity-link functions checked lead status internally, but default PUBLIC EXECUTE still exposed SECURITY DEFINER endpoints to anonymous calls. PUBLIC/anon execution was revoked and authenticated execution explicitly granted for term setup, G9 assignment, and external linking. Those three anonymous warnings cleared. The remaining computer-lab RPC used a different server/session design and was left to its domain owner. DB privileges and internal role checks serve complementary purposes.

## 29. Student numbers and Auth move separately

After number reconciliation the counts were 175 active students, 28 numbered, 144 enrolled, zero local Auth, and zero external Auth links. Core readiness split local and external Auth into separate axes. A human identifier is not a login identity; linking an external account need not increase the Core-local Auth count.

## 30. Repeatable cross-project migration tooling

`scripts/migrate-sp-external-identities.mjs` directly connects the two trusted projects. It defaults to dry run and reads only SP id/student_no/core_student_id and Core id/student_no, excluding names, emails, PINs, and DOB. Output is aggregate-only. Duplicate numbers, contradictory source bridges, conflicting external identities, or multiple source identities for one Core student stop writes. The databases cannot share a transaction, so both writes are idempotent and recover by rerun. CI checks runner syntax.

## 31. Inventory before content inspection

The lead-only `get_study_planner_target_inventory()` exposes counts for staff, identity bridges, weeks, reference data, goals, plans, items, execution records, and comments without revealing student plans or comment text. Target content remained zero. Validation proceeds from count/FK/uniqueness parity to limited behavior sampling and then frontend cut-over.

## 32. Integration checkpoint

The recorded state was 180 Core identities, 175 active, 28 verified numbers, one term, 13 classes, 144 enrollments, 31 pending G9 assignments, zero local/external student Auth links, 13+ SP target tables, zero copied SP content, computer-lab schema present, and discipline active. Schema integration was progressing; verified identity enrichment and domain migration remained.

## 33. Department merits become operator-managed data

An Excel-dependent process required developer involvement for every membership/rule change and risked roster disclosure. A lead console now manages departments, weekly rules, dated memberships, and current-week generation in Supabase. Memberships use starts_on/ends_on; changed rules close effective_to and open a new effective_from instead of overwriting history. SEONDO may read; only leads write; SASAENG access is restricted. Immediately after deployment, department/membership/rule/generated counts remained zero, so no real points were invented.

## 34. Catching an automated UI replacement error

A broad string replacement placed a department-generation status block in the penalty-entry page on the branch. Source inspection found it; the block was moved using an explicit department-page header anchor. The erroneous CI failed and the corrected commit passed. Tool-call success did not prove placement correctness. Source review, type/build checks, and branch CI were all necessary.

## 35. Department merit completion boundary

A lead could create a department, define weekly points/label, add membership, invoke `ensure_weekly_department_merits()`, and inspect generated/expected counts. Deterministic source keys prevented duplicates. Real memberships and scores were deliberately not entered; verified operator setup remained the next action.

## 36. From shared access to personal accountability

With shared accounts, `auth.uid()` identifies a shared role account rather than a unique person. Personal accounts were introduced alongside the existing fallback so provisioning, scope, and audit attribution could be tested gradually without interrupting school work. Shared accounts should become inactive only after the rollout is stable.

## 37. Keep Auth Admin API outside the browser

The JWT-authenticated `provision-admin-account` Edge Function verifies an active SEONDO lead, calls the service-only Auth Admin API, and registers the profile under the caller context. A profile failure triggers compensating Auth-user deletion. Cryptographically random temporary passwords are returned once, never stored in Git or profile rows, and changed at first login. At this checkpoint there were still two operational profiles and no newly provisioned staff accounts.

## 38. A password-complete flag is not proof

An authenticated user could call the original completion RPC without actually changing the password. That client-controlled design was removed. `change-admin-password` verifies JWT, active profile, and complexity, performs the Auth update, and clears `must_change_password` only after success. Completion follows the mutation result rather than UI call order.

## 39. Enforcing the first-login flow

New accounts start with `must_change_password = true`; protected routes display a mandatory password screen before operational screens. The policy requires at least 12 characters with upper/lowercase, number, and special character. Success reloads the profile and opens the dashboard. Inactive profiles receive a separate access-blocking screen.

## 40. Protecting administrator continuity

Only leads manage accounts. SASAENG cannot become SEONDO lead; lead scope is always ALL; the final active lead cannot be demoted or disabled; login IDs remain fixed after creation; and deactivation preserves audit history. These guards prevent accidental loss of all administrator access.

## 41. Personal-account checkpoint

There were two active profiles, one active lead, zero password-change-required profiles, and zero newly provisioned staff accounts. Both Edge Functions were active with JWT required. The frontend included account management, one-time temporary credentials, first-login enforcement, and inactive lockout. Typecheck/build passed. Gradual provisioning of verified staff remained operational work.

## 42. Discipline records gain canonical UUIDs

Although the roster had Core identity, point and punishment records still stored integer FKs. A dual-key phase reduced the risk of changing frontend, triggers, reports, and calculations at once. The existing point record was backfilled through the bridge: one of one Core-linked, zero mismatches; punishments remained zero. Existing reflection history was preserved.

## 43. Dual keys must identify the same student

`private.sync_discipline_core_student_id()` resolves the legacy locator, fills a missing UUID, and rejects an inconsistent UUID on insert/update. Core remains authoritative throughout transition. A rollback insert verified automatic UUID filling without retaining a test record.

## 44. Canonical write entry points

`create_point_record_core(...)` and `create_punishment_core(...)` initially resolved Core UUIDs through the bridge and delegated to existing rule implementations, avoiding duplicated validation. An authenticated SEONDO rollback test confirmed creation, UUID presence, and same-student identity; counts were unchanged afterward.

## 45. Frontend write cut-over

Changing API input types exposed stale `studentId` call sites in App.tsx through CI. Calls were changed to `selectedStudent.coreStudentId`; submission is blocked when Core identity is absent. Typecheck/build then passed. New discipline writes started from UUIDs while numeric reads/routes remained transitional.

## 42. Linking source records to Core identity

This repeated checkpoint records the same dual-key milestone from the source-record perspective: added point/punishment Core UUID columns, backfilled existing records, and verified one linked point row with zero mismatches and zero punishment rows. UI-only identity was no longer the limit of integration.

## 43. Enforcing identity agreement in the database

The repeated transition record emphasizes that adding a UUID column alone cannot prevent silent corruption. The synchronization trigger resolves the bridge, fills absent UUIDs, compares supplied UUIDs, and rejects disagreement. Old and new IDs must always represent one student.

## 44. Starting every new write with a Core UUID

Core write RPCs accept UUIDs and temporarily resolve legacy integers internally, preserving one implementation of point/reflection/punishment rules. Frontend writes switched to these RPCs. Integer student-detail reads remained transitional at this dated checkpoint.

## 45. Live verification with rollback

A temporary authenticated SEONDO transaction called the Core point RPC, confirmed successful creation, UUID presence, and bridge agreement, then rolled back. No test discipline row remained. Frontend typecheck/build passed. These are recorded historical probes, not newly executed tests in the translation work.

## 46. Why integer columns were not dropped immediately

Routes, old aggregates/views, RPC signatures, and history compatibility still depended on integers. Retirement required every record linked, zero mismatches, UUID-only new writes, Core-based reads, and equivalent reports/rollback checks. Later entries record completion of those gates.

## 47. Moving reads and routes to UUIDs

The `/students/:id` shape stayed stable, but new links used Core UUIDs. A numeric fallback resolver preserved older bookmarks. Point-history filters and reflection-to-student links moved to Core identity; `core_student_id` was appended to reflection views.

## 48. Shadow calculation before promotion

Core shadow views for weekly scores, weekly penalties, and settlement ran beside legacy calculations. Aggregate parity measured weekly 1/1, penalties 1/1, settlement 0/0, all mismatch zero. Only then were public contract views promoted to the Core implementations.

## 49. Student-summary parity: 175 of 175

The summary combines lifetime merits/demerits, weekly/settlement NET, training/committee eligibility, reflections, residential sanctions, and leave restrictions. Its shadow matched 175 legacy rows to 175 Core rows with zero mismatches. Summary/report counts stayed 175 and all recorded target counters remained unchanged when the Core implementation was promoted.

## 50. Inspecting the PostgreSQL dependency graph

A text search for student_id also matched core_student_id. `pg_depend` identified physical dependencies precisely: readiness and legacy-shadow settlement/summary/weekly views for point IDs, and readiness/summary shadow views for punishment IDs. This established which objects had to be detached before dropping columns.

## 51. A hidden runtime trigger dependency

`private.create_reflection_for_penalty()` still read `new.student_id` for grade lookup even after view/RPC migration. It was changed to `new.core_student_id` through the student bridge. Otherwise new penalty inserts would have failed after column removal. Catalog dependencies and runtime trigger bodies both needed inspection.

## 52. Preserve evidence before destructive change

Preflight confirmed one linked point record, zero punishment records, zero identity mismatches, weekly 1/1, weekly penalties 1/1, settlement 0/0, and student summary 175/175, with zero calculation mismatches. Aggregate-only evidence was stored in `discipline.core_cutover_evidence`, excluding names, student numbers, Auth UUIDs, and mapping rows, before the destructive migration.

## 53. Physical integer foreign keys removed

The point and punishment student_id columns were dropped; both tables now store only `core_student_id UUID NOT NULL`. Compatibility views derive integers through the bridge when needed. Point count 1, sum 5, reflection count 1, punishment count 0, report rows 175, and dashboard counts were preserved. Post-drop Core and legacy point/punishment calls and reflection creation passed rollback probes. The status became POST_LEGACY_COLUMN_DROP_VERIFIED with removal/completion flags true. The small observed dataset limits the scope of the evidence.

## 54. Reversing business-rule ownership

Core UUID RPCs became authoritative implementations. Legacy integer RPCs now resolve UUIDs and delegate to Core, reversing the initial wrapper direction. Department-merit writes likewise store only UUIDs. Removing compatibility wrappers later need not replace the business-rule implementation.

## 55. Aligning the ledger with production

Fifteen recent cut-over filenames were reconciled with actual live migration names/versions; 15/15 matched afterward. Admin RLS optimization was aligned to `20260926172018`. Some changes moved existing blobs without changing SQL content. A working live DB does not excuse filename/version drift that could cause CLI reapplication.

## 56. Fixing meaningful advisor findings

`admins_read_self_or_lead` was changed to initplan-friendly scalar subqueries for Auth/lead checks; the auth_rls_initplan warning cleared. Remaining unused-index INFO findings were not a reason to delete indexes before enough workload history existed. Computer-lab security surfaces and leaked-password protection remained distinct owner/platform follow-ups.

## 57. Reconciling the entire production migration history

A full audit initially found 48 Git SQL files versus 52 live migrations, with 20 version-missing and 16 version-extra entries. Name/content comparison showed most differences were identical structural migrations with draft timestamps. Initial schema/logic/RLS, Core foundations, and operational extensions were renamed to actual live versions without changing SQL. Exactly four live-only entries remained.

## 58. The remaining four are operational data

Historical seeds, environment-specific Auth bindings, a private roster import, and a private correction should not be restored as public SQL. TRACKED means schema SQL exists under the exact live version/name; LIVE_ONLY_DATA means history records the operation but sensitive SQL is intentionally absent. The checkpoint was 52 production, 48 tracked, four data-only, zero extra Git files.

## 59. Migration names can reveal identity too

A roster-correction migration name itself could identify a student. The ledger replaced it with `name_redacted = true` and `private_label = private_roster_correction`, excluding the actual name. Keeping SQL private is insufficient if metadata discloses the same information.

## 60. Making migration governance a CI contract

`supabase/migration-ledger.json`, `scripts/check-migration-ledger.mjs`, and `npm run check:migration-ledger` enforce unique 14-digit versions, exact tracked filenames, file existence, data-only rationales, absence of data-only SQL, and redaction rules. Every Git migration requires a tracked entry. Missing ledger updates, private-data SQL, or version mismatch fail CI. The initial ledger check/typecheck/build passed; governance became an executable merge gate.

## 61. G9 assignment also moves to UUIDs

The frontend hook moved from numeric IDs and the legacy assignment RPC to `coreStudentId: string` and `assign_current_grade9_section_core(uuid,text)`. Row/test IDs changed too. `20260926173405_grade9_core_assignment_rpc.sql` was reconciled and tracked: 53 live, 49 structural, four data-only. A rollback transaction tested Core G9-A then legacy G9-B on the same student with successful identity agreement and no retained placement change. Intermediate stale call sites failed typecheck; the completed conversion passed all checks.

## 62. Locking the legacy bridge against browser writes

Old student mutation hooks could still write to `public.students`, now only a compatibility bridge. The students_write/students_update policies and browser mutation/sequence privileges were removed. Authenticated users retain SELECT only; anon has no table privileges; one read policy and zero write policies remain. StudentInput/create/update/delete hooks were removed. Only Core provisioning/import may modify student master data. Live migration `20260926175058_legacy_students_read_only` brought the checkpoint to 54/50/4; final checks passed.

## 63. Reducing legacy-wrapper privileges

The integer G9 wrapper only resolves a UUID and delegates, so it changed from SECURITY DEFINER to SECURITY INVOKER. The authoritative Core RPC retains privileged writes and lead authorization. Advisor authenticated-definer warnings fell from 11 to 10. Migration `20260926175410_grade9_legacy_wrapper_invoker` was tracked, giving 55 live, 51 structural, four data-only.

## Deployment provenance — September 27, 2026

PR #1 had merged and main CI passed while Netlify still served a September 21 build. Vite now receives COMMIT_REF and authenticated admins see its short value, with the full value in the title. Builds without metadata show an unverified-commit label; printouts omit it. The top date badge was also fixed to Asia/Seoul so foreign browser timezones cannot disagree with input defaults. Deployment must be checked against main; CI success alone does not prove production freshness.

## 64. Unattended Monday department merits — September 28, 2026

The existing RPC ran only when SEONDO opened the app, so no login meant no midnight generation. pg_cron was available but inactive and its timezone was GMT; the public RPC required an authenticated role. A postgres-owned `department-merits-monday-kst` job now calls `private.run_weekly_department_merit_job()` at Sunday 15:00 UTC, Monday 00:00 KST. It uses the same membership/rule conditions and deterministic membership/Monday source key. Browser roles, including service_role, cannot execute the private function. The public RPC/button remains a recovery path.

The migration was rollback-tested, then `20260927153350_department_merits_monday_cron` applied once. pg_cron 1.6.4, job name/schedule/command/active state/owner, and denied browser execution were checked. A harmless one-minute `select 1` probe succeeded and was immediately unscheduled. Two manual current-week runs returned zero without errors; expected/generated counts were zero. Nonempty generation still needs verified departments/memberships/rules and a later Monday job-run/count check.

## September 28, 2026 — Dashboard design and workflow
Following typography/contrast work, Josh requested a more coherent design. Date/week context and five target-card order were retained. Queries and responsibility filtering stayed in the container while DashboardView separated presentation. A green weekly panel groups calendar/merit work; adjacent links reach reflections, notices, and settlement. The student card joins filters/search/table/summary, with right-aligned numbers and a shaded NET column. A dedicated settlement query avoids inferring period state from the first student.

Local typecheck/build passed. Because agent-browser could not bind its daemon socket, a temporary Netlify preview rendered the real component with synthetic data. Desktop, 320px, 390px, dark mode, filters, empty/unconfigured/error states, and role links were checked. Temporary fixtures/pages were excluded before merge. Authenticated real-data verification remained follow-up work. The design record and fixture screenshot are in UI_DESIGN_SYSTEM.md.

## October 28, 2026 — Covered penalties should not create reflection obligations

A student with +10 merits and -5 penalties has NET +5. Showing missing/double obligations for that covered penalty contradicted policy; later negative NET must not retrospectively make the earlier record overdue. The source point/reflection rows remain intact, while reads require both current negative full-week NET and negative entry-time running NET. Week membership uses recorded_at; entry order uses created_at,id. Targets disappear together when NET reaches zero and later eligible penalties return if NET becomes negative.

A contract-preserving view migration aligned the read paths without changing deadlines or training/committee policy at that checkpoint. The recorded live check excluded 12 of 81 rows, including two incorrect double statuses. A +10,-5,-6,+1,-1 scenario was verified with BEGIN/ROLLBACK, retaining no test data. The regression is in supabase/tests/reflection_weekly_net.sql.

## October 28, 2026 — Today's work differs from occurrence date

An occurrence-date-only notice omitted older overdue reflections from today's work. After defining negative-NET eligibility, the read path combined today's actionable missing records with carried DOUBLE records. Submitted students disappear while ledger/deadline history remains. Carry-forward applies only to today's notice and does not rewrite past-date output.

Dark-navy training and red DOUBLE status remain distinct. Weekly penalties show an explicit sign. G9 routing moves to high school without altering grade. A4 margins, body/table sizes and multi-page tables were improved together.

## October 28, 2026 — Submission checks connect to training

Completing double submission by the 17:00 check avoids training for that missing obligation; continued non-submission activates it the next day. The three reasons are independent and may coexist, so dashboard/reports retain all of them rather than a single representative reason. Existing submission timestamps and score source rows were not changed. Rollback checks covered next-day activation, single-week credit and release upon completion.
