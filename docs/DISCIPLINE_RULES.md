# Current Point Display and Discipline Rules

**Language / 언어:** [English](DISCIPLINE_RULES.md) | [한국어](DISCIPLINE_RULES.ko.md)

Updated November 6, 2026. These recorded operational decisions supersede earlier threshold descriptions in the roadmap, initial specification, and journal. Later subsections also supersede conflicting earlier checkpoints below.

## Scores and committee referral

- Weekly NET = weekly merits minus weekly penalties. Term totals are available in point history.
- Weekly training initially uses NET <= -8 OR at least three penalty occurrence records in the Monday–Sunday week. Merits offset points, not occurrence counts. NET -8 qualifies; -7 alone does not. The additional overdue-reflection criterion is defined below.
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

## Additional training reason — October 28

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
