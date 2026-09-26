# Discipline Core UUID Cut-over Runbook

> Purpose: safely retire the legacy integer student FK from Daniel's Scale after the discipline domain is fully anchored to `core.students.id`.
>
> Status: **COMPLETED / VERIFIED**

## Final architecture

```text
core.students.id (uuid)
        ↑ canonical identity

point_records
  core_student_id uuid NOT NULL

punishments
  core_student_id uuid NOT NULL
```

Physical legacy columns removed:

```text
point_records.student_id   REMOVED
punishments.student_id     REMOVED
```

Legacy integer IDs are no longer stored on discipline records.

Compatibility for older UI/contracts is derived only when needed:

```text
core_student_id
   ↓
public.students.core_student_id
   ↓
public.students.id
   ↓
derived compatibility student_id
```

## Production status

Use:

```sql
select * from public.v_discipline_core_cutover_status;
```

Verified production result:

```text
stage                  POST_LEGACY_COLUMN_DROP_VERIFIED
legacy_columns_removed true
cutover_completed      true

point records          1 / 1 Core linked
point mismatch         0

punishments            0 / 0 Core linked
punishment mismatch    0

weekly mismatch        0
weekly penalty mismatch 0
settlement mismatch    0
summary mismatch       0
```

## Gate A — Write path — DONE

Authoritative implementations:

```text
create_point_record_core(core_student_id, ...)
create_punishment_core(core_student_id, ...)
```

The integer RPCs remain compatibility wrappers only:

```text
create_point_record(integer, ...)
  → resolve Core UUID
  → create_point_record_core(...)

create_punishment(integer, ...)
  → resolve Core UUID
  → create_punishment_core(...)
```

Frontend new writes send Core UUID.

Department weekly merit generation also stores only Core UUID.

## Gate B — Historical data — DONE

Before destructive cut-over:

```text
point_records total        1
Core linked                1
mismatch                   0

punishments total          0
Core linked                0
mismatch                   0
```

All existing discipline records had canonical Core identity before the integer columns were removed.

Reflection linkage remains through:

```text
reflection_records.point_record_id
```

and was unaffected by the student FK change.

## Gate C — Read path — DONE

Migrated to Core UUID internally:

- student detail lookup,
- point-record filtering,
- punishment lookup,
- reflection lookup,
- daily notices,
- weekly scoring,
- weekly penalty history,
- settlement scoring,
- student summary,
- weekly reports,
- dashboard counts.

Public view contracts may still expose a derived integer `student_id` for compatibility, but they no longer depend on a physical discipline-table integer FK.

## Gate D — Routes and API contracts — DONE

New student links use:

```text
/students/:coreStudentId
```

The route shape was intentionally unchanged while the identifier semantics moved to Core UUID.

Legacy numeric URLs remain temporarily supported:

```text
numeric ref → legacy lookup
UUID ref    → canonical Core lookup
```

This prevents old bookmarks from silently breaking during transition.

## Gate E — Department merit automation — DONE

Department membership identity already uses:

```text
core.department_memberships.student_id
→ core.students.id
```

Weekly merit generation now inserts:

```text
point_records.core_student_id
```

without a physical integer student FK.

The deterministic `source_key` remains the idempotency guard.

## Gate F — Reflection trigger — DONE

A late dependency audit found that:

```text
private.create_reflection_for_penalty()
```

still used:

```text
new.student_id
```

to look up grade.

Before the destructive cut-over it was changed to:

```text
new.core_student_id
→ public.students.core_student_id
→ grade
```

Post-cutover rollback testing confirmed that new negative point records still generate reflection rows.

## Gate G — Calculation parity — DONE

Core shadow calculations were created before promotion.

Pre-promotion evidence:

```text
weekly
legacy 1 / Core 1 / mismatch 0

weekly penalties
legacy 1 / Core 1 / mismatch 0

settlement
legacy 0 / Core 0 / mismatch 0

student summary
legacy 175 / Core 175 / mismatch 0
```

Only after mismatch=0 were the stable public contracts promoted to the Core implementations.

## Aggregate evidence ledger

Before the destructive migration, aggregate evidence was stored in:

```text
discipline.core_cutover_evidence
```

No student names, student numbers, Auth UUIDs, or per-student mappings are stored there.

The pre-drop evidence remains available even after the old shadow views and physical integer columns were removed.

## Post-cutover rollback tests

After the physical columns were removed:

### Point write

```text
Core RPC           Core UUID match true
Legacy wrapper     Core UUID match true
Reflection created true / true
```

### Punishment write

```text
Core RPC           Core UUID match true
Legacy wrapper     Core UUID match true
```

All test transactions were rolled back. No test discipline rows remain in production.

## Production state preserved

Before and after cut-over:

```text
point records        1
point sum            5
reflection records   1
punishments          0
weekly report rows 175
```

Dashboard counts remained unchanged.

## PostgreSQL dependency verification

String search was not used as the final dependency authority because `core_student_id` itself contains the substring `student_id`.

Physical column dependencies were resolved with PostgreSQL `pg_depend`.

This exposed only the true legacy shadow/readiness dependencies.

A separate trigger audit then found the runtime reflection dependency.

Both schema dependencies and trigger dependencies were removed before the column drop.

## Migration ledger reconciliation

Live Supabase history and Git migration filenames were reconciled after the cut-over.

Recent migration filename versions now match the actual production migration versions one-to-one.

This prevents a future CLI migration run from treating an already-applied migration as new solely because the Git timestamp differs.

## Current compatibility boundary

The discipline record tables are fully Core-native.

The remaining legacy compatibility boundary is:

```text
public.students.id
```

which may still be used by:

- legacy numeric student URLs,
- Core setup / G9 transitional tools,
- older client contracts,
- integer compatibility RPCs.

This bridge can be retired separately once no other DICS lane depends on it.

It is no longer a physical FK of discipline records.

## Current stop conditions for any future cleanup

Do not remove the remaining compatibility layer unless:

- no active frontend sends or expects numeric student IDs,
- old bookmarked numeric routes have an explicit migration/redirect policy,
- G9/Core setup tools use canonical Core UUID directly,
- SP and other domains do not depend on the same bridge,
- CI is green,
- production status view remains `cutover_completed=true`,
- backup/recovery strategy is acceptable.

## Evidence to preserve

Keep:

- readiness snapshots,
- mismatch counts,
- migration commits,
- CI results,
- rollback test results,
- pre-drop evidence rows,
- PostgreSQL dependency findings,
- final production state comparison,
- Git ↔ live migration reconciliation records.

No student PII is required for this evidence.
