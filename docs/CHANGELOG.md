# Daniel's Scale — Change Log

**Language / 언어:** [English](CHANGELOG.md) | [한국어](CHANGELOG.ko.md)

Reconciled through main `30f90a4` on October 29, 2026. Newest changes appear first. Commit-register dates use Asia/Seoul; operation dates are distinguished in the entries. Historical verification records are not a fresh production audit.

## October 2026 — Commit Register

| Korea-local date | Commit | Change |
| --- | --- | --- |
| 2026-10-29 | [30f90a4](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/30f90a4168ae97df69a201cb0089d80f14be8fce) | Future-dated events with KST effective-day scoring |
| 2026-10-28 | [0b375c3](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/0b375c32a45605f3bd14d1b1ae0e0b93db9ac48f) | English-first bilingual documentation and validation |
| 2026-10-28 | [e682248](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/e682248d717b042fb8074ed32a4c9e3819a2daf3) | Next-day training for overdue double reflection |
| 2026-10-28 | [6db9325](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/6db932596db56c6c654f04a0c5e62e38372fc931) | Carry overdue notices; route G9 to HIGH |
| 2026-10-28 | [beb53fd](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/beb53fdd0cd7a3381cc6c532060ec0be5eba0f79) | Reflection eligibility follows negative weekly NET |
| 2026-10-27 | [5223116](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/5223116c37219a93e7bddd11a43d202da97c8045) | End memberships immediately; resume automatic merits |
| 2026-10-27 | [cd9fe25](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/cd9fe25670e508c9e2b74e04968dfd5ff398b3a9) | Require consecutive training weeks; show cumulative NET |
| 2026-10-27 | [6370422](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/6370422106d1fa907ce64202dd4f8eafd7923f07) | Use merit-minus-penalty weekly NET display |
| 2026-10-27 | [56a8296](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/56a8296c81210d7e698c3364c0ac956eeba7ec17) | Prioritize students with point records |
| 2026-10-27 | [6c5036e](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/6c5036e59aafc5e2cc30191b68085e6009f58236) | Allow past occurrence dates for manual entries |
| 2026-10-27 | [0ecda8b](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/0ecda8b948aa4dd665b01cf7fdbec79164f54eb2) | Weekly ledger import and daily-operation cut-over |
| 2026-10-15 | [537b3db](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/537b3dbbb728f5aa76efd07b7b8a1bf08e9a541a) | Synchronize the Core roster |
| 2026-10-06 | [c4a26a5](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/c4a26a5f76ecd5bf6d43804558397dfb5c6da8ed) | Add a historical account handout; later sanitized |
| 2026-10-04 | [7a0622c](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/7a0622c17390bae6be63a037dbce0af55ff07037) | Organization-repository Netlify CLI deployment workflow |

## October 29, 2026 — Future-dated merit and penalty entries

- Removed the point-entry form's HTML `max=today` restriction for both positive and negative points. Shows the effective date and indicates upcoming records as scheduled.
- Removed the DB cutover trigger's future-date prohibition while retaining immutable superseded historical rows and write-audit behavior.
- New effective-day SQL projections gate weekly totals, penalty incidents, lifetime scores, reflection-paper eligibility, and closed/current settlement values at KST current date. Future entries are saved and auditable now but do not prematurely influence discipline status.
- Disabled the point-entry 'same-day reflection submitted' shortcut for future negative records. Added a scheduled marker to recent session entries and student detail history.
- Applied production migrations `20261028185513_future_point_records_effective_date` and `20261028185542_future_point_records_allow_write`. Live rollback test saved a future merit + penalty through the real admin RPC and confirmed that current scoring, reflections, training and committee indicators were unchanged.

Related commits: [30f90a4](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/30f90a4168ae97df69a201cb0089d80f14be8fce).

## October 28, 2026 — Reflection eligibility follows negative weekly NET

