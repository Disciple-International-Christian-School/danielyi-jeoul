# DICS Core — Decision Log

**Language / 언어:** [English](DECISIONS.md) | [한국어](DECISIONS.ko.md)

This ledger records alternatives and reasons, complementing the narrative [development journal](DEVELOPMENT_JOURNAL.md). Status vocabulary: ACCEPTED, TRANSITION, OPEN, SUPERSEDED. Statuses describe the cited historical decisions; unresolved operational questions require current verification.

| ID | Status | Decision | Reason |
| --- | --- | --- | --- |
| D-001 | ACCEPTED | Separate canonical student and login UUIDs | Students may have no account; Auth providers must not define person identity |
| D-002 | ACCEPTED | One student master: core.students | Prevent duplicate masters across learning, discipline, lab, and assessment |
| D-003 | ACCEPTED | Grade/class in term enrollment | Preserve promotion and section history |
| D-004 | ACCEPTED | Preserve raw scores and derive NET | Apply policy without erasing original merits/demerits |
| D-005 | ACCEPTED | Administrator-closed settlement replaces calendar month | Home-leave cycles vary between two and three weeks |
| D-006 | ACCEPTED | due_at is timestamptz | Express 17:00, 21:00, and next-school-morning deadlines |
| D-007 | ACCEPTED | Explicit Asia/Seoul dates | Avoid previous-day defaults in morning work |
| D-008 | ACCEPTED | Idempotent merit RPC before scheduler | Duplicate-free results survive scheduler changes |
| D-009 | ACCEPTED | No guessed real-data identity matching | Duplicate names/typos can corrupt canonical identity |
| D-010 | ACCEPTED | Do not guess historical authors | Null is more accurate than invented provenance |
| D-011 | ACCEPTED | External SP Auth and local Core Auth are separate | Different projects cannot share Auth FKs |
| D-012 | TRANSITION | Preserve 28 verified pilot numbers | Existing login identifiers were verified one-to-one |
| D-013 | OPEN | School-wide student-number policy | GGNN embeds grade and conflicts with stable identity after promotion |
| D-014 | OPEN | Permanent GGNN or legacy login alias | Balance existing login compatibility and durable identification |
| D-015 | TRANSITION | Core provisioning console in Daniel | Safe interim path before dedicated Core Admin |
| D-016 | TRANSITION | Central shared-database migration ledger | Parallel live changes otherwise drift from Git |
| D-017 | ACCEPTED | Identity mappings use a secure migration path | Operational mappings do not belong in Git/issues/chats |
| D-018 | ACCEPTED | Stage individual-account adoption | Preserve continuity while personalizing audit actors |
| D-019 | ACCEPTED | Provisioning/password completion in Edge Functions | Keep service credentials server-side and verify real Auth changes |
| D-020 | ACCEPTED | Discipline stores only canonical UUID FKs | Dual-key/parity gates enabled removal of physical integer FKs |
| D-021 | ACCEPTED | Store aggregate evidence before destructive cut-over | Preserve a basis for verification and recovery decisions |
| D-022 | ACCEPTED | Git migration versions match production | Prevent reapplication and ordering drift |

## D-001 — Student identity differs from login identity

Choose `core.students.id` as canonical UUID and optional `core.students.auth_user_id` as the local Auth link. Reject students.id = auth.users.id: students without accounts still exist, authentication can change, and domains need one stable reference.

## D-009 — Do not turn 28/29 into an invented 29/29

Reconciliation found 29 source rows, 28 exact, one unmatched, zero ambiguous. Apply only 28 verified matches, hold the other for original-source review, and exclude PINs. This rule applies to future roster imports too.

## D-011 — External Auth namespace

SP Auth and Core Auth are independent namespaces. Preserve SP UUID → core.external_auth_identities → canonical student. Only a login provisioned in Core Auth may populate core.students.auth_user_id.

## D-013 / D-014 — Numbering policy remains open

Pilot IDs such as 0801/0901/1101 encoded two-digit grade plus sequence. If 0802 changes to a G9 number next year, it is not stable. If it stays 0802, users may mistake its prefix for current grade.

| Option | Benefit | Cost |
| --- | --- | --- |
| Keep GGNN permanently | Familiar; easy existing-login compatibility | Embedded grade becomes stale |
| Keep GGNN as alias and add stable school ID | Stable human identity with old-login compatibility | Two identifiers and transition explanation |
| Issue a new grade-independent number to all | Clean long-term structure | Change 29 pilot logins, handouts, and habits |

No final policy was chosen. Preserve the 28 verified numbers while the school decides before generating numbers for everyone. Canonical UUIDs already exist, so there is no technical need to rush.

## D-016 — Shared Core migration ownership

Core, discipline, study_planner, and computer_lab now share one database. Live-before-Git drift occurred during parallel work. Daniel's migrations are an interim central ledger; a future DICS-Core repository should own shared schema and migration ordering. Completion means rebuilding structure from Git, not merely observing a healthy live DB.

## D-017 — Identity bridges are operational data

Never put actual UUID/number mappings in SQL seeds, issues, or PR comments. Read a trusted source, verify mappings, use an authenticated/service migration path, and invoke guarded Core RPCs. Validate number existence; reject external identity reassignment and conflicting same-source identities; make repeated exact mappings idempotent. PIN/password values never participate.

## D-018 — Shared account to individual account

A typed entered_by_name and authenticated auth.uid() do not carry equal evidential weight. Provision personal accounts → verify real workflows → confirm scope → review audit actors → disable shared accounts. Do not remove the fallback first.

## D-019 — Password completion is server-verified

The old mark_admin_password_changed() client RPC could clear a flag without changing a password. Replace it with a JWT-authenticated Edge Function that updates Auth and only then clears must_change_password. Provisioning also uses the server-only Auth Admin API. Service credentials never enter browser JavaScript.

## D-020 — Completed discipline FK strategy

Use four stages: dual integer/UUID keys, UUID write entry points, Core reads/routes, then integer dependency removal. Reject immediate one-migration replacement because reflection/weekly/settlement/punishment rules and existing routes were operational. Each phase requires mismatch zero; dual-key triggers reject different-student pairs.

## D-021 — Evidence before dropping columns

Preflight: points 1/1 linked, point mismatch 0; punishments 0/0 linked, mismatch 0; weekly 1/1 and penalties 1/1, mismatch 0; settlement 0/0, mismatch 0; summary 175/175, mismatch 0. Store aggregates in discipline.core_cutover_evidence, with no per-student values. Then remove point_records.student_id and punishments.student_id; retain only core_student_id UUID NOT NULL. Legacy IDs are derived through the public.students bridge for old contracts. These are small historical datasets, not load-test evidence.

## D-022 — Match the live migration ledger

A draft version such as 20260927022500 can differ from the actual 20260926171350 application version. Identical content under a different version may be treated as unapplied by CLI tooling. After applying, read actual name/version, align the Git filename, and recheck uniqueness. Fifteen cut-over migrations plus admin RLS optimization were reconciled this way. Apply the same rule in a future central Core repository.
