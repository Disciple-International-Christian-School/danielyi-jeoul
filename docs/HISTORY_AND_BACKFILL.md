# DaS history and daily-entry cutover — 2026-10-26

## Confirmed operating contract

This document supersedes the earlier backfill proposal. The source workbook contains independent, final weekly settlements; tabs are not running totals.

- Through 2026-10-25: preserve weekly settlement values as authoritative student-week results.
- From 2026-10-26: accumulate actual daily events and eligible automatic department merits using the same CORE student UUID.
- 2026-08-19–23 is camp and 2026-09-21–27 is the Chuseok break. These are explicitly non-operating periods, not missing uploads and not observations of perfect behavior.
- There are eight completed weekly tabs before cutover and one ongoing 10/26–11/1 tab. Never import the ongoing tab as a completed weekly settlement.
- A missing student row is not a zero score and is not proof of withdrawal. Resolve against CORE and preserve uncertainty.
- Active rosters and historical identity are separate: inactive/withdrawn students disappear from current input lists; their existing historical records remain attributable. Never attach an unmatched former student to a similarly named active student.
- The user explicitly excluded one transferred student's source rows from active import; retain source provenance and an exclusion reason without recreating an active CORE account.

## Evidence from source and production (read-only)

The original Google Sheet has three five-column blocks: class, name, merit, penalty, net. Source net formulas are merit minus penalty. App operational views currently use penalty minus merit.

| Completed week | Source rows | Distinct class/name pairs | Source merit sum | Source penalty sum |
| --- | ---: | ---: | ---: | ---: |
| 8/24–8/30 | 111 | 111 | 0 | 39 |
| 8/31–9/6 | 114 | 113 | 0 | 142 |
| 9/7–9/13 | 113 | 113 | 0 | 318 |
| 9/14–9/20 | 113 | 113 | 100 | 247 |
| 9/28–10/4 | 113 | 113 | 0 | 266 |
| 10/5–10/11 | 112 | 111 | 0 | 158 |
| 10/12–10/18 | 111 | 110 | 0 | 387 |
| 10/19–10/25 | 110 | 110 | 0 | 115 |

These are raw-source control totals, NOT approved CORE totals. Duplicate rows, excluded former students, and an unconfirmed 100-point entry must be resolved before publication. Do not interpret source penalty columns as reconstructed gross daily penalties when only the final weekly balance is established.

Three duplicate student-week groups exist (zero/nonzero and zero/zero). Name suffixes also change, and a historical class/name resembles a current student in another grade. Mapping must use explicit, class-aware aliases and preserve originals. Do not automatically strip suffixes globally or match by row position.

The 10/12–18 tab also has weekly narrative notes listing training targets and overdue reflection names. Preserve those as source annotations, not dated incidents, verified punishment completions, or reconstructed incident counts.

Before cutover the live DB contains 171 non-deleted event rows: 158 automatic merits totaling 374 points, 12 manual penalties totaling 25 points, and one manual merit worth 2 points. They are NOT an additional opening balance on top of the final source settlements. Preserve them for audit and reconcile coverage; do not blindly delete them or label them all test data.

On 10/26 the DB already has two manual penalties totaling 9 points and 38 automatic merit rows totaling 86 points. Today's sheet has two different penalty rows totaling 10 points. Neither side proves duplication or test status. Do not erase today's entries or import its aggregate as dated events.

The open operational settlement starts 9/30, midweek. A weekly historical total cannot be split across 9/30 without daily source data. Academic-term history and operational settlement eligibility must therefore remain separate during cutover.

## Required storage and query model (not yet implemented)

1. Immutable import batch and source rows: source workbook/tab IDs, source range, original class/name, original entered values, formulas/effective net, snapshot checksum, importer, and import timestamp. Blank cells remain distinguishable from entered zeroes.
2. Resolution layer: CORE UUID or explicit unresolved/excluded status, alias justification, duplicate decisions, anomaly-review state, and revision history. Each reviewed student-week has one effective settlement. A changed source snapshot becomes a revision rather than a second additive batch.
3. Historical weekly settlements: term, CORE UUID, week bounds, exact source net, source components as supplied, weekly precision, review status, and provenance. Occurrence date and incident count remain unknown. Importing this layer never invokes the daily penalty/reflection trigger.
4. Daily events from cutover: actual occurrence date separate from entry timestamp, reason/category, point type/value, actor UUID, source, and request idempotency key. Retried saves must not produce duplicate events; intentional identical incidents remain possible with distinct request IDs.
5. A shared student-week/term read model: select historical settlement before cutover, daily-event aggregation from cutover onward. Do not UNION and sum both sources for the same week. Incomplete/reviewed/excluded/no-school/not-enrolled states must survive aggregation; a partial total must not be labeled a complete semester total.
6. Access: authenticated users only within established admin scope; future student endpoints restrict to that student's CORE/Auth mapping at the database layer. Reuse this read model in SP and student dashboards rather than rewriting formulas in each frontend.

