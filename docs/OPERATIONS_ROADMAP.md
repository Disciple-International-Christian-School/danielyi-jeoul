# Daniel's Scale — Operations Roadmap

**Language / 언어:** [English](OPERATIONS_ROADMAP.md) | [한국어](OPERATIONS_ROADMAP.ko.md)

> Active design record, September 25, 2026. Historical implementation checkboxes are preserved below; use the later [change log](CHANGELOG.md) and [cut-over record](DISCIPLINE_CORE_CUTOVER.md) for completed work. This document defines intended behavior, not a fresh audit of production.

## 1. Operational direction

Support the full workflow: collect morning demerit sheets → enter records quickly → generate same-day reflection requirements → collect by responsible grade group → print class notices → review weekly training eligibility → accumulate an administrator-closed settlement → identify disciplinary-committee referrals.

New designs use DICS Core. Daniel's Scale is the discipline domain, not another independent student master.

## 2. DICS Core student identity

`core.students.id` is the canonical school UUID; `student_no` is a human-facing identifier; optional `auth_user_id` refers only to an account inside the Core Supabase project. External Auth UUIDs belong in `core.external_auth_identities`. Do not link apps by names or create separate domain student masters.

The legacy Daniel serial ID and SP's Auth-as-student-PK are transitional. Daniel's `public.students.core_student_id` bridge connects old rows until UUID cut-over and eventual compatibility retirement. Students may exist without accounts.

PINs are authentication credentials, not profile fields. Never store plaintext PINs in Core or Git. Authentication provisioning owns them. Core may hold necessary DOB/gender data; discipline projections should expose only student UUID, number, name, grade, and homeroom.

## 3. Academic terms and enrollment

Grades and classes are term membership, not permanent student attributes. Use `core.academic_terms`, `core.classes`, and `core.enrollments` linked to `core.students`. A student can move from G9-A in 2026-FALL to another placement without overwriting history. Notices use the same current-term placement. Private rosters stay ignored by Git; existing minimal operational rows are the bootstrap source.

## 4. Score calculation

Preserve original positive and negative points separately. Derive `net_penalty = negative_points - positive_points` for policy decisions; do not erase raw records through netting.

## 5. Weekly review

Weeks begin Monday. Physical-training eligibility is at least three NEGATIVE incidents or weekly NET at least 8. Reports show name/grade/class, incident count, merits, demerits, NET, and eligibility, with printable output for the responsible operator.

## 6. Settlement follows home-leave cycles

Calendar months do not fit a variable two-to-three-week home-leave cycle. `settlement_periods` permits one OPEN period. Administrators close it at actual home leave; leaving it open explicitly continues accumulation. A subsequent period can begin the next day.

## 7. Disciplinary-committee referral

Within the open settlement, eligibility is `physical_training_weeks >= 3 OR settlement_net_penalty >= 20`. Derive eligible weeks from underlying point records instead of entering an unverified manual counter.

## 8. Automated department merits

Private membership spreadsheets do not belong in Git. Dated memberships and weekly rules generate POSITIVE point records on Mondays. Requirements: no duplicate student/week generation; identifiable automatic provenance; start/end dates; visible results; and traceable corrections rather than hard deletion. Exact department/rule values need school approval.

## 9. Reflection deadlines

G7–G12: same-day 17:00 by default, discretionary extension to 21:00 for afternoon or exceptional cases. G1–G6: next school morning rather than the same evening. `due_at timestamptz` expresses the time boundary that a date-only field cannot.

## 10. Responsibility scopes

Individual SEONDO accounts use ELEMENTARY (G1–6), MIDDLE (G7–9), HIGH (G10–12), or lead/ALL. Actual operator identities stay in operational data. Leads need oversight of omissions, consolidated entry, weekly review, and teacher reporting.

## 11. Morning entry UX

P1: keyboard-focused continuous student search, today's date, retained repeated item/score fields, immediate next-student entry, and efficient handling of multiple paper records. P2: photo → recognition → proposed records → mandatory human review → confirmed save. Recognition never auto-confirms unreviewed student records.

## 12. Daily class notices

Group today's demerit/reflection targets by grade and class, including G9-A/B. Provide date/grade/class filters, reason, submission status/deadline, A4 formatting, and hidden navigation when printing. The output is a ready-to-use notice.

## 13. Weekly reporting

Show three-incident and NET-8 thresholds, training targets, missing reflections, and current settlement accumulation together. Produce A4 weekly reports and target lists.

## 14. Entry and login

This internal tool opens directly to administrator ID/password login; an authenticated operator goes to the dashboard. A marketing landing page is unnecessary for this workflow.

## 15. Administrator identity and audit

Personal account → SEONDO/SASAENG role → responsibility scope → created_by/updated_by → audit log. Existing `seondo`/`sasaeng` shared accounts remain transitional fallbacks and are phased out only after individual account verification.

## 16. Relationship to other school apps

Phase A creates Core students/terms/classes/enrollments, numbers, optional local Auth, and external bridges. Phase B maps Daniel integers and SP external Auth to verified Core UUIDs. Phase C changes domain FKs to canonical UUIDs. Phase D can combine learning progress, discipline, assessment, and computer-lab history in a student profile. Cross-app joins use a shared UUID, not guessed name/number strings.

## 17. Historical implementation checklist

### P1-A — Core and operations foundation

- [x] Core students, terms/classes/enrollments design
- [x] Legacy bridge and minimal-operational-roster bootstrap prepared and applied
- [ ] Confirm the SP mapping plan against current operations
- [ ] Resolve the historical G9-A/B verification backlog (144 non-G9 enrollments; 31 G9 pending at this checkpoint)
- [x] Simplified login, weekly positive/negative/NET views, and eligibility foundation

### P1-B — Settlement

- [x] Period table, single OPEN period, administrator close, NET, eligible-week count, committee decision

### P1-C — Reflections

- [x] due_at, 17:00 default, 21:00 extension, elementary next-morning deadline, grade scopes, daily targets, class printing

### P1-D — Reports

- [x] Weekly review, training-list printing, omission/aggregate oversight

### P2 — Automation

- [x] Monday department-merit foundation and continuous entry
- [ ] Photo intake and reviewed extraction
- [x] Individual-account structure and detailed audit foundation (rollout requires operational confirmation)

### P3 — Legacy retirement and unified profile

- [x] Discipline FKs to Core UUIDs — completed in the later cut-over record
- [ ] Retire public.students compatibility bridge
- [ ] Complete SP FK migration and verify its operational state
- [ ] Use Core UUIDs from the start in new lab/assessment tables
- [ ] Unify school-wide Auth/PIN provisioning policy
- [ ] Unified student learning/discipline/school-record view

## 18. Data protection

Never commit real names/number/PIN rosters, including SQL containing student lists. Do not duplicate unnecessary DOB/gender data into discipline. Print the minimum needed information. Define retention and deletion policy before introducing photo uploads.
