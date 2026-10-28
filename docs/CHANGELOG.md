# Daniel's Scale — Change Log

**Language / 언어:** [English](CHANGELOG.md) | [한국어](CHANGELOG.ko.md)

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

## October 15, 2026 — Core roster synchronization

Applied trigger-based creation/update of Daniel compatibility rows from active Core students/current enrollments. Core name/activity and enrollment additions/changes/endings synchronize automatically; inactive or no-current-enrollment students disappear from the active roster. Term changes resync all bridges. One active Core-only student was backfilled. Core UUID remains authoritative. Live migration: 20261015101921_sync_daniel_roster_from_core.sql.

## October 26, 2026 — English-first bilingual documentation

Expanded the existing bilingual overview PR to all maintained Markdown documents with English defaults and Korean counterparts. Added a project case study, language-maintenance checks, and historical-attachment translations. Replaced an account handout containing real student identifiers/PINs with a synthetic template. Historical Git objects still require owner review; document replacement is not credential rotation or history erasure. New commit messages are English-only. Existing-message rewriting is prepared separately from the owner-reviewed documentation PR.

## October 28, 2026 — Reflection eligibility follows negative weekly NET

Reflections now require current Monday–Sunday NET below zero and negative running NET when that penalty was entered. Covered early penalties never become retroactively overdue/double. Reflection, notice, point-history and dashboard summaries share the DB eligibility projection without altering source/audit records. Migration 20261028003013 was applied; the recorded check excluded 12 of 81 formerly active rows (including two double-status rows), leaving 69. Transaction-rollback regression tests passed. Deadline/training rules were unchanged at this checkpoint.

## October 28, 2026 — Carried notices, G9 scope, and printed status

Today's notice includes today's unsubmitted eligible records plus older current DOUBLE records; submitted or NET-offset targets are excluded. Historical-date notices do not carry forward rows. Reflection filters and Today counts use the same set, with 60-second refresh and submission-cache invalidation. Weekly penalties show an explicit minus sign; training is dark navy and DOUBLE remains red.

G9 responsibility moved to HIGH across DB views, history RPC and frontend filters without changing enrollment. A4 margins became 16×17 mm, with 12.5px table text, expanded header/cell spacing, stable page splits and emphasized original dates/double status. Migration 20261028012114 was applied and G9 HIGH routing verified.

## October 28, 2026 — Third physical-training criterion

An unsubmitted double-reflection obligation after its 17:00 check deadline adds training from the following day. Existing weekly incident/NET conditions remain independent and all reasons are displayed. Checks cover deadlines, release upon submission, and no duplicate weekly qualification. Dashboard, detail, weekly print and periodic reads use the rule. See [current discipline rules](DISCIPLINE_RULES.md).
