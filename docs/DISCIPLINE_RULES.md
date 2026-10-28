# Current point-display and discipline rules

Updated 2026-10-27 by user instruction. This supersedes earlier threshold descriptions.

- 주간 상벌NET = weekly merits minus weekly penalties.
- 누적NET = merits minus penalties in the current operational settlement period. Starting/closing a period controls this cumulative score's bounds.
- Weekly training: weekly NET <= -8 OR at least three penalty occurrence records in the same Monday–Sunday week. Merits offset scores, not occurrence count. Equal to -8 qualifies; -7 does not without three occurrences.
- Discipline: three consecutive calendar weeks qualifying for training in the current academic term. This is independent of the settlement-period start and cumulative NET. A gap breaks the run. Previous 20-point and three nonconsecutive-week alternatives are removed.
- `physical_training_weeks` now exposes the longest consecutive qualifying run in the current term through the settlement end. The UI labels it 最長/최장 연속 체력훈련 주차.
- Imported weekly source rows do not invent missing occurrence counts. Archived and deleted event rows do not participate. The reset historical balances remain non-current and automatic merits remain paused.
- Internal compatibility fields named `net_penalty_points` remain penalty-minus-merit. UI displays explicitly compute merit-minus-penalty from the components. The backend owns eligibility.

Verification: SQL rollback regression checks cover three consecutive weeks across a settlement boundary, a missing middle week, a 20-point total without a streak, three low-point penalty occurrences despite offsetting merits, two occurrences, NET -7, and NET -8. Test records are not retained.

## Reflection-paper eligibility — 2026-10-28

- **주간 상벌NET = 해당 월요일~일요일 상점 합계 − 벌점 합계.** Only NET < 0 makes the student a reflection-paper target; NET 0 or positive does not, even with penalty incidents.
- Only penalties entered at a time when that week's running NET became negative contribute reflection obligations. Example: +10, -5, -6 means the -5 is covered; -6 makes NET -1 and becomes the first eligible reflection. The -5 must not retrospectively become 2x due.
- When later merits bring the week's NET to 0 or positive, the corresponding reflection targets, missing/double badges, daily notices, and history statuses become inactive. Point events and underlying reflection audit rows are not deleted. When NET becomes negative again, eligible later penalties reappear.
- The weekly physical-training rule remains independent: **NET <= -8 OR three penalty incidents**. Other thresholds, deadline schedules, and settled/historical source rows are unchanged.
- DB canonical projection: `v_reflection_eligible_penalties` (creation-order running NET + current full-week NET), reused in `v_reflections`, `v_point_records`, `v_daily_discipline_notice`, and student-summary status aggregation.
