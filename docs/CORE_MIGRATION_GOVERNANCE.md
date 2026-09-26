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
    supabase/migration-ledger.json

act as the interim version-controlled migration ledger for the shared Core project.

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
2. its Git filename matches the actual live version/name,
3. the migration ledger marks it TRACKED,
4. the migration is idempotent or has a clear one-time ordering,
5. the migration can recreate the structure in a fresh environment,
6. relevant docs/change history are updated.

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

Operational data changes may be executed directly in Supabase, but the method and aggregate result should be recorded. If such a change appears in Supabase migration history, record only a privacy-safe LIVE_ONLY_DATA ledger entry rather than committing the data SQL.

## 6. Migration naming

Use timestamped files for Git migrations.

Do not rewrite an already-applied migration to hide a mistake.

Prefer:

    original migration
    correction migration

This preserves the development story and makes production history explainable.

## 6A. Production migration ledger contract

The live Supabase migration history and Git migrations are reconciled through:

    supabase/migration-ledger.json

Two statuses are allowed.

### TRACKED

A structural migration that belongs in Git.

Contract:

    ledger version
    + ledger name
    = exact Git filename

CI fails if:

- the tracked file is missing,
- its filename does not match the production version/name,
- a Git migration exists without a TRACKED ledger entry,
- ledger versions are duplicated.

### LIVE_ONLY_DATA

A historical/operational data migration whose SQL must not be committed.

Examples include:

- private student roster imports,
- corrections tied to private roster rows,
- environment-specific Auth/admin bindings,
- historical seed data not required to reconstruct schema.

Contract:

- version is recorded,
- rationale is recorded,
- SQL file must be absent from public Git,
- a sensitive live migration name may be redacted if the name itself contains private information.

CI fails if a SQL file appears for a LIVE_ONLY_DATA version.

Current reconciliation checkpoint:

    production migrations 53
    TRACKED structural    49
    LIVE_ONLY_DATA         4
    extra Git migrations   0

This gives a reproducible structural ledger without forcing operational PII into source control.

## 6B. Applying a new migration

After any live migration:

1. read the actual Supabase migration version,
2. compare it with the Git filename,
3. if the connector assigned a different version, rename the Git file to the live version,
4. add or update the ledger entry,
5. run `npm run check:migration-ledger`,
6. wait for CI green,
7. record the change in the development journal when it materially changes architecture.

Do not assume a timestamp chosen before execution is the timestamp production recorded.
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