Term trend = sum of reviewed historical weekly net + sum of daily net from cutover. Keep this independent of discipline periods, reflection status, and training incident-count thresholds. Past weekly settlements do not generate overdue reflections or retroactive punishments.

Operational metrics may retain signed penalty-minus-merit semantics for compatibility. User-facing trend should explicitly say which direction is positive; preferred source-compatible display is merit minus penalty. Never flip stored scoring rules or threshold comparisons merely to change display signs. Show merit/penalty components and plain-language surplus where known; label historical gross components unavailable if only final balance is reliable.

## UI review and meeting requirements

The current app is an administrative console with separate menus; it does not yet complete the field-entry → weekly review → student-trend workflow.

| Meeting item | Verified current state | Required response |
| --- | --- | --- |
| Add department / instrumental leaders | New-department reset is immediately undone by initial auto-selection effect | Fixed in this draft by distinguishing initial selection from explicit create mode; no department/rule values invented |
| Manual merit and penalty entry | Score/date inputs exist but custom reason is saved only as a generic label | Fixed in this draft with required free-text reason; preset changes clear stale point values |
| Clear existing penalties before launch | Contains pre-cutover overlap and real entries after cutover | Source-based reconciliation and reversible exclusion, never blanket deletion |
| Merit reflected in weekly score | SQL already subtracts merits from penalties | Expose components and consistent sign labels; no second merit-deduction event |
| Grade-9 name suffix | Roster change already verified in prior work | Link history to UUID and preserve source spelling |
| Extend deadline to next day 17:00 / weekends Monday 17:00 | DB and UI still use same-day 21:00 extension; default trigger remains same-day 17:00 for secondary | Update extension policy and labels together; distinguish an extension request from a default-deadline change; test Friday/weekends/KST and already-submitted rows |
| Historical weekly upload | Absent | Preview → mapping/exceptions → atomic versioned commit → student-week reconciliation |
| Click previous dashboard date | Implemented in draft PR #15; not deployed | Verify signed-in/mobile behavior; weekly source periods should open a weekly summary, not fabricated daily records |
| Student semester trend | Draft totals only cover existing event rows; detail page caps at 100 records and requires active roster summary | Add unified week history with full pagination and separate historical identity lookup |
| Printable announcement text | No input in current Reports page | Add optional notice with print preview and unambiguous save/persistence behavior |
| Rules source spreadsheet | Reference requirement visible in screenshot | Audit rule mapping against the rule tab before changing item values |

Recommended information architecture:

- **Input:** mobile-first student search → preset/custom reason → points/date → save feedback and recent editable entries. Keep useful repeat conditions, show offline/save errors, and prevent accidental repeat submissions.
- **Today / weekly review:** selected date or week, entered records, pending reflections, component totals, and source/completion state. Date selection must visibly scope the content it controls; keep historical data distinct from current action cards.
- **Student history:** CORE identity, week-by-week net and cumulative trend, source precision, admission/withdrawal context, and optional daily detail only where it exists. Use term cumulative for trajectory, not a permanent current-punishment balance.
- **Management:** imports/reconciliation, rule versions, department membership, settlement periods, notice output, admin accounts, and audit history. Keep these out of the frontline entry sequence.

Future insights must account for enrollment duration, non-operating weeks, the weekly-to-daily measurement change, and missing observations. A lower recorded total alone is not proof of improved behavior. Do not infer violation frequency from historical weekly balances.

## Draft implementation and validation

Existing PR #15 provides weekday record links, date/week navigation, and a paginated event archive. This update fixes department-create mode and adds actual custom reasons. It does not implement the historical storage/read model above, import production data, reset a settlement, change the reflection policy, or deploy.

Required checks: typecheck, production build, history date-boundary tests; signed-in field-entry, department-create, contrast/mobile, and scope verification remains before rollout. All production DB inspection for this review was read-only.

## Completion order

1. Archive source and resolve explicit exceptions; produce approved student-week coverage.
2. Add historical storage plus a single CORE-based query path with exclusive cutover and idempotent revision handling.
3. Reconcile old event rows and operational settlement boundary without deleting originals or backdating unknown events.
4. Finish field-entry and deadline behavior, personal admin accountability, and live device verification.
5. Deliver student history and later consume it from SP/student dashboards.

This is the agreed target and implementation backlog, not a claim that migration is complete.
