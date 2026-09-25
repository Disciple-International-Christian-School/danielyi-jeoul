# SP External Identity Migration Protocol

> Purpose: securely link existing Study Planner login identities to canonical DICS Core students without putting real mapping rows, PINs, or service credentials in Git.

## What moves

Only identity references:

    SP public.students.id
    = external SP Auth UUID

    SP public.students.student_no
    = existing human login ID

    DICS Core core.students.id
    = canonical student UUID

The result is stored in core.external_auth_identities.
The confirmed canonical UUID is also written back to SP public.students.core_student_id.

## What never moves through this tool

- PIN/password
- email
- student name
- DOB
- parent information
- arbitrary roster profile data

The runner queries only SP id/student_no/core_student_id and Core id/student_no.

## Preconditions

1. SP bridge migration has been applied so public.students.core_student_id exists.
2. Verified student numbers already exist in DICS Core for the cohort being migrated.
3. Known non-student accounts T01–T05 and DEV1 remain explicitly excluded.
4. Service-role credentials exist only in the trusted execution environment.
5. Credentials are never pasted into GitHub Issue, PR, or committed files.

## Environment variables

Set locally or in a trusted secret store:

    SP_SUPABASE_URL
    SP_SUPABASE_SERVICE_ROLE_KEY
    CORE_SUPABASE_URL
    CORE_SUPABASE_SERVICE_ROLE_KEY

Optional:

    SP_PROJECT_REF

Do not commit an env file. The repository already ignores .env and .env.*.

## Phase 1 — Dry run

Run:

    npm run migrate:sp-identities

The default is DRY RUN.

It reports aggregate counts only:

- source rows
- excluded non-student rows
- real source students
- Core students with student_no
- exact student_no matches
- unmatched students
- already-correct source bridge count
- already-correct external bridge count
- conflicts

It does not print actual student_no, Auth UUID, or Core UUID values.

## Hard-stop conditions

The runner aborts before any write if it sees:

- duplicate real student_no in SP
- duplicate student_no in Core
- existing SP core_student_id pointing to a different Core student
- external Auth UUID already linked to a different student
- same Core student already linked to a different SP Auth UUID

These cases require human investigation.

## Phase 2 — Apply

Only after dry-run aggregate counts are reviewed:

    npm run migrate:sp-identities -- --apply

Writes:

1. Core external_auth_identities
2. SP students.core_student_id

The operation is intentionally idempotent.

Two separate Supabase projects cannot share one database transaction. An interrupted run may leave one side ahead of the other, so the runner is designed to be safely re-run.

## Phase 3 — Verify

After apply, record aggregate state only:

    real students
    matched
    unmatched
    external links
    source bridge mapped
    conflicts = 0

Do not paste mapping rows into Git or coordination issues.

## Why this is preferable to manual copying

Manual UUID copying creates person-to-account mix-up risk, accidental PII disclosure, unrepeatable migration, and weak conflict checking.

The runner makes the migration repeatable and evidence-based while keeping operational identity values outside version control.

## Current expected first cohort

At the time this protocol was created:

    real SP pilot students   29
    exact Core matches       28
    unresolved                1
    ambiguous                 0

The unresolved row must remain unresolved until its source identity is verified. The first migration pass should therefore link only the exact-match cohort.
