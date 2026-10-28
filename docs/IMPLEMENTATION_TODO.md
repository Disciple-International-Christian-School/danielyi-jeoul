# Weekly Ledger and Daily Operations — Implementation Checklist

**Language / 언어:** [English](IMPLEMENTATION_TODO.md) | [한국어](IMPLEMENTATION_TODO.ko.md)

Historical checklist for the October 26 cut-over: final secondary-school weekly balances through October 25 replace old events in official aggregation; daily events/automatic merits accumulate from October 26. Elementary data and original audit events are preserved. Later [reset](OPERATIONS_2026-10-27.md), [merit](DEPARTMENT_MERITS.md), and [rule](DISCIPLINE_RULES.md) decisions supersede the relevant initial state.

- [x] Preserve eight weeks/898 original rows, 873 linked balances, and 22 unlinked rows separately.
- [x] Apply weekly-ledger/source/revision/idempotent-import schema.
- [x] Exclude 170 superseded secondary events from official totals and historical reflections from current obligations.
- [x] Start the October 26 settlement; verify daily/weekly/term reads and elementary/current-day 40-event preservation.
- [x] Provide historical date/week reads, student trends, term totals, and inactive-student history.
- [x] Provide multi-tab XLSX import, preview, anomaly/partial-file rejection, and import history.
- [x] Require manual reasons, prevent retry duplication, and support recent-save undo.
- [x] Extend reflections to next-day 17:00; weekend occurrences to Monday 17:00; preserve legacy RPC compatibility.
- [x] Add page-local announcement drafting and print preview.
- [x] Fix new-department mode and verify automatic-award rerun/concurrency safety.
- [x] Compare source rules and application catalog; differences are in [history/backfill](HISTORY_AND_BACKFILL.md).
- [ ] Verify remote CI/production deployment for that feature rollout (local type/build and DB rule/permission checks were complete at this checkpoint).
- [ ] Perform authenticated device acceptance of entry, undo, import, student reads, and printing.

## Separate follow-ups

- [ ] Resolve five unlinked historical identities and review the original 100-point merit; preservation/review markers are complete.
- [ ] Decide catalog normalization and blank source scores; preserve existing items/manual entry meanwhile.
- [ ] Confirm new department rules/memberships; creation behavior is fixed.
- [ ] Confirm previously pending student Auth/PIN provisioning without committing identities or credentials.
- [ ] Confirm individual staff-account assignees.
- [ ] Connect the shared read API to SP/student dashboards; this feature covered DaS and the shared backend only.
