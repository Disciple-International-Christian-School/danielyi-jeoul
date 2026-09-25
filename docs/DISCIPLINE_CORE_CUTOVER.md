# Discipline Core UUID Cut-over Runbook

> Purpose: safely retire the legacy integer student FK from Daniel's Scale after the discipline domain is fully anchored to `core.students.id`.

## Current architecture

Transition state:

```text
core.students.id (uuid)
        ↑ canonical identity

public.students.id (integer)
        ↑ legacy compatibility bridge

point_records
  student_id       integer   ← compatibility
  core_student_id  uuid      ← canonical

punishments
  student_id       integer   ← compatibility
  core_student_id  uuid      ← canonical
```

New point and punishment writes already start from the Core UUID.

## Why the integer FK is not dropped yet

The integer ID still appears in:

- student detail routes,
- some existing aggregation views,
- compatibility query keys,
- legacy RPC internals,
- older report contracts.

Dropping it before these are migrated would create unnecessary operational risk without improving current user behavior.

## Production readiness view

Use:

```sql
select * from public.v_discipline_core_fk_readiness;
```

Required before final cut-over:

```text
point_records_core_linked = point_records_total
point_records_mismatch    = 0

punishments_core_linked   = punishments_total
punishments_mismatch      = 0
```

The same values are visible in the lead-only Core Setup page.

## Gate A — Write path

Required:

- new point records use `create_point_record_core(...)`,
- new punishments use `create_punishment_core(...)`,
- browser code does not send legacy integer ID for new discipline creation,
- dual-key trigger still rejects mismatches.

Status: implemented.

## Gate B — Historical data

Required:

- every historical point record has Core UUID,
- every punishment has Core UUID,
- no mismatched pair,
- reflection linkage remains valid through point_record_id,
- audit logs preserve historical before/after data.

Status at initial dual-key migration:

```text
point records: 1/1 Core linked, mismatch 0
punishments:   0/0 Core linked, mismatch 0
```

Re-check immediately before final cut-over because production counts will grow.

## Gate C — Read path

Before dropping legacy FK, migrate and verify:

- student detail lookup,
- point-record list filtering,
- punishment list/detail joins,
- weekly scoring,
- settlement scoring,
- daily notices,
- weekly reports,
- dashboard summary,
- reflection operational views.

For each changed view/query, compare results before and after using aggregate counts and controlled samples.

Do not use names as migration join keys.

## Gate D — Routes and API contracts

Preferred final route identity:

```text
/students/:coreStudentId
```

or another canonical-ID route contract.

Do not expose a migration that makes old bookmarked integer routes silently point to another student.

A temporary redirect/compatibility resolver may be used during the route transition.

## Gate E — Department merit automation

Department memberships already use canonical Core UUID.

Before final cut-over confirm that generated:

```text
DEPARTMENT_WEEKLY
```

point records contain matching canonical UUIDs and remain idempotent.

## Gate F — Rollback plan

Before destructive schema changes:

1. record current relation/view definitions,
2. record readiness counts,
3. confirm latest database backup/recovery strategy,
4. deploy read-path changes first,
5. observe normal school workflow,
6. only then remove legacy dependency.

The final destructive migration should be separate from preparatory migrations.

## Proposed final sequence

```text
1. Core UUID dual-key             DONE
2. New writes Core UUID           DONE
3. Readiness dashboard            DONE
4. Migrate read/report contracts  NEXT
5. Migrate routes/query keys
6. Observe production
7. Remove legacy RPC dependency
8. Drop legacy discipline FK
9. Keep public.students bridge only if another legacy lane still needs it
```

## Stop conditions

Do not run final cut-over if any of these is true:

- mismatch > 0,
- linked < total,
- unresolved Core student mapping exists for a discipline record,
- CI is red,
- daily/weekly report output differs unexpectedly,
- SP/Core identity migration is in a state that would make student identity ambiguous,
- backup/recovery is not acceptable for the intended change.

## Evidence to preserve

For the project development narrative preserve:

- readiness snapshots,
- mismatch counts,
- migration commits,
- CI results,
- rollback test results,
- any discovered dependency that delayed the destructive cut-over,
- final before/after report parity evidence.

No student PII is required in this evidence.
