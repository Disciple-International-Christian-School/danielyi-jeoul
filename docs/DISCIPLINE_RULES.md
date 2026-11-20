# Current Point Display and Discipline Rules

**Language / 언어:** [English](DISCIPLINE_RULES.md) | [한국어](DISCIPLINE_RULES.ko.md)

Updated November 6, 2026. These recorded operational decisions supersede earlier threshold descriptions in the roadmap, initial specification, and journal. Later subsections also supersede conflicting earlier checkpoints below.

## Scores and committee referral

- Weekly NET = weekly merits minus weekly penalties. Term totals are available in point history.
- **Superseded historical rule:** Three penalty incidents used to qualify for training. The November revision **removes incident count as an eligibility condition**. Only weekly NET <= -8 or an overdue doubled reflection may qualify; counts remain informational.
- Committee eligibility requires three consecutive calendar weeks qualifying for training within the current academic term, independent of settlement start and cumulative NET. A gap breaks the run. The former 20-point and three nonconsecutive-week alternatives are removed.
- `physical_training_weeks` exposes the longest consecutive qualifying run in the current academic term; UI wording means longest consecutive training-week run.
- Imported weekly rows never invent unknown occurrence counts. Archived/deleted events are excluded. Historical reset balances remain non-current. Automatic merits, initially paused, were subsequently resumed as recorded in [department merits](DEPARTMENT_MERITS.md).
- Internal compatibility fields named `net_penalty_points` remain penalty-minus-merit. UI explicitly computes merit-minus-penalty from components; the backend owns eligibility.

Recorded SQL rollback checks cover a consecutive run across settlement boundaries, a missing middle week, 20 points without a streak, three low-point incidents offset by merits, two incidents, NET -7, and NET -8. No test rows are retained.

## Reflection eligibility — October 28

Only a negative full Monday–Sunday weekly NET makes a student eligible for reflection work. NET zero or positive does not, even when penalty incidents exist.

Only penalties whose entry-time running NET became or remained negative create actionable obligations. With +10, -5, -6, the -5 is covered; -6 makes NET -1 and is the first eligible reflection. The earlier covered record must not retrospectively become overdue double submission.

Later merits bringing the weekly NET to zero or positive deactivate related targets, missing/double badges, notices, and history statuses without deleting events or audit rows. Later eligible penalties reappear if NET becomes negative again. Existing weekly thresholds, deadlines, and historical source rows otherwise remain unchanged at this checkpoint.

Canonical projection `v_reflection_eligible_penalties` combines creation-order running NET with current full-week NET, reused by reflection, point-record, daily-notice and student-summary views.

## Notices, visual status, and responsibility scope — October 28

Responsibility scopes are ELEMENTARY G1–6, MIDDLE G7–8, HIGH G9–12. Reflection and history access must agree. This routes staff work; it does not change student grade/enrollment.

Today's print notice combines today's unsubmitted eligible reflections with all earlier unsubmitted records currently DOUBLE. Submitted and weekly-NET-ineligible records are excluded from the actionable notice, while audit history stays intact. Historical-date notices do not automatically carry overdue records into the past.

The dashboard Today count, default reflection worklist and daily notice use the same actionable set. The worklist offers all pending obligations and week-based history. Both screens show the signed NET of the incident week and the applicable submission deadline. The settlement management page is retired. Committee eligibility uses the current academic term directly. DOUBLE uses the existing red negative pill; training uses dark navy. Weekly printed/dashboard merits use +0, penalties use −0, and NET remains signed merit minus penalty.

## Additional training reason — October 28 (historical, superseded by November revision)

A student qualifies through any of three independent reasons: at least three weekly penalty incidents; weekly NET <= -8; or an unsubmitted double-reflection obligation after its 17:00 check deadline, effective from the following day. Display all applicable reasons on dashboard and notice/report outputs.

If the original submission deadline is before 17:00, use that day's 17:00 for the double-submission check; if it is at or after 17:00, use the next day's 17:00. Marking completion deactivates the double-missing reason; other reasons remain independent. For the three-consecutive-week rule, one double-missing obligation contributes only its first qualifying week, preventing duplicate weekly credit.

## Future-dated point entries — October 29, 2026

