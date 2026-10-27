# Manual-entry testing state — 2026-10-27

This operating decision supersedes the initial cutover restrictions documented in HISTORY_AND_BACKFILL.md.

At the user's request all currently visible points were reset for manual-entry testing: 42 event rows were soft-deleted and 873 weekly balances marked non-current. The 898 original source rows and previous records remain archived. A private reset checkpoint stores the prior event, weekly-balance, automatic-rule and cron state. Four automatic department-merit rules and the weekly cron are paused. Restore/re-enable only following a new operating decision.

Manual merits and penalties now accept any past occurrence date, including dates before 2026-10-26 and before the current term. The selected occurrence date drives daily and weekly aggregation; the creation timestamp remains the actual entry time. Current-term totals retain the term's date range. Future dates are rejected. Superseded audit originals remain immutable. Backdated penalties retain occurrence-date-based reflection deadlines.

Validation: transaction-rollback tests verify past merit/penalty creation, date preservation, net aggregation into the correct past week, dates before the academic term, future rejection, and archived-original immutability. Test events are not retained. The date field has no lower bound and keeps its KST-today upper bound. Automatic grants remain paused.
