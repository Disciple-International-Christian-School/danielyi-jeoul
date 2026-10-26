# Key Issues and Follow-up Checks

**Language / 언어:** [English](KEY_ISSUES.en.md) | [한국어](KEY_ISSUES.md)

[Documentation index](README.en.md) · [Main README](../README.en.md)

> **Documentation review: 2026-10-26.** This page summarizes decisions, roadmaps, and change logs stored in Git; it is **not** a live database audit. A verification-needed label does not imply a production incident.

## Status at a glance

| Area | Documented status | Next action |
| --- | --- | --- |
| School-wide student number policy (D-013/D-014) | **OPEN** | Decide on stable school identifiers and legacy login aliases |
| Discipline Core UUID migration | **Recorded as completed** | Preserve verified cut-over; do not relabel as outstanding |
| `public.students` compatibility bridge | **TRANSITION** | Audit callers, old URLs and cross-app dependencies before retirement |
| Study Planner → Core migration | **Current execution status needs verification** | Confirm identity, data, Auth, and rollback gates |
| Individual administrator accounts | **Rollout status needs verification** | Validate staff sign-in, permissions and audit before shared-account retirement |
| Shared Core DB migration ownership | **Interim governance exists** | Maintain central ledger and decide eventual Core repo ownership |
| Photo-based demerit intake | **Planned in roadmap** | Define privacy, review and retention requirements before implementation |

## 1. School-wide student numbers — OPEN

The older Study Planner `GGNN` pattern embeds a grade, making it unsuitable as a self-evidently permanent identifier after students advance to the next grade. The canonical identity is already the grade-independent `core.students.id` UUID.

**Decision required:** retain existing human-readable numbers, preserve them only as login aliases, or issue new stable school-wide numbers. Do not generate student IDs or match identities using names alone without a reviewed school policy.

Sources: [Decision Log — D-013/D-014](DECISIONS.md), [SP identity migration protocol](SP_IDENTITY_MIGRATION_PROTOCOL.md).

## 2. Discipline Core UUID vs. legacy compatibility — separate completed and transitional work

**Completed in the recorded migration:** discipline record tables moved to Core UUID foreign keys and dropped physical integer student FKs. The [cut-over runbook](DISCIPLINE_CORE_CUTOVER.md) records a production validation with `cutover_completed=true`. The [2026-10-15 change log](CHANGELOG.md) also records automatic synchronization of the Core roster into the legacy UI compatibility bridge.

**Still subject to a retirement decision:** `public.students.id` remains a compatibility bridge for numeric URLs, legacy RPC contracts and transitional tooling. Do not delete it until old links, front-end callers, other DICS applications, CI and recovery conditions have been checked.

Sources: [Discipline Core UUID Cut-over](DISCIPLINE_CORE_CUTOVER.md), [Change Log](CHANGELOG.md).

## 3. Study Planner integration — validate migration stages

Study Planner uses an external Auth namespace. Its Auth UUID must not be mistaken for a canonical Core student UUID or a local Core Auth UUID. Before data migration, verify identity reconciliation, source/target counts, FK consistency, Auth provisioning and rollback checkpoints.

A migration plan is not proof that deployment is either complete or still outstanding. Verify the actual execution history with the responsible maintainers before updating its status. Never guess a student's identity from a similar name.

Sources: [Migration plan](STUDY_PLANNER_MIGRATION_PLAN.md), [Migration runbook](SP_CORE_MIGRATION_RUNBOOK.md), [Identity protocol](SP_IDENTITY_MIGRATION_PROTOCOL.md).

## 4. Individual administrator accounts and audit trail — check rollout

The architecture for personal administrator accounts and audit attribution has implementation records. However, the [account operations runbook](ADMIN_ACCOUNT_OPERATIONS.md) reported that no individual accounts had been provisioned **at the time it was written**. Verify today's actual rollout separately.

Do not delete shared `seondo`/`sasaeng` credentials prematurely. Provision individual users, complete first-login password changes, test scope and audit records, confirm full team adoption, and only then deactivate shared accounts. Never disclose credentials in a PR.

Sources: [Admin Account Operations](ADMIN_ACCOUNT_OPERATIONS.md), [Change Log](CHANGELOG.md).

## 5. Shared DICS Core database migration governance

Several apps and developers can change the same Supabase database. Maintain consistency between the committed migrations, live migration versions, `supabase/migration-ledger.json`, validation evidence, and rollback instructions.

The [existing governance document](CORE_MIGRATION_GOVERNANCE.md) names `shualoalumin/danielyi-jeoul` as the interim ledger repository. The current repository lives at `Disciple-International-Christian-School/danielyi-jeoul`; the Owner should confirm current source-of-truth ownership and update stale paths as a separate governed decision. A dedicated DICS-Core repository remains a long-term architectural proposal.

Sources: [Core Migration Governance](CORE_MIGRATION_GOVERNANCE.md), [Decision Log — D-016/D-022](DECISIONS.md).

## 6. Planned features — not confirmed defects

The [operations roadmap](OPERATIONS_ROADMAP.md) includes **photo-based demerit-sheet intake with review** and an **integrated cross-app student profile**. These are planned enhancements, not evidence of a live defect. Any photo-processing design needs minimal collection of student data, role-based access, and explicit retention/deletion policies.

## Rules for maintaining this summary

- Update statuses only after checking later change logs, CI evidence, and production verification.
- When older roadmap checkboxes conflict with later cut-over evidence, favor the later verified record.
- Never commit student PII, student numbers, PINs, passwords or identity-mapping rows.
- These are **documentation summaries**, not new GitHub issues or approved engineering priorities.
