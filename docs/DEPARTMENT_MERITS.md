# Department Membership and Automatic Merits

**Language / 언어:** [English](DEPARTMENT_MERITS.md) | [한국어](DEPARTMENT_MERITS.ko.md)

Updated October 27, 2026. The user requested automatic merits to resume after the manual-entry reset. This supersedes the paused-automation checkpoint in [the reset record](OPERATIONS_2026-10-27.md).

Four existing merit rules and the Monday 00:00 KST cron are enabled again. Only this week's reset-derived automatic awards for eligible memberships were restored. Older reset events and inactive historical weekly balances remain archived. Manual entries are preserved. Repeated generation and cron execution produced no duplicate awards.

Membership intervals are [starts_on, ends_on). Ending a membership today removes it from the current member list and department count today. The old inclusive end-date check incorrectly kept it visible through the end date. The same boundary now applies to weekly eligibility checks, member reads, and membership RPC lookups.

Weekly merits are based on membership on Monday. A student ending on Tuesday was eligible on that Monday and retains that week's award, while being absent from the current roster and future Monday eligibility. A student ending on Monday is excluded from that Monday's eligibility. Existing awards are not deleted when ending a membership.

The membership RPC permits ending a membership in a paused department (or for a nonactive student), while additions still require an active department and student. Same-day join/end/rejoin is supported without a duplicate-key error. UI disables termination while a request is pending and refreshes score/history queries after changes.

Database rollback tests cover same-day termination visibility, preserved end-date history, same-day rejoin, and removal while the department is paused. The recorded production operation verified 35 current memberships, zero ended-today rows visible, and 38/38 current-week awards generated. Current membership count and Monday eligibility count intentionally represent different dates.
