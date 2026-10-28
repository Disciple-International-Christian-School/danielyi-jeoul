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

## Notice, visual status, and grade scope — 2026-10-28

- Responsibility: elementary G1–6, middle G7–8, high G9–12. Reflections and the history RPC must agree. This is a staff routing classification, not a change to the student's grade.
- Current-date print notice contains today's unsubmitted eligible reflections plus all earlier unsubmitted reflections currently in DOUBLE status. Submitted and weekly-NET-ineligible penalty records are excluded from the **target notice**, though point audit history is preserved. Non-current date print notices do not automatically carry overdue rows into history.
- The dashboard's Today target count reflects the same actionable new-plus-carried set. `DOUBLE` badges use the established red negative pill; physical training uses dark navy. Training criteria themselves are unchanged.
- Sign conventions on dashboard and printed weekly report: weekly merits `+0`, weekly penalties `−0`, weekly NET remains signed merit minus penalty.

## 2026-10-28 — 체력훈련 사유 추가

- 세 조건 중 하나면 대상: 주간 벌점 3회 이상 / 주간 NET -8 이하 / 2배 반성문 17시 미제출 후 익일.
- 최초 제출 마감이 17시 이전이면 해당일 17시, 17시 이후라면 다음날 17시를 2배 제출 확인 마감으로 사용.
- 완료 표시되면 2배 미제출 사유는 비활성화하며 다른 조건은 독립 유지.
- 3주 연속 대상 판정에서 2배 미제출 1건은 최초 대상 주차 1회만 인정.
- 모든 해당 사유는 대시보드와 공지 출력에 표시.
