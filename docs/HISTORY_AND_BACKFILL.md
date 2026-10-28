# DaS weekly history and daily-entry cutover

**Language / 언어:** [English](HISTORY_AND_BACKFILL.md) | [한국어](HISTORY_AND_BACKFILL.ko.md)

> Initial cut-over record. Later [manual-entry reset](OPERATIONS_2026-10-27.md), [department-merit](DEPARTMENT_MERITS.md), and [current-rule](DISCIPLINE_RULES.md) decisions supersede its operational-state and eligibility checkpoints. Original source rows remain historical evidence.

## Operating contract

The source workbook contains independent final weekly settlements, not running totals. The weekly net is merit minus penalty. The source's two component columns are retained as supplied; they are not a reconstruction of individual incidents.

- Through 2026-10-25, secondary-school weekly settlements replace older DaS events in official aggregation.
- From 2026-10-26, actual daily events and eligible automatic department merits accumulate against the same CORE UUID.
- Old events remain in `point_records`, linked to the superseding import. Operational views exclude them. The immutable originals can be inspected by an authorized database operator.
- Elementary records are outside this secondary-school import and remain included.
- Camp 8/19–23 (week beginning 8/17) and Chuseok 9/21–27 are `NO_SCHOOL`, not zero-score observations.
- Missing student rows remain missing. An inactive CORE identity retains its history; an unknown identity stays in the source archive without creating a new active student.
- The ongoing 10/26–11/1 sheet is excluded. Its entries are not assumed to duplicate the daily database.
- The prior settlement closes 10/25; the new operational settlement starts 10/26. Term history survives settlement closure.

## Production reconciliation

The structural migrations and initial import were applied on 2026-10-26 UTC. Initial source rows: **898**. Linked current weekly balances: **873**. Unlinked source rows: **22** across five historical class/name identities. Three duplicate groups collapsed. All original rows, blank cells, formulas/effective values, and annotations are retained in the private database.

| Week | Original rows | Distinct source identities | Linked balances | Source merit | Source penalty | Linked merit | Linked penalty |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 8/24–8/30 | 111 | 111 | 106 | 0 | 39 | 0 | 30 |
| 8/31–9/6 | 114 | 113 | 108 | 0 | 142 | 0 | 129 |
| 9/7–9/13 | 113 | 113 | 109 | 0 | 318 | 0 | 315 |
| 9/14–9/20 | 113 | 113 | 109 | 100 | 247 | 100 | 243 |
| 9/28–10/4 | 113 | 113 | 110 | 0 | 266 | 0 | 266 |
| 10/5–10/11 | 112 | 111 | 110 | 0 | 158 | 0 | 158 |
| 10/12–10/18 | 111 | 110 | 110 | 0 | 387 | 0 | 387 |
| 10/19–10/25 | 111 | 111 | 111 | 0 | 123 | 0 | 123 |

The earlier analysis omitted one row with a malformed class cell. The exact name has one consistent class across the other tabs; the import preserves the malformed original and documents the class resolution. This restores an eight-point penalty. The original 100-point merit remains included with an explicit review note, not silently corrected.

**170 non-deleted secondary events** were superseded. The elementary penalty was preserved. On 10/26, all **40 existing events** remained: two manual penalties totaling 9 and 38 automatic merits totaling 86. Importing weekly balances created no reflection records. The current reflection view contains the two current secondary records plus the preserved elementary record.

Source student identities and raw payloads are private operational data and must not be committed to this repository.

## Storage, revision, and access

- `discipline.history_settings`: term, cutoff, grade scope, activation audit.
- `history_import_batches` and `history_source_rows`: original payload, hash, source coordinates, components, net, resolution, importer/time. Large annotations are retained without inventing events.
- `history_aliases`: explicit class-aware alias mapping. Never globally strip name suffixes or join by row position.
- `weekly_balances`: one current row per term/student/week, prior versions retained. Replacing a week must include every previously imported source identity. Partial uploads fail atomically.
- Identical or zero-placeholder duplicates collapse to the same nonzero settlement. Distinct nonzero settlements for one student/week fail. Never sum duplicate final values.
- Re-uploading an identical current payload is idempotent. A stale previously superseded payload is rejected. Changed payloads create an import revision, not additive balances.
- `public.get_discipline_history(student_id,start,end)` returns exact weekly settlements, daily-derived weekly totals, identity, source precision, review notes, and calendar. Weekly source rows have `incident_count = null`.
- Staff reads obey the admin's grade scope. Non-admin callers must supply their own CORE student ID linked to `auth.uid()`. Anonymous calls are denied. Import/status/activation require a lead administrator.
- Six new tables have RLS. Public RPCs are invoker wrappers; privileged internals live in the private schema with explicit role/ownership checks and an empty search path.

