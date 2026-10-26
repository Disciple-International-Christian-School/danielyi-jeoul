# History and semester ledger — 2026-10-26

## Delivered in this change

- Dashboard weekday buttons open the selected date's original point records.
- Read-only day/week navigation and current CORE-term cumulative totals.
- Search by student name, number, homeroom, or recorded item.
- Archive reads page in deterministic date/id order rather than truncating at a server row limit.
- Existing current-week and settlement status remain current, not historical snapshots.
- No changes to score formulas, records, RLS, reflections, or punishments.
- NET remains penalty minus merit. Negative NET means merit exceeds penalties.

## Evidence and limits

Read-only production inspection found no negatively stored point values. Both
weekly and settlement SQL subtract merit from penalties. The reported example
was correctly calculated; improving sign explanation avoids treating a negative
NET as another penalty total.

The current CORE term starts 2026-08-19. The earliest non-deleted point record
is 2026-09-21. Semester totals therefore represent **entered records only**, not
proof that all paper records were entered. Closing settlement periods does not
delete point records. Historical reflection statuses are shown only on existing
current screens; this archive is a score ledger, not an as-of status simulator.

Scoped dashboards match current roster membership; ALL scope includes archived
records even if the student is not in the active roster. Historic class labels
are not reconstructed; shown class labels come from the current roster.

## Pending: historical sheet import

Not implemented by this change. Obtain a representative original sheet before
deciding its mapping. Never invent dates from a weekly total or import NET as a
penalty record. Required safeguards:

1. Preview and validate exact CORE student number/UUID; disambiguate names.
2. Retain original occurrence date, separate merit/penalty, reason, and provenance.
3. Reject invalid rows before any writes; batch-atomic commit.
4. Idempotent source keys and cross-checks against existing records; distinguish
   an intentional second event from a duplicate file upload.
5. Store import batch, source-row identity, actor, and recoverable rollback.
6. Do not silently generate overdue reflections or retroactive sanctions from
   backfilled paper records. Confirm whether existing paper actions are already
   settled before enabling any such behavior.
7. Reconcile totals per student/week and whole term against the original sheets.

Validation: npm run typecheck; npm run build; node scripts/test-history.mjs.
Live signed-in browser verification remains required before production rollout.