Reflections now require current Monday–Sunday NET below zero and negative running NET when that penalty was entered. Covered early penalties never become retroactively overdue/double. Reflection, notice, point-history and dashboard summaries share the DB eligibility projection without altering source/audit records. Migration 20261028003013 was applied; the recorded check excluded 12 of 81 formerly active rows (including two double-status rows), leaving 69. Transaction-rollback regression tests passed. Deadline/training rules were unchanged at this checkpoint.

Related commits: [beb53fd](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/beb53fdd0cd7a3381cc6c532060ec0be5eba0f79).

## October 28, 2026 — Carried notices, G9 scope, and printed status

Today's notice includes today's unsubmitted eligible records plus older current DOUBLE records; submitted or NET-offset targets are excluded. Historical-date notices do not carry forward rows. Reflection filters and Today counts use the same set, with 60-second refresh and submission-cache invalidation. Weekly penalties show an explicit minus sign; training is dark navy and DOUBLE remains red.

G9 responsibility moved to HIGH across DB views, history RPC and frontend filters without changing enrollment. A4 margins became 16×17 mm, with 12.5px table text, expanded header/cell spacing, stable page splits and emphasized original dates/double status. Migration 20261028012114 was applied and G9 HIGH routing verified.

Related commits: [6db9325](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/6db932596db56c6c654f04a0c5e62e38372fc931).

## October 28, 2026 — Third physical-training criterion

An unsubmitted double-reflection obligation after its 17:00 check deadline adds training from the following day. Existing weekly incident/NET conditions remain independent and all reasons are displayed. Checks cover deadlines, release upon submission, and no duplicate weekly qualification. Dashboard, detail, weekly print and periodic reads use the rule. See [current discipline rules](DISCIPLINE_RULES.md).

Related commits: [e682248](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/e682248d717b042fb8074ed32a4c9e3819a2daf3).

## October 28, 2026 — Bilingual documentation merged after October 26 preparation

Expanded the existing bilingual overview PR to all maintained Markdown documents with English defaults and Korean counterparts. Added a project case study, language-maintenance checks, and historical-attachment translations. Replaced an account handout containing real student identifiers/PINs with a synthetic template. Historical Git objects still require owner review; document replacement is not credential rotation or history erasure. New commit messages are English-only. Existing-message rewriting is prepared separately from the owner-reviewed documentation PR.

Related commits: [0b375c3](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/0b375c32a45605f3bd14d1b1ae0e0b93db9ac48f).

## October 27, 2026 — Weekly history, daily entry, and operational corrections

The weekly-ledger cut-over committed on this date records an operation applied on October 26 UTC: preserve 898 source rows, link 873 weekly balances, keep 22 unresolved rows private, and supersede 170 old secondary events without deleting audit originals. Elementary records and the then-current 40 daily events were preserved. Historical whole-week values remain distinguishable from daily records; missing/no-school periods are not fabricated as zero observations. XLSX preview, revision-aware import, retry guards, undo, and scoped history access were added. See [history/backfill](HISTORY_AND_BACKFILL.md).

A later operator-requested manual-entry reset soft-deleted 42 events and made 873 balances non-current, preserving original rows and a private checkpoint. Past-date manual entry became available, including dates before the current term; future dates were still blocked at that checkpoint. The October 29 effective-day change supersedes that restriction. See [reset record](OPERATIONS_2026-10-27.md).

Additional commits prioritized students with recorded points, made displayed weekly NET explicitly merit minus penalty, and required three consecutive qualifying calendar weeks in the current term for committee eligibility. A gap breaks the run; the old 20-point/nonconsecutive alternatives no longer apply. Department membership uses an exclusive end date; four automatic merit rules and the Monday cron resumed, with recorded generation 38/38 and no duplicate awards. Current roster count and Monday eligibility count intentionally differ. See [current rules](DISCIPLINE_RULES.md) and [department merits](DEPARTMENT_MERITS.md).

These are dated repository records, not a new live database audit. The commit register above distinguishes the commit dates from operation dates described in the records.