- SEONDO staff may set the occurrence date of a new positive or negative point to a past, present, or future local calendar day. The original entry date and the authenticated writer remain auditable at write time.
- Future entries are stored immediately, but become effective only when their `recorded_at` date arrives in Asia/Seoul. Weekly/lifetime/settlement balances, weekly incident counts, actionable reflection status and weekly training/committee indicators exclude future entries before that day. Existing history cutover protections remain in force.
- An underlying penalty/reflection row is preserved for audit, but a future reflection is not an actionable target until the occurrence date. Staff cannot mark a future penalty's reflection as already submitted from the point-entry form.
- Staff can verify saved upcoming events through the student record list, where future dates are marked `예정`. Affects only manually entered points, not DICS CORE enrollment or imported historical balances.

## Historical weekly balances restored — November 2, 2026

- The accepted 2026 Fall Google Sheet import was committed on 2026-10-26 with 898 source rows, 876 linked source rows and 873 aggregated student-week balances across eight operational weeks (August 24 through October 25; the August 19–23 camp and September 21–27 holiday weeks are excluded).
- The October 27 score-screen reset set all 873 `discipline.weekly_balances.is_current` flags to false. This preserved the imported source but hid every imported weekly balance from the authenticated `get_discipline_history` query, making the semester history and its student totals incomplete.
- On November 2, restored only the 873 rows in the previously approved import batch to `is_current=true`. No point event, reflection, training rule or settlement-period computation was changed; `is_current` is consumed by the term-history RPC.
- Authenticated supervisor query now returns 873 weekly rows plus 160 post-October-26 daily weekly aggregates for the current reporting range, a total of 1,033 student-week rows. The term cumulative NET in the history panel is merits minus penalties across these effective rows; `누적NET` on the main dashboard remains the separate current-settlement-period net.
- Twenty-two source rows remain unlinked to CORE IDs and are intentionally excluded from student totals pending identity review. They represent five distinct source names, including inactive or renamed students. No speculative links were created.

## Publication and calendar settlements — November 2026 revision

Operations activates the policy by setting a cutover timestamp in the Daniel-owned
discipline schema. Record the effective time at the start of a Monday for a complete
first weekly period. The migration leaves the timestamp unset. Earlier incidents
retain their original eligibility and deadlines. For the new policy, existing
pre-cutover merit balances are excluded because previous allocations were not recorded.

- In **Reports → Daily notice**, the discipline lead fixes the print cutoff, prints the
  draft, posts it, and confirms publication. Only receipt times before the cutoff are
  included. Printing again does not make another batch. The published notice records
  its rows and their original offense reasons for reprints.
- The effective receipt date is the later of the record entry and the scheduled offense
  or merit date. A merit may offset **only offenses occurring after the merit's effective receipt time**. Its eligibility is T through T+4, five **school days** across week boundaries; weekends, public holidays, and recorded DICS discretionary closures do not count. When received on a non-school day, T is the next school day. Spend unallocated eligible merits against the smallest subsequent penalties first. Reflection pages become final on publication; merits earned after publication never reduce an already posted notice. A merit cannot be spent twice.
- The posting date sets G7–G12's first deadline at 17:00. The second deadline is 17:00
  on the next school day. G1–G6 use 08:20 on the first and second school days. School
  days exclude weekends and recorded holidays. The included calendar covers the
  remainder of 2026 and the 2027 Korean public holidays. Add later public holidays and DICS school closures to
  `discipline.seondo_holidays` before they are needed.
- Outstanding double submissions reappear at subsequent cutoffs until submitted.
  Missing the second deadline is recorded for the week of that deadline, even when
  the student submits afterward. The weekly NET uses that week's merit and penalty
  totals. The merit carryover allocation is used for reflection pages.
- Weekly and monthly decisions finalize at 23:59 KST on Sunday and on each month's
  last day, respectively. Weekly training counts once per student regardless of the
  number of matching reasons. A week belongs to the month of its closing Sunday.
  Three finalized training weeks in the same month qualify G7–G12 for review.
- Approved school and committee accounts registered in
  `discipline.seondo_committee_recipients` receive the finalized report in the existing
  teacher portal. A recipient account receives one copy per month. No email or
  external chat is needed for this delivery.

Deploy the database migration before the app bundle. Verify the published notice,
one weekly and one monthly synthetic closure with the rollback test in
`supabase/tests/seondo_notice_and_settlements.sql`. The test runs with the
`supabase/tests/fixtures/seondo.sql` fixture and the two reflection notice migrations
in a disposable PostgreSQL environment. Confirm the rollout date and registered
recipients before activating the policy in production. Existing reflection eligibility, frozen page counts, and due dates **must not be recalculated retrospectively**.

