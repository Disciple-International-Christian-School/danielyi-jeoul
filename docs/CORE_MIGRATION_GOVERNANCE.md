# DICS Core Migration Governance

> Interim governance for a shared Supabase database used by multiple DICS applications.

## Why this exists

DICS Core is no longer touched by only one application.

The same Supabase project now contains or is preparing:

- core.*
- discipline.*
- study_planner.*
- computer_lab.*
- future assessment.*

Parallel Claude/GPT/app work has already produced a real example of database drift:

    live database changed
    before
    the same structural change existed in the Git migration tree

A shared database therefore needs an explicit migration owner and handoff contract.

## 1. Interim source of truth

Until a dedicated DICS-Core repository exists:

    shualoalumin/danielyi-jeoul
    supabase/migrations/

acts as the interim version-controlled migration ledger for the shared Core project.

This is an operational compromise, not the final ownership model.

Daniel's Scale remains a discipline app; the Core schema should eventually have its own repository.

## 2. Long-term target

Create a dedicated repository, suggested name:

    DICS-Core

That repository should own:

- core schema
- academic terms/classes/enrollments
- shared identity
- external identity bridges
- central role/directory primitives
- cross-domain migration ordering
- shared database verification scripts
- disaster-recovery / rebuild instructions

Application repositories should own:

- frontend code,
- domain-specific business logic,
- domain-specific migrations where safely isolated.

## 3. Domain ownership

Suggested ownership:

    DICS-Core
      core.*

    Daniel's Scale
      discipline.*

    SP Manager DICS
      study_planner.*

    Computer Lab
      computer_lab.*

    Assessment apps
      assessment.*

Cross-domain migrations must be coordinated through the Core migration ledger.

## 4. No direct structural drift

A structural live-DB change is incomplete until:

1. a migration exists in version control,
2. the migration is idempotent or has a clear one-time ordering,
3. the live migration name is recorded,
4. the migration can recreate the structure in a fresh environment,
5. relevant docs/change history are updated.

If a parallel session changes live DB first, the next session must create a reconciliation migration.

## 5. Data vs schema

Schema/rules belong in Git.

Examples:

- CREATE TABLE
- ALTER TABLE
- views
- RPCs
- triggers
- RLS
- indexes
- non-PII reference constants

Operational PII does not belong in public Git.

Examples:

- student names
- student numbers
- PINs
- DOB
- class roster rows
- verified identity mappings

Operational data changes may be executed directly in Supabase, but the method and aggregate result should be recorded.

## 6. Migration naming

Use timestamped files for Git migrations.

Do not rewrite an already-applied migration to hide a mistake.

Prefer:

    original migration
    correction migration

This preserves the development story and makes production history explainable.

## 7. Parallel AI handoff

Every AI session that changes shared DB structure should record:

    repository
    branch
    commit
    live migration name
    schemas/tables touched
    validation result
    rollback or correction strategy
    next dependency

For SP, GitHub Issue #2 is already used as a Claude/GPT coordination board.

A future DICS-Core repo should have its own central coordination issue.

## 8. Auth namespace rule

Never assume UUID equality means shared identity.

Distinguish:

    canonical person/student identity
    Core-local Auth identity
    external/legacy Auth identity

Use:

    core.students.id
    core.students.auth_user_id
    core.external_auth_identities

for those separate concepts.

## 9. Fresh-environment test

A core quality target is:

> Could we rebuild the database structure from Git without relying on undocumented live changes?

If the answer is no, migration governance is incomplete.

## 10. Reporting value

This governance itself is part of the project story.

The system did not begin with enterprise-style migration management. That need emerged naturally when:

- several school applications began sharing identity,
- multiple AI development agents worked in parallel,
- live DB changes began arriving from multiple workflows.

The migration process matured in response to actual operational complexity.