Related commits: [5223116](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/5223116c37219a93e7bddd11a43d202da97c8045), [cd9fe25](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/cd9fe25670e508c9e2b74e04968dfd5ff398b3a9), [6370422](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/6370422106d1fa907ce64202dd4f8eafd7923f07), [56a8296](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/56a8296c81210d7e698c3364c0ac956eeba7ec17), [6c5036e](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/6c5036e59aafc5e2cc30191b68085e6009f58236), [0ecda8b](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/0ecda8b948aa4dd665b01cf7fdbec79164f54eb2).

## October 15, 2026 — Core roster synchronization

Applied trigger-based creation/update of Daniel compatibility rows from active Core students/current enrollments. Core name/activity and enrollment additions/changes/endings synchronize automatically; inactive or no-current-enrollment students disappear from the active roster. Term changes resync all bridges. One active Core-only student was backfilled. Core UUID remains authoritative. Live migration: 20261015101921_sync_daniel_roster_from_core.sql.

Related commits: [537b3db](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/537b3dbbb728f5aa76efd07b7b8a1bf08e9a541a).

## October 6, 2026 — Historical account-handout addition

A commit with an empty message added an account-distribution HTML file. Its file diff establishes the change; an empty message is not treated as evidence of a deployment. The later bilingual-documentation change replaced its working copy with a synthetic template. Historical objects still require owner-controlled credential/exposure review; no credential values are repeated here.


Related commits: [c4a26a5](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/c4a26a5f76ecd5bf6d43804558397dfb5c6da8ed).

## October 4, 2026 — Organization deployment workflow

Added GitHub Actions verification and pinned Netlify CLI deployment for the private organization repository, using the existing site and production environment. PRs verify without production deployment; main app/build changes can deploy. The committed workflow is evidence of configuration, not by itself proof that a particular deployment succeeded. The October 4 date is the Korea-local date of the October 3 UTC commit. See [deployment instructions](netlify-deployment.md).

Related commits: [7a0622c](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/7a0622c17390bae6be63a037dbce0af55ff07037).

## September 2026 — Historical Foundation

> Active record since September 21, 2026. This English edition reflows the historical narrative and retains implementation milestones, measured evidence, and unresolved states. Original requirements remain in [spec.md](spec.md); initial-build history is frozen in [LEGACY_INITIAL_BUILD.md](LEGACY_INITIAL_BUILD.md). Record meaningful product changes here regardless of whether they came through GPT, Cursor, another tool, or manual infrastructure work.

## Purpose and original accountability proposal

An operational school system must explain who entered or changed a record, when, under what authority, and what the previous state was. The initial Replit draft validated student/point/reflection/punishment workflows and two roles. The Vite/Supabase/Netlify port replaced Clerk and Express with Supabase Auth, PostgreSQL views/RPCs/triggers/RLS, soft deletion, KST calculations, and SPA routing.

SEONDO manages guidance records; SASAENG manages residential sanctions. Shared role logins establish a role but not an individual operator. A manually typed entered_by_name can vary in spelling or identify someone other than the authenticated user. The proposed improvement separated individual account, profile, role, and scope, while retaining the two business roles.

The original P1 sequence was individual accounts → automatic created_by → updated_by/updated_at → before/after audit logs for create/update/soft-delete, reflections, and sanctions. Suggested profile fields were user_id, display_name, role, is_active, created_at; audit fields included actor_user_id, action, entity_type/id, before_data, after_data, reason, and created_at. A UI could display the authenticated operator and timestamp without asking for a typed name. Examples in that proposal were illustrative, not claims about real operators.

The original roadmap marked Replit and the Vite prototype complete, P1-A/B/C/D planned, and operational UX/permissions as later P2 work. Later entries record implementation and distinguish that from actual staff adoption.

Principles: the DB is the final authorization boundary; server-side rules do not rely on hidden buttons; preserve historical records through soft deletion/audit; use fictional seeds only; and separate identity from role. The intended improvement was from “a department recorded this” to an attributable operator, timestamp, and score-change history.