## November 16, 2026 transition (approved)

- **G1–G6 weekly training**: weekly NET <= -8 **or** a missed second doubled-reflection deadline; once per student-week even if both apply.
- **G7–G12 weekly training**: **weekly NET <= -8 only**. Missed reflection deadlines still require reflection submission but do not independently trigger physical training. The three-incident trigger is abolished for all grades from November 16.
- **Reflection notices**: previously issued obligations remain under their historical rules, with no retroactive revisions. A newly posted notice freezes its page count.
- **November committee**: count approved old-policy qualifying weeks closing November 1, 8 and 15 together with new-policy weekly outcomes closing November 22 and 29. Refer G7–G12 with **at least 3 total weekly counts**, whether consecutive or not.
- **December committee**: count **only** the new-policy weekly outcomes whose Sundays are in December; refer G7–G12 with at least 3 counts. November counts do not carry over.
- **Elementary**: may qualify for physical training but is always excluded from monthly committee referral.
- **School calendar**: through December 23, 2026, there are no statutory or discretionary school closures beyond Saturdays and Sundays in the regular term.
- **New reflection-notice activation:** the live policy is scheduled for 00:00 KST on November 18, 2026. Existing reflection records through November 17 remain governed by their prior deadlines; the Seondo lead must explicitly close and post the first new notice.
- **Pre-transition history review**: authoritative historical training closures were never stored. Derived candidates are staged in `discipline.seondo_legacy_weekly_candidates` but are **not confirmed counts**; November month-end committee closure is gated until the school approves the snapshot. Training-week accrual for the new rule begins at 00:00 KST on November 16 independently from the non-retroactive reflection notice cutover.

## November 18, 2026 — unified live reflection targets

- Immediately after a penalty is recorded, calculate **live reflection pages** from valid forward-only merits (T through T+4 attendance days) and show the same result in the reflection list, dashboard cards, and daily notice preview.
- Zero-page penalties fully covered by prior merit are **not reflection targets**, without deleting their underlying point records.
- Before the print cutoff, pages are live computed values and may change as point records change. The print cutoff snapshots the current calculation for the physical notice; publication does not retroactively change earlier posted pages.
- A reflection submitted before publication must not be resurrected as outstanding or doubled when the notice snapshot is read.
- Preview reads never insert merit allocations or alter reflection due dates.

## 2026-11-20 — Submission clocks survive unpublished notices

Original `reflection_records.due_at` controls doubling even when printing or publication has not been confirmed. Today's preview must not replace an earlier first deadline with today's deadline or downgrade DOUBLE to MISSING. Second deadlines follow the school calendar; overdue pages double once and remain open until submission.

Migration `20261120022738_reflection_deadlines_without_publication` preserves all student records and past notice entries. Carryover snapshots reference their source batch, leaving one canonical initial obligation and one merit allocation. This also fixes the unique-index error on consecutive daily cutoffs. Cutoff and publication no longer restart submission clocks.

Production verification under the authorized Seondo role: 8 actionable November 18 cases and 21 November 19 cases returned `is_double=true` after application. A rolled-back rehearsal produced the same counts. Synthetic database checks covered missing publication, secondary and elementary deadlines, consecutive/idempotent cutoffs, unchanged earlier pages/deadlines, submitted exclusions, and weekend skipping. Live browser rendering remains to be checked after frontend deployment.

## 2026-11-21 — Cancelled notice records and current obligations

Notice reads now exclude cancelled/superseded point records from every date, while keeping stored snapshots for audit. Today's print list also omits completed submissions. The current reflection queue consumes a separate `live_entries` array even after cutoff/publication; an empty array is authoritative and never falls back to frozen print rows. This prevents a deleted reflection absent from `v_reflections` from being synthesized as an overdue pending obligation.

A replacement entered after the cutoff remains in the live reflection queue with its own original deadline. It is included in the next notice, and the print screen reports the count of pending post-cutoff entries. Original cutoff membership is preserved. Create/update/delete/submission mutations invalidate both notice and reflection caches.

Migration `20261120153500_cancelled_notice_live_queue` was applied after a rolled-back production rehearsal. Synthetic SQL tests cover cancellation after cutoff, replacement after cutoff, single-page non-double state, submission exclusion and retained audit snapshots. Existing consecutive-cutoff tests, frontend regressions, typecheck and build passed. Production verification confirmed the cancelled case is absent and the valid replacement remains an ordinary obligation. No student source record was rewritten.