Weekly periods are indivisible. A day query in the historical range returns the overlapping **whole weekly settlement**, visibly labeled as such; it must not be described as a daily score. Term totals cover available records only. Missing rows and non-operating weeks are not filled with zero.

## UI and daily operations

- Dashboard: date/week/term history plus a lead-only link to the weekly import/reconciliation page.
- Student detail: semester weekly trend, source precision, component values, missing/no-school gaps, and an inactive-identity fallback. The editable daily list remains explicitly labeled as the most recent 100 events; totals come from the complete RPC, never that capped list.
- Import: `.xlsx` multi-tab parser, completed-week filtering, source totals, duplicate/malformed-class/large-value warnings, unresolved identity preview, explicit replacement review, import history, and current unresolved source rows.
- Entry: required custom reason (80-character DB limit), preset changes clear stale score, continuous student entry retains the selected reason, request UUID prevents retried saves from duplicating, recent-save undo, cutoff/future-date guards.
- Operational penalty-minus-merit numbers are labeled **`순벌점`**. Historical source-compatible totals are labeled **`최종값/학기 누계 = 상점 − 벌점`**. Threshold formulas are unchanged.
- Reflection extension: occurrence date + one day at 17:00 KST; Saturday/Sunday occurrences extend to Monday 17:00. Friday therefore extends to Saturday under this literal policy. The default same-day deadline is unchanged. Already-submitted rows cannot be extended. Legacy RPC callers receive the new extension behavior too.
- Reports: optional announcement text with immediate print preview. Text is retained only while the page remains open; it is not a shared saved announcement.
- Department creation distinguishes first load from explicit new mode. Automatic merits retain source-key uniqueness, handle concurrent retries, and skip historical imported secondary weeks.

## Rules audit

The source rules tab and active app rules were compared. No new school policy or score was invented.

| Difference | Source | Current app | Handling |
| --- | --- | --- | --- |
| Punctuation/spacing | `등교지각, 욕설·비속어` | `등교 지각, 욕설` | Recorded for canonical-name review |
| Grouped vs split | `세상노래 가창/연주`, each 7 | `세상노래`, 7 | Existing score unchanged; splitting remains a policy/catalog decision |
| Wording | `교실 미소등`, 2 | `미소등`, 2 | Existing score unchanged |
| Blank source scores | `등교지각, 잔반` and other manual items | `등교 지각/잔반` currently 2 | A blank is not interpreted as zero or a request to erase an existing rule |
| Fixed source-only items | `교실 미정리 2; 냉난방 문단속 2; 슬리퍼 등교 2; 복도통행 2; 성경책 미지참 5; 선풍기 가동 2; 체육복 미착용` 2 | No matching preset | Available through custom reason/score; catalog synchronization is pending policy review |
| Additional source-only blank items | `교외 실내화 착용; 교내 실외화 착용; 식사 후 테이블 미정리; 교내 취식; 복도 양치` | No matching preset | Custom input supported; fixed score not fabricated |
| App-only items | Not listed in source tab | `암송 미완료; 일기 미제출; 수업태도 불량; 선생님 재량 벌점` | Retained; teacher-discretion 1–5 validator unchanged |

## Verification and remaining boundaries

Passed: TypeScript; production build; date boundary tests; source-parser duplicate/sign/date/cell-validation tests. Transaction-rollback database tests covered exact source and linked totals, no new reflections, elementary preservation, current events, repeated file upload, partial-file rejection, daily request idempotency, cutoff enforcement, automatic-merit retries, staff RPC access, student ownership/cross-student rejection, anonymous rejection, and KST extension dates. Production was re-queried after the atomic import.

Supabase advisors found no newly introduced security finding. A new history foreign-key index finding was fixed in the follow-up migration. Existing cross-app advisories remain outside this change; details are available in the Supabase project advisor. See [Supabase advisor reference](https://supabase.com/docs/guides/database/database-linter).

Live sign-in is required for device/browser acceptance of staff-only pages. The cloud browser reached the production login page but had no administrator session; authenticated visual acceptance must not be claimed as complete.

Student-facing SP/dashboard integration, unresolved former-student identity decisions, review of the original 100-point merit, optional catalog synchronization, personal staff-account assignments, and previously pending student Auth/PIN onboarding remain explicit follow-ups. The shared CORE read API is ready; those other apps were not modified by this change.