## September 21, 2026 — Initial version record

Documented the two-role structure, limitations of typed authors, individual identity proposal, auth.uid-based provenance, audit concepts, and staged P1 roadmap.

## Operations-foundation review stage

Branch: gpt/operations-foundation. The roadmap established a single Core student UUID, separate optional login identity, term-based enrollment, and minimum disclosure of DOB/gender. Foundation migrations added core students/terms/classes/enrollments, a legacy bridge, weekly raw/NET views, administrator-closed settlement, and time-aware reflection deadlines: G7–12 17:00 with 21:00 extension, G1–6 next morning 08:20.

The branch simplified entry to login, widened the old grade constraint from 1–6 to 1–12, promoted the existing minimal operational roster instead of reimporting private spreadsheets, allowed nullable numbers during bootstrap, and made the roster Core-managed/read-only. Dashboard planning used weekly merits/demerits/NET and settlement NET, with three incidents or NET 8 for training and three eligible weeks or NET 20 for committee referral.

An early statement that SP Auth UUIDs would populate local auth_user_id was corrected by the later external-namespace design. These were review-stage statements at the time, not proof of production deployment.

## September 25, 2026 — Core production foundation

- Applied Core bootstrap to daniels-scale: 180/180 UUID mappings, 175 active and 5 inactive. Inactive discipline history remained linked.
- Applied Core RLS/current-student projections, weekly NET, settlement periods, due_at, Core-aware summary/count views, fixed function search_path, and FK access indexes.
- Preserved leading production-view columns for old frontend compatibility.
- Reflection deadlines: 17:00, discretionary 21:00, elementary next morning 08:20.
- Open settlement count was zero; an operator would choose the actual cycle start.

### Notices and printing

Applied v_daily_discipline_notice with date, placement, reason/points, reflection status/deadline; and v_weekly_discipline_report with raw/NET scores, incident count, training eligibility, settlement NET/eligible weeks, and committee referral. Queries returned normally; weekly output covered 175 active students and zero current training/committee targets.

The branch added daily class notices, date/class filters, grouped weekly reports, target-only extraction, and A4 print layouts. Missing homeroom falls back to G{grade} until verified enrollment exists. CI added npm ci → typecheck → build.

### Department-merit foundation

Added core.departments/memberships, discipline.department_merit_rules, source_type/source_key, a unique duplicate guard, and ensure_weekly_department_merits(). Actual department/membership/rule/generated rows were all zero. At this stage no pg_cron was installed; first SEONDO dashboard access ensured Monday records idempotently. New generation alone triggered aggregate refetch/notification; empty configuration did not show unnecessary status. A later entry adds unattended scheduling.

### Morning continuous entry

Expanded search to name/number/class, single-result Enter selection, continuous-entry mode with retained item/points/date/operator, student-only reset, refocus, and six recent saves. Photo recognition stayed P2.

### Responsibility scopes

Added ELEMENTARY G1–6, MIDDLE G7–9, HIGH G10–12, ALL for leads; is_lead/is_active; and v_reflections.assigned_scope. The shared SEONDO account stayed ALL/lead/active during transition. Inactive accounts return no operational role. Settlement start/close RPCs require a lead. Frontend reflection/notices follow scope; weekly reports and settlement management are lead-only.

### Auth provenance and audit

Added created_by/updated_by to point/reflection/punishment records and server triggers using auth.uid(). Historical unknown actors stayed null. discipline.audit_logs stores append-only INSERT/UPDATE/DELETE before/after for those entities and settlements. Existing RPC signatures remained, with role checks/fixed search_path. No new advisor warnings were recorded; leaked-password protection remained a separate review item in light of the student PIN policy.

### Readiness and SP shadow target

Added v_core_migration_readiness/v_core_student_readiness. Snapshot: 180 Core, 175 active/bridged, 144 enrolled, 28 numbered, zero Core-local/external Auth links. Live-first term/audit changes were reconciled into Git. The study_planner target reused Core students/terms, with zero copied SP content and the source project still live. The console showed READY/PARTIAL/CORE_ONLY and missing links. The journal and SP runbook were added; source aggregate inventory was requested through the coordination workflow.

### Secure cross-project identity migration

Separated local/external Auth, reconciled core.external_auth_identities, and added lead-only link_external_auth_identity with number existence, identity-conflict, same-source, and idempotency guards. Revoked anonymous execution of Core-admin SECURITY DEFINER RPCs. Added PII-free v_external_auth_mapping_status, independent staff profiles/external staff bridges, lead-only target inventory, and ten SP FK indexes flagged by the advisor.

The migration runner defaults to DRY RUN and writes only with --apply. It excludes names/email/PIN/DOB, uses exact verified numbers, explicitly excludes test/developer IDs, stops on conflicts, and supports idempotent reruns across databases. CI checks its syntax.

### Department administration

Lead-only RPCs manage departments, dated memberships, and versioned effective-date rules; SEONDO reads and leads write. The frontend manages active status, student search, generated/expected status, and an idempotent current-week button. Actual data stayed 0/0/0/0. A misplaced UI replacement failed CI, was moved to the department console, and the corrected branch passed.

### Personal administrator accounts

Added admins.login_id, must_change_password, last_password_changed_at, provisioned_by; self/active-lead roster access; register/update profile RPCs; final-active-lead protection; lead scope ALL; and profile auditing. Removed the client-controlled password-complete RPC.

Deployed JWT-required provision-admin-account and change-admin-password Edge Functions. Provisioning checks lead status, uses server-only Auth Admin API, creates random temporary credentials, and compensates profile failure with Auth deletion. Password completion clears the flag only after a real Auth update. Frontend account management, one-time credentials, first-login enforcement, and inactive lockout were prepared, retaining shared fallback accounts.

Operational checkpoint: profiles 2, active 2, leads 1, new personal accounts 0, must-change-password profiles 0. Feature availability is not evidence of completed personal-account adoption.

### Discipline UUID dual-key and write entry points

Added Core UUID columns/FKs/indexes to point_records and punishments, backfilled existing records, enforced same-student dual-key agreement, exposed UUIDs in views, and added v_discipline_core_fk_readiness. Core write entry points initially delegated to existing business rules.

Points were 1/1 linked, identity mismatch 0; punishments 0, mismatch 0. Rollback trigger/RPC tests confirmed UUID autofill and agreement under authenticated context; no test record survived. Frontend new point/punishment writes switched to UUIDs. Stale integer call sites failed CI until corrected. Numeric routes/reads intentionally remained at this checkpoint. The original log recorded this milestone twice from complementary perspectives; both referred to the same transition, not separate deployment counts.

### Historical branch-only frontend state

Core read-only roster, weekly/settlement NET dashboard, lead settlement start/close/next-day-period UI, exact reflection times/21:00 extension, and KST input defaults were prepared. That particular local environment could not run npm build because of external DNS restrictions. Later CI results are separate evidence.

### Private roster loading

Only minimal name/grade rows were loaded in Supabase, without addresses, resident IDs, contacts, or parent data. Grades expanded to 1–12. Four fictional seed students were soft-deleted; demo history remained attached. One erroneous private roster row was soft-deleted after review, with no point history. G9 section assignments required a separate source; no section column existed then.

Active count after loading: 175, by grade G1–12: 10, 7, 9, 9, 14, 15, 19, 19, 31, 21, 16, 5. Private roster-import/correction SQL remained remote-only. Department-merit spreadsheet data was not loaded. Draft migration paths in the original account were later reconciled to actual live versions; use the current ledger rather than those historical draft names.

## September 27, 2026 — Final discipline UUID cut-over

- Dropped physical point_records.student_id and punishments.student_id. Both now store core_student_id UUID NOT NULL only.
- Public contracts derive numeric IDs through the compatibility bridge. Core RPCs became authoritative; integer RPCs delegate to them. Department generation and reflection-grade lookup use UUIDs.
- New student links use UUIDs; old numeric URLs resolve through fallback.
- Shadow parity: weekly 1/1, weekly penalties 1/1, settlement 0/0, summary 175/175; every mismatch count zero. Public score/summary/read joins were then promoted.
- pg_depend identified true physical dependencies; a separate trigger audit caught new.student_id in reflection creation before drop.
- Stored aggregate-only evidence in discipline.core_cutover_evidence before destructive change. Post-drop flags legacy_columns_removed/cutover_completed were true.
- Core and legacy point/punishment paths plus reflection generation passed rollback probes; all test rows rolled back.
- Preserved points 1, sum 5, reflections 1, punishments 0, weekly report rows 175, and dashboard counts. These small counts do not establish high-volume performance.
- Reconciled 15 cut-over migration paths plus admin RLS optimization with actual live versions, without changing SQL content. Kept version uniqueness.
- Initplan-friendly admins_read_self_or_lead removed auth_rls_initplan warnings. Unused-index INFO remained pending meaningful usage history.

### Production ledger enforcement

Reconciled 16 additional historical structural version/name differences. Initial full checkpoint: 52 production, 48 tracked structural, 4 LIVE_ONLY_DATA, zero extra Git migrations. Added migration-ledger.json, checker, npm script, and CI enforcement of exact filenames, all tracked files, uniqueness, and absence of private-data SQL. Sensitive live migration names may be redacted. The first ledger CI run passed.

### G9 assignment

Frontend moved to assign_current_grade9_section_core(uuid,text), with Core UUID row/test IDs. Integer assignment remained a wrapper. Migration 20260926173405 was tracked, giving 53/49/4. Rollback tested Core G9-A and legacy G9-B on the same identity without retaining changes. Stale integer call sites failed intermediate typecheck; complete conversion passed.

### Browser read-only legacy bridge

Removed browser INSERT/UPDATE/DELETE and sequence usage, students_write/students_update policies, and unused StudentInput/create/update/delete hooks. Authenticated SELECT remains; anon has no privileges. Core provisioning/import is the only student-master write path. Migration 20260926175058 gave 54/50/4; final cleanup CI passed.

### Least-privilege legacy assignment wrapper

Changed the integer wrapper to SECURITY INVOKER; the authoritative Core RPC retains SECURITY DEFINER with lead checks. Advisor authenticated-definer warnings fell 11 → 10. Migration 20260926175410 gave 55/51/4.

## September 28, 2026 — Target-list navigation

Reflection target/missing/double cards open their respective lists. Today's records use KST dates. Missing includes ordinary missing and overdue double targets, matching dashboard count scope. Training/committee cards filter the student list; users can return to All. Responsibility limits remain enforced. Roster navigation is nested below admin accounts for leads and remains available as appropriate to ordinary SEONDO.

## September 28, 2026 — Korean typography and contrast

Unified fonts with Pretendard Variable dynamic subsets and system Korean fallback. Increased text/control/table/badge sizes and weights, added tabular numerals, adjusted light/dark text and input contrast. Representative calculated ratios exceeded 4.5:1 for text and 3:1 for boundaries; this was not full accessibility certification. Standardized Lucide size/stroke, fixed brand wrapping, removed noise overlay, enlarged login controls, restored mobile zoom, and improved print notes/headers. Font license: [Pretendard OFL 1.1](https://github.com/orioncactus/pretendard/blob/main/LICENSE).

## September 28, 2026 — Dashboard design, PR #11

Reordered date/week/actions, five target cards, weekly work, and student scores. Added calendar/merit/notice/reflection/settlement links; independent settlement query; distinct query-error versus unconfigured states; filter/search/sort/focus/empty-state improvements. Training/committee clicks clear search. Synthetic desktop/dark/320px/390px checks and local/PR type/build checks passed. [Design evidence](UI_DESIGN_SYSTEM.md).
